//
//  CartLine.swift
//  Domain · Cart · Model
//
//  One line of the cart: a snapshot of what the user added, not a pointer to a catalogue that gets
//  purged on every refresh.
//

import Foundation

nonisolated struct CartLine: Identifiable, Hashable, Sendable {
    /// Also the identity of the line: a product appears once, with a quantity.
    let productId: Int
    let title: String
    let thumbnailURL: URL?
    /// The price **as it was when the product was added**. The user sees what they accepted, not a
    /// number that moved underneath them.
    let price: Price
    let quantity: Int

    var id: Int { productId }

    /// Deliberately delegating: the discount rule lives in `Price` and nowhere else.
    var gross: Cents { price.gross(quantity: quantity) }
    var discount: Cents { price.discount(quantity: quantity) }
    var net: Cents { price.net(quantity: quantity) }
}

nonisolated extension CartLine {
    /// The bounds a line may take. `minimumOrderQuantity` from the API is ignored on purpose — a
    /// mascara with a minimum of 48 units adds nothing to this exercise, and it is declared as an
    /// assumption in the README.
    static let quantityRange = 1...99
}
