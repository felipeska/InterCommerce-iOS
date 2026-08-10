//
//  ProductMapper.swift
//  Data · Catalog
//
//  DTO -> entity -> domain. Three conversions happen here and nowhere else, and each one is the
//  boundary where a whole class of bug is stopped:
//
//   1. `Double` money becomes integer cents, once.
//   2. A missing brand becomes `""`, once.
//   3. A malformed URL becomes `nil` instead of taking the product down with it.
//

import Foundation

nonisolated enum ProductMapper {

    // MARK: - DTO -> entity

    /// - Parameter position: `skip + index within the page`. The JSON carries no ordering, so the
    ///   server's order is materialised here; without it the grid would sort by id and pages would
    ///   interleave.
    static func entity(from dto: ProductDTO, position: Int, cachedAt: Date = .now) -> ProductEntity {
        ProductEntity(
            id: dto.id,
            title: dto.title,
            productDescription: dto.description,
            category: dto.category,
            brand: dto.brand ?? "",
            listCents: cents(from: dto.price),
            discountPercentage: dto.discountPercentage,
            rating: dto.rating,
            stock: dto.stock,
            thumbnail: dto.thumbnail,
            images: dto.images,
            availabilityStatus: dto.availabilityStatus,
            shippingInformation: dto.shippingInformation,
            warrantyInformation: dto.warrantyInformation,
            returnPolicy: dto.returnPolicy,
            position: position,
            cachedAt: cachedAt
        )
    }

    // MARK: - Entity -> domain

    static func domain(from entity: ProductEntity) -> Product {
        Product(
            id: entity.id,
            title: entity.title,
            summary: entity.productDescription,
            category: entity.category,
            brand: entity.brand,
            price: Price(
                list: Cents(entity.listCents),
                discountBasisPoints: basisPoints(from: entity.discountPercentage)
            ),
            rating: entity.rating,
            stock: entity.stock,
            // A bad URL costs one image, not the whole product. Decoding straight into `URL` would
            // have thrown and lost the entire response.
            thumbnailURL: remoteImageURL(entity.thumbnail),
            imageURLs: entity.images.compactMap(remoteImageURL),
            availabilityStatus: entity.availabilityStatus,
            shippingInformation: entity.shippingInformation,
            warrantyInformation: entity.warrantyInformation,
            returnPolicy: entity.returnPolicy
        )
    }

    // MARK: - Scalars

    /// `9.99` -> `999`. The single crossing from floating point to money in the whole app.
    static func cents(from price: Double) -> Int64 {
        Int64((price * 100).rounded())
    }

    /// `10.48 %` -> `1048` hundredths of a percent, so the discount arithmetic stays integral.
    static func basisPoints(from percentage: Double) -> Int {
        Int((percentage * 100).rounded())
    }

    /// An absolute `http(s)` URL, or `nil`.
    ///
    /// `URL(string:)` alone is **not** a validity check: since the RFC 3986 parser landed it happily
    /// returns a relative URL for `"not a url at all"` (percent-encoding the spaces), and it accepts
    /// `javascript:` and `file:` schemes too. A `compactMap(URL.init(string:))` therefore filters
    /// nothing — it just defers the failure to load time. Requiring a scheme and a host is what
    /// actually drops the junk, and it keeps a hostile payload from handing us a `file:` URL.
    static func remoteImageURL(_ string: String) -> URL? {
        guard let url = URL(string: string),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host()?.isEmpty == false
        else { return nil }
        return url
    }
}
