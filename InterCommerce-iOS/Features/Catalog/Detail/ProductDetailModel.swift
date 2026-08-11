//
//  ProductDetailModel.swift
//  Features · Catalog · Detail
//
//  Cache first, network second. The product shows instantly because it is already stored — the
//  refresh happens behind it and, if it fails, nobody finds out (research.md §4).
//

import Foundation
import Observation

@Observable
final class ProductDetailModel {

    private(set) var product: Product?
    private(set) var isRefreshing = false
    /// Only ever set when there is nothing cached to show. A failed background refresh over a
    /// product the user is already reading is not worth a word.
    private(set) var failure: AppError?

    private let productId: Int
    private let observeProduct: ObserveProduct
    private let refreshProduct: RefreshProduct

    init(productId: Int, observeProduct: ObserveProduct, refreshProduct: RefreshProduct) {
        self.productId = productId
        self.observeProduct = observeProduct
        self.refreshProduct = refreshProduct
    }

    var showsLoading: Bool { product == nil && failure == nil }

    func start() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in await self?.observe() }
            group.addTask { [weak self] in await self?.refresh() }
        }
    }

    private func observe() async {
        for await product in observeProduct(id: productId) {
            self.product = product
            if product != nil { failure = nil }
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        switch await refreshProduct(id: productId) {
        case .loaded, .noop, .cancelled:
            break
        case .failed(let error):
            // The rule that keeps a working screen working: the error surfaces only when there is
            // nothing underneath it.
            if product == nil { failure = error }
        }
    }
}
