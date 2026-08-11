//
//  SearchResults.swift
//  Domain · Catalog · Model
//
//  What a search answered, and where the answer came from.
//

/// Products that matched, plus the provenance the UI needs to be honest about them.
nonisolated struct SearchResults: Equatable, Sendable {
    let products: [Product]
    let source: Source

    /// Where the answer came from.
    ///
    /// `local` carries the failure that caused the fallback. Two reasons: the screen can say *why*
    /// it is showing saved data, and nobody can produce a local result without recording that the
    /// remote attempt failed.
    enum Source: Equatable, Sendable {
        case remote
        case local(reason: AppError)

        var isLocal: Bool {
            if case .local = self { return true }
            return false
        }
    }
}

/// The result of asking to search.
///
/// There is no `failed` case, and that is the point: a failed request is not a failed search, it is
/// a search answered from the cache (research.md §5.3). The only thing that can stop a search
/// without an answer is cancellation — the user typing another character.
nonisolated enum SearchOutcome: Equatable, Sendable {
    case results(SearchResults)
    case cancelled
}
