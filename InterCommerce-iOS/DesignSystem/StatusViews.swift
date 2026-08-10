//
//  StatusViews.swift
//  DesignSystem
//
//  Empty, error and offline. They are built on `ContentUnavailableView` rather than hand-rolled:
//  the system one is already accessible, already matches the platform, and gets the Liquid Glass
//  treatment for free (design.md §4.1).
//

import SwiftUI

// MARK: - Error

/// A failure the user can act on. Always offers the retry — an error with no way out is a dead end.
struct AppErrorView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    let retry: () -> Void

    init(
        title: LocalizedStringKey = "Something went wrong",
        message: LocalizedStringKey,
        systemImage: String = "exclamationmark.triangle",
        retry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.retry = retry
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.glassProminent)
        }
    }
}

// MARK: - Empty

/// Nothing to show, and something to do about it. The action is a slot because each screen sends
/// the user somewhere different: the catalogue retries, the cart navigates, search clears.
struct AppEmptyView<Action: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let action: Action

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            action
        }
    }
}

// MARK: - Offline

/// Shown over content that is still perfectly usable, so it is informative, not alarming: it uses
/// the elevated surface and never the discount colour. Being offline is not the user's mistake.
struct OfflineBanner: View {
    var body: some View {
        Label("Offline · showing saved data", systemImage: "wifi.slash")
            .font(.gabarito(.footnote, weight: .medium))
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            // Glass here is deliberate and rationed: it floats over the grid without hiding it
            // (ADR §28). Not interactive, so no `.interactive()`.
            .glassEffect(.regular, in: .capsule)
            .accessibilityElement(children: .combine)
    }
}

#Preview("Error") {
    AppErrorView(message: "We could not reach the catalogue.") {}
}

#Preview("Empty") {
    AppEmptyView(
        title: "Your cart is empty",
        message: "Products you add will show up here.",
        systemImage: "cart"
    ) {
        Button("Browse the catalogue") {}
            .buttonStyle(.glassProminent)
    }
}

#Preview("Offline banner") {
    ZStack {
        Color.background
        OfflineBanner()
    }
}
