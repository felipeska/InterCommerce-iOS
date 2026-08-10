//
//  URLProtocolStub.swift
//  Data tests · support
//
//  The stand-in for MockWebServer: intercepts requests inside URLSession, so the tests exercise the
//  real client — middleware chain, status handling, decoding — without touching the network.
//
//  State is held in a `Mutex` rather than a plain static: `URLProtocol` callbacks arrive on the
//  loading thread, and `nonisolated(unsafe)` here would be an unchecked promise instead of a
//  guarantee.
//

import Foundation
import Synchronization

final class URLProtocolStub: URLProtocol {

    enum Outcome: Sendable {
        case response(status: Int, body: Data)
        case failure(URLError.Code)
        /// Never answers. Used to test cancellation: the request is in flight when the task dies.
        case hang
    }

    private static let outcome = Mutex<Outcome>(.response(status: 200, body: Data()))
    private static let recordedRequests = Mutex<[URLRequest]>([])

    static func set(_ outcome: Outcome) {
        Self.outcome.withLock { $0 = outcome }
        Self.recordedRequests.withLock { $0 = [] }
    }

    static var requests: [URLRequest] {
        recordedRequests.withLock { $0 }
    }

    /// A session wired to this stub. Ephemeral so no on-disk cache leaks between tests.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.recordedRequests.withLock { $0.append(request) }

        switch Self.outcome.withLock({ $0 }) {
        case let .response(status, body):
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.invalid")!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)

        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))

        case .hang:
            break
        }
    }

    override func stopLoading() {}
}
