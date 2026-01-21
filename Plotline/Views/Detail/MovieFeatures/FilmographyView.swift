import SwiftUI

/// Director/Actor filmography horizontal scroll view
struct FilmographyView: View {
    @Binding var selectedType: FilmographyType
    let directorName: String?
    let actorName: String?
    let directorFilmography: [PersonCrewCredit]
    let actorFilmography: [PersonCastCredit]
    let isLoading: Bool

    private var currentPersonName: String? {
        selectedType == .director ? directorName : actorName
    }

    private var hasData: Bool {
        selectedType == .director ? !directorFilmography.isEmpty : !actorFilmography.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with picker
            HStack {
                Text("Filmography")
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                // Type picker
                Picker("", selection: $selectedType) {
                    ForEach(FilmographyType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            // Person name subtitle
            if let name = currentPersonName {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Content
            if isLoading {
                filmographyLoadingView
            } else if hasData {
                filmographyScrollView
            } else {
                emptyStateView
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Filmography Scroll View

    @ViewBuilder
    private var filmographyScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                if selectedType == .director {
                    ForEach(directorFilmography) { credit in
                        NavigationLink(value: credit.toMediaItem()) {
                            FilmographyCard(
                                title: credit.title ?? "",
                                year: credit.year,
                                rating: credit.formattedRating,
                                posterURL: credit.posterURL
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ForEach(actorFilmography) { credit in
                        NavigationLink(value: credit.toMediaItem()) {
                            FilmographyCard(
                                title: credit.title ?? "",
                                year: credit.year,
                                rating: credit.formattedRating,
                                posterURL: credit.posterURL
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Loading View

    private var filmographyLoadingView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "film.stack")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No filmography available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
}

// MARK: - Filmography Card Component

struct FilmographyCard: View {
    let title: String
    let year: String?
    let rating: String
    let posterURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: posterURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else if case .empty = phase {
                    posterPlaceholder.shimmering()
                } else {
                    posterPlaceholder
                }
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 4) {
                if let year {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.imdbYellow)

                    Text(rating)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100)
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.plotlineCard
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview("Director Filmography") {
    NavigationStack {
        FilmographyView(
            selectedType: .constant(.director),
            directorName: "Christopher Nolan",
            actorName: "Leonardo DiCaprio",
            directorFilmography: [],
            actorFilmography: [],
            isLoading: false
        )
        .padding()
        .background(Color.plotlineBackground)
    }
}

#Preview("Loading") {
    FilmographyView(
        selectedType: .constant(.director),
        directorName: nil,
        actorName: nil,
        directorFilmography: [],
        actorFilmography: [],
        isLoading: true
    )
    .padding()
    .background(Color.plotlineBackground)
}
