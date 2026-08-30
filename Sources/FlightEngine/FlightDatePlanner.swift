import Foundation

enum FlightDatePlanner {
    static func dates(anchor: Date, flexibility: DateFlexibility, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: anchor)
        switch flexibility {
        case .exact:
            return [start]
        case .plusMinusOne, .plusMinusTwo:
            // One product choice covers both ±1 and ±2 days. Keep the selected
            // day first, then progressively expand so the user sees useful nearby
            // alternatives without losing the original date.
            return [0, -1, 1, -2, 2].compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .weekend:
            // Weekend dates are normalized at TripDraft level to Friday → Monday.
            // Do not fan the flight search out to neighbouring weekends.
            return [start]
        }
    }
}
