import Foundation

struct TripStayBreakdown: Hashable {
    let totalNights: Int
    let totalDays: Int
    let makkahNights: Int
    let madinahNights: Int
}

enum TripStayPlanner {
    static func breakdown(for trip: TripDraft, calendar: Calendar = .current) -> TripStayBreakdown {
        let start = calendar.startOfDay(for: trip.departureDate)
        let end = calendar.startOfDay(for: trip.returnDate)
        let rawNights = calendar.dateComponents([.day], from: start, to: end).day ?? 1
        let totalNights = max(1, rawNights)
        let totalDays = totalNights + 1

        guard trip.scope == .makkahAndMadinah, totalNights > 1 else {
            return TripStayBreakdown(totalNights: totalNights, totalDays: totalDays, makkahNights: totalNights, madinahNights: 0)
        }

        let makkah = max(1, min(totalNights - 1, Int(ceil(Double(totalNights) * 0.6))))
        let madinah = max(1, totalNights - makkah)
        return TripStayBreakdown(totalNights: totalNights, totalDays: totalDays, makkahNights: makkah, madinahNights: madinah)
    }
}
