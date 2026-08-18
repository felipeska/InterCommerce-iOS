//
//  PriceLabel.swift
//  Features · Catalog · Components
//
//  Shows a price. It **only formats**: the discounted amount, the struck-through original and the
//  percentage all come out of `Price`. No view in this app does money arithmetic.
//
//  It lives with the catalogue rather than in DesignSystem because only the catalogue and its detail
//  screen use it — the cart formats with `MoneyFormat` directly. It moves up when a second feature
//  needs it, not before.
//

import SwiftUI

struct PriceLabel: View {
    let price: Price
    var size: Size = .regular

    @Environment(\.dynamicTypeSize) private var typeSize

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
                // Side by side normally, stacked at accessibility sizes, where the two together are
                // wider than the cell and a struck-through price truncated to "US$ 9…" tells the
                // user nothing. `ViewThatFits` looks like the tool for this and is not: it proposes
                // an ideal size, so the text reports a single line and then truncates instead of
                // wrapping.
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        originalPrice
                        discountPercentage
                    }
                } else {
                    HStack(spacing: Spacing.s) {
                        originalPrice
                        discountPercentage
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The original price is struck through and the percentage is spelled out, so the discount never
    /// depends on colour alone to be understood.
    private var originalPrice: some View {
        Text(MoneyFormat.string(price.list))
            .font(.gabarito(size.originalStyle))
            .strikethrough()
            .foregroundStyle(.textSecondary)
            // Wrap rather than truncate when the cell is narrower than the formatted amount.
            .fixedSize(horizontal: false, vertical: true)
    }

    private var discountPercentage: some View {
        Text(MoneyFormat.percentage(price.discountPercentage))
            .font(.gabarito(size.originalStyle, weight: .medium))
            .foregroundStyle(.discount)
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
