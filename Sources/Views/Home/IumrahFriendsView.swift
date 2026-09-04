import SwiftUI

struct IumrahFriendsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.dismiss) private var dismiss

    @State private var dashboard: IumrahFriendsDashboard?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                hero

                if account.isAuthenticated {
                    if isLoading && dashboard == nil {
                        loadingCard
                    } else if let dashboard {
                        balanceCard(dashboard)
                        giftsSection(dashboard)
                        rulesCard
                    }
                } else {
                    lockedCard
                    rulesCard
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, IumrahDesign.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 42)
        }
        .background(Color.iumrahPageBackground)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .task(id: account.bearerToken) { await loadDashboard() }
        .refreshable { await loadDashboard() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                IumrahHaptics.soft()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .iumrahGlass(in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("iumrah Friends")
                    .font(.headline)
                Text(tr("Umrah Gifts", "Подарки для умры", "Umrah sovg‘alari", "Умра совғалари"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color.iumrahCareDark.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 190, height: 190)
                .offset(x: 175, y: -75)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    Spacer()
                    Text("3 × $100")
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .iumrahGlass(in: Capsule())
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("iumrah Friends")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(-0.6)
                    Text(tr(
                        "Give $100 toward someone’s Umrah. When your friend pays for the journey, you earn $100 iumrah Credit.",
                        "Подарите другу $100 на умру. Когда друг оплатит поездку, Вы получите $100 iumrah Credit.",
                        "Do‘stingizga Umrah uchun $100 sovg‘a qiling. U safarni to‘lagach, Siz $100 iumrah Credit olasiz.",
                        "Дўстингизга Умра учун $100 совға қилинг. У сафарни тўлагач, Сиз $100 iumrah Credit оласиз."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(22)
        }
        .frame(minHeight: 235)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 26, y: 12)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(tr("Preparing your Gifts…", "Готовим Ваши Gift-карты…", "Gift kartalaringiz tayyorlanmoqda…", "Gift карталарингиз тайёрланмоқда…"))
                .font(.subheadline.weight(.medium))
        }
        .iumrahCard()
    }

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 50, height: 50)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            Text(tr("Unlock your 3 Umrah Gifts", "Откройте 3 Umrah Gift-карты", "3 ta Umrah Gift kartasini oching", "3 та Umrah Gift картасини очинг"))
                .font(.title3.bold())
            Text(tr(
                "Sign in or create your iumrah account. Every registered pilgrim receives three $100 Gifts to share.",
                "Войдите или создайте аккаунт iumrah. Каждый зарегистрированный паломник получает три Gift-карты по $100 для друзей.",
                "iumrah akkauntingizga kiring yoki yarating. Har bir ro‘yxatdan o‘tgan ziyoratchi do‘stlari uchun uchta $100 Gift oladi.",
                "iumrah аккаунтингизга киринг ёки яратинг. Ҳар бир рўйхатдан ўтган зиёратчи дўстлари учун учта $100 Gift олади."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                dismiss()
                chrome.navigate(to: .account)
            } label: {
                HStack {
                    Text(tr("Open iumrah account", "Открыть аккаунт iumrah", "iumrah akkauntini ochish", "iumrah аккаунтини очиш"))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(IumrahPrimaryButtonStyle())
        }
        .iumrahCard()
    }

    private func balanceCard(_ value: IumrahFriendsDashboard) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Your iumrah Credit", "Ваш iumrah Credit", "Sizning iumrah Credit", "Сизнинг iumrah Credit"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(money(value.availableCreditUsd))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                }
                Spacer()
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack(spacing: 10) {
                metric(title: tr("Pending", "Ожидается", "Kutilmoqda", "Кутилмоқда"), value: money(value.pendingRewardsUsd), icon: "clock.fill")
                metric(title: tr("Earned", "Заработано", "Ishlangan", "Ишланган"), value: money(value.earnedRewardsUsd), icon: "checkmark.circle.fill")
            }
        }
        .iumrahCard()
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.bold))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.iumrahRaisedBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func giftsSection(_ value: IumrahFriendsDashboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Your Gifts", "Ваши подарки", "Sovg‘alaringiz", "Совғаларингиз"))
                    .font(.title3.bold())
                Spacer()
                Text("\(value.gifts.filter(\.isAvailable).count)/3")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(.secondary)
            }

            ForEach(value.gifts) { gift in
                giftCard(gift)
            }
        }
    }

    private func giftCard(_ gift: IumrahFriendGift) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("$100")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                    Text(tr("Umrah Gift", "Umrah Gift", "Umrah Gift", "Umrah Gift"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(giftState(gift))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(gift.isAvailable ? Color.green.opacity(0.10) : Color.iumrahRaisedBackground, in: Capsule())
                    .foregroundStyle(gift.isAvailable ? Color.green : Color.secondary)
            }

            Text(gift.code)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .tracking(0.7)
                .textSelection(.enabled)

            if gift.isAvailable {
                ShareLink(item: shareText(gift)) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text(tr("Send Umrah Gift", "Отправить Umrah Gift", "Umrah Gift yuborish", "Umrah Gift юбориш"))
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 15)
                    .frame(height: 50)
                    .foregroundStyle(.primary)
                    .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if gift.isRewardEarned {
                Label(tr("$100 added to iumrah Credit", "$100 зачислены в iumrah Credit", "$100 iumrah Credit ga qo‘shildi", "$100 iumrah Credit га қўшилди"), systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Label(tr("$100 reward after your friend pays", "$100 будут начислены после оплаты друга", "Do‘stingiz to‘lagach $100 hisoblanadi", "Дўстингиз тўлагач $100 ҳисобланади"), systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .iumrahCard()
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 18, weight: .semibold))
                Text(tr("How Friends works", "Как работает Friends", "Friends qanday ishlaydi", "Friends қандай ишлайди"))
                    .font(.headline)
            }

            rule("1", tr("Your friend receives $100 toward their first eligible iumrah booking.", "Друг получает $100 на первое подходящее бронирование iumrah.", "Do‘stingiz birinchi mos iumrah broniga $100 oladi.", "Дўстингиз биринчи мос iumrah бронига $100 олади."))
            rule("2", tr("You receive $100 iumrah Credit only after the friend’s booking is paid.", "Вы получаете $100 iumrah Credit только после оплаты бронирования другом.", "Do‘stingiz bronni to‘lagandan keyingina Siz $100 iumrah Credit olasiz.", "Дўстингиз бронни тўлагандан кейингина Сиз $100 iumrah Credit оласиз."))
            rule("3", tr("Trips up to $2,000 can use up to $100 Friends benefit. Above $2,000, up to $200.", "Для поездки до $2,000 применяется максимум $100 Friends. Свыше $2,000 — максимум $200.", "$2,000 gacha bo‘lgan safarda Friends limiti $100. $2,000 dan yuqori — $200 gacha.", "$2,000 гача бўлган сафарда Friends лимити $100. $2,000 дан юқори — $200 гача."))
            rule("4", tr("iumrah Security Confirmation protects Gifts from duplicate identities and self-referrals.", "iumrah Security Confirmation защищает Gift-карты от повторных личностей и саморефералов.", "iumrah Security Confirmation Gift kartalarni takroriy shaxs va o‘z-o‘ziga referral qilishdan himoya qiladi.", "iumrah Security Confirmation Gift карталарни такрорий шахс ва ўз-ўзига referral қилишдан ҳимоя қилади."))
        }
        .iumrahCard()
    }

    private func rule(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number)
                .font(.caption.monospaced().weight(.bold))
                .frame(width: 28, height: 28)
                .background(Color.iumrahRaisedBackground, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func giftState(_ gift: IumrahFriendGift) -> String {
        if gift.isAvailable { return tr("AVAILABLE", "ДОСТУПНА", "MAVJUD", "МАВЖУД") }
        if gift.isRewardEarned { return tr("EARNED", "ЗАЧИСЛЕНО", "HISOBLANDI", "ҲИСОБЛАНДИ") }
        return tr("PENDING", "ОЖИДАНИЕ", "KUTILMOQDA", "КУТИЛМОҚДА")
    }

    private func shareText(_ gift: IumrahFriendGift) -> String {
        let sender = account.account?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (sender?.isEmpty == false ? sender! : "iumrah Friend")
        return tr(
            "🎁 \(name) sent you a $100 Umrah Gift. Use code \(gift.code) on your first eligible iumrah booking. https://iumrah.app/friends?gift=\(gift.code)",
            "🎁 \(name) отправил(а) Вам Umrah Gift на $100. Используйте код \(gift.code) при первом подходящем бронировании iumrah. https://iumrah.app/friends?gift=\(gift.code)",
            "🎁 \(name) Sizga $100 Umrah Gift yubordi. Birinchi mos iumrah bronida \(gift.code) kodidan foydalaning. https://iumrah.app/friends?gift=\(gift.code)",
            "🎁 \(name) Сизга $100 Umrah Gift юборди. Биринчи мос iumrah бронида \(gift.code) кодидан фойдаланинг. https://iumrah.app/friends?gift=\(gift.code)"
        )
    }

    @MainActor
    private func loadDashboard() async {
        guard account.isAuthenticated else {
            dashboard = nil
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            dashboard = try await account.friendsDashboard()
            errorMessage = nil
        } catch {
            errorMessage = L10n.error(error, settings.language)
        }
    }

    private func money(_ value: Double) -> String {
        "$\(Int(value.rounded()))"
    }

    private func tr(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch settings.language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }
}
