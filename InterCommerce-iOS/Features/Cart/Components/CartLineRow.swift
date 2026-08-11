//
//  CartLineRow.swift
//  Features · Cart · Components
//

import SwiftUI

struct CartLineRow: View {
    let line: CartLine
    let onQuantityChange: (Int) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            CachedAsyncImage.product(url: line.thumbnailURL)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: CornerRadius.small))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(line.title)
                    .font(.gabarito(.subheadline, weight: .medium))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)

                Text(MoneyFormat.string(line.price.unitNet))
                    .font(.gabarito(.footnote))
                    .foregroundStyle(.textSecondary)

                // The system stepper: 44 pt targets, VoiceOver and Dynamic Type for free.
                //
                // Increment/decrement rather than a `Binding`: routing the callback through
                // `Binding(get:set:)` crashes the compiler (swift-frontend 6.3.3, IRGen, while
                // emitting the reabstraction thunk for the isolated setter). This form is also the
                // clearer one — decrementing at 1 hands 0 to the caller, which is what removes the
                // line.
                Stepper {
                    Text("Quantity: \(line.quantity)")
                        .font(.gabarito(.footnote))
                        .foregroundStyle(.textPrimary)
                } onIncrement: {
                    guard line.quantity < CartLine.quantityRange.upperBound else { return }
                    onQuantityChange(line.quantity + 1)
                } onDecrement: {
                    onQuantityChange(line.quantity - 1)
                }
            }

            Spacer(minLength: Spacing.s)

            Text(MoneyFormat.string(line.net))
                .font(.gabarito(.subheadline, weight: .semibold))
                .foregroundStyle(.textPrimary)
        }
        .padding(.vertical, Spacing.s)
    }
}

#Preview {
    List {
        CartLineRow(line: CartLine.previewList[0], onQuantityChange: { _ in })
    }
}
