//
//  AppActionButton.swift
//  DesignSystem
//
//  The app's action button.
//
//  It exists because `.buttonStyle(.glassProminent)` sizes itself to its label, and a short label
//  like "Reload" comes out around 36 pt tall — under the 44 pt the HIG asks for, and noticeably
//  smaller than the same button on the next screen. The minimum height and the horizontal breathing
//  room belong in one place, or every call site has to remember them.
//

import SwiftUI

struct AppActionButton: View {
    let title: LocalizedStringKey
    var style: Style = .prominent
    /// Fills the width where the button owns the bottom of a screen — the cart CTA, the
    /// confirmation. Left off inside an empty state, where a full-bleed button reads as a banner.
    var fillsWidth = false
    let action: () -> Void

    enum Style {
        /// The one thing to do on the screen.
        case prominent
        /// An alternative next to it, or a retry that is not the main story.
        case secondary
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.gabarito(.headline, weight: .semibold))
                .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: Layout.minimumTouchTarget)
                .padding(.horizontal, fillsWidth ? 0 : Spacing.l)
        }
        .modifier(ActionButtonStyle(style: style))
    }
}

/// A modifier and not a branch in the body: `.buttonStyle` returns different types, and returning
/// them from one `if` would need an `AnyView` for no gain.
private struct ActionButtonStyle: ViewModifier {
    let style: AppActionButton.Style

    func body(content: Content) -> some View {
        switch style {
        case .prominent:
            content
                .buttonStyle(.glassProminent)
                .tint(.brandPrimary)
        case .secondary:
            content.buttonStyle(.glass)
        }
    }
}

#Preview("Action buttons") {
    VStack(spacing: Spacing.l) {
        AppActionButton(title: "Browse the catalogue") {}
        AppActionButton(title: "Try again", style: .secondary) {}
        AppActionButton(title: "Checkout", fillsWidth: true) {}
    }
    .padding(Spacing.l)
}
