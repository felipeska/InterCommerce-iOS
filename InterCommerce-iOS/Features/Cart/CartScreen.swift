//
//  CartScreen.swift
//  Features · Cart
//

import SwiftUI

struct CartScreen: View {
    @State private var model: CartModel
    private let taxPercentage: Double
    let onBrowse: () -> Void

    init(dependencies: AppDependencies, onBrowse: @escaping () -> Void) {
        _model = State(initialValue: CartModel(
            observeCart: dependencies.observeCart,
            updateQuantity: dependencies.updateQuantity,
            removeFromCart: dependencies.removeFromCart,
            addToCart: dependencies.addToCart,
            calculateTotals: dependencies.calculateTotals
        ))
        self.taxPercentage = dependencies.taxPolicy.percentage
        self.onBrowse = onBrowse
    }

    var body: some View {
        CartContentView(
            lines: model.lines,
            totals: model.totals,
            taxPercentage: taxPercentage,
            onQuantityChange: { line, quantity in
                Task { await model.setQuantity(quantity, for: line) }
            },
            onRemove: { line in Task { await model.remove(line) } },
            onBrowse: onBrowse
        )
        .task { await model.start() }
        .toolbar {
            // Undo for a stray swipe. Losing a cart line to an accidental gesture is precisely the
            // data loss this brief is about, and the fix costs one button.
            if model.lastRemoved != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Undo") { Task { await model.undoRemove() } }
                }
            }
        }
    }
}
