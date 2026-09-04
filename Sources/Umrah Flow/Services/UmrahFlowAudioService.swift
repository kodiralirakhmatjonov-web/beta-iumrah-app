import AVFoundation
import Combine
import Foundation

@MainActor
final class UmrahFlowAudioService: ObservableObject {
    @Published private(set) var currentKey: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false

    /// Smoothed, normalized output energy of the voice guide (0...1).
    ///
    /// This is measured from the audio that is actually being played, rather than
    /// generated from a synthetic timer, so visual components can react to the
    /// real narration dynamics.
    @Published private(set) var amplitude: Double = 0

    private var player: AVAudioPlayer?
    private var meterTimer: Timer?
    private var loadTask: Task<Void, Never>?
    private var activeRequestID = UUID()
    private var peakHold: Double = 0

    private let audioCache: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.totalCostLimit = 48 * 1024 * 1024
        cache.countLimit = 18
        return cache
    }()

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

        let requestID = UUID()
        activeRequestID = requestID
        currentKey = key
        isLoading = true
        amplitude = 0

        loadTask = Task { [weak self] in
            guard let self else { return }

            do {
                let data = try await self.audioData(for: url)
                try Task.checkCancellation()
                guard self.activeRequestID == requestID else { return }

                try self.beginPlayback(data: data, key: key)
            } catch is CancellationError {
                // A new clip was selected or playback was stopped while loading.
            } catch {
                guard self.activeRequestID == requestID else { return }
                self.finishPlayback(clearKey: true)
            }
        }
    }

    func stop() {
        activeRequestID = UUID()
        loadTask?.cancel()
        loadTask = nil

        player?.stop()
        player = nil
        stopMetering()

        isPlaying = false
        isLoading = false
        amplitude = 0
        peakHold = 0
        currentKey = nil
    }

    private func audioData(for url: URL) async throws -> Data {
        let cacheKey = url as NSURL
        if let cached = audioCache.object(forKey: cacheKey) {
            return cached as Data
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard !data.isEmpty else {
            throw URLError(.zeroByteResource)
        }

        audioCache.setObject(data as NSData, forKey: cacheKey, cost: data.count)
        return data
    }

    private func beginPlayback(data: Data, key: String) throws {
        let player = try AVAudioPlayer(data: data)
        player.isMeteringEnabled = true
        player.prepareToPlay()

        self.player = player
        currentKey = key
        isLoading = false

        guard player.play() else {
            throw URLError(.cannotOpenFile)
        }

        isPlaying = true
        startMetering()
    }

    private func startMetering() {
        stopMetering()

        let timer = Timer(timeInterval: 1.0 / 45.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAmplitudeMeter()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func updateAmplitudeMeter() {
        guard let player else {
            amplitude = 0
            return
        }

        guard player.isPlaying else {
            if isPlaying {
                finishPlayback(clearKey: false)
            }
            return
        }

        player.updateMeters()

        let channelCount = max(player.numberOfChannels, 1)
        var averageDB: Float = -80
        var peakDB: Float = -80

        for channel in 0..<channelCount {
            averageDB = max(averageDB, player.averagePower(forChannel: channel))
            peakDB = max(peakDB, player.peakPower(forChannel: channel))
        }

        let average = normalizedPower(averageDB, floor: -56)
        let peak = normalizedPower(peakDB, floor: -48)

        // Voice is transient-heavy, so a max-weighted meter reads syllables more
        // naturally than a simple average. Keep a very short peak hold so the
        // visual can visibly "open" on consonants without becoming jittery.
        var target = min(1.0, max(average * 0.92, peak * 0.86) * 1.20)
        peakHold = max(target, peakHold * 0.80)
        target = max(target, peakHold * 0.92)

        // Keep true silence visually calm while retaining ordinary speech.
        if target < 0.018 {
            target = 0
        }

        // Faster attack and a controlled release make amplitude changes visible
        // at the small Advisor widget size while still looking fluid.
        let smoothing = target > amplitude ? 0.80 : 0.17
        amplitude += (target - amplitude) * smoothing

        if amplitude < 0.002 {
            amplitude = 0
        }
    }

    private func normalizedPower(_ decibels: Float, floor: Float) -> Double {
        let clamped = max(floor, min(0, decibels))
        let normalized = Double((clamped - floor) / -floor)

        // Mild perceptual compression keeps normal spoken voice expressive while
        // still leaving headroom for louder syllables.
        return pow(max(0, min(1, normalized)), 0.66)
    }

    private func finishPlayback(clearKey: Bool) {
        stopMetering()
        player = nil
        loadTask = nil
        isPlaying = false
        isLoading = false
        amplitude = 0
        peakHold = 0

        if clearKey {
            currentKey = nil
        }
    }

    deinit {
        meterTimer?.invalidate()
        loadTask?.cancel()
    }
}
