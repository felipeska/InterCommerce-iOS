//
//  ContrastTests.swift
//  DesignSystem tests
//
//  WCAG AA for every text colour on every surface it is actually drawn on, in both themes.
//
//  This started as a manual audit and found three real failures — the secondary text was a 50 %
//  tint, which lands wherever the surface underneath puts it (3.00:1 on a card), and the discount
//  red fell to 4.03:1 on the dark summary. A palette is edited casually and a ratio is invisible to
//  the eye, so the check belongs here rather than in someone's memory.
//

import Testing
import UIKit

@testable import InterCommerce_iOS

@MainActor
struct ContrastTests {

    /// Every pair the app actually renders: foreground, the surface behind it, and what it is.
    ///
    /// `nonisolated` because `@Test(arguments:)` evaluates its cases outside the actor, and this
    /// target's default isolation is the main actor.
    nonisolated static let textPairs: [(fg: String, bg: String, what: String)] = [
        ("TextPrimary", "Background", "body text"),
        ("TextPrimary", "Surface", "card title and price"),
        ("TextPrimary", "SurfaceElevated", "summary figures"),
        ("TextSecondary", "Background", "secondary text"),
        ("TextSecondary", "Surface", "brand, struck-through price, quantity"),
        ("TextSecondary", "SurfaceElevated", "summary labels"),
        ("Discount", "Surface", "discount percentage on a card"),
        ("Discount", "SurfaceElevated", "the discounts row"),
        ("Discount", "Background", "out-of-stock label"),
    ]

    @Test("Text clears AA on the surfaces it is drawn on", arguments: textPairs, [UIUserInterfaceStyle.light, .dark])
    func textClearsAA(pair: (fg: String, bg: String, what: String), style: UIUserInterfaceStyle) {
        let ratio = contrastRatio(pair.fg, on: pair.bg, style: style)

        #expect(
            ratio >= 4.5,
            "\(pair.fg) on \(pair.bg) (\(pair.what)) is \(String(format: "%.2f", ratio)):1 in \(style == .dark ? "dark" : "light") — AA needs 4.5:1"
        )
    }

    /// The CTA is the one exception, and it is deliberate: white on the brand purple is 3.79:1,
    /// which clears AA for large text only. The label is 17 pt semibold, and WCAG counts bold text
    /// from 14 pt as large, so it qualifies — but only as long as it stays bold and that size.
    @Test("The CTA label clears AA for large text", arguments: [UIUserInterfaceStyle.light, .dark])
    func ctaClearsLargeTextAA(style: UIUserInterfaceStyle) {
        let ratio = contrastRatio("BrandPrimaryContent", on: "BrandPrimary", style: style)

        #expect(ratio >= 3.0, "The CTA label is \(String(format: "%.2f", ratio)):1 — below AA even for large text")
    }

    // MARK: - WCAG arithmetic

    private func contrastRatio(_ foreground: String, on background: String, style: UIUserInterfaceStyle) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let bg = UIColor(named: background)!.resolvedColor(with: traits)
        // Composited, not taken raw: a colour with alpha is only as legible as what sits behind it.
        let fg = UIColor(named: foreground)!.resolvedColor(with: traits).composited(over: bg)

        let light = max(fg.relativeLuminance, bg.relativeLuminance)
        let dark = min(fg.relativeLuminance, bg.relativeLuminance)
        return (light + 0.05) / (dark + 0.05)
    }
}

private extension UIColor {

    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    func composited(over background: UIColor) -> UIColor {
        let top = rgba, bottom = background.rgba
        func blend(_ f: Double, _ b: Double) -> CGFloat { CGFloat(f * top.a + b * (1 - top.a)) }
        return UIColor(
            red: blend(top.r, bottom.r),
            green: blend(top.g, bottom.g),
            blue: blend(top.b, bottom.b),
            alpha: 1
        )
    }

    var relativeLuminance: Double {
        let (r, g, b, _) = rgba
        func channel(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
