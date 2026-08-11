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
    /// Shared by the card and the detail so the zoom transition can match them. It lives here
    /// because the source and the destination are declared in different views.
    @Namespace private var productTransition

    var body: some View {
        NavigationStack(path: $path) {
            CatalogScreen(dependencies: dependencies, transitionNamespace: productTransition)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .productDetail(let id):
                        ProductDetailScreen(productId: id, dependencies: dependencies)
                            .navigationTransition(.zoom(sourceID: id, in: productTransition))
                    case .cart:
                        CartScreen(dependencies: dependencies) { path.removeLast(path.count) }
                    }
                }
        }
    }
}

#Preview {
    RootView()
}
