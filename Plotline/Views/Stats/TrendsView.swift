import SwiftUI

/// 2x2 grid hub linking to the four trend explorer sub-features
struct TrendsView: View {
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                trendCard(
                    icon: "waveform.path.ecg",
                    title: "Genre Evolution",
                    subtitle: "Rating trends over 50 years",
                    color: .plotlineGold,
                    destination: GenreEvolutionView()
                )

                trendCard(
                    icon: "calendar.badge.clock",
                    title: "Best Years",
                    subtitle: "Top-rated years for film",
                    color: .plotlineSecondaryAccent,
                    destination: BestYearsView()
                )

                trendCard(
                    icon: "chart.bar.xaxis.ascending",
                    title: "Decade Battle",
                    subtitle: "Compare eras head to head",
                    color: .plotlinePrimary,
                    destination: DecadeBattleView()
                )

                trendCard(
                    icon: "square.stack.3d.up",
                    title: "Franchise Tracker",
                    subtitle: "Track franchise quality",
                    color: .rottenGreen,
                    destination: FranchiseTrackerView()
                )
            }
            .padding()
        }
        .background(Color.plotlineBackground)
        .navigationTitle("Trend Explorer")
    }

    // MARK: - Card Builder

    private func trendCard<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink {
            destination
                .navigationDestination(for: MediaItem.self) { item in
                    MediaDetailView(media: item)
                }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .padding(12)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 8)
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    NavigationStack {
        TrendsView()
    }
}
