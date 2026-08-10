//
//  PersistenceTests.swift
//  Data tests
//
//  The schema is three models and no relationships. These tests pin down the two properties that
//  the rest of the app leans on: `id` upserts instead of duplicating, and purging the catalogue
//  leaves the cart untouched.
//

import Foundation
import SwiftData
import Testing

@testable import InterCommerce_iOS

@Suite(.serialized)
struct PersistenceTests {

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainerFactory.inMemory())
    }

    private func makeProduct(id: Int, position: Int, title: String = "Product") -> ProductEntity {
        ProductEntity(
            id: id,
            title: title,
            productDescription: "",
            category: "beauty",
            brand: "",
            listCents: 999,
            discountPercentage: 10.48,
            rating: 2.5,
            stock: 10,
            thumbnail: "https://cdn.dummyjson.com/thumb.webp",
            images: [],
            availabilityStatus: nil,
            shippingInformation: nil,
            warrantyInformation: nil,
            returnPolicy: nil,
            position: position,
            cachedAt: .now
        )
    }

    private func makeCartItem(productId: Int, quantity: Int) -> CartItemEntity {
        CartItemEntity(
            productId: productId,
            title: "Snapshot title",
            thumbnail: "https://cdn.dummyjson.com/thumb.webp",
            listCents: 999,
            discountPercentage: 10.48,
            quantity: quantity,
            addedAt: .now,
            updatedAt: .now
        )
    }

    // MARK: - Schema

    @Test("The in-memory container opens with the three models")
    func containerOpens() throws {
        let container = try ModelContainerFactory.inMemory()
        #expect(container.schema.entities.count == 3)
    }

    @Test("Products are read back in server order, not by id")
    func ordersByPosition() throws {
        let context = try makeContext()
        // Inserted out of order, and with ids that do not follow the ordering.
        context.insert(makeProduct(id: 30, position: 2))
        context.insert(makeProduct(id: 10, position: 0))
        context.insert(makeProduct(id: 20, position: 1))
        try context.save()

        let descriptor = FetchDescriptor<ProductEntity>(sortBy: [SortDescriptor(\.position)])
        let products = try context.fetch(descriptor)

        #expect(products.map(\.id) == [10, 20, 30])
    }

    @Test("Re-inserting an existing id upserts instead of duplicating")
    func uniqueIdUpserts() throws {
        let context = try makeContext()
        context.insert(makeProduct(id: 1, position: 0, title: "Before"))
        try context.save()

        context.insert(makeProduct(id: 1, position: 0, title: "After"))
        try context.save()

        let products = try context.fetch(FetchDescriptor<ProductEntity>())
        #expect(products.count == 1)
        #expect(products.first?.title == "After")
    }

    // MARK: - The one that protects the user's data

    /// The single most likely data-loss bug in this brief: a refresh deletes every product, and if
    /// the cart hung off a relationship it would be emptied along with them (ADR §12). This test is
    /// the reason `CartItemEntity` carries a snapshot and no `@Relationship`.
    @Test("Purging the whole catalogue leaves the cart intact")
    func catalogRefreshDoesNotTouchTheCart() throws {
        let context = try makeContext()
        context.insert(makeProduct(id: 1, position: 0))
        context.insert(makeProduct(id: 2, position: 1))
        context.insert(makeCartItem(productId: 1, quantity: 3))
        context.insert(makeCartItem(productId: 2, quantity: 1))
        try context.save()

        // What a REFRESH does to the catalogue.
        try context.delete(model: ProductEntity.self)
        try context.save()

        let products = try context.fetch(FetchDescriptor<ProductEntity>())
        let cart = try context.fetch(FetchDescriptor<CartItemEntity>(sortBy: [SortDescriptor(\.productId)]))

        #expect(products.isEmpty)
        #expect(cart.count == 2, "The catalogue refresh emptied the cart")
        #expect(cart.map(\.quantity) == [3, 1], "Quantities did not survive the refresh")
        #expect(cart.first?.listCents == 999, "The price snapshot did not survive the refresh")
    }

    @Test("The cart keeps the price captured at add time, not the catalogue's")
    func cartKeepsItsSnapshot() throws {
        let context = try makeContext()
        let product = makeProduct(id: 1, position: 0)
        context.insert(product)
        context.insert(makeCartItem(productId: 1, quantity: 1))
        try context.save()

        // The catalogue is refreshed and the price went up.
        product.listCents = 1_999
        try context.save()

        let line = try #require(try context.fetch(FetchDescriptor<CartItemEntity>()).first)
        #expect(line.listCents == 999)
    }
}
