import SwiftUI

struct TawafReadingPage: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore

    @State private var pageID: Int?
    @State private var showsSunnahDua = false

    @Environment(\.colorScheme) private var colorScheme

    init(flow: UmrahFlowState, store: UmrahFlowStore) {
        self.flow = flow
        self.store = store
        _pageID = State(initialValue: flow.tawafReadingStep)
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
                        Text(store.text("tawaf_title", fallback: "Tawaf").uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.25)
                            .foregroundStyle(palette.textSecondary)
                        Spacer()
                        Text("\(flow.tawafRound) / 7  ·  \(flow.tawafReadingStep + 1) / 7")
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
            if flow.tawafReadingStep != newValue {
                IumrahHaptics.selection()
                flow.tawafReadingStep = newValue
            }
        }
        .onChange(of: flow.tawafRound) { _, _ in
            pageID = 0
            flow.resetTawafReading()
        }
        .sheet(isPresented: $showsSunnahDua) {
            SunnahDuaSheet(store: store)
        }
    }

    private var readingPager: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    readingStep(steps[index], index: index)
                        .containerRelativeFrame(.vertical)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 72, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageID)
    }

    @ViewBuilder
    private func readingStep(_ step: ReadingStep, index: Int) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 18) {
                Text(step.label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(palette.accent)

                switch step.kind {
                case .arabic:
                    UmrahAnimatedText(
                        text: step.primary,
                        font: .system(size: arabicFontSize(step.primary), weight: .medium, design: .rounded),
                        foreground: palette.textPrimary,
                        alignment: .center,
                        lineSpacing: 11,
                        isArabic: true
                    )

                case .regular:
                    UmrahAnimatedText(
                        text: step.primary,
                        font: .system(size: readingFontSize(step.primary), weight: .semibold, design: .rounded),
                        foreground: palette.textPrimary,
                        alignment: .center,
                        lineSpacing: 7
                    )

                    if let secondary = step.secondary, !secondary.isEmpty {
                        UmrahAnimatedText(
                            text: secondary,
                            font: .system(size: readingFontSize(secondary) - 1, weight: .medium, design: .rounded),
                            foreground: palette.textSecondary,
                            alignment: .center,
                            lineSpacing: 7
                        )
                    }

                case .zikr:
                    zikrContent(step)
                }
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, minHeight: 330, alignment: .center)
            .padding(.vertical, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func zikrContent(_ step: ReadingStep) -> some View {
        VStack(spacing: 16) {
            Button {
                guard flow.tawafZikrCount < 20 else { return }
                IumrahHaptics.selection()
                withAnimation(.smooth(duration: 0.26, extraBounce: 0)) {
                    flow.tawafZikrCount += 1
                }
            } label: {
                VStack(spacing: 10) {
                    Text("\(max(0, 20 - flow.tawafZikrCount))")
                        .font(.system(size: 54, weight: .light, design: .rounded))
                        .foregroundStyle(palette.textPrimary.opacity(0.20))
                        .contentTransition(.numericText())

                    Text(step.primary)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)

                    if let secondary = step.secondary, !secondary.isEmpty {
                        Text(secondary)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .iumrahGlass(
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous),
                    interactive: true
                )
            }
            .buttonStyle(.plain)

            Button {
                IumrahHaptics.soft()
                showsSunnahDua = true
            } label: {
                Label(store.text("sunna_dua_btn", fallback: "Sunnah Dua"), systemImage: "hands.sparkles.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .iumrahGlass(in: Capsule(), interactive: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var steps: [ReadingStep] {
        let round = flow.tawafRound
        return [
            .init(kind: .arabic, label: UmrahFlowCopy.dua(store.guideLanguage), primary: store.text("tawaf\(round)_reading_arab1", fallback: "")),
            .init(kind: .regular, label: UmrahFlowCopy.meaning(store.guideLanguage), primary: store.text("tawaf\(round)_reading_text1", fallback: ""), secondary: store.text("tawaf\(round)_reading_text2", fallback: "")),
            .init(kind: .arabic, label: UmrahFlowCopy.dua(store.guideLanguage), primary: store.text("tawaf\(round)_reading_arab2", fallback: "")),
            .init(kind: .regular, label: UmrahFlowCopy.meaning(store.guideLanguage), primary: store.text("tawaf\(round)_reading_text3", fallback: ""), secondary: store.text("tawaf\(round)_reading_text4", fallback: "")),
            .init(kind: .arabic, label: UmrahFlowCopy.dua(store.guideLanguage), primary: store.text("tawaf\(round)_reading_arab3", fallback: "")),
            .init(kind: .regular, label: UmrahFlowCopy.meaning(store.guideLanguage), primary: store.text("tawaf\(round)_reading_text5", fallback: ""), secondary: store.text("tawaf\(round)_reading_text6", fallback: "")),
            .init(kind: .zikr, label: UmrahFlowCopy.dhikr(store.guideLanguage), primary: store.text("tawaf\(round)_zikr_repeat", fallback: "Dhikr"), secondary: store.text("tawaf\(round)_zikr_text", fallback: "Remember Allah and make dua."))
        ]
    }

    private var isLastStep: Bool { flow.tawafReadingStep >= 6 }

    private func previousStep() {
        if flow.tawafReadingStep > 0 {
            withAnimation(.smooth(duration: 0.34, extraBounce: 0)) {
                pageID = flow.tawafReadingStep - 1
            }
        } else if flow.tawafRound > 1 {
            withAnimation(.smooth(duration: 0.34, extraBounce: 0)) {
                flow.tawafRound -= 1
            }
        } else {
            withAnimation(.smooth(duration: 0.30, extraBounce: 0)) {
                flow.tawafMode = .listening
            }
        }
    }

    private func nextStep() {
        if !isLastStep {
            withAnimation(.smooth(duration: 0.34, extraBounce: 0)) {
                pageID = flow.tawafReadingStep + 1
            }
        } else {
            completeRound()
        }
    }

    private func completeRound() {
        flow.resetTawafReading()
        pageID = 0
        if flow.tawafRound < 7 {
            withAnimation(.smooth(duration: 0.38, extraBounce: 0)) {
                flow.tawafRound += 1
            }
        } else {
            withAnimation(.smooth(duration: 0.42, extraBounce: 0)) {
                flow.stage = .postTawaf
            }
        }
    }

    private func readingFontSize(_ text: String) -> CGFloat {
        if text.count > 260 { return 19 }
        if text.count > 170 { return 21 }
        return 23
    }

    private func arabicFontSize(_ text: String) -> CGFloat {
        if text.count > 220 { return 23 }
        if text.count > 140 { return 25 }
        return 28
    }
}

private struct ReadingStep {
    enum Kind { case arabic, regular, zikr }
    let kind: Kind
    let label: String
    let primary: String
    var secondary: String? = nil
}
