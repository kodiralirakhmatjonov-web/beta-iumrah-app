import Foundation

enum FlightDatePlanner {
    static func dates(anchor: Date, flexibility: DateFlexibility, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: anchor)
        switch flexibility {
        case .exact:
            return [start]
        case .plusMinusOne, .plusMinusTwo:
            // Weekly discovery keeps the chosen date as the first attempt for
            // perceived performance, then covers the entire seven-day window.
            // The unified flight provider is queried with real dates under the hood,
            // while the product contract remains "find which days this week fly".
            return [0, -1, 1, -2, 2, -3, 3].compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .weekend:
            // Weekend dates are normalized at TripDraft level to Friday → Monday.
            // Do not fan the flight search out to neighbouring weekends.
            return [start]
        }
    }
}
