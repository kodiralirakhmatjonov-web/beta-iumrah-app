import Foundation
import CoreLocation

struct ZiyaratImage: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let position: Int
    let byteSize: Int?
    let width: Int?
    let height: Int?

    var bundledAssetName: String? {
        guard url.hasPrefix("asset:") else { return nil }
        return String(url.dropFirst("asset:".count))
    }
}

struct ZiyaratPlaceTranslation: Codable, Hashable {
    let title: String
    let shortDescription: String
    let longDescription: String
    let interestingFacts: [String]
    let visitNotes: String
}

struct ZiyaratPlace: Codable, Identifiable, Hashable {
    let id: String
    let routeID: String
    let slug: String
    let city: String
    let country: String
    let title: String
    let titleArabic: String
    let category: String
    let shortDescription: String
    let longDescription: String
    let interestingFacts: [String]
    let visitNotes: String
    let visitType: String
    let durationMinutes: Int
    let latitude: Double
    let longitude: Double
    let address: String
    let mapLabel: String
    let routeOrder: Int
    let status: String
    let images: [ZiyaratImage]
    let translations: [String: ZiyaratPlaceTranslation]?

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }

    func localizedContent(locale: String) -> ZiyaratPlaceTranslation {
        if let exact = translations?[locale], !exact.title.isEmpty { return exact }
        if let english = translations?["en"], !english.title.isEmpty { return english }
        if let russian = translations?["ru"], !russian.title.isEmpty { return russian }
        if let uzbek = translations?["uz"], !uzbek.title.isEmpty { return uzbek }
        if let cyrillic = translations?["uz-cyrl"], !cyrillic.title.isEmpty { return cyrillic }
        return ZiyaratPlaceTranslation(
            title: title,
            shortDescription: shortDescription,
            longDescription: longDescription,
            interestingFacts: interestingFacts,
            visitNotes: visitNotes
        )
    }
}

struct ZiyaratRoute: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let city: String
    let country: String
    let title: String
    let subtitle: String
    let transportMode: String
    let status: String
    let estimatedMinutes: Int
    let stopCount: Int
    let places: [ZiyaratPlace]
}

struct ZiyaratCatalogResponse: Codable {
    let ok: Bool
    let route: ZiyaratRoute?
}

enum ZiyaratSeedData {
    private static let qubaTranslations: [String: ZiyaratPlaceTranslation] = [
        "ru": ZiyaratPlaceTranslation(
            title: "Мечеть Куба",
            shortDescription: "Первая мечеть, основанная в исламе, и одна из важнейших точек зиярата в Медине.",
            longDescription: "Мечеть Куба тесно связана с хиджрой и ранней мусульманской общиной Медины. Современная мечеть находится на историческом месте и остаётся одной из самых посещаемых точек города.",
            interestingFacts: [
                "Мечеть связана с началом периода жизни Пророка ﷺ в Медине.",
                "Она традиционно считается первой мечетью, основанной в исламе.",
                "Современный комплекс сохраняет связь с историческим местом Куба и принимает большое количество молящихся."
            ],
            visitNotes: "Основная остановка. Оставьте достаточно времени, чтобы спокойно войти, совершить намаз и собраться с группой перед продолжением маршрута."
        ),
        "uz": ZiyaratPlaceTranslation(
            title: "Qubo masjidi",
            shortDescription: "Islomda barpo etilgan ilk masjid va Madinadagi eng muhim ziyorat maskanlaridan biri.",
            longDescription: "Qubo masjidi hijrat va Madinadagi ilk musulmon jamoasi bilan chambarchas bog‘liq. Hozirgi masjid tarixiy joyda joylashgan bo‘lib, shaharning eng ko‘p ziyorat qilinadigan maskanlaridan biri bo‘lib qolmoqda.",
            interestingFacts: [
                "Masjid Payg‘ambarimiz ﷺning Madinadagi hayotining boshlanish davri bilan bog‘liq.",
                "U an’anaviy ravishda Islomda barpo etilgan birinchi masjid deb qaraladi.",
                "Zamonaviy majmua tarixiy Qubo maskani bilan bog‘liqlikni saqlab, ko‘plab namozxonlarga xizmat qiladi."
            ],
            visitNotes: "Asosiy to‘xtash joyi. Ichkariga xotirjam kirish, namoz o‘qish va yo‘nalishni davom ettirishdan oldin guruh bilan yig‘ilish uchun yetarli vaqt ajrating."
        ),
        "uz-cyrl": ZiyaratPlaceTranslation(
            title: "Қубо масжиди",
            shortDescription: "Исломда барпо этилган илк масжид ва Мадинадаги энг муҳим зиёрат масканларидан бири.",
            longDescription: "Қубо масжиди ҳижрат ва Мадинадаги илк мусулмон жамоаси билан чамбарчас боғлиқ. Ҳозирги масжид тарихий жойда жойлашган бўлиб, шаҳарнинг энг кўп зиёрат қилинадиган масканларидан бири бўлиб қолмоқда.",
            interestingFacts: [
                "Масжид Пайғамбаримиз ﷺнинг Мадинадаги ҳаётининг бошланиш даври билан боғлиқ.",
                "У анъанавий равишда Исломда барпо этилган биринчи масжид деб қаралади.",
                "Замонавий мажмуа тарихий Қубо маскани билан боғлиқликни сақлаб, кўплаб намозхонларга хизмат қилади."
            ],
            visitNotes: "Асосий тўхташ жойи. Ичкарига хотиржам кириш, намоз ўқиш ва йўналишни давом эттиришдан олдин гуруҳ билан йиғилиш учун етарли вақт ажратинг."
        ),
        "en": ZiyaratPlaceTranslation(
            title: "Quba Mosque",
            shortDescription: "The first mosque established in Islam and one of Madinah’s most important ziyarat stops.",
            longDescription: "Quba Mosque is closely connected with the Hijrah and the earliest Muslim community in Madinah. The present mosque stands on the historic site and remains one of the city’s most visited places.",
            interestingFacts: [
                "The mosque is connected with the beginning of the Prophet’s ﷺ life in Madinah.",
                "It is traditionally regarded as the first mosque established in Islam.",
                "The modern complex preserves the identity of the historic Quba site while serving large numbers of worshippers."
            ],
            visitNotes: "Main stop. Allow enough time to enter calmly, pray and regroup with your guide before continuing the route."
        )
    ]

    static let medina = ZiyaratRoute(
        id: "medina-main",
        slug: "medina-ziyarat",
        city: "Madinah",
        country: "Saudi Arabia",
        title: "Medina Ziyarat",
        subtitle: "Sacred and historic places around Madinah",
        transportMode: "car",
        status: "published",
        estimatedMinutes: 40,
        stopCount: 1,
        places: [
            ZiyaratPlace(
                id: "quba-mosque",
                routeID: "medina-main",
                slug: "quba-mosque",
                city: "Madinah",
                country: "Saudi Arabia",
                title: "Quba Mosque",
                titleArabic: "مسجد قباء",
                category: "mosque",
                shortDescription: "The first mosque established in Islam and one of Madinah’s most important ziyarat stops.",
                longDescription: "Quba Mosque is closely connected with the Hijrah and the earliest Muslim community in Madinah. The present mosque stands on the historic site and remains one of the city’s most visited places.",
                interestingFacts: qubaTranslations["en"]?.interestingFacts ?? [],
                visitNotes: qubaTranslations["en"]?.visitNotes ?? "",
                visitType: "enter",
                durationMinutes: 40,
                latitude: 24.43917,
                longitude: 39.61722,
                address: "3493 Al Hijrah Rd, Al Khatim, Madinah 42318, Saudi Arabia",
                mapLabel: "Quba Mosque · exact point",
                routeOrder: 1,
                status: "published",
                images: (1...5).map { ZiyaratImage(id: "quba-\($0)", url: "asset:ZiyaratQuba\($0)", position: $0 - 1, byteSize: nil, width: 1254, height: 1254) },
                translations: qubaTranslations
            )
        ]
    )

    static func fallback(city: String) -> ZiyaratRoute {
        let normalized = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "makkah" || normalized == "mecca" {
            return ZiyaratRoute(
                id: "makkah-main",
                slug: "makkah-ziyarat",
                city: "Makkah",
                country: "Saudi Arabia",
                title: "Makkah Ziyarat",
                subtitle: "Sacred and historic places around Makkah",
                transportMode: "car",
                status: "published",
                estimatedMinutes: 0,
                stopCount: 0,
                places: []
            )
        }
        return medina
    }

}
