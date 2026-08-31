import Foundation

@MainActor
final class FlightBotOrchestrator {
    struct SearchResult {
        let candidates: [LiveFlightCandidate]
        let summary: FlightBotSearchSummary
        let blockedChallenges: [FlightBotChallenge]
    }

    enum OrchestratorError: LocalizedError {
        case noVerifiedResults(blockedProviders: [String])

        var errorDescription: String? {
            switch self {
            case .noVerifiedResults(let blocked):
                let blockedText = blocked.isEmpty ? "" : " Некоторые авиакомпании запросили дополнительную проверку: \(blocked.joined(separator: ", "))."
                return "Не удалось получить рейс с подтверждённым номером и маршрутом.\(blockedText)"
            }
        }
    }

    private enum ProviderAttempt {
        case candidates([LiveFlightCandidate])
        case challenge(FlightBotChallenge)
        case failed
    }

    private struct SearchCheckpoint {
        var candidates: [LiveFlightCandidate]
        var attemptedKeys: Set<String>
        var challenges: [FlightBotChallenge]
        var updatedAt: Date
    }

    private struct SearchBatch {
        let date: Date
        let providers: [FlightBotProvider]
        let isFlexibleCoverageBatch: Bool
    }

    static let shared = FlightBotOrchestrator()

    let minimumTarget = AppConfig.flightBotMinimumOptions
    let preferredTarget = AppConfig.flightBotPreferredOptions

    private var checkpoints: [String: SearchCheckpoint] = [:]
    private let checkpointLifetime: TimeInterval = 10 * 60

    private init() {}

    func search(
        request baseRequest: FlightBotSearchRequest,
        flexibility: DateFlexibility,
        requirement: FlightCandidateRequirement = .displayable,
        minimumResults: Int? = nil,
        preferredResults: Int? = nil,
        maxProviderAttempts: Int? = nil,
        allowedProviderIDs: Set<FlightBotProviderID>? = nil,
        publishChallenges: Bool = true,
        onProvider: (@MainActor (FlightBotProvider) -> Void)? = nil,
        onProgress: (@MainActor ([LiveFlightCandidate]) async -> Void)? = nil
    ) async throws -> SearchResult {
        pruneCheckpoints()

        // Production has one candidate contract only: a complete displayable
        // itinerary with exact carrier flight numbers.
        let effectiveRequirement: FlightCandidateRequirement = .displayable
        let hardMinimum = max(1, minimumResults ?? minimumTarget)
        let desired = max(hardMinimum, preferredResults ?? preferredTarget)
        let searchID = UUID().uuidString
        let requestedAt = Date()
        let deadline = requestedAt.addingTimeInterval(AppConfig.flightBotSearchHardTimeoutSeconds)
        let dates = FlightDatePlanner.dates(anchor: baseRequest.date, flexibility: flexibility)
        let providers = FlightBotProviderRegistry
            .deviceProviders(for: baseRequest.origin, destination: baseRequest.destination)
            .filter { provider in
                provider.isOfficialCarrierSource && (allowedProviderIDs?.contains(provider.id) ?? true)
            }

        let checkpointKey = signature(for: baseRequest, flexibility: flexibility, requirement: effectiveRequirement)
        let existing = checkpoints[checkpointKey]
        var collected = (existing?.candidates ?? []).filter(\.isDisplayableCandidate)
        var attemptedKeys = existing?.attemptedKeys ?? []
        var challenges = existing?.challenges ?? []

        let batches = buildBatches(dates: dates, providers: providers, flexibility: flexibility)
        let allAttemptKeys = Set(batches.flatMap { batch in
            batch.providers.map { attemptKey(provider: $0, date: batch.date) }
        })
        if !allAttemptKeys.isEmpty, allAttemptKeys.isSubset(of: attemptedKeys) {
            // “Continue search” after a complete pass starts another fresh pass but
            // retains already verified candidates for deduplication/ranking.
            attemptedKeys.removeAll()
        }

        var succeeded = 0
        var started = 0
        var completedBatches = 0
        let requiredFlexibleCoverageBatches: Int = {
            guard flexibility.isFlexibleDayRange, !dates.isEmpty, !providers.isEmpty else { return 0 }
            // One exact-date bounded batch plus one priority-carrier batch for each
            // alternate date is sufficient coverage before early stopping.
            return dates.count
        }()
        var flexibleCoverageCompleted = 0

        searchLoop: for batch in batches {
            guard Date() < deadline else { break }
            if let maxProviderAttempts, started >= maxProviderAttempts { break }

            var untried = batch.providers.filter {
                !attemptedKeys.contains(attemptKey(provider: $0, date: batch.date))
            }
            if let maxProviderAttempts {
                let remaining = max(0, maxProviderAttempts - started)
                untried = Array(untried.prefix(remaining))
            }
            if untried.isEmpty {
                if batch.isFlexibleCoverageBatch { flexibleCoverageCompleted += 1 }
                continue
            }

            let request = FlightBotSearchRequest(
                direction: baseRequest.direction,
                origin: baseRequest.origin,
                destination: baseRequest.destination,
                date: batch.date,
                adults: baseRequest.adults,
                children: baseRequest.children,
                infants: baseRequest.infants,
                cabin: baseRequest.cabin
            )

            started += untried.count
            let tasks: [(String, Task<ProviderAttempt, Never>)] = untried.map { provider in
                let key = attemptKey(provider: provider, date: batch.date)
                return (key, Task { @MainActor in
                    onProvider?(provider)
                    do {
                        let remaining = max(3, deadline.timeIntervalSinceNow)
                        let providerBudget = min(provider.deviceTimeoutSeconds, remaining)
                        let results = try await FlightBotRunner(
                            provider: provider,
                            request: request,
                            requirement: effectiveRequirement
                        ).run(timeoutSeconds: providerBudget)
                        let accepted = results.filter(\.isDisplayableCandidate)
                        if !accepted.isEmpty, let onProgress {
                            // Do not wait for a slower provider in the same bounded
                            // batch before the first verified airline card appears.
                            await onProgress(accepted)
                        }
                        return .candidates(results)
                    } catch FlightBotRunner.BotError.challengeRequired(let challenge) {
                        if !publishChallenges {
                            // Hidden return prewarm must never strand a provider
                            // session in an invisible verification state. A later
                            // visible search will start a fresh carrier attempt.
                            FlightBotDeviceSessionPool.shared.verificationCancelled(challenge)
                            return .failed
                        }
                        return .challenge(challenge)
                    } catch {
                        return .failed
                    }
                })
            }

            for (key, task) in tasks {
                attemptedKeys.insert(key)
                switch await task.value {
                case .candidates(let results):
                    let accepted = results.filter(\.isDisplayableCandidate)
                    if !accepted.isEmpty { succeeded += 1 }
                    collected.append(contentsOf: accepted)
                case .challenge(let challenge):
                    challenges.append(challenge)
                case .failed:
                    break
                }
            }

            completedBatches += 1
            if batch.isFlexibleCoverageBatch { flexibleCoverageCompleted += 1 }

            let ranked = deduplicateAndRank(collected, anchor: baseRequest.date, flexibility: flexibility)
            checkpoints[checkpointKey] = SearchCheckpoint(
                candidates: ranked,
                attemptedKeys: attemptedKeys,
                challenges: challenges,
                updatedAt: Date()
            )

            // Surface every completed provider batch immediately. This is the
            // production boundary used by the flight screens: one slow or empty
            // source must never hide results already returned by another airline.
            if let onProgress {
                await onProgress(Array(ranked.prefix(16)))
            }

            // For ±1–2 days, always give the highest-priority official carriers
            // a chance on every candidate date before stopping. This is what makes
            // cheaper flights one/two days earlier or later actually appear.
            let coverageSatisfied = !flexibility.isFlexibleDayRange || flexibleCoverageCompleted >= requiredFlexibleCoverageBatches
            guard coverageSatisfied else { continue }

            if ranked.count >= desired { break searchLoop }
            if ranked.count >= hardMinimum && completedBatches >= requiredFlexibleCoverageBatches + 3 {
                break searchLoop
            }
        }

        let final = Array(
            deduplicateAndRank(collected.filter(\.isDisplayableCandidate), anchor: baseRequest.date, flexibility: flexibility)
                .prefix(16)
        )
        let summary = FlightBotSearchSummary(
            searchID: searchID,
            requestedAt: requestedAt,
            providersStarted: started,
            providersSucceeded: succeeded,
            providersBlocked: challenges.count,
            rawCandidateCount: collected.count,
            deduplicatedCandidateCount: final.count,
            minimumTarget: hardMinimum,
            preferredTarget: desired
        )

        checkpoints[checkpointKey] = SearchCheckpoint(
            candidates: final,
            attemptedKeys: attemptedKeys,
            challenges: challenges,
            updatedAt: Date()
        )

        if publishChallenges, let challenge = challenges.first {
            FlightBotChallengeCenter.shared.publish(challenge)
        }

        guard !final.isEmpty else {
            throw OrchestratorError.noVerifiedResults(
                blockedProviders: Array(Set(challenges.map(\.providerName))).sorted()
            )
        }

        return SearchResult(candidates: final, summary: summary, blockedChallenges: challenges)
    }

    func resetCheckpointsAfterVerification() {
        checkpoints.removeAll()
    }

    private func buildBatches(
        dates: [Date],
        providers: [FlightBotProvider],
        flexibility: DateFlexibility
    ) -> [SearchBatch] {
        guard !dates.isEmpty, !providers.isEmpty else { return [] }
        let size = max(1, AppConfig.flightBotProviderBatchSize)

        if flexibility.isFlexibleDayRange {
            // Exact-date coverage comes first for every reviewed carrier. This
            // prevents a third carrier (for example Air Samarkand) from waiting
            // behind ten ±1/±2 attempts. After exact coverage, nearby dates keep
            // the authoritative 0,-1,+1,-2,+2 order and prioritise the first two
            // carrier adapters before broader fallback coverage.
            let priorityCoverageCount = min(2, providers.count)
            var output: [SearchBatch] = []

            if let exactDate = dates.first {
                for start in stride(from: 0, to: providers.count, by: size) {
                    let end = min(providers.count, start + size)
                    output.append(SearchBatch(
                        date: exactDate,
                        providers: Array(providers[start..<end]),
                        isFlexibleCoverageBatch: start < priorityCoverageCount
                    ))
                }
            }

            for date in dates.dropFirst() {
                let priority = Array(providers.prefix(priorityCoverageCount))
                if !priority.isEmpty {
                    output.append(SearchBatch(date: date, providers: priority, isFlexibleCoverageBatch: true))
                }
            }

            let remaining = Array(providers.dropFirst(priorityCoverageCount))
            for date in dates.dropFirst() {
                for start in stride(from: 0, to: remaining.count, by: size) {
                    let end = min(remaining.count, start + size)
                    output.append(SearchBatch(date: date, providers: Array(remaining[start..<end]), isFlexibleCoverageBatch: false))
                }
            }
            return output
        }

        var output: [SearchBatch] = []
        for date in dates {
            for start in stride(from: 0, to: providers.count, by: size) {
                let end = min(providers.count, start + size)
                output.append(SearchBatch(date: date, providers: Array(providers[start..<end]), isFlexibleCoverageBatch: false))
            }
        }
        return output
    }

    private func signature(
        for request: FlightBotSearchRequest,
        flexibility: DateFlexibility,
        requirement: FlightCandidateRequirement
    ) -> String {
        let formatter = ISO8601DateFormatter()
        return [
            request.direction.rawValue,
            request.origin,
            request.destination,
            formatter.string(from: Calendar.current.startOfDay(for: request.date)),
            flexibility.rawValue,
            String(request.adults),
            String(request.children),
            String(request.infants),
            request.cabin,
            requirement.rawValue
        ].joined(separator: "|")
    }

    private func attemptKey(provider: FlightBotProvider, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date))|\(provider.id.rawValue)"
    }

    private func pruneCheckpoints() {
        let cutoff = Date().addingTimeInterval(-checkpointLifetime)
        checkpoints = checkpoints.filter { $0.value.updatedAt >= cutoff }
    }

    private func deduplicateAndRank(
        _ candidates: [LiveFlightCandidate],
        anchor: Date,
        flexibility: DateFlexibility
    ) -> [LiveFlightCandidate] {
        var unique: [String: LiveFlightCandidate] = [:]
        for candidate in candidates where candidate.isDisplayableCandidate {
            if let existing = unique[candidate.deduplicationKey] {
                unique[candidate.deduplicationKey] = preferredSource(candidate, over: existing) ? candidate : existing
            } else {
                unique[candidate.deduplicationKey] = candidate
            }
        }

        return unique.values.sorted { lhs, rhs in
            let leftDay = abs(Calendar.current.startOfDay(for: lhs.departureAt).timeIntervalSince(Calendar.current.startOfDay(for: anchor)))
            let rightDay = abs(Calendar.current.startOfDay(for: rhs.departureAt).timeIntervalSince(Calendar.current.startOfDay(for: anchor)))

            if flexibility.isFlexibleDayRange {
                // When flexible dates are explicitly selected, fare becomes the
                // primary ranking signal within the same currency; nearby date and
                // fewer stops break ties.
                if lhs.observedCurrency == rhs.observedCurrency && lhs.observedFare != rhs.observedFare {
                    return lhs.observedFare < rhs.observedFare
                }
                if leftDay != rightDay { return leftDay < rightDay }
                if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            } else {
                if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
                if leftDay != rightDay { return leftDay < rightDay }
                if lhs.observedCurrency == rhs.observedCurrency && lhs.observedFare != rhs.observedFare {
                    return lhs.observedFare < rhs.observedFare
                }
            }
            return providerPriority(lhs.providerID) < providerPriority(rhs.providerID)
        }
    }

    private func preferredSource(_ lhs: LiveFlightCandidate, over rhs: LiveFlightCandidate) -> Bool {
        let leftRichness = (lhs.segments ?? []).reduce(0) { score, segment in
            score + 1 + (segment.aircraft == nil ? 0 : 1) + (segment.origin.terminal == nil ? 0 : 1) + (segment.destination.terminal == nil ? 0 : 1)
        }
        let rightRichness = (rhs.segments ?? []).reduce(0) { score, segment in
            score + 1 + (segment.aircraft == nil ? 0 : 1) + (segment.origin.terminal == nil ? 0 : 1) + (segment.destination.terminal == nil ? 0 : 1)
        }
        if leftRichness != rightRichness { return leftRichness > rightRichness }
        if lhs.observedCurrency == rhs.observedCurrency && lhs.observedFare != rhs.observedFare {
            return lhs.observedFare < rhs.observedFare
        }
        return providerPriority(lhs.providerID) < providerPriority(rhs.providerID)
    }

    private func providerPriority(_ id: FlightBotProviderID) -> Int {
        FlightBotProviderRegistry.providers.first(where: { $0.id == id })?.priority ?? 999
    }
}
