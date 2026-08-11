//
//  CartMapper.swift
//  Data · Cart
//
//  Product -> snapshot -> domain line. The snapshot is the whole point: after this, the cart owes
//  the catalogue nothing.
//

import Foundation

nonisolated enum CartMapper {
    static func entity(from product: Product, quantity: Int, now: Date = .now) -> CartItemEntity {
        CartItemEntity(
            productId: product.id,
            title: product.title,
            thumbnail: product.thumbnailURL?.absoluteString ?? "",
            listCents: product.price.list.rawValue,
            // Stored back as a percentage because that is the entity's shape; the domain converts it
            // to basis points on the way out, exactly like the catalogue does.
            discountPercentage: product.price.discountPercentage,
            quantity: quantity,
            addedAt: now,
            updatedAt: now
        )
    }

    static func domain(from entity: CartItemEntity) -> CartLine {
        CartLine(
            productId: entity.productId,
            title: entity.title,
            thumbnailURL: ProductMapper.remoteImageURL(entity.thumbnail),
            price: Price(
                list: Cents(entity.listCents),
                discountBasisPoints: ProductMapper.basisPoints(from: entity.discountPercentage)
            ),
            quantity: entity.quantity
        )
    }
}
