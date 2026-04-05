import SwiftUI

/// Compact preview card for the Discovery tab showing taste profile highlights
struct TasteProfileCard: View {
    let topGenres: [(genre: String, percentage: Double)]
    let tasteTags: [TasteTag]
    let hasEnoughData: Bool

    var body: some View {
        if hasEnoughData {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.title3)
                        .foregroundStyle(Color.plotlineGold)

                    Text("Your Taste Profile")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                // Taste tag capsules (up to 3)
                HStack(spacing: 8) {
                    ForEach(Array(tasteTags.prefix(3))) { tag in
                        Text(tag.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.plotlineGold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.plotlineGold.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        TasteProfileCard(
            topGenres: [
                (genre: "Sci-Fi", percentage: 0.42),
                (genre: "Drama", percentage: 0.31),
                (genre: "Thriller", percentage: 0.18)
            ],
            tasteTags: [
                TasteTag(id: "cerebral", label: "Cerebral", score: 0.9),
                TasteTag(id: "cinephile", label: "Cinephile", score: 0.85),
                TasteTag(id: "binge_watcher", label: "Binge Watcher", score: 0.7),
                TasteTag(id: "thriller_junkie", label: "Thriller Junkie", score: 0.65)
            ],
            hasEnoughData: true
        )

        TasteProfileCard(
            topGenres: [],
            tasteTags: [],
            hasEnoughData: false
        )
    }
    .padding()
    .background(Color.plotlineBackground)
}
