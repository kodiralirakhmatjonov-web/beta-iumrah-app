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
                return "Flight Engine нашёл \(found) подтверждённых вариантов; для beta нужно минимум \(minimum).\(blockedText)"
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

    func search(request baseRequest: FlightBotSearchRequest, flexibility: DateFlexibility) async throws -> SearchResult {
        FlightBotChallengeCenter.shared.clear()

        let searchID = UUID().uuidString
        let requestedAt = Date()
        let dates = FlightDatePlanner.dates(anchor: baseRequest.date, flexibility: flexibility)
        let providers = FlightBotProviderRegistry.ordered(for: baseRequest.origin)

        var collected: [LiveFlightCandidate] = []
        var challenges: [FlightBotChallenge] = []
        var succeeded = 0
        var started = 0

        for date in dates {
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
                let batchEnd = min(providers.count, batchStart + AppConfig.flightBotProviderBatchSize)
                let batch = Array(providers[batchStart..<batchEnd])
                started += batch.count

                let tasks: [(FlightBotProvider, Task<ProviderAttempt, Never>)] = batch.map { provider in
                    let task = Task { @MainActor in
                        do {
                            let results = try await FlightBotRunner(provider: provider, request: request)
                                .run(timeoutSeconds: AppConfig.flightBotProviderTimeoutSeconds)
                            return ProviderAttempt.candidates(results)
                        } catch FlightBotRunner.BotError.challengeRequired(let challenge) {
                            return ProviderAttempt.challenge(challenge)
                        } catch {
                            return ProviderAttempt.failed
                        }
                    }
                    return (provider, task)
                }

                for (_, task) in tasks {
                    switch await task.value {
                    case .candidates(let results):
                        succeeded += 1
                        collected.append(contentsOf: results)
                    case .challenge(let challenge):
                        challenges.append(challenge)
                    case .failed:
                        break
                    }
                }

                if deduplicateAndRank(collected, anchor: baseRequest.date).count >= preferredTarget {
                    break
                }
            }

            if deduplicateAndRank(collected, anchor: baseRequest.date).count >= preferredTarget {
                break
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
            minimumTarget: minimumTarget,
            preferredTarget: preferredTarget
        )

        guard final.count >= minimumTarget else {
            if let challenge = challenges.first {
                FlightBotChallengeCenter.shared.publish(challenge)
            }
            throw OrchestratorError.insufficientResults(
                found: final.count,
                minimum: minimumTarget,
                blockedProviders: challenges.map(\.providerName)
            )
        }

        FlightBotChallengeCenter.shared.clear()
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
            let leftDay = abs(lhs.departureAt.timeIntervalSince(anchor))
            let rightDay = abs(rhs.departureAt.timeIntervalSince(anchor))
            if lhs.stops != rhs.stops { return lhs.stops < rhs.stops }
            if leftDay != rightDay { return leftDay < rightDay }
            if lhs.observedCurrency == rhs.observedCurrency && lhs.observedFare != rhs.observedFare {
                return lhs.observedFare < rhs.observedFare
            }
            return providerPriority(lhs.providerID) < providerPriority(rhs.providerID)
        }
    }

    private func preferredSource(_ lhs: LiveFlightCandidate, over rhs: LiveFlightCandidate) -> Bool {
        if lhs.observedCurrency == rhs.observedCurrency && lhs.observedFare != rhs.observedFare {
            return lhs.observedFare < rhs.observedFare
        }
        return providerPriority(lhs.providerID) < providerPriority(rhs.providerID)
    }

    private func providerPriority(_ id: FlightBotProviderID) -> Int {
        FlightBotProviderRegistry.providers.first(where: { $0.id == id })?.priority ?? 999
    }
}
