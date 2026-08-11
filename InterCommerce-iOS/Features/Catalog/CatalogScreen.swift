//
//  CatalogScreen.swift
//  Features · Catalog
//
//  Owns the model and wires it to the view. The dependencies arrive from the parent, because
//  `@Environment` cannot be read in an initialiser (ADR §31).
//

import SwiftUI

struct CatalogScreen: View {
    @State private var model: CatalogModel
    @Environment(\.scenePhase) private var scenePhase

    private let transitionNamespace: Namespace.ID
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies, transitionNamespace: Namespace.ID) {
        self.transitionNamespace = transitionNamespace
        self.dependencies = dependencies
        _model = State(initialValue: CatalogModel(
            observeCatalog: dependencies.observeCatalog,
            refreshCatalog: dependencies.refreshCatalog,
            loadNextPage: dependencies.loadNextPage,
            searchProducts: dependencies.searchProducts
        ))
    }

    var body: some View {
        CatalogContentView(
            products: model.visibleProducts,
            isSearching: model.isSearching,
            searchPhase: model.search,
            showsSkeletons: model.showsSkeletons,
            isOffline: model.showsOfflineBanner,
            failure: model.failure,
            showsEmptyState: model.showsEmptyState,
            appendPhase: model.append,
            onRetry: { Task { await model.refreshNow() } },
            onReachEnd: { Task { await model.loadMore() } },
            transitionNamespace: transitionNamespace
        )
        .navigationTitle("InterCommerce")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Destination.cart) {
                    CartBadge(observeCart: dependencies.observeCart)
                }
            }
        }
        .searchable(text: $model.query, prompt: "Search products")
        // With a full grid the system collapses search into a toolbar button and gives the height
        // back to the content (design.md §1 bis).
        .searchToolbarBehavior(.minimize)
        // `.task(id:)` is the debounce *and* the cancellation of the stale query: changing the id
        // tears the previous run down before the next one starts.
        .task(id: model.query) { await model.runSearch(model.query) }
        .refreshable { await model.refreshNow() }
        // `.task` and not `onAppear`: leaving the screen cancels the stream and any in-flight page.
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from the background re-checks the TTL. `start()` does not run again while
            // the process is alive, so without this the catalogue could stay stale for a session.
            guard phase == .active else { return }
            Task { await model.refreshIfStaleOnResume() }
        }
    }
}
