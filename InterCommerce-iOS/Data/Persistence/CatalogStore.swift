//
//  CatalogStore.swift
//  Data · Persistence
//
//  The only place allowed to write products, and the only place that reads them. Everything that
//  mutates the catalogue goes through here, so the writes serialise without a single lock: the actor
//  owns the context.
//
//  Two writers exist by design — pages (the paginator) and one row (the detail refresh) — and both
//  live inside this actor. The contract is in ADR §26; the trap it prevents is doing a read here and
//  a write from outside, which reopens the race with the compiler's blessing.
//

import Foundation
import SwiftData

@ModelActor
actor CatalogStore {

    /// Live readers. The UI observes domain values through these, never SwiftData (ADR §30).
    private var subscribers: [UUID: AsyncStream<[Product]>.Continuation] = [:]

    // MARK: - Observation

    /// A stream of the catalogue, in server order, as domain values.
    ///
    /// This is what replaces `@Query`. It emits once immediately — so a screen opening offline has
    /// content on its first frame — and again after every write.
    ///
    /// - Note: emissions are published by the store itself rather than by observing
    ///   `ModelContext.didSave`. Two reasons, in order of weight: this actor is the only writer, so
    ///   there is no change it could miss; and `Notification` is not `Sendable`, so bridging that
    ///   sequence across isolation would cost more ceremony than the thing it replaces.
    func productsStream() -> AsyncStream<[Product]> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<[Product]>.makeStream()

        subscribers[id] = continuation
        continuation.yield(currentProducts())

        continuation.onTermination = { [weak self] _ in
            // The view went away. Drop the continuation, or the store leaks one per screen.
            Task { await self?.removeSubscriber(id) }
        }

        return stream
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    /// How many live readers the store is feeding. Exists so a test can prove that a screen going
    /// away actually releases its continuation, instead of trusting that it does.
    var subscriberCount: Int { subscribers.count }

    private func broadcast() {
        let products = currentProducts()
        for continuation in subscribers.values {
            continuation.yield(products)
        }
    }

    // MARK: - Reads

    func currentProducts() -> [Product] {
        let descriptor = FetchDescriptor<ProductEntity>(sortBy: [SortDescriptor(\.position)])
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        return entities.map(ProductMapper.domain(from:))
    }

    func product(id: Int) -> Product? {
        var descriptor = FetchDescriptor<ProductEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first.map(ProductMapper.domain(from:))
    }

    /// The offline half of search: whatever has already been downloaded.
    ///
    /// `brand` is a non-optional `String` precisely so this predicate does not need a `??` inside it
    /// (ADR §32).
    func search(query: String) -> [Product] {
        let descriptor = FetchDescriptor<ProductEntity>(
            predicate: #Predicate {
                $0.title.localizedStandardContains(query) || $0.brand.localizedStandardContains(query)
            },
            sortBy: [SortDescriptor(\.position)]
        )
        let entities = (try? modelContext.fetch(descriptor)) ?? []
        return entities.map(ProductMapper.domain(from:))
    }

    func pageCursor() -> PageCursor? {
        let descriptor = FetchDescriptor<CatalogRemoteKey>()
        guard let key = (try? modelContext.fetch(descriptor))?.first else { return nil }
        return PageCursor(nextSkip: key.nextSkip, total: key.total, lastRefreshAt: key.lastRefreshAt)
    }

    // MARK: - Writes

    /// A full refresh: replace everything with the first page.
    ///
    /// - Important: the delete happens **here**, after the response arrived, and in the same save as
    ///   the insert. Deleting before the request would leave the table empty whenever a refresh
    ///   fails offline — which is exactly the scenario the brief tests (ADR §11).
    func replaceFirstPage(_ dtos: [ProductDTO], total: Int, now: Date = .now) throws {
        try modelContext.delete(model: ProductEntity.self)

        for (index, dto) in dtos.enumerated() {
            modelContext.insert(ProductMapper.entity(from: dto, position: index, cachedAt: now))
        }

        try updateCursor(nextSkip: dtos.count, total: total, refreshedAt: now)
        try modelContext.save()
        broadcast()
    }

    /// The next page. Nothing is deleted: positions continue from `skip`.
    func appendPage(_ dtos: [ProductDTO], startingAt skip: Int, total: Int, now: Date = .now) throws {
        for (index, dto) in dtos.enumerated() {
            modelContext.insert(ProductMapper.entity(from: dto, position: skip + index, cachedAt: now))
        }

        try updateCursor(nextSkip: skip + dtos.count, total: total, refreshedAt: nil)
        try modelContext.save()
        broadcast()
    }

    /// The second writer (ADR §26): one row, from the detail screen.
    ///
    /// Read and write happen in **this one method**. Splitting them — fetching from outside and
    /// writing back — reopens the race the actor is here to close, and the compiler would not
    /// complain, because each half is fine on its own.
    func updateProduct(from dto: ProductDTO, now: Date = .now) throws {
        // Hoisted: `#Predicate` cannot reach through `dto.id`, it only captures plain values.
        let id = dto.id
        var descriptor = FetchDescriptor<ProductEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let existing = (try? modelContext.fetch(descriptor))?.first else { return }

        // The existing position is preserved: it belongs to the page that fetched the row, and
        // overwriting it with anything else reorders the grid.
        let fresh = ProductMapper.entity(from: dto, position: existing.position, cachedAt: now)
        guard existing.differs(from: fresh) else { return } // Write only if something actually changed.

        existing.apply(fresh)
        try modelContext.save()
        broadcast()
    }

    private func updateCursor(nextSkip: Int, total: Int, refreshedAt: Date?) throws {
        let descriptor = FetchDescriptor<CatalogRemoteKey>()
        if let key = (try? modelContext.fetch(descriptor))?.first {
            key.nextSkip = nextSkip
            key.total = total
            if let refreshedAt { key.lastRefreshAt = refreshedAt }
        } else {
            modelContext.insert(
                CatalogRemoteKey(nextSkip: nextSkip, total: total, lastRefreshAt: refreshedAt ?? .now)
            )
        }
    }
}

/// Where pagination stands. A value, so it can leave the actor.
nonisolated struct PageCursor: Equatable, Sendable {
    let nextSkip: Int
    let total: Int
    let lastRefreshAt: Date

    var hasMore: Bool { nextSkip < total }
}
