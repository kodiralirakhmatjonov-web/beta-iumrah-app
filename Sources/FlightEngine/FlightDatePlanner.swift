import Foundation

enum FlightDatePlanner {
    static func dates(anchor: Date, flexibility: DateFlexibility, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: anchor)
        switch flexibility {
        case .exact:
            return [start]
        case .plusMinusOne:
            return [0, -1, 1].compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .plusMinusTwo:
            return [0, -1, 1, -2, 2].compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .weekend:
            return weekendDates(around: start, calendar: calendar)
        }
    }

    private static func weekendDates(around anchor: Date, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        for offset in -3...4 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: anchor) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 7 || weekday == 1 { result.append(date) }
        }
        return Array(result.sorted { abs($0.timeIntervalSince(anchor)) < abs($1.timeIntervalSince(anchor)) }.prefix(4))
    }
}
