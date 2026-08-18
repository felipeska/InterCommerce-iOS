//
//  CartViewModel.swift
//  Features · Cart
//
//  Local, reactive, and never in an error state: nothing here touches the network.
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
    private let placeOrder: PlaceOrder
    private let calculateTotals: CalculateCartTotals

    init(
        observeCart: ObserveCart,
        updateQuantity: UpdateQuantity,
        removeFromCart: RemoveFromCart,
        addToCart: AddToCart,
        placeOrder: PlaceOrder,
        calculateTotals: CalculateCartTotals
    ) {
        self.observeCart = observeCart
        self.updateQuantity = updateQuantity
        self.removeFromCart = removeFromCart
        self.addToCart = addToCart
        self.placeOrder = placeOrder
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

    /// - Returns: `true` when there was something to order. The screen only navigates to the
    ///   confirmation on `true`, so it can never confirm an order for an empty cart.
    func checkout() async -> Bool {
        guard !lines.isEmpty else { return false }
        // The pending undo goes with it: offering to restore a line into a cart that was just
        // ordered would put the item back with nothing to pay for it.
        lastRemoved = nil
        await placeOrder()
        return true
    }

    func dismissUndo() { lastRemoved = nil }
}
