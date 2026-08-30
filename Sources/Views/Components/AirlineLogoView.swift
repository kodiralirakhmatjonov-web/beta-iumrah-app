import SwiftUI

/// Temporary production-safe carrier mark. Remote logo CDNs are deliberately
/// disabled until the curated airline assets are shipped inside the app bundle.
/// This prevents an incorrect third-party logo from ever being shown next to a
/// verified flight number.
struct AirlineLogoView: View {
    let airlineCode: String?
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.iumrahRaisedBackground)

            if let code = verifiedCode {
                Text(code)
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
            } else {
                Image(systemName: "airplane")
                    .font(.system(size: size * 0.30, weight: .semibold))
                    .foregroundStyle(.secondary)
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
        guard let airlineCode,
              FlightReferenceCatalog.airline(code: airlineCode) != nil else { return nil }
        return airlineCode.uppercased()
    }
}
