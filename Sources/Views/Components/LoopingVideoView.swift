import SwiftUI
import AVFoundation
import UIKit

struct LoopingVideoView: UIViewRepresentable {
    let resource: String
    var gravity: AVLayerVideoGravity = .resizeAspectFill

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

        func attach(to view: PlayerView) {
            guard player == nil else { return }
            let url = Bundle.main.url(forResource: resource, withExtension: "mp4")
                ?? Bundle.main.url(forResource: resource, withExtension: "mp4", subdirectory: "Animations")
            guard let url else { return }

            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.actionAtItemEnd = .none
            let looper = AVPlayerLooper(player: queue, templateItem: item)

            self.player = queue
            self.looper = looper
            view.playerLayer.player = queue
            view.playerLayer.videoGravity = gravity
            queue.play()
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
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.playerLayer.player = nil
    }
}
