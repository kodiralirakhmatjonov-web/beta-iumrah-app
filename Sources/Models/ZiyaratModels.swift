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

    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
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
                longDescription: "Quba Mosque is closely connected with the Hijrah and the earliest Muslim community in Madinah. The present mosque stands on the historic site and remains one of the city’s most visited places. iumrah saves the exact coordinate for the stop instead of searching by name, so the map marker always points to the intended location.",
                interestingFacts: [
                    "The mosque is connected with the beginning of the Prophet’s ﷺ life in Madinah.",
                    "It is traditionally regarded as the first mosque established in Islam.",
                    "The modern complex preserves the identity of the historic Quba site while serving large numbers of worshippers."
                ],
                visitNotes: "Main stop. Allow enough time to enter calmly, pray and regroup with your guide before continuing the route.",
                visitType: "enter",
                durationMinutes: 40,
                latitude: 24.43917,
                longitude: 39.61722,
                address: "3493 Al Hijrah Rd, Al Khatim, Madinah 42318, Saudi Arabia",
                mapLabel: "Quba Mosque · exact point",
                routeOrder: 1,
                status: "published",
                images: (1...5).map { ZiyaratImage(id: "quba-\($0)", url: "asset:ZiyaratQuba\($0)", position: $0 - 1, byteSize: nil, width: 1254, height: 1254) }
            )
        ]
    )
}
