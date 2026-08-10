//
//  ImageLoader.swift
//  Data · Images
//
//  `AsyncImage` is the obvious answer and it does not fit the brief: it gives no usable disk cache
//  across launches, re-downloads when a cell scrolls back into view, and does not coalesce two
//  requests for the same URL. The brief evaluates exactly those three things, so this is ~90 lines
//  of our own (ADR §25).
//
//  An actor rather than a lock: the in-flight table is shared mutable state, and the isolation makes
//  the check-then-insert atomic for free.
//

import Foundation
import UIKit

actor ImageLoader {

    private let session: URLSession
    /// Decoded images. The URLCache below holds bytes; decoding is the expensive half, so the
    /// result of it is what gets kept in memory.
    private let decoded: NSCache<NSURL, UIImage>
    /// One task per URL in flight. Two cells showing the same thumbnail make one request.
    private var inFlight: [URL: Task<UIImage, any Error>] = [:]

    init(session: URLSession? = nil, decodedImageLimit: Int = 50) {
        self.session = session ?? Self.makeSession()
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = decodedImageLimit
        self.decoded = cache
    }

    /// A session of its own, not the API's: images want a big cache and long-lived storage, the
    /// API wants neither (the catalogue's cache is SwiftData, and two caching layers with different
    /// policies produce bugs nobody can reproduce).
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "ImageCache")
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = decoded.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<UIImage, any Error> { [session] in
            let (data, response) = try await session.data(from: url)

            if let http = response as? HTTPURLResponse,
               let failure = AppError.mapping(statusCode: http.statusCode) {
                throw failure
            }

            // Decoding happens here, inside the actor, so it never lands on the main actor. The
            // `preparingForDisplay` call does the work that would otherwise happen during the first
            // frame that shows the image.
            guard let image = UIImage(data: data)?.preparingForDisplay() else {
                throw AppError.decoding
            }
            return image
        }

        inFlight[url] = task

        do {
            let image = try await task.value
            inFlight[url] = nil
            decoded.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            inFlight[url] = nil
            // Cancellation stays cancellation; everything else becomes an AppError the UI can show
            // as a broken-image placeholder.
            if error is AppError { throw error }
            throw try AppError.mapping(error)
        }
    }
}
