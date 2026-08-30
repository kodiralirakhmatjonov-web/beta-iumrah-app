import SwiftUI

struct AirlineLogoView: View {
    let airlineCode: String?
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.white)
            if let url = logoURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.14)
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.7)
        }
        .accessibilityHidden(true)
    }

    private var logoURL: URL? {
        if let known = FlightReferenceCatalog.airline(code: airlineCode)?.logoURL { return known }
        guard let code = airlineCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              code.range(of: "^[A-Z0-9]{2}$", options: .regularExpression) != nil else { return nil }
        return URL(string: "https://www.gstatic.com/flights/airline_logos/70px/\(code).png")
    }

    private var fallback: some View {
        Text(airlineCode?.uppercased() ?? "✈")
            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary)
            .minimumScaleFactor(0.6)
    }
}
