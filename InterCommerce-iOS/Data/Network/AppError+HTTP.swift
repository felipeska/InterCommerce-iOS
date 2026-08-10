//
//  AppError+HTTP.swift
//  Data · Network
//
//  The single place where a technical failure becomes something the app can explain. Nothing above
//  Data ever sees a `URLError` or a `DecodingError`.
//

import Foundation

extension AppError {

    /// Translates a transport or decoding failure.
    ///
    /// - Important: **Cancellation is never translated.** `CancellationError` and
    ///   `URLError.cancelled` are re-thrown untouched, which is why this is a throwing function and
    ///   not a pure mapping. Turning a cancelled request into a displayable error is how a search
    ///   that the user simply kept typing over ends up showing "no connection".
    static func mapping(_ error: any Error) throws -> AppError {
        if error is CancellationError { throw error }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled:
                throw error
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff:
                return .noConnection
            case .timedOut:
                return .timeout
            default:
                return .unknown
            }
        }

        if error is DecodingError { return .decoding }

        return .unknown
    }

    /// Translates a response the server did answer, but that we cannot use.
    static func mapping(statusCode: Int) -> AppError? {
        switch statusCode {
        case 200...299: nil
        case 404: .notFound
        case 500...599: .server(status: statusCode)
        default: .unknown
        }
    }
}
