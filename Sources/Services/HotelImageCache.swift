import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// Hotel photography has a much longer lifecycle than price data.
/// URLs are the version key: the same URL is served from memory/disk without a TTL;
/// replacing the URL naturally creates a new cache entry while catalog prices keep
/// their independent 48-hour server freshness contract.
actor HotelImageCache {
    static let shared = HotelImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private let directory: URL

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = caches.appendingPathComponent("iumrah-hotel-images-v1", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 180
    }

    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cached = memory.object(forKey: key) { return cached }

        let diskURL = fileURL(for: url)
        if let data = try? Data(contentsOf: diskURL), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key)
            return image
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let image = UIImage(data: data) else { return nil }
            try? data.write(to: diskURL, options: .atomic)
            memory.setObject(image, forKey: key)
            return image
        } catch {
            return nil
        }
    }

    func prefetch(urls: [URL]) async {
        let unique = Array(Set(urls))
        for chunkStart in stride(from: 0, to: unique.count, by: 6) {
            let chunk = Array(unique[chunkStart..<min(chunkStart + 6, unique.count)])
            await withTaskGroup(of: Void.self) { group in
                for url in chunk {
                    group.addTask {
                        _ = await self.image(for: url)
                    }
                }
            }
        }
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name).appendingPathExtension("img")
    }
}

struct HotelCachedImage: View {
    enum ContentMode { case fill, fit }

    let rawURL: String?
    var contentMode: ContentMode = .fill
    var placeholderSystemName: String = "building.2.fill"

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode == .fill ? .fill : .fit)
                        // A panoramic source image must never define the SwiftUI
                        // layout width. The parent card owns the viewport; the photo
                        // is rendered inside that exact viewport and cropped there.
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Color.iumrahRaisedBackground
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .overlay {
                            Image(systemName: placeholderSystemName)
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipped()
        .task(id: rawURL) {
            guard let url = AppConfig.absoluteURL(rawURL) else {
                image = nil
                return
            }
            // Never flash the previous cell's photo while a reused SwiftUI view
            // switches to a different hotel URL. Disk hits still resolve immediately.
            image = nil
            image = await HotelImageCache.shared.image(for: url)
        }
    }
}
