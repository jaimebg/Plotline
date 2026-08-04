import SwiftUI

/// An empty state that offers something to look at instead of an apology.
///
/// The suggestions come from the bundled dataset, so this renders with no
/// network and no saved data — which is the difference between a screen that
/// looks broken and one that looks like it has content.
struct SuggestionsEmptyState: View {
    let title: String
    let message: String
    let systemImage: String
    /// Set by the caller so Favorites and Watchlist are told apart on screen.
    let shelfIdentifier: String

    private var suggestions: [MediaItem] {
        // Highest-scoring series first: if we are going to suggest anything
        // unprompted, suggest what the analysis rates best.
        DatasetStore.shared.topRated(limit: 12).map(\.asMediaItem)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(title). \(message)")

                if !suggestions.isEmpty {
                    MediaSection(title: "Analysed by Plotline", items: suggestions)
                        .accessibilityIdentifier(shelfIdentifier)
                }
            }
            .padding(.vertical)
        }
    }
}
