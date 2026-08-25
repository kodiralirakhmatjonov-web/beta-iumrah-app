import SwiftUI

struct AirportPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @Binding var selection: Airport?
    @Binding var fallbackCode: String

    @State private var query = ""
    @State private var results: [Airport] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = AirportSearchService()

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "airplane.circle")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text(L10n.text("airport_search_title", settings.language))
                            .font(.headline)
                        Text(L10n.text("airport_search_body", settings.language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading && results.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { airport in
                        Button {
                            selection = airport
                            fallbackCode = airport.iata
                            IumrahHaptics.selection()
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Text(airport.iata)
                                    .font(.headline.monospaced())
                                    .frame(width: 54, height: 42)
                                    .background(Color.iumrahRaisedBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(airport.city)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(airport.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                    .overlay {
                        if !isLoading && results.isEmpty {
                            if let errorMessage {
                                ContentUnavailableView(
                                    L10n.text("airport_search_failed", settings.language),
                                    systemImage: "wifi.exclamationmark",
                                    description: Text(errorMessage)
                                )
                            } else {
                                ContentUnavailableView(
                                    L10n.text("airport_none", settings.language),
                                    systemImage: "airplane",
                                    description: Text(L10n.text("airport_none_body", settings.language))
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("airport_title", settings.language))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.text("airport_search_title", settings.language))
            .task {
                if query.isEmpty { query = selection?.iata ?? fallbackCode }
            }
            .task(id: query) { await search() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("close", settings.language)) { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func search() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await service.search(value, limit: 10)
        } catch {
            results = []
            errorMessage = L10n.error(error, settings.language)
        }
    }
}
