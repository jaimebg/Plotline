import SwiftUI

/// Horizontal row of rating scorecards
struct ScorecardsView: View {
    let tmdbScore: Double?
    let mediaId: Int
    let isTVSeries: Bool

    init(tmdbScore: Double? = nil, mediaId: Int = 0, isTVSeries: Bool = false) {
        self.tmdbScore = tmdbScore
        self.mediaId = mediaId
        self.isTVSeries = isTVSeries
    }

    private var hasAnyRating: Bool {
        (tmdbScore ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ratings")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            if hasAnyRating, let score = tmdbScore {
                TMDBRatingCard(score: score, mediaId: mediaId, isTVSeries: isTVSeries)
            } else {
                emptyView
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .foregroundStyle(.secondary)

            Text("No ratings available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No ratings available")
    }
}

// MARK: - Preview

#Preview("Scorecards View") {
    VStack(spacing: 24) {
        ScorecardsView(tmdbScore: 8.4, mediaId: 1, isTVSeries: false)

        ScorecardsView()
    }
    .padding()
    .background(Color.plotlineBackground)
}
