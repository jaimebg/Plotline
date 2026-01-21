import SwiftUI

/// Individual rating card for IMDb, Rotten Tomatoes, or Metacritic
struct RatingCard: View {
    let rating: RatingSource
    let style: CardStyle

    enum CardStyle {
        case standard   // Full card with icon and label
        case compact    // Smaller version for tight spaces
        case minimal    // Just icon and value
    }

    init(rating: RatingSource, style: CardStyle = .standard) {
        self.rating = rating
        self.style = style
    }

    var body: some View {
        switch style {
        case .standard:
            standardCard
        case .compact:
            compactCard
        case .minimal:
            minimalCard
        }
    }

    // MARK: - Standard Card

    private var standardCard: some View {
        VStack(spacing: 8) {
            // Icon
            ratingIcon
                .font(.title2)

            // Value
            Text(rating.displayValue)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(.primary)

            // Source label
            Text(rating.shortName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 80)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
