//
//  CachedAsyncImage.swift
//  DesignSystem
//
//  What `AsyncImage` would be if it kept a disk cache and coalesced requests. The loading itself
//  lives in Data; this view only knows *a function that returns an image*, injected through the
//  environment. That is what keeps `DesignSystem` from naming a `Data` type (architecture.md §2 bis).
//

import SwiftUI
import UIKit

// MARK: - Injection point

/// How this view loads bytes. The app plugs in the real `ImageLoader`; previews and tests plug in
/// something that never touches the network — which is why every `#Preview` in this project renders
/// offline.
extension EnvironmentValues {
    @Entry var loadImage: @Sendable (URL) async throws -> UIImage = { _ in
        throw CancellationError()
    }
}

// MARK: - View

struct CachedAsyncImage<Placeholder: View, Failure: View>: View {
    private let url: URL?
    private let placeholder: Placeholder
    private let failure: Failure

    @Environment(\.loadImage) private var loadImage
    @State private var phase: Phase = .loading

    private enum Phase: Equatable {
        case loading
        case loaded(UIImage)
        case failed
    }

    init(
        url: URL?,
        @ViewBuilder placeholder: () -> Placeholder,
        @ViewBuilder failure: () -> Failure
    ) {
        self.url = url
        self.placeholder = placeholder()
        self.failure = failure()
    }

    var body: some View {
        content
            // `.task(id:)` and not `.onAppear`: when the cell is recycled to another URL the
            // previous load is cancelled for us, and a cancelled load must not paint an error.
            .task(id: url) {
                guard let url else {
                    phase = .failed
                    return
                }
                phase = .loading
                do {
                    phase = .loaded(try await loadImage(url))
                } catch is CancellationError {
                    // The cell moved on. Leave the phase alone.
                } catch {
                    phase = .failed
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            placeholder
        case .loaded(let image):
            Image(uiImage: image)
                .resizable()
                .transition(.opacity)
        case .failed:
            failure
        }
    }
}

// MARK: - Defaults

extension CachedAsyncImage where Placeholder == AnyView, Failure == AnyView {
    /// The product-image treatment used across the app: a tinted surface while loading, and a
    /// symbol when the image will never arrive.
    static func product(url: URL?) -> some View {
        CachedAsyncImage(url: url) {
            AnyView(Rectangle().fill(.surface).shimmering())
        } failure: {
            AnyView(
                ZStack {
                    Rectangle().fill(.surface)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.textSecondary)
                }
            )
        }
    }
}

#Preview("Loaded") {
    CachedAsyncImage(url: URL(string: "https://picsum.photos/200")) {
        Rectangle().fill(.surface)
    } failure: {
        Rectangle().fill(.discount)
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(.rect(cornerRadius: CornerRadius.card))
    .padding(Spacing.l)
    // `UIColor` and not `Color.brandPrimary`: this closure is `@Sendable` and therefore
    // nonisolated, while the generated asset symbols are MainActor-isolated (ADR §29).
    .environment(\.loadImage) { _ in
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }
}

#Preview("Failure") {
    CachedAsyncImage.product(url: URL(string: "https://example.invalid/missing.png"))
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: CornerRadius.card))
        .padding(Spacing.l)
        .environment(\.loadImage) { _ in throw AppError.notFound }
}
