//
//  CatalogContentView.swift
//  Features · Catalog
//
//  Stateless. Takes values and closures, never the model — which is what lets every state below have
//  a preview that renders offline.
//

import SwiftUI

struct CatalogContentView: View {
    let products: [Product]
    var isSearching: Bool = false
    var searchPhase: CatalogModel.SearchPhase = .inactive
    let showsSkeletons: Bool
    let isOffline: Bool
    let failure: AppError?
    let showsEmptyState: Bool
    let appendPhase: CatalogModel.LoadPhase
    let onRetry: () -> Void
    let onReachEnd: () -> Void
    /// Supplied by `RootView`, so the card and the detail share one namespace. Optional because the
    /// previews below have no navigation stack to zoom into.
    var transitionNamespace: Namespace.ID?

    @Namespace private var fallbackNamespace

    var body: some View {
        ScrollView {
            if showsSkeletons {
                CatalogSkeletonGrid()
                    .padding(Spacing.l)
                    .accessibilityLabel("Loading products")
            } else {
                LazyVGrid(columns: CatalogGrid.columns, spacing: Spacing.m) {
                    ForEach(products) { product in
                        NavigationLink(value: Destination.productDetail(id: product.id)) {
                            ProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                        // The zoom transition: the card is the source the detail grows out of. If
                        // the ids ever stopped matching, the system falls back to a plain push —
                        // a benign failure mode (design.md §8).
                        .matchedTransitionSource(id: product.id, in: transitionNamespace ?? fallbackNamespace)
                    }
                }
                .padding(Spacing.l)

                // Paging belongs to the catalogue, not to a result set.
                if !isSearching { appendFooter }
            }
        }
        .background(Color.background)
        // The system fades content under the toolbar; painting our own background behind the bar
        // would fight it (ADR §28).
        .scrollEdgeEffectStyle(.soft, for: .top)
        .safeAreaInset(edge: .top) {
            if isOffline {
                OfflineBanner().padding(.bottom, Spacing.s)
            }
        }
        .overlay {
            if case .searching = searchPhase, products.isEmpty {
                ProgressView()
            } else if case .empty(let isLocal) = searchPhase {
                ContentUnavailableView {
                    Label("No matches", systemImage: "magnifyingglass")
                } description: {
                    // Being honest about what was searched: offline, only what is cached can match.
                    Text(isLocal
                         ? "Nothing in your saved products matches that."
                         : "Try a different search.")
                }
            } else if let failure {
                AppErrorView(message: failure.message, systemImage: failure.symbol, retry: onRetry)
            } else if showsEmptyState {
                AppEmptyView(
                    title: "No products",
                    message: "There is nothing in the catalogue right now.",
                    systemImage: "shippingbox"
                ) {
                    Button("Reload", action: onRetry).buttonStyle(.glassProminent)
                }
            }
        }
    }

    @ViewBuilder
    private var appendFooter: some View {
        switch appendPhase {
        case .loading:
            ProgressView().padding(Spacing.l)
        case .failed:
            // A failed "load more" keeps everything already on screen: the retry sits at the tail.
            VStack(spacing: Spacing.s) {
                Text("Could not load more products")
                    .font(.gabarito(.footnote))
                    .foregroundStyle(.textSecondary)
                Button("Try again", action: onReachEnd).buttonStyle(.glass)
            }
            .padding(Spacing.l)
        case .idle:
            // The sentinel: reaching it is what asks for the next page.
            Color.clear
                .frame(height: 1)
                .onAppear(perform: onReachEnd)
        }
    }
}

#Preview("Content") {
    NavigationStack {
        CatalogContentView(
            products: Product.previewList,
            showsSkeletons: false, isOffline: false, failure: nil,
            showsEmptyState: false, appendPhase: .idle,
            onRetry: {}, onReachEnd: {}
        )
    }
}

#Preview("Loading") {
    CatalogContentView(
        products: [], showsSkeletons: true, isOffline: false, failure: nil,
        showsEmptyState: false, appendPhase: .idle, onRetry: {}, onReachEnd: {}
    )
}

#Preview("Offline with content") {
    NavigationStack {
        CatalogContentView(
            products: Product.previewList,
            showsSkeletons: false, isOffline: true, failure: nil,
            showsEmptyState: false, appendPhase: .idle,
            onRetry: {}, onReachEnd: {}
        )
    }
}

#Preview("Error, nothing cached") {
    CatalogContentView(
        products: [], showsSkeletons: false, isOffline: false, failure: .noConnection,
        showsEmptyState: false, appendPhase: .idle, onRetry: {}, onReachEnd: {}
    )
}
