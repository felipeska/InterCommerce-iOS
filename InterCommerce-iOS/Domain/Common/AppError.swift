//
//  AppError.swift
//  Domain · Common
//
//  The only failure vocabulary the app knows. Data maps every transport, decoding and status
//  failure onto this type, so nothing above Data ever sees a URLError or a DecodingError.
//
//  Cancellation is deliberately absent: `CancellationError` is never mapped, it is re-thrown.
//  Swallowing it breaks structured concurrency silently — `.task(id:)` stops behaving as expected
//  and nobody can tell why.
//

/// A failure the app knows how to explain to a person.
nonisolated enum AppError: Error, Equatable, Sendable {
    /// No route to the host: airplane mode, no signal, captive portal.
    case noConnection
    /// The request outlived its timeout.
    case timeout
    /// HTTP 404. For the detail screen this means "this product no longer exists".
    case notFound
    /// HTTP 5xx. Carries the status so logs can tell 500 from 503.
    case server(status: Int)
    /// The payload did not match the expected shape.
    case decoding
    /// A valid response with nothing usable in it.
    case emptyResult
    /// Anything not worth a case of its own.
    case unknown
}
