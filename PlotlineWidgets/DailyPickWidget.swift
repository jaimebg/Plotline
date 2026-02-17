import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct DailyPickEntry: TimelineEntry {
    let date: Date
    let pick: WidgetDailyPick?
}

// MARK: - Timeline Provider

struct DailyPickProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyPickEntry {
        DailyPickEntry(date: .now, pick: WidgetDailyPick(
            tmdbId: 0, title: "Your Daily Pick", posterPath: nil,
            voteAverage: 8.2, mediaType: "movie", basedOnTitle: "Breaking Bad"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPickEntry) -> Void) {
        completion(DailyPickEntry(date: .now, pick: WidgetDataManager.loadDailyPick()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyPickEntry>) -> Void) {
        let entry = DailyPickEntry(date: .now, pick: WidgetDataManager.loadDailyPick())

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        let midnight = calendar.startOfDay(for: tomorrow)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - Widget View

struct DailyPickMediumView: View {
    let pick: WidgetDailyPick?

    var body: some View {
        if let pick {
            HStack(spacing: 12) {
                if let uiImage = WidgetDataManager.loadCachedImage(posterPath: pick.posterPath) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.plotlineGold.opacity(0.8), Color.plotlineSecondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: pick.mediaType == "tv" ? "tv.fill" : "film.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(width: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR DAILY PICK")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.plotlineGold)

                    Text(pick.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text(String(format: "%.1f", pick.voteAverage))
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(Color.plotlineGold)

                    Spacer()

                    Text("Because you liked \(pick.basedOnTitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding()
            .widgetURL(URL(string: "plotline://detail/\(pick.mediaType)/\(pick.tmdbId)"))
        } else {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.plotlineGold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Pick")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Add favorites to get picks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Widget Definition

struct DailyPickWidget: Widget {
    let kind = "DailyPickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyPickProvider()) { entry in
            DailyPickMediumView(pick: entry.pick)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Pick")
        .description("A personalized recommendation just for you.")
        .supportedFamilies([.systemMedium])
    }
}
