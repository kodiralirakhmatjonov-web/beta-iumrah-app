import PhotosUI
import SwiftUI
import UIKit

struct BookingChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var chrome: AppChromeStore
    let bookingID: String

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var failedDraft: String?
    @State private var isSending = false
    @State private var isSendingPhoto = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var registeredImmersive = false
    @FocusState private var composerFocused: Bool

    var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ZStack {
                    Color.iumrahPageBackground
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            careBanner
                                .padding(.bottom, 5)

                            if isLoading && messages.isEmpty {
                                ProgressView(L10n.text("chat_load", settings.language))
                                    .padding(.top, 42)
                            } else if messages.isEmpty {
                                emptyState
                                    .padding(.top, 18)
                            } else {
                                ForEach(messages) { message in
                                    bubble(message)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding(.horizontal, IumrahDesign.pagePadding)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _, _ in
                        scrollToLatest(proxy)
                    }
                }

                if let errorMessage {
                    errorBar(errorMessage)
                }

                composer
            }
            .background(Color.iumrahPageBackground)
            .task {
                await PushNotificationManager.shared.ensureAuthorizationForBookedTrips(hasBookings: true)
                await load()
                scrollToLatest(proxy, animated: false)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(6))
                    await load(silent: true)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) { chatNavigationHeader }
        .onAppear {
            guard !registeredImmersive else { return }
            registeredImmersive = true
            chrome.beginInternalNavigation()
        }
        .onDisappear {
            guard registeredImmersive else { return }
            registeredImmersive = false
            chrome.endInternalNavigation()
        }
        .onChange(of: selectedPhoto) { _, item in
            if let item { Task { await sendPhoto(item) } }
        }
    }

    private var chatNavigationHeader: some View {
        HStack(spacing: 12) {
            Button {
                IumrahHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("iumrah Care")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.82))

            Spacer()

            NavigationLink {
                BookingDetailView(bookingID: bookingID)
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.top, 7)
        .padding(.bottom, 10)
        .background {
            ZStack(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        Color.iumrahPageBackground.opacity(0.96),
                        Color.iumrahPageBackground.opacity(0.72),
                        Color.iumrahPageBackground.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 86)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var careBanner: some View {
        HStack(spacing: 12) {
            Image("CareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .padding(5)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("iumrah Care")
                    .font(.subheadline.weight(.bold))
                Text(careSupportText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.iumrahCareLight.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.iumrahCareLight.opacity(0.20), lineWidth: 1)
        }
    }

    private var careSupportText: String {
        switch settings.language {
        case .russian: return "Поддержка рядом на всех этапах вашей поездки."
        case .english: return "Support by your side throughout your journey."
        case .uzbek: return "Safaringizning barcha bosqichlarida yoningizdagi yordam."
        case .uzbekCyrillic: return "Сафарингизнинг барча босқичларида ёнингиздаги ёрдам."
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image("CareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .padding(8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(L10n.text("chat_empty_title", settings.language))
                .font(.headline)
            Text(L10n.text("chat_empty_body", settings.language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let isMine = ["client", "pilgrim"].contains(message.senderType.lowercased())
        return HStack(alignment: .bottom, spacing: 8) {
            if isMine { Spacer(minLength: 46) }

            if !isMine {
                Image("CareMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .background(Color.white)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isMine ? L10n.text("chat_you", settings.language) : "iumrah Care")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(isMine ? Color.secondary : Color.white.opacity(0.72))

                if message.messageType == "image", let path = message.attachmentURL {
                    AuthenticatedChatImage(path: path, bookingID: bookingID)
                        .frame(maxWidth: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }

                if !message.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.body)
                        .font(.body)
                        .foregroundColor(isMine ? Color.primary : Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(chatTimeLabel(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(isMine ? Color.secondary : Color.white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background {
                if isMine {
                    Color.iumrahCardBackground
                } else {
                    LinearGradient(
                        colors: [Color.iumrahCareDark, Color.iumrahCareLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isMine ? Color.primary.opacity(0.055) : Color.clear, lineWidth: 1)
            }

            if !isMine { Spacer(minLength: 46) }
        }
    }

    private func errorBar(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)

            Button(L10n.text("chat_retry", settings.language)) {
                if let failedDraft, !failedDraft.isEmpty {
                    draft = failedDraft
                    Task { await send() }
                } else {
                    Task { await load() }
                }
            }
            .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.055))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Group {
                    if isSendingPhoto {
                        ProgressView()
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .semibold))
                    }
                }
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
            }
            .disabled(isSending || isSendingPhoto)

            TextField(L10n.text("chat_placeholder", settings.language), text: $draft, axis: .vertical)
                .focused($composerFocused)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.iumrahCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
                }

            Button {
                Task { await send() }
            } label: {
                Group {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .frame(width: 50, height: 50)
                .foregroundColor(.white)
                .background(sendButtonColor)
                .clipShape(Circle())
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && !isSendingPhoto
    }

    private var sendButtonColor: Color {
        canSend ? Color.iumrahCareDark : Color.secondary.opacity(0.45)
    }

    @MainActor
    private func load(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            let loaded = try await bookings.loadChat(for: bookingID)
            messages = loaded.sorted(by: { $0.createdAt < $1.createdAt })
            if failedDraft == nil { errorMessage = nil }
        } catch {
            if !silent { errorMessage = L10n.error(error, settings.language) }
        }
    }

    @MainActor
    private func send() async {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSending else { return }

        isSending = true
        errorMessage = nil
        failedDraft = nil
        do {
            _ = try await bookings.send(message: message, for: bookingID)
            draft = ""
            messages = bookings.chats[bookingID] ?? messages
            composerFocused = true
            IumrahHaptics.selection()
        } catch {
            failedDraft = message
            errorMessage = L10n.format("chat_send_failed", settings.language, L10n.error(error, settings.language))
            IumrahHaptics.error()
        }
        isSending = false
    }

    @MainActor
    private func sendPhoto(_ item: PhotosPickerItem) async {
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
            messages = bookings.chats[bookingID] ?? messages
            IumrahHaptics.selection()
        } catch {
            errorMessage = L10n.format("chat_send_failed", settings.language, L10n.error(error, settings.language))
            IumrahHaptics.error()
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let last = messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private func chatTimeLabel(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: raw) ?? ISO8601DateFormatter.fractional.date(from: raw) else { return "" }
        let output = DateFormatter()
        output.locale = Locale(identifier: settings.language.localeIdentifier)
        output.dateFormat = "HH:mm"
        return output.string(from: date)
    }
}

private struct AuthenticatedChatImage: View {
    @EnvironmentObject private var bookings: BookingStore
    let path: String
    let bookingID: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Color.black.opacity(0.05)
                    ProgressView()
                }
                .frame(width: 220, height: 150)
            }
        }
        .task(id: path) {
            guard image == nil,
                  let data = try? await bookings.chatAttachmentData(path: path, bookingID: bookingID),
                  let loaded = UIImage(data: data) else { return }
            image = loaded
        }
    }
}

private func optimizedChatJPEG(_ data: Data) -> Data? {
    guard let image = UIImage(data: data) else { return nil }
    let maxSide: CGFloat = 1600
    let sourceSize = image.size
    let largest = max(sourceSize.width, sourceSize.height)
    let scale = largest > maxSide ? maxSide / largest : 1
    let target = CGSize(width: max(1, sourceSize.width * scale), height: max(1, sourceSize.height * scale))
    let renderer = UIGraphicsImageRenderer(size: target)
    let normalized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: target))
    }
    return normalized.jpegData(compressionQuality: 0.80)
}

private extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
