//
//  CatalogScreen.swift
//  Features · Catalog
//
//  Owns the model and wires it to the view. The dependencies arrive from the parent, because
//  `@Environment` cannot be read in an initialiser.
//

import SwiftUI

struct CatalogScreen: View {
    @State private var viewModel: CatalogViewModel
    @Environment(\.scenePhase) private var scenePhase

    private let transitionNamespace: Namespace.ID
    private let dependencies: AppDependencies
    private let cartCount: Int
    private let onOpenCart: () -> Void

    init(
        dependencies: AppDependencies,
        transitionNamespace: Namespace.ID,
        cartCount: Int,
        onOpenCart: @escaping () -> Void
    ) {
        self.transitionNamespace = transitionNamespace
        self.dependencies = dependencies
        self.cartCount = cartCount
        self.onOpenCart = onOpenCart
        _viewModel = State(initialValue: CatalogViewModel(
            observeCatalog: dependencies.observeCatalog,
            refreshCatalog: dependencies.refreshCatalog,
            loadNextPage: dependencies.loadNextPage,
            searchProducts: dependencies.searchProducts
        ))
    }

    var body: some View {
        CatalogContentView(
            products: viewModel.visibleProducts,
            isSearching: viewModel.isSearching,
            searchPhase: viewModel.search,
            showsSkeletons: viewModel.showsSkeletons,
            isOffline: viewModel.showsOfflineBanner,
            failure: viewModel.failure,
            showsEmptyState: viewModel.showsEmptyState,
            appendPhase: viewModel.append,
            onRetry: { Task { await viewModel.refreshNow() } },
            onReachEnd: { Task { await viewModel.loadMore() } },
            transitionNamespace: transitionNamespace
        )
        .navigationTitle("InterCommerce")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenCart) {
                    CartBadge(count: cartCount)
                }
            }
        }
        // Deliberately without `.searchToolbarBehavior(.minimize)`. Collapsing search into a toolbar
        // button gives the grid its height back, but the minimized button and the cart item then
        // share the navigation bar, and popping the detail screen logs an unsatisfiable-constraint
        // warning: UIKit sizes the bar-button wrapper to zero mid-transition while its own 8pt
        // insets still hold. Both constraints are UIKit's, so the only lever we have is not putting
        // the two of them in the bar together. The full search field costs height and nothing else.
        .searchable(text: $viewModel.query, prompt: "Search products")
        // `.task(id:)` is the debounce *and* the cancellation of the stale query: changing the id
        // tears the previous run down before the next one starts.
        .task(id: viewModel.query) { await viewModel.runSearch(viewModel.query) }
        .refreshable { await viewModel.refreshNow() }
        // `.task` and not `onAppear`: leaving the screen cancels the stream and any in-flight page.
        .task { await viewModel.start() }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from the background re-checks the TTL. `start()` does not run again while
            // the process is alive, so without this the catalogue could stay stale for a session.
            guard phase == .active else { return }
            Task { await viewModel.refreshIfStaleOnResume() }
        }
    }
}
