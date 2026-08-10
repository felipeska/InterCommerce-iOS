//
//  CartStore.swift
//  Data · Persistence
//
//  The only place allowed to write cart lines. Separate from CatalogStore because they answer to
//  different rules: the catalogue is a cache that gets purged, the cart is user data that never is.
//

import Foundation
import SwiftData

@ModelActor
actor CartStore {
    // Operations arrive in Phase 5.
}
