//
//  LoadOutcome.swift
//  Domain · Catalog · Model
//
//  What happened when the app asked for something over the network. Used by paging and by the
//  detail refresh — it was called `PageOutcome` until the second caller made the name a lie.
//

/// The result of a load attempt.
///
/// It is not `AppResult<Void>`, and the two extra cases are the reason:
///
///  - `noop` distinguishes "there was nothing to do" — cache still fresh, end of the catalogue
///    reached, a load already running — from "it worked". A screen that cannot tell those apart
///    shows a spinner for a request that never happened.
///  - `cancelled` keeps cancellation out of `AppError`. A `Result` cannot carry it without lying
///    about it being a failure, and a cancelled load is not something to show the user.
nonisolated enum LoadOutcome: Equatable, Sendable {
    case loaded
    case noop
    case failed(AppError)
    case cancelled

    var error: AppError? {
        if case let .failed(error) = self { return error }
        return nil
    }
}

nonisolated extension LoadOutcome {
    /// Classifies a thrown error. Cancellation is not a failure and never becomes one — the reason
    /// this lives here rather than being written at each call site, where one of them would forget.
    init(_ error: any Error) {
        if error is CancellationError {
            self = .cancelled
        } else if let appError = error as? AppError {
            self = .failed(appError)
        } else if let mapped = try? AppError.mapping(error) {
            self = .failed(mapped)
        } else {
            // `AppError.mapping` only throws for cancellation.
            self = .cancelled
        }
    }
}
