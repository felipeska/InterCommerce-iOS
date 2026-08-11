//
//  CatalogStoreTests.swift
//  Data tests
//
//  The store is the single writer and the single reader of the catalogue. What matters here is that
//  the server's order survives, that a refresh truncates while an append does not, and that the
//  stream — the thing standing in for `@Query` — emits exactly when it should.
//

import Foundation
import SwiftData
import Testing

@testable import InterCommerce_iOS

struct CatalogStoreTests {

    private func makeStore() throws -> CatalogStore {
        CatalogStore(modelContainer: try ModelContainerFactory.inMemory())
    }

    private func makeDTOs(ids: [Int], titlePrefix: String = "Product", brand: String? = "Acme") -> [ProductDTO] {
        ids.map { id in
            let json = """
            {
              "id": \(id), "title": "\(titlePrefix) \(id)", "description": "d", "category": "beauty",
              "price": 9.99, "discountPercentage": 10.48, "rating": 4, "stock": 5,
              \(brand.map { "\"brand\": \"\($0)\"," } ?? "")
              "images": ["https://cdn.example/\(id).webp"], "thumbnail": "https://cdn.example/t\(id).webp"
            }
            """
            // Force-decoding a literal the test itself wrote is safe and keeps the fixture readable.
            return try! JSONDecoder().decode(ProductDTO.self, from: Data(json.utf8))
        }
    }

    // MARK: - Order and paging

    @Test("The first page defines positions 0..<n and the cursor")
    func replaceFirstPage() async throws {
        let store = try makeStore()

        try await store.replaceFirstPage(makeDTOs(ids: [30, 10, 20]), total: 194)

        let products = await store.currentProducts()
        #expect(products.map(\.id) == [30, 10, 20], "Server order was not preserved")

        let cursor = await store.pageCursor()
        #expect(cursor?.nextSkip == 3)
        #expect(cursor?.total == 194)
        #expect(cursor?.hasMore == true)
    }

    @Test("An append continues the order and moves the cursor")
    func appendPage() async throws {
        let store = try makeStore()
        try await store.replaceFirstPage(makeDTOs(ids: [1, 2, 3]), total: 6)

        try await store.appendPage(makeDTOs(ids: [4, 5, 6]), startingAt: 3, total: 6)

        let products = await store.currentProducts()
        #expect(products.map(\.id) == [1, 2, 3, 4, 5, 6])

        let cursor = await store.pageCursor()
        #expect(cursor?.nextSkip == 6)
        #expect(cursor?.hasMore == false, "The cursor should know the catalogue is exhausted")
    }

    /// A refresh truncates to one page. That is the accepted cost of replace-and-reinsert,
    /// and it is written down as a test so nobody "fixes" it later by accident.
    @Test("A refresh replaces everything, it does not merge")
    func refreshTruncates() async throws {
        let store = try makeStore()
        try await store.replaceFirstPage(makeDTOs(ids: [1, 2, 3]), total: 6)
        try await store.appendPage(makeDTOs(ids: [4, 5, 6]), startingAt: 3, total: 6)

        try await store.replaceFirstPage(makeDTOs(ids: [1, 2, 3]), total: 6)

        let products = await store.currentProducts()
        #expect(products.map(\.id) == [1, 2, 3])
        #expect(await store.pageCursor()?.nextSkip == 3)
    }

    // MARK: - Reads

    @Test("Local search matches title and brand, case- and accent-insensitively")
    func localSearch() async throws {
        let store = try makeStore()
        try await store.replaceFirstPage(
            makeDTOs(ids: [1], titlePrefix: "Cámara") + makeDTOs(ids: [2], titlePrefix: "Phone", brand: "Zenith"),
            total: 2
        )

        #expect(await store.search(query: "camara").map(\.id) == [1], "Accent folding is not working")
        #expect(await store.search(query: "ZENITH").map(\.id) == [2], "Case folding is not working")
        #expect(await store.search(query: "nothing here").isEmpty)
    }

    @Test("A single product can be read by id")
    func productById() async throws {
        let store = try makeStore()
        try await store.replaceFirstPage(makeDTOs(ids: [7, 8]), total: 2)

        #expect(await store.product(id: 8)?.id == 8)
        #expect(await store.product(id: 999) == nil)
    }

    // MARK: - The stream that replaces @Query

    @Test("The stream emits current contents immediately, then once per write")
    func streamEmitsOnWrite() async throws {
        let store = try makeStore()
        try await store.replaceFirstPage(makeDTOs(ids: [1]), total: 3)

        var iterator = await store.productsStream().makeAsyncIterator()

        // Immediately: what is already cached. This is why a screen opening offline has content on
        // its first frame.
        let initial = await iterator.next()
        #expect(initial?.map(\.id) == [1])

        try await store.appendPage(makeDTOs(ids: [2]), startingAt: 1, total: 3)
        let afterAppend = await iterator.next()
        #expect(afterAppend?.map(\.id) == [1, 2])

        try await store.replaceFirstPage(makeDTOs(ids: [9]), total: 3)
        let afterRefresh = await iterator.next()
        #expect(afterRefresh?.map(\.id) == [9])
    }

    @Test("Every reader sees every write")
    func streamFansOut() async throws {
        let store = try makeStore()
        var first = await store.productsStream().makeAsyncIterator()
        var second = await store.productsStream().makeAsyncIterator()
        _ = await first.next()
        _ = await second.next()

        try await store.replaceFirstPage(makeDTOs(ids: [42]), total: 1)

        #expect(await first.next()?.map(\.id) == [42])
        #expect(await second.next()?.map(\.id) == [42])
    }

    /// Without this, the store accumulates one continuation per screen that ever appeared.
    @Test("A finished stream stops being fed")
    func streamUnsubscribesOnTermination() async throws {
        let store = try makeStore()

        do {
            let stream = await store.productsStream()
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
        } // The stream goes out of scope here.

        // Give the termination handler a turn to run.
        try await Task.sleep(for: .milliseconds(50))
        try await store.replaceFirstPage(makeDTOs(ids: [1]), total: 1)

        #expect(await store.subscriberCount == 0, "The store is still holding a dead subscriber")
    }

    // MARK: - The second writer

    @Test("A row refresh keeps the position it already had")
    func rowRefreshPreservesPosition() async throws {
        let store = try makeStore()
        try await store.replaceFirstPage(makeDTOs(ids: [1, 2, 3]), total: 3)

        // The same product, arriving from the detail endpoint with a new title.
        try await store.updateProduct(from: makeDTOs(ids: [2], titlePrefix: "Renamed")[0])

        let products = await store.currentProducts()
        #expect(products.map(\.id) == [1, 2, 3], "The grid was reordered by a detail refresh")
        #expect(products[1].title == "Renamed 2")
    }

    /// The race the actor exists to close: a page replace and a row refresh landing at the
    /// same time must not leave the grid reordered or a position duplicated.
    @Test("A page refresh and a row refresh at the same time keep positions intact")
    func concurrentWritersKeepPositions() async throws {
        let store = try makeStore()
        try await store.replaceFirstPage(makeDTOs(ids: [1, 2, 3]), total: 3)

        async let rowRefresh: Void = store.updateProduct(from: makeDTOs(ids: [2], titlePrefix: "Renamed")[0])
        async let pageRefresh: Void = store.replaceFirstPage(makeDTOs(ids: [1, 2, 3]), total: 3)
        _ = try await (rowRefresh, pageRefresh)

        let products = await store.currentProducts()
        #expect(products.count == 3)
        #expect(products.map(\.id) == [1, 2, 3], "The grid order survived neither writer")

        // The invariant that matters: positions are exactly 0..<n, with no duplicates. A row written
        // against a generation of the table that no longer exists shows up here.
        let positions = await store.debugPositions()
        #expect(positions == [0, 1, 2], "Positions ended up as \(positions)")
    }

    @Test("A row refresh that changes nothing does not write")
    func rowRefreshSkipsWhenUnchanged() async throws {
        let store = try makeStore()
        let dtos = makeDTOs(ids: [1])
        try await store.replaceFirstPage(dtos, total: 1)

        var iterator = await store.productsStream().makeAsyncIterator()
        _ = await iterator.next()

        try await store.updateProduct(from: dtos[0])

        // No broadcast means no needless churn in the grid. Proven by the next real write arriving
        // as the next emission.
        try await store.appendPage(makeDTOs(ids: [2]), startingAt: 1, total: 2)
        #expect(await iterator.next()?.map(\.id) == [1, 2])
    }
}
