import SwiftUI

@main
struct IumrahBetaApp: App {
    @StateObject private var journey = JourneyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(journey)
        }
    }
}
