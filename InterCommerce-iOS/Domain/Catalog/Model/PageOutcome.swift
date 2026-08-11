//
//  PageOutcome.swift
//  Domain · Catalog · Model
//
//  What happened when the app asked for a page.
//

/// The result of a paging attempt.
///
/// It is not `AppResult<Void>`, and the two extra cases are the reason:
///
///  - `noop` distinguishes "there was nothing to do" — cache still fresh, end of the catalogue
///    reached, a load already running — from "it worked". A screen that cannot tell those apart
///    shows a spinner for a request that never happened.
///  - `cancelled` keeps cancellation out of `AppError`. A `Result` cannot carry it without lying
///    about it being a failure, and a cancelled load is not something to show the user.
nonisolated enum PageOutcome: Equatable, Sendable {
    case loaded
    case noop
    case failed(AppError)
    case cancelled

    var error: AppError? {
        if case let .failed(error) = self { return error }
        return nil
    }
}
