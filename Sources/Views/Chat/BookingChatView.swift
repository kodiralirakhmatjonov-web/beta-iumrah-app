import SwiftUI

struct BookingChatView: View {
    @EnvironmentObject private var bookings: BookingStore
    let bookingID: String

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?

    private let service = ChatService()

    var body: some View {
        VStack(spacing: 0) {
            if let session = bookings.session(id: bookingID) {
                chatHeader(session)
                Divider()
                messagesView(session)
                composer(session)
            } else {
                ContentUnavailableView("Чат недоступен", systemImage: "bubble.left.and.exclamationmark.bubble.right")
            }
        }
        .background(Color.iumrahPageBackground)
        .navigationTitle("iumrah Care")
        .navigationBarTitleDisplayMode(.inline)
        .task { await pollingLoop() }
    }

    private func chatHeader(_ session: StoredBookingSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.iumrahRaisedBackground)
                Image(systemName: "heart.fill")
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("iumrah Care")
                    .font(.headline)
                Text(session.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("онлайн").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func messagesView(_ session: StoredBookingSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if isLoading && messages.isEmpty {
                        ProgressView("Загружаем чат…")
                            .padding(.top, 40)
                    } else if messages.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "message")
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary)
                            Text("Начните разговор")
                                .font(.headline)
                            Text("Спросите о бронировании, рейсе, отеле, трансфере или маршруте.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 50)
                    }

                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        let mine = message.senderType == "pilgrim"
        return HStack {
            if mine { Spacer(minLength: 46) }
            VStack(alignment: .leading, spacing: 5) {
                Text(mine ? "Вы" : "iumrah Care")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(message.body)
                    .font(.body)
                Text(time(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(mine ? Color.primary.opacity(0.10) : Color.iumrahCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            if !mine { Spacer(minLength: 46) }
        }
    }

    private func composer(_ session: StoredBookingSession) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Сообщение…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                Task { await send(session) }
            } label: {
                Group {
                    if isSending { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.up") }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.black)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func pollingLoop() async {
        guard let session = bookings.session(id: bookingID) else { return }
        await load(session, showLoader: true)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { break }
            await load(session, showLoader: false)
        }
    }

    @MainActor
    private func load(_ session: StoredBookingSession, showLoader: Bool) async {
        if showLoader { isLoading = true }
        defer { if showLoader { isLoading = false } }
        do {
            messages = try await service.messages(bookingId: session.id, accessToken: session.accessToken)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func send(_ session: StoredBookingSession) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            _ = try await service.send(String(text.prefix(2000)), bookingId: session.id, accessToken: session.accessToken)
            draft = ""
            IumrahHaptics.soft()
            await load(session, showLoader: false)
        } catch {
            errorMessage = error.localizedDescription
            IumrahHaptics.error()
        }
    }

    private func time(_ raw: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: raw) else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
