import SwiftUI

@main
struct IumrahBetaApp: App {
    @UIApplicationDelegateAdaptor(IumrahAppDelegate.self) private var appDelegate
    @StateObject private var journey = JourneyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(journey)
        }
    }
}
