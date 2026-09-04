import SwiftUI

/// Chat-local Liquid Glass bridge.
/// On iOS 26 this uses Apple's native Liquid Glass APIs and glass button styles.
/// Earlier OS versions keep a restrained Material fallback without changing chat logic.
struct CareNativeGlassContainer<Content: View>: View {
    let spacing: CGFloat?
    let content: () -> Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

private struct CareNativeGlassButtonModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            content.buttonStyle(CareLegacyGlassButtonStyle(prominent: prominent))
        }
    }
}

private struct CareNativeGlassSurfaceModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let glass = Glass.regular
                .interactive(interactive)
                .tint(tint)
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background(Color.iumrahCardBackground, in: shape)
                .overlay {
                    shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.65)
                }
        }
    }
}

private struct CareLegacyGlassButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if prominent {
                    Capsule().fill(Color.iumrahCareDark.opacity(0.96))
                } else {
                    Capsule().fill(Color.iumrahCardBackground)
                }
            }
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(prominent ? 0.16 : 0.30), lineWidth: 0.65)
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.80), value: configuration.isPressed)
    }
}

extension View {
    func careNativeGlassButton(prominent: Bool = false) -> some View {
        modifier(CareNativeGlassButtonModifier(prominent: prominent))
    }

    func careNativeGlassSurface<S: Shape>(
        in shape: S,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        modifier(CareNativeGlassSurfaceModifier(shape: shape, interactive: interactive, tint: tint))
    }
}
