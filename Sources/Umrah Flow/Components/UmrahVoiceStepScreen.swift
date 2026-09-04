import SwiftUI

struct UmrahVoiceStepScreen: View {
    @ObservedObject var store: UmrahFlowStore
    @ObservedObject var audio: UmrahFlowAudioService

    let audioKey: String
    let kicker: String
    let title: String
    let text: String

    var counterText: String? = nil
    var symbol: String? = nil
    var isArabic = false
    var alignment: TextAlignment = .center
    var allowsTextCycling = false
    var onTextTap: (() -> Void)? = nil

    var showsPrevious = true
    var showsNext = true
    var nextIsDone = false
    var onPrevious: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil

    var secondaryActionTitle: String? = nil
    var secondaryActionSymbol: String = "sparkles"
    var onSecondaryAction: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    private var isCurrentPlaying: Bool {
        audio.currentKey == audioKey && audio.isPlaying
    }

    private var isCurrentLoading: Bool {
        audio.currentKey == audioKey && audio.isLoading
    }

    private var audioAvailable: Bool {
        store.audioURL(for: audioKey) != nil
    }

    var body: some View {
        GeometryReader { proxy in
            let gradientHeight = min(286, max(196, proxy.size.height * 0.30))
            let textBottomClearance = min(96, max(68, gradientHeight * 0.30))
            let textMaxHeight = max(240, proxy.size.height - textBottomClearance - 28)

            ZStack {
                // Voice aura owns only the visual layer. It can bleed below the safe
                // area, while navigation remains centered in the usable content area.
                AdvisorVoiceGradient(
                    amplitude: CGFloat(isCurrentPlaying ? audio.amplitude : 0),
                    isSpeaking: isCurrentPlaying || isCurrentLoading,
                    minimumHeight: gradientHeight,
                    maximumHeightRatio: 0.62,
                    bottomOverscan: 64
                )
                .allowsHitTesting(false)
                .zIndex(0)

                // The lower aura is the play/pause surface. Keep this hit target
                // behind the text and side controls so nothing interactive is blocked.
                VStack(spacing: 0) {
                    Spacer()
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: gradientHeight * 0.72)
                        .onTapGesture {
                            guard audioAvailable else { return }
                            IumrahHaptics.soft()
                            audio.toggle(key: audioKey, url: store.audioURL(for: audioKey))
                        }
                        .accessibilityLabel(voiceStatus)
                        .accessibilityAddTraits(.isButton)
                }
                .zIndex(1)

                VStack(spacing: 0) {
                    Spacer(minLength: 8)

                    mainTextArea(maxHeight: textMaxHeight)
                        .frame(maxWidth: .infinity)

                    Spacer()
                        .frame(height: textBottomClearance)
                }
                .padding(.horizontal, 72)
                .zIndex(2)

                // Side navigation is intentionally independent of the text and
                // gradient geometry. This keeps Previous / Next at the visual middle
                // of the screen on every iPhone instead of falling to the bottom.
                sideNavigation
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .zIndex(3)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder
    private func mainTextArea(maxHeight: CGFloat) -> some View {
        ViewThatFits(in: .vertical) {
            mainContent
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: maxHeight, alignment: .center)

            ScrollView(.vertical) {
                mainContent
                    .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: maxHeight)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 14) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 46, height: 46)
                    .iumrahGlass(in: Circle())
                    .umrahEntranceMotion()
            }

            HStack(spacing: 9) {
                Text(kicker.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.25)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let counterText, !counterText.isEmpty {
                    Circle()
                        .fill(palette.textSecondary.opacity(0.45))
                        .frame(width: 3, height: 3)
                    Text(counterText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textSecondary)
                }
            }

            if !title.isEmpty {
                UmrahAnimatedText(
                    text: title,
                    font: .system(size: 17, weight: .semibold, design: .rounded),
                    foreground: palette.accent,
                    alignment: .center,
                    lineSpacing: 3
                )
            }

            Button {
                guard allowsTextCycling, let onTextTap else { return }
                IumrahHaptics.selection()
                onTextTap()
            } label: {
                UmrahAnimatedText(
                    text: text,
                    font: .system(size: bodyFontSize, weight: isArabic ? .medium : .semibold, design: .rounded),
                    foreground: palette.textPrimary,
                    alignment: alignment,
                    lineSpacing: isArabic ? 8 : 5,
                    isArabic: isArabic
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!allowsTextCycling || onTextTap == nil)

            if allowsTextCycling {
                Label(UmrahFlowCopy.tapToChange(store.guideLanguage), systemImage: "hand.tap")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textSecondary.opacity(0.78))
                    .padding(.top, 1)
            }

            if let secondaryActionTitle, let onSecondaryAction {
                Button {
                    IumrahHaptics.soft()
                    onSecondaryAction()
                } label: {
                    Label(secondaryActionTitle, systemImage: secondaryActionSymbol)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, 17)
                        .frame(height: 44)
                        .iumrahGlass(in: Capsule(), interactive: true)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var sideNavigation: some View {
        HStack {
            if showsPrevious, let onPrevious {
                UmrahSideStepButton(
                    systemName: "chevron.left",
                    accessibilityLabel: UmrahFlowCopy.previous(store.guideLanguage),
                    action: onPrevious
                )
            } else {
                Color.clear.frame(width: 54, height: 54)
            }

            Spacer()

            if showsNext, let onNext {
                UmrahSideStepButton(
                    systemName: nextIsDone ? "checkmark" : "chevron.right",
                    emphasized: true,
                    accessibilityLabel: nextIsDone ? UmrahFlowCopy.done(store.guideLanguage) : UmrahFlowCopy.next(store.guideLanguage),
                    action: onNext
                )
            } else {
                Color.clear.frame(width: 54, height: 54)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }

    private var bodyFontSize: CGFloat {
        let count = text.count
        if isArabic {
            if count > 290 { return 19 }
            if count > 190 { return 21 }
            if count > 115 { return 22.5 }
            return 24
        }

        if count > 360 { return 18 }
        if count > 250 { return 19.5 }
        if count > 170 { return 21 }
        if count > 105 { return 22.5 }
        return 24.5
    }

    private var voiceStatus: String {
        if isCurrentLoading { return UmrahFlowCopy.loadingVoice(store.guideLanguage) }
        if isCurrentPlaying { return UmrahFlowCopy.advisorSpeaking(store.guideLanguage) }
        return audioAvailable
            ? UmrahFlowCopy.tapToListen(store.guideLanguage)
            : UmrahFlowCopy.audioUnavailable(store.guideLanguage)
    }
}

struct UmrahSideStepButton: View {
    let systemName: String
    var emphasized = false
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var palette: UmrahFlowPalette {
        colorScheme == .dark ? .dark : .light
    }

    var body: some View {
        Button {
            IumrahHaptics.selection()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(emphasized ? Color.white : palette.textPrimary)
                .frame(width: 54, height: 54)
                .iumrahGlass(
                    in: Circle(),
                    interactive: true,
                    tint: emphasized ? palette.accent.opacity(colorScheme == .dark ? 0.48 : 0.56) : nil
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
