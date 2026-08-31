import Combine
import Foundation
import Network

enum IumrahConnectivityStatus: Hashable {
    case checking
    case online
    case offline

    var title: String {
        switch self {
        case .checking: return "Checking"
        case .online: return "Online"
        case .offline: return "Offline"
        }
    }

    var systemImage: String {
        switch self {
        case .checking: return "globe"
        case .online: return "globe"
        case .offline: return "wifi.slash"
        }
    }
}

/// Small app-level reachability monitor used only for presentation state.
/// NWPathMonitor reacts immediately to radio/Wi-Fi changes, while the short
/// HTTPS probe prevents a connected-but-unusable network from being shown as online.
final class IumrahConnectivityMonitor: ObservableObject {
    @Published private(set) var status: IumrahConnectivityStatus = .checking

    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "com.iumrah.beta.connectivity-path", qos: .utility)
    private let probeSession: URLSession
    private var probeTask: Task<Void, Never>?

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 4
        configuration.timeoutIntervalForResource = 5
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.probeSession = URLSession(configuration: configuration)

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let pathStatus = path.status
            Task { @MainActor [weak self] in
                self?.apply(pathStatus: pathStatus)
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    deinit {
        probeTask?.cancel()
        pathMonitor.cancel()
        probeSession.invalidateAndCancel()
    }

    @MainActor
    func refresh() {
        apply(pathStatus: pathMonitor.currentPath.status)
    }

    @MainActor
    private func apply(pathStatus: NWPath.Status) {
        guard pathStatus == .satisfied else {
            probeTask?.cancel()
            status = .offline
            return
        }

        if status == .offline {
            status = .checking
        }
        startProbe()
    }

    @MainActor
    private func startProbe() {
        probeTask?.cancel()

        var request = URLRequest(url: AppConfig.apiBaseURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 4
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("iumrah-ios-beta/connectivity", forHTTPHeaderField: "User-Agent")

        let session = probeSession
        probeTask = Task { [weak self] in
            do {
                let (_, response) = try await session.data(for: request)
                guard !Task.isCancelled else { return }
                let hasInternetResponse = response is HTTPURLResponse

                await MainActor.run {
                    guard let self else { return }
                    self.status = hasInternetResponse ? .online : .offline
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.status = .offline
                }
            }
        }
    }
}
