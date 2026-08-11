//
//  CatalogUseCases.swift
//  Domain · Catalog · UseCase
//
//  The door into the domain. Reads and commands both go through here, so there is no exception to
//  remember: a screen never talks to a repository, and never to SwiftData (ADR §14, §30).
//
//  Three of these are one-liners. They are not ceremony — they are the *only* path to the data, and
//  that is what makes the boundary checkable rather than aspirational.
//

import Foundation

nonisolated struct ObserveCatalog: Sendable {
    private let repository: any ProductRepository

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    func callAsFunction() -> AsyncStream<[Product]> {
        repository.observeCatalog()
    }
}

nonisolated struct RefreshCatalog: Sendable {
    /// How long cached products stay fresh. 30 minutes: long enough that reopening the app is
    /// instant, short enough that prices are not stale for a session (research.md §5.1).
    static let defaultTTL: Duration = .seconds(30 * 60)

    private let repository: any ProductRepository
    private let ttl: Duration

    init(repository: any ProductRepository, ttl: Duration = RefreshCatalog.defaultTTL) {
        self.repository = repository
        self.ttl = ttl
    }

    /// On appearing or returning to the foreground: refresh only if the cache aged out.
    func ifStale() async -> PageOutcome {
        await repository.refreshCatalogIfStale(ttl: ttl)
    }

    /// Pull-to-refresh and the retry button: the user asked, so the TTL does not get a vote.
    func callAsFunction() async -> PageOutcome {
        await repository.refreshCatalog()
    }
}

nonisolated struct LoadNextPage: Sendable {
    private let repository: any ProductRepository

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> PageOutcome {
        await repository.loadNextPage()
    }
}

/// Searching. A delegator — the remote-then-local decision lives in `Data` (ADR §14) — but it is the
/// only door to it, which is what keeps the boundary checkable.
nonisolated struct SearchProducts: Sendable {
    /// Below this, a query is noise: two characters is where results start being about what the
    /// person meant rather than what they had typed so far.
    static let minimumQueryLength = 2

    private let repository: any ProductRepository

    init(repository: any ProductRepository) {
        self.repository = repository
    }

    func callAsFunction(query: String) async -> SearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumQueryLength else {
            return .results(SearchResults(products: [], source: .remote))
        }
        return await repository.search(query: trimmed)
    }
}
