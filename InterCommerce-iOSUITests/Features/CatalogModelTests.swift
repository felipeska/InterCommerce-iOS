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
            loadNextPage: LoadNextPage(repository: repository),
            searchProducts: SearchProducts(repository: repository)
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

    // MARK: - Search

    @Test("A query shorter than two characters leaves the catalogue alone", arguments: ["", "a", " x "])
    func shortQueriesDoNotSearch(query: String) async {
        let repository = FakeProductRepository(products: Product.previewList)
        let model = makeModel(repository: repository)
        await model.start()

        await model.runSearch(query, debounce: .zero)

        #expect(model.search == .inactive)
        #expect(model.visibleProducts.count == 3, "The catalogue should still be on screen")
        #expect(await repository.searchCallCount == 0, "It searched for something too short to mean anything")
    }

    @Test("Remote results replace the grid without touching the catalogue")
    func remoteResults() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            searchOutcome: .results(SearchResults(products: [Product.preview], source: .remote))
        )
        let model = makeModel(repository: repository)
        await model.start()

        await model.runSearch("mascara", debounce: .zero)

        #expect(model.visibleProducts.map(\.id) == [1])
        #expect(model.showsOfflineBanner == false)
        #expect(model.products.count == 3, "The cached catalogue was overwritten by a search")
    }

    /// The degradation the brief asks for: a failed request is answered from the cache, and the
    /// screen says so.
    @Test("Local results raise the offline banner")
    func localResultsAreFlagged() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            searchOutcome: .results(SearchResults(products: [Product.preview], source: .local(reason: .noConnection)))
        )
        let model = makeModel(repository: repository)
        await model.start()

        await model.runSearch("mascara", debounce: .zero)

        #expect(model.visibleProducts.map(\.id) == [1])
        #expect(model.showsOfflineBanner, "A cached answer was presented as if it were fresh")
    }

    @Test("No matches offline says so, rather than claiming the product does not exist")
    func emptyLocalResults() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            searchOutcome: .results(SearchResults(products: [], source: .local(reason: .noConnection)))
        )
        let model = makeModel(repository: repository)
        await model.start()

        await model.runSearch("nothing", debounce: .zero)

        #expect(model.search == .empty(isLocal: true))
    }

    /// The debounce: a query the user typed past never reaches the network.
    @Test("Typing over a query cancels it before it is sent")
    func debounceDropsSupersededQueries() async throws {
        let repository = FakeProductRepository(products: Product.previewList)
        let model = makeModel(repository: repository)

        let typing = Task { await model.runSearch("pho", debounce: .milliseconds(300)) }
        try await Task.sleep(for: .milliseconds(50))
        typing.cancel()
        _ = await typing.value

        #expect(await repository.searchCallCount == 0, "The superseded query still hit the network")
    }

    @Test("A cancelled search leaves the previous results on screen")
    func cancelledSearchKeepsResults() async {
        let repository = FakeProductRepository(products: Product.previewList, searchOutcome: .cancelled)
        let model = makeModel(repository: repository)
        await model.start()

        await model.runSearch("phone", debounce: .zero)

        #expect(model.search == .searching, "A superseded search should not blank the screen")
    }
}

// MARK: - Fake

private actor FakeProductRepository: ProductRepository {
    private let products: [Product]
    private let refreshOutcome: PageOutcome
    private let nextPageOutcome: PageOutcome
    private let nextPageDelay: Duration?
    private let searchOutcome: SearchOutcome
    private let searchDelay: Duration?
    private(set) var nextPageCallCount = 0
    private(set) var searchCallCount = 0

    init(
        products: [Product],
        refreshOutcome: PageOutcome = .loaded,
        nextPageOutcome: PageOutcome = .loaded,
        nextPageDelay: Duration? = nil,
        searchOutcome: SearchOutcome = .results(SearchResults(products: [], source: .remote)),
        searchDelay: Duration? = nil
    ) {
        self.products = products
        self.refreshOutcome = refreshOutcome
        self.nextPageOutcome = nextPageOutcome
        self.nextPageDelay = nextPageDelay
        self.searchOutcome = searchOutcome
        self.searchDelay = searchDelay
    }

    nonisolated func observeCatalog() -> AsyncStream<[Product]> {
        let products = products
        return AsyncStream { continuation in
            continuation.yield(products)
            continuation.finish()
        }
    }

    func search(query: String) async -> SearchOutcome {
        searchCallCount += 1
        if let searchDelay { try? await Task.sleep(for: searchDelay) }
        return searchOutcome
    }

    func refreshCatalogIfStale(ttl: Duration) async -> PageOutcome { refreshOutcome }
    func refreshCatalog() async -> PageOutcome { refreshOutcome }

    func loadNextPage() async -> PageOutcome {
        nextPageCallCount += 1
        if let nextPageDelay { try? await Task.sleep(for: nextPageDelay) }
        return nextPageOutcome
    }
}
