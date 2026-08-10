//
//  SchemaV1.swift
//  Data · Persistence
//
//  The whole database, in one file. Three models, no relationships between them — and the absence
//  of one of those relationships is the single most important decision in this schema.
//

import Foundation
import SwiftData

// MARK: - Catalog

/// A cached product. Disposable: the catalogue is a cache, the server is the authority.
@Model
nonisolated final class ProductEntity {
    /// The grid always sorts by `position`, so it gets an index. Available because the deployment
    /// target is iOS 26: `#Index` is iOS 18 (ADR §22).
    #Index<ProductEntity>([\.position])

    /// Unique so that inserting an id that already exists upserts instead of duplicating.
    @Attribute(.unique) var id: Int

    var title: String
    /// Not `description`: that name collides with `CustomStringConvertible` on a class.
    var productDescription: String
    var category: String
    /// `""` when the API omits it, normalised once in the mapper (ADR §32). Not optional, so the
    /// local search predicate does not have to carry a `??` — which SwiftData translates poorly.
    var brand: String
    /// Money is an integer. Never `Double` (ADR §3).
    var listCents: Int64
    var discountPercentage: Double
    var rating: Double
    var stock: Int
    var thumbnail: String
    var images: [String]
    var availabilityStatus: String?
    var shippingInformation: String?
    var warrantyInformation: String?
    var returnPolicy: String?
    /// `skip + index within the page`. The JSON carries no ordering, so it is materialised here;
    /// the grid sorts by this and not by `id`.
    var position: Int
    var cachedAt: Date

    init(
        id: Int,
        title: String,
        productDescription: String,
        category: String,
        brand: String,
        listCents: Int64,
        discountPercentage: Double,
        rating: Double,
        stock: Int,
        thumbnail: String,
        images: [String],
        availabilityStatus: String?,
        shippingInformation: String?,
        warrantyInformation: String?,
        returnPolicy: String?,
        position: Int,
        cachedAt: Date
    ) {
        self.id = id
        self.title = title
        self.productDescription = productDescription
        self.category = category
        self.brand = brand
        self.listCents = listCents
        self.discountPercentage = discountPercentage
        self.rating = rating
        self.stock = stock
        self.thumbnail = thumbnail
        self.images = images
        self.availabilityStatus = availabilityStatus
        self.shippingInformation = shippingInformation
        self.warrantyInformation = warrantyInformation
        self.returnPolicy = returnPolicy
        self.position = position
        self.cachedAt = cachedAt
    }
}

/// The pagination cursor. A single row: where to continue, how many exist, when it was refreshed.
@Model
nonisolated final class CatalogRemoteKey {
    var nextSkip: Int
    var total: Int
    var lastRefreshAt: Date

    init(nextSkip: Int, total: Int, lastRefreshAt: Date) {
        self.nextSkip = nextSkip
        self.total = total
        self.lastRefreshAt = lastRefreshAt
    }
}

// MARK: - Cart

/// A line the user added. **User data, not cache**: nothing purges this.
///
/// - Important: there is deliberately **no relationship to `ProductEntity`**. A refresh deletes
///   every product, and a `@Relationship` — even the innocent-looking optional kind — would let the
///   default delete rule empty the user's cart on the first refresh. That is the most likely
///   data-loss bug in this brief (ADR §12).
///
///   The fields below are a snapshot taken when the product was added, which also means the user
///   keeps seeing the price they accepted rather than one that changed underneath them.
@Model
nonisolated final class CartItemEntity {
    @Attribute(.unique) var productId: Int

    var title: String
    var thumbnail: String
    var listCents: Int64
    var discountPercentage: Double
    var quantity: Int
    var addedAt: Date
    var updatedAt: Date

    init(
        productId: Int,
        title: String,
        thumbnail: String,
        listCents: Int64,
        discountPercentage: Double,
        quantity: Int,
        addedAt: Date,
        updatedAt: Date
    ) {
        self.productId = productId
        self.title = title
        self.thumbnail = thumbnail
        self.listCents = listCents
        self.discountPercentage = discountPercentage
        self.quantity = quantity
        self.addedAt = addedAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Versioning

/// Versioned from day one. Adding the version later means migrating blind, because there is no
/// recorded shape to migrate *from*.
nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ProductEntity.self, CatalogRemoteKey.self, CartItemEntity.self]
    }
}

/// Empty on purpose: one version, no stages yet. It exists so the next schema change has somewhere
/// to declare its migration instead of inventing the plumbing under pressure.
nonisolated enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// MARK: - Row updates

nonisolated extension ProductEntity {
    /// Whether a fresh copy carries anything the user would notice.
    ///
    /// `cachedAt` and `position` are excluded on purpose: the first always differs, and the second
    /// belongs to whoever paged the row in. Comparing them would make every detail refresh a write,
    /// which is the difference between a quiet background refresh and a grid that churns.
    func differs(from other: ProductEntity) -> Bool {
        title != other.title
            || productDescription != other.productDescription
            || category != other.category
            || brand != other.brand
            || listCents != other.listCents
            || discountPercentage != other.discountPercentage
            || rating != other.rating
            || stock != other.stock
            || thumbnail != other.thumbnail
            || images != other.images
            || availabilityStatus != other.availabilityStatus
            || shippingInformation != other.shippingInformation
            || warrantyInformation != other.warrantyInformation
            || returnPolicy != other.returnPolicy
    }

    /// Copies everything except `position`, which the caller owns.
    func apply(_ other: ProductEntity) {
        title = other.title
        productDescription = other.productDescription
        category = other.category
        brand = other.brand
        listCents = other.listCents
        discountPercentage = other.discountPercentage
        rating = other.rating
        stock = other.stock
        thumbnail = other.thumbnail
        images = other.images
        availabilityStatus = other.availabilityStatus
        shippingInformation = other.shippingInformation
        warrantyInformation = other.warrantyInformation
        returnPolicy = other.returnPolicy
        cachedAt = other.cachedAt
    }
}
