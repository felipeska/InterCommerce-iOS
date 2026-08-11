//
//  ShimmerModifier.swift
//  DesignSystem
//
//  The loading skeleton effect, in ~30 lines. No dependency: what a shimmer library adds here is a
//  package, and what it hides is a masked gradient.
//

import SwiftUI

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            // Reduce Motion is not a suggestion. A travelling highlight is exactly the kind of
            // repeating movement it exists to stop, so the placeholder simply stays dimmed.
            content.opacity(0.6)
        } else {
            content
                .mask {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            colors: [.black.opacity(0.35), .black, .black.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 1.6)
                        .phaseAnimator([false, true]) { highlight, travelling in
                            highlight.offset(x: travelling ? width * 1.3 : -width * 1.3)
                        } animation: { _ in
                            .linear(duration: 1.2)
                        }
                    }
                }
        }
    }
}

extension View {
    /// Marks this view as a loading placeholder.
    ///
    /// The caller is responsible for hiding the skeleton from VoiceOver: a screen reader should hear
    /// "loading products" once, not a dozen empty shapes.
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview("Shimmer") {
    VStack(alignment: .leading, spacing: Spacing.s) {
        RoundedRectangle(cornerRadius: CornerRadius.card).fill(.surface).frame(height: 160)
        RoundedRectangle(cornerRadius: CornerRadius.small).fill(.surface).frame(width: 140, height: 14)
        RoundedRectangle(cornerRadius: CornerRadius.small).fill(.surface).frame(width: 80, height: 14)
    }
    .shimmering()
    .padding(Spacing.l)
}
