import SwiftUI

struct AirportSelectorButton: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @Binding var airport: Airport?
    @Binding var fallbackCode: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
            IumrahHaptics.soft()
        } label: {
            HStack(spacing: 13) {
                IumrahIconBadge(
                    systemName: "airplane.departure",
                    role: .travel,
                    size: 38,
                    symbolSize: 17,
                    shape: .circle
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("airport_title", settings.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let airport {
                        Text(airport.compactTitle)
                            .font(.headline)
                        Text(airport.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(fallbackCode.isEmpty ? L10n.text("airport_search_title", settings.language) : fallbackCode.uppercased())
                            .font(.headline)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous), interactive: true)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            AirportPickerView(selection: $airport, fallbackCode: $fallbackCode)
        }
    }
}
