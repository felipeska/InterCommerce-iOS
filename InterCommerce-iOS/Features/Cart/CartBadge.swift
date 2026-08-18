//
//  CartBadge.swift
//  Features · Cart
//
//  The count in the toolbar. Purely a display: the number is observed by `CartBadgeViewModel`,
//  which outlives this view.
//

import SwiftUI

struct CartBadge: View {
    let count: Int

    var body: some View {
        Image(systemName: "cart")
            .badge(count)
            .accessibilityLabel(count == 0 ? Text("Cart, empty") : Text("Cart, \(count) items"))
    }
}

#Preview("Badge") {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CartBadge(count: 3) }
            }
    }
}
