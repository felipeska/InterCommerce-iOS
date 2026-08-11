//
//  ProductDetailScreen.swift
//  Features · Catalog · Detail
//
//  Owns the model. Receives the id, never the product: the screen re-reads it from the store, which
//  is what keeps a single source of truth and lets the row refresh reach the screen on its own
//  (architecture.md §7).
//

import SwiftUI

struct ProductDetailScreen: View {
    @State private var model: ProductDetailModel

    init(productId: Int, dependencies: AppDependencies) {
        _model = State(initialValue: ProductDetailModel(
            productId: productId,
            observeProduct: dependencies.observeProduct,
            refreshProduct: dependencies.refreshProduct
        ))
    }

    var body: some View {
        Group {
            if let product = model.product {
                ProductDetailContentView(product: product)
            } else if let failure = model.failure {
                // Only reachable with nothing cached: the product was never paged in and the network
                // is unavailable.
                AppErrorView(message: failure.message, systemImage: failure.symbol) {
                    Task { await model.refresh() }
                }
            } else {
                ProgressView()
            }
        }
        .task { await model.start() }
    }
}
