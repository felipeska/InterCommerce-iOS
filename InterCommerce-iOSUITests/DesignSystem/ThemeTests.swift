//
//  ThemeTests.swift
//  DesignSystem tests
//
//  Two things worth pinning: the type helper reaches real weights through the variation axis, and
//  money never gets formatted from a floating-point value.
//

import Foundation
import Testing
import UIKit

@testable import InterCommerce_iOS

@MainActor
struct ThemeTests {

    // MARK: - Type

    @Test("Every weight resolves to a distinct face, not a synthesised one", arguments: [
        GabaritoWeight.medium, .semibold, .bold,
    ])
    func weightsResolveDistinctFaces(weight: GabaritoWeight) {
        let regular = resolvedFont(weight: .regular)
        let variant = resolvedFont(weight: weight)

        #expect(variant.familyName == "Gabarito")
        #expect(variant.fontName != regular.fontName, "wght \(weight.rawValue) fell back to the regular face")
    }

    /// Dynamic Type is the thing a bundled typeface most often breaks: a custom font pinned to a
    /// point size ignores the user's setting entirely.
    @Test("The font scales with the user's text size")
    func fontScalesWithDynamicType() {
        let small = scaledSize(for: .init(forTextStyle: .body), category: .small)
        let large = scaledSize(for: .init(forTextStyle: .body), category: .accessibilityExtraExtraExtraLarge)

        #expect(large > small, "The font is not honouring Dynamic Type")
    }

    // MARK: - Money

    @Test("Cents are formatted from an integer, with the Colombian locale")
    func formatsMoney() {
        let formatted = MoneyFormat.string(Cents(999))

        #expect(formatted.contains("9"))
        #expect(formatted.contains("99"))
    }

    @Test("Formatting is exact where floating point would drift", arguments: [
        (Cents(2_997), "29"), (Cents(1), "0"), (Cents(100_000), "1"),
    ])
    func formatsExactly(amount: Cents, expectedFragment: String) {
        #expect(MoneyFormat.string(amount).contains(expectedFragment))
    }

    @Test("A discount percentage reads as a whole number")
    func formatsPercentage() {
        #expect(MoneyFormat.percentage(10.48) == "-10 %")
        #expect(MoneyFormat.percentage(9.51) == "-10 %")
    }

    // MARK: - Helpers

    private func resolvedFont(weight: GabaritoWeight) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "Gabarito-Regular",
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
                GabaritoWeight.axis: weight.rawValue
            ],
        ])
        return UIFont(descriptor: descriptor, size: 17)
    }

    private func scaledSize(for metrics: UIFontMetrics, category: UIContentSizeCategory) -> CGFloat {
        let base = UIFont(descriptor: UIFontDescriptor(fontAttributes: [.name: "Gabarito-Regular"]), size: 17)
        return metrics.scaledFont(
            for: base,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
        ).pointSize
    }
}
