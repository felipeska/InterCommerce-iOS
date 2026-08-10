//
//  Endpoint.swift
//  Data · Network
//
//  A request described as data, not assembled as a string. Interpolating query values into a URL
//  is how you ship a search that breaks on the first accented character or ampersand;
//  `URLComponents` percent-encodes them for us.
//

import Foundation

/// A single API call, independent of how it is executed.
nonisolated struct Endpoint: Sendable, Equatable {
    let path: String
    let queryItems: [URLQueryItem]

    init(path: String, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.queryItems = queryItems
    }

    /// Builds the request, or `nil` if `baseURL` and `path` cannot form a valid URL.
    ///
    /// Returning an optional rather than force-unwrapping is deliberate: the base URL comes from
    /// `Info.plist`, so a typo there must surface as a handled failure, not a crash.
    func makeRequest(baseURL: URL) -> URLRequest? {
        guard var components = URLComponents(
            url: baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else { return nil }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else { return nil }
        return URLRequest(url: url)
    }
}

// MARK: - The three calls this app makes

extension Endpoint {
    static func products(limit: Int, skip: Int) -> Endpoint {
        Endpoint(
            path: "products",
            queryItems: [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "skip", value: String(skip)),
            ]
        )
    }

    static func searchProducts(query: String, limit: Int, skip: Int) -> Endpoint {
        Endpoint(
            path: "products/search",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "skip", value: String(skip)),
            ]
        )
    }

    static func product(id: Int) -> Endpoint {
        Endpoint(path: "products/\(id)")
    }
}
