//
//  CatalogPaginatorTests.swift
//  Data tests
//
//  One test per rule from plan.md §3.3. These are the guarantees Paging 3 provides on the Android
//  side; here they are ours to keep, so they are the ones worth pinning hardest.
//

import Foundation
import Testing

@testable import InterCommerce_iOS

@Suite(.serialized)
struct CatalogPaginatorTests {

    private let host = "paginator.test"

    private func makePaginator(pageSize: Int = 2) throws -> (CatalogPaginator, CatalogStore) {
        let client = HTTPClient(
            baseURL: URL(string: "https://\(host)")!,
            session: URLProtocolStub.makeSession(),
            middlewares: []
        )
        let store = CatalogStore(modelContainer: try ModelContainerFactory.inMemory())
        return (CatalogPaginator(api: ProductAPI(client: client), store: store, pageSize: pageSize), store)
    }

    private func page(ids: [Int], total: Int) -> Data {
        let products = ids.map { id in
            """
            { "id": \(id), "title": "P\(id)", "description": "", "category": "c",
              "price": 9.99, "discountPercentage": 0, "rating": 4, "stock": 5,
              "images": [], "thumbnail": "https://cdn.example/\(id).webp" }
            """
        }.joined(separator: ",")
        return Data("""
        { "products": [\(products)], "total": \(total), "skip": 0, "limit": \(ids.count) }
        """.utf8)
    }

    // MARK: - Rule 1 · idempotence

    /// The trigger is the last cell appearing, which fires repeatedly during a fast scroll. Two
    /// concurrent calls must produce **one** request, or the catalogue pages twice and skips rows.
    @Test("Concurrent loads produce a single request")
    func concurrentLoadsCoalesce() async throws {
        let (paginator, _) = try makePaginator()
        URLProtocolStub.set(.slowResponse(status: 200, body: page(ids: [1, 2], total: 10), delay: .milliseconds(250)), host: host)

        async let first = paginator.refresh()
        async let second = paginator.refresh()
        async let third = paginator.refresh()
        let outcomes = await [first, second, third]

        #expect(URLProtocolStub.requests(host: host).count == 1)
        #expect(outcomes.filter { $0 == .loaded }.count == 1)
        #expect(outcomes.filter { $0 == .noop }.count == 2, "The extra calls should be no-ops, not failures")
    }

    // MARK: - Rule 2 · nothing is written when the request fails

    /// The scenario the brief tests with airplane mode: the list must survive a failed refresh.
    @Test("A failed refresh leaves the cached catalogue untouched")
    func failedRefreshKeepsCache() async throws {
        let (paginator, store) = try makePaginator()
        URLProtocolStub.set(.response(status: 200, body: page(ids: [1, 2], total: 10)), host: host)
        #expect(await paginator.refresh() == .loaded)

        URLProtocolStub.set(.failure(.notConnectedToInternet), host: host)
        let outcome = await paginator.refresh()

        #expect(outcome == .failed(.noConnection))
        #expect(await store.currentProducts().map(\.id) == [1, 2], "A failed refresh emptied the cache")
        #expect(await store.pageCursor()?.nextSkip == 2, "The cursor moved on a failed refresh")
    }

    // MARK: - Rule 3 · end of pagination

    @Test("Past the end of the catalogue there is no request at all")
    func stopsAtTheEnd() async throws {
        let (paginator, _) = try makePaginator()
        URLProtocolStub.set(.response(status: 200, body: page(ids: [1, 2], total: 2)), host: host)
        _ = await paginator.refresh()

        let outcome = await paginator.loadNextPage()

        #expect(outcome == .noop)
        #expect(URLProtocolStub.requests(host: host).count == 1, "It asked for a page that cannot exist")
    }

    @Test("Pages continue from the cursor, keeping the server's order")
    func appendsFromCursor() async throws {
        let (paginator, store) = try makePaginator()
        URLProtocolStub.set(.response(status: 200, body: page(ids: [1, 2], total: 4)), host: host)
        _ = await paginator.refresh()

        URLProtocolStub.set(.response(status: 200, body: page(ids: [3, 4], total: 4)), host: host)
        #expect(await paginator.loadNextPage() == .loaded)

        #expect(await store.currentProducts().map(\.id) == [1, 2, 3, 4])
        let skip = URLProtocolStub.requests(host: host).last?.url?.query()?.contains("skip=2")
        #expect(skip == true, "The second page did not ask for skip=2")
    }

    // MARK: - Rule 4 · TTL

    @Test("A fresh cache is not refreshed")
    func freshCacheIsNotRefetched() async throws {
        let (paginator, _) = try makePaginator()
        let now = Date()
        URLProtocolStub.set(.response(status: 200, body: page(ids: [1, 2], total: 10)), host: host)
        _ = await paginator.refresh(now: now)

        let outcome = await paginator.refreshIfStale(ttl: .seconds(1_800), now: now.addingTimeInterval(60))

        #expect(outcome == .noop)
        #expect(URLProtocolStub.requests(host: host).count == 1)
    }

    @Test("A stale cache is refreshed")
    func staleCacheIsRefetched() async throws {
        let (paginator, _) = try makePaginator()
        let now = Date()
        URLProtocolStub.set(.response(status: 200, body: page(ids: [1, 2], total: 10)), host: host)
        _ = await paginator.refresh(now: now)

        let outcome = await paginator.refreshIfStale(ttl: .seconds(1_800), now: now.addingTimeInterval(3_600))

        #expect(outcome == .loaded)
        #expect(URLProtocolStub.requests(host: host).count == 2)
    }

    // MARK: - Rule 5 · cancellation

    /// A cancelled load is not a failure, and must not be shown as one.
    @Test("Cancellation is reported as cancelled, never as an error")
    func cancellationIsNotAFailure() async throws {
        let (paginator, store) = try makePaginator()
        URLProtocolStub.set(.hang, host: host)

        let task = Task { await paginator.refresh() }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        let outcome = await task.value
        #expect(outcome == .cancelled)
        #expect(outcome.error == nil, "Cancellation leaked into AppError")
        #expect(await store.currentProducts().isEmpty, "A cancelled load wrote to the store")
    }

    /// After a cancellation the actor must be free again, or the screen never loads anything else.
    @Test("A cancelled load releases the paginator")
    func cancellationReleasesTheActor() async throws {
        let (paginator, store) = try makePaginator()
        URLProtocolStub.set(.hang, host: host)

        let task = Task { await paginator.refresh() }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        _ = await task.value

        URLProtocolStub.set(.response(status: 200, body: page(ids: [1, 2], total: 2)), host: host)
        #expect(await paginator.refresh() == .loaded)
        #expect(await store.currentProducts().count == 2)
    }
}
