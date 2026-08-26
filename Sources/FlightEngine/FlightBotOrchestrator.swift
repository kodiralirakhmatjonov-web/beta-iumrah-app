import Foundation

@MainActor
final class FlightBotOrchestrator {
    struct SearchResult {
        let candidates: [LiveFlightCandidate]
        let summary: FlightBotSearchSummary
        let blockedChallenges: [FlightBotChallenge]
    }

    enum OrchestratorError: LocalizedError {
        case insufficientResults(found: Int, minimum: Int, blockedProviders: [String])

        var errorDescription: String? {
            switch self {
            case .insufficientResults(let found, let minimum, let blocked):
                let blockedText = blocked.isEmpty ? "" : " Требуется проверка: \(blocked.joined(separator: ", "))."
                return "Flight Engine нашёл \(found) подтверждённых вариантов; нужно минимум \(minimum).\(blockedText)"
            }
        }
    }

    private enum ProviderAttempt {
        case candidates([LiveFlightCandidate])
        case challenge(FlightBotChallenge)
        case failed
    }

    static let shared = FlightBotOrchestrator()

    let minimumTarget = AppConfig.flightBotMinimumOptions
    let preferredTarget = AppConfig.flightBotPreferredOptions

    private init() {}

    func search(
        request baseRequest: FlightBotSearchRequest,
        flexibility: DateFlexibility,
        minimumResults: Int? = nil,
        preferredResults: Int? = nil
    ) async throws -> SearchResult {
        let requiredMinimum = max(1, minimumResults ?? minimumTarget)
        let desired = max(requiredMinimum, preferredResults ?? preferredTarget)
        let searchID = UUID().uuidString
        let requestedAt = Date()
        let deadline = requestedAt.addingTimeInterval(AppConfig.flightBotSearchHardTimeoutSeconds)
        let dates = FlightDatePlanner.dates(anchor: baseRequest.date, flexibility: flexibility)
        let providers = FlightBotProviderRegistry.ordered(for: baseRequest.origin, destination: baseRequest.destination)

        var collected: [LiveFlightCandidate] = []
        var challenges: [FlightBotChallenge] = []
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
                let batch = Array(providers[batchStart..<batchEnd])
                started += batch.count

                let tasks: [Task<ProviderAttempt, Never>] = batch.map { provider in
                    Task { @MainActor in
                        do {
                            let remaining = max(3, deadline.timeIntervalSinceNow)
                            let providerBudget = min(AppConfig.flightBotProviderTimeoutSeconds, remaining)
                            let results = try await FlightBotRunner(provider: provider, request: request)
                                .run(timeoutSeconds: providerBudget)
                            return ProviderAttempt.candidates(results)
                        } catch FlightBotRunner.BotError.challengeRequired(let challenge) {
                            return ProviderAttempt.challenge(challenge)
                        } catch {
                            return ProviderAttempt.failed
                        }
                    }
                }

                for task in tasks {
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

                completedBatches += 1
                let ranked = deduplicateAndRank(collected, anchor: baseRequest.date)

                // Never keep a pilgrim staring at a spinner just to move from 4–5
                // good live options to 6. Once the minimum is reached after at least
                // two provider batches, return immediately. If a single first batch
                // already produced the preferred target, return even sooner.
                if ranked.count >= desired || (ranked.count >= requiredMinimum && completedBatches >= 2) {
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
            minimumTarget: requiredMinimum,
            preferredTarget: desired
        )

        guard final.count >= requiredMinimum else {
            if let challenge = challenges.first {
                FlightBotChallengeCenter.shared.publish(challenge)
            }
            throw OrchestratorError.insufficientResults(
                found: final.count,
                minimum: requiredMinimum,
                blockedProviders: Array(Set(challenges.map(\.providerName))).sorted()
            )
        }

        return SearchResult(candidates: final, summary: summary, blockedChallenges: challenges)
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
