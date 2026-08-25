import SwiftUI

struct AirportPickerView: View {
    @Environment(\.dismiss) private var dismiss
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
                        Text("Найдите аэропорт вылета")
                            .font(.headline)
                        Text("Можно искать по городу, названию или трёхбуквенному коду аэропорта — например TAS, Ташкент, Москва, Стамбул.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading && results.isEmpty {
                    ProgressView("Ищем аэропорты…")
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
                        if !isLoading && results.isEmpty && errorMessage == nil {
                            ContentUnavailableView("Ничего не найдено", systemImage: "airplane", description: Text("Попробуйте другой город или код аэропорта."))
                        }
                    }
                }
            }
            .navigationTitle("Аэропорт вылета")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Город или IATA")
            .task {
                if query.isEmpty {
                    query = selection?.iata ?? fallbackCode
                }
            }
            .task(id: query) {
                await search()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
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
            errorMessage = error.localizedDescription
        }
    }
}
