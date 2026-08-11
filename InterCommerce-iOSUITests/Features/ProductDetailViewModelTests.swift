//
//  ProductDetailViewModelTests.swift
//  Features tests
//
//  The detail is cache-first: it must show a stored product with no network at all, and a failed
//  background refresh must never take over a screen that is already readable.
//

import Foundation
import Testing

@testable import InterCommerce_iOS

@MainActor
struct ProductDetailViewModelTests {

    private func makeViewModel(id: Int = 1, repository: FakeDetailRepository) -> ProductDetailViewModel {
        ProductDetailViewModel(
            productId: id,
            observeProduct: ObserveProduct(repository: repository),
            refreshProduct: RefreshProduct(repository: repository),
            observeCart: ObserveCart(repository: EmptyCartRepository()),
            addToCart: AddToCart(repository: EmptyCartRepository())
        )
    }

    @Test("A cached product shows even when the refresh fails")
    func showsCachedProductOffline() async {
        let viewModel = makeViewModel(repository: FakeDetailRepository(
            product: .preview,
            refreshOutcome: .failed(.noConnection)
        ))

        await viewModel.start()

        #expect(viewModel.product?.id == 1)
        #expect(viewModel.failure == nil, "A failed background refresh covered a readable screen")
    }

    @Test("With nothing cached and no network, the error surfaces")
    func failsWhenNothingCached() async {
        let viewModel = makeViewModel(repository: FakeDetailRepository(
            product: nil,
            refreshOutcome: .failed(.noConnection)
        ))

        await viewModel.start()

        #expect(viewModel.product == nil)
        #expect(viewModel.failure == .noConnection)
    }

    @Test("A successful refresh reaches the screen through the stream")
    func refreshUpdatesTheScreen() async {
        let repository = FakeDetailRepository(product: .preview, refreshOutcome: .loaded)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.start()

        #expect(viewModel.product?.title == "Essence Mascara Lash Princess")
        #expect(await repository.refreshCallCount == 1)
    }

    /// Cancellation is not a failure: leaving the screen must not paint an error on the way out.
    @Test("A cancelled refresh reports nothing")
    func cancelledRefreshIsSilent() async {
        let viewModel = makeViewModel(repository: FakeDetailRepository(product: nil, refreshOutcome: .cancelled))

        await viewModel.start()

        #expect(viewModel.failure == nil)
    }

    @Test("Retrying after a failure asks again")
    func retryAsksAgain() async {
        let repository = FakeDetailRepository(product: nil, refreshOutcome: .failed(.timeout))
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.refresh()

        #expect(await repository.refreshCallCount == 2)
    }
}

private struct EmptyCartRepository: CartRepository {
    func observeLines() -> AsyncStream<[CartLine]> { AsyncStream { $0.finish() } }
    func add(_ product: Product, quantity: Int) async {}
    func setQuantity(_ quantity: Int, productId: Int) async {}
    func remove(productId: Int) async {}
}

// MARK: - Fake

private actor FakeDetailRepository: ProductRepository {
    private let product: Product?
    private let refreshOutcome: LoadOutcome
    private(set) var refreshCallCount = 0

    init(product: Product?, refreshOutcome: LoadOutcome) {
        self.product = product
        self.refreshOutcome = refreshOutcome
    }

    nonisolated func observeProduct(id: Int) -> AsyncStream<Product?> {
        let product = product
        return AsyncStream { continuation in
            continuation.yield(product)
            continuation.finish()
        }
    }

    func refreshProduct(id: Int) async -> LoadOutcome {
        refreshCallCount += 1
        return refreshOutcome
    }

    nonisolated func observeCatalog() -> AsyncStream<[Product]> {
        AsyncStream { $0.finish() }
    }

    func refreshCatalogIfStale(ttl: Duration) async -> LoadOutcome { .noop }
    func refreshCatalog() async -> LoadOutcome { .noop }
    func loadNextPage() async -> LoadOutcome { .noop }
    func search(query: String) async -> SearchOutcome {
        .results(SearchResults(products: [], source: .remote))
    }
}
