//
//  URLProtocolStub.swift
//  Data tests · support
//
//  The stand-in for MockWebServer: intercepts requests inside URLSession, so the tests exercise the
//  real client — middleware chain, status handling, decoding — without touching the network.
//
//  Outcomes are keyed **by host**. A single global outcome looked simpler and was wrong twice: with
//  `@Suite(.serialized)` the tests inside a suite stopped fighting each other, but suites still run
//  in parallel, so `HTTPClientTests` and `ImageLoaderTests` kept trading responses. Keying by host
//  removes the shared slot instead of taking turns on it.
//
//  State lives in a `Mutex` rather than a plain static: `URLProtocol` callbacks arrive on the
//  loading thread, and `nonisolated(unsafe)` here would be an unchecked promise instead of a
//  guarantee.
//

import Foundation
import Synchronization

final class URLProtocolStub: URLProtocol {

    enum Outcome: Sendable {
        case response(status: Int, body: Data)
        /// Answers after a delay, so a second request can arrive while the first is still in
        /// flight. Without this, de-duplication cannot be observed deterministically.
        case slowResponse(status: Int, body: Data, delay: Duration)
        case failure(URLError.Code)
        /// Never answers. Used to test cancellation: the request is in flight when the task dies.
        case hang
    }

    private static let outcomes = Mutex<[String: Outcome]>([:])
    private static let recordedRequests = Mutex<[URLRequest]>([])

    /// Sets the outcome for every request to `host`, and forgets that host's previous requests.
    static func set(_ outcome: Outcome, host: String) {
        outcomes.withLock { $0[host] = outcome }
        recordedRequests.withLock { $0.removeAll { $0.url?.host() == host } }
    }

    static func requests(host: String) -> [URLRequest] {
        recordedRequests.withLock { $0.filter { $0.url?.host() == host } }
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

        let host = request.url?.host() ?? ""
        guard let outcome = Self.outcomes.withLock({ $0[host] }) else {
            // Loud on purpose: a test that forgot to stub its host should fail with that reason,
            // not with a puzzling decoding error.
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        switch outcome {
        case let .response(status, body):
            respond(status: status, body: body)

        case let .slowResponse(status, body, delay):
            let seconds = Double(delay.components.seconds)
                + Double(delay.components.attoseconds) / 1e18
            Thread.sleep(forTimeInterval: seconds)
            respond(status: status, body: body)

        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))

        case .hang:
            break
        }
    }

    override func stopLoading() {}

    private func respond(status: Int, body: Data) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.invalid")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
