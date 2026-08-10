//
//  PersistenceUnavailableView.swift
//  Features · Navigation
//
//  Shown when the local store cannot be opened. Rare, and precisely why it must not be a crash:
//  the app still explains itself, and the user can report something more useful than "it closes".
//

import SwiftUI

struct PersistenceUnavailableView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("InterCommerce could not open its local database, so the catalogue and cart cannot be shown.")
        }
        .accessibilityHint(Text(error.localizedDescription))
    }
}

#Preview {
    PersistenceUnavailableView(error: URLError(.cannotOpenFile))
}
