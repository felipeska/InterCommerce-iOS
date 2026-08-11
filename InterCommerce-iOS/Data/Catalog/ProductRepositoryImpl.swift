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

    init(store: CatalogStore, paginator: CatalogPaginator) {
        self.store = store
        self.paginator = paginator
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

    func refreshCatalogIfStale(ttl: Duration) async -> PageOutcome {
        await paginator.refreshIfStale(ttl: ttl)
    }

    func refreshCatalog() async -> PageOutcome {
        await paginator.refresh()
    }

    func loadNextPage() async -> PageOutcome {
        await paginator.loadNextPage()
    }
}
