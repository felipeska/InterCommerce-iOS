//
//  RootView.swift
//  Features · Navigation
//
//  Placeholder. The catalogue arrives in Phase 2 and the navigation stack in Phase 4; this exists
//  so the app has a root that is not the Xcode template.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        ContentUnavailableView(
            "InterCommerce",
            systemImage: "shippingbox",
            description: Text("The catalogue arrives in Phase 2.")
        )
    }
}

#Preview {
    RootView()
}
