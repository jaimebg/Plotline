import SwiftUI

/// Grid of links to the four trend explorer sub-features.
///
/// Rendered only inside `StatsView`, which supplies the scroll view, the
/// padding, the background and the navigation title. This view used to carry
/// its own copy of all four: the padding stacked with the parent's to 64pt,
/// which left too little room for a second column on any iPhone narrower than
/// 402pt, and the navigation title overrode "Stats" on the tab it lives in.
struct TrendsView: View {
    var body: some View {
        LazyVGrid(columns: GridItem.adaptiveColumns(minimumWidth: AdaptiveLayout.minimumColumnWidth), spacing: 16) {
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(subtitle)")
            .accessibilityAddTraits(.isButton)
        }
    }
}

#Preview {
    NavigationStack {
        TrendsView()
    }
}
