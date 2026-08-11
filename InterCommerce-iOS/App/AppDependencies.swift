//
//  AppDependencies.swift
//  App · composition root
//
//  The only place in the app that builds concrete types. Everything above receives use cases and has
//  no idea a network or a database exists (ADR §31).
//

import Foundation
import SwiftData
import UIKit

struct AppDependencies: Sendable {
    let observeCatalog: ObserveCatalog
    let refreshCatalog: RefreshCatalog
    let loadNextPage: LoadNextPage
    let searchProducts: SearchProducts
    let observeProduct: ObserveProduct
    let refreshProduct: RefreshProduct
    let observeCart: ObserveCart
    let addToCart: AddToCart
    let updateQuantity: UpdateQuantity
    let removeFromCart: RemoveFromCart
    let calculateTotals: CalculateCartTotals
    /// Exposed so the summary can label the row. The rate lives in exactly one place (research.md §6).
    let taxPolicy: TaxPolicy
    /// Handed to the design system as a plain function, so no view ever names `ImageLoader`.
    let loadImage: @Sendable (URL) async throws -> UIImage

    // MARK: - Live

    static func live(container: ModelContainer, configuration: AppConfiguration = .fromInfoPlist()) -> AppDependencies {
        let client = HTTPClient(
            baseURL: configuration.baseURL,
            session: makeAPISession(),
            middlewares: [LoggingMiddleware(), HeadersMiddleware()]
        )
        let store = CatalogStore(modelContainer: container)
        let paginator = CatalogPaginator(api: ProductAPI(client: client), store: store)
        let api = ProductAPI(client: client)
        let repository = ProductRepositoryImpl(store: store, paginator: paginator, api: api)
        let cartStore = CartStore(modelContainer: container)
        let cartRepository = CartRepositoryImpl(store: cartStore)
        let imageLoader = ImageLoader()

        return AppDependencies(
            observeCatalog: ObserveCatalog(repository: repository),
            refreshCatalog: RefreshCatalog(repository: repository, ttl: configuration.catalogTTL),
            loadNextPage: LoadNextPage(repository: repository),
            searchProducts: SearchProducts(repository: repository),
            observeProduct: ObserveProduct(repository: repository),
            refreshProduct: RefreshProduct(repository: repository),
            observeCart: ObserveCart(repository: cartRepository),
            addToCart: AddToCart(repository: cartRepository),
            updateQuantity: UpdateQuantity(repository: cartRepository),
            removeFromCart: RemoveFromCart(repository: cartRepository),
            calculateTotals: CalculateCartTotals(taxPolicy: configuration.taxPolicy),
            taxPolicy: configuration.taxPolicy,
            loadImage: { url in try await imageLoader.image(for: url) }
        )
    }

    /// The API session caches nothing: the catalogue's cache is SwiftData, and two caching layers
    /// with different policies produce bugs nobody can reproduce.
    private static func makeAPISession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }
}

/// Values that come from `Info.plist` rather than being hardcoded in the client.
struct AppConfiguration: Sendable {
    let baseURL: URL
    /// How long cached products stay fresh.
    let catalogTTL: Duration
    /// Zero by default, on purpose: the brief names no rate, so the app ships the mechanism rather
    /// than an invented tax figure (research.md §6).
    let taxPolicy: TaxPolicy

    static func fromInfoPlist(
        bundle: Bundle = .main,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> AppConfiguration {
        // A launch argument wins over the plist. This is the hook UI tests use to point the app at a
        // stub server, and the only practical way to exercise "the network is unreachable" on a
        // simulator that shares the Mac's connection:
        //   xcrun simctl launch <device> fcb.intercommerce -ICBaseURL http://127.0.0.1:9
        let plistURL = (bundle.object(forInfoDictionaryKey: "ICBaseURL") as? String).flatMap(URL.init(string:))
        let overrideURL = arguments.firstIndex(of: "-ICBaseURL")
            .flatMap { arguments[safe: $0 + 1] }
            .flatMap(URL.init(string:))

        // A TTL of zero forces a refresh on every launch, which is how a test reaches the "tried and
        // failed" state deterministically instead of waiting half an hour for the cache to age.
        let overrideTTL = arguments.firstIndex(of: "-ICCatalogTTLSeconds")
            .flatMap { arguments[safe: $0 + 1] }
            .flatMap(Int.init)
            .map(Duration.seconds)

        return AppConfiguration(
            // The fallback is the same value the plist holds: a missing key must not take the app
            // down, and there is nothing secret about a public base URL.
            baseURL: overrideURL ?? plistURL ?? URL(string: "https://dummyjson.com")!,
            catalogTTL: overrideTTL ?? RefreshCatalog.defaultTTL,
            taxPolicy: arguments.firstIndex(of: "-ICTaxBasisPoints")
                .flatMap { arguments[safe: $0 + 1] }
                .flatMap(Int.init)
                .map(TaxPolicy.init(basisPoints:)) ?? .none
        )
    }
}

// MARK: - Preview

extension AppDependencies {
    /// A graph with no network and no database.
    ///
    /// It is the default value of the environment key, which means **every `#Preview` in this
    /// project renders offline** — and that is a continuous, build-by-build demonstration that the
    /// UI does not depend on `Data`.
    static let preview = AppDependencies(
        observeCatalog: ObserveCatalog(repository: PreviewProductRepository()),
        refreshCatalog: RefreshCatalog(repository: PreviewProductRepository()),
        loadNextPage: LoadNextPage(repository: PreviewProductRepository()),
        searchProducts: SearchProducts(repository: PreviewProductRepository()),
        observeProduct: ObserveProduct(repository: PreviewProductRepository()),
        refreshProduct: RefreshProduct(repository: PreviewProductRepository()),
        observeCart: ObserveCart(repository: PreviewCartRepository()),
        addToCart: AddToCart(repository: PreviewCartRepository()),
        updateQuantity: UpdateQuantity(repository: PreviewCartRepository()),
        removeFromCart: RemoveFromCart(repository: PreviewCartRepository()),
        calculateTotals: CalculateCartTotals(),
        taxPolicy: .none,
        loadImage: { _ in
            // `UIColor`, not an asset symbol: this closure is nonisolated and the generated colour
            // symbols are MainActor-isolated (ADR §29).
            UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { context in
                UIColor.systemGray5.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
            }
        }
    )
}

private struct PreviewCartRepository: CartRepository {
    func observeLines() -> AsyncStream<[CartLine]> {
        AsyncStream { continuation in
            continuation.yield(CartLine.previewList)
            continuation.finish()
        }
    }

    func add(_ product: Product, quantity: Int) async {}
    func setQuantity(_ quantity: Int, productId: Int) async {}
    func remove(productId: Int) async {}
}

private struct PreviewProductRepository: ProductRepository {
    func observeCatalog() -> AsyncStream<[Product]> {
        AsyncStream { continuation in
            continuation.yield(Product.previewList)
            continuation.finish()
        }
    }

    func refreshCatalogIfStale(ttl: Duration) async -> LoadOutcome { .noop }
    func refreshCatalog() async -> LoadOutcome { .noop }
    func loadNextPage() async -> LoadOutcome { .noop }

    func observeProduct(id: Int) -> AsyncStream<Product?> {
        AsyncStream { continuation in
            continuation.yield(Product.previewList.first { $0.id == id } ?? .preview)
            continuation.finish()
        }
    }

    func refreshProduct(id: Int) async -> LoadOutcome { .noop }
    func search(query: String) async -> SearchOutcome {
        .results(SearchResults(products: Product.previewList, source: .remote))
    }
}

nonisolated private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
