import SwiftUI

/// Filter options for watchlist
enum WatchlistFilter: String, CaseIterable {
    case all = "All"
    case wantToWatch = "Want to Watch"
    case watched = "Watched"
}

/// Standalone view for displaying the user's watchlist
struct WatchlistView: View {
    @Environment(\.themeManager) private var themeManager
    @Environment(\.watchlistManager) private var watchlistManager
    @State private var filter: WatchlistFilter = .all
    @State private var sort: FavoriteSort = .dateAdded
    @State private var navigationPath = NavigationPath()
    @Namespace private var namespace

    private var filteredItems: [WatchlistItem] {
        var result = watchlistManager.watchlistItems

        switch filter {
        case .all:
            break
        case .wantToWatch:
            result = result.filter { $0.watchStatus == "want_to_watch" }
        case .watched:
            result = result.filter { $0.watchStatus == "watched" }
        }

        switch sort {
        case .dateAdded:
            result.sort { $0.addedAt > $1.addedAt }
        case .rating:
            result.sort { $0.voteAverage > $1.voteAverage }
        case .alphabetical:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        return result
    }

    /// Spring animation for list reorganization
    private var reorderAnimation: Animation {
        .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.1)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                filterPicker
                    .padding(.horizontal)
                    .padding(.top, 8)

                if watchlistManager.watchlistItems.isEmpty {
                    emptyStateView
                } else if filteredItems.isEmpty {
                    filteredEmptyStateView
                } else {
                    watchlistList
                }
            }
            .background(Color.plotlineBackground)
            .navigationTitle("Watchlist")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: MediaItem.self) { item in
                MediaDetailView(media: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: namespace))
            }
            .toolbar {
                if !watchlistManager.watchlistItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
            }
        }
        .environment(\.navigationNamespace, namespace)
        .preferredColorScheme(themeManager.colorScheme)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: Binding(
            get: { filter },
            set: { newFilter in
                withAnimation(reorderAnimation) {
                    filter = newFilter
                }
            }
        )) {
            ForEach(WatchlistFilter.allCases, id: \.self) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
    }

    private var watchlistList: some View {
        List {
            ForEach(filteredItems, id: \.tmdbId) { item in
                NavigationLink(value: item.toMediaItem()) {
                    WatchlistRow(item: item)
                }
                .matchedTransitionSource(id: item.tmdbId, in: namespace)
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation(reorderAnimation) {
                            let newStatus = item.watchStatus == "watched" ? "want_to_watch" : "watched"
                            watchlistManager.updateStatus(tmdbId: item.tmdbId, status: newStatus)
                        }
                    } label: {
                        Label(
                            item.watchStatus == "watched" ? "Want to Watch" : "Watched",
                            systemImage: item.watchStatus == "watched" ? "eye" : "checkmark.circle"
                        )
                    }
                    .tint(Color.plotlinePrimary)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation(reorderAnimation) {
                            watchlistManager.removeFromWatchlist(tmdbId: item.tmdbId)
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(FavoriteSort.allCases, id: \.self) { sortOption in
                Button {
                    withAnimation(reorderAnimation) {
                        sort = sortOption
                    }
                } label: {
                    Label(sortOption.rawValue, systemImage: sortOption.icon)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body)
                .foregroundStyle(Color.plotlinePrimary)
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.plotlinePrimary.opacity(0.15),
                                Color.plotlineGold.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 12) {
                    Image(systemName: "eye.circle")
                        .font(.system(.largeTitle, weight: .regular))
                        .imageScale(.large)
                        .foregroundStyle(Color.plotlinePrimary)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)

                    Text("Your Watchlist is Empty")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Use the eye icon on any movie or series to track what you want to watch")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 32)
            }
            .frame(height: 200)
            .padding(.horizontal)
            Spacer()
        }
    }

    private var filteredEmptyStateView: some View {
        ContentUnavailableView(
            "No \(filter.rawValue) Items",
            systemImage: filter == .watched ? "checkmark.circle" : "eye",
            description: Text("You don't have any items marked as \"\(filter.rawValue.lowercased())\"")
        )
    }
}

/// Row for displaying a watchlist item
struct WatchlistRow: View {
    let item: WatchlistItem

    private var posterURL: URL? {
        guard let path = item.posterPath, !path.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(path)")
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.plotlineCard)
                    .overlay {
                        if posterURL == nil {
                            Image(systemName: item.isTVSeries ? "tv" : "film")
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
            }
            .frame(width: 60, height: 90)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(item.isTVSeries ? "TV Series" : "Movie")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.plotlineCard)
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)

                    Label(item.statusLabel, systemImage: item.watchStatus == "watched" ? "checkmark.circle.fill" : "eye.fill")
                        .font(.caption)
                        .foregroundStyle(item.watchStatus == "watched" ? .green : Color.plotlinePrimary)
                }

                if item.voteAverage > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.imdbYellow)
                        Text(String(format: "%.1f", item.voteAverage))
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
