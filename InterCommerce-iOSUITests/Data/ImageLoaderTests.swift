//
//  ImageLoaderTests.swift
//  Data tests
//
//  The two properties that justify writing a loader instead of using AsyncImage: it coalesces
//  concurrent requests for the same URL, and it serves the second read from memory.
//

import Foundation
import Testing
import UIKit

@testable import InterCommerce_iOS

@Suite(.serialized)
struct ImageLoaderTests {

    private let url = URL(string: "https://cdn.dummyjson.com/thumbnail.png")!
    private let host = "cdn.dummyjson.com"

    /// A real 1×1 PNG: the loader decodes what it receives, so a fake byte string would only prove
    /// that decoding fails.
    private func makePNG() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }.pngData()!
    }

    private func makeLoader() -> ImageLoader {
        ImageLoader(session: URLProtocolStub.makeSession())
    }

    @Test("Decodes an image from the response")
    func loadsImage() async throws {
        URLProtocolStub.set(.response(status: 200, body: makePNG()), host: host)

        let image = try await makeLoader().image(for: url)

        #expect(image.size.width > 0)
    }

    /// The reason for the in-flight table: a grid shows the same thumbnail in several cells at once,
    /// and without coalescing that is one download per cell.
    @Test("Concurrent requests for the same URL produce a single download")
    func deduplicatesInFlightRequests() async throws {
        URLProtocolStub.set(.slowResponse(status: 200, body: makePNG(), delay: .milliseconds(300)), host: host)
        let loader = makeLoader()

        async let first = loader.image(for: url)
        async let second = loader.image(for: url)
        async let third = loader.image(for: url)
        _ = try await (first, second, third)

        #expect(URLProtocolStub.requests(host: host).count == 1, "Made \(URLProtocolStub.requests(host: host).count) requests instead of 1")
    }

    @Test("The second read comes from memory, without hitting the network again")
    func servesFromMemoryCache() async throws {
        URLProtocolStub.set(.response(status: 200, body: makePNG()), host: host)
        let loader = makeLoader()

        _ = try await loader.image(for: url)
        _ = try await loader.image(for: url)

        #expect(URLProtocolStub.requests(host: host).count == 1)
    }

    @Test("A 404 on an image becomes notFound, not a decoding failure")
    func mapsStatusCode() async {
        URLProtocolStub.set(.response(status: 404, body: Data()), host: host)

        await #expect(throws: AppError.notFound) {
            _ = try await makeLoader().image(for: url)
        }
    }

    @Test("Bytes that are not an image become decoding")
    func mapsUndecodableData() async {
        URLProtocolStub.set(.response(status: 200, body: Data("not an image".utf8)), host: host)

        await #expect(throws: AppError.decoding) {
            _ = try await makeLoader().image(for: url)
        }
    }

    /// A failure must not poison the URL: the placeholder shows, and a later attempt still tries.
    @Test("A failed load leaves no entry behind")
    func failureDoesNotPoisonTheURL() async throws {
        URLProtocolStub.set(.failure(.notConnectedToInternet), host: host)
        let loader = makeLoader()

        await #expect(throws: AppError.noConnection) {
            _ = try await loader.image(for: url)
        }

        URLProtocolStub.set(.response(status: 200, body: makePNG()), host: host)
        let image = try await loader.image(for: url)
        #expect(image.size.width > 0)
    }
}
