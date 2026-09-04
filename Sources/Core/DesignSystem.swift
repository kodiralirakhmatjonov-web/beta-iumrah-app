import SwiftUI
import UIKit

enum IumrahDesign {
    // Keep the same compact geometry discipline as the AutoSale Umar reference:
    // system surfaces, rounded continuous corners and restrained spacing.
    static let pagePadding: CGFloat = 18
    static let cardRadius: CGFloat = 28
    static let heroRadius: CGFloat = 34
    static let compactRadius: CGFloat = 19
    static let controlHeight: CGFloat = 56
    static let glassIconSize: CGFloat = 46
}

private extension UIColor {
    static let iumrahPage = UIColor { _ in
        .systemBackground
    }

    static let iumrahCard = UIColor { _ in
        .secondarySystemGroupedBackground
    }

    static let iumrahRaised = UIColor { _ in
        .tertiarySystemGroupedBackground
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
                    .strokeBorder(Color.primary.opacity(0.075), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(0.045), radius: 18, y: 8)
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
                    .strokeBorder(dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.075), lineWidth: 0.7)
            }
            .shadow(color: .black.opacity(dark ? 0.14 : 0.045), radius: 20, y: 9)
    }
}

extension View {
    func iumrahCard() -> some View { modifier(IumrahCardModifier()) }
    func iumrahMarketingCard(dark: Bool = false) -> some View { modifier(IumrahMarketingCardModifier(dark: dark)) }
}

/// Primary call-to-action follows the AutoSale Umar reference: a crisp system
/// primary surface. Liquid Glass is reserved for floating / secondary controls.
struct IumrahPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .foregroundStyle(Color.iumrahPrimaryButtonText)
            .background(
                Color.iumrahPrimaryButtonBackground.opacity(configuration.isPressed ? 0.84 : 1),
                in: RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct IumrahSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .foregroundStyle(.primary)
            .iumrahGlass(
                in: RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous),
                interactive: true
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Apple's native Liquid Glass renderer. Interactive controls opt into
            // the system response rather than recreating blur/highlight effects.
            if let tint {
                content.glassEffect(.regular.interactive(interactive).tint(tint), in: shape)
            } else {
                content.glassEffect(.regular.interactive(interactive), in: shape)
            }
        } else {
            // Compatibility only. Do not imitate Liquid Glass with Material/blur.
            content
                .background(tint ?? Color.iumrahCardBackground, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.7))
        }
    }
}

extension View {
    func iumrahGlass<S: Shape>(
        in shape: S,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        modifier(IumrahGlassModifier(shape: shape, interactive: interactive, tint: tint))
    }
}

/// Canonical floating icon control used throughout the app.
/// Its iOS 26 appearance is entirely provided by Apple's Liquid Glass API.
struct IumrahGlassIconButton: View {
    let systemName: String
    var size: CGFloat = IumrahDesign.glassIconSize
    var fontSize: CGFloat = 17
    var foreground: Color? = nil
    var tint: Color? = nil
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(foreground ?? Color.primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .iumrahGlass(in: Circle(), interactive: true, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? systemName)
    }
}

/// Canonical glass surface for compact floating information and controls.
struct IumrahGlassSurface<Content: View>: View {
    var radius: CGFloat = 22
    var interactive = false
    var tint: Color? = nil
    private let content: Content

    init(
        radius: CGFloat = 22,
        interactive: Bool = false,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.radius = radius
        self.interactive = interactive
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content.iumrahGlass(
            in: RoundedRectangle(cornerRadius: radius, style: .continuous),
            interactive: interactive,
            tint: tint
        )
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
