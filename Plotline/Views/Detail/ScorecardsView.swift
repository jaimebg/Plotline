import SwiftUI

/// Horizontal row of rating scorecards
struct ScorecardsView: View {
    let ratings: [RatingSource]
    let isLoading: Bool
    let error: String?

    init(ratings: [RatingSource], isLoading: Bool = false, error: String? = nil) {
        self.ratings = ratings
        self.isLoading = isLoading
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Ratings")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)

            // Content
            if isLoading {
                loadingView
            } else if let error = error, ratings.isEmpty {
                errorView(message: error)
            } else if ratings.isEmpty {
                emptyView
            } else {
                ratingsRow
            }
        }
    }

    // MARK: - Ratings Row

    private var ratingsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ratings) { rating in
                    RatingCard(rating: rating, style: .standard)
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.plotlineCard)
                    .frame(width: 100, height: 100)
                    .shimmering()
            }
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)

            Text("Could not load ratings")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    }
}

// MARK: - Compact Scorecards (for inline use)

struct CompactScorecardsView: View {
    let ratings: [RatingSource]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ratings) { rating in
                RatingCard(rating: rating, style: .minimal)
            }
        }
    }
}

// MARK: - Single Rating Display

struct SingleRatingView: View {
    let rating: RatingSource
    let showLabel: Bool

    init(rating: RatingSource, showLabel: Bool = true) {
        self.rating = rating
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: 6) {
            icon
                .font(.caption)

            Text(rating.displayValue)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(.white)

            if showLabel {
                Text(rating.shortName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch rating.ratingType {
        case .imdb:
            Image(systemName: "star.fill")
                .foregroundStyle(Color.imdbYellow)
        case .rottenTomatoes:
            Image(systemName: "leaf.fill")
                .foregroundStyle(rating.normalizedValue ?? 0 >= 0.60 ? Color.rottenGreen : Color.rottenRed)
        case .metacritic:
            Text("M")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(metacriticColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .unknown:
            Image(systemName: "number")
                .foregroundStyle(.secondary)
        }
    }

    private var metacriticColor: Color {
        let value = rating.normalizedValue ?? 0
        if value >= 0.61 {
            return .metacriticGreen
        } else if value >= 0.40 {
            return .metacriticYellow
        } else {
            return .metacriticRed
        }
    }
}

// MARK: - Preview

#Preview("Scorecards View") {
    VStack(spacing: 24) {
        ScorecardsView(ratings: RatingSource.previewRatings)

        ScorecardsView(ratings: [], isLoading: true)

        ScorecardsView(ratings: [], error: "Network error")

        ScorecardsView(ratings: [])
    }
    .padding()
    .background(Color.plotlineBackground)
}

#Preview("Compact Scorecards") {
    CompactScorecardsView(ratings: RatingSource.previewRatings)
        .padding()
        .background(Color.plotlineBackground)
}
