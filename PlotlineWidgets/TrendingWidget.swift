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
                if let uiImage = WidgetDataManager.loadCachedImage(posterPath: item.posterPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Color.plotlinePrimary, Color.plotlineSecondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: item.mediaType == "tv" ? "tv.fill" : "film.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.3))
                }

                // Bottom overlay with title and rating
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(String(format: "%.1f", item.voteAverage))
                            .font(.caption.bold())
                    }
                    .foregroundStyle(Color.plotlineGold)

                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(radius: 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .widgetURL(URL(string: "plotline://detail/\(item.mediaType)/\(item.tmdbId)"))
        } else {
            emptyView
        }
    }

    private var emptyView: some View {
        VStack(spacing: 4) {
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
            HStack(spacing: 12) {
                if let uiImage = WidgetDataManager.loadCachedImage(posterPath: item.posterPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.plotlinePrimary, Color.plotlineSecondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: item.mediaType == "tv" ? "tv.fill" : "film.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TRENDING")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.plotlineGold)

                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        if let year = item.year {
                            Text(year)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(item.mediaType == "tv" ? "TV Series" : "Movie")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text(String(format: "%.1f", item.voteAverage))
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(Color.plotlineGold)
                }

                Spacer()
            }
            .padding()
            .widgetURL(URL(string: "plotline://detail/\(item.mediaType)/\(item.tmdbId)"))
        } else {
            HStack {
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
}

// MARK: - Widget Definition

struct TrendingWidget: Widget {
    let kind = "TrendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrendingProvider()) { entry in
            TrendingWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Trending")
        .description("See what's trending in movies and TV.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
