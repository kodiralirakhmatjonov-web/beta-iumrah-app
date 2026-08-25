import SwiftUI

struct IumrahHeaderLogo: View {
    @Environment(\.colorScheme) private var colorScheme
    var width: CGFloat = 112

    var body: some View {
        Image(colorScheme == .dark ? "HeaderWordmarkDark" : "HeaderWordmarkLight")
            .resizable()
            .scaledToFit()
            .frame(width: width, height: 30, alignment: .leading)
            .accessibilityLabel("iumrah Project")
    }
}
