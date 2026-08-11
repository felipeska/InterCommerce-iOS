//
//  CatalogModel.swift
//  Features · Catalog
//
//  Screen state. It orchestrates refresh and paging, and it *observes* the catalogue — it never
//  fetches it. Content always arrives through the stream, which is what makes losing the network a
//  banner rather than an empty screen (ADR §30).
//
//  It takes the three use cases it uses, not the whole dependency graph: the initialiser documents
//  what this screen can do, and a test needs three fakes and one line (ADR §31).
//

import Foundation
import Observation

@Observable
final class CatalogModel {

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

    private let observeCatalog: ObserveCatalog
    private let refreshCatalog: RefreshCatalog
    private let loadNextPage: LoadNextPage

    init(observeCatalog: ObserveCatalog, refreshCatalog: RefreshCatalog, loadNextPage: LoadNextPage) {
        self.observeCatalog = observeCatalog
        self.refreshCatalog = refreshCatalog
        self.loadNextPage = loadNextPage
    }

    // MARK: - Derived state
    //
    // The combinations that matter, named once here instead of being re-derived in the view. The
    // second one is the whole point of the offline story: content plus a warning, never an error
    // screen replacing products the user can still read.

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
    /// Deliberately **not** unconditional: a full refresh truncates to one page (ADR §11), and
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

    // MARK: - Outcome handling

    /// One place decides what an outcome means for the screen.
    ///
    /// `cancelled` **restores the phase it had before the attempt** rather than leaving it alone.
    /// The first version just did nothing, which looked right and was not: this method is called
    /// after the caller has already set `.loading`, so a cancelled load left the screen showing
    /// skeletons for ever. A test caught it. Cancellation must put the screen back where it was,
    /// never invent a failure and never leave a spinner behind.
    private func apply(
        _ outcome: PageOutcome,
        to phase: ReferenceWritableKeyPath<CatalogModel, LoadPhase>,
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
