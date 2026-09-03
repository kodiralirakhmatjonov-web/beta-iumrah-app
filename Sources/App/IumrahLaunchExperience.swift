import SwiftUI

/// A short native hand-off between iOS' static launch screen and the live app.
///
/// The first rendered frame intentionally matches `UILaunchScreen` exactly:
/// adaptive launch background + centered `LaunchWordmark`. This prevents the
/// dark/blank flash that can otherwise appear while SwiftUI creates RootView.
struct IumrahLaunchExperience<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let content: Content

    @State private var splashVisible = true
    @State private var wordmarkScale: CGFloat = 1
    @State private var wordmarkOffset: CGFloat = 0
    @State private var wordmarkBlur: CGFloat = 0
    @State private var wordmarkOpacity: Double = 1
    @State private var sheenProgress: CGFloat = -1.15
    @State private var haloScale: CGFloat = 0.72
    @State private var haloOpacity: Double = 0
    @State private var backgroundOpacity: Double = 1
    @State private var contentScale: CGFloat = 1.008
    @State private var contentOpacity: Double = 0.985
    @State private var hasStarted = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .scaleEffect(contentScale)
                .opacity(contentOpacity)
                .allowsHitTesting(!splashVisible)

            if splashVisible {
                splashLayer
                    .zIndex(1000)
                    .transition(.identity)
            }
        }
        .background(Color("LaunchBackground"))
        .task {
            await runLaunchSequenceIfNeeded()
        }
    }

    private var splashLayer: some View {
        ZStack {
            Color("LaunchBackground")
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.primary.opacity(0.055),
                            Color.primary.opacity(0.018),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 122
                    )
                )
                .frame(width: 244, height: 244)
                .scaleEffect(haloScale)
                .opacity(haloOpacity)
                .blur(radius: 10)
                .accessibilityHidden(true)

            launchWordmark
                .frame(width: 220, height: 90)
                .scaleEffect(wordmarkScale)
                .offset(y: wordmarkOffset)
                .blur(radius: wordmarkBlur)
                .opacity(wordmarkOpacity)
                .accessibilityHidden(true)
        }
        .compositingGroup()
    }

    private var launchWordmark: some View {
        ZStack {
            Image("LaunchWordmark")
                .resizable()
                .scaledToFit()

            GeometryReader { proxy in
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: sheenColor.opacity(0.02), location: 0.36),
                        .init(color: sheenColor.opacity(0.22), location: 0.49),
                        .init(color: sheenColor.opacity(0.04), location: 0.61),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 72, height: proxy.size.height * 1.55)
                .rotationEffect(.degrees(17))
                .offset(x: sheenProgress * (proxy.size.width + 100))
            }
            .mask {
                Image("LaunchWordmark")
                    .resizable()
                    .scaledToFit()
            }
            .allowsHitTesting(false)
        }
    }

    private var sheenColor: Color {
        colorScheme == .dark ? .black : .white
    }

    @MainActor
    private func runLaunchSequenceIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }
            IumrahHaptics.soft()

            withAnimation(.easeOut(duration: 0.22)) {
                wordmarkOpacity = 0
                backgroundOpacity = 0
                contentOpacity = 1
                contentScale = 1
            }

            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled else { return }
            splashVisible = false
            return
        }

        // Frame zero matches the system launch screen. The first movement is
        // deliberately tiny so the launch feels like iOS itself coming alive.
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.86, blendDuration: 0.08)) {
            wordmarkScale = 1.018
            haloScale = 1
            haloOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(210))
        guard !Task.isCancelled else { return }
        IumrahHaptics.soft()

        withAnimation(.easeInOut(duration: 0.54)) {
            sheenProgress = 1.18
            wordmarkScale = 1
            haloScale = 1.15
            haloOpacity = 0.36
        }

        try? await Task.sleep(for: .milliseconds(430))
        guard !Task.isCancelled else { return }

        // Reveal RootView through the splash rather than swapping screens.
        // This removes the visual seam between launch experience and app UI.
        withAnimation(.easeInOut(duration: 0.42)) {
            wordmarkOffset = -7
            wordmarkScale = 0.988
            wordmarkBlur = 5
            wordmarkOpacity = 0
            haloScale = 1.34
            haloOpacity = 0
            backgroundOpacity = 0
            contentScale = 1
            contentOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        IumrahHaptics.selection()

        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        splashVisible = false
    }
}
