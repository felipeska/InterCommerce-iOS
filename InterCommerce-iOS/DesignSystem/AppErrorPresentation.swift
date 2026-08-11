//
//  AppErrorPresentation.swift
//  DesignSystem
//
//  How a failure reads on screen. One table, so no view invents its own wording — and so "no
//  connection" never gets described as something the user did wrong.
//

import SwiftUI

extension AppError {
    var message: LocalizedStringKey {
        switch self {
        case .noConnection: "You appear to be offline."
        case .timeout: "The catalogue is taking too long to answer."
        case .notFound: "This product is no longer available."
        case .server: "The store is having trouble. Please try again shortly."
        case .decoding, .emptyResult, .unknown: "Something went wrong loading this."
        }
    }

    var symbol: String {
        switch self {
        case .noConnection: "wifi.slash"
        case .timeout: "clock.badge.exclamationmark"
        case .notFound: "questionmark.circle"
        default: "exclamationmark.triangle"
        }
    }
}
