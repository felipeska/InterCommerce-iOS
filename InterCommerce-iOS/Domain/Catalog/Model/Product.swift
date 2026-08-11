//
//  Product.swift
//  Domain · Catalog · Model
//
//  What the rest of the app means by "a product". Immutable, framework-free, and the only product
//  type that ever leaves Data.
//

import Foundation

nonisolated struct Product: Identifiable, Hashable, Sendable {
    let id: Int
    let title: String
    let summary: String
    let category: String
    /// `""` when the API omits it — normalised once in the mapper. Callers check
    /// `brand.isEmpty`, not `brand == nil`.
    let brand: String
    /// Money and its discount rule, together. Nothing else computes a discount.
    let price: Price
    let rating: Double
    let stock: Int
    let thumbnailURL: URL?
    let imageURLs: [URL]
    let availabilityStatus: String?
    let shippingInformation: String?
    let warrantyInformation: String?
    let returnPolicy: String?

    var isOutOfStock: Bool { stock <= 0 }
}
