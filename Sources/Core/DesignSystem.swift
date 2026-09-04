import SwiftUI
import UIKit

enum IumrahDesign {
    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 30
    static let heroRadius: CGFloat = 34
    static let compactRadius: CGFloat = 20
    static let controlHeight: CGFloat = 56
}

private extension UIColor {
    static let iumrahPage = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.105, green: 0.112, blue: 0.126, alpha: 1)
        }
        return UIColor(red: 0.965, green: 0.968, blue: 0.974, alpha: 1)
    }

    static let iumrahCard = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.145, green: 0.154, blue: 0.172, alpha: 1)
        }
        return .systemBackground
    }

    static let iumrahRaised = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.185, green: 0.196, blue: 0.216, alpha: 1)
        }
        return UIColor(red: 0.925, green: 0.934, blue: 0.949, alpha: 1)
    }

    static let iumrahPrimaryButton = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.96, alpha: 1)
            : UIColor.black
    }

    static let iumrahPrimaryButtonText = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.075, blue: 0.085, alpha: 1)
            : UIColor.white
    }

    static let iumrahCareDark = UIColor(red: 14/255, green: 36/255, blue: 34/255, alpha: 1)
    static let iumrahCareLight = UIColor(red: 116/255, green: 161/255, blue: 135/255, alpha: 1)
}

extension Color {
    static let iumrahPageBackground = Color(uiColor: .iumrahPage)
    static let iumrahCardBackground = Color(uiColor: .iumrahCard)
    static let iumrahRaisedBackground = Color(uiColor: .iumrahRaised)
    static let iumrahPrimaryButtonBackground = Color(uiColor: .iumrahPrimaryButton)
    static let iumrahPrimaryButtonText = Color(uiColor: .iumrahPrimaryButtonText)
    static let iumrahGraphite = Color(red: 0.09, green: 0.10, blue: 0.115)
    static let iumrahCareDark = Color(uiColor: .iumrahCareDark)
    static let iumrahCareLight = Color(uiColor: .iumrahCareLight)
}

struct IumrahCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.055), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.055), radius: 22, y: 10)
    }
}

struct IumrahMarketingCardModifier: ViewModifier {
    var dark: Bool

    func body(content: Content) -> some View {
        content
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                    .fill(
                        dark
                        ? LinearGradient(colors: [Color.iumrahCareDark, Color.iumrahGraphite], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.iumrahCardBackground, Color.iumrahCardBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.heroRadius, style: .continuous)
                    .strokeBorder(dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.055), lineWidth: 1)
            }
            .shadow(color: .black.opacity(dark ? 0.16 : 0.055), radius: 26, y: 12)
    }
}

extension View {
    func iumrahCard() -> some View { modifier(IumrahCardModifier()) }
    func iumrahMarketingCard(dark: Bool = false) -> some View { modifier(IumrahMarketingCardModifier(dark: dark)) }
}

struct IumrahPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .foregroundStyle(Color.iumrahPrimaryButtonText)
            .background(Color.iumrahPrimaryButtonBackground.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 12, y: 7)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

struct IumrahSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .foregroundStyle(.primary)
            .background(Color.iumrahRaisedBackground.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

enum IumrahHaptics {
    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

private struct IumrahGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26: use Apple's native Liquid Glass renderer. Interactive
            // controls opt into the system scale/bounce/shimmer response.
            if interactive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            // Functional compatibility for iOS 17–25. This is deliberately a
            // normal opaque system surface, not a simulated Liquid Glass blur.
            content
                .background(Color.iumrahCardBackground, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.8))
        }
    }
}

extension View {
    func iumrahGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(IumrahGlassModifier(shape: shape, interactive: interactive))
    }
}

/// Groups nearby native Liquid Glass elements so iOS 26 can sample and morph
/// them as one visual system. Older iOS versions simply render the content.
struct IumrahGlassGroup<Content: View>: View {
    let spacing: CGFloat?
    private let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}
