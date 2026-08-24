import SwiftUI

enum IumrahDesign {
    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 28
    static let compactRadius: CGFloat = 20
    static let controlHeight: CGFloat = 54
}

struct IumrahCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.cardRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}

extension View {
    func iumrahCard() -> some View { modifier(IumrahCardModifier()) }
}

struct IumrahPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .foregroundStyle(.white)
            .background(.black.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}

struct IumrahSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: IumrahDesign.controlHeight)
            .foregroundStyle(.primary)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.86), value: configuration.isPressed)
    }
}
