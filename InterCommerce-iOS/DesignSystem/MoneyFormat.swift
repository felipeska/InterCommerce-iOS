//
//  MoneyFormat.swift
//  DesignSystem
//
//  The one place that turns cents into something a person reads. Both features format money, which
//  is why it lives here and `PriceLabel` — which knows about discounts — lives with the catalogue.
//

import Foundation

enum MoneyFormat {
    /// DummyJSON prices are USD; the app is Colombian. No conversion is performed and that is
    /// declared as an assumption in the README, rather than inventing an exchange rate.
    static let currencyCode = "USD"
    static let locale = Locale(identifier: "es_CO")

    /// Formats an amount. Takes `Cents` — never a `Double` — so there is no path from the API's
    /// floating point to the screen that skips the integer conversion.
    static func string(_ amount: Cents) -> String {
        let value = Decimal(amount.rawValue) / 100
        return value.formatted(.currency(code: currencyCode).locale(locale))
    }

    /// A whole-number percentage, for discount badges: `10.48` reads as `-10 %`.
    static func percentage(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return "-\(rounded) %"
    }
}
