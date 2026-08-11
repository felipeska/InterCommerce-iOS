//
//  ProductRepositoryImpl.swift
//  Data · Catalog
//
//  Wires the store and the paginator behind the domain contract. Thin on purpose: the decisions live
//  in the pieces it composes, not here.
//

import Foundation

nonisolated struct ProductRepositoryImpl: ProductRepository {
    private let store: CatalogStore
    private let paginator: CatalogPaginator
    private let api: ProductAPI
    private let searchPageSize: Int

    init(store: CatalogStore, paginator: CatalogPaginator, api: ProductAPI, searchPageSize: Int = 30) {
        self.store = store
        self.paginator = paginator
        self.api = api
        self.searchPageSize = searchPageSize
    }

    func observeCatalog() -> AsyncStream<[Product]> {
        // The stream is created inside the actor, so the handshake is asynchronous while the
        // returned sequence is not. Bridging here keeps that detail out of the domain contract.
        AsyncStream { continuation in
            let task = Task {
                for await products in await store.productsStream() {
                    continuation.yield(products)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func refreshCatalogIfStale(ttl: Duration) async -> LoadOutcome {
        await paginator.refreshIfStale(ttl: ttl)
    }

    func refreshCatalog() async -> LoadOutcome {
        await paginator.refresh()
    }

    func loadNextPage() async -> LoadOutcome {
        await paginator.loadNextPage()
    }

    func observeProduct(id: Int) -> AsyncStream<Product?> {
        // Derived from the catalogue stream rather than a second subscription: one source of truth,
        // and the detail sees a row refresh the moment the store broadcasts it.
        AsyncStream { continuation in
            let task = Task {
                for await products in await store.productsStream() {
                    continuation.yield(products.first { $0.id == id })
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Refreshes one row. The write itself — preserve `position`, only if changed, read and write in
    /// a single actor method — is `CatalogStore.updateProduct`.
    func refreshProduct(id: Int) async -> LoadOutcome {
        do {
            let dto = try await api.product(id: id)
            try Task.checkCancellation()
            try await store.updateProduct(from: dto)
            return .loaded
        } catch {
            return LoadOutcome(error)
        }
    }

    /// Remote first, cache second.
    ///
    /// The fallback is triggered by the request **failing**, never by asking the system whether
    /// there is a network: the OS can report a connection while a captive portal swallows every
    /// request, and two sources of truth that disagree are worse than one.
    func search(query: String) async -> SearchOutcome {
        do {
            let page = try await api.searchProducts(query: query, limit: searchPageSize, skip: 0)
            let products = page.products.enumerated().map { index, dto in
                ProductMapper.domain(from: ProductMapper.entity(from: dto, position: index))
            }
            return .results(SearchResults(products: products, source: .remote))
        } catch is CancellationError {
            return .cancelled
        } catch let error as URLError where error.code == .cancelled {
            return .cancelled
        } catch {
            let reason = (try? AppError.mapping(error)) ?? .unknown
            // Whatever has already been downloaded. Documented limitation: offline search only finds
            // products the app has seen.
            return .results(SearchResults(products: await store.search(query: query), source: .local(reason: reason)))
        }
    }
}
