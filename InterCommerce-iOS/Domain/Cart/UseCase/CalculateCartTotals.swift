//
//  CalculateCartTotals.swift
//  Domain · Cart · UseCase
//
//  The calculation the brief is really asking about. Pure Swift: no SwiftUI, no SwiftData, no
//  Foundation beyond value types — which is why its tests need neither a simulator nor a database.
//
//  The order is not incidental. Discounts are applied and rounded **per line** (`Price`), the lines
//  are summed, and only then is tax applied to the discounted subtotal. Rounding at the end instead
//  would make the sum of the visible line discounts disagree with the total by a cent or two, which
//  is the exact failure this design exists to avoid.
//

nonisolated struct CalculateCartTotals: Sendable {
    private let taxPolicy: TaxPolicy

    init(taxPolicy: TaxPolicy = .none) {
        self.taxPolicy = taxPolicy
    }

    func callAsFunction(_ lines: [CartLine]) -> CartTotals {
        guard !lines.isEmpty else { return .empty }

        let subtotal = lines.reduce(Cents.zero) { $0 + $1.net }
        let discount = lines.reduce(Cents.zero) { $0 + $1.discount }
        let tax = tax(on: subtotal)

        return CartTotals(
            subtotal: subtotal,
            discount: discount,
            tax: tax,
            total: subtotal + tax,
            itemCount: lines.reduce(0) { $0 + $1.quantity }
        )
    }

    /// Applied to the **discounted** subtotal, and rounded half up with integers — the same rule as
    /// the line discount, for the same reason.
    private func tax(on subtotal: Cents) -> Cents {
        guard taxPolicy.basisPoints > 0, subtotal != .zero else { return .zero }
        let scaled = subtotal.rawValue * Int64(taxPolicy.basisPoints)
        return Cents((scaled + 5_000) / 10_000)
    }
}
