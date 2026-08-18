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

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // At accessibility sizes the grid is one column wide, so a square image would take
                // most of the screen and push the price below the fold. The thumbnail shrinks to a
                // fixed square beside the text, which is the same shape the cart already uses.
                HStack(alignment: .top, spacing: Spacing.m) {
                    thumbnail
                        .frame(width: 88, height: 88)
                        .clipShape(.rect(cornerRadius: CornerRadius.small))
                    details
                }
                .padding(Spacing.m)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    thumbnail
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .clipShape(.rect(cornerRadius: CornerRadius.card))

                    details
                        .padding(Spacing.m)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The image is square and the surface continues behind the text, so the whole cell reads as
        // one tile. Same shape and radius as the image, so the two corners line up exactly.
        .background(.surface, in: .rect(cornerRadius: CornerRadius.card))
        // One element, one sentence: VoiceOver reads the product, not four disconnected fragments.
        .accessibilityElement(children: .combine)
    }

    private var thumbnail: some View {
        CachedAsyncImage.product(url: product.thumbnailURL)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(product.title)
                .font(.gabarito(.subheadline, weight: .medium))
                .foregroundStyle(.textPrimary)
                // Two lines is right for a dense grid cell. At accessibility sizes those two lines
                // hold about four words, so the limit comes off and the card grows instead.
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)

            // No brand means no line, and no reserved gap: the card just gets shorter.
            if !product.brand.isEmpty {
                Text(product.brand)
                    .font(.gabarito(.footnote))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            }

            PriceLabel(price: product.price)

            if product.isOutOfStock {
                Label("Out of stock", systemImage: "xmark.circle")
                    .font(.gabarito(.caption, weight: .medium))
                    .foregroundStyle(.discount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Card") {
    ProductCard(product: .preview)
        .frame(width: 180)
        .padding(Spacing.l)
}

#Preview("Card · accessibility size") {
    ProductCard(product: .preview)
        .padding(Spacing.l)
        .environment(\.dynamicTypeSize, .accessibility3)
}
