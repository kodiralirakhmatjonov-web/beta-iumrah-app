import SwiftUI
import AVFoundation

struct OnboardingFlowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettingsStore
    let onComplete: () -> Void

    @State private var pageID: Int? = 0
    @State private var isMuted = true
    @State private var showIntro = true
    @State private var isFinishing = false

    @State private var introIconOpacity: Double = 0
    @State private var introIconScale: CGFloat = 0.82
    @State private var introWordmarkOpacity: Double = 0
    @State private var introWordmarkOffset: CGFloat = 16
    @State private var introCaptionOpacity: Double = 0

    private let pageCount = 5

    private var page: Int {
        min(max(pageID ?? 0, 0), pageCount - 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CinematicAmbientBackground(page: page)
                    .ignoresSafeArea()

                pager(proxy: proxy)
                    .ignoresSafeArea()
                    .opacity(showIntro ? 0 : (isFinishing ? 0.18 : 1))
                    .scaleEffect(isFinishing && !reduceMotion ? 0.975 : 1)
                    .blur(radius: isFinishing && !reduceMotion ? 5 : 0)

                topBar(topInset: proxy.safeAreaInsets.top)
                    .opacity(showIntro || isFinishing ? 0 : 1)
                    .zIndex(20)

                footer(bottomInset: proxy.safeAreaInsets.bottom)
                    .opacity(showIntro || isFinishing ? 0 : 1)
                    .zIndex(20)

                if showIntro {
                    introOverlay
                        .transition(.opacity)
                        .zIndex(30)
                }

                if isFinishing {
                    finishingOverlay
                        .transition(.opacity)
                        .zIndex(40)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear(perform: startIntroSequence)
        .onChange(of: pageID) { oldValue, newValue in
            guard oldValue != nil, newValue != nil, oldValue != newValue, !showIntro else { return }
            IumrahHaptics.selection()
        }
    }

    private func pager(proxy: GeometryProxy) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                cinematicPage(index: 0, proxy: proxy) {
                    welcomeScene(isActive: page == 0, size: proxy.size)
                }
                cinematicPage(index: 1, proxy: proxy) {
                    builderScene(isActive: page == 1, size: proxy.size)
                }
                cinematicPage(index: 2, proxy: proxy) {
                    packageScene(isActive: page == 2, size: proxy.size)
                }
                cinematicPage(index: 3, proxy: proxy) {
                    careScene(isActive: page == 3, size: proxy.size)
                }
                cinematicPage(index: 4, proxy: proxy) {
                    closingScene(isActive: page == 4, size: proxy.size)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageID)
        .scrollClipDisabled()
    }

    private func cinematicPage<Scene: View>(
        index: Int,
        proxy: GeometryProxy,
        @ViewBuilder scene: () -> Scene
    ) -> some View {
        let shouldReduceMotion = reduceMotion

        return OnboardingCinematicPage(
            kicker: pageKicker(index),
            title: pageTitle(index),
            bodyText: pageBody(index),
            footnote: pageFootnote(index),
            bottomReserve: max(proxy.safeAreaInsets.bottom, 28) + 126,
            showsCopy: index != pageCount - 1,
            scene: scene()
        )
        .frame(width: proxy.size.width, height: proxy.size.height)
        .id(index)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.58)
                .scaleEffect(phase.isIdentity || shouldReduceMotion ? 1 : 0.965)
                .blur(radius: phase.isIdentity || shouldReduceMotion ? 0 : 2.6)
        }
    }

    private func topBar(topInset: CGFloat) -> some View {
        HStack {
            Spacer()

            Menu {
                ForEach(AppSettingsStore.Language.allCases) { language in
                    Button {
                        settings.language = language
                        IumrahHaptics.selection()
                    } label: {
                        HStack {
                            Text(language.title)
                            if settings.language == language {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(headerForeground)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder((page == 0 || page == 2 ? Color.white : Color.black).opacity(0.10), lineWidth: 1)
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, max(topInset, 44) + 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.22), value: page)
    }

    private func footer(bottomInset: CGFloat) -> some View {
        VStack(spacing: 11) {
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index == page ? Color.primary : Color.primary.opacity(0.18))
                        .frame(width: index == page ? 25 : 7, height: 7)
                }
            }
            .animation(.snappy(duration: 0.24), value: page)
            .accessibilityHidden(true)

            if page == pageCount - 1 {
                Text(L10n.text("onboarding_bismillah", settings.language))
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                    .transition(.opacity)
            }

            Button {
                if page == pageCount - 1 {
                    finishOnboarding()
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        pageID = page + 1
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(page == pageCount - 1
                         ? L10n.text("onboarding_start", settings.language)
                         : L10n.text("onboarding_next", settings.language))
                    Image(systemName: page == pageCount - 1 ? "sparkles" : "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                }
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .foregroundStyle(Color.iumrahPrimaryButtonText)
                .background(Color.iumrahPrimaryButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 14, y: 7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, max(bottomInset, 28) + 12)
        .background {
            LinearGradient(
                colors: [
                    Color.iumrahPageBackground.opacity(0),
                    Color.iumrahPageBackground.opacity(0.96),
                    Color.iumrahPageBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func welcomeScene(isActive: Bool, size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            LoopingVideoView(
                resource: "home-story-02",
                isPlaying: scenePhase == .active && !showIntro && !isFinishing && page == 0,
                isMuted: isMuted
            )

            LinearGradient(
                colors: [Color.black.opacity(0.22), Color.black.opacity(0.06), Color.black.opacity(0.52)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 10) {
                OnboardingGlassPill(
                    title: L10n.text("city_makkah", settings.language),
                    icon: "moon.stars.fill",
                    lightText: true
                )
                OnboardingGlassPill(
                    title: L10n.text("city_madinah", settings.language),
                    icon: "sparkles",
                    lightText: true
                )

                Spacer(minLength: 8)

                Button {
                    isMuted.toggle()
                    IumrahHaptics.soft()
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isMuted ? "Sound off" : "Sound on")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
            .opacity(isActive ? 1 : 0.72)
            .scaleEffect(isActive || reduceMotion ? 1 : 0.965, anchor: .bottom)
            .animation(.spring(response: 0.62, dampingFraction: 0.86), value: isActive)
        }
    }

    private func builderScene(isActive: Bool, size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(colorScheme == .dark ? 0.02 : 0.78), Color.iumrahCareLight.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.iumrahCareLight.opacity(0.28))
                .frame(width: 300, height: 300)
                .blur(radius: 18)
                .offset(x: 150, y: -126)

            Circle()
                .fill(Color.iumrahCareDark.opacity(0.09))
                .frame(width: 250, height: 250)
                .blur(radius: 22)
                .offset(x: -158, y: 150)

            OnboardingBuilderMock(isActive: isActive)
                .frame(width: min(size.width * 0.86, 356))
                .rotationEffect(.degrees(isActive && !reduceMotion ? -2.2 : -0.7))
                .offset(x: isActive && !reduceMotion ? -18 : -6, y: isActive && !reduceMotion ? 8 : 20)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.965)
                .shadow(color: .black.opacity(0.14), radius: 30, y: 16)
                .animation(.spring(response: 0.62, dampingFraction: 0.84), value: isActive)

            VStack(spacing: 10) {
                floatingSummaryCard(title: "TAS → MED", subtitle: L10n.text("route_label", settings.language), icon: "airplane")
                floatingSummaryCard(title: "27 Sep – 30 Sep", subtitle: L10n.text("detail_dates", settings.language), icon: "calendar")
                floatingSummaryCard(title: L10n.text("tier_standard", settings.language), subtitle: L10n.text("trip_format_title", settings.language), icon: "sparkles")
            }
            .offset(x: isActive && !reduceMotion ? 104 : 128, y: isActive && !reduceMotion ? -34 : -14)
            .opacity(isActive ? 1 : 0.62)
            .scaleEffect(isActive || reduceMotion ? 1 : 0.93, anchor: .trailing)
            .animation(.spring(response: 0.60, dampingFraction: 0.83).delay(0.05), value: isActive)
        }
    }

    private func packageScene(isActive: Bool, size: CGSize) -> some View {
        ZStack {
            LoopingVideoView(
                resource: "flight-search",
                isPlaying: scenePhase == .active && !showIntro && !isFinishing && page == 2,
                isMuted: true
            )
            .opacity(0.54)

            LinearGradient(
                colors: [Color.black.opacity(0.18), Color.iumrahCareDark.opacity(0.62), Color.black.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.iumrahCareLight.opacity(0.30))
                .frame(width: 340, height: 340)
                .blur(radius: 18)
                .offset(x: 150, y: -108)

            Circle()
                .fill(Color.white.opacity(0.065))
                .frame(width: 270, height: 270)
                .blur(radius: 18)
                .offset(x: -160, y: 148)

            OnboardingPackageMock(isActive: isActive)
                .frame(width: min(size.width * 0.87, 360))
                .rotationEffect(.degrees(isActive && !reduceMotion ? -2.4 : -0.8))
                .offset(x: isActive && !reduceMotion ? -14 : -4, y: isActive && !reduceMotion ? -4 : 12)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.965)
                .shadow(color: .black.opacity(0.30), radius: 34, y: 18)
                .animation(.spring(response: 0.62, dampingFraction: 0.84), value: isActive)

            priceSpotlight
                .offset(x: isActive && !reduceMotion ? -96 : -70, y: isActive && !reduceMotion ? -132 : -104)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.92)
                .opacity(isActive ? 1 : 0.68)
                .animation(.spring(response: 0.58, dampingFraction: 0.82).delay(0.04), value: isActive)

            HStack(spacing: 9) {
                OnboardingGlassPill(title: L10n.text("onboarding_chip_flight", settings.language), icon: "airplane", lightText: true)
                OnboardingGlassPill(title: L10n.text("onboarding_chip_hotel", settings.language), icon: "building.2.fill", lightText: true)
                OnboardingGlassPill(title: L10n.text("onboarding_chip_support", settings.language), icon: "heart.fill", lightText: true)
            }
            .offset(y: isActive && !reduceMotion ? 164 : 142)
            .opacity(isActive ? 1 : 0.70)
            .scaleEffect(isActive || reduceMotion ? 1 : 0.93)
            .animation(.spring(response: 0.60, dampingFraction: 0.83).delay(0.08), value: isActive)
        }
    }

    private func careScene(isActive: Bool, size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.iumrahPageBackground, Color.iumrahCareLight.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.iumrahCareLight.opacity(0.26))
                .frame(width: 310, height: 310)
                .blur(radius: 18)
                .offset(x: 150, y: 116)

            Circle()
                .fill(Color.iumrahCareDark.opacity(0.11))
                .frame(width: 270, height: 270)
                .blur(radius: 20)
                .offset(x: -154, y: -124)

            OnboardingJourneyMock(isActive: isActive)
                .frame(width: min(size.width * 0.78, 324))
                .rotationEffect(.degrees(isActive && !reduceMotion ? -6.5 : -2.5))
                .offset(x: isActive && !reduceMotion ? -64 : -42, y: isActive && !reduceMotion ? 44 : 58)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.95)
                .shadow(color: .black.opacity(0.14), radius: 28, y: 16)
                .animation(.spring(response: 0.62, dampingFraction: 0.84), value: isActive)

            OnboardingCareMock(isActive: isActive)
                .frame(width: min(size.width * 0.72, 298))
                .rotationEffect(.degrees(isActive && !reduceMotion ? 5.5 : 2.1))
                .offset(x: isActive && !reduceMotion ? 64 : 40, y: isActive && !reduceMotion ? -30 : -6)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.96)
                .shadow(color: .black.opacity(0.18), radius: 30, y: 16)
                .animation(.spring(response: 0.64, dampingFraction: 0.83).delay(0.04), value: isActive)

            VStack(spacing: 10) {
                OnboardingGlassPill(title: "24/7", icon: "dot.radiowaves.left.and.right", lightText: false)
                    .offset(x: 110, y: -122)
                OnboardingGlassPill(title: L10n.text("onboarding_chip_status", settings.language), icon: "checkmark.circle.fill", lightText: false)
                    .offset(x: -108, y: 112)
            }
            .opacity(isActive ? 1 : 0.70)
            .scaleEffect(isActive || reduceMotion ? 1 : 0.93)
            .animation(.spring(response: 0.60, dampingFraction: 0.82).delay(0.07), value: isActive)
        }
    }

    private func closingScene(isActive: Bool, size: CGSize) -> some View {
        let compact = size.height < 760

        return ZStack {
            LinearGradient(
                colors: [Color.iumrahPageBackground, Color.iumrahCareLight.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.iumrahCareLight.opacity(0.22))
                .frame(width: compact ? 270 : 320, height: compact ? 270 : 320)
                .blur(radius: 26)
                .offset(x: 0, y: compact ? -40 : -60)

            VStack(spacing: compact ? 14 : 18) {
                Spacer(minLength: compact ? 28 : 60)

                Image("OnboardingBrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 138 : 164, height: compact ? 138 : 164)
                    .scaleEffect(isActive || reduceMotion ? 1 : 0.92)
                    .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
                    .animation(.spring(response: 0.68, dampingFraction: 0.84), value: isActive)

                VStack(spacing: 6) {
                    Text("iumrah")
                        .font(.system(size: compact ? 33 : 38, weight: .bold, design: .rounded))
                    Text("PROJECT")
                        .font(.system(size: compact ? 10 : 12, weight: .semibold))
                        .tracking(compact ? 3.2 : 4)
                        .foregroundStyle(Color.secondary)
                }
                .foregroundStyle(Color.primary)
                .opacity(isActive ? 1 : 0.82)
                .offset(y: isActive || reduceMotion ? 0 : 10)
                .animation(.spring(response: 0.60, dampingFraction: 0.84).delay(0.03), value: isActive)

                VStack(spacing: 9) {
                    Text(L10n.text("onboarding_closing_headline", settings.language))
                        .font(.system(size: compact ? 22 : 25, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.primary)
                    Text(L10n.text("onboarding_closing_message", settings.language))
                        .font(.system(size: compact ? 15.5 : 17, weight: .regular, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.secondary)
                        .lineSpacing(3)
                }
                .padding(.horizontal, compact ? 24 : 28)
                .opacity(isActive ? 1 : 0.76)
                .offset(y: isActive || reduceMotion ? 0 : 12)
                .animation(.spring(response: 0.62, dampingFraction: 0.86).delay(0.08), value: isActive)

                Spacer()
            }
            .padding(.top, compact ? 40 : 70)
            .padding(.bottom, compact ? 22 : 40)
        }
    }

    private var priceSpotlight: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.text("final_price", settings.language))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.70))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("2 050 $")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text(L10n.text("price_per_person", settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.13), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
    }

    private func floatingSummaryCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.iumrahCareDark)
                .frame(width: 32, height: 32)
                .background(Color.iumrahCareLight.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(width: 178)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
    }

    private var introOverlay: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            LoopingVideoView(
                resource: "flight-search",
                isPlaying: scenePhase == .active && showIntro,
                isMuted: true
            )
            .opacity(0.62)
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.18), Color.black.opacity(0.48), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Image("OnboardingBrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 132, height: 132)
                    .scaleEffect(introIconScale)
                    .opacity(introIconOpacity)
                    .shadow(color: .black.opacity(0.24), radius: 24, y: 12)

                Image("HeaderWordmarkDark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 225, height: 58)
                    .opacity(introWordmarkOpacity)
                    .offset(y: introWordmarkOffset)

                Text(L10n.text("onboarding_intro_line", settings.language))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .opacity(introCaptionOpacity)

                Spacer()
            }
        }
    }

    private var finishingOverlay: some View {
        ZStack {
            Color.iumrahPageBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image("OnboardingBrandIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 106, height: 106)
                    .shadow(color: .black.opacity(0.14), radius: 22, y: 10)

                Image(wordmarkAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 202, height: 52)
            }
            .scaleEffect(isFinishing && !reduceMotion ? 1 : 0.98)
        }
    }

    private var headerForeground: Color {
        (page == 0 || page == 2) ? .white : .primary
    }

    private func startIntroSequence() {
        guard showIntro else { return }

        withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
            introIconOpacity = 1
            introIconScale = 1
        }
        withAnimation(.easeOut(duration: 0.40).delay(0.18)) {
            introWordmarkOpacity = 1
            introWordmarkOffset = 0
        }
        withAnimation(.easeOut(duration: 0.34).delay(0.34)) {
            introCaptionOpacity = 0.9
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            withAnimation(.easeInOut(duration: 0.34)) {
                introCaptionOpacity = 0
                introWordmarkOpacity = 0
                introIconOpacity = 0
            }
            withAnimation(.easeInOut(duration: 0.42).delay(0.04)) {
                showIntro = false
            }
        }
    }

    private func finishOnboarding() {
        guard !isFinishing else { return }
        IumrahHaptics.success()

        withAnimation(.easeInOut(duration: 0.34)) {
            isFinishing = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            onComplete()
        }
    }

    private func pageKicker(_ index: Int) -> String {
        switch index {
        case 0: return L10n.text("onboarding_welcome_kicker", settings.language)
        case 1: return L10n.text("onboarding_builder_kicker", settings.language)
        case 2: return L10n.text("onboarding_package_kicker", settings.language)
        case 3: return L10n.text("onboarding_care_kicker", settings.language)
        default: return L10n.text("onboarding_closing_kicker", settings.language)
        }
    }

    private func pageTitle(_ index: Int) -> String {
        switch index {
        case 0: return L10n.text("onboarding_welcome_title", settings.language)
        case 1: return L10n.text("onboarding_builder_title", settings.language)
        case 2: return L10n.text("onboarding_package_title", settings.language)
        case 3: return L10n.text("onboarding_care_title", settings.language)
        default: return L10n.text("onboarding_closing_title", settings.language)
        }
    }

    private func pageBody(_ index: Int) -> String {
        switch index {
        case 0: return L10n.text("onboarding_welcome_body", settings.language)
        case 1: return L10n.text("onboarding_builder_body", settings.language)
        case 2: return L10n.text("onboarding_package_body", settings.language)
        case 3: return L10n.text("onboarding_care_body", settings.language)
        default: return L10n.text("onboarding_closing_body", settings.language)
        }
    }

    private func pageFootnote(_ index: Int) -> String {
        switch index {
        case 0: return L10n.text("onboarding_welcome_footnote", settings.language)
        case 1: return L10n.text("onboarding_builder_footnote", settings.language)
        case 2: return L10n.text("onboarding_package_footnote", settings.language)
        case 3: return L10n.text("onboarding_care_footnote", settings.language)
        default: return L10n.text("onboarding_closing_footnote", settings.language)
        }
    }
}

private struct OnboardingCinematicPage<Scene: View>: View {
    let kicker: String
    let title: String
    let bodyText: String
    let footnote: String
    let bottomReserve: CGFloat
    let showsCopy: Bool
    let scene: Scene

    var body: some View {
        GeometryReader { proxy in
            let availableHeight = max(proxy.size.height - bottomReserve, 430)
            let compact = availableHeight < 650
            let copyLength = title.count + bodyText.count + footnote.count
            let sceneFraction: CGFloat = {
                if !showsCopy { return 1.0 }
                if compact { return copyLength > 165 ? 0.48 : 0.52 }
                if copyLength > 190 { return 0.54 }
                if copyLength > 155 { return 0.57 }
                return 0.60
            }()
            let sceneHeight = showsCopy
                ? min(max(availableHeight * sceneFraction, compact ? 300 : 390), compact ? 390 : 475)
                : availableHeight

            VStack(spacing: 0) {
                scene
                    .frame(width: proxy.size.width, height: sceneHeight)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: showsCopy ? 44 : 0,
                            bottomTrailingRadius: showsCopy ? 44 : 0,
                            topTrailingRadius: 0,
                            style: .continuous
                        )
                    )
                    .overlay(alignment: .bottom) {
                        if showsCopy {
                            LinearGradient(
                                colors: [Color.clear, Color.iumrahPageBackground.opacity(0.86), Color.iumrahPageBackground],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 112)
                        }
                    }

                if showsCopy {
                    VStack(alignment: .leading, spacing: compact ? 9 : 11) {
                        Text(kicker)
                            .font(.system(size: 12.5, weight: .bold))
                            .tracking(2.2)
                            .foregroundStyle(Color.secondary)

                        Text(title)
                            .font(.system(size: compact ? 33 : 36, weight: .bold, design: .rounded))
                            .tracking(-0.95)
                            .foregroundStyle(Color.primary)
                            .lineSpacing(0)
                            .minimumScaleFactor(0.90)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(bodyText)
                            .font(.system(size: compact ? 16 : 17, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.secondary)
                            .lineSpacing(2)
                            .minimumScaleFactor(0.92)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(footnote)
                            .font(.system(size: compact ? 12.5 : 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.secondary.opacity(0.80))
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)
                            .padding(.top, 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, compact ? 10 : 12)

                    Spacer(minLength: 0)
                }
            }
            .frame(width: proxy.size.width, height: availableHeight, alignment: .top)
            .padding(.bottom, bottomReserve)
        }
    }
}

private struct CinematicAmbientBackground: View {
    let page: Int

    var body: some View {
        ZStack {
            Color.iumrahPageBackground

            Circle()
                .fill(primaryColor.opacity(0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 30)
                .offset(x: page.isMultiple(of: 2) ? 160 : -160, y: -220)

            Circle()
                .fill(secondaryColor.opacity(0.08))
                .frame(width: 320, height: 320)
                .blur(radius: 34)
                .offset(x: page.isMultiple(of: 2) ? -170 : 170, y: 280)
        }
        .animation(.easeInOut(duration: 0.7), value: page)
    }

    private var primaryColor: Color {
        switch page {
        case 0: return Color.iumrahCareDark
        case 1: return Color.iumrahCareLight
        case 2: return Color.iumrahCareDark
        case 3: return Color.iumrahCareLight
        default: return Color.iumrahCareDark
        }
    }

    private var secondaryColor: Color {
page == 2 ? Color.white : (page == 4 ? Color.iumrahCareLight : Color.iumrahCareDark)
    }
}


private struct OnboardingBuilderMock: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Color.iumrahRaisedBackground, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("trip_origin_title", settings.language))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.secondary)
                    Text("TAS")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.secondary.opacity(0.65))
            }
            .cinematicReveal(isActive, delay: 0.02, y: 14)

            VStack(alignment: .leading, spacing: 9) {
                Text(L10n.text("trip_destination_title", settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)

                HStack(spacing: 0) {
                    Text(L10n.text("city_makkah", settings.language))
                        .frame(maxWidth: .infinity)
                    Text("\(L10n.text("city_makkah", settings.language)) + \(L10n.text("city_madinah", settings.language))")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.iumrahCardBackground, in: Capsule(style: .continuous))
                }
                .font(.caption)
                .padding(3)
                .background(Color.iumrahRaisedBackground, in: Capsule(style: .continuous))
            }
            .cinematicReveal(isActive, delay: 0.06, y: 16)

            HStack(spacing: 10) {
                mockDataPill(icon: "calendar", title: "27 Sep")
                mockDataPill(icon: "calendar.badge.clock", title: "30 Sep")
            }
            .cinematicReveal(isActive, delay: 0.10, y: 16)

            VStack(alignment: .leading, spacing: 9) {
                Text(L10n.text("hotel_level", settings.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)

                HStack(spacing: 7) {
                    ForEach(1...5, id: \.self) { star in
                        Text("\(star)★")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(star == 4 ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(star == 4 ? Color.black : Color.iumrahRaisedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .cinematicReveal(isActive, delay: 0.14, y: 16)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.iumrahCareDark)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.text("tier_standard", settings.language))
                        .font(.subheadline.weight(.bold))
                    Text(L10n.text("tier_standard_subtitle", settings.language))
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.iumrahRaisedBackground.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .cinematicReveal(isActive, delay: 0.18, y: 16)
        }
        .padding(18)
        .background(Color.iumrahCardBackground.opacity(0.98), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
        .opacity(isActive ? 1 : 0.82)
    }

    private func mockDataPill(icon: String, title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(Color.iumrahRaisedBackground, in: Capsule(style: .continuous))
    }
}

private struct OnboardingPackageMock: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let isActive: Bool

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(L10n.text("final_price", settings.language), systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                    Label("2", systemImage: "person.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.12), in: Capsule(style: .continuous))
                }

                Text("4 100 $")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(-1.2)

                Text(L10n.text("final_price_note", settings.language))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))

                HStack(spacing: 10) {
                    personPrice("2 050 $")
                    personPrice("2 050 $")
                }
            }
            .padding(19)
            .background(
                LinearGradient(
                    colors: [Color.iumrahCareDark.opacity(0.98), Color.black.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
            .cinematicReveal(isActive, delay: 0.02, y: 18)

            VStack(alignment: .leading, spacing: 11) {
                Text(L10n.text("booking_included", settings.language))
                    .font(.headline)
                    .foregroundStyle(.primary)

                includedRow(icon: "airplane", title: L10n.text("booking_outbound_flight", settings.language))
                includedRow(icon: "building.2.fill", title: L10n.text("booking_makkah_hotel", settings.language))
                includedRow(icon: "building.2.fill", title: L10n.text("booking_madinah_hotel", settings.language))
                includedRow(icon: "car.fill", title: L10n.text("booking_transfer_title", settings.language))
            }
            .padding(17)
            .background(Color.iumrahCardBackground.opacity(0.98), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
            }
            .cinematicReveal(isActive, delay: 0.10, y: 20)
        }
        .opacity(isActive ? 1 : 0.84)
    }

    private func personPrice(_ price: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.fill")
            Text(price)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Color.white.opacity(0.11), in: Capsule(style: .continuous))
    }

    private func includedRow(icon: String, title: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.iumrahCareDark)
                .frame(width: 28, height: 28)
                .background(Color.iumrahCareLight.opacity(0.20), in: Circle())
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 20)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer()
        }
    }
}

private struct OnboardingJourneyMock: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("home_hero_kicker", settings.language))
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.secondary)
                    Text(L10n.status("AVAILABILITY_CHECK", settings.language))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "clock.fill")
                    .foregroundStyle(Color.iumrahCareDark)
                    .frame(width: 36, height: 36)
                    .background(Color.iumrahCareLight.opacity(0.18), in: Circle())
            }
            .cinematicReveal(isActive, delay: 0.02, y: 14)

            mockJourneyRow(icon: "airplane", title: L10n.text("route_label", settings.language), value: "TAS → MED")
                .cinematicReveal(isActive, delay: 0.06, y: 12)
            mockJourneyRow(icon: "calendar", title: L10n.text("detail_dates", settings.language), value: "27–30 Sep 2026")
                .cinematicReveal(isActive, delay: 0.10, y: 12)
            mockJourneyRow(icon: "building.2.fill", title: L10n.text("detail_hotel", settings.language), value: "voco Makkah by IHG")
                .cinematicReveal(isActive, delay: 0.14, y: 12)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("final_price", settings.language))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                    Text("2 050 $")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                }
                Spacer()
                Label("2", systemImage: "person.2.fill")
                    .font(.caption.weight(.semibold))
            }
            .cinematicReveal(isActive, delay: 0.18, y: 12)

            HStack {
                Text(L10n.text("open_booking", settings.language))
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .cinematicReveal(isActive, delay: 0.22, y: 12)
        }
        .padding(17)
        .background(Color.iumrahCardBackground.opacity(0.98), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
        .opacity(isActive ? 1 : 0.84)
    }

    private func mockJourneyRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.iumrahCareDark)
                .frame(width: 30, height: 30)
                .background(Color.iumrahCareLight.opacity(0.17), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

private struct OnboardingCareMock: View {
    @EnvironmentObject private var settings: AppSettingsStore
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .padding(5)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer()
                Text("24/7")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(Color.white.opacity(0.13), in: Capsule(style: .continuous))
            }
            .cinematicReveal(isActive, delay: 0.02, y: 14)

            Text("iumrah Care")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .cinematicReveal(isActive, delay: 0.06, y: 14)

            Text(L10n.text("care_subtitle", settings.language))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(3)
                .cinematicReveal(isActive, delay: 0.10, y: 14)

            HStack(spacing: 8) {
                metric(icon: "bubble.left.fill", title: L10n.text("care_metric_answers", settings.language))
                metric(icon: "bell.fill", title: L10n.text("care_metric_updates", settings.language))
                metric(icon: "heart.fill", title: L10n.text("care_metric_care", settings.language))
            }
            .cinematicReveal(isActive, delay: 0.14, y: 14)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.iumrahCareDark, Color.iumrahCareLight.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .opacity(isActive ? 1 : 0.84)
    }

    private func metric(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.12), in: Circle())
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}


private struct CinematicRevealModifier: ViewModifier {
    let isActive: Bool
    let delay: Double
    let y: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0.35)
            .offset(y: isActive ? 0 : y)
            .scaleEffect(isActive ? 1 : 0.985, anchor: .center)
            .animation(
                .spring(response: 0.52, dampingFraction: 0.86).delay(isActive ? delay : 0),
                value: isActive
            )
    }
}

private extension View {
    func cinematicReveal(_ isActive: Bool, delay: Double, y: CGFloat = 14) -> some View {
        modifier(CinematicRevealModifier(isActive: isActive, delay: delay, y: y))
    }
}

private struct OnboardingGlassPill: View {
    let title: String
    let icon: String
    let lightText: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(lightText ? Color.white : Color.primary)
        .padding(.horizontal, 13)
        .frame(height: 34)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder((lightText ? Color.white : Color.primary).opacity(lightText ? 0.14 : 0.06), lineWidth: 1)
        }
    }
}
