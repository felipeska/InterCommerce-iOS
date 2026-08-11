//
//  CentsTests.swift
//  Domain tests
//
//  These deliberately import neither SwiftUI nor SwiftData, and the suite is NOT `@MainActor`.
//  That is the evidence that the domain is isolated: guard G7 checks the imports, and if anyone
//  ever pins `Cents` to the main actor, these tests stop compiling.
//

import Testing

@testable import InterCommerce_iOS

struct CentsTests {

    @Test("Addition and subtraction stay exact")
    func additiveArithmetic() {
        #expect(Cents(999) + Cents(1) == Cents(1000))
        #expect(Cents(1000) - Cents(999) == Cents(1))
        #expect(Cents.zero + Cents(500) == Cents(500))
    }

    @Test("Summing lines starts from zero")
    func summing() {
        let lines: [Cents] = [1099, 250, 1]
        #expect(lines.reduce(.zero, +) == Cents(1350))
    }

    @Test("Scaling by a quantity multiplies the amount", arguments: [(999, 3, 2997), (0, 5, 0), (1, 99, 99)])
    func scaling(unit: Int64, quantity: Int, expected: Int64) {
        #expect(Cents(unit) * quantity == Cents(expected))
    }

    @Test("Ordering compares the underlying amount")
    func ordering() {
        #expect(Cents(999) < Cents(1000))
        #expect(!(Cents(1000) < Cents(1000)))
        #expect([Cents(300), Cents(100), Cents(200)].sorted() == [100, 200, 300])
    }

    @Test("The raw value survives the round trip")
    func rawValueRoundTrip() {
        #expect(Cents(rawValue: 1234).rawValue == 1234)
        #expect(Cents(1234) == Cents(rawValue: 1234))
    }

    /// Money is signed on purpose: a discount is subtracted and intermediate results may dip below
    /// zero while a total is being assembled. Clamping is a decision for the use case, not the type.
    @Test("Negative amounts are representable")
    func negativeAmounts() {
        #expect(Cents(100) - Cents(150) == Cents(-50))
    }
}
