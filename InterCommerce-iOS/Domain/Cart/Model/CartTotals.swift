//
//  CartTotals.swift
//  Domain · Cart · Model
//

/// What the cart costs, broken down the way the summary shows it.
nonisolated struct CartTotals: Equatable, Sendable {
    /// The sum of the lines after their discounts.
    let subtotal: Cents
    /// What the discounts saved, for the row that shows it.
    let discount: Cents
    let tax: Cents
    let total: Cents
    /// Units, not lines: the badge counts things in the bag.
    let itemCount: Int

    static let empty = CartTotals(subtotal: .zero, discount: .zero, tax: .zero, total: .zero, itemCount: 0)
}

/// How much tax to add, in hundredths of a percent.
///
/// **The default is zero, and that is a decision, not an oversight.** The brief names no rate, so
/// the app ships the *mechanism* — modelled, injected and tested with non-zero rates — rather than
/// inventing a tax figure. The row is shown even at zero, and nothing in the code or the UI calls it
/// "IVA" or ties it to a country (research.md §6).
nonisolated struct TaxPolicy: Equatable, Sendable {
    let basisPoints: Int

    init(basisPoints: Int) {
        self.basisPoints = max(0, basisPoints)
    }

    static let none = TaxPolicy(basisPoints: 0)

    /// For display: `1900` reads as `19 %`.
    var percentage: Double { Double(basisPoints) / 100 }
}
