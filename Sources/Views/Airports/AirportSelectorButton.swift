import SwiftUI

struct AirportSelectorButton: View {
    @Binding var airport: Airport?
    @Binding var fallbackCode: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
            IumrahHaptics.soft()
        } label: {
            HStack(spacing: 13) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(Color.iumrahRaisedBackground)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Аэропорт вылета")
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
                        Text(fallbackCode.isEmpty ? "Выберите аэропорт" : fallbackCode.uppercased())
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
            .background(Color.iumrahRaisedBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            AirportPickerView(selection: $airport, fallbackCode: $fallbackCode)
        }
    }
}
