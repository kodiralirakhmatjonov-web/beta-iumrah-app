import SwiftUI

struct SafaReadingPage: View {
    @ObservedObject var flow: UmrahFlowState
    @ObservedObject var store: UmrahFlowStore

    @State private var pageID: Int?
    @State private var showsSafaDua = false

    init(flow: UmrahFlowState, store: UmrahFlowStore) {
        self.flow = flow
        self.store = store
        _pageID = State(initialValue: flow.safaReadingStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Safa & Marwa")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Reading · \(store.text("safa\(flow.safaRound)_title1", fallback: "Round \(flow.safaRound)"))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.44))
                }
                Spacer()
                Text("\(flow.safaReadingStep + 1) / 2")
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

            GeometryReader { proxy in
                HStack(spacing: 12) {
                    ZStack(alignment: .top) {
                        Capsule().fill(Color.white.opacity(0.035)).iumrahGlass(in: Capsule())
                        Capsule()
                            .fill(Color.white.opacity(0.38))
                            .frame(height: max(50, proxy.size.height * (flow.safaReadingStep == 0 ? 0.5 : 1.0)))
                            .animation(.spring(response: 0.42, dampingFraction: 0.90), value: flow.safaReadingStep)
                    }
                    .frame(width: 18)
                    .padding(.vertical, 48)

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
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $pageID)
                }
                .padding(.horizontal, 20)
            }

            UmrahRoundSwipeControl(
                round: flow.safaRound,
                total: 7,
                label: flow.safaReadingStep == 1 ? store.text("tap_btn", fallback: "complete passage") : "Read both cards first",
                isEnabled: flow.safaReadingStep == 1
            ) {
                completeRound()
            }
            .id("safa-reading-\(flow.safaRound)")
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 14)
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

    private var guidancePage: some View {
        readingCard(
            label: "Guidance",
            title: store.text("safa\(flow.safaRound)_title1", fallback: "Round \(flow.safaRound)"),
            text: store.text("safa\(flow.safaRound)_text1", fallback: "Continue Sa'i calmly and remember Allah."),
            arabic: nil
        )
    }

    private var duaPage: some View {
        VStack(spacing: 14) {
            readingCard(
                label: "Dua",
                title: store.text("safa\(flow.safaRound)_title1", fallback: "Round \(flow.safaRound)"),
                text: store.text("safa\(flow.safaRound)_text2", fallback: "Make dua while continuing this passage."),
                arabic: store.text("safa\(flow.safaRound)_sarab1", fallback: "")
            )

            Button {
                IumrahHaptics.soft()
                showsSafaDua = true
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
        .padding(.vertical, 8)
    }

    private func readingCard(label: String, title: String, text: String, arabic: String?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.34))

                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                UmrahAnimatedText(
                    text: text,
                    font: .system(size: 21, weight: .semibold, design: .rounded),
                    foreground: .white.opacity(0.82),
                    alignment: .leading,
                    lineSpacing: 6
                )

                if let arabic, !arabic.isEmpty {
                    Divider().overlay(Color.white.opacity(0.08))
                    UmrahAnimatedText(
                        text: arabic,
                        font: .system(size: 25, weight: .medium, design: .rounded),
                        foreground: .white,
                        alignment: .center,
                        lineSpacing: 9,
                        isArabic: true
                    )
                }
        }
        .padding(22)
        .background(Color.white.opacity(0.022), in: RoundedRectangle(cornerRadius: 42, style: .continuous))
        .iumrahGlass(in: RoundedRectangle(cornerRadius: 42, style: .continuous))
        .umrahEntranceMotion()
    }

    private func completeRound() {
        pageID = 0
        flow.resetSafaReading()
        if flow.safaRound < 7 {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) {
                flow.safaRound += 1
            }
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) {
                flow.stage = .end
            }
        }
    }
}
