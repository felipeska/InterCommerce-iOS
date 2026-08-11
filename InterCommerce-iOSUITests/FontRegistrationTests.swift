//
//  FontRegistrationTests.swift
//  Phase 0 verification: the brand font is registered and its weights are reachable.
//
//  `gabarito_variable.ttf` is a VARIABLE font (single `wght` axis, 400 to 900). Probing it on the
//  iOS 26 simulator established three facts:
//
//   1. iOS does expose the named instances, but under DERIVED names, not canonical ones:
//      ["Gabarito-Regular", "Gabarito-Regular_Medium", "Gabarito-Regular_SemiBold",
//       "Gabarito-Regular_Bold", "Gabarito-Regular_ExtraBold", "Gabarito-Regular_Black"]
//   2. So `UIFont(name: "Gabarito-Bold")` returns **nil**: that name does not exist.
//   3. Setting the `wght` axis does resolve the real face (700 -> "Gabarito-Regular_Bold").
//
//  Decision: `Font.gabarito` selects weight through the axis, not by name. The
//  derived names are an implementation detail of how CoreText registers instances and may change
//  between releases; the axis is the semantic API and accepts any weight in range.
//
//  These tests are the net that fires if that ground shifts.
//

import Testing
import UIKit

struct FontRegistrationTests {

    @Test("Gabarito family is registered from the bundle")
    func familyIsRegistered() {
        #expect(
            UIFont.familyNames.contains("Gabarito"),
            "Gabarito is not registered: check UIAppFonts in Info.plist and target membership of the .ttf."
        )
    }

    @Test("Base weight is instantiable by name")
    func regularIsUsable() {
        #expect(UIFont(name: "Gabarito-Regular", size: 17) != nil)
    }

    @Test("Canonical weight names do not exist, so the axis is required")
    func canonicalWeightNamesDoNotExist() {
        #expect(
            UIFont(name: "Gabarito-Bold", size: 17) == nil,
            "Gabarito-Bold now resolves: iOS changed how it registers variable font instances, so the weight helper can be simplified to use names."
        )
    }

    @Test("The wght axis resolves a real face rather than a synthesised weight", arguments: [500, 700])
    func weightAxisResolvesRealFace(weight: Int) {
        let wght = 0x77676874 // 'wght'
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: "Gabarito-Regular",
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [wght: weight],
        ])
        let font = UIFont(descriptor: descriptor, size: 17)

        #expect(font.familyName == "Gabarito")
        #expect(
            font.fontName != "Gabarito-Regular",
            "The wght=\(weight) axis did not change the face: the weight would be synthesised."
        )
    }
}
