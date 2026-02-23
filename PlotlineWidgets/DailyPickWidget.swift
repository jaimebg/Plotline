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
            ZStack(alignment: .bottomLeading) {
                // Full-bleed poster image
                posterImage(for: pick)

                // Bottom gradient - warm tint for Daily Pick
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.15),
                        .init(color: .black.opacity(0.5), location: 0.5),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Left gradient for depth
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

                    // Daily Pick badge
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                        Text("DAILY PICK")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                    }
                    .foregroundStyle(Color.plotlineGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.plotlineGold.opacity(0.15))
                    .clipShape(Capsule())

                    // Title
                    Text(pick.title)
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
                            Text(String(format: "%.1f", pick.voteAverage))
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(Color.plotlineGold)

                        // Separator
                        Circle()
                            .fill(.white.opacity(0.5))
                            .frame(width: 3, height: 3)

                        // Reason
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9))
                            Text(pick.basedOnTitle)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(14)
            }
            .widgetURL(URL(string: "plotline://detail/\(pick.mediaType)/\(pick.tmdbId)"))
        } else {
            // Empty state
            HStack(spacing: 10) {
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

    @ViewBuilder
    private func posterImage(for pick: WidgetDailyPick) -> some View {
        if let uiImage = WidgetDataManager.loadCachedImage(posterPath: pick.posterPath) {
            Color.clear.overlay(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            )
            .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color.plotlineGold.opacity(0.6), Color.plotlineSecondaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: pick.mediaType == "tv" ? "tv.fill" : "film.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }
}

// MARK: - Widget Definition

struct DailyPickWidget: Widget {
    let kind = "DailyPickWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyPickProvider()) { entry in
            DailyPickMediumView(pick: entry.pick)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Daily Pick")
        .description("A personalized recommendation just for you.")
        .supportedFamilies([.systemMedium])
        .containerBackgroundRemovable(false)
        .contentMarginsDisabled()
    }
}
