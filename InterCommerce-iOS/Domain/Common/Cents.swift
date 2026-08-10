//
//  Cents.swift
//  Domain · Common
//
//  Money, as whole cents. `9.99 * 3` in binary floating point is not `29.97`, and once discounts
//  and tax pile on top the totals drift and the tests turn into approximations. The API's `Double`
//  is converted exactly once, in the mapper; from there money is an integer.
//
//  Why a struct and not `typealias Cents = Int64`: an alias would happily let you add money to a
//  `stock` or a `position`. The struct will not, and the compiler unwraps it to a bare `Int64` in
//  the binary, so it costs nothing. It is the counterpart of Kotlin's `@JvmInline value class`.
//
//  It lives in Common, not in the catalog domain, because both features spend money (`CartLine`,
//  `CartTotals`). `Price` — which owns the *discount rounding rule* — stays in the catalog domain.
//

/// An amount of money in whole cents.
nonisolated struct Cents: RawRepresentable, Hashable, Comparable, Sendable {
    let rawValue: Int64

    init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    init(_ value: Int64) {
        self.rawValue = value
    }

    static func < (lhs: Cents, rhs: Cents) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Arithmetic
//
// Every extension carries `nonisolated` of its own. Marking the *type* nonisolated does not cover
// members declared in extensions: with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` those inherit
// the main actor, and the first consumer of `Cents` outside the main actor — `Price` — failed to
// compile with "call to main actor-isolated operator function '+'". Easy to miss, because the type
// declaration looks like it settled the question (ADR §29).

// `AdditiveArithmetic` and not `Numeric`, on purpose: adding two amounts is meaningful, and
// `lines.map(\.net).reduce(.zero, +)` reads well. Multiplying two amounts of money is meaningless,
// and leaving it available invites the exact mistake `Price` exists to prevent — computing a
// per-unit discount and multiplying it by the quantity.
nonisolated extension Cents: AdditiveArithmetic {
    static let zero = Cents(0)

    static func + (lhs: Cents, rhs: Cents) -> Cents {
        Cents(lhs.rawValue + rhs.rawValue)
    }

    static func - (lhs: Cents, rhs: Cents) -> Cents {
        Cents(lhs.rawValue - rhs.rawValue)
    }
}

nonisolated extension Cents {
    /// Scaling by a quantity — the one multiplication that means something.
    static func * (amount: Cents, quantity: Int) -> Cents {
        Cents(amount.rawValue * Int64(quantity))
    }
}

// MARK: - Conveniences

nonisolated extension Cents: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int64) {
        self.rawValue = value
    }
}

nonisolated extension Cents: CustomStringConvertible {
    /// Debug only. User-facing formatting lives in `MoneyFormat` (DesignSystem) and is localised.
    var description: String { "\(rawValue)¢" }
}
