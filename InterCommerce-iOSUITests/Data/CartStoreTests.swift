//
//  CartStoreTests.swift
//  Data tests
//
//  The cart is the only user data in the app: everything else can be thrown away and fetched again.
//  These pin the rules that decide whether the user is charged the right amount — the price snapshot
//  taken once, the quantity bounds, and the stream that keeps the badge and the totals honest.
//

import Foundation
import Testing

@testable import InterCommerce_iOS

struct CartStoreTests {

    private func makeStore() throws -> CartStore {
        CartStore(modelContainer: try ModelContainerFactory.inMemory())
    }

    private func product(id: Int, list: Cents = 999, discountBasisPoints: Int = 1_048) -> Product {
        Product(
            id: id,
            title: "Product \(id)",
            summary: "",
            category: "beauty",
            brand: "Acme",
            price: Price(list: list, discountBasisPoints: discountBasisPoints),
            rating: 4,
            stock: 10,
            thumbnailURL: URL(string: "https://cdn.example/t\(id).webp"),
            imageURLs: [],
            availabilityStatus: nil,
            shippingInformation: nil,
            warrantyInformation: nil,
            returnPolicy: nil
        )
    }

    // MARK: - Adding

    @Test("Adding a product the cart has never seen creates one line")
    func addNewProduct() async throws {
        let store = try makeStore()

        try await store.add(product(id: 1), quantity: 1)

        let lines = await store.currentLines()
        #expect(lines.count == 1)
        #expect(lines.first?.productId == 1)
        #expect(lines.first?.quantity == 1)
        #expect(lines.first?.price.list == Cents(999))
    }

    @Test("Adding a product that is already there raises the quantity instead of duplicating")
    func addExistingProductIncrements() async throws {
        let store = try makeStore()
        try await store.add(product(id: 1), quantity: 1)

        try await store.add(product(id: 1), quantity: 2)

        let lines = await store.currentLines()
        #expect(lines.count == 1, "The same product produced two lines")
        #expect(lines.first?.quantity == 3)
    }

    /// The rule the store's own comment claims, and the one a user would notice: the price is
    /// captured when the decision is made. Adding a second unit after a price rise must not
    /// retroactively reprice the first.
    @Test("A second add keeps the price captured by the first")
    func secondAddKeepsTheOriginalSnapshot() async throws {
        let store = try makeStore()
        try await store.add(product(id: 1, list: 999), quantity: 1)

        try await store.add(product(id: 1, list: 1_999), quantity: 1)

        let line = try #require(await store.line(productId: 1))
        #expect(line.price.list == Cents(999), "The line adopted a price the user never accepted")
        #expect(line.quantity == 2)
    }

    @Test("Adding past the maximum clamps rather than overflowing the line")
    func addClampsToTheMaximum() async throws {
        let store = try makeStore()
        try await store.add(product(id: 1), quantity: CartLine.quantityRange.upperBound)

        try await store.add(product(id: 1), quantity: 5)

        #expect(await store.line(productId: 1)?.quantity == CartLine.quantityRange.upperBound)
    }

    @Test("Separate products are separate lines, oldest first")
    func linesKeepInsertionOrder() async throws {
        let store = try makeStore()
        let earlier = Date(timeIntervalSince1970: 1_000)

        try await store.add(product(id: 7), quantity: 1, now: earlier)
        try await store.add(product(id: 3), quantity: 1, now: earlier.addingTimeInterval(60))

        // Not sorted by id: a line must not jump around when the cart changes.
        #expect(await store.currentLines().map(\.productId) == [7, 3])
    }

    // MARK: - Changing the quantity

    @Test("Setting a quantity replaces it rather than adding to it")
    func setQuantityReplaces() async throws {
        let store = try makeStore()
        try await store.add(product(id: 1), quantity: 2)

        try await store.setQuantity(5, productId: 1)

        #expect(await store.line(productId: 1)?.quantity == 5)
    }

    @Test("Quantities outside the range are clamped into it", arguments: [(0, 1), (-4, 1), (500, 99)])
    func setQuantityClamps(requested: Int, expected: Int) async throws {
        let store = try makeStore()
        try await store.add(product(id: 1), quantity: 1)

        try await store.setQuantity(requested, productId: 1)

        #expect(await store.line(productId: 1)?.quantity == expected)
    }

    /// Removal is `remove`, never `setQuantity(0)`. If this silently created a line the cart would
    /// grow rows the user never asked for.
    @Test("Setting a quantity on a product that is not in the cart does nothing")
    func setQuantityOnMissingProductIsANoOp() async throws {
        let store = try makeStore()

        try await store.setQuantity(3, productId: 404)

        #expect(await store.currentLines().isEmpty)
    }

    // MARK: - Removing

    @Test("Removing takes out one line and leaves the rest alone")
    func removeOneLine() async throws {
        let store = try makeStore()
        try await store.add(product(id: 1), quantity: 1)
        try await store.add(product(id: 2), quantity: 4)

        try await store.remove(productId: 1)

        let lines = await store.currentLines()
        #expect(lines.map(\.productId) == [2])
        #expect(lines.first?.quantity == 4, "Removing a line disturbed another")
    }

    @Test("Removing a product that is not there is not an error")
    func removeMissingProduct() async throws {
        let store = try makeStore()
        try await store.add(product(id: 1), quantity: 1)

        try await store.remove(productId: 404)

        #expect(await store.currentLines().count == 1)
    }

    // MARK: - The stream

    /// The badge and the totals both read this stream. If a write did not broadcast, the cart would
    /// be right in the database and wrong on screen — the failure mode that is hardest to spot.
    @Test("Every write reaches the stream, starting with the current contents")
    func streamEmitsOnEveryWrite() async throws {
        let store = try makeStore()
        try await store.add(product(id: 1), quantity: 1)

        var emissions: [[Int]] = []
        let stream = await store.linesStream()

        let collector = Task {
            for await lines in stream {
                emissions.append(lines.map(\.quantity))
                if emissions.count == 4 { break }
            }
            return emissions
        }

        try await store.add(product(id: 1), quantity: 1)
        try await store.setQuantity(9, productId: 1)
        try await store.remove(productId: 1)

        let observed = await collector.value
        #expect(observed == [[1], [2], [9], []], "A write did not reach the observers")
    }

    /// The confirmation screen depends on this: the badge is a live subscriber, and an order that
    /// does not reach it leaves a count for a cart that no longer has anything in it.
    @Test("Clearing the cart reaches the observers")
    func clearReachesObservers() async throws {
        let store = try makeStore()
        try await store.add(product(id: 1), quantity: 2)
        try await store.add(product(id: 2), quantity: 1)

        var emissions: [[Int]] = []
        let stream = await store.linesStream()
        let collector = Task {
            for await lines in stream {
                emissions.append(lines.map(\.productId))
                if emissions.count == 2 { break }
            }
            return emissions
        }

        try await store.clear()

        #expect(await collector.value == [[1, 2], []], "The clear did not reach the observers")
        #expect(await store.currentLines().isEmpty)
    }

    @Test("A finished stream stops counting against the store")
    func terminatedStreamIsReleased() async throws {
        let store = try makeStore()

        do {
            let stream = await store.linesStream()
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
            #expect(await store.subscriberCount == 1)
        }

        // Termination is delivered on a detached task, so the drop is not synchronous.
        try await Task.sleep(for: .milliseconds(100))
        #expect(await store.subscriberCount == 0, "Subscribers leak once their stream is gone")
    }
}
