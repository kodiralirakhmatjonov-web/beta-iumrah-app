import SwiftUI

struct SafaReadingPage: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore

    @State private var pageID: Int?
    @State private var showsSafaDua = false

    @Environment(\.colorScheme) private var colorScheme

    init(flow: UmrahFlowState, store: UmrahFlowStore) {
        self.flow = flow
        self.store = store
        _pageID = State(initialValue: flow.safaReadingStep)
    }

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AdvisorVoiceGradient(
                    amplitude: 0.025,
                    isSpeaking: false,
                    minimumHeight: min(190, proxy.size.height * 0.24),
                    maximumHeightRatio: 0.36
                )
                .opacity(0.56)
                .allowsHitTesting(false)

                VStack(spacing: 8) {
                    HStack {
                        Text(store.text("sai_title", fallback: "Safa & Marwa").uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.25)
                            .foregroundStyle(palette.textSecondary)
                        Spacer()
                        Text("\(flow.safaRound) / 7  ·  \(flow.safaReadingStep + 1) / 2")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                    }
                    .padding(.horizontal, 72)
                    .padding(.top, 8)

                    readingPager
                }

                HStack {
                    UmrahSideStepButton(
                        systemName: "chevron.left",
                        accessibilityLabel: UmrahFlowCopy.previous(store.guideLanguage),
                        action: previousStep
                    )
                    Spacer()
                    UmrahSideStepButton(
                        systemName: isLastStep ? "checkmark" : "chevron.right",
                        emphasized: true,
                        accessibilityLabel: isLastStep ? UmrahFlowCopy.done(store.guideLanguage) : UmrahFlowCopy.next(store.guideLanguage),
                        action: nextStep
                    )
                }
                .padding(.horizontal, 14)
                .offset(y: -8)
            }
        }
        .onChange(of: pageID) { _, newValue in
            guard let newValue else { return }
            if flow.safaReadingStep != newValue {
                IumrahHaptics.selection()
                flow.safaReadingStep = newValue
            }
        }
        .onChange(of: flow.safaRound) { _, _ in
            pageID = 0
            flow.resetSafaReading()
        }
        .sheet(isPresented: $showsSafaDua) {
            SafaDuaSheet(store: store)
        }
    }

    private var readingPager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                guidancePage
                    .containerRelativeFrame(.vertical)
                    .id(0)
                duaPage
                    .containerRelativeFrame(.vertical)
                    .id(1)
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 72, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageID)
    }

    private var guidancePage: some View {
        readingPage(
            label: UmrahFlowCopy.guidance(store.guideLanguage),
            title: store.text("safa\(flow.safaRound)_title1", fallback: ""),
            text: store.text("safa\(flow.safaRound)_text1", fallback: "Continue Sa'i calmly and remember Allah."),
            arabic: nil,
            showsDuaButton: false
        )
    }

    private var duaPage: some View {
        readingPage(
            label: UmrahFlowCopy.dua(store.guideLanguage),
            title: store.text("safa\(flow.safaRound)_title1", fallback: ""),
            text: store.text("safa\(flow.safaRound)_text2", fallback: "Make dua while continuing this passage."),
            arabic: store.text("safa\(flow.safaRound)_sarab1", fallback: ""),
            showsDuaButton: true
        )
    }

    private func readingPage(
        label: String,
        title: String,
        text: String,
        arabic: String?,
        showsDuaButton: Bool
    ) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 18) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(palette.accent)

                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                UmrahAnimatedText(
                    text: text,
                    font: .system(size: text.count > 240 ? 20 : 23, weight: .semibold, design: .rounded),
                    foreground: palette.textPrimary,
                    alignment: .center,
                    lineSpacing: 7
                )

                if let arabic, !arabic.isEmpty {
                    UmrahAnimatedText(
                        text: arabic,
                        font: .system(size: arabic.count > 180 ? 23 : 27, weight: .medium, design: .rounded),
                        foreground: palette.textPrimary,
                        alignment: .center,
                        lineSpacing: 10,
                        isArabic: true
                    )
                }

                if showsDuaButton {
                    Button {
                        IumrahHaptics.soft()
                        showsSafaDua = true
                    } label: {
                        Label(store.text("sunna_dua_btn", fallback: "Sunnah Dua"), systemImage: "hands.sparkles.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .iumrahGlass(in: Capsule(), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, minHeight: 330, alignment: .center)
            .padding(.vertical, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var isLastStep: Bool { flow.safaReadingStep >= 1 }

    private func previousStep() {
        if flow.safaReadingStep > 0 {
            withAnimation(.smooth(duration: 0.34, extraBounce: 0)) {
                pageID = 0
            }
        } else if flow.safaRound > 1 {
            withAnimation(.smooth(duration: 0.34, extraBounce: 0)) {
                flow.safaRound -= 1
            }
        } else {
            withAnimation(.smooth(duration: 0.30, extraBounce: 0)) {
                flow.safaMode = .listening
            }
        }
    }

    private func nextStep() {
        if !isLastStep {
            withAnimation(.smooth(duration: 0.34, extraBounce: 0)) {
                pageID = 1
            }
        } else {
            completeRound()
        }
    }

    private func completeRound() {
        pageID = 0
        flow.resetSafaReading()
        if flow.safaRound < 7 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.safaRound += 1
            }
        } else {
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .end
            }
        }
    }
}
