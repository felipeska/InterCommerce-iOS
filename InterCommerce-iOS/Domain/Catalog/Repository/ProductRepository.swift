//
//  ProductRepository.swift
//  Domain · Catalog · Repository
//
//  Everything the app is allowed to know about where products come from.
//
//  Read the signatures and notice what is absent: no `ModelContext`, no `ProductEntity`, no
//  `URLSession`, no DTO — and no `searchRemote`/`searchLocal` either. Whether an answer came from
//  the network or from disk is Data's business; a domain contract that named the transport would
//  force every caller to re-implement the fallback.
//

import Foundation

nonisolated protocol ProductRepository: Sendable {
    /// The catalogue, in server order, as it changes. Emits what is cached straight away — which is
    /// what puts content on the first frame when the app opens offline.
    func observeCatalog() -> AsyncStream<[Product]>

    /// Refreshes only if the cache has aged past `ttl`.
    func refreshCatalogIfStale(ttl: Duration) async -> LoadOutcome

    /// Forces a refresh: pull-to-refresh, or the retry button.
    func refreshCatalog() async -> LoadOutcome

    /// Loads the page after the cursor.
    func loadNextPage() async -> LoadOutcome

    /// A single product, as it changes. Emits the cached copy immediately, so the detail screen has
    /// content on its first frame even with no network.
    func observeProduct(id: Int) -> AsyncStream<Product?>

    /// Refreshes one product in the background. The second writer of `ProductEntity`.
    func refreshProduct(id: Int) async -> LoadOutcome

    /// Searches the catalogue.
    ///
    /// One method, not `searchRemote` plus `searchLocal`: deciding when to serve from disk is Data's
    /// job, and a domain contract that named the transport would push that decision into every
    /// caller.
    func search(query: String) async -> SearchOutcome
}
