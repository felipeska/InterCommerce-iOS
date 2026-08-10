//
//  AppResult.swift
//  Domain · Common
//
//  Swift already has a result type with a typed failure, so this project does not invent one.
//  (The Kotlin sibling had to: `kotlin.Result` cannot type its error.)
//
//  Repositories return `AppResult` rather than using typed throws because callers *store* the
//  failure as screen state, and a stored `Result` reads better than a `do/catch` that assigns to a
//  property. Inside Data, where errors only propagate, `throws(AppError)` is used instead.
//

/// The outcome of an operation that can fail in a way the app knows how to explain.
typealias AppResult<Success> = Result<Success, AppError>
