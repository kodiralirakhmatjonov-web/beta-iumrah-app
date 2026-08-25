import SwiftUI

struct BookingChatView: View {
    @EnvironmentObject private var bookings: BookingStore
    @EnvironmentObject private var settings: AppSettingsStore
    let bookingID: String

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    var session: StoredBookingSession? { bookings.booking(id: bookingID) }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header

                ZStack {
                    Color.iumrahPageBackground
                    if isLoading {
                        ProgressView(L10n.text("chat_load", settings.language))
                    } else if messages.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    bubble(message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, IumrahDesign.pagePadding)
                            .padding(.vertical, 18)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Button(L10n.text("chat_retry", settings.language)) {
                        Task { await load() }
                    }
                    .buttonStyle(IumrahSecondaryButtonStyle())
                    .padding(.horizontal, IumrahDesign.pagePadding)
                    .padding(.bottom, 8)
                    .overlay(alignment: .topLeading) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, IumrahDesign.pagePadding)
                            .offset(y: -10)
                    }
                }

                composer
            }
            .background(Color.iumrahPageBackground)
            .task {
                await load()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    await load(silent: true)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image("CareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(session?.travelerName ?? bookingID)
                    .font(.headline)
                HStack(spacing: 6) {
                    Circle().fill(Color.iumrahCareLight).frame(width: 7, height: 7)
                    Text("Aiomra Care · \(L10n.text("chat_online", settings.language))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 12)
        .background(Color.iumrahPageBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "message")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
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
        let isMine = message.senderType.lowercased() == "pilgrim"
        return HStack {
            if isMine { Spacer(minLength: 34) }
            VStack(alignment: .leading, spacing: 5) {
                Text(isMine ? L10n.text("chat_you", settings.language) : L10n.text("chat_staff", settings.language))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isMine ? .secondary : .white.opacity(0.72))
                Text(message.body)
                    .font(.body)
                    .foregroundStyle(isMine ? .primary : .white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(chatTimeLabel(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(isMine ? .secondary : .white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(isMine ? Color.iumrahCardBackground : LinearGradient(colors: [.iumrahCareDark, .iumrahCareLight], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: isMine ? .bottomTrailing : .bottomLeading) {
                Circle().fill(isMine ? Color.iumrahCardBackground : Color.iumrahCareDark).frame(width: 10, height: 10).offset(x: isMine ? 2 : -2, y: 2)
            }
            if !isMine { Spacer(minLength: 34) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(L10n.text("chat_placeholder", settings.language), text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.iumrahCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
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
                .foregroundStyle(.white)
                .background((draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending) ? Color.secondary.opacity(0.45) : Color.iumrahCareDark)
                .clipShape(Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    @MainActor
    private func load(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { isLoading = false }
        do {
            let loaded = try await bookings.loadChat(for: bookingID)
            messages = loaded.sorted(by: { $0.id < $1.id })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func send() async {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSending else { return }
        isSending = true
        do {
            _ = try await bookings.send(message: message, for: bookingID)
            draft = ""
            messages = bookings.chats[bookingID] ?? messages
            errorMessage = nil
            IumrahHaptics.selection()
        } catch {
            errorMessage = error.localizedDescription
            IumrahHaptics.error()
        }
        isSending = false
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
