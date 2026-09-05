import SwiftUI
import UIKit

struct HomeVideoCarousel: View {
    @Environment(\.scenePhase) private var scenePhase

    private let stories = HomeEmotionalStory.all

    @State private var activeStoryID: String? = HomeEmotionalStory.all.first?.id
    @State private var isVisible = false
    @State private var isMuted = true

    private var carouselHeight: CGFloat {
        min(max(UIScreen.main.bounds.height * 0.72, 460), 680)
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width * 0.968, 290)
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
                                        .scaleEffect(phase.isIdentity ? 1 : 0.985)
                                        .opacity(phase.isIdentity ? 1 : 0.9)
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

    private func videoCard(_ story: HomeEmotionalStory) -> some View {
        LoopingVideoView(
            resource: story.resource,
            isPlaying: isVisible && scenePhase == .active && activeStoryID == story.id,
            isMuted: isMuted
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Button {
                isMuted.toggle()
                IumrahHaptics.soft()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
                    .iumrahGlass(in: Circle(), interactive: true, chrome: true)
            }
            .buttonStyle(.plain)
            .padding(16)
            .opacity(activeStoryID == story.id ? 1 : 0.78)
        }
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
        .iumrahGlass(in: Capsule(style: .continuous), allowsStaticGlass: true, chrome: true)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func storyIndex(_ story: HomeEmotionalStory) -> Int {
        stories.firstIndex(of: story) ?? 0
    }
}
