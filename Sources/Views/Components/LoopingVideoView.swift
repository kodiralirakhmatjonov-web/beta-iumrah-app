import SwiftUI
import AVFoundation
import UIKit

struct LoopingVideoView: UIViewRepresentable {
    let resource: String
    var gravity: AVLayerVideoGravity = .resizeAspectFill
    var isPlaying: Bool = true
    var isMuted: Bool = true

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    final class Coordinator {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private let resource: String
        private let gravity: AVLayerVideoGravity

        init(resource: String, gravity: AVLayerVideoGravity) {
            self.resource = resource
            self.gravity = gravity
        }

        func attach(to view: PlayerView, isPlaying: Bool, isMuted: Bool) {
            guard player == nil else {
                updatePlayback(isPlaying: isPlaying, isMuted: isMuted)
                return
            }

            let url = Bundle.main.url(forResource: resource, withExtension: "mp4")
                ?? Bundle.main.url(forResource: resource, withExtension: "mp4", subdirectory: "Animations")
            guard let url else { return }

            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = isMuted
            queue.actionAtItemEnd = .none
            queue.automaticallyWaitsToMinimizeStalling = false

            let looper = AVPlayerLooper(player: queue, templateItem: item)

            self.player = queue
            self.looper = looper
            view.playerLayer.player = queue
            view.playerLayer.videoGravity = gravity

            if isPlaying {
                queue.play()
            }
        }

        func updatePlayback(isPlaying: Bool, isMuted: Bool) {
            player?.isMuted = isMuted
            if isPlaying {
                player?.play()
            } else {
                player?.pause()
            }
        }

        func stop() {
            player?.pause()
            player?.removeAllItems()
            looper = nil
            player = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(resource: resource, gravity: gravity)
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        context.coordinator.attach(to: view, isPlaying: isPlaying, isMuted: isMuted)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.videoGravity = gravity
        context.coordinator.updatePlayback(isPlaying: isPlaying, isMuted: isMuted)
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.playerLayer.player = nil
    }
}
