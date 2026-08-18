//
//  CartBadgeViewModel.swift
//  Features · Cart
//
//  The cart count, observed once for as long as the app is on screen.
//
//  It exists because the count cannot be observed from inside the toolbar item that displays it.
//  A `.task` there is tied to the lifetime of the bar button, and SwiftUI tears that down while
//  another screen is pushed over it — so a cart emptied by an order never reaches the badge, and it
//  keeps showing a count for a cart with nothing in it until something happens to re-create the
//  view. Owned by `RootView`, above the navigation stack, the subscription simply never stops.
//

import Foundation
import Observation

@Observable
final class CartBadgeViewModel {

    private(set) var count = 0

    private let observeCart: ObserveCart

    init(observeCart: ObserveCart) {
        self.observeCart = observeCart
    }

    func start() async {
        for await lines in observeCart() {
            // Units, not lines: three of one product is three things in the bag.
            count = lines.reduce(0) { $0 + $1.quantity }
        }
    }
}
