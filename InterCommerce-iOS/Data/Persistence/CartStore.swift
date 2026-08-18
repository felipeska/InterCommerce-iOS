//
//  CartStore.swift
//  Data · Persistence
//
//  The only place allowed to write cart lines. Separate from `CatalogStore` because the two answer
//  to opposite rules: the catalogue is a cache that gets purged, the cart is user data that never is.
//

import Foundation
import SwiftData

@ModelActor
actor CartStore {

    private var subscribers: [UUID: AsyncStream<[CartLine]>.Continuation] = [:]

    // MARK: - Observation

    func linesStream() -> AsyncStream<[CartLine]> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<[CartLine]>.makeStream()

        subscribers[id] = continuation
        continuation.yield(currentLines())
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }

        return stream
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    var subscriberCount: Int { subscribers.count }

    private func broadcast() {
        let lines = currentLines()
        for continuation in subscribers.values {
            continuation.yield(lines)
        }
    }

    // MARK: - Reads

    /// Oldest first, so a line does not jump around the screen when its quantity changes.
    func currentLines() -> [CartLine] {
        let descriptor = FetchDescriptor<CartItemEntity>(sortBy: [SortDescriptor(\.addedAt)])
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        return entities.map(CartMapper.domain(from:))
    }

    func line(productId: Int) -> CartLine? {
        var descriptor = FetchDescriptor<CartItemEntity>(predicate: #Predicate { $0.productId == productId })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first.map(CartMapper.domain(from:))
    }

    // MARK: - Writes

    /// Adds a line, or raises the quantity of the one already there.
    ///
    /// The snapshot is only taken the **first** time: adding a second unit must not silently adopt a
    /// price that changed since the user made the decision.
    func add(_ product: Product, quantity: Int, now: Date = .now) throws {
        let productId = product.id
        var descriptor = FetchDescriptor<CartItemEntity>(predicate: #Predicate { $0.productId == productId })
        descriptor.fetchLimit = 1

        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.quantity = min(existing.quantity + quantity, CartLine.quantityRange.upperBound)
            existing.updatedAt = now
        } else {
            modelContext.insert(CartMapper.entity(from: product, quantity: quantity, now: now))
        }

        try modelContext.save()
        broadcast()
    }

    func setQuantity(_ quantity: Int, productId: Int, now: Date = .now) throws {
        var descriptor = FetchDescriptor<CartItemEntity>(predicate: #Predicate { $0.productId == productId })
        descriptor.fetchLimit = 1
        guard let existing = (try? modelContext.fetch(descriptor))?.first else { return }

        existing.quantity = quantity.clamped(to: CartLine.quantityRange)
        existing.updatedAt = now
        try modelContext.save()
        broadcast()
    }

    /// Empties the cart in one delete rather than a loop: the order is one event, and the observers
    /// should see one emission, not a countdown.
    func clear() throws {
        try modelContext.delete(model: CartItemEntity.self)
        try modelContext.save()
        broadcast()
    }

    func remove(productId: Int) throws {
        try modelContext.delete(
            model: CartItemEntity.self,
            where: #Predicate { $0.productId == productId }
        )
        try modelContext.save()
        broadcast()
    }
}

nonisolated private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
