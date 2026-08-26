import SwiftUI
import UIKit

struct BookingChatView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    let bookingID: String

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var failedDraft: String?
    @State private var isSending = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @FocusState private var composerFocused: Bool

    var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                conversationHeader

                ZStack {
                    Color.iumrahPageBackground
                    if isLoading {
                        ProgressView(L10n.text("chat_load", settings.language))
                    } else if messages.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(messages) { message in
                                    bubble(message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, IumrahDesign.pagePadding)
                            .padding(.vertical, 18)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: messages.count) { _, _ in
                            scrollToLatest(proxy)
                        }
                    }
                }

                if let errorMessage {
                    errorBar(errorMessage)
                }

                composer
            }
            .background(Color.iumrahPageBackground)
            .task {
                await load()
                scrollToLatest(proxy, animated: false)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    await load(silent: true)
                }
            }
        }
        .iumrahInternalNavigation()
    }

    private var conversationHeader: some View {
        HStack(spacing: 14) {
            Image("CareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .padding(4)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(session?.travelerName ?? bookingID)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.iumrahCareLight)
                        .frame(width: 7, height: 7)
                    Text("iumrah Care · \(L10n.text("chat_online", settings.language))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 12)
        .background(Color.iumrahPageBackground)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            VStack(alignment: .leading, spacing: 5) {
                Text(isMine ? L10n.text("chat_you", settings.language) : L10n.text("chat_staff", settings.language))
                    .font(.caption2.weight(.bold))
                    .foregroundColor(isMine ? Color.secondary : Color.white.opacity(0.72))
                if message.messageType == "image", let attachmentID = message.attachmentID, let accessToken = session?.accessToken {
                    AuthenticatedChatImage(bookingID: bookingID, attachmentID: attachmentID, accessToken: accessToken)
                }
                if !message.body.isEmpty && !(message.messageType == "image" && message.body == "Фотография") {
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
        HStack(alignment: .bottom, spacing: 10) {
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
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
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
            messages = loaded.sorted { lhs, rhs in lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt < rhs.createdAt }
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

private extension ISO8601DateFormatter {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}


private struct AuthenticatedChatImage: View {
    let bookingID: String
    let attachmentID: String
    let accessToken: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .frame(width: 180, height: 120)
            }
        }
        .frame(maxWidth: 240, maxHeight: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: attachmentID) {
            guard image == nil else { return }
            if let data = try? await ChatService().loadAttachment(bookingID: bookingID, attachmentID: attachmentID, accessToken: accessToken),
               let loaded = UIImage(data: data) {
                image = loaded
            }
        }
    }
}
