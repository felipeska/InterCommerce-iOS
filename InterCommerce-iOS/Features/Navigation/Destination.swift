//
//  Destination.swift
//  Features · Navigation
//
//  Every place the app can navigate to. Primitives only — never a `Product`, never a `@Model`.
//

nonisolated enum Destination: Hashable {
    case productDetail(id: Int)
    case cart
    case orderPlaced
}
