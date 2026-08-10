//
//  Spacing.swift
//  DesignSystem
//
//  The numbers the layout is allowed to use. A literal `16` in a view is a review failure: it is
//  how two screens end up almost-but-not-quite aligned.
//

import Foundation

enum Spacing {
    /// 4 — between a label and its value.
    static let xs: CGFloat = 4
    /// 8 — inside a card.
    static let s: CGFloat = 8
    /// 12 — between grid cells.
    static let m: CGFloat = 12
    /// 16 — screen margins.
    static let l: CGFloat = 16
    /// 24 — between sections.
    static let xl: CGFloat = 24
}

enum CornerRadius {
    /// 12 — thumbnails.
    static let small: CGFloat = 12
    /// 16 — product cards, taken from the reference design.
    static let card: CGFloat = 16
}

enum Layout {
    /// Minimum touch target. The HIG floor, and the reason the quantity steppers are not smaller.
    static let minimumTouchTarget: CGFloat = 44
    /// Minimum width of a grid cell; the column count follows from the available width.
    static let productCellMinimumWidth: CGFloat = 168
}
