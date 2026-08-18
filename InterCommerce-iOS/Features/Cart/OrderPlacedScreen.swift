//
//  OrderPlacedScreen.swift
//  Features · Cart
//
//  Confirmation after checkout: a brand-coloured field with the illustration, and a light sheet
//  carrying the message and the one way out.
//
//  Stateless and without a view model. It shows one message and offers one action, and nothing on
//  it can change while it is open — a model here would be a model with nothing to model.
//

import SwiftUI

struct OrderPlacedScreen: View {
    let onBackToCatalog: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            Color.brandPrimary.ignoresSafeArea()

            // Stacked, the sheet takes the height it needs and the illustration gets the remainder —
            // on a phone held sideways that remainder is a thumbnail, with half the width unused
            // beside it. Side by side past the breakpoint, the same arrangement the detail uses.
            if isWide {
                HStack(spacing: 0) {
                    illustration
                    sheet(corners: .rect(topLeadingRadius: CornerRadius.card, bottomLeadingRadius: CornerRadius.card))
                }
            } else {
                VStack(spacing: 0) {
                    illustration
                    sheet(corners: .rect(topLeadingRadius: CornerRadius.card, topTrailingRadius: CornerRadius.card))
                }
            }
        }
        .navigationBarBackButtonHidden()
        // There is nothing to go back to: the cart was emptied by the order, and the stack no
        // longer holds it.
        .toolbar(.hidden, for: .navigationBar)
    }

    private var illustration: some View {
        Image(.orderPlaced)
            .resizable()
            // `scaledToFit` and not a fraction of the width: the aspect ratio belongs to the asset,
            // and pinning one here breaks the day it is replaced.
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Spacing.xl)
            // Decorative: the heading right below states the outcome.
            .accessibilityHidden(true)
    }

    private func sheet(corners: UnevenRoundedRectangle) -> some View {
        // Scrollable rather than clipped: at a large text size on a short screen the sheet outgrows
        // what it is given, and a confirmation whose button cannot be reached is not a confirmation.
        ScrollView {
            VStack(spacing: Spacing.l) {
                Text("Order placed")
                    .font(.gabarito(.title, weight: .bold))
                    .foregroundStyle(.textPrimary)

                Text("We'll send the confirmation by email.")
                    .font(.gabarito(.body))
                    .foregroundStyle(.textSecondary)

                Button(action: onBackToCatalog) {
                    Text("Back to the catalogue")
                        .font(.gabarito(.headline, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: Layout.minimumTouchTarget)
                }
                .buttonStyle(.glassProminent)
                .tint(.brandPrimary)
                .padding(.top, Spacing.s)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Only the BACKGROUND runs under the home indicator. Sized to the safe area instead, the
        // sheet stops short and leaves a band of the brand colour below it; extending the content
        // too would put the button under the indicator.
        .background {
            Color.surfaceElevated
                .clipShape(corners)
                .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: isWide ? .infinity : nil)
    }
}

#Preview("Order placed") {
    OrderPlacedScreen(onBackToCatalog: {})
}

#Preview("Order placed · accessibility size") {
    OrderPlacedScreen(onBackToCatalog: {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
