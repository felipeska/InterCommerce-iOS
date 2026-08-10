//
//  HTTPClientTests.swift
//  Data tests
//
//  One case per row of the error table in architecture.md §8, plus the two rules that are easy to
//  break silently: the middleware chain must wrap in order, and cancellation must never become an
//  AppError.
//

import Foundation
import Testing

@testable import InterCommerce_iOS

/// `.serialized` is not decoration: `URLProtocolStub` holds its outcome in global state, and Swift
/// Testing runs tests in parallel by default. Without this, each test would set the stub and then
/// observe whatever a sibling set a microsecond later — the first run failed exactly that way, with
/// every case seeing a 500 that belonged to another test.
@Suite(.serialized)
struct HTTPClientTests {

    private let baseURL = URL(string: "https://dummyjson.com")!
    /// Each suite stubs its own host so suites can keep running in parallel.
    private let host = "dummyjson.com"

    private struct Payload: Codable, Equatable, Sendable {
        let id: Int
        let title: String
    }

    private func makeClient(
        middlewares: [any HTTPClientMiddleware] = []
    ) -> HTTPClient {
        HTTPClient(
            baseURL: baseURL,
            session: URLProtocolStub.makeSession(),
            middlewares: middlewares
        )
    }

    // MARK: - Happy path

    @Test("Decodes a 200 with a real body")
    func decodesSuccess() async throws {
        URLProtocolStub.set(.response(status: 200, body: #"{"id":1,"title":"Essence Mascara"}"#.data(using: .utf8)!), host: host)

        let payload: Payload = try await makeClient().send(.product(id: 1))

        #expect(payload == Payload(id: 1, title: "Essence Mascara"))
    }

    @Test("Builds the URL from the endpoint, percent-encoding the query")
    func buildsURL() async throws {
        URLProtocolStub.set(.response(status: 200, body: #"{"id":1,"title":"x"}"#.data(using: .utf8)!), host: host)

        _ = try await makeClient().send(.searchProducts(query: "café & té", limit: 10, skip: 0)) as Payload

        let url = try #require(URLProtocolStub.requests(host: host).first?.url?.absoluteString)
        #expect(url.hasPrefix("https://dummyjson.com/products/search?"))
        #expect(url.contains("q=caf%C3%A9%20%26%20t%C3%A9") || url.contains("q=caf%C3%A9+%26+t%C3%A9"))
        #expect(url.contains("limit=10"))
        #expect(url.contains("skip=0"))
    }

    // MARK: - The error table

    @Test("404 becomes notFound")
    func notFound() async {
        URLProtocolStub.set(.response(status: 404, body: #"{"message":"not found"}"#.data(using: .utf8)!), host: host)
        await #expect(throws: AppError.notFound) {
            _ = try await makeClient().send(.product(id: 99_999)) as Payload
        }
    }

    @Test("5xx becomes server, carrying the status", arguments: [500, 503])
    func serverError(status: Int) async {
        URLProtocolStub.set(.response(status: status, body: Data()), host: host)
        await #expect(throws: AppError.server(status: status)) {
            _ = try await makeClient().send(.product(id: 1)) as Payload
        }
    }

    @Test("No connectivity becomes noConnection", arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .cannotFindHost])
    func noConnection(code: URLError.Code) async {
        URLProtocolStub.set(.failure(code), host: host)
        await #expect(throws: AppError.noConnection) {
            _ = try await makeClient().send(.product(id: 1)) as Payload
        }
    }

    @Test("A timeout becomes timeout")
    func timeout() async {
        URLProtocolStub.set(.failure(.timedOut), host: host)
        await #expect(throws: AppError.timeout) {
            _ = try await makeClient().send(.product(id: 1)) as Payload
        }
    }

    @Test("Malformed JSON becomes decoding")
    func malformedJSON() async {
        URLProtocolStub.set(.response(status: 200, body: #"{"id":"not-a-number"}"#.data(using: .utf8)!), host: host)
        await #expect(throws: AppError.decoding) {
            _ = try await makeClient().send(.product(id: 1)) as Payload
        }
    }

    @Test("An empty 200 becomes emptyResult")
    func emptyBody() async {
        URLProtocolStub.set(.response(status: 200, body: Data()), host: host)
        await #expect(throws: AppError.emptyResult) {
            _ = try await makeClient().send(.product(id: 1)) as Payload
        }
    }

    // MARK: - Cancellation

    /// The rule that is easiest to break and hardest to notice: a cancelled request must not
    /// surface as a displayable error, or a search the user keeps typing over ends up rendering
    /// "no connection".
    @Test("Cancellation is never turned into an AppError")
    func cancellationIsNotAnAppError() async throws {
        URLProtocolStub.set(.hang, host: host)
        let client = makeClient()

        let task = Task { () -> Result<Payload, any Error> in
            do {
                return .success(try await client.send(.product(id: 1)) as Payload)
            } catch {
                return .failure(error)
            }
        }

        // Give the request time to be in flight before pulling the rug.
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        guard case let .failure(thrown) = await task.value else {
            Issue.record("A cancelled request returned a value")
            return
        }
        #expect(!(thrown is AppError), "Cancellation leaked into the domain as \(thrown)")
    }

    // MARK: - Middleware

    @Test("Headers middleware adds Accept and User-Agent")
    func headersMiddleware() async throws {
        URLProtocolStub.set(.response(status: 200, body: #"{"id":1,"title":"x"}"#.data(using: .utf8)!), host: host)

        _ = try await makeClient(middlewares: [HeadersMiddleware(userAgent: "Probe")])
            .send(.product(id: 1)) as Payload

        let request = try #require(URLProtocolStub.requests(host: host).first)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Probe")
    }

    /// Open/closed in practice: this middleware did not exist when `HTTPClient` was written, and
    /// adding it required no change to the client.
    @Test("The chain wraps in order: the first middleware is the outermost")
    func middlewareOrder() async throws {
        URLProtocolStub.set(.response(status: 200, body: #"{"id":1,"title":"x"}"#.data(using: .utf8)!), host: host)
        let recorder = OrderRecorder()

        _ = try await makeClient(middlewares: [
            TaggingMiddleware(tag: "outer", recorder: recorder),
            TaggingMiddleware(tag: "inner", recorder: recorder),
        ]).send(.product(id: 1)) as Payload

        #expect(await recorder.events == ["outer.before", "inner.before", "inner.after", "outer.after"])
    }
}

// MARK: - Test doubles

private actor OrderRecorder {
    private(set) var events: [String] = []
    func record(_ event: String) { events.append(event) }
}

private struct TaggingMiddleware: HTTPClientMiddleware {
    let tag: String
    let recorder: OrderRecorder

    func intercept(
        _ request: URLRequest,
        next: (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        await recorder.record("\(tag).before")
        let result = try await next(request)
        await recorder.record("\(tag).after")
        return result
    }
}
