import Foundation

enum TransferVehicleKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case malibu
    case carnival
    case yukon

    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .malibu: return "TransferMalibu"
        case .carnival: return "TransferCarnival"
        case .yukon: return "TransferYukon"
        }
    }

    var modelName: String {
        switch self {
        case .malibu: return "Chevrolet Malibu"
        case .carnival: return "Kia Carnival"
        case .yukon: return "GMC Yukon"
        }
    }

    var passengerCapacity: Int {
        switch self {
        case .malibu: return 3
        case .carnival: return 7
        case .yukon: return 6
        }
    }

    var luggageCapacity: Int {
        switch self {
        case .malibu: return 2
        case .carnival: return 5
        case .yukon: return 5
        }
    }
}
