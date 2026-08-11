//
//  Product+Preview.swift
//  Domain · Catalog · Model
//
//  Sample data for previews and tests. It lives in the domain because both the UI and the test
//  target need it, and it carries no framework of its own.
//

import Foundation

nonisolated extension Product {
    static let preview = Product(
        id: 1,
        title: "Essence Mascara Lash Princess",
        summary: "A popular mascara known for its volumising effect.",
        category: "beauty",
        brand: "Essence",
        price: Price(list: Cents(999), discountBasisPoints: 1_048),
        rating: 2.56,
        stock: 99,
        thumbnailURL: URL(string: "https://cdn.dummyjson.com/thumbnail.webp"),
        imageURLs: [],
        availabilityStatus: "In Stock",
        shippingInformation: "Ships in 3-5 business days",
        warrantyInformation: "1 week warranty",
        returnPolicy: "No return policy"
    )

    static let previewList: [Product] = [
        preview,
        Product(
            id: 2, title: "Eyeshadow Palette with Mirror", summary: "", category: "beauty",
            // No brand: the card must simply omit the line, not reserve a gap for it.
            brand: "",
            price: Price(list: Cents(1_999), discountBasisPoints: 0),
            rating: 4.1, stock: 0,
            thumbnailURL: URL(string: "https://cdn.dummyjson.com/2.webp"), imageURLs: [],
            availabilityStatus: "Out of Stock", shippingInformation: nil,
            warrantyInformation: nil, returnPolicy: nil
        ),
        Product(
            id: 3, title: "Powder Canister", summary: "", category: "beauty", brand: "Velvet Touch",
            price: Price(list: Cents(1_489), discountBasisPoints: 1_814),
            rating: 4.6, stock: 12,
            thumbnailURL: URL(string: "https://cdn.dummyjson.com/3.webp"), imageURLs: [],
            availabilityStatus: "In Stock", shippingInformation: nil,
            warrantyInformation: nil, returnPolicy: nil
        ),
    ]
}
