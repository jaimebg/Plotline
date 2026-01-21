import SwiftUI

/// Franchise carousel showing all films in a collection
struct FranchiseTimelineView: View {
    let movies: [CollectionMovie]
    let collectionName: String
    let currentMovieId: Int
    let isLoading: Bool

    /// Movies sorted by release date
    private var sortedMovies: [CollectionMovie] {
        movies.sorted { ($0.yearInt ?? 0) < ($1.yearInt ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Franchise")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("\(collectionName) · \(movies.count) films")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if isLoading {
                loadingView
            } else if movies.isEmpty {
                emptyView
            } else {
                // Movie carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(sortedMovies) { movie in
                            let isCurrent = movie.id == currentMovieId
                            if isCurrent {
                                FranchiseMovieCard(movie: movie, isCurrent: true)
                            } else {
                                NavigationLink(value: movie.toMediaItem()) {
                                    FranchiseMovieCard(movie: movie, isCurrent: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 100, height: 150)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 80, height: 12)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 50, height: 10)
                    }
                    .shimmering()
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "film.stack")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No franchise data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
}

// MARK: - Franchise Movie Card

struct FranchiseMovieCard: View {
    let movie: CollectionMovie
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Poster with current badge
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: movie.posterURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if case .empty = phase {
                        posterPlaceholder
                            .shimmering()
                    } else {
                        posterPlaceholder
                    }
                }
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isCurrent ? Color.plotlineGold : .clear, lineWidth: 2)
                )
            }

            // Title
            Text(movie.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isCurrent ? Color.plotlineGold : .primary)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)

            // Year and rating
            HStack(spacing: 4) {
                if let year = movie.year {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.imdbYellow)

                    Text(movie.formattedRating)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100)
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.2)
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview("Franchise Carousel") {
    NavigationStack {
        FranchiseTimelineView(
            movies: [
                CollectionMovie(id: 1, title: "Iron Man", overview: nil, releaseDate: "2008-05-02", voteAverage: 7.6, voteCount: 10000, posterPath: nil, backdropPath: nil),
                CollectionMovie(id: 2, title: "Iron Man 2", overview: nil, releaseDate: "2010-05-07", voteAverage: 6.8, voteCount: 9000, posterPath: nil, backdropPath: nil),
                CollectionMovie(id: 3, title: "Iron Man 3", overview: nil, releaseDate: "2013-05-03", voteAverage: 6.9, voteCount: 11000, posterPath: nil, backdropPath: nil)
            ],
            collectionName: "Iron Man Collection",
            currentMovieId: 2,
            isLoading: false
        )
        .padding()
        .background(Color.plotlineBackground)
    }
}

#Preview("Loading") {
    FranchiseTimelineView(
        movies: [],
        collectionName: "Loading...",
        currentMovieId: 0,
        isLoading: true
    )
    .padding()
    .background(Color.plotlineBackground)
}
