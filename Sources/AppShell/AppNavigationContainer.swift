import SwiftUI

struct AppNavigationContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .background(Color.iumrahPageBackground.ignoresSafeArea())
        }
    }
}
