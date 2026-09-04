import SwiftUI

struct IumrahGiftCardsView: View {
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var account: IumrahAccountStore
    @EnvironmentObject private var chrome: AppChromeStore
    @Environment(\.dismiss) private var dismiss

    @State private var dashboard: IumrahFriendsDashboard?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                intro

                if account.isAuthenticated {
                    if isLoading && dashboard == nil {
                        loadingCard
                    } else if let dashboard {
                        balanceCard(dashboard)
                        giftCardsSection(dashboard)
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
                    .iumrahGlass(in: Circle(), interactive: true)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("iUmrah Gift Cards")
                    .font(.headline)
                Text(localizedSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, IumrahDesign.pagePadding)
        .padding(.vertical, 8)
        .background(Color.iumrahPageBackground)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("iUmrah Gift Cards")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .tracking(-0.7)
                    Text(localizedSubtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("3 × $100")
                    .font(.caption.monospaced().weight(.bold))
                    .padding(.horizontal, 13)
                    .frame(height: 38)
                    .iumrahGlass(in: Capsule())
            }

            Text(tr(
                "Give someone close $100 toward their first eligible Umrah booking. When that booking is confirmed and paid, you earn $100 iumrah Credit.",
                "Подарите близкому $100 на первое подходящее бронирование умры. После подтверждения личности и оплаты поездки Вы получите $100 iumrah Credit.",
                "Yaqin insoningizga birinchi mos Umrah broniga $100 sovg‘a qiling. Shaxs tasdiqlanib, safar to‘langach, Siz $100 iumrah Credit olasiz.",
                "Яқин инсонга биринчи мос Умра бронига $100 совға қилинг. Шахс тасдиқланиб, сафар тўлангач, Сиз $100 iumrah Credit оласиз."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(tr("Preparing your Gift Cards…", "Готовим Ваши Gift Cards…", "Gift Card laringiz tayyorlanmoqda…", "Gift Card ларингиз тайёрланмоқда…"))
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

            Text(tr("Unlock your 3 Gift Cards", "Откройте 3 Gift Cards", "3 ta Gift Card ni oching", "3 та Gift Card ни очинг"))
                .font(.title3.bold())
            Text(tr(
                "Sign in or create your iumrah account. Every registered pilgrim receives three $100 Gift Cards to share with people close to them.",
                "Войдите или создайте аккаунт iumrah. Каждый зарегистрированный паломник получает три Gift Cards по $100 для близких.",
                "iumrah akkauntingizga kiring yoki yarating. Har bir ro‘yxatdan o‘tgan ziyoratchi yaqinlari uchun uchta $100 Gift Card oladi.",
                "iumrah аккаунтингизга киринг ёки яратинг. Ҳар бир рўйхатдан ўтган зиёратчи яқинлари учун учта $100 Gift Card олади."
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
                .font(.headline)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .iumrahGlass(in: RoundedRectangle(cornerRadius: 19, style: .continuous), interactive: true)
            }
            .buttonStyle(.plain)
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

    private func giftCardsSection(_ value: IumrahFriendsDashboard) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Your Gift Cards", "Ваши Gift Cards", "Gift Card laringiz", "Gift Card ларингиз"))
                    .font(.title3.bold())
                Spacer()
                Text("\(value.gifts.filter(\.isAvailable).count)/3")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(.secondary)
            }

            ForEach(value.gifts) { gift in
                VStack(spacing: 12) {
                    IumrahGiftCardPass(gift: gift, language: settings.language)

                    if gift.isAvailable {
                        ShareLink(item: shareText(gift)) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text(tr("Send Gift Card", "Отправить Gift Card", "Gift Card yuborish", "Gift Card юбориш"))
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .iumrahGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
                        }
                        .buttonStyle(.plain)
                    } else if gift.isRewardEarned {
                        Label(tr("$100 added to iumrah Credit", "$100 зачислены в iumrah Credit", "$100 iumrah Credit ga qo‘shildi", "$100 iumrah Credit га қўшилди"), systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Label(tr("$100 reward after your friend pays", "$100 будут начислены после оплаты близкого", "Yaqin insoningiz to‘lagach $100 hisoblanadi", "Яқин инсонингиз тўлагач $100 ҳисобланади"), systemImage: "clock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 18, weight: .semibold))
                Text(tr("How Gift Cards work", "Как работают Gift Cards", "Gift Card qanday ishlaydi", "Gift Card қандай ишлайди"))
                    .font(.headline)
            }

            rule("1", tr("The recipient receives $100 toward their first eligible iumrah booking.", "Получатель получает $100 на первое подходящее бронирование iumrah.", "Qabul qiluvchi birinchi mos iumrah broniga $100 oladi.", "Қабул қилувчи биринчи мос iumrah бронига $100 олади."))
            rule("2", tr("You receive $100 iumrah Credit only after their identity is confirmed and the booking is paid.", "Вы получаете $100 iumrah Credit только после подтверждения личности получателя и оплаты бронирования.", "Siz $100 iumrah Credit ni faqat qabul qiluvchining shaxsi tasdiqlanib, bron to‘langandan keyin olasiz.", "Сиз $100 iumrah Credit ни фақат қабул қилувчининг шахси тасдиқланиб, брон тўлангандан кейин оласиз."))
            rule("3", tr("Trips up to $2,000 can use up to $100. Above $2,000, up to $200.", "Для поездки до $2,000 применяется максимум $100. Свыше $2,000 — максимум $200.", "$2,000 gacha bo‘lgan safarda limit $100. $2,000 dan yuqori — $200 gacha.", "$2,000 гача бўлган сафарда лимит $100. $2,000 дан юқори — $200 гача."))
            rule("4", tr("iumrah Security uses only a manually confirmed passport identity for Gift Card anti-fraud.", "Антифрод Gift Card использует только паспортную личность, вручную подтверждённую через iumrah Security.", "Gift Card antifraud faqat iumrah Security orqali qo‘lda tasdiqlangan pasport shaxsidan foydalanadi.", "Gift Card antifraud фақат iumrah Security орқали қўлда тасдиқланган паспорт шахсидан фойдаланади."))
            rule("5", tr("If the referred booking is cancelled or refunded, the $100 referral reward is reversed and the Gift Card becomes available again.", "Если бронирование приглашённого отменено или возвращено, реферальные $100 аннулируются, а Gift Card снова становится доступной.", "Taklif qilingan bron bekor qilinsa yoki puli qaytarilsa, $100 referral mukofoti bekor qilinadi va Gift Card yana mavjud bo‘ladi.", "Таклиф қилинган брон бекор қилинса ёки пули қайтарилса, $100 referral мукофоти бекор қилинади ва Gift Card яна мавжуд бўлади."))
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

    private var localizedSubtitle: String {
        tr("Gift cards for someone close", "Подарочные карты для близких", "Yaqinlar uchun sovg‘a kartalari", "Яқинлар учун совға карталари")
    }

    private func shareText(_ gift: IumrahFriendGift) -> String {
        let sender = account.account?.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (sender?.isEmpty == false ? sender! : "iumrah")
        return tr(
            "🎁 \(name) sent you an iUmrah Gift Card worth $100 toward your first eligible Umrah booking. Open iumrah and use code \(gift.code). https://iumrah.app",
            "🎁 \(name) отправил(а) Вам iUmrah Gift Card на $100 для первого подходящего бронирования умры. Откройте iumrah и примените код \(gift.code). https://iumrah.app",
            "🎁 \(name) Sizga birinchi mos Umrah broniga $100 iUmrah Gift Card yubordi. iumrah ni oching va \(gift.code) kodini kiriting. https://iumrah.app",
            "🎁 \(name) Сизга биринчи мос Умра бронига $100 iUmrah Gift Card юборди. iumrah ни очинг ва \(gift.code) кодини киритинг. https://iumrah.app"
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
