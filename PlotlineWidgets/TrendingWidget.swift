import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct TrendingEntry: TimelineEntry {
    let date: Date
    let item: WidgetTrendingItem?
}

// MARK: - Timeline Provider

struct TrendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrendingEntry {
        TrendingEntry(date: .now, item: WidgetTrendingItem(
            tmdbId: 0, title: "Trending Title", posterPath: nil,
            voteAverage: 8.5, mediaType: "movie", year: "2026"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (TrendingEntry) -> Void) {
        let items = WidgetDataManager.loadTrending()
        completion(TrendingEntry(date: .now, item: items.first))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrendingEntry>) -> Void) {
        let items = WidgetDataManager.loadTrending()
        var entries: [TrendingEntry] = []
        let now = Date()

        if items.isEmpty {
            entries.append(TrendingEntry(date: now, item: nil))
        } else {
            for (index, item) in items.prefix(5).enumerated() {
                let entryDate = Calendar.current.date(byAdding: .hour, value: index * 2, to: now) ?? now
                entries.append(TrendingEntry(date: entryDate, item: item))
            }
        }

        let refreshDate = Calendar.current.date(byAdding: .hour, value: 10, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }
}

// MARK: - Widget Views

struct TrendingWidgetSmallView: View {
    let entry: TrendingEntry

    var body: some View {
        if let item = entry.item {
            ZStack(alignment: .bottomLeading) {
                // Full-bleed poster image
                posterImage(for: item)

                // Gradient overlay - 3 stops for better readability
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.6), location: 0.65),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content overlay
                VStack(alignment: .leading, spacing: 3) {
                    Spacer()

                    // Media type pill
                    Text(item.mediaType == "tv" ? "TV" : "MOVIE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial.opacity(0.8))
                        .clipShape(Capsule())

                    // Title
                    Text(item.title)
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)

                    // Rating
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text(String(format: "%.1f", item.voteAverage))
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Color.plotlineGold)
                }
                .padding(12)
            }
            .widgetURL(URL(string: "plotline://detail/\(item.mediaType)/\(item.tmdbId)"))
        } else {
            emptyView
        }
    }

    @ViewBuilder
    private func posterImage(for item: WidgetTrendingItem) -> some View {
        if let uiImage = WidgetDataManager.loadCachedImage(posterPath: item.posterPath) {
            Color.clear.overlay(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
            .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.plotlinePrimary, Color.plotlineSecondaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: item.mediaType == "tv" ? "tv.fill" : "film.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color.plotlineGold)
            Text("Open Plotline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TrendingWidgetMediumView: View {
    let entry: TrendingEntry

    var body: some View {
        if let item = entry.item {
            ZStack(alignment: .bottomLeading) {
                // Full-bleed poster image
                posterImage(for: item)

                // Double gradient overlay for cinematic look
                // Bottom gradient for text readability
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.15),
                        .init(color: .black.opacity(0.5), location: 0.5),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Left gradient for extra depth
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.6), location: 0.0),
                        .init(color: .clear, location: 0.6)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // Content overlay
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()

                    // Trending badge
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("TRENDING")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                    }
                    .foregroundStyle(Color.plotlineGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.plotlineGold.opacity(0.15))
                    .clipShape(Capsule())

                    // Title
                    Text(item.title)
                        .font(.system(.title3, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)

                    // Metadata row
                    HStack(spacing: 8) {
                        // Rating
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                            Text(String(format: "%.1f", item.voteAverage))
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(Color.plotlineGold)

                        // Separator
                        Circle()
                            .fill(.white.opacity(0.5))
                            .frame(width: 3, height: 3)

                        // Year
                        if let year = item.year {
                            Text(year)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        // Media type
                        Text(item.mediaType == "tv" ? "TV Series" : "Movie")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(14)
            }
            .widgetURL(URL(string: "plotline://detail/\(item.mediaType)/\(item.tmdbId)"))
        } else {
            // Empty state
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.plotlineGold)
                Text("Open Plotline to see trending titles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func posterImage(for item: WidgetTrendingItem) -> some View {
        if let uiImage = WidgetDataManager.loadCachedImage(posterPath: item.posterPath) {
            Color.clear.overlay(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
            .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.plotlinePrimary, Color.plotlineSecondaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: item.mediaType == "tv" ? "tv.fill" : "film.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }
}

// MARK: - Widget Definition

struct TrendingWidget: Widget {
    let kind = "TrendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrendingProvider()) { entry in
            TrendingWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Trending")
        .description("See what's trending in movies and TV.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(false)
        .contentMarginsDisabled()
    }
}

struct TrendingWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TrendingEntry

    var body: some View {
        switch family {
        case .systemSmall:
            TrendingWidgetSmallView(entry: entry)
        default:
            TrendingWidgetMediumView(entry: entry)
        }
    }
}
