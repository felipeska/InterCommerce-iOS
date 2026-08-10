//
//  HTTPClientMiddleware.swift
//  Data · Network
//
//  The brief asks for a client with logging and header "interceptors". That is a six-line protocol,
//  not a dependency: each middleware wraps the next one, so adding behaviour never touches
//  `HTTPClient` itself.
//

import Foundation
import os

/// One link in the request chain. Call `next` to continue, or don't, to short-circuit.
nonisolated protocol HTTPClientMiddleware: Sendable {
    func intercept(
        _ request: URLRequest,
        next: (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse)
}

// MARK: - Headers

/// Adds the headers every request in this app carries.
nonisolated struct HeadersMiddleware: HTTPClientMiddleware {
    let userAgent: String

    init(userAgent: String = "InterCommerce-iOS") {
        self.userAgent = userAgent
    }

    func intercept(
        _ request: URLRequest,
        next: (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return try await next(request)
    }
}

// MARK: - Logging

/// Logs method, URL, status and duration.
///
/// Compiled out of release builds: a logger that ships to production would leak the user's search
/// terms into the device log for no benefit, and the brief only asks for it as a development aid.
nonisolated struct LoggingMiddleware: HTTPClientMiddleware {
    private let logger = Logger(subsystem: "fcb.intercommerce", category: "http")

    func intercept(
        _ request: URLRequest,
        next: (URLRequest) async throws -> (Data, HTTPURLResponse)
    ) async throws -> (Data, HTTPURLResponse) {
        #if DEBUG
        let method = request.httpMethod ?? "GET"
        // `.public` on method and URL only: both are ours, neither carries user data beyond the
        // search term, which is why the whole middleware is DEBUG-only.
        let start = ContinuousClock.now

        do {
            let (data, response) = try await next(request)
            let elapsed = ContinuousClock.now - start
            logger.debug("\(method, privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) -> \(response.statusCode) in \(elapsed, privacy: .public)")
            return (data, response)
        } catch {
            let elapsed = ContinuousClock.now - start
            logger.debug("\(method, privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) -> \(error.localizedDescription, privacy: .public) in \(elapsed, privacy: .public)")
            throw error
        }
        #else
        return try await next(request)
        #endif
    }
}
