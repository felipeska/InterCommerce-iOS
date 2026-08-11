//
//  ProductDetailScreen.swift
//  Features · Catalog · Detail
//
//  Owns the viewModel. Receives the id, never the product: the screen re-reads it from the store, which
//  is what keeps a single source of truth and lets the row refresh reach the screen on its own
// .
//

import SwiftUI

struct ProductDetailScreen: View {
    @State private var viewModel: ProductDetailViewModel

    init(productId: Int, dependencies: AppDependencies) {
        _viewModel = State(initialValue: ProductDetailViewModel(
            productId: productId,
            observeProduct: dependencies.observeProduct,
            refreshProduct: dependencies.refreshProduct,
            observeCart: dependencies.observeCart,
            addToCart: dependencies.addToCart
        ))
    }

    var body: some View {
        Group {
            if let product = viewModel.product {
                ProductDetailContentView(
                    product: product,
                    quantityInCart: viewModel.quantityInCart,
                    onAddToCart: { Task { await viewModel.addProductToCart() } }
                )
            } else if let failure = viewModel.failure {
                // Only reachable with nothing cached: the product was never paged in and the network
                // is unavailable.
                AppErrorView(message: failure.message, systemImage: failure.symbol) {
                    Task { await viewModel.refresh() }
                }
            } else {
                ProgressView()
            }
        }
        .task { await viewModel.start() }
    }
}
