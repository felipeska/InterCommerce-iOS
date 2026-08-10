//
//  Price.swift
//  Domain · Catalog · Model
//
//  The only place in the app that computes a discount.
//
//  Left to itself, the same formula ends up in three places — the card, the detail screen and the
//  totals — with three different roundings, and then the discount shown per product does not add up
//  to the discount shown in the total. This type exists so that cannot happen (ADR §4).
//

/// A list price and the discount that applies to it.
nonisolated struct Price: Hashable, Sendable {

    /// The undiscounted unit price.
    let list: Cents

    /// The discount in **hundredths of a percent**: `10.48 %` is `1048`.
    ///
    /// The API sends a `Double`. It is scaled to an integer once, in the mapper, so every
    /// computation from here on is integer arithmetic and the results are exact rather than
    /// approximately right.
    let discountBasisPoints: Int

    init(list: Cents, discountBasisPoints: Int) {
        self.list = list
        self.discountBasisPoints = max(0, discountBasisPoints)
    }

    var hasDiscount: Bool { discountBasisPoints > 0 }

    /// For display only — never feed this back into a calculation.
    var discountPercentage: Double { Double(discountBasisPoints) / 100 }

    // MARK: - Line arithmetic

    /// What the line costs before the discount.
    func gross(quantity: Int) -> Cents {
        list * quantity
    }

    /// The discount for the **whole line**, rounded once, half up.
    ///
    /// - Important: there is deliberately no `unitDiscount`. Rounding per unit and multiplying gives
    ///   a different answer — 999 ¢ at 10.48 % over 3 units is **314 ¢** per line but **315 ¢** if
    ///   rounded per unit — and that one-cent gap is exactly the bug this type prevents. Making the
    ///   quantity part of the signature means the wrong version cannot be written by accident.
    func discount(quantity: Int) -> Cents {
        let grossAmount = gross(quantity: quantity).rawValue
        guard grossAmount != 0, discountBasisPoints != 0 else { return .zero }

        let scaled = grossAmount * Int64(discountBasisPoints)
        // Half up, with integers: no floating point anywhere near money.
        let rounded = (scaled + 5_000) / 10_000
        return Cents(min(rounded, grossAmount))
    }

    /// What the line actually costs.
    func net(quantity: Int) -> Cents {
        gross(quantity: quantity) - discount(quantity: quantity)
    }

    /// The single-unit price after discount. For display: the price a card shows.
    var unitNet: Cents { net(quantity: 1) }
}
