import SwiftUI

/// Airline mark used by verified flight results and curated direct-flight cards.
/// Google Flights' public carrier image endpoint is also used by iumrah Business;
/// a strict two-character IATA check and local code fallback keep the card usable
/// when a logo is unavailable.
struct AirlineLogoView: View {
    let airlineCode: String?
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.white)

            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.14)
                    } else {
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
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.7)
        }
        .accessibilityHidden(true)
    }

    private var verifiedCode: String? {
        guard let airlineCode else { return nil }
        let code = airlineCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.range(of: "^[A-Z0-9]{2}$", options: .regularExpression) != nil else { return nil }
        return code
    }

    private var logoURL: URL? {
        guard let verifiedCode else { return nil }
        return URL(string: "https://www.gstatic.com/flights/airline_logos/70px/\(verifiedCode).png")
    }

    private var fallback: some View {
        Group {
            if let verifiedCode {
                Text(verifiedCode)
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
            } else {
                Image(systemName: "airplane")
                    .font(.system(size: size * 0.30, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
