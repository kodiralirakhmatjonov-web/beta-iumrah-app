import SwiftUI

struct TawafReadingPage: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore

    @State private var pageID: Int?
    @State private var showsSunnahDua = false

    init(flow: UmrahFlowState, store: UmrahFlowStore) {
        self.flow = flow
        self.store = store
        _pageID = State(initialValue: flow.tawafReadingStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.text("tawaf_title", fallback: "Tawaf"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Reading · Round \(flow.tawafRound) of 7")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.44))
                }
                Spacer()
                Text("\(flow.tawafReadingStep + 1) / 7")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color.white.opacity(0.025), in: Capsule())
                    .iumrahGlass(in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 6)

            readingPager

            UmrahRoundSwipeControl(
                round: flow.tawafRound,
                total: 7,
                label: isLastStep ? store.text("tap_btn", fallback: "complete round") : "Read all 7 cards first",
                isEnabled: isLastStep
            ) {
                completeRound()
            }
            .id("tawaf-reading-\(flow.tawafRound)")
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 14)
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
        GeometryReader { proxy in
            HStack(spacing: 12) {
                sideProgress(height: min(390, max(250, proxy.size.height * 0.72)))
                    .frame(width: 20)

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
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $pageID)
            }
            .padding(.horizontal, 20)
        }
    }

    private func sideProgress(height: CGFloat) -> some View {
        let fraction = CGFloat(flow.tawafReadingStep + 1) / 7.0
        return ZStack(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.035))
                .iumrahGlass(in: Capsule())
            Capsule()
                .fill(Color.white.opacity(0.38))
                .frame(height: max(42, height * fraction))
                .animation(.spring(response: 0.42, dampingFraction: 0.90), value: flow.tawafReadingStep)
        }
        .frame(width: 18, height: height)
    }

    @ViewBuilder
    private func readingStep(_ step: ReadingStep, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(step.label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.25)
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Text("\(index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.28))
            }

            switch step.kind {
            case .arabic:
                UmrahAnimatedText(
                    text: step.primary,
                    font: .system(size: 29, weight: .medium, design: .rounded),
                    foreground: .white,
                    alignment: .center,
                    lineSpacing: 12,
                    isArabic: true
                )

            case .regular:
                UmrahAnimatedText(
                    text: step.primary,
                    font: .system(size: 21, weight: .semibold, design: .rounded),
                    foreground: .white.opacity(0.90),
                    alignment: .leading,
                    lineSpacing: 6
                )
                if let secondary = step.secondary, !secondary.isEmpty {
                    UmrahAnimatedText(
                        text: secondary,
                        font: .system(size: 20, weight: .medium, design: .rounded),
                        foreground: .white.opacity(0.58),
                        alignment: .leading,
                        lineSpacing: 6
                    )
                }

            case .zikr:
                Button {
                    guard flow.tawafZikrCount < 20 else { return }
                    IumrahHaptics.selection()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        flow.tawafZikrCount += 1
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Text("\(max(0, 20 - flow.tawafZikrCount))")
                                .font(.system(size: 58, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.14))
                                .contentTransition(.numericText())
                            Spacer()
                            Image(systemName: "hand.tap.fill")
                                .foregroundStyle(.white.opacity(0.20))
                        }
                        Text(step.primary)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let secondary = step.secondary {
                            Text(secondary)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    IumrahHaptics.soft()
                    showsSunnahDua = true
                } label: {
                    HStack {
                        Image(systemName: "hands.sparkles.fill")
                        Text(store.text("sunna_dua_btn", fallback: "Sunnah Dua"))
                        Spacer()
                        Image(systemName: "chevron.up")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(Color.white.opacity(0.025), in: Capsule())
                    .iumrahGlass(in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.white.opacity(0.018), in: RoundedRectangle(cornerRadius: 42, style: .continuous))
        .umrahEntranceMotion()
    }

    private var steps: [ReadingStep] {
        let r = flow.tawafRound
        return [
            .init(kind: .arabic, label: "Dua", primary: store.text("tawaf\(r)_reading_arab1", fallback: "")),
            .init(kind: .regular, label: "Meaning", primary: store.text("tawaf\(r)_reading_text1", fallback: ""), secondary: store.text("tawaf\(r)_reading_text2", fallback: "")),
            .init(kind: .arabic, label: "Dua", primary: store.text("tawaf\(r)_reading_arab2", fallback: "")),
            .init(kind: .regular, label: "Meaning", primary: store.text("tawaf\(r)_reading_text3", fallback: ""), secondary: store.text("tawaf\(r)_reading_text4", fallback: "")),
            .init(kind: .arabic, label: "Dua", primary: store.text("tawaf\(r)_reading_arab3", fallback: "")),
            .init(kind: .regular, label: "Meaning", primary: store.text("tawaf\(r)_reading_text5", fallback: ""), secondary: store.text("tawaf\(r)_reading_text6", fallback: "")),
            .init(kind: .zikr, label: "Dhikr", primary: store.text("tawaf\(r)_zikr_repeat", fallback: "Dhikr"), secondary: store.text("tawaf\(r)_zikr_text", fallback: "Remember Allah and make dua."))
        ]
    }

    private var isLastStep: Bool { flow.tawafReadingStep >= 6 }

    private func completeRound() {
        flow.resetTawafReading()
        pageID = 0
        if flow.tawafRound < 7 {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) {
                flow.tawafRound += 1
            }
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) {
                flow.stage = .postTawaf
            }
        }
    }
}

private struct ReadingStep {
    enum Kind { case arabic, regular, zikr }
    let kind: Kind
    let label: String
    let primary: String
    var secondary: String? = nil
}
