import SwiftUI

struct UmrahAnimatedText: View {
    let text: String
    var font: Font
    var foreground: Color = .white
    var alignment: TextAlignment = .leading
    var lineSpacing: CGFloat = 4
    var isArabic = false

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
                .transition(
                    .asymmetric(
                        insertion: .opacity
                            .combined(with: .move(edge: .bottom))
                            .combined(with: .scale(scale: 0.985)),
                        removal: .opacity
                            .combined(with: .move(edge: .top))
                            .combined(with: .scale(scale: 0.992))
                    )
                )
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.88), value: text)
    }
}

private struct UmrahEntranceMotion: ViewModifier {
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .scaleEffect(appeared ? 1 : 0.992)
            .onAppear {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.90).delay(0.03)) {
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
