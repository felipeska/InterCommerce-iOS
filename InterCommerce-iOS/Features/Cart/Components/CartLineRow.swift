//
//  CartLineRow.swift
//  Features · Cart · Components
//

import SwiftUI

struct CartLineRow: View {
    let line: CartLine
    let onQuantityChange: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            CachedAsyncImage.product(url: line.thumbnailURL)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: CornerRadius.small))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(line.title)
                    .font(.gabarito(.subheadline, weight: .medium))
                    .foregroundStyle(.textPrimary)
                    // Two lines keep the rows even; at accessibility sizes they hold three words,
                    // so the row grows instead of hiding what the person is paying for.
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)

                Text(MoneyFormat.string(line.price.unitNet))
                    .font(.gabarito(.footnote))
                    .foregroundStyle(.textSecondary)

                Text("Quantity: \(line.quantity)")
                    .font(.gabarito(.footnote))
                    .foregroundStyle(.textPrimary)
            }

            Spacer(minLength: Spacing.s)

            VStack(alignment: .trailing, spacing: Spacing.s) {
                Text(MoneyFormat.string(line.net))
                    .font(.gabarito(.subheadline, weight: .semibold))
                    .foregroundStyle(.textPrimary)

                // The system stepper: 44 pt targets, VoiceOver and Dynamic Type for free.
                //
                // Increment/decrement rather than a `Binding`: routing the callback through
                // `Binding(get:set:)` crashes the compiler (swift-frontend 6.3.3, IRGen, while
                // emitting the reabstraction thunk for the isolated setter). This form is also the
                // clearer one — decrementing at 1 hands 0 to the caller, which is what removes the
                // line.
                Stepper {
                    // The count is spelled out beside the title instead; hiding the label here is
                    // what lets the stepper shrink to just its two buttons.
                    Text("Quantity: \(line.quantity)")
                } onIncrement: {
                    guard line.quantity < CartLine.quantityRange.upperBound else { return }
                    onQuantityChange(line.quantity + 1)
                } onDecrement: {
                    onQuantityChange(line.quantity - 1)
                }
                .labelsHidden()
            }
        }
        .padding(.vertical, Spacing.s)
    }
}

#Preview {
    List {
        CartLineRow(line: CartLine.previewList[0], onQuantityChange: { _ in })
    }
}
