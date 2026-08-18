//
//  RootView.swift
//  Features · Navigation
//
//  The navigation stack. Destinations are a `Hashable` enum carrying primitives only: the detail
//  screen re-reads its product from the store rather than receiving it.
//

import SwiftUI

struct RootView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var path = NavigationPath()
    /// Owned here so the subscription outlives every push: see `CartBadgeViewModel`.
    @State private var cartBadge: CartBadgeViewModel?
    /// Shared by the card and the detail so the zoom transition can match them. It lives here
    /// because the source and the destination are declared in different views.
    @Namespace private var productTransition

    var body: some View {
        NavigationStack(path: $path) {
            CatalogScreen(
                dependencies: dependencies,
                transitionNamespace: productTransition,
                cartCount: cartBadge?.count ?? 0,
                onOpenCart: { path.append(Destination.cart) }
            )
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .productDetail(let id):
                        ProductDetailScreen(productId: id, dependencies: dependencies)
                            .navigationTransition(.zoom(sourceID: id, in: productTransition))
                    case .cart:
                        CartScreen(
                            dependencies: dependencies,
                            onBrowse: { path.removeLast(path.count) },
                            // The cart leaves the stack with the order: going back from the
                            // confirmation must not land on a cart that was just emptied.
                            onCheckout: {
                                path.removeLast()
                                path.append(Destination.orderPlaced)
                            }
                        )

                    case .orderPlaced:
                        OrderPlacedScreen { path.removeLast(path.count) }
                    }
                }
        }
        .task {
            let model = cartBadge ?? CartBadgeViewModel(observeCart: dependencies.observeCart)
            cartBadge = model
            await model.start()
        }
    }
}

#Preview {
    RootView()
}
