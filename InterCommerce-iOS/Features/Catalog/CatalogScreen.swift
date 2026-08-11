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

    init(dependencies: AppDependencies) {
        _model = State(initialValue: CatalogModel(
            observeCatalog: dependencies.observeCatalog,
            refreshCatalog: dependencies.refreshCatalog,
            loadNextPage: dependencies.loadNextPage
        ))
    }

    var body: some View {
        CatalogContentView(
            products: model.products,
            showsSkeletons: model.showsSkeletons,
            isOffline: model.isOffline,
            failure: model.failure,
            showsEmptyState: model.showsEmptyState,
            appendPhase: model.append,
            onRetry: { Task { await model.refreshNow() } },
            onReachEnd: { Task { await model.loadMore() } }
        )
        .navigationTitle("InterCommerce")
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
