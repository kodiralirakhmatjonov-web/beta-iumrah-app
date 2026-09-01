import Foundation

/// Shared booking payload value retained for backward compatibility with the
/// existing booking path. The former server PackageSearch/flight-bot models were removed.
enum ServerIntercityTransport: String, Codable, Hashable {
    case road
    case haramainTrain
}
