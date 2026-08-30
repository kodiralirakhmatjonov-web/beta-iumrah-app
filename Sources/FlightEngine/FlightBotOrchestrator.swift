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
                let blockedText = blocked.isEmpty ? "" : " Некоторые источники запросили дополнительную проверку: \(blocked.joined(separator: ", "))."
                return "Поиск не успел получить ни одного подтверждённого варианта.\(blockedText)"
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
        preferredResults: Int? = nil
    ) async throws -> SearchResult {
        pruneCheckpoints()

        let hardMinimum = max(1, minimumResults ?? minimumTarget)
        let desired = max(hardMinimum, preferredResults ?? preferredTarget)
        let comfortTarget = min(desired, max(hardMinimum, AppConfig.flightBotTargetOptions))
        let searchID = UUID().uuidString
        let requestedAt = Date()
        let deadline = requestedAt.addingTimeInterval(AppConfig.flightBotSearchHardTimeoutSeconds)
        let dates = FlightDatePlanner.dates(anchor: baseRequest.date, flexibility: flexibility)
        let providers = FlightBotProviderRegistry.ordered(for: baseRequest.origin, destination: baseRequest.destination)
        let checkpointKey = signature(for: baseRequest, flexibility: flexibility, requirement: requirement)
        let existing = checkpoints[checkpointKey]

        var collected = existing?.candidates ?? []
        let possibleAttemptCount = max(1, dates.count * providers.count)
        // “Continue search” resumes from the last untried provider/date. Once a full
        // pass has genuinely exhausted every source, a later retry starts a fresh pass.
        var attemptedKeys = existing?.attemptedKeys ?? []
        if attemptedKeys.count >= possibleAttemptCount { attemptedKeys.removeAll() }
        var challenges = existing?.challenges ?? []
        var succeeded = 0
        var started = 0
        var completedBatches = 0

        searchLoop: for date in dates {
            guard Date() < deadline else { break }

            let request = FlightBotSearchRequest(
                direction: baseRequest.direction,
                origin: baseRequest.origin,
                destination: baseRequest.destination,
                date: date,
                adults: baseRequest.adults,
                children: baseRequest.children,
                infants: baseRequest.infants,
                cabin: baseRequest.cabin
            )

            for batchStart in stride(from: 0, to: providers.count, by: AppConfig.flightBotProviderBatchSize) {
                guard Date() < deadline else { break searchLoop }

                let batchEnd = min(providers.count, batchStart + AppConfig.flightBotProviderBatchSize)
                let batch = Array(providers[batchStart..<batchEnd]).filter { provider in
                    !attemptedKeys.contains(attemptKey(provider: provider, date: date))
                }
                guard !batch.isEmpty else { continue }
                started += batch.count

                let tasks: [(String, Task<ProviderAttempt, Never>)] = batch.map { provider in
                    let key = attemptKey(provider: provider, date: date)
                    return (key, Task { @MainActor in
                        do {
                            let remaining = max(3, deadline.timeIntervalSinceNow)
                            let providerBudget = min(AppConfig.flightBotProviderTimeoutSeconds, remaining)
                            let results = try await FlightBotRunner(
                                provider: provider,
                                request: request,
                                requirement: requirement
                            ).run(timeoutSeconds: providerBudget)
                            return .candidates(results)
                        } catch FlightBotRunner.BotError.challengeRequired(let challenge) {
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
                        if !results.isEmpty { succeeded += 1 }
                        collected.append(contentsOf: results)
                    case .challenge(let challenge):
                        challenges.append(challenge)
                    case .failed:
                        break
                    }
                }

                checkpoints[checkpointKey] = SearchCheckpoint(
                    candidates: collected,
                    attemptedKeys: attemptedKeys,
                    challenges: challenges,
                    updatedAt: Date()
                )

                completedBatches += 1
                let ranked = deduplicateAndRank(collected, anchor: baseRequest.date)

                if ranked.count >= desired || (ranked.count >= comfortTarget && completedBatches >= 2) {
                    break searchLoop
                }
            }
        }

        let final = Array(deduplicateAndRank(collected, anchor: baseRequest.date).prefix(12))
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

        guard !final.isEmpty else {
            if let challenge = challenges.first { FlightBotChallengeCenter.shared.publish(challenge) }
            throw OrchestratorError.noVerifiedResults(
                blockedProviders: Array(Set(challenges.map(\.providerName))).sorted()
            )
        }

        return SearchResult(candidates: final, summary: summary, blockedChallenges: challenges)
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

    private func deduplicateAndRank(_ candidates: [LiveFlightCandidate], anchor: Date) -> [LiveFlightCandidate] {
        var unique: [String: LiveFlightCandidate] = [:]
        for candidate in candidates {
            if let existing = unique[candidate.deduplicationKey] {
                unique[candidate.deduplicationKey] = preferredSource(candidate, over: existing) ? candidate : existing
            } else {
                unique[candidate.deduplicationKey] = candidate
            }
        }

        return unique.values.sorted { lhs, rhs in
            let leftDay = abs(Calendar.current.startOfDay(for: lhs.departureAt).timeIntervalSince(Calendar.current.startOfDay(for: anchor)))
            let rightDay = abs(Calendar.current.startOfDay(for: rhs.departureAt).timeIntervalSince(Calendar.current.startOfDay(for: anchor)))
            if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            if leftDay != rightDay { return leftDay < rightDay }
            if lhs.observedCurrency == rhs.observedCurrency && lhs.observedFare != rhs.observedFare {
                return lhs.observedFare < rhs.observedFare
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
