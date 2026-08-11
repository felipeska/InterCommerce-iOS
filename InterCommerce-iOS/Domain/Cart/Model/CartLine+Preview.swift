//
//  CartLine+Preview.swift
//  Domain · Cart · Model
//

nonisolated extension CartLine {
    static let previewList: [CartLine] = [
        CartLine(
            productId: 1, title: "Essence Mascara Lash Princess",
            thumbnailURL: Product.preview.thumbnailURL,
            price: Price(list: Cents(999), discountBasisPoints: 1_048), quantity: 3
        ),
        CartLine(
            productId: 3, title: "Powder Canister", thumbnailURL: nil,
            price: Price(list: Cents(1_489), discountBasisPoints: 0), quantity: 1
        ),
    ]
}
