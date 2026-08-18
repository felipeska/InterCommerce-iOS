//
//  CartRepositoryImpl.swift
//  Data · Cart
//

import Foundation

nonisolated struct CartRepositoryImpl: CartRepository {
    private let store: CartStore

    init(store: CartStore) {
        self.store = store
    }

    func observeLines() -> AsyncStream<[CartLine]> {
        AsyncStream { continuation in
            let task = Task {
                for await lines in await store.linesStream() {
                    continuation.yield(lines)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // These swallow the save error on purpose. A cart write failing is not something a person can
    // act on, and the alternative — an error state on a button — would put a scary dialog in front
    // of someone for a condition that is either transient or fatal to the whole app anyway.
    func add(_ product: Product, quantity: Int) async {
        try? await store.add(product, quantity: quantity)
    }

    func setQuantity(_ quantity: Int, productId: Int) async {
        try? await store.setQuantity(quantity, productId: productId)
    }

    func remove(productId: Int) async {
        try? await store.remove(productId: productId)
    }

    func clear() async {
        try? await store.clear()
    }
}
