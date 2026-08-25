import SwiftUI

struct IumrahRootPageTitle: View {
    @EnvironmentObject private var chrome: AppChromeStore
    @EnvironmentObject private var settings: AppSettingsStore

    let title: String
    var showsMakkahTime = false
    var lightStyle = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .tracking(-1.0)
                .foregroundStyle(lightStyle ? Color.white : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: showsMakkahTime ? 8 : 0) {
                Button {
                    chrome.openDrawer()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(lightStyle ? Color.white : Color.primary)
                        .frame(width: 46, height: 46)
                        .background {
                            Circle()
                                .fill(lightStyle ? Color.black.opacity(0.24) : Color.iumrahCardBackground)
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(lightStyle ? Color.white.opacity(0.16) : Color.primary.opacity(0.06), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("drawer_open", settings.language))

                if showsMakkahTime {
                    MakkahClockView(lightStyle: lightStyle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MakkahClockView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    var lightStyle = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .trailing, spacing: 1) {
                Text(L10n.text("makkah_time", settings.language))
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(timeString(context.date))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(lightStyle ? Color.white.opacity(0.96) : Color.secondary)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
