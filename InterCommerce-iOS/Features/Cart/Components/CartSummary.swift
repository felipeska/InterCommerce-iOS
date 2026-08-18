//
//  CartSummary.swift
//  Features · Cart · Components
//
//  Opaque, not glass: these are the figures the person is deciding on, and legibility beats the
//  effect.
//

import SwiftUI

struct CartSummary: View {
    let totals: CartTotals
    let taxPercentage: Double

    var body: some View {
        VStack(spacing: Spacing.s) {
            // The gross sum, not the discounted one: the rows below read top to bottom as
            // subtotal − discounts + tax = total, and a subtotal that already had the discount taken
            // out would contradict the "Discounts" line right under it.
            row("Subtotal", MoneyFormat.string(totals.gross))

            // Only when there is something to show: a "− $0,00" line is noise.
            if totals.discount != .zero {
                row("Discounts", "− " + MoneyFormat.string(totals.discount), emphasised: true)
            }

            // Always present, even at zero: the rate is part of what the person is agreeing to, and
            // hiding it at zero would make it look like it appeared out of nowhere later.
            row("Tax (\(formattedRate))", MoneyFormat.string(totals.tax))

            Divider().overlay(Color.separatorLine)

            HStack {
                Text("Total")
                    .font(.gabarito(.title3, weight: .bold))
                Spacer()
                Text(MoneyFormat.string(totals.total))
                    .font(.gabarito(.title2, weight: .bold))
            }
            .foregroundStyle(.textPrimary)
        }
        .padding(Spacing.l)
        .background(Color.surfaceElevated)
        .overlay(alignment: .top) { Divider().overlay(Color.separatorLine) }
        .accessibilityElement(children: .combine)
    }

    private var formattedRate: String {
        taxPercentage == taxPercentage.rounded()
            ? "\(Int(taxPercentage)) %"
            : String(format: "%.2f %%", taxPercentage)
    }

    private func row(_ label: LocalizedStringKey, _ value: String, emphasised: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.gabarito(.subheadline))
                .foregroundStyle(.textSecondary)
            Spacer()
            Text(value)
                .font(.gabarito(.subheadline, weight: .medium))
                .foregroundStyle(emphasised ? Color.discount : Color.textPrimary)
        }
    }
}

#Preview {
    CartSummary(
        totals: CalculateCartTotals(taxPolicy: TaxPolicy(basisPoints: 1_900))(CartLine.previewList),
        taxPercentage: 19
    )
}
