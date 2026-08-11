//
//  CalculateCartTotalsTests.swift
//  Domain tests
//
//  The test that carries the most weight in this brief: the money has to be right to the cent, and
//  right for the stated reason — discounts rounded per line, tax on the discounted subtotal.
//
//  It imports neither SwiftUI nor SwiftData, and the suite is not `@MainActor`. That is not a
//  formality: it is the demonstration that the calculation is free of the frameworks around it.
//

import Testing

@testable import InterCommerce_iOS

struct CalculateCartTotalsTests {

    private func line(cents: Int64, basisPoints: Int = 0, quantity: Int = 1) -> CartLine {
        CartLine(
            productId: Int.random(in: 1...100_000),
            title: "Product",
            thumbnailURL: nil,
            price: Price(list: Cents(cents), discountBasisPoints: basisPoints),
            quantity: quantity
        )
    }

    // MARK: - The shape of an empty cart

    @Test("An empty cart is all zeros, not a crash and not a nil")
    func emptyCart() {
        #expect(CalculateCartTotals()([]) == .empty)
    }

    // MARK: - Sums

    @Test("A single line without a discount")
    func singleLineNoDiscount() {
        let totals = CalculateCartTotals()([line(cents: 999, quantity: 3)])

        #expect(totals.subtotal == Cents(2_997))
        #expect(totals.discount == .zero)
        #expect(totals.total == Cents(2_997))
        #expect(totals.itemCount == 3)
    }

    /// The case the whole design turns on. Rounded per line the discount is 314 ¢; rounded per unit
    /// and multiplied it would be 315 ¢, and the summary would disagree with the line by a cent.
    @Test("A discounted line rounds once, per line")
    func singleLineWithDiscount() {
        let totals = CalculateCartTotals()([line(cents: 999, basisPoints: 1_048, quantity: 3)])

        #expect(totals.discount == Cents(314))
        #expect(totals.subtotal == Cents(2_683))
        #expect(totals.subtotal + totals.discount == Cents(2_997), "The parts do not add back up to the gross")
    }

    @Test("Several lines add up, and the discounts add up with them")
    func severalLines() {
        let totals = CalculateCartTotals()([
            line(cents: 999, basisPoints: 1_048, quantity: 3),   // net 2 683, discount 314
            line(cents: 1_299, basisPoints: 0, quantity: 1),     // net 1 299
            line(cents: 2_450, basisPoints: 1_500, quantity: 2), // gross 4 900, discount 735, net 4 165
        ])

        #expect(totals.discount == Cents(314 + 0 + 735))
        #expect(totals.subtotal == Cents(2_683 + 1_299 + 4_165))
        #expect(totals.itemCount == 6)
    }

    // MARK: - Tax

    @Test("The default rate is zero, and the row is still meaningful")
    func defaultRateIsZero() {
        let totals = CalculateCartTotals()([line(cents: 1_000, quantity: 1)])

        #expect(totals.tax == .zero)
        #expect(totals.total == totals.subtotal)
    }

    /// The mechanism, exercised with rates the brief never named — which is the point of injecting
    /// it rather than hardcoding a figure.
    @Test("Tax applies to the discounted subtotal", arguments: [
        // basis points, expected tax on a 10 000 ¢ subtotal
        (1_900, Cents(1_900)),  // 19 %
        (500, Cents(500)),      // 5 %
        (1_250, Cents(1_250)),  // 12.5 %
    ])
    func taxOnSubtotal(basisPoints: Int, expected: Cents) {
        let totals = CalculateCartTotals(taxPolicy: TaxPolicy(basisPoints: basisPoints))(
            [line(cents: 10_000, quantity: 1)]
        )

        #expect(totals.tax == expected)
        #expect(totals.total == totals.subtotal + expected)
    }

    /// Tax on the *discounted* amount, not on the list price. Charging tax on money nobody paid is a
    /// real-world billing bug, so it gets its own test.
    @Test("Tax is charged on what is owed, not on the list price")
    func taxIgnoresTheDiscountedPortion() {
        let totals = CalculateCartTotals(taxPolicy: TaxPolicy(basisPoints: 1_000))(
            [line(cents: 1_000, basisPoints: 5_000, quantity: 1)] // 50 % off: net 500
        )

        #expect(totals.subtotal == Cents(500))
        #expect(totals.tax == Cents(50), "Tax was applied to the undiscounted price")
        #expect(totals.total == Cents(550))
    }

    @Test("Tax rounds half up, like every other money operation here", arguments: [
        (Int64(105), 500, Cents(5)),   // 5.25 -> 5
        (Int64(110), 500, Cents(6)),   // 5.50 -> 6
        (Int64(1), 10_000, Cents(1)),
    ])
    func taxRounding(subtotalCents: Int64, basisPoints: Int, expected: Cents) {
        let totals = CalculateCartTotals(taxPolicy: TaxPolicy(basisPoints: basisPoints))(
            [line(cents: subtotalCents, quantity: 1)]
        )

        #expect(totals.tax == expected)
    }

    @Test("A negative rate is clamped rather than refunding the customer")
    func negativeRateIsClamped() {
        let totals = CalculateCartTotals(taxPolicy: TaxPolicy(basisPoints: -500))(
            [line(cents: 1_000, quantity: 1)]
        )

        #expect(totals.tax == .zero)
    }

    // MARK: - Edges

    @Test("The maximum quantity still adds up exactly")
    func maximumQuantity() {
        let totals = CalculateCartTotals()([line(cents: 999, basisPoints: 1_048, quantity: 99)])

        // 98 901 gross · 10.48 % = 10 364.8 -> 10 365
        #expect(totals.discount == Cents(10_365))
        #expect(totals.subtotal == Cents(98_901 - 10_365))
        #expect(totals.itemCount == 99)
    }

    @Test("A fully discounted cart totals zero without going negative")
    func fullDiscount() {
        let totals = CalculateCartTotals(taxPolicy: TaxPolicy(basisPoints: 1_900))(
            [line(cents: 999, basisPoints: 10_000, quantity: 2)]
        )

        #expect(totals.subtotal == .zero)
        #expect(totals.tax == .zero, "Tax was charged on a subtotal of zero")
        #expect(totals.total == .zero)
    }
}
