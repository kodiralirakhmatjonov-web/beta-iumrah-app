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

    @EnvironmentObject private var settings: AppSettingsStore
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
            ZStack {
                AdvisorVoiceGradient(
                    amplitude: CGFloat(isCurrentPlaying ? audio.amplitude : 0),
                    isSpeaking: isCurrentPlaying || isCurrentLoading,
                    minimumHeight: min(245, max(180, proxy.size.height * 0.29)),
                    maximumHeightRatio: 0.60
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 18)

                    mainTextArea(maxHeight: max(245, proxy.size.height * 0.57))
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 124)
                }
                .padding(.horizontal, 70)

                sideNavigation

                VStack {
                    Spacer()
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(height: min(210, max(150, proxy.size.height * 0.29)))
                        .onTapGesture {
                            guard audioAvailable else { return }
                            IumrahHaptics.soft()
                            audio.toggle(key: audioKey, url: store.audioURL(for: audioKey))
                        }
                        .accessibilityLabel(voiceStatus)
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    @ViewBuilder
    private func mainTextArea(maxHeight: CGFloat) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 48, height: 48)
                        .background(palette.glassTint, in: Circle())
                        .iumrahGlass(in: Circle())
                        .umrahEntranceMotion()
                }

                HStack(spacing: 10) {
                    Text(kicker.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.35)
                        .foregroundStyle(palette.textSecondary)

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
                        font: .system(size: 18, weight: .semibold, design: .rounded),
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
                        lineSpacing: isArabic ? 9 : 6,
                        isArabic: isArabic
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!allowsTextCycling || onTextTap == nil)

                if allowsTextCycling {
                    Label(UmrahFlowCopy.tapToChange(settings.language), systemImage: "hand.tap")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
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
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(palette.glassTint, in: Capsule())
                            .iumrahGlass(in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: maxHeight)
    }

    private var sideNavigation: some View {
        HStack {
            if showsPrevious, let onPrevious {
                UmrahSideStepButton(
                    systemName: "chevron.left",
                    accessibilityLabel: UmrahFlowCopy.previous(settings.language),
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
                    accessibilityLabel: nextIsDone ? UmrahFlowCopy.done(settings.language) : UmrahFlowCopy.next(settings.language),
                    action: onNext
                )
            } else {
                Color.clear.frame(width: 54, height: 54)
            }
        }
        .padding(.horizontal, 14)
        .offset(y: -12)
    }

    private var bodyFontSize: CGFloat {
        let count = text.count
        if isArabic {
            if count > 290 { return 22 }
            if count > 190 { return 24 }
            return 27
        }
        if count > 360 { return 20 }
        if count > 250 { return 22 }
        if count > 170 { return 24 }
        if count > 100 { return 26 }
        return 28
    }

    private var voiceStatus: String {
        if isCurrentLoading { return UmrahFlowCopy.loadingVoice(settings.language) }
        if isCurrentPlaying { return UmrahFlowCopy.advisorSpeaking(settings.language) }
        return audioAvailable ? UmrahFlowCopy.tapToListen(settings.language) : UmrahFlowCopy.loadingVoice(settings.language)
    }
}

struct UmrahSideStepButton: View {
    let systemName: String
    var emphasized = false
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var pressed = false

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
                .background(
                    emphasized
                        ? palette.accent.opacity(colorScheme == .dark ? 0.48 : 0.72)
                        : palette.glassTint,
                    in: Circle()
                )
                .iumrahGlass(in: Circle())
                .overlay {
                    Circle().stroke(palette.glassStroke.opacity(emphasized ? 0.45 : 0.70), lineWidth: 0.7)
                }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
