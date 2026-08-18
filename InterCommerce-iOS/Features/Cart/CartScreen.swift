//
//  CartScreen.swift
//  Features · Cart
//

import SwiftUI

struct CartScreen: View {
    @State private var viewModel: CartViewModel
    private let taxPercentage: Double
    let onBrowse: () -> Void
    let onCheckout: () -> Void

    init(
        dependencies: AppDependencies,
        onBrowse: @escaping () -> Void,
        onCheckout: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: CartViewModel(
            observeCart: dependencies.observeCart,
            updateQuantity: dependencies.updateQuantity,
            removeFromCart: dependencies.removeFromCart,
            addToCart: dependencies.addToCart,
            placeOrder: dependencies.placeOrder,
            calculateTotals: dependencies.calculateTotals
        ))
        self.taxPercentage = dependencies.taxPolicy.percentage
        self.onBrowse = onBrowse
        self.onCheckout = onCheckout
    }

    var body: some View {
        CartContentView(
            lines: viewModel.lines,
            totals: viewModel.totals,
            taxPercentage: taxPercentage,
            onQuantityChange: { line, quantity in
                Task { await viewModel.setQuantity(quantity, for: line) }
            },
            onRemove: { line in Task { await viewModel.remove(line) } },
            onBrowse: onBrowse,
            onCheckout: {
                Task {
                    // Only navigates when there was something to order.
                    if await viewModel.checkout() { onCheckout() }
                }
            }
        )
        .task { await viewModel.start() }
        .toolbar {
            // Undo for a stray swipe. Losing a cart line to an accidental gesture is precisely the
            // data loss this brief is about, and the fix costs one button.
            if viewModel.lastRemoved != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Undo") { Task { await viewModel.undoRemove() } }
                }
            }
        }
    }
}
