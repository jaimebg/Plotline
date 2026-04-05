import SwiftUI

/// Personalized smart lists: "Because you liked", "Directors you should know", "Top in your genres"
struct SmartListsView: View {
    @Environment(\.navigationNamespace) private var namespace

    let viewModel: SmartListsViewModel

    var body: some View {
        if viewModel.hasEnoughData {
            VStack(alignment: .leading, spacing: 24) {
                becauseYouLikedSection
                directorsSection
                topGenresSection
            }
        }
    }

    // MARK: - Because You Liked

    @ViewBuilder
    private var becauseYouLikedSection: some View {
        if viewModel.isLoadingBecause {
            shimmerSection(title: "Because you liked...")
        } else if !viewModel.becauseYouLiked.isEmpty {
            MediaSection(
                title: "Because you liked \(viewModel.becauseYouLikedTitle)",
                items: viewModel.becauseYouLiked
            )
        }
    }

    // MARK: - Directors You Should Know

    @ViewBuilder
    private var directorsSection: some View {
        if viewModel.isLoadingDirectors {
            shimmerSection(title: "Directors you should know")
        } else if !viewModel.directorsToKnow.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Directors you should know")
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(viewModel.directorsToKnow, id: \.item.id) { entry in
                            NavigationLink(value: entry.item) {
                                directorCard(entry: entry)
                            }
                            .if(namespace != nil) { view in
                                view.matchedTransitionSource(id: entry.item.id, in: namespace!)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Directors you should know section")
        }
    }

    private func directorCard(entry: (item: MediaItem, directorName: String, fromTitle: String)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Poster
            AsyncImage(url: entry.item.posterURL) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.plotlineCard)
                        .shimmering()

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 210)
                        .clipped()

                case .failure:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.plotlineCard)
                        .overlay {
                            Image(systemName: "film")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }

                @unknown default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.plotlineCard)
                }
            }
            .frame(width: 140, height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Title
            Text(entry.item.displayTitle)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Director subtitle
            Text("Dir. \(entry.directorName)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }

    // MARK: - Top in Your Genres

    @ViewBuilder
    private var topGenresSection: some View {
        if viewModel.isLoadingTopGenres {
            shimmerSection(title: "Top in your genres")
        } else if !viewModel.topInYourGenres.isEmpty {
            MediaSection(
                title: "Top in your genres",
                items: viewModel.topInYourGenres
            )
        }
    }

    // MARK: - Shimmer Placeholder

    private func shimmerSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.plotlineCard)
                            .frame(width: 140, height: 210)
                            .shimmering()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
