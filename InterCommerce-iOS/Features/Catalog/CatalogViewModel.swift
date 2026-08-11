//
//  CatalogViewModel.swift
//  Features · Catalog
//
//  Screen state. It orchestrates refresh and paging, and it *observes* the catalogue — it never
//  fetches it. Content always arrives through the stream, which is what makes losing the network a
//  banner rather than an empty screen.
//
//  It takes the three use cases it uses, not the whole dependency graph: the initialiser documents
//  what this screen can do, and a test needs three fakes and one line.
//

import Foundation
import Observation

@Observable
final class CatalogViewModel {

    /// Where a load stands. Deliberately separate for refresh and append: a failed "load more" must
    /// not blank a screen that is already showing products.
    enum LoadPhase: Equatable {
        case idle
        case loading
        case failed(AppError)

        var error: AppError? {
            if case let .failed(error) = self { return error }
            return nil
        }
    }

    private(set) var products: [Product] = []
    private(set) var refresh: LoadPhase = .idle
    private(set) var append: LoadPhase = .idle

    /// Bound to `.searchable`. The view owns the text; the model owns what it means.
    var query: String = ""
    private(set) var search: SearchPhase = .inactive

    /// What the screen is showing instead of the catalogue, if anything.
    enum SearchPhase: Equatable {
        /// Fewer than two characters: the catalogue stays on screen.
        case inactive
        case searching
        case results([Product], isLocal: Bool)
        case empty(isLocal: Bool)

        var isLocal: Bool {
            switch self {
            case .results(_, let isLocal), .empty(let isLocal): isLocal
            case .inactive, .searching: false
            }
        }
    }

    private let observeCatalog: ObserveCatalog
    private let refreshCatalog: RefreshCatalog
    private let loadNextPage: LoadNextPage
    private let searchProducts: SearchProducts

    init(
        observeCatalog: ObserveCatalog,
        refreshCatalog: RefreshCatalog,
        loadNextPage: LoadNextPage,
        searchProducts: SearchProducts
    ) {
        self.observeCatalog = observeCatalog
        self.refreshCatalog = refreshCatalog
        self.loadNextPage = loadNextPage
        self.searchProducts = searchProducts
    }

    // MARK: - Derived state
    //
    // The combinations that matter, named once here instead of being re-derived in the view. The
    // second one is the whole point of the offline story: content plus a warning, never an error
    // screen replacing products the user can still read.

    /// True while the screen is answering a query rather than showing the catalogue.
    var isSearching: Bool { search != .inactive }

    /// What the grid renders: search results when there is a query, the catalogue otherwise.
    var visibleProducts: [Product] {
        if case let .results(results, _) = search { return results }
        return products
    }

    /// The banner covers both stories: a stale catalogue and a search answered from the cache.
    var showsOfflineBanner: Bool { isOffline || search.isLocal }

    var showsSkeletons: Bool { products.isEmpty && refresh == .loading }
    var isOffline: Bool { !products.isEmpty && refresh.error != nil }
    var failure: AppError? { products.isEmpty ? refresh.error : nil }
    var showsEmptyState: Bool { products.isEmpty && refresh == .idle }

    // MARK: - Lifecycle

    /// Starts observing, and refreshes if the cache aged out. Cancelled with the view.
    func start() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in await self?.observe() }
            group.addTask { [weak self] in await self?.refreshIfStale() }
        }
    }

    private func observe() async {
        for await products in observeCatalog() {
            self.products = products
        }
    }

    private func refreshIfStale() async {
        let previous = refresh
        if products.isEmpty { refresh = .loading }
        apply(await refreshCatalog.ifStale(), to: \.refresh, revertingTo: previous)
    }

    // MARK: - Intents

    /// Returning to the foreground. Re-checks the TTL, because `start()` does not run again while
    /// the process is alive.
    ///
    /// Deliberately **not** unconditional: a full refresh truncates to one page, and
    /// yanking someone back to the top of a list they were halfway down is worse than data that is
    /// forty minutes old. It only refreshes what the TTL says is stale.
    func refreshIfStaleOnResume() async {
        apply(await refreshCatalog.ifStale(), to: \.refresh, revertingTo: refresh)
    }

    /// Pull-to-refresh, and the retry button. The user asked, so the TTL does not get a vote.
    func refreshNow() async {
        let previous = refresh
        if products.isEmpty { refresh = .loading }
        apply(await refreshCatalog(), to: \.refresh, revertingTo: previous)
    }

    /// Called by the sentinel cell at the end of the grid.
    func loadMore() async {
        guard append != .loading else { return }
        let previous = append
        append = .loading
        apply(await loadNextPage(), to: \.append, revertingTo: previous)
    }

    // MARK: - Search

    /// Runs a query, debounced.
    ///
    /// The caller is `.task(id: query)`, so SwiftUI cancels the previous run the moment another
    /// character is typed: the sleep below turns that into a debounce, and the cancellation into the
    /// obsolete request being dropped. No `debounce` operator, no manual bookkeeping — the structure
    /// of the task *is* the mechanism.
    func runSearch(_ query: String, debounce: Duration = .milliseconds(350)) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= SearchProducts.minimumQueryLength else {
            search = .inactive
            return
        }

        do {
            try await Task.sleep(for: debounce)
        } catch {
            return // Another keystroke arrived. This query never mattered.
        }

        search = .searching

        switch await searchProducts(query: trimmed) {
        case .cancelled:
            break // Superseded; the newer query owns the screen.
        case .results(let results):
            let isLocal = results.source.isLocal
            search = results.products.isEmpty
                ? .empty(isLocal: isLocal)
                : .results(results.products, isLocal: isLocal)
        }
    }

    // MARK: - Outcome handling

    /// One place decides what an outcome means for the screen.
    ///
    /// `cancelled` **restores the phase it had before the attempt** rather than leaving it alone.
    /// The first version just did nothing, which looked right and was not: this method is called
    /// after the caller has already set `.loading`, so a cancelled load left the screen showing
    /// skeletons for ever. A test caught it. Cancellation must put the screen back where it was,
    /// never invent a failure and never leave a spinner behind.
    private func apply(
        _ outcome: LoadOutcome,
        to phase: ReferenceWritableKeyPath<CatalogViewModel, LoadPhase>,
        revertingTo previous: LoadPhase
    ) {
        switch outcome {
        case .loaded, .noop:
            self[keyPath: phase] = .idle
        case .failed(let error):
            self[keyPath: phase] = .failed(error)
        case .cancelled:
            self[keyPath: phase] = previous
        }
    }
}
