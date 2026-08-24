import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            TripBuilderView()
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(.primary)
    }
}
