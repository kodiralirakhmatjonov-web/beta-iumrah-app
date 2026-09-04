import PhotosUI
import SwiftUI
import UIKit

struct BookingChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore

    let bookingID: String

    @StateObject private var appearance: CareChatAppearanceStore

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var failedDraft: String?
    @State private var pendingOutgoing: PendingOutgoingMessage?
    @State private var launchingOutgoing: PendingOutgoingMessage?
    @State private var isSending = false
    @State private var isSendingPhoto = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var registeredImmersive = false
    @State private var careProfile: IumrahPublicProfile?
    @State private var showCareProfile = false
    @State private var isAtBottom = true
    @State private var unseenIncomingCount = 0
    @State private var presentationByID: [String: CareMessagePresentation] = [:]
    @FocusState private var composerFocused: Bool
    @GestureState private var timestampReveal: CGFloat = 0
    @State private var scrollViewportHeight: CGFloat = 0
    @Namespace private var sendNamespace
    @Namespace private var profileNamespace

    private let bottomAnchorID = "care-chat-bottom-anchor"
    private let scrollCoordinateSpace = "care-chat-scroll-space"

    init(bookingID: String) {
        self.bookingID = bookingID
        _appearance = StateObject(wrappedValue: CareChatAppearanceStore(bookingID: bookingID))
    }

    private var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                CareConversationBackground(
                    wallpaper: appearance.wallpaper,
                    customImage: appearance.customImage,
                    motionEnabled: !showCareProfile
                )

                conversation(proxy: proxy)

                if showCareProfile {
                    CareContactInfoView(
                        appearance: appearance,
                        profile: careProfile,
                        language: settings.language,
                        bookingNumber: session?.displayBookingNumber,
                        onCall: openPhone,
                        onTelegram: openTelegram,
                        onWhatsApp: openWhatsApp,
                        onRequestFounder: {
                            await requestFounderReview(proxy: proxy)
                        },
                        transitionNamespace: profileNamespace,
                        onClose: {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
                                showCareProfile = false
                            }
                        }
                    )
                    .zIndex(20)
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !showCareProfile {
                    chatNavigationHeader
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !showCareProfile {
                    VStack(spacing: 0) {
                        if let errorMessage {
                            errorBar(errorMessage, proxy: proxy)
                        }
                        composer(proxy: proxy)
                    }
                }
            }
            .task {
                await PushNotificationManager.shared.ensureAuthorizationForBookedTrips(hasBookings: true)
                await loadCareProfile()
                await load(proxy: proxy)
                await Task.yield()
                scrollToLatest(proxy, animated: false)

                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(6))
                    await load(silent: true, proxy: proxy)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await sendPhoto(item, proxy: proxy) }
            }
            .onChange(of: composerFocused) { _, focused in
                guard focused else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    scrollToLatest(proxy)
                }
            }
            .onChange(of: messages) { _, _ in
                rebuildMessagePresentation()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            CareChatFeedback.shared.prepare()
            guard !registeredImmersive else { return }
            registeredImmersive = true
            chrome.beginInternalNavigation()
        }
        .onDisappear {
            guard registeredImmersive else { return }
            registeredImmersive = false
            chrome.endInternalNavigation()
        }
    }

    // MARK: - Conversation

    private func conversation(proxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if isLoading && messages.isEmpty {
                        loadingState
                            .padding(.top, 88)
                    } else if messages.isEmpty && pendingOutgoing == nil {
                        emptyState
                            .padding(.top, 78)
                    } else {
                        messageHistory
                    }

                    if let pendingOutgoing {
                        pendingBubble(pendingOutgoing)
                            .id(pendingOutgoing.id)
                            .padding(.top, 4)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom)
                                        .combined(with: .scale(scale: 0.94, anchor: .bottomTrailing))
                                        .combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }

                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: CareChatBottomYPreferenceKey.self,
                                value: geometry.frame(in: .named(scrollCoordinateSpace)).maxY
                            )
                    }
                    .frame(height: 2)
                    .id(bottomAnchorID)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentMargins(.bottom, 0, for: .scrollContent)
            .coordinateSpace(name: scrollCoordinateSpace)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { scrollViewportHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { _, newValue in
                            scrollViewportHeight = newValue
                        }
                }
            }
            .onPreferenceChange(CareChatBottomYPreferenceKey.self) { bottomY in
                guard scrollViewportHeight > 0 else { return }
                let nearBottom = bottomY <= scrollViewportHeight + 84
                if nearBottom != isAtBottom {
                    withAnimation(.easeOut(duration: 0.16)) {
                        isAtBottom = nearBottom
                    }
                }
                if nearBottom {
                    unseenIncomingCount = 0
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .updating($timestampReveal) { value, state, _ in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard dx < 0, abs(dx) > abs(dy) * 1.2 else { return }
                        state = min(1, max(0, -dx / 78))
                    }
            )

            if !isAtBottom && (!messages.isEmpty || pendingOutgoing != nil) {
                Button {
                    if appearance.hapticsEnabled { IumrahHaptics.selection() }
                    unseenIncomingCount = 0
                    scrollToLatest(proxy)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)

                        if unseenIncomingCount > 0 {
                            Text("\(min(unseenIncomingCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 20, minHeight: 20)
                                .background(Color.iumrahCareDark, in: Capsule())
                                .offset(x: 7, y: -6)
                        }
                    }
                    .foregroundStyle(conversationPrimary)
                }
                .careNativeGlassButton()
                .padding(.trailing, 16)
                .padding(.bottom, 14)
                .transition(.scale(scale: 0.86).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var messageHistory: some View {
        ForEach(messages) { message in
            let meta = presentationByID[message.id] ?? fallbackPresentation(for: message)

            if meta.showDateSeparator {
                dateSeparator(meta.dateSeparatorText)
                    .padding(.vertical, meta.isFirst ? 10 : 16)
            }

            CareChatMessageRow(
                message: message,
                bookingID: bookingID,
                language: settings.language,
                isMine: meta.isMine,
                groupStart: meta.groupStart,
                groupEnd: meta.groupEnd,
                showDelivery: meta.showDelivery,
                wallpaperActive: appearance.wallpaper.isVisual,
                timestampText: meta.timeText,
                timestampReveal: timestampReveal
            )
            .id(message.id)
            .padding(.bottom, meta.groupEnd ? 8 : 2)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .bottom)
                        .combined(with: .scale(scale: 0.96, anchor: meta.isMine ? .bottomTrailing : .bottomLeading))
                        .combined(with: .opacity),
                    removal: .opacity
                )
            )
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
            Text(L10n.text("chat_load", settings.language))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(conversationSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            CareProfileAvatar(profile: careProfile, size: 92)
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)

            VStack(spacing: 7) {
                Text(L10n.text("chat_empty_title", settings.language))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(conversationPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.text("chat_empty_body", settings.language))
                    .font(.system(size: 17))
                    .foregroundStyle(conversationSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
            }

            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(careSupportText)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
            }
            .foregroundStyle(conversationPrimary.opacity(0.82))
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().stroke(Color.white.opacity(appearance.wallpaper.isVisual ? 0.20 : 0.32), lineWidth: 0.6) }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func dateSeparator(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(conversationSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if appearance.wallpaper.isVisual {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .frame(maxWidth: .infinity)
    }

    private func pendingBubble(_ pending: PendingOutgoingMessage) -> some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 58)

            VStack(alignment: .trailing, spacing: 3) {
                Text(pending.body)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 13)
                    .padding(.trailing, 17)
                    .padding(.vertical, 9)
                    .background {
                        CareMessageBubbleShape(isMine: true, groupStart: true, groupEnd: true)
                            .fill(Color.iumrahCareDark.opacity(0.96))
                    }

                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(tr("Sending", "Отправляется", "Yuborilmoqda", "Юборилмоқда"))
                        .font(.system(size: 11.5))
                }
                .foregroundStyle(conversationSecondary)
                .padding(.trailing, 9)
            }
            .matchedGeometryEffect(id: "care-send-\(pending.id)", in: sendNamespace, isSource: false)
        }
    }

    // MARK: - Navigation Header

    private var chatNavigationHeader: some View {
        ZStack {
            CareNativeGlassContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        if appearance.hapticsEnabled { IumrahHaptics.soft() }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 21, weight: .semibold))
                            .frame(width: 46, height: 46)
                            .contentShape(Circle())
                    }
                    .foregroundStyle(headerPrimary)
                    .careNativeGlassButton()
                    .accessibilityLabel(tr("Back", "Назад", "Orqaga", "Орқага"))

                    Spacer(minLength: 96)

                    Button {
                        if appearance.hapticsEnabled { IumrahHaptics.selection() }
                        composerFocused = false
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
                            showCareProfile = true
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 22, weight: .medium))
                            .frame(width: 46, height: 46)
                            .contentShape(Circle())
                    }
                    .foregroundStyle(headerPrimary)
                    .careNativeGlassButton()
                    .accessibilityLabel(tr("Care information", "Информация iumrah Care", "iumrah Care ma’lumoti", "iumrah Care маълумоти"))
                }
            }

            Button {
                if appearance.hapticsEnabled { IumrahHaptics.selection() }
                composerFocused = false
                withAnimation(.spring(response: 0.42, dampingFraction: 0.92)) {
                    showCareProfile = true
                }
            } label: {
                VStack(spacing: 3) {
                    CareProfileAvatar(profile: nil, size: 52)
                        .matchedGeometryEffect(id: "care-profile-avatar", in: profileNamespace, isSource: !showCareProfile)
                        .shadow(color: .black.opacity(appearance.wallpaper.isVisual ? 0.20 : 0.08), radius: 7, y: 3)

                    HStack(spacing: 3) {
                        Text("iumrah Care")
                            .matchedGeometryEffect(id: "care-profile-name", in: profileNamespace, isSource: !showCareProfile)
                            .font(.system(size: 14.5, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8.5, weight: .bold))
                    }
                    .foregroundStyle(headerPrimary)
                }
                .frame(maxWidth: 176)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(showCareProfile ? 0 : 1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 5)
        .padding(.bottom, 8)
        .background {
            headerBackdrop
                .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private var headerBackdrop: some View {
        if appearance.wallpaper.isVisual {
            LinearGradient(
                colors: [Color.black.opacity(0.24), Color.black.opacity(0.07), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.86)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.035))
                        .frame(height: 0.5)
                }
        }
    }

    // MARK: - Composer

    private func composer(proxy: ScrollViewProxy) -> some View {
        CareNativeGlassContainer(spacing: 10) {
            HStack(alignment: .bottom, spacing: 9) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Group {
                        if isSendingPhoto {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .regular))
                        }
                    }
                    .foregroundStyle(composerControlColor)
                    .frame(width: 46, height: 46)
                    .contentShape(Circle())
                }
                .careNativeGlassButton()
                .disabled(isSending || isSendingPhoto)
                .accessibilityLabel(tr("Add photo", "Добавить фото", "Rasm qo‘shish", "Расм қўшиш"))

                HStack(alignment: .bottom, spacing: 7) {
                    TextField(L10n.text("chat_placeholder", settings.language), text: $draft, axis: .vertical)
                        .focused($composerFocused)
                        .font(.system(size: 17))
                        .lineLimit(1...5)
                        .submitLabel(.send)
                        .onSubmit {
                            guard canSend else { return }
                            Task { await send(proxy: proxy) }
                        }
                        .padding(.leading, 15)
                        .padding(.vertical, 11)

                    if canSend || isSending {
                        Button {
                            Task { await send(proxy: proxy) }
                        } label: {
                            Group {
                                if isSending {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 15.5, weight: .bold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                        }
                        .tint(Color.iumrahCareDark)
                        .careNativeGlassButton(prominent: true)
                        .disabled(!canSend)
                        .padding(.trailing, 5)
                        .padding(.bottom, 5)
                        .transition(.scale(scale: 0.72).combined(with: .opacity))
                    }
                }
                .frame(minHeight: 46)
                .careNativeGlassSurface(
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                    interactive: true
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.84), value: canSend)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .overlay(alignment: .bottomTrailing) {
            if let launchingOutgoing {
                Text(launchingOutgoing.body)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background {
                        CareMessageBubbleShape(isMine: true, groupStart: true, groupEnd: true)
                            .fill(Color.iumrahCareDark.opacity(0.98))
                    }
                    .matchedGeometryEffect(id: "care-send-\(launchingOutgoing.id)", in: sendNamespace, isSource: true)
                    .padding(.trailing, 16)
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
                    .zIndex(5)
            }
        }
        .background {
            composerBackdrop
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var composerBackdrop: some View {
        if appearance.wallpaper.isVisual {
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.055), Color.black.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.84)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.035))
                        .frame(height: 0.5)
                }
        }
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && !isSendingPhoto
    }

    private var composerControlColor: Color {
        appearance.wallpaper.isVisual ? .white : .primary
    }

    // MARK: - Error

    private func errorBar(_ message: String, proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.system(size: 13.5))
                .foregroundStyle(conversationPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(L10n.text("chat_retry", settings.language)) {
                if let failedDraft, !failedDraft.isEmpty {
                    draft = failedDraft
                    composerFocused = true
                    Task { await send(proxy: proxy) }
                } else {
                    Task { await load(proxy: proxy) }
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(conversationPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Loading / Sending

    @MainActor
    private func load(silent: Bool = false, proxy: ScrollViewProxy? = nil) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }

        do {
            let previousIDs = Set(messages.map(\.id))
            let hadExistingMessages = !messages.isEmpty
            let loaded = try await bookings.loadChat(for: bookingID)
                .sorted(by: { $0.createdAt < $1.createdAt })

            let newIncoming = loaded.filter { message in
                !previousIDs.contains(message.id) && !isMine(message)
            }

            if loaded != messages {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                    messages = loaded
                }
            }

            if failedDraft == nil { errorMessage = nil }

            guard silent, hadExistingMessages, !newIncoming.isEmpty else { return }

            if appearance.soundsEnabled {
                CareChatFeedback.shared.play(.receive)
            }
            if appearance.hapticsEnabled {
                IumrahHaptics.soft()
            }

            if isAtBottom, let proxy {
                scrollToLatest(proxy)
            } else {
                unseenIncomingCount += newIncoming.count
            }
        } catch {
            if !silent { errorMessage = L10n.error(error, settings.language) }
        }
    }

    @MainActor
    private func send(proxy: ScrollViewProxy) async {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSending else { return }

        isSending = true
        errorMessage = nil
        failedDraft = nil

        let pending = PendingOutgoingMessage(id: UUID().uuidString, body: message)
        launchingOutgoing = pending
        draft = ""

        await Task.yield()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            pendingOutgoing = pending
            launchingOutgoing = nil
        }

        if appearance.soundsEnabled {
            CareChatFeedback.shared.play(.send)
        }
        if appearance.hapticsEnabled {
            IumrahHaptics.selection()
        }

        await Task.yield()
        scrollToLatest(proxy)

        do {
            _ = try await bookings.send(message: message, for: bookingID)
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                messages = (bookings.chats[bookingID] ?? messages).sorted(by: { $0.createdAt < $1.createdAt })
                pendingOutgoing = nil
                launchingOutgoing = nil
            }
            composerFocused = true
            scrollToLatest(proxy)
        } catch {
            withAnimation(.easeOut(duration: 0.16)) {
                pendingOutgoing = nil
                launchingOutgoing = nil
            }
            draft = message
            failedDraft = message
            errorMessage = L10n.format("chat_send_failed", settings.language, L10n.error(error, settings.language))
            if appearance.soundsEnabled {
                CareChatFeedback.shared.play(.error)
            }
            if appearance.hapticsEnabled {
                IumrahHaptics.error()
            }
            composerFocused = true
        }

        isSending = false
    }

    @MainActor
    private func sendPhoto(_ item: PhotosPickerItem, proxy: ScrollViewProxy) async {
        selectedPhoto = nil
        isSendingPhoto = true
        errorMessage = nil
        defer { isSendingPhoto = false }

        do {
            guard let raw = try await item.loadTransferable(type: Data.self),
                  let data = optimizedChatJPEG(raw) else {
                throw APIError.invalidResponse
            }

            _ = try await bookings.sendPhoto(data: data, for: bookingID)
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                messages = (bookings.chats[bookingID] ?? messages).sorted(by: { $0.createdAt < $1.createdAt })
            }

            if appearance.soundsEnabled {
                CareChatFeedback.shared.play(.send)
            }
            if appearance.hapticsEnabled {
                IumrahHaptics.selection()
            }
            scrollToLatest(proxy)
        } catch {
            errorMessage = L10n.format("chat_send_failed", settings.language, L10n.error(error, settings.language))
            if appearance.soundsEnabled {
                CareChatFeedback.shared.play(.error)
            }
            if appearance.hapticsEnabled {
                IumrahHaptics.error()
            }
        }
    }

    // MARK: - Message Grouping / Dates

    private func isMine(_ message: ChatMessage) -> Bool {
        ["client", "pilgrim"].contains(message.senderType.lowercased())
    }

    private func isGroupStart(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index]
        let previous = messages[index - 1]
        guard isMine(current) == isMine(previous) else { return true }
        guard let currentDate = parsedDate(current.createdAt), let previousDate = parsedDate(previous.createdAt) else { return true }
        return currentDate.timeIntervalSince(previousDate) > 120 || shouldShowDateSeparator(at: index)
    }

    private func isGroupEnd(at index: Int) -> Bool {
        guard index < messages.count - 1 else { return true }
        let current = messages[index]
        let next = messages[index + 1]
        guard isMine(current) == isMine(next) else { return true }
        guard let currentDate = parsedDate(current.createdAt), let nextDate = parsedDate(next.createdAt) else { return true }
        return nextDate.timeIntervalSince(currentDate) > 120 || shouldShowDateSeparator(at: index + 1)
    }

    private func rowBottomSpacing(at index: Int) -> CGFloat {
        isGroupEnd(at: index) ? 8 : 2
    }

    private func shouldShowDelivery(for index: Int) -> Bool {
        guard isMine(messages[index]) else { return false }
        guard index == messages.count - 1 || !isMine(messages[index + 1]) else { return false }
        return index == messages.lastIndex(where: { isMine($0) })
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        guard let current = parsedDate(messages[index].createdAt),
              let previous = parsedDate(messages[index - 1].createdAt) else { return false }

        let calendar = Calendar.current
        if !calendar.isDate(current, inSameDayAs: previous) { return true }
        return current.timeIntervalSince(previous) >= 30 * 60
    }

    private func dateSeparatorLabel(_ raw: String) -> String {
        guard let date = parsedDate(raw) else { return "" }
        let calendar = Calendar.current
        let time = DateFormatter()
        time.locale = Locale(identifier: settings.language.localeIdentifier)
        time.dateFormat = "HH:mm"

        if calendar.isDateInToday(date) {
            return "\(tr("Today", "Сегодня", "Bugun", "Бугун")), \(time.string(from: date))"
        }

        if calendar.isDateInYesterday(date) {
            return "\(tr("Yesterday", "Вчера", "Kecha", "Кеча")), \(time.string(from: date))"
        }

        let output = DateFormatter()
        output.locale = Locale(identifier: settings.language.localeIdentifier)
        output.setLocalizedDateFormatFromTemplate("EEE d MMM HH:mm")
        return output.string(from: date)
    }

    private func messageTimeLabel(_ raw: String) -> String {
        guard let date = parsedDate(raw) else { return "" }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private func rebuildMessagePresentation() {
        guard !messages.isEmpty else {
            presentationByID = [:]
            return
        }

        var next: [String: CareMessagePresentation] = [:]
        next.reserveCapacity(messages.count)

        for index in messages.indices {
            let message = messages[index]
            let showDate = shouldShowDateSeparator(at: index)
            next[message.id] = CareMessagePresentation(
                isMine: isMine(message),
                groupStart: isGroupStart(at: index),
                groupEnd: isGroupEnd(at: index),
                showDelivery: shouldShowDelivery(for: index),
                showDateSeparator: showDate,
                dateSeparatorText: showDate ? dateSeparatorLabel(message.createdAt) : "",
                timeText: messageTimeLabel(message.createdAt),
                isFirst: index == messages.startIndex
            )
        }

        presentationByID = next
    }

    private func fallbackPresentation(for message: ChatMessage) -> CareMessagePresentation {
        CareMessagePresentation(
            isMine: isMine(message),
            groupStart: true,
            groupEnd: true,
            showDelivery: false,
            showDateSeparator: false,
            dateSeparatorText: "",
            timeText: messageTimeLabel(message.createdAt),
            isFirst: false
        )
    }

    private func parsedDate(_ raw: String) -> Date? {
        ISO8601DateFormatter.chatDefault.date(from: raw) ?? ISO8601DateFormatter.chatFractional.date(from: raw)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.90)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchorID, anchor: .bottom)
        }
    }

    @MainActor
    private func requestFounderReview(proxy: ScrollViewProxy) async -> Bool {
        guard !isSending && !isSendingPhoto else { return false }

        let message = tr(
            "Please connect Abdulaziz to this chat. I’d like the founder to review my trip once more.",
            "Подключите к чату Абдулазиза. Хочу, чтобы основатель ещё раз проверил мою поездку.",
            "Abdulazizni ushbu chatga ulang. Asoschi safarimni yana bir bor tekshirib chiqishini xohlayman.",
            "Абдулазизни ушбу чатга уланг. Асосчи сафаримни яна бир бор текшириб чиқишини хоҳлайман."
        )

        isSending = true
        errorMessage = nil
        failedDraft = nil

        let pending = PendingOutgoingMessage(id: UUID().uuidString, body: message)
        launchingOutgoing = pending
        await Task.yield()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            pendingOutgoing = pending
            launchingOutgoing = nil
        }

        if appearance.soundsEnabled { CareChatFeedback.shared.play(.send) }
        if appearance.hapticsEnabled { IumrahHaptics.selection() }
        await Task.yield()
        scrollToLatest(proxy)

        do {
            _ = try await bookings.send(message: message, for: bookingID)
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                messages = (bookings.chats[bookingID] ?? messages).sorted(by: { $0.createdAt < $1.createdAt })
                pendingOutgoing = nil
                launchingOutgoing = nil
            }
            isSending = false
            scrollToLatest(proxy)
            return true
        } catch {
            withAnimation(.easeOut(duration: 0.16)) {
                pendingOutgoing = nil
                launchingOutgoing = nil
            }
            failedDraft = message
            errorMessage = L10n.format("chat_send_failed", settings.language, L10n.error(error, settings.language))
            if appearance.soundsEnabled { CareChatFeedback.shared.play(.error) }
            if appearance.hapticsEnabled { IumrahHaptics.error() }
            isSending = false
            return false
        }
    }

    // MARK: - Care Profile Actions

    @MainActor
    private func loadCareProfile() async {
        guard careProfile == nil else { return }
        careProfile = try? await ChatService().loadCareProfile()
    }

    private var preferredPhone: String {
        let sa = careProfile?.phoneSA.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sa.isEmpty { return sa }
        return careProfile?.phoneUZ ?? ""
    }

    private func openPhone() {
        let digits = preferredPhone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel:\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    private func openTelegram() {
        guard let raw = careProfile?.telegram.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
        let url: URL?
        if raw.lowercased().hasPrefix("http") {
            url = URL(string: raw)
        } else {
            let username = raw
                .replacingOccurrences(of: "@", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            url = URL(string: "https://t.me/\(username)")
        }
        if let url { UIApplication.shared.open(url) }
    }

    private func openWhatsApp() {
        guard let raw = careProfile?.whatsapp.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
        if raw.lowercased().hasPrefix("http"), let url = URL(string: raw) {
            UIApplication.shared.open(url)
            return
        }
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "https://wa.me/\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Presentation Helpers

    private var careSupportText: String {
        tr(
            "Support by your side throughout your journey",
            "Поддержка рядом на всех этапах вашей поездки",
            "Safaringizning barcha bosqichlarida yoningizdagi yordam",
            "Сафарингизнинг барча босқичларида ёнингиздаги ёрдам"
        )
    }

    private var conversationPrimary: Color {
        appearance.wallpaper.isVisual ? .white : .primary
    }

    private var conversationSecondary: Color {
        appearance.wallpaper.isVisual ? .white.opacity(0.68) : .secondary
    }

    private var headerPrimary: Color {
        appearance.wallpaper.isVisual ? .white : .primary
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}

private struct CareMessagePresentation {
    let isMine: Bool
    let groupStart: Bool
    let groupEnd: Bool
    let showDelivery: Bool
    let showDateSeparator: Bool
    let dateSeparatorText: String
    let timeText: String
    let isFirst: Bool
}

private struct CareChatBottomYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PendingOutgoingMessage: Identifiable, Equatable {
    let id: String
    let body: String
}

private func optimizedChatJPEG(_ data: Data) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let maxSide: CGFloat = 1600
    let sourceSize = image.size
    let largest = max(sourceSize.width, sourceSize.height)
    let scale = largest > maxSide ? maxSide / largest : 1
    let target = CGSize(
        width: max(1, sourceSize.width * scale),
        height: max(1, sourceSize.height * scale)
    )
    let renderer = UIGraphicsImageRenderer(size: target)
    let normalized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: target))
    }
    return normalized.jpegData(compressionQuality: 0.80)
}

private extension ISO8601DateFormatter {
    static let chatDefault: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let chatFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
