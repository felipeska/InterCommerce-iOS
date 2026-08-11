//
//  ProductRepository.swift
//  Domain · Catalog · Repository
//
//  Everything the app is allowed to know about where products come from.
//
//  Read the signatures and notice what is absent: no `ModelContext`, no `ProductEntity`, no
//  `URLSession`, no DTO — and no `searchRemote`/`searchLocal` either. Whether an answer came from
//  the network or from disk is Data's business; a domain contract that named the transport would
//  force every caller to re-implement the fallback (ADR §14).
//

import Foundation

nonisolated protocol ProductRepository: Sendable {
    /// The catalogue, in server order, as it changes. Emits what is cached straight away — which is
    /// what puts content on the first frame when the app opens offline.
    func observeCatalog() -> AsyncStream<[Product]>

    /// Refreshes only if the cache has aged past `ttl`.
    func refreshCatalogIfStale(ttl: Duration) async -> PageOutcome

    /// Forces a refresh: pull-to-refresh, or the retry button.
    func refreshCatalog() async -> PageOutcome

    /// Loads the page after the cursor.
    func loadNextPage() async -> PageOutcome
}
