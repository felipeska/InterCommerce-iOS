//
//  CartRepository.swift
//  Domain · Cart · Repository
//

import Foundation

nonisolated protocol CartRepository: Sendable {
    /// The cart as it changes. Local only — this never fails and never needs a network.
    func observeLines() -> AsyncStream<[CartLine]>
    func add(_ product: Product, quantity: Int) async
    func setQuantity(_ quantity: Int, productId: Int) async
    func remove(productId: Int) async
    /// Empties the cart. Separate from removing every line one by one, because the two mean
    /// different things to the person: one is an edit that can be undone, this one is an order.
    func clear() async
}
