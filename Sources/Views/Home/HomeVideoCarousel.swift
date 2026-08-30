import SwiftUI
import UIKit

struct HomeVideoCarousel: View {
    @Environment(\.scenePhase) private var scenePhase

    private struct Story: Identifiable {
        let id: String
        let resource: String
    }

    private let stories: [Story] = [
        Story(id: "home-story-01", resource: "home-story-01"),
        Story(id: "home-story-02", resource: "home-story-02"),
        Story(id: "home-story-03", resource: "home-story-03"),
        Story(id: "home-story-04", resource: "home-story-04"),
        Story(id: "home-story-05", resource: "home-story-05"),
        Story(id: "home-story-06", resource: "home-story-06"),
        Story(id: "home-story-07", resource: "home-story-07"),
        Story(id: "home-story-08", resource: "home-story-08")
    ]

    @State private var activeStoryID: String? = "home-story-01"
    @State private var isVisible = false

    private var carouselHeight: CGFloat {
        min(max(UIScreen.main.bounds.height * 0.72, 460), 680)
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width * 0.92, 280)
            let sideInset = max((proxy.size.width - cardWidth) / 2, 0)

            ZStack(alignment: .bottom) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(stories) { story in
                            videoCard(story)
                                .frame(width: cardWidth, height: carouselHeight)
                                .id(story.id)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.965)
                                        .opacity(phase.isIdentity ? 1 : 0.84)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, sideInset, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $activeStoryID, anchor: .center)
                .scrollClipDisabled()

                pageIndicator
                    .padding(.bottom, 14)
            }
        }
        .frame(height: carouselHeight)
        .onAppear {
            isVisible = true
            if activeStoryID == nil {
                activeStoryID = stories.first?.id
            }
        }
        .onDisappear {
            isVisible = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("iumrah video stories")
    }

    private func videoCard(_ story: Story) -> some View {
        LoopingVideoView(
            resource: story.resource,
            isPlaying: isVisible && scenePhase == .active && activeStoryID == story.id,
            isMuted: true
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 24, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityLabel("Video \(storyIndex(story) + 1) of \(stories.count)")
    }

    private var pageIndicator: some View {
        HStack(spacing: 5) {
            ForEach(stories) { story in
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(activeStoryID == story.id ? 0.96 : 0.46))
                    .frame(width: activeStoryID == story.id ? 18 : 6, height: 6)
                    .animation(.snappy(duration: 0.25), value: activeStoryID)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func storyIndex(_ story: Story) -> Int {
        stories.firstIndex(where: { $0.id == story.id }) ?? 0
    }
}
