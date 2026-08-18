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
            placeOrder: PlaceOrder(repository: repository),
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

@MainActor
struct CartCheckoutTests {

    private func makeViewModel(repository: FakeCartRepository) -> CartViewModel {
        CartViewModel(
            observeCart: ObserveCart(repository: repository),
            updateQuantity: UpdateQuantity(repository: repository),
            removeFromCart: RemoveFromCart(repository: repository),
            addToCart: AddToCart(repository: repository),
            placeOrder: PlaceOrder(repository: repository),
            calculateTotals: CalculateCartTotals()
        )
    }

    @Test("Checking out empties the cart and reports that an order was placed")
    func checkoutClearsTheCart() async {
        let repository = FakeCartRepository(lines: CartLine.previewList)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        let placed = await viewModel.checkout()

        #expect(placed, "The screen would not have navigated to the confirmation")
        #expect(await repository.clearCount == 1)
    }

    /// The confirmation screen is reached only through a real order. Without this the button would
    /// happily confirm an order for nothing.
    @Test("An empty cart cannot be checked out")
    func emptyCartDoesNotCheckOut() async {
        let repository = FakeCartRepository(lines: [])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        let placed = await viewModel.checkout()

        #expect(placed == false)
        #expect(await repository.clearCount == 0, "An empty cart was cleared anyway")
    }

    /// Undo restores a line, and the cart it would restore into no longer exists. Offering it after
    /// an order would put the item back with nothing to pay for it.
    @Test("Placing the order drops the pending undo")
    func checkoutDropsTheUndo() async {
        let repository = FakeCartRepository(lines: CartLine.previewList)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()
        await viewModel.remove(CartLine.previewList[0])
        #expect(viewModel.lastRemoved != nil)

        _ = await viewModel.checkout()

        #expect(viewModel.lastRemoved == nil, "The confirmation screen still offered an undo")
    }

    /// Clearing goes through `clear`, not a loop of removals: the order is one event, and the
    /// removal path is the one that offers an undo.
    @Test("Checkout does not remove the lines one by one")
    func checkoutDoesNotLoopOverRemovals() async {
        let repository = FakeCartRepository(lines: CartLine.previewList)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.start()

        _ = await viewModel.checkout()

        #expect(await repository.removed.isEmpty)
    }
}

private actor FakeCartRepository: CartRepository {
    private let lines: [CartLine]
    private(set) var removed: [Int] = []
    private(set) var added: [(Int, Int)] = []
    private(set) var clearCount = 0

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
    func clear() async { clearCount += 1 }
}
