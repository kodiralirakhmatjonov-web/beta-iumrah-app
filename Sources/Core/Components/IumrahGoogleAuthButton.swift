import SwiftUI
import UIKit

/// iumrah presentation wrapper for Google authentication.
///
/// The action still runs through the official GoogleSignIn SDK. The multicolor
/// Google mark is loaded from the SDK's own signed resource bundle, while iumrah
/// owns only the surrounding SwiftUI surface so Google and Apple have the same
/// 56pt production control geometry.
struct IumrahGoogleAuthButton: View {
    let title: String
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                IumrahGoogleMark()
                    .frame(width: 23, height: 23)

                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.20), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.055), radius: 2, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
        }
        .buttonStyle(IumrahGoogleAuthPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.46 : 1)
        .accessibilityLabel(title)
    }
}

private struct IumrahGoogleAuthPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct IumrahGoogleMark: View {
    var body: some View {
        Group {
            if let image = IumrahGoogleBrandAsset.image {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                // This should never be used in production: GoogleSignIn ships
                // google.png in its resource bundle. Keep a harmless fallback so
                // a missing package resource cannot crash the account screen.
                Text("G")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.blue)
            }
        }
        .accessibilityHidden(true)
    }
}

private enum IumrahGoogleBrandAsset {
    static let image: UIImage? = {
        var bundles: [Bundle] = [Bundle.main]
        let nested = Bundle.main.urls(forResourcesWithExtension: "bundle", subdirectory: nil) ?? []
        bundles.append(contentsOf: nested.compactMap(Bundle.init(url:)))

        for bundle in bundles {
            if let url = bundle.url(forResource: "google", withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }()
}
