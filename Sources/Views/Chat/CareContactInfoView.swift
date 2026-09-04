import PhotosUI
import SwiftUI

struct CareContactInfoView: View {
    enum Section: String, CaseIterable {
        case info
        case background
    }

    @ObservedObject var appearance: CareChatAppearanceStore

    let profile: IumrahPublicProfile?
    let language: AppSettingsStore.Language
    let bookingNumber: String?
    let onCall: () -> Void
    let onTelegram: () -> Void
    let onWhatsApp: () -> Void
    let transitionNamespace: Namespace.ID
    let onClose: () -> Void

    @State private var section: Section = .info
    @State private var selectedPhoto: PhotosPickerItem?
    @GestureState private var dismissDragX: CGFloat = 0
    @Namespace private var segmentNamespace

    var body: some View {
        ZStack {
            CareConversationBackground(
                wallpaper: appearance.wallpaper,
                customImage: appearance.customImage,
                motionEnabled: true
            )

            if appearance.wallpaper.isVisual {
                LinearGradient(
                    colors: [Color.black.opacity(0.10), Color.clear, Color.black.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHero
                        .padding(.top, 10)

                    segmentControl
                        .padding(.top, 27)

                    ZStack(alignment: .top) {
                        if section == .info {
                            informationSection
                                .transition(.opacity.combined(with: .offset(x: -12)))
                        } else {
                            backgroundSection
                                .transition(.opacity.combined(with: .offset(x: 12)))
                        }
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 44)
            }
        }
        .offset(x: max(0, dismissDragX))
        .shadow(color: .black.opacity(dismissDragX > 0 ? 0.18 : 0), radius: 22, x: -8)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .updating($dismissDragX) { value, state, transaction in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard value.startLocation.x <= 32, dx > 0, abs(dx) > abs(dy) * 1.12 else { return }
                    state = dx
                    transaction.animation = .interactiveSpring(response: 0.28, dampingFraction: 0.92)
                }
                .onEnded { value in
                    let isEdgeSwipe = value.startLocation.x <= 32
                    let horizontal = value.translation.width > abs(value.translation.height) * 1.12
                    let shouldClose = value.translation.width > 95 || value.predictedEndTranslation.width > 170
                    if isEdgeSwipe && horizontal && shouldClose {
                        if appearance.hapticsEnabled { IumrahHaptics.soft() }
                        onClose()
                    }
                }
        )
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { floatingTopBar }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    selectedPhoto = nil
                    if let data {
                        if appearance.hapticsEnabled { IumrahHaptics.selection() }
                        appearance.setCustomPhoto(data: data)
                    }
                }
            }
        }
    }

    private var floatingTopBar: some View {
        HStack {
            Button {
                if appearance.hapticsEnabled { IumrahHaptics.soft() }
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
            .foregroundStyle(primaryText)
            .buttonStyle(CareGlassPressStyle(shape: Circle()))
            .accessibilityLabel(tr("Back", "Назад", "Orqaga", "Орқага"))

            Spacer()

            Button {
                if appearance.hapticsEnabled { IumrahHaptics.selection() }
                onClose()
            } label: {
                Text(tr("Done", "Готово", "Tayyor", "Тайёр"))
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 17)
                    .frame(height: 48)
            }
            .foregroundStyle(primaryText)
            .buttonStyle(CareGlassPressStyle(shape: Capsule()))
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 3)
    }

    private var profileHero: some View {
        VStack(spacing: 12) {
            CareProfileAvatar(profile: profile, size: 112)
                .matchedGeometryEffect(id: "care-profile-avatar", in: transitionNamespace, isSource: true)
                .shadow(color: .black.opacity(appearance.wallpaper.isVisual ? 0.20 : 0.12), radius: 20, y: 9)

            Text(displayName)
                .matchedGeometryEffect(id: "care-profile-name", in: transitionNamespace, isSource: true)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(-0.75)
                .foregroundStyle(primaryText)
                .multilineTextAlignment(.center)

            Text(roleTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 28) {
                actionButton(
                    title: tr("Call", "Позвонить", "Qo‘ng‘iroq", "Қўнғироқ"),
                    icon: "phone.fill",
                    enabled: !preferredPhone.isEmpty,
                    action: onCall
                )
                actionButton(
                    title: "Telegram",
                    icon: "paperplane.fill",
                    enabled: hasTelegram,
                    action: onTelegram
                )
                actionButton(
                    title: "WhatsApp",
                    icon: "message.fill",
                    enabled: hasWhatsApp,
                    action: onWhatsApp
                )
            }
            .padding(.top, 11)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(
        title: String,
        icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard enabled else { return }
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 58, height: 58)
                    .contentShape(Circle())
                    .iumrahGlass(in: Circle())

                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(enabled ? primaryText : secondaryText.opacity(0.48))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var segmentControl: some View {
        HStack(spacing: 12) {
            segmentButton(.info, title: tr("Info", "Сведения", "Ma’lumot", "Маълумот"))
            segmentButton(.background, title: tr("Background", "Фон", "Fon", "Фон"))
        }
        .frame(maxWidth: .infinity)
    }

    private func segmentButton(_ value: Section, title: String) -> some View {
        Button {
            guard section != value else { return }
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.90)) {
                section = value
            }
        } label: {
            Text(title)
                .font(.system(size: 16.5, weight: section == value ? .semibold : .medium))
                .foregroundStyle(primaryText.opacity(section == value ? 1 : 0.62))
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background {
                    if section == value {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .matchedGeometryEffect(id: "care-profile-segment", in: segmentNamespace)
                            .overlay {
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.7)
                            }
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var informationSection: some View {
        VStack(spacing: 14) {
            if let bio = profile?.bio.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
                glassCard {
                    Text(bio)
                        .font(.system(size: 16))
                        .foregroundStyle(primaryText.opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
            }

            glassCard {
                VStack(spacing: 0) {
                    if !preferredPhone.isEmpty {
                        infoRow(
                            label: tr("Phone", "Телефон", "Telefon", "Телефон"),
                            value: preferredPhone,
                            icon: "phone.fill"
                        )
                        if hasTelegram || hasWhatsApp {
                            Divider().opacity(0.24).padding(.leading, 56)
                        }
                    }
                    if hasTelegram {
                        infoRow(label: "Telegram", value: profile?.telegram ?? "", icon: "paperplane.fill")
                        if hasWhatsApp {
                            Divider().opacity(0.24).padding(.leading, 56)
                        }
                    }
                    if hasWhatsApp {
                        infoRow(label: "WhatsApp", value: profile?.whatsapp ?? "", icon: "message.fill")
                    }
                }
                .padding(.horizontal, 16)
            }

            glassCard {
                VStack(spacing: 0) {
                    settingsToggle(
                        title: tr("Chat sounds", "Звуки чата", "Chat tovushlari", "Чат товушлари"),
                        icon: "speaker.wave.2.fill",
                        isOn: $appearance.soundsEnabled
                    )
                    Divider().opacity(0.24).padding(.leading, 56)
                    settingsToggle(
                        title: tr("Haptics", "Виброотклик", "Haptika", "Ҳаптика"),
                        icon: "hand.tap.fill",
                        isOn: $appearance.hapticsEnabled
                    )
                }
                .padding(.horizontal, 16)
            }

            if let bookingNumber, !bookingNumber.isEmpty {
                glassCard {
                    HStack(spacing: 12) {
                        Image(systemName: "suitcase.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 38, height: 38)
                            .iumrahGlass(in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Booking", "Бронирование", "Bron", "Брон"))
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            Text(bookingNumber)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundStyle(primaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                }
            }
        }
    }

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 76), spacing: 14)],
                alignment: .center,
                spacing: 20
            ) {
                wallpaperCircle(.none)
                customPhotoCircle
                wallpaperCircle(.dawn)
                wallpaperCircle(.sky)
                wallpaperCircle(.water)
                wallpaperCircle(.aurora)
            }

            VStack(alignment: .leading, spacing: 15) {
                Text(tr("Suggestions", "Предложения", "Takliflar", "Таклифлар"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(primaryText)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    spacing: 14
                ) {
                    wallpaperCard(.makkah)
                    wallpaperCard(.sand)
                    wallpaperCard(.aurora)
                    wallpaperCard(.water)
                }
            }
        }
    }

    private func wallpaperCircle(_ wallpaper: CareChatWallpaper) -> some View {
        Button {
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
            appearance.select(wallpaper)
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CareWallpaperPreview(wallpaper: wallpaper, customImage: appearance.customImage)
                        .frame(width: 76, height: 76)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(
                                appearance.wallpaper == wallpaper ? Color.white : Color.white.opacity(0.18),
                                lineWidth: appearance.wallpaper == wallpaper ? 3 : 0.8
                            )
                        }
                        .shadow(color: .black.opacity(0.11), radius: 9, y: 5)

                    if appearance.wallpaper == wallpaper {
                        selectionBadge
                            .offset(x: 2, y: 2)
                    }
                }

                Text(wallpaper.title(language))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .buttonStyle(.plain)
    }

    private var customPhotoCircle: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let image = appearance.customImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.88), Color.white.opacity(0.34)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(primaryText.opacity(0.66))
                            }
                        }
                    }
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(
                            appearance.wallpaper == .photo ? Color.white : Color.white.opacity(0.18),
                            lineWidth: appearance.wallpaper == .photo ? 3 : 0.8
                        )
                    }
                    .shadow(color: .black.opacity(0.11), radius: 9, y: 5)

                    if appearance.wallpaper == .photo {
                        selectionBadge.offset(x: 2, y: 2)
                    }
                }

                Text(CareChatWallpaper.photo.title(language))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(primaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private func wallpaperCard(_ wallpaper: CareChatWallpaper) -> some View {
        Button {
            if appearance.hapticsEnabled { IumrahHaptics.selection() }
            appearance.select(wallpaper)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CareWallpaperPreview(wallpaper: wallpaper, customImage: appearance.customImage)
                    .frame(height: 224)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.48)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                HStack(spacing: 8) {
                    Text(wallpaper.title(language))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    if appearance.wallpaper == wallpaper {
                        selectionBadge
                    }
                }
                .padding(14)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        Color.white.opacity(appearance.wallpaper == wallpaper ? 0.90 : 0.15),
                        lineWidth: appearance.wallpaper == wallpaper ? 2 : 0.8
                    )
            }
            .shadow(color: .black.opacity(0.13), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var selectionBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(.black)
            .frame(width: 25, height: 25)
            .background(Color.white, in: Circle())
            .overlay { Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.7) }
            .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 29, style: .continuous)
                    .stroke(Color.white.opacity(appearance.wallpaper.isVisual ? 0.16 : 0.22), lineWidth: 0.65)
            }
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(primaryText)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    private func settingsToggle(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 38, height: 38)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(primaryText)

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.vertical, 10)
    }

    private var displayName: String {
        let value = profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "iumrah Care" : value
    }

    private var roleTitle: String {
        let value = profile?.roleTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !value.isEmpty { return value }
        return tr("iumrah support", "Поддержка iumrah", "iumrah yordami", "iumrah ёрдами")
    }

    private var preferredPhone: String {
        let sa = profile?.phoneSA.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sa.isEmpty { return sa }
        return profile?.phoneUZ.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasTelegram: Bool {
        !(profile?.telegram.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
    }

    private var hasWhatsApp: Bool {
        !(profile?.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
    }

    private var primaryText: Color {
        appearance.wallpaper.isVisual ? .white : .primary
    }

    private var secondaryText: Color {
        appearance.wallpaper.isVisual ? .white.opacity(0.68) : .secondary
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

struct CareProfileAvatar: View {
    let profile: IumrahPublicProfile?
    let size: CGFloat

    var body: some View {
        Group {
            if let path = profile?.photoURL, let url = AppConfig.absoluteURL(path) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay { Circle().stroke(Color.white.opacity(0.48), lineWidth: 1) }
        .contentShape(Circle())
    }

    private var fallback: some View {
        Image("CareMark")
            .resizable()
            .scaledToFit()
            .padding(size * 0.12)
            .background(Color.white)
    }
}

struct CareGlassPressStyle<S: Shape>: ButtonStyle {
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .iumrahGlass(in: shape)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.80 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.77), value: configuration.isPressed)
    }
}
