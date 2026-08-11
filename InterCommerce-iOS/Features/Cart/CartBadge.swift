//
//  CartBadge.swift
//  Features · Cart
//
//  The count in the toolbar, on every screen. It observes the cart directly rather than having the
//  number passed down, so it cannot drift out of step with what is actually stored.
//

import SwiftUI

struct CartBadge: View {
    @State private var count = 0
    private let observeCart: ObserveCart

    init(observeCart: ObserveCart) {
        self.observeCart = observeCart
    }

    var body: some View {
        Image(systemName: "cart")
            .overlay(alignment: .topTrailing) {
                if count > 0 {
                    Text(count, format: .number)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.red, in: .capsule)
                        .alignmentGuide(.top) { $0[.bottom] / 2 }
                        .alignmentGuide(.trailing) { $0[.leading] + $0.width / 2 }
                }
            }
            .accessibilityLabel(count == 0 ? Text("Cart, empty") : Text("Cart, \(count) items"))
            .task {
                for await lines in observeCart() {
                    // Units, not lines: three of one product is three things in the bag.
                    count = lines.reduce(0) { $0 + $1.quantity }
                }
            }
    }
}
