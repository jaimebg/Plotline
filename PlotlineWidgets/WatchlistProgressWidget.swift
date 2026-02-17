import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct WatchlistProgressEntry: TimelineEntry {
    let date: Date
    let stats: WidgetWatchlistStats?
}

// MARK: - Timeline Provider

struct WatchlistProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchlistProgressEntry {
        WatchlistProgressEntry(date: .now, stats: WidgetWatchlistStats(
            totalCount: 20, watchedCount: 12, wantToWatchCount: 8
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchlistProgressEntry) -> Void) {
        completion(WatchlistProgressEntry(date: .now, stats: WidgetDataManager.loadWatchlistStats()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchlistProgressEntry>) -> Void) {
        let entry = WatchlistProgressEntry(date: .now, stats: WidgetDataManager.loadWatchlistStats())
        // App-driven reloads via WidgetCenter; use .never to conserve budget
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Widget Views

struct WatchlistProgressSmallView: View {
    let stats: WidgetWatchlistStats?

    var body: some View {
        if let stats, stats.totalCount > 0 {
            let progress = Double(stats.watchedCount) / Double(stats.totalCount)

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.plotlineSecondaryAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(progress * 100))%")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Text("watched")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                Text("\(stats.watchedCount) of \(stats.totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(URL(string: "plotline://stats"))
        } else {
            VStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.title2)
                    .foregroundStyle(Color.plotlineSecondaryAccent)
                Text("No watchlist items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WatchlistAccessoryCircularView: View {
    let stats: WidgetWatchlistStats?

    var body: some View {
        if let stats, stats.totalCount > 0 {
            let progress = Double(stats.watchedCount) / Double(stats.totalCount)
            Gauge(value: progress) {
                Image(systemName: "eye.fill")
            } currentValueLabel: {
                Text("\(stats.watchedCount)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetURL(URL(string: "plotline://stats"))
        } else {
            Image(systemName: "eye.fill")
        }
    }
}

struct WatchlistAccessoryRectangularView: View {
    let stats: WidgetWatchlistStats?

    var body: some View {
        if let stats, stats.totalCount > 0 {
            let progress = Double(stats.watchedCount) / Double(stats.totalCount)
            VStack(alignment: .leading, spacing: 2) {
                Text("Watchlist")
                    .font(.headline)
                    .widgetAccentable()
                Text("\(stats.watchedCount) of \(stats.totalCount) watched")
                    .font(.caption)
                Gauge(value: progress) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
            }
            .widgetURL(URL(string: "plotline://stats"))
        } else {
            VStack(alignment: .leading) {
                Text("Watchlist")
                    .font(.headline)
                Text("No items yet")
                    .font(.caption)
            }
        }
    }
}

// MARK: - Widget Definition

struct WatchlistProgressWidget: Widget {
    let kind = "WatchlistProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchlistProgressProvider()) { entry in
            WatchlistProgressEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Watchlist Progress")
        .description("Track your watchlist completion.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct WatchlistProgressEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WatchlistProgressEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            WatchlistAccessoryCircularView(stats: entry.stats)
        case .accessoryRectangular:
            WatchlistAccessoryRectangularView(stats: entry.stats)
        default:
            WatchlistProgressSmallView(stats: entry.stats)
        }
    }
}
