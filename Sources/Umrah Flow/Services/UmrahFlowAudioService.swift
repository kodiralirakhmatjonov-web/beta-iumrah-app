import Combine
import AVFoundation
import Foundation

@MainActor
final class UmrahFlowAudioService: ObservableObject {
    @Published private(set) var currentKey: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    func toggle(key: String, url: URL?) {
        if currentKey == key, isPlaying {
            stop()
            return
        }
        guard let url else { return }
        play(key: key, url: url)
    }

    func play(key: String, url: URL) {
        stop()
        isLoading = true
        currentKey = key

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.isLoading = false
            }
        }

        player.play()
        isLoading = false
        isPlaying = true
    }

    func stop() {
        player?.pause()
        player = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        isPlaying = false
        isLoading = false
        currentKey = nil
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}
