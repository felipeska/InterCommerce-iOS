//
//  CartContentView.swift
//  Features · Cart
//

import SwiftUI

struct CartContentView: View {
    let lines: [CartLine]
    let totals: CartTotals
    let taxPercentage: Double
    let onQuantityChange: (CartLine, Int) -> Void
    let onRemove: (CartLine) -> Void
    let onBrowse: () -> Void
    let onCheckout: () -> Void

    var body: some View {
        Group {
            if lines.isEmpty {
                AppEmptyView(
                    title: "Your cart is empty",
                    message: "Products you add will show up here.",
                    systemImage: "cart"
                ) {
                    Button("Browse the catalogue", action: onBrowse)
                        .buttonStyle(.glassProminent)
                }
            } else {
                List {
                    ForEach(lines) { line in
                        CartLineRow(
                            line: line,
                            onQuantityChange: { onQuantityChange(line, $0) }
                        )
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                onRemove(line)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .bottom) {
                    CartSummary(totals: totals, taxPercentage: taxPercentage, onCheckout: onCheckout)
                }
            }
        }
        .navigationTitle("Cart")
    }
}

#Preview("With lines") {
    NavigationStack {
        CartContentView(
            lines: CartLine.previewList,
            totals: CalculateCartTotals(taxPolicy: TaxPolicy(basisPoints: 1_900))(CartLine.previewList),
            taxPercentage: 19,
            onQuantityChange: { _, _ in }, onRemove: { _ in }, onBrowse: {}, onCheckout: {}
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        CartContentView(
            lines: [], totals: .empty, taxPercentage: 0,
            onQuantityChange: { _, _ in }, onRemove: { _ in }, onBrowse: {}, onCheckout: {}
        )
    }
}
