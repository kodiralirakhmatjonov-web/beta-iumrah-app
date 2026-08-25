import SwiftUI

@main
struct IumrahBetaApp: App {
    @UIApplicationDelegateAdaptor(IumrahAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
