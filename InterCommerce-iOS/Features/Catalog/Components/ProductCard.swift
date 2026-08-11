//
//  ProductCard.swift
//  Features · Catalog · Components
//
//  One product in the grid. Opaque, never glass: the title and price have to stay readable over any
//  photograph, and that is a job for a solid surface.
//

import SwiftUI

struct ProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CachedAsyncImage.product(url: product.thumbnailURL)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: CornerRadius.card))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(product.title)
                    .font(.gabarito(.subheadline, weight: .medium))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)

                // No brand means no line, and no reserved gap: the card just gets shorter.
                if !product.brand.isEmpty {
                    Text(product.brand)
                        .font(.gabarito(.footnote))
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }

                PriceLabel(price: product.price)

                if product.isOutOfStock {
                    Label("Out of stock", systemImage: "xmark.circle")
                        .font(.gabarito(.caption, weight: .medium))
                        .foregroundStyle(.discount)
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The image is square and the surface continues behind the text, so the whole cell reads as
        // one tile. Same shape and radius as the image, so the two corners line up exactly.
        .background(.surface, in: .rect(cornerRadius: CornerRadius.card))
        // One element, one sentence: VoiceOver reads the product, not four disconnected fragments.
        .accessibilityElement(children: .combine)
    }
}

#Preview("Card") {
    ProductCard(product: .preview)
        .frame(width: 180)
        .padding(Spacing.l)
}
