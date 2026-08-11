//
//  CatalogSkeletonGrid.swift
//  Features · Catalog · Components
//
//  The loading state the brief asks for by name. Same grid, same cell size and the same column count
//  as the real thing, so the content does not jump when it arrives.
//

import SwiftUI

struct CatalogSkeletonGrid: View {
    var body: some View {
        LazyVGrid(columns: CatalogGrid.columns, spacing: Spacing.m) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.aspectRatio(1, contentMode: .fit)

                    // The bars sit on the tile, so they are drawn in the elevated tone rather than
                    // in the surface the card itself is painted with.
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(.surfaceElevated)
                            .frame(height: 14)
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(.surfaceElevated)
                            .frame(width: 80, height: 14)
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(.surface, in: .rect(cornerRadius: CornerRadius.card))
            }
        }
        .shimmering()
        // A screen reader should hear "loading products" once, not a dozen empty shapes.
        .accessibilityHidden(true)
    }
}

/// Shared by the real grid and its skeleton, so they cannot drift apart.
enum CatalogGrid {
    static let columns = [
        GridItem(.adaptive(minimum: Layout.productCellMinimumWidth), spacing: Spacing.m)
    ]
}

#Preview("Skeletons") {
    ScrollView {
        CatalogSkeletonGrid().padding(Spacing.l)
    }
}
