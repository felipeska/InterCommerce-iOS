//
//  ProductDTO.swift
//  Data · Catalog
//
//  The wire shape. It never leaves Data — guard G5 enforces that.
//

import Foundation

/// The envelope the three list endpoints share.
nonisolated struct PagedResponseDTO<Item: Decodable & Sendable>: Decodable, Sendable {
    let products: [Item]
    /// Total across the whole set, not the page: this is how pagination knows when to stop.
    let total: Int
    let skip: Int
    let limit: Int
}

nonisolated struct ProductDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let description: String
    let category: String
    /// Absent for several categories (`groceries`, `furniture`). Optional here and **only** here:
    /// the mapper normalises it to `""`. A non-optional `String` would make `Codable`
    /// throw, turning a missing brand into "malformed data".
    let brand: String?
    let price: Double
    let discountPercentage: Double
    let rating: Double
    let stock: Int
    let thumbnail: String
    let images: [String]
    let availabilityStatus: String?
    let shippingInformation: String?
    let warrantyInformation: String?
    let returnPolicy: String?

    // Deliberately not decoded: `reviews`, `meta`, `dimensions`, `tags`, `sku`, `weight` and
    // `minimumOrderQuantity`. `JSONDecoder` ignores keys a type does not declare, so leaving them
    // out costs nothing and keeps the model honest about what the app actually uses.
}
