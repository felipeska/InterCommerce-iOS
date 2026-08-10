//
//  HTTPClient.swift
//  Data · Network
//
//  URLSession plus a middleware chain. No third-party client: what Alamofire would add here is a
//  dependency, and what it would hide is the part the brief actually asks to see.
//

import Foundation

nonisolated struct HTTPClient: Sendable {
    private let session: URLSession
    private let baseURL: URL
    private let middlewares: [any HTTPClientMiddleware]
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        middlewares: [any HTTPClientMiddleware] = [LoggingMiddleware(), HeadersMiddleware()],
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.middlewares = middlewares
        self.decoder = decoder
    }

    /// Runs the endpoint and decodes the payload.
    ///
    /// Throws `AppError` for anything the app knows how to explain, and re-throws cancellation
    /// untouched — the caller's task is going away, and a cancelled request is not a failure to
    /// report. It is untyped `throws` for exactly that reason: `throws(AppError)` could not let a
    /// `CancellationError` through.
    func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        guard let request = endpoint.makeRequest(baseURL: baseURL) else {
            throw AppError.unknown
        }

        let (data, response) = try await perform(request)

        if let failure = AppError.mapping(statusCode: response.statusCode) {
            throw failure
        }

        guard !data.isEmpty else { throw AppError.emptyResult }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw try AppError.mapping(error)
        }
    }

    // MARK: - Chain

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Built back to front so the first middleware in the array is the outermost one: it sees
        // the request first and the response last.
        var next: (URLRequest) async throws -> (Data, HTTPURLResponse) = { request in
            try await self.load(request)
        }

        for middleware in middlewares.reversed() {
            let chain = next
            next = { request in
                try await middleware.intercept(request, next: chain)
            }
        }

        return try await next(request)
    }

    private func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AppError.unknown }
            return (data, http)
        } catch let error as AppError {
            throw error
        } catch {
            throw try AppError.mapping(error)
        }
    }
}
