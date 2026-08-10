//
//  CatalogStore.swift
//  Data · Persistence
//
//  The only place allowed to write products. Everything that mutates the catalogue goes through
//  here, so the writes serialise without a single lock: the actor owns the context.
//
//  Two writers exist by design — pages (the paginator) and one row (the detail refresh) — and both
//  live inside this actor. The contract is in ADR §26; the trap it prevents is doing a read here
//  and a write from outside, which reopens the race with the compiler's blessing.
//

import Foundation
import SwiftData

@ModelActor
actor CatalogStore {
    // Operations arrive in Phase 2. The type exists now because the isolation it imposes is what
    // shapes them: nothing above may hold a ModelContext or a @Model.
}
