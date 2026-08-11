//
//  CartViewModelTests.swift
//  Features tests
//

import Foundation
import Testing

@testable import InterCommerce_iOS

@MainActor
struct CartViewModelTests {

    private func makeViewModel(
        repository: FakeCartRepository,
        taxPolicy: TaxPolicy = .none
    ) -> CartViewModel {
        CartViewModel(
            observeCart: ObserveCart(repository: repository),
            updateQuantity: UpdateQuantity(repository: repository),
            removeFromCart: RemoveFromCart(repository: repository),
            addToCart: AddToCart(repository: repository),
            calculateTotals: CalculateCartTotals(taxPolicy: taxPolicy)
        )
    }

    @Test("Totals are computed from the lines, not accumulated")
    func totalsFollowTheLines() async {
        let viewModel = makeViewModel(repository: FakeCartRepository(lines: CartLine.previewList))

        await viewModel.start()

        #expect(viewModel.lines.count == 2)
        #expect(viewModel.totals.itemCount == 4)
        #expect(viewModel.totals.subtotal == Cents(2_683 + 1_489))
    }

    @Test("An empty cart totals zero")
    func emptyCart() async {
        let viewModel = makeViewModel(repository: FakeCartRepository(lines: []))

        await viewModel.start()

        #expect(viewModel.isEmpty)
        #expect(viewModel.totals == .empty)
    }

    /// Dropping below one removes the line: it is what the stepper's minus means at a quantity of 1,
    /// and a line holding nothing is a state nobody asked for.
    @Test("Decrementing past one removes the line")
    func decrementingPastOneRemoves() async {
        let repository = FakeCartRepository(lines: CartLine.previewList)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        await viewModel.setQuantity(0, for: CartLine.previewList[1])

        #expect(await repository.removed == [3])
        #expect(viewModel.lastRemoved?.productId == 3, "Nothing was offered to undo")
    }

    @Test("Removing offers an undo, and undoing puts the line back with its quantity")
    func undoRestoresTheLine() async {
        let repository = FakeCartRepository(lines: CartLine.previewList)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()
        await viewModel.remove(CartLine.previewList[0])

        await viewModel.undoRemove()

        let restored = await repository.added
        #expect(restored.count == 1)
        #expect(restored.first?.0 == 1)
        #expect(restored.first?.1 == 3, "The quantity was not restored")
        #expect(viewModel.lastRemoved == nil)
    }

    @Test("Tax reaches the totals through the injected policy")
    func taxIsInjected() async {
        let viewModel = makeViewModel(
            repository: FakeCartRepository(lines: [CartLine.previewList[1]]),
            taxPolicy: TaxPolicy(basisPoints: 1_900)
        )

        await viewModel.start()

        #expect(viewModel.totals.subtotal == Cents(1_489))
        #expect(viewModel.totals.tax == Cents(283)) // 1 489 · 19 % = 282.91 -> 283
        #expect(viewModel.totals.total == Cents(1_772))
    }
}

private actor FakeCartRepository: CartRepository {
    private let lines: [CartLine]
    private(set) var removed: [Int] = []
    private(set) var added: [(Int, Int)] = []

    init(lines: [CartLine]) {
        self.lines = lines
    }

    nonisolated func observeLines() -> AsyncStream<[CartLine]> {
        let lines = lines
        return AsyncStream { continuation in
            continuation.yield(lines)
            continuation.finish()
        }
    }

    func add(_ product: Product, quantity: Int) async { added.append((product.id, quantity)) }
    func setQuantity(_ quantity: Int, productId: Int) async {}
    func remove(productId: Int) async { removed.append(productId) }
}
