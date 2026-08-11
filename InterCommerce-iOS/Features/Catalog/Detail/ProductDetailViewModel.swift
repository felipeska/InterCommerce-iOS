//
//  ProductDetailViewModel.swift
//  Features · Catalog · Detail
//
//  Cache first, network second. The product shows instantly because it is already stored — the
//  refresh happens behind it and, if it fails, nobody finds out.
//

import Foundation
import Observation

@Observable
final class ProductDetailViewModel {

    private(set) var product: Product?
    private(set) var isRefreshing = false
    /// Only ever set when there is nothing cached to show. A failed background refresh over a
    /// product the user is already reading is not worth a word.
    private(set) var failure: AppError?

    /// How many of this product are already in the cart, so the button can say so.
    private(set) var quantityInCart = 0

    private let productId: Int
    private let observeProduct: ObserveProduct
    private let refreshProduct: RefreshProduct
    private let observeCart: ObserveCart
    private let addToCart: AddToCart

    init(
        productId: Int,
        observeProduct: ObserveProduct,
        refreshProduct: RefreshProduct,
        observeCart: ObserveCart,
        addToCart: AddToCart
    ) {
        self.productId = productId
        self.observeProduct = observeProduct
        self.refreshProduct = refreshProduct
        self.observeCart = observeCart
        self.addToCart = addToCart
    }

    var showsLoading: Bool { product == nil && failure == nil }

    func start() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in await self?.observe() }
            group.addTask { [weak self] in await self?.refresh() }
            group.addTask { [weak self] in await self?.observeCartQuantity() }
        }
    }

    private func observeCartQuantity() async {
        for await lines in observeCart() {
            quantityInCart = lines.first { $0.productId == productId }?.quantity ?? 0
        }
    }

    func addProductToCart() async {
        guard let product else { return }
        await addToCart(product)
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
