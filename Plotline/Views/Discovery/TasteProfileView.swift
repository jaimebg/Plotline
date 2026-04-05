import SwiftUI

/// Full taste profile screen showing detailed viewing personality analysis
struct TasteProfileView: View {
    let viewModel: TasteProfileViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                tasteTagsSection
                topGenresSection
                favoritePeopleSection
                ratingSweetSpotSection
                preferredEraSection
                moviesVsSeriesSection
            }
            .padding()
        }
        .background(Color.plotlineBackground)
        .navigationTitle("Taste Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Taste Tags

    private var tasteTagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You Are")
                .font(.headline)
                .foregroundStyle(.primary)

            FlowLayout(spacing: 8) {
                ForEach(viewModel.tasteTags) { tag in
                    Text(tag.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.plotlineGold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.plotlineGold.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Top Genres

    private var topGenresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Genres")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                ForEach(Array(viewModel.topGenres.prefix(3).enumerated()), id: \.offset) { _, genre in
                    HStack(spacing: 12) {
                        Text(genre.genre)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.plotlineGold.opacity(0.15))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [.plotlineSecondaryAccent, .plotlineGold],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * genre.percentage, height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(genre.percentage * 100))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Favorite Director & Actor

    @ViewBuilder
    private var favoritePeopleSection: some View {
        if viewModel.favoriteDirector != nil || viewModel.favoriteActor != nil {
            VStack(alignment: .leading, spacing: 12) {
                if let director = viewModel.favoriteDirector {
                    personRow(
                        icon: "megaphone.fill",
                        label: "Favorite Director",
                        name: director.name,
                        count: director.count
                    )
                }

                if viewModel.favoriteDirector != nil && viewModel.favoriteActor != nil {
                    Divider()
                }

                if let actor = viewModel.favoriteActor {
                    personRow(
                        icon: "person.fill",
                        label: "Favorite Actor",
                        name: actor.name,
                        count: actor.count
                    )
                }
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func personRow(icon: String, label: String, name: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.plotlineSecondaryAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text("\(count) titles")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Rating Sweet Spot

    private var ratingSweetSpotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rating Sweet Spot")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                // Scale bar 1-10
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let rangeStart = CGFloat((viewModel.ratingSweetSpot.low - 1) / 9)
                    let rangeEnd = CGFloat((viewModel.ratingSweetSpot.high - 1) / 9)

                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.plotlineGold.opacity(0.1))
                            .frame(height: 12)

                        // Highlighted IQR range
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient.plotlineGradient)
                            .frame(
                                width: max(0, (rangeEnd - rangeStart) * totalWidth),
                                height: 12
                            )
                            .offset(x: rangeStart * totalWidth)
                    }
                }
                .frame(height: 12)

                // Scale labels
                HStack {
                    Text("1")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: "%.1f – %.1f", viewModel.ratingSweetSpot.low, viewModel.ratingSweetSpot.high))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.plotlineGold)

                    Spacer()

                    Text("10")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Preferred Era

    @ViewBuilder
    private var preferredEraSection: some View {
        if let era = viewModel.preferredEra {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundStyle(Color.plotlineSecondaryAccent)

                Text("Your era:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(era)
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Movies vs Series

    private var moviesVsSeriesSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(viewModel.moviesCount)")
                    .font(.system(.largeTitle, weight: .bold))
                    .foregroundStyle(Color.plotlineSecondaryAccent)

                Text("Movies")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60)

            VStack(spacing: 4) {
                Text("\(viewModel.seriesCount)")
                    .font(.system(.largeTitle, weight: .bold))
                    .foregroundStyle(Color.plotlineGold)

                Text("Series")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TasteProfileView(viewModel: .preview)
    }
}
