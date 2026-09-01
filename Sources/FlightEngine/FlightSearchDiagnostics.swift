import Foundation

enum FlightSearchExecutionLocation: String, Hashable {
    case server
    case device
}

enum FlightProviderSearchOutcome: Hashable {
    case searching
    case verified(Int)
    case verificationRequired
    /// The official source was reached, but no candidate could be promoted through
    /// the strict flight contract. This deliberately does NOT mean "no flight exists".
    case notConfirmed
    /// The source could not be completed in this attempt (timeout, changed page,
    /// connection failure, or other provider-level interruption).
    case unavailable
}

struct FlightProviderSearchEvent: Identifiable, Hashable {
    let providerID: FlightBotProviderID
    let providerName: String
    let execution: FlightSearchExecutionLocation
    let date: Date
    let outcome: FlightProviderSearchOutcome
    let observedAt: Date

    init(
        providerID: FlightBotProviderID,
        providerName: String,
        execution: FlightSearchExecutionLocation,
        date: Date,
        outcome: FlightProviderSearchOutcome,
        observedAt: Date = Date()
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.execution = execution
        self.date = date
        self.outcome = outcome
        self.observedAt = observedAt
    }

    var id: String {
        let day = Calendar(identifier: .gregorian).startOfDay(for: date).timeIntervalSince1970
        return "\(providerID.rawValue)|\(execution.rawValue)|\(Int(day))|\(outcomeKey)|\(observedAt.timeIntervalSince1970)"
    }

    var attemptKey: String {
        let day = Calendar(identifier: .gregorian).startOfDay(for: date).timeIntervalSince1970
        return "\(providerID.rawValue)|\(execution.rawValue)|\(Int(day))"
    }

    private var outcomeKey: String {
        switch outcome {
        case .searching: return "searching"
        case .verified(let count): return "verified-\(count)"
        case .verificationRequired: return "verification"
        case .notConfirmed: return "not-confirmed"
        case .unavailable: return "unavailable"
        }
    }
}

struct FlightProviderSearchReport: Identifiable, Hashable {
    let providerID: FlightBotProviderID
    let providerName: String
    let attemptedDates: [Date]
    let executions: Set<FlightSearchExecutionLocation>
    let verifiedCount: Int
    let hasVerificationRequired: Bool
    let hasNotConfirmed: Bool
    let hasUnavailable: Bool
    let isSearching: Bool

    var id: FlightBotProviderID { providerID }
}

enum FlightSearchDiagnostics {
    static func merge(
        _ existing: [FlightProviderSearchEvent],
        _ incoming: [FlightProviderSearchEvent]
    ) -> [FlightProviderSearchEvent] {
        var latest = Dictionary(uniqueKeysWithValues: existing.map { ($0.attemptKey, $0) })
        for event in incoming {
            if let current = latest[event.attemptKey], current.observedAt > event.observedAt { continue }
            latest[event.attemptKey] = event
        }
        return latest.values.sorted { lhs, rhs in
            if lhs.providerID != rhs.providerID {
                return providerPriority(lhs.providerID) < providerPriority(rhs.providerID)
            }
            return lhs.date < rhs.date
        }
    }

    static func reports(from events: [FlightProviderSearchEvent]) -> [FlightProviderSearchReport] {
        let grouped = Dictionary(grouping: events, by: \.providerID)
        return grouped.compactMap { providerID, values -> FlightProviderSearchReport? in
            guard let first = values.first else { return nil }
            let dates = Array(Set(values.map { Calendar.current.startOfDay(for: $0.date) })).sorted()
            var verifiedCount = 0
            var verification = false
            var notConfirmed = false
            var unavailable = false
            var searching = false
            for event in values {
                switch event.outcome {
                case .searching: searching = true
                case .verified(let count): verifiedCount += count
                case .verificationRequired: verification = true
                case .notConfirmed: notConfirmed = true
                case .unavailable: unavailable = true
                }
            }
            // A completed outcome for every attempt supersedes stale "searching"
            // events because merge() keeps only the latest event per attempt key.
            searching = values.contains { if case .searching = $0.outcome { return true }; return false }
            return FlightProviderSearchReport(
                providerID: providerID,
                providerName: first.providerName,
                attemptedDates: dates,
                executions: Set(values.map(\.execution)),
                verifiedCount: verifiedCount,
                hasVerificationRequired: verification,
                hasNotConfirmed: notConfirmed,
                hasUnavailable: unavailable,
                isSearching: searching
            )
        }.sorted { providerPriority($0.providerID) < providerPriority($1.providerID) }
    }

    private static func providerPriority(_ id: FlightBotProviderID) -> Int {
        FlightBotProviderRegistry.providers.first(where: { $0.id == id })?.priority ?? 999
    }
}
