# iumrah Ziyarats Native iOS 26 v7

Client-only correction.

- Removes the custom draggable Ziyarats drawer.
- Removes the standalone `UITabBar` / `UIViewRepresentable` implementation.
- Uses a system SwiftUI `.sheet` with native `presentationDetents` and native drag physics.
- Uses a real SwiftUI `TabView`/`Tab`, allowing iOS 26 to own the tab bar and Liquid Glass appearance.
- Keeps native `.buttonStyle(.glass)` / `.glassProminent` only for explicit iOS 26 controls.
- No custom `Material`, `UIBlurEffect`, painted blur background, or custom spring is used for the sheet/tab bar.
