//
//  CatalogPaginator.swift
//  Data · Catalog
//
//  What Paging 3 gave the Android sibling for free, written by hand (ADR §2). An actor, because the
//  trigger is the last cell appearing — which fires several times during a fast scroll — and the
//  check-then-load has to be atomic. A `Bool` on the main actor looks like it is enough right up
//  until two callers slip between the `await` and the assignment.
//

import Foundation

actor CatalogPaginator {
    private let api: ProductAPI
    private let store: CatalogStore
    private let pageSize: Int
    private var isLoading = false

    init(api: ProductAPI, store: CatalogStore, pageSize: Int = 20) {
        self.api = api
        self.store = store
        self.pageSize = pageSize
    }

    /// Refreshes only if the cache has aged past `ttl`.
    ///
    /// Fresh cache means no request at all, which is what lets the app open offline with content
    /// instead of a spinner (research.md §5.1).
    func refreshIfStale(ttl: Duration, now: Date = .now) async -> PageOutcome {
        guard let cursor = await store.pageCursor() else {
            return await refresh(now: now) // Nothing cached yet.
        }
        let age = now.timeIntervalSince(cursor.lastRefreshAt)
        guard age >= ttl.seconds else { return .noop }
        return await refresh(now: now)
    }

    /// Replaces the catalogue with a fresh first page.
    func refresh(now: Date = .now) async -> PageOutcome {
        guard !isLoading else { return .noop }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await api.products(limit: pageSize, skip: 0)
            // Nothing is written for a load nobody is waiting for.
            try Task.checkCancellation()
            try await store.replaceFirstPage(page.products, total: page.total, now: now)
            return .loaded
        } catch {
            return PageOutcome(error)
        }
    }

    /// Loads the page after the cursor. A no-op at the end of the catalogue, and while another load
    /// is in flight.
    func loadNextPage(now: Date = .now) async -> PageOutcome {
        guard !isLoading else { return .noop }
        guard let cursor = await store.pageCursor() else { return await refresh(now: now) }
        guard cursor.hasMore else { return .noop }

        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await api.products(limit: pageSize, skip: cursor.nextSkip)
            try Task.checkCancellation()
            try await store.appendPage(
                page.products,
                startingAt: cursor.nextSkip,
                total: page.total,
                now: now
            )
            return .loaded
        } catch {
            return PageOutcome(error)
        }
    }
}

// `nonisolated` again: an extension does not inherit it from the type, and with default MainActor
// isolation these helpers would be unreachable from the actor (ADR §29).
nonisolated private extension PageOutcome {
    /// Cancellation is not a failure and never becomes one.
    init(_ error: any Error) {
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            self = .cancelled
        } else if let appError = error as? AppError {
            self = .failed(appError)
        } else {
            self = .failed((try? AppError.mapping(error)) ?? .unknown)
        }
    }
}

nonisolated private extension Duration {
    var seconds: TimeInterval {
        TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1e18
    }
}
