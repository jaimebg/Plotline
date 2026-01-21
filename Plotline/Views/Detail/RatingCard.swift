import SwiftUI

/// Individual rating card for IMDb, Rotten Tomatoes, or Metacritic
struct RatingCard: View {
    @Environment(\.openURL) private var openURL

    let rating: RatingSource
    let style: CardStyle
    let imdbId: String?
    let title: String?

    enum CardStyle {
        case standard   // Full card with icon and label
        case compact    // Smaller version for tight spaces
        case minimal    // Just icon and value
    }

    init(rating: RatingSource, style: CardStyle = .standard, imdbId: String? = nil, title: String? = nil) {
        self.rating = rating
        self.style = style
        self.imdbId = imdbId
        self.title = title
    }

    private var ratingURL: URL? {
        rating.ratingType.url(imdbId: imdbId, title: title)
    }

    private func openRatingURL() {
        guard let url = ratingURL else { return }
        openURL(url)
    }

    var body: some View {
        Group {
            switch style {
            case .standard:
                standardCard
            case .compact:
                compactCard
            case .minimal:
                minimalCard
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openRatingURL()
        }
        .opacity(ratingURL != nil ? 1.0 : 0.6)
    }

    // MARK: - Standard Card

    private var standardCard: some View {
        VStack(spacing: 6) {
            // Icon
            ratingIcon
                .font(.title3)

            // Value
            Text(rating.displayValue)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)

            // Source label
            Text(rating.shortName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 70)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Compact Card

    private var compactCard: some View {
        HStack(spacing: 8) {
            ratingIcon
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(rating.displayValue)
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.primary)

                Text(rating.shortName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Minimal Card

    private var minimalCard: some View {
        HStack(spacing: 4) {
            ratingIcon
                .font(.caption)

            Text(rating.displayValue)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Rating Icon

    @ViewBuilder
    private var ratingIcon: some View {
        switch rating.ratingType {
        case .imdb:
            Image(systemName: "star.fill")
                .foregroundStyle(Color.imdbYellow)

        case .rottenTomatoes:
            rottenTomatoesIcon

        case .metacritic:
            metacriticIcon

        case .unknown:
            Image(systemName: "number")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var rottenTomatoesIcon: some View {
        let isFresh = (rating.normalizedValue ?? 0) >= 0.60

        if isFresh {
            Image(systemName: "leaf.fill")
                .foregroundStyle(Color.rottenGreen)
        } else {
            Image(systemName: "leaf")
                .foregroundStyle(Color.rottenRed)
        }
    }

    @ViewBuilder
    private var metacriticIcon: some View {
        let value = rating.normalizedValue ?? 0
        let color: Color = {
            if value >= 0.61 {
                return .metacriticGreen
            } else if value >= 0.40 {
                return .metacriticYellow
            } else {
                return .metacriticRed
            }
        }()

        Text("M")
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(.primary)
            .frame(width: 20, height: 20)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = "\(rating.shortName) rating: \(rating.value)"

        switch rating.ratingType {
        case .imdb:
            if let normalized = rating.normalizedValue {
                let outOf10 = normalized * 10
                label = "IMDb rating: \(String(format: "%.1f", outOf10)) out of 10"
            }
        case .rottenTomatoes:
            let isFresh = (rating.normalizedValue ?? 0) >= 0.60
            label = "Rotten Tomatoes: \(rating.value), \(isFresh ? "Fresh" : "Rotten")"
        case .metacritic:
            if let normalized = rating.normalizedValue {
                let score = Int(normalized * 100)
                let sentiment: String
                if normalized >= 0.61 {
                    sentiment = "Generally Favorable"
                } else if normalized >= 0.40 {
                    sentiment = "Mixed"
                } else {
                    sentiment = "Generally Unfavorable"
                }
                label = "Metacritic score: \(score) out of 100, \(sentiment)"
            }
        case .unknown:
            break
        }

        return label
    }
}

// MARK: - TMDB Rating Card

/// Rating card for TMDB user scores
struct TMDBRatingCard: View {
    let score: Double

    private var formattedScore: String {
        String(format: "%.1f", score)
    }

    var body: some View {
        VStack(spacing: 6) {
            // TMDB icon
            Image(systemName: "person.3.fill")
                .font(.title3)
                .foregroundStyle(Color.plotlineSecondaryAccent)

            // Value
            Text(formattedScore)
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)

            // Source label
            Text("TMDB")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("TMDB user rating: \(formattedScore) out of 10")
    }
}

// MARK: - Preview

#Preview("Standard Cards") {
    HStack(spacing: 12) {
        RatingCard(rating: .imdbPreview, style: .standard)
        RatingCard(rating: .rottenPreview, style: .standard)
        RatingCard(rating: .metacriticPreview, style: .standard)
    }
    .padding()
    .background(Color.plotlineBackground)
}

#Preview("Compact Cards") {
    VStack(spacing: 8) {
        RatingCard(rating: .imdbPreview, style: .compact)
        RatingCard(rating: .rottenPreview, style: .compact)
        RatingCard(rating: .metacriticPreview, style: .compact)
    }
    .padding()
    .background(Color.plotlineBackground)
}

#Preview("Minimal Cards") {
    HStack(spacing: 16) {
        RatingCard(rating: .imdbPreview, style: .minimal)
        RatingCard(rating: .rottenPreview, style: .minimal)
        RatingCard(rating: .metacriticPreview, style: .minimal)
    }
    .padding()
    .background(Color.plotlineBackground)
}
