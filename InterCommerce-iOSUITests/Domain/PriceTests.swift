//
//  PriceTests.swift
//  Domain tests
//
//  The rounding rule, pinned. These are the tests the brief is really asking for: the totals have to
//  be right to the cent, and they have to be right for the reason stated — rounding per line — not
//  by accident.
//

import Testing

@testable import InterCommerce_iOS

struct PriceTests {

    /// The case that gives this type its shape. 999 ¢ at 10.48 % over three units:
    /// rounded per line it is 314 ¢, rounded per unit and multiplied it is 315 ¢.
    @Test("The discount is rounded once per line, never per unit")
    func roundsPerLineNotPerUnit() {
        let price = Price(list: Cents(999), discountBasisPoints: 1_048)

        #expect(price.discount(quantity: 3) == Cents(314))

        // What the wrong implementation would produce, spelled out so the difference is visible.
        let perUnitThenMultiplied = price.discount(quantity: 1) * 3
        #expect(perUnitThenMultiplied == Cents(315))
        #expect(price.discount(quantity: 3) != perUnitThenMultiplied)
    }

    @Test("Gross, discount and net add up", arguments: [1, 2, 3, 7, 99])
    func partsAddUp(quantity: Int) {
        let price = Price(list: Cents(1_299), discountBasisPoints: 1_575)

        #expect(price.net(quantity: quantity) + price.discount(quantity: quantity)
                == price.gross(quantity: quantity))
    }

    @Test("No discount means the net equals the gross")
    func withoutDiscount() {
        let price = Price(list: Cents(999), discountBasisPoints: 0)

        #expect(price.hasDiscount == false)
        #expect(price.discount(quantity: 5) == .zero)
        #expect(price.net(quantity: 5) == Cents(4_995))
    }

    @Test("Rounding is half up", arguments: [
        // gross · basis points -> expected discount
        (Cents(100), 50, Cents(1)),      // 0.5 ¢ rounds up to 1
        (Cents(100), 49, Cents(0)),      // 0.49 ¢ rounds down to 0
        (Cents(1_000), 1_250, Cents(125)),
    ])
    func roundsHalfUp(list: Cents, basisPoints: Int, expected: Cents) {
        let price = Price(list: list, discountBasisPoints: basisPoints)
        #expect(price.discount(quantity: 1) == expected)
    }

    @Test("A full discount cannot exceed the price")
    func fullDiscount() {
        let price = Price(list: Cents(999), discountBasisPoints: 10_000)

        #expect(price.discount(quantity: 2) == Cents(1_998))
        #expect(price.net(quantity: 2) == .zero)
    }

    /// A negative discount would mean charging more than the list price. The API has never sent one,
    /// which is precisely why the guard is here rather than in a comment.
    @Test("A negative discount is clamped to zero")
    func negativeDiscountIsClamped() {
        let price = Price(list: Cents(999), discountBasisPoints: -500)

        #expect(price.hasDiscount == false)
        #expect(price.net(quantity: 1) == Cents(999))
    }

    @Test("The unit price after discount is what a card shows")
    func unitNet() {
        let price = Price(list: Cents(999), discountBasisPoints: 1_048)
        #expect(price.unitNet == Cents(894))
        #expect(price.discountPercentage == 10.48)
    }
}
