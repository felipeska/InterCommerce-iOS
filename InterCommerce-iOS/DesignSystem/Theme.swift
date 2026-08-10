//
//  Theme.swift
//  DesignSystem
//
//  Colour and type. Nine semantic tokens, not a palette: a view asks for `.textSecondary`, never for
//  a grey. A literal colour in a view is a review failure (design.md §2).
//

import SwiftUI
import UIKit

// MARK: - Colour
//
// There is no colour extension here on purpose. Xcode generates type-safe symbols from the asset
// catalog (`Color.brandPrimary`, `.surfaceElevated`, `.separatorLine`…), so a typo fails the build
// instead of silently resolving to a transparent `Color("Typo")`. Declaring our own accessors would
// only shadow them — the first attempt did exactly that and collided.
//
// The tokens are: brandPrimary, brandPrimaryContent, background, surface, surfaceElevated,
// textPrimary, textSecondary, separatorLine, discount (design.md §2).
//
// `separatorLine` is not called `separator`: that name collides with `UIColor.separator` and breaks
// symbol generation.

// MARK: - Type

extension Font {

    /// Gabarito at a given weight, scaled by the user's Dynamic Type setting.
    ///
    /// The weight is applied through the font's `wght` **variation axis**, not by name. Phase 0
    /// established why: this is a variable font, and iOS registers its instances under derived
    /// names (`Gabarito-Regular_Bold`), so `UIFont(name: "Gabarito-Bold")` is `nil`. Those derived
    /// names are an implementation detail; the axis is the semantic API (design.md §3).
    static func gabarito(_ style: Font.TextStyle, weight: GabaritoWeight = .regular) -> Font {
        let textStyle = style.uiTextStyle
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "Gabarito-Regular",
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
                GabaritoWeight.axis: weight.rawValue
            ],
        ])

        let base = UIFont(descriptor: descriptor, size: UIFont.preferredFont(forTextStyle: textStyle).pointSize)
        // Scaled, not fixed: without this the custom font would ignore Dynamic Type, which is the
        // most common way a bundled typeface breaks accessibility.
        return Font(UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base))
    }
}

/// The weights this app uses, as points on the `wght` axis (the font ranges 400 to 900).
enum GabaritoWeight: Int {
    case regular = 400
    case medium = 500
    case semibold = 600
    case bold = 700

    /// The four-character code for the weight axis, as CoreText expects it.
    static let axis = 0x77676874 // 'wght'
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .body
        }
    }
}
