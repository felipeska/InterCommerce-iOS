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
    let showsSkeletons: Bool
    let isOffline: Bool
    let failure: AppError?
    let showsEmptyState: Bool
    let appendPhase: CatalogModel.LoadPhase
    let onRetry: () -> Void
    let onReachEnd: () -> Void

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
                    }
                }
                .padding(Spacing.l)

                appendFooter
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
            if let failure {
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
