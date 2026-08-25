import SwiftUI
import UIKit

enum IumrahDesign {
    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 28
    static let compactRadius: CGFloat = 20
    static let controlHeight: CGFloat = 54
}

private extension UIColor {
    static let iumrahPage = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.075, green: 0.082, blue: 0.094, alpha: 1)
        }
        return .systemGroupedBackground
    }

    static let iumrahCard = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.115, green: 0.125, blue: 0.142, alpha: 1)
        }
        return .systemBackground
    }

    static let iumrahRaised = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.145, green: 0.158, blue: 0.178, alpha: 1)
        }
        return .secondarySystemGroupedBackground
    }

    static let iumrahPrimaryButton = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.93, alpha: 1)
            : UIColor.black
    }

    static let iumrahPrimaryButtonText = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.065, blue: 0.075, alpha: 1)
            : UIColor.white
    }
}

extension Color {
    static let iumrahPageBackground = Color(uiColor: .iumrahPage)
    static let iumrahCardBackground = Color(uiColor: .iumrahCard)
    static let iumrahRaisedBackground = Color(uiColor: .iumrahRaised)
    static let iumrahPrimaryButtonBackground = Color(uiColor: .iumrahPrimaryButton)
    static let iumrahPrimaryButtonText = Color(uiColor: .iumrahPrimaryButtonText)
}

struct IumrahCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Color.iumrahCardBackground)
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
            .foregroundStyle(Color.iumrahPrimaryButtonText)
            .background(Color.iumrahPrimaryButtonBackground.opacity(configuration.isPressed ? 0.82 : 1))
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
            .background(Color.iumrahRaisedBackground.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IumrahDesign.compactRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
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
}
