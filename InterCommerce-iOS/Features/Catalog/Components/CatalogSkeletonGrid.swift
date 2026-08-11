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
                VStack(alignment: .leading, spacing: Spacing.s) {
                    RoundedRectangle(cornerRadius: CornerRadius.card)
                        .fill(.surface)
                        .aspectRatio(1, contentMode: .fit)
                    RoundedRectangle(cornerRadius: CornerRadius.small).fill(.surface).frame(height: 14)
                    RoundedRectangle(cornerRadius: CornerRadius.small).fill(.surface).frame(width: 80, height: 14)
                }
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
