//
//  PriceLabel.swift
//  Features · Catalog · Components
//
//  Shows a price. It **only formats**: the discounted amount, the struck-through original and the
//  percentage all come out of `Price`. No view in this app does money arithmetic (ADR §4).
//
//  It lives with the catalogue rather than in DesignSystem because only the catalogue and its detail
//  screen use it — the cart formats with `MoneyFormat` directly. It moves up when a second feature
//  needs it, not before (ADR §27).
//

import SwiftUI

struct PriceLabel: View {
    let price: Price
    var size: Size = .regular

    enum Size {
        case regular
        case large

        var finalStyle: Font.TextStyle { self == .large ? .title2 : .title3 }
        var originalStyle: Font.TextStyle { self == .large ? .subheadline : .footnote }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(MoneyFormat.string(price.unitNet))
                .font(.gabarito(size.finalStyle, weight: .semibold))
                .foregroundStyle(.textPrimary)

            if price.hasDiscount {
                HStack(spacing: Spacing.s) {
                    // The original price is struck through and the percentage is spelled out, so the
                    // discount never depends on colour alone to be understood.
                    Text(MoneyFormat.string(price.list))
                        .font(.gabarito(size.originalStyle))
                        .strikethrough()
                        .foregroundStyle(.textSecondary)

                    Text(MoneyFormat.percentage(price.discountPercentage))
                        .font(.gabarito(size.originalStyle, weight: .medium))
                        .foregroundStyle(.discount)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: Text {
        price.hasDiscount
            ? Text("\(MoneyFormat.string(price.unitNet)), reduced from \(MoneyFormat.string(price.list))")
            : Text(MoneyFormat.string(price.unitNet))
    }
}

#Preview("With discount") {
    PriceLabel(price: Price(list: Cents(999), discountBasisPoints: 1_048))
        .padding(Spacing.l)
}

#Preview("Without discount") {
    PriceLabel(price: Price(list: Cents(2_450), discountBasisPoints: 0), size: .large)
        .padding(Spacing.l)
}
