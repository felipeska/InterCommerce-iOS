//
//  ProductAPI.swift
//  Data · Catalog
//
//  The three calls the brief names, and nothing else.
//

import Foundation

nonisolated struct ProductAPI: Sendable {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func products(limit: Int, skip: Int) async throws -> PagedResponseDTO<ProductDTO> {
        try await client.send(.products(limit: limit, skip: skip))
    }

    func searchProducts(query: String, limit: Int, skip: Int) async throws -> PagedResponseDTO<ProductDTO> {
        try await client.send(.searchProducts(query: query, limit: limit, skip: skip))
    }

    func product(id: Int) async throws -> ProductDTO {
        try await client.send(.product(id: id))
    }
}
