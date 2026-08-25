import SwiftUI

struct UmrahHomeView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 34, weight: .medium))
                .frame(width: 72, height: 72)
                .background(Color.iumrahRaisedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(L10n.text("tab_umrah", settings.language))
                .font(.system(size: 31, weight: .bold, design: .rounded))

            Text(descriptionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.iumrahPageBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var descriptionText: String {
        switch settings.language {
        case .english:
            return "Step-by-step Umrah guidance will be added here in a later update."
        case .russian:
            return "Пошаговое сопровождение Умры мы добавим сюда в одном из следующих обновлений."
        case .uzbek:
            return "Umra bo‘yicha bosqichma-bosqich yo‘riqnoma keyingi yangilanishlardan birida shu yerga qo‘shiladi."
        case .uzbekCyrillic:
            return "Умра бўйича босқичма-босқич йўриқнома кейинги янгиланишлардан бирида шу ерга қўшилади."
        }
    }
}
