import SwiftUI

private struct UmrahTextPhaseModifier: ViewModifier {
    let opacity: Double
    let blur: CGFloat
    let y: CGFloat
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
            .offset(y: y)
            .scaleEffect(scale)
    }
}

private extension AnyTransition {
    static var umrahTextChange: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: UmrahTextPhaseModifier(opacity: 0, blur: 7, y: 9, scale: 0.992),
                identity: UmrahTextPhaseModifier(opacity: 1, blur: 0, y: 0, scale: 1)
            ),
            removal: .modifier(
                active: UmrahTextPhaseModifier(opacity: 0, blur: 5, y: -7, scale: 0.996),
                identity: UmrahTextPhaseModifier(opacity: 1, blur: 0, y: 0, scale: 1)
            )
        )
    }
}

struct UmrahAnimatedText: View {
    let text: String
    var font: Font
    var foreground: Color = .primary
    var alignment: TextAlignment = .leading
    var lineSpacing: CGFloat = 4
    var isArabic = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: alignment == .center ? .center : .leading) {
            Text(text)
                .font(font)
                .foregroundStyle(foreground)
                .multilineTextAlignment(alignment)
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
                .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
                .fixedSize(horizontal: false, vertical: true)
                .id(text)
                .transition(reduceMotion ? .opacity : .umrahTextChange)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.22) : .smooth(duration: 0.46, extraBounce: 0), value: text)
    }
}

private struct UmrahEntranceMotion: ViewModifier {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .blur(radius: appeared || reduceMotion ? 0 : 5)
            .offset(y: appeared || reduceMotion ? 0 : 8)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.994)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .smooth(duration: 0.48, extraBounce: 0)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func umrahEntranceMotion() -> some View {
        modifier(UmrahEntranceMotion())
    }
}
