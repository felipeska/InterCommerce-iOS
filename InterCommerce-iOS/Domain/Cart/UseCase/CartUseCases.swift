//
//  CartUseCases.swift
//  Domain · Cart · UseCase
//

import Foundation

nonisolated struct ObserveCart: Sendable {
    private let repository: any CartRepository

    init(repository: any CartRepository) {
        self.repository = repository
    }

    func callAsFunction() -> AsyncStream<[CartLine]> {
        repository.observeLines()
    }
}

/// Deciding what "add" means: a new line, or one more of what is already there.
///
/// The decision lives here rather than in the button because it is a rule, not an interaction — and
/// because the quantity ceiling has to hold wherever the call comes from.
nonisolated struct AddToCart: Sendable {
    private let repository: any CartRepository

    init(repository: any CartRepository) {
        self.repository = repository
    }

    func callAsFunction(_ product: Product, quantity: Int = 1) async {
        let clamped = min(max(quantity, CartLine.quantityRange.lowerBound), CartLine.quantityRange.upperBound)
        await repository.add(product, quantity: clamped)
    }
}

nonisolated struct UpdateQuantity: Sendable {
    private let repository: any CartRepository

    init(repository: any CartRepository) {
        self.repository = repository
    }

    /// Dropping to zero removes the line: it is what the stepper's minus button means at 1, and
    /// leaving a line with nothing in it would be a state nobody asked for.
    func callAsFunction(productId: Int, quantity: Int) async {
        if quantity < CartLine.quantityRange.lowerBound {
            await repository.remove(productId: productId)
        } else {
            await repository.setQuantity(quantity, productId: productId)
        }
    }
}

nonisolated struct RemoveFromCart: Sendable {
    private let repository: any CartRepository

    init(repository: any CartRepository) {
        self.repository = repository
    }

    func callAsFunction(productId: Int) async {
        await repository.remove(productId: productId)
    }
}
