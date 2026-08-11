//
//  CatalogModelTests.swift
//  Features tests
//
//  Fakes are plain structs — there is no mocking library and none is needed. The model takes three
//  use cases, so wiring a scenario is three lines (ADR §16, §31).
//

import Foundation
import Testing

@testable import InterCommerce_iOS

@MainActor
struct CatalogModelTests {

    private func makeModel(repository: FakeProductRepository) -> CatalogModel {
        CatalogModel(
            observeCatalog: ObserveCatalog(repository: repository),
            refreshCatalog: RefreshCatalog(repository: repository),
            loadNextPage: LoadNextPage(repository: repository)
        )
    }

    // MARK: - Content

    @Test("Products arrive through the stream, never from the refresh call")
    func observesProducts() async {
        let repository = FakeProductRepository(products: Product.previewList)
        let model = makeModel(repository: repository)

        await model.start()

        #expect(model.products.count == 3)
        #expect(model.refresh == .idle)
    }

    @Test("Skeletons show only while loading with nothing cached")
    func showsSkeletonsWhenEmpty() async {
        let repository = FakeProductRepository(products: [], refreshOutcome: .loaded)
        let model = makeModel(repository: repository)

        #expect(model.showsSkeletons == false, "Nothing has been asked for yet")

        await model.start()
        #expect(model.showsSkeletons == false, "The load finished")
    }

    // MARK: - The offline rule

    /// The heart of the brief: losing the network with content on screen produces a banner, not an
    /// error screen. Content the user can still read is never replaced by a failure.
    @Test("A failed refresh with cached products shows a banner, not an error")
    func failureWithContentIsABanner() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            refreshOutcome: .failed(.noConnection)
        )
        let model = makeModel(repository: repository)

        await model.start()

        #expect(model.products.count == 3, "Products were dropped on a failed refresh")
        #expect(model.isOffline)
        #expect(model.failure == nil, "An error screen would have covered readable content")
    }

    @Test("A failed refresh with nothing cached shows the error screen")
    func failureWithoutContentIsAnError() async {
        let repository = FakeProductRepository(products: [], refreshOutcome: .failed(.noConnection))
        let model = makeModel(repository: repository)

        await model.start()

        #expect(model.failure == .noConnection)
        #expect(model.isOffline == false)
    }

    // MARK: - Cancellation

    /// A cancelled load must leave the screen exactly as it was: writing state nobody will read is
    /// how a cancelled request ends up rendering "no connection".
    @Test("Cancellation leaves the phase untouched")
    func cancellationDoesNotChangeState() async {
        let repository = FakeProductRepository(products: Product.previewList, refreshOutcome: .cancelled)
        let model = makeModel(repository: repository)

        await model.start()

        #expect(model.refresh == .idle)
        #expect(model.failure == nil)
        #expect(model.isOffline == false)
    }

    // MARK: - Paging

    @Test("Loading more reports its own failure without touching the content")
    func appendFailureIsIsolated() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            nextPageOutcome: .failed(.timeout)
        )
        let model = makeModel(repository: repository)
        await model.start()

        await model.loadMore()

        #expect(model.append == .failed(.timeout))
        #expect(model.products.count == 3, "A failed page load dropped the products")
        #expect(model.failure == nil, "A failed page load took over the whole screen")
    }

    @Test("A no-op page load is not a failure")
    func noopIsNotAFailure() async {
        let repository = FakeProductRepository(products: Product.previewList, nextPageOutcome: .noop)
        let model = makeModel(repository: repository)
        await model.start()

        await model.loadMore()

        #expect(model.append == .idle)
    }

    @Test("The sentinel cannot start two page loads at once")
    func loadMoreIsGuarded() async {
        let repository = FakeProductRepository(products: Product.previewList, nextPageDelay: .milliseconds(200))
        let model = makeModel(repository: repository)
        await model.start()

        async let first: Void = model.loadMore()
        async let second: Void = model.loadMore()
        _ = await (first, second)

        #expect(await repository.nextPageCallCount == 1, "The grid asked for the same page twice")
    }
}

// MARK: - Fake

private actor FakeProductRepository: ProductRepository {
    private let products: [Product]
    private let refreshOutcome: PageOutcome
    private let nextPageOutcome: PageOutcome
    private let nextPageDelay: Duration?
    private(set) var nextPageCallCount = 0

    init(
        products: [Product],
        refreshOutcome: PageOutcome = .loaded,
        nextPageOutcome: PageOutcome = .loaded,
        nextPageDelay: Duration? = nil
    ) {
        self.products = products
        self.refreshOutcome = refreshOutcome
        self.nextPageOutcome = nextPageOutcome
        self.nextPageDelay = nextPageDelay
    }

    nonisolated func observeCatalog() -> AsyncStream<[Product]> {
        let products = products
        return AsyncStream { continuation in
            continuation.yield(products)
            continuation.finish()
        }
    }

    func refreshCatalogIfStale(ttl: Duration) async -> PageOutcome { refreshOutcome }
    func refreshCatalog() async -> PageOutcome { refreshOutcome }

    func loadNextPage() async -> PageOutcome {
        nextPageCallCount += 1
        if let nextPageDelay { try? await Task.sleep(for: nextPageDelay) }
        return nextPageOutcome
    }
}
