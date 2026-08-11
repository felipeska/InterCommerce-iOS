//
//  ProductDetailContentView.swift
//  Features · Catalog · Detail
//
//  Stateless. Adapts to width: one scrolling column on a phone, gallery beside the details when
//  there is room.
//

import SwiftUI

struct ProductDetailContentView: View {
    let product: Product
    let quantityInCart: Int
    let onAddToCart: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// Incremented on every add. It is what drives both the haptic and the confirmation, so the two
    /// cannot fall out of step.
    @State private var addCount = 0
    @State private var showsConfirmation = false

    var body: some View {
        ScrollView {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: Spacing.xl) {
                    gallery.frame(maxWidth: .infinity)
                    details.frame(maxWidth: .infinity)
                }
                .padding(Spacing.l)
            } else {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    gallery
                    details
                }
                .padding(Spacing.l)
            }
        }
        .background(Color.background)
        .navigationTitle(product.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { addToCartButton }
        // The system modifier, not a UIImpactFeedbackGenerator: it respects the user's settings,
        // needs no permission and does nothing on a simulator, which is correct rather than broken
        //.
        .sensoryFeedback(.success, trigger: addCount)
    }

    private var addToCartButton: some View {
        Button {
            addCount += 1
            onAddToCart()
            showsConfirmation = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                showsConfirmation = false
            }
        } label: {
            Label(buttonTitle, systemImage: showsConfirmation ? "checkmark" : "cart.badge.plus")
                .font(.gabarito(.headline, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: Layout.minimumTouchTarget)
                // The visual confirmation is the primary signal; the haptic only reinforces it.
                // Someone with haptics off must still see that something happened.
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.glassProminent)
        .tint(.brandPrimary)
        .disabled(product.isOutOfStock)
        .padding(Spacing.l)
    }

    private var buttonTitle: LocalizedStringKey {
        if showsConfirmation { return "Added" }
        if product.isOutOfStock { return "Out of stock" }
        // Saying what is already there beats a silent second add.
        return quantityInCart > 0 ? "Add another (\(quantityInCart) in cart)" : "Add to cart"
    }

    private var gallery: some View {
        TabView {
            // Falls back to the thumbnail: a product with no gallery still shows the picture the
            // grid was showing, rather than an empty frame.
            ForEach(product.imageURLs.isEmpty ? [product.thumbnailURL].compactMap { $0 } : product.imageURLs, id: \.self) { url in
                CachedAsyncImage.product(url: url)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .tabViewStyle(.page)
        .frame(height: 320)
        .clipShape(.rect(cornerRadius: CornerRadius.card))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(product.title)
                    .font(.gabarito(.title2, weight: .bold))
                    .foregroundStyle(.textPrimary)

                if !product.brand.isEmpty {
                    Text(product.brand)
                        .font(.gabarito(.subheadline))
                        .foregroundStyle(.textSecondary)
                }
            }

            PriceLabel(price: product.price, size: .large)

            stock

            if !product.summary.isEmpty {
                Text(product.summary)
                    .font(.gabarito(.body))
                    .foregroundStyle(.textPrimary)
            }

            VStack(spacing: 0) {
                specification("Availability", product.availabilityStatus)
                specification("Shipping", product.shippingInformation)
                specification("Warranty", product.warrantyInformation)
                specification("Returns", product.returnPolicy)
            }
        }
    }

    private var stock: some View {
        // Never colour alone: the symbol and the words carry the meaning too.
        Label(
            product.isOutOfStock ? "Out of stock" : "In stock · \(product.stock) available",
            systemImage: product.isOutOfStock ? "xmark.circle" : "checkmark.circle"
        )
        .font(.gabarito(.footnote, weight: .medium))
        .foregroundStyle(product.isOutOfStock ? Color.discount : Color.textSecondary)
    }

    @ViewBuilder
    private func specification(_ label: LocalizedStringKey, _ value: String?) -> some View {
        // A missing field is simply absent: no empty rows, no "N/A".
        if let value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label)
                    .font(.gabarito(.footnote))
                    .foregroundStyle(.textSecondary)
                Spacer(minLength: Spacing.l)
                Text(value)
                    .font(.gabarito(.footnote, weight: .medium))
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, Spacing.s)
            .overlay(alignment: .bottom) { Divider().overlay(Color.separatorLine) }
        }
    }
}

#Preview("Detail") {
    NavigationStack {
        ProductDetailContentView(product: .preview, quantityInCart: 0, onAddToCart: {})
    }
}

#Preview("Already in the cart") {
    NavigationStack {
        ProductDetailContentView(product: .preview, quantityInCart: 2, onAddToCart: {})
    }
}

#Preview("Out of stock, no brand") {
    NavigationStack {
        ProductDetailContentView(product: Product.previewList[1], quantityInCart: 0, onAddToCart: {})
    }
}
