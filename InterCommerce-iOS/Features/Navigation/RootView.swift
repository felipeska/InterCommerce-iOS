//
//  RootView.swift
//  Features · Navigation
//
//  The navigation stack. Destinations are a `Hashable` enum carrying primitives only: the detail
//  screen re-reads its product from the store rather than receiving it (architecture.md §7).
//

import SwiftUI

struct RootView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            CatalogScreen(dependencies: dependencies)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .productDetail(let id):
                        // Phase 4.
                        Text("Product \(id)")
                    case .cart:
                        // Phase 5.
                        Text("Cart")
                    }
                }
        }
    }
}

#Preview {
    RootView()
}
