//
//  ProductDetailContentView.swift
//  Features · Catalog · Detail
//
//  Stateless. Adapts to width: one scrolling column on a phone, gallery beside the details when
//  there is room (design.md §6).
//

import SwiftUI

struct ProductDetailContentView: View {
    let product: Product
    @Environment(\.horizontalSizeClass) private var sizeClass

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
        ProductDetailContentView(product: .preview)
    }
}

#Preview("Out of stock, no brand") {
    NavigationStack {
        ProductDetailContentView(product: Product.previewList[1])
    }
}
