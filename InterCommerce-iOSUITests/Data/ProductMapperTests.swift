//
//  ProductMapperTests.swift
//  Data tests
//
//  Decoded from the real payload shape, not from a hand-written ideal one: the fixture below is a
//  trimmed copy of what dummyjson.com actually returns, including the fields the DTO ignores.
//

import Foundation
import Testing

@testable import InterCommerce_iOS

struct ProductMapperTests {

    /// Real response shape, including `reviews`, `meta`, `dimensions`, `tags` and `sku` — none of
    /// which the DTO declares. If ignoring unknown keys ever stopped working, this fails.
    private let fullPayload = Data("""
    {
      "id": 1,
      "title": "Essence Mascara Lash Princess",
      "description": "A popular mascara.",
      "category": "beauty",
      "price": 9.99,
      "discountPercentage": 10.48,
      "rating": 2.56,
      "stock": 99,
      "tags": ["beauty", "mascara"],
      "brand": "Essence",
      "sku": "BEA-ESS-ESS-001",
      "weight": 4,
      "dimensions": { "width": 15.14, "height": 13.08, "depth": 22.99 },
      "warrantyInformation": "1 week warranty",
      "shippingInformation": "Ships in 3-5 business days",
      "availabilityStatus": "In Stock",
      "reviews": [{ "rating": 3, "comment": "ok", "date": "2024-05-23", "reviewerName": "A", "reviewerEmail": "a@b.c" }],
      "returnPolicy": "No return policy",
      "minimumOrderQuantity": 48,
      "meta": { "createdAt": "2024-05-23", "updatedAt": "2024-05-23", "barcode": "9164", "qrCode": "https://x" },
      "images": ["https://cdn.dummyjson.com/1.webp"],
      "thumbnail": "https://cdn.dummyjson.com/thumbnail.webp"
    }
    """.utf8)

    /// A `groceries` product: the API omits `brand` entirely.
    private let payloadWithoutBrand = Data("""
    {
      "id": 22, "title": "Rice", "description": "", "category": "groceries",
      "price": 3.5, "discountPercentage": 0, "rating": 4.1, "stock": 5,
      "images": [], "thumbnail": "https://cdn.dummyjson.com/rice.webp"
    }
    """.utf8)

    private func decode(_ data: Data) throws -> ProductDTO {
        try JSONDecoder().decode(ProductDTO.self, from: data)
    }

    // MARK: - Decoding

    @Test("Unknown keys are ignored rather than fatal")
    func ignoresUnknownKeys() throws {
        let dto = try decode(fullPayload)
        #expect(dto.id == 1)
        #expect(dto.brand == "Essence")
    }

    @Test("A missing brand decodes instead of throwing")
    func missingBrandDecodes() throws {
        let dto = try decode(payloadWithoutBrand)
        #expect(dto.brand == nil)
    }

    // MARK: - Normalisation

    @Test("A missing brand becomes an empty string, not an optional carried onwards")
    func normalisesMissingBrand() throws {
        let entity = ProductMapper.entity(from: try decode(payloadWithoutBrand), position: 0)

        #expect(entity.brand == "")
        #expect(ProductMapper.domain(from: entity).brand.isEmpty)
    }

    @Test("Prices cross into integers exactly once", arguments: [
        (9.99, Int64(999)), (3.5, 350), (0.01, 1), (1_299.95, 129_995), (0, 0),
    ])
    func convertsPriceToCents(price: Double, expected: Int64) {
        #expect(ProductMapper.cents(from: price) == expected)
    }

    /// `19.99 * 100` is `1998.9999999999998` in binary floating point. Truncating gives 1998 — a
    /// cent lost on every conversion. Rounding is what makes this exact.
    @Test("Prices that float badly still convert exactly")
    func convertsAwkwardFloats() {
        #expect(ProductMapper.cents(from: 19.99) == 1_999)
        #expect(ProductMapper.cents(from: 8.29) == 829)
        #expect(ProductMapper.cents(from: 1.15) == 115)
    }

    @Test("Percentages become basis points")
    func convertsPercentageToBasisPoints() {
        #expect(ProductMapper.basisPoints(from: 10.48) == 1_048)
        #expect(ProductMapper.basisPoints(from: 0) == 0)
        #expect(ProductMapper.basisPoints(from: 100) == 10_000)
    }

    // MARK: - Domain

    @Test("The full round trip preserves what the app needs")
    func mapsToDomain() throws {
        let entity = ProductMapper.entity(from: try decode(fullPayload), position: 7)
        let product = ProductMapper.domain(from: entity)

        #expect(product.id == 1)
        #expect(product.title == "Essence Mascara Lash Princess")
        #expect(product.brand == "Essence")
        #expect(product.price.list == Cents(999))
        #expect(product.price.discountBasisPoints == 1_048)
        #expect(product.price.unitNet == Cents(894))
        #expect(product.thumbnailURL?.absoluteString == "https://cdn.dummyjson.com/thumbnail.webp")
        #expect(product.imageURLs.count == 1)
        #expect(entity.position == 7)
        #expect(product.isOutOfStock == false)
    }

    /// One broken URL must cost one image, not the product.
    @Test("Junk image URLs are dropped, and the product survives")
    func dropsMalformedURLs() throws {
        let dto = try decode(fullPayload)
        let entity = ProductMapper.entity(from: dto, position: 0)
        entity.images = ["https://valid.example/a.png", "not a url at all", "", "///nope"]

        let product = ProductMapper.domain(from: entity)

        #expect(product.imageURLs.map(\.absoluteString) == ["https://valid.example/a.png"])
        #expect(product.title == dto.title)
    }

    /// `URL(string:)` is not a validity check. These all produce a non-nil `URL`, which is why the
    /// mapper requires a scheme and a host instead of relying on the initialiser to fail.
    @Test("Strings that URL(string:) accepts but are not usable images", arguments: [
        "not a url at all", "///nope", "javascript:alert(1)", "file:///etc/passwd", "/relative/path.png",
    ])
    func rejectsNonRemoteURLs(candidate: String) {
        #expect(URL(string: candidate) != nil, "Fixture is wrong: URL(string:) already rejected this")
        #expect(ProductMapper.remoteImageURL(candidate) == nil)
    }

    @Test("Real image URLs pass through untouched")
    func acceptsRemoteURLs() {
        #expect(ProductMapper.remoteImageURL("https://cdn.dummyjson.com/a.webp")?.absoluteString
                == "https://cdn.dummyjson.com/a.webp")
    }

    @Test("Position is what the caller says, so pages keep the server's order")
    func carriesPosition() throws {
        let dto = try decode(fullPayload)
        let second = ProductMapper.entity(from: dto, position: 10 + 3)

        #expect(second.position == 13)
    }
}
