//
//  CartViewModel.swift
//  Features · Cart
//
//  Local, reactive, and never in an error state: nothing here touches the network (research.md §4).
//

import Foundation
import Observation

@Observable
final class CartViewModel {

    private(set) var lines: [CartLine] = []
    private(set) var totals: CartTotals = .empty
    /// Set when a line is removed, so the screen can offer to put it back.
    private(set) var lastRemoved: CartLine?

    private let observeCart: ObserveCart
    private let updateQuantity: UpdateQuantity
    private let removeFromCart: RemoveFromCart
    private let addToCart: AddToCart
    private let calculateTotals: CalculateCartTotals

    init(
        observeCart: ObserveCart,
        updateQuantity: UpdateQuantity,
        removeFromCart: RemoveFromCart,
        addToCart: AddToCart,
        calculateTotals: CalculateCartTotals
    ) {
        self.observeCart = observeCart
        self.updateQuantity = updateQuantity
        self.removeFromCart = removeFromCart
        self.addToCart = addToCart
        self.calculateTotals = calculateTotals
    }

    var isEmpty: Bool { lines.isEmpty }

    func start() async {
        for await lines in observeCart() {
            self.lines = lines
            // Recomputed from the lines, never accumulated: a total that is kept in a variable and
            // adjusted drifts away from the lines it claims to summarise.
            self.totals = calculateTotals(lines)
        }
    }

    func setQuantity(_ quantity: Int, for line: CartLine) async {
        if quantity < CartLine.quantityRange.lowerBound { lastRemoved = line }
        await updateQuantity(productId: line.productId, quantity: quantity)
    }

    func remove(_ line: CartLine) async {
        lastRemoved = line
        await removeFromCart(productId: line.productId)
    }

    /// Undo for an accidental swipe. Cheap to offer, and losing a cart line to a stray gesture is
    /// exactly the kind of data loss this brief is about.
    func undoRemove() async {
        guard let line = lastRemoved else { return }
        lastRemoved = nil
        await addToCart(
            Product(
                id: line.productId, title: line.title, summary: "", category: "", brand: "",
                price: line.price, rating: 0, stock: 0,
                thumbnailURL: line.thumbnailURL, imageURLs: [],
                availabilityStatus: nil, shippingInformation: nil,
                warrantyInformation: nil, returnPolicy: nil
            ),
            quantity: line.quantity
        )
    }

    func dismissUndo() { lastRemoved = nil }
}
