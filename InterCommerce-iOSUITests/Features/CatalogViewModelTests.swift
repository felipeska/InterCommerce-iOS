//
//  CatalogViewModelTests.swift
//  Features tests
//
//  Fakes are plain structs — there is no mocking library and none is needed. The model takes three
//  use cases, so wiring a scenario is three lines.
//

import Foundation
import Testing

@testable import InterCommerce_iOS

@MainActor
struct CatalogViewModelTests {

    private func makeViewModel(repository: FakeProductRepository) -> CatalogViewModel {
        CatalogViewModel(
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
        let viewModel = makeViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.products.count == 3)
        #expect(viewModel.refresh == .idle)
    }

    @Test("Skeletons show only while loading with nothing cached")
    func showsSkeletonsWhenEmpty() async {
        let repository = FakeProductRepository(products: [], refreshOutcome: .loaded)
        let viewModel = makeViewModel(repository: repository)

        #expect(viewModel.showsSkeletons == false, "Nothing has been asked for yet")

        await viewModel.start()
        #expect(viewModel.showsSkeletons == false, "The load finished")
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
        let viewModel = makeViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.products.count == 3, "Products were dropped on a failed refresh")
        #expect(viewModel.isOffline)
        #expect(viewModel.failure == nil, "An error screen would have covered readable content")
    }

    @Test("A failed refresh with nothing cached shows the error screen")
    func failureWithoutContentIsAnError() async {
        let repository = FakeProductRepository(products: [], refreshOutcome: .failed(.noConnection))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.failure == .noConnection)
        #expect(viewModel.isOffline == false)
    }

    // MARK: - Cancellation

    /// A cancelled load must leave the screen exactly as it was: writing state nobody will read is
    /// how a cancelled request ends up rendering "no connection".
    @Test("Cancellation leaves the phase untouched")
    func cancellationDoesNotChangeState() async {
        let repository = FakeProductRepository(products: Product.previewList, refreshOutcome: .cancelled)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.refresh == .idle)
        #expect(viewModel.failure == nil)
        #expect(viewModel.isOffline == false)
    }

    // MARK: - Paging

    @Test("Loading more reports its own failure without touching the content")
    func appendFailureIsIsolated() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            nextLoadOutcome: .failed(.timeout)
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.loadMore()

        #expect(viewModel.append == .failed(.timeout))
        #expect(viewModel.products.count == 3, "A failed page load dropped the products")
        #expect(viewModel.failure == nil, "A failed page load took over the whole screen")
    }

    @Test("A no-op page load is not a failure")
    func noopIsNotAFailure() async {
        let repository = FakeProductRepository(products: Product.previewList, nextLoadOutcome: .noop)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.loadMore()

        #expect(viewModel.append == .idle)
    }

    @Test("The sentinel cannot start two page loads at once")
    func loadMoreIsGuarded() async {
        let repository = FakeProductRepository(products: Product.previewList, nextPageDelay: .milliseconds(200))
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        async let first: Void = viewModel.loadMore()
        async let second: Void = viewModel.loadMore()
        _ = await (first, second)

        #expect(await repository.nextPageCallCount == 1, "The grid asked for the same page twice")
    }

    // MARK: - Search

    @Test("A query shorter than two characters leaves the catalogue alone", arguments: ["", "a", " x "])
    func shortQueriesDoNotSearch(query: String) async {
        let repository = FakeProductRepository(products: Product.previewList)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.runSearch(query, debounce: .zero)

        #expect(viewModel.search == .inactive)
        #expect(viewModel.visibleProducts.count == 3, "The catalogue should still be on screen")
        #expect(await repository.searchCallCount == 0, "It searched for something too short to mean anything")
    }

    @Test("Remote results replace the grid without touching the catalogue")
    func remoteResults() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            searchOutcome: .results(SearchResults(products: [Product.preview], source: .remote))
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.runSearch("mascara", debounce: .zero)

        #expect(viewModel.visibleProducts.map(\.id) == [1])
        #expect(viewModel.showsOfflineBanner == false)
        #expect(viewModel.products.count == 3, "The cached catalogue was overwritten by a search")
    }

    /// The degradation the brief asks for: a failed request is answered from the cache, and the
    /// screen says so.
    @Test("Local results raise the offline banner")
    func localResultsAreFlagged() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            searchOutcome: .results(SearchResults(products: [Product.preview], source: .local(reason: .noConnection)))
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.runSearch("mascara", debounce: .zero)

        #expect(viewModel.visibleProducts.map(\.id) == [1])
        #expect(viewModel.showsOfflineBanner, "A cached answer was presented as if it were fresh")
    }

    @Test("No matches offline says so, rather than claiming the product does not exist")
    func emptyLocalResults() async {
        let repository = FakeProductRepository(
            products: Product.previewList,
            searchOutcome: .results(SearchResults(products: [], source: .local(reason: .noConnection)))
        )
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.runSearch("nothing", debounce: .zero)

        #expect(viewModel.search == .empty(isLocal: true))
    }

    /// The debounce: a query the user typed past never reaches the network.
    @Test("Typing over a query cancels it before it is sent")
    func debounceDropsSupersededQueries() async throws {
        let repository = FakeProductRepository(products: Product.previewList)
        let viewModel = makeViewModel(repository: repository)

        let typing = Task { await viewModel.runSearch("pho", debounce: .milliseconds(300)) }
        try await Task.sleep(for: .milliseconds(50))
        typing.cancel()
        _ = await typing.value

        #expect(await repository.searchCallCount == 0, "The superseded query still hit the network")
    }

    @Test("A cancelled search leaves the previous results on screen")
    func cancelledSearchKeepsResults() async {
        let repository = FakeProductRepository(products: Product.previewList, searchOutcome: .cancelled)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.runSearch("phone", debounce: .zero)

        #expect(viewModel.search == .searching, "A superseded search should not blank the screen")
    }
}

// MARK: - Fake

private actor FakeProductRepository: ProductRepository {
    private let products: [Product]
    private let refreshOutcome: LoadOutcome
    private let nextLoadOutcome: LoadOutcome
    private let nextPageDelay: Duration?
    private let searchOutcome: SearchOutcome
    private let searchDelay: Duration?
    private(set) var nextPageCallCount = 0
    private(set) var searchCallCount = 0

    init(
        products: [Product],
        refreshOutcome: LoadOutcome = .loaded,
        nextLoadOutcome: LoadOutcome = .loaded,
        nextPageDelay: Duration? = nil,
        searchOutcome: SearchOutcome = .results(SearchResults(products: [], source: .remote)),
        searchDelay: Duration? = nil
    ) {
        self.products = products
        self.refreshOutcome = refreshOutcome
        self.nextLoadOutcome = nextLoadOutcome
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

    nonisolated func observeProduct(id: Int) -> AsyncStream<Product?> {
        AsyncStream { $0.finish() }
    }

    func refreshProduct(id: Int) async -> LoadOutcome { .noop }

    func refreshCatalogIfStale(ttl: Duration) async -> LoadOutcome { refreshOutcome }
    func refreshCatalog() async -> LoadOutcome { refreshOutcome }

    func loadNextPage() async -> LoadOutcome {
        nextPageCallCount += 1
        if let nextPageDelay { try? await Task.sleep(for: nextPageDelay) }
        return nextLoadOutcome
    }
}
