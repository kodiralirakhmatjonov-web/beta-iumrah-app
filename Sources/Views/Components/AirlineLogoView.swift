import SwiftUI

struct AirlineLogoView: View {
    let airlineCode: String?
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.white)
            if let url = FlightReferenceCatalog.airline(code: airlineCode)?.logoURL {
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

    private var fallback: some View {
        Text(airlineCode?.uppercased() ?? "✈")
            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary)
            .minimumScaleFactor(0.6)
    }
}
