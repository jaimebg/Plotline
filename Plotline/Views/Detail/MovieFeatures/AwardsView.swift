import SwiftUI

/// Awards display section for movies
struct AwardsView: View {
    let awards: AwardsData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Awards")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            // Awards badges
            HStack(spacing: 16) {
                if awards.hasOscarWins {
                    AwardBadge(
                        icon: "trophy.fill",
                        count: awards.oscarWins,
                        label: "Oscar\(awards.oscarWins == 1 ? "" : "s")",
                        color: .plotlineGold
                    )
                } else if awards.hasOscarNominations {
                    AwardBadge(
                        icon: "star.fill",
                        count: awards.oscarNominations,
                        label: "Oscar Nom\(awards.oscarNominations == 1 ? "" : "s")",
                        color: .plotlineGold.opacity(0.7)
                    )
                }

                if awards.otherWins > 0 {
                    AwardBadge(
                        icon: "medal.fill",
                        count: awards.totalWins,
                        label: "Total Wins",
                        color: .plotlineSecondaryAccent
                    )
                }

                if awards.totalNominations > 0 {
                    AwardBadge(
                        icon: "hand.thumbsup.fill",
                        count: awards.totalNominations,
                        label: "Nominations",
                        color: .secondary
                    )
                }

                Spacer()
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Award Badge Component

struct AwardBadge: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            Text("\(count)")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Preview

#Preview("Oscar Winner") {
    AwardsView(awards: .oscarWinnerPreview)
        .padding()
        .background(Color.plotlineBackground)
}

#Preview("Oscar Nominee") {
    AwardsView(awards: .oscarNomineePreview)
        .padding()
        .background(Color.plotlineBackground)
}

#Preview("Regular Awards") {
    AwardsView(awards: .regularPreview)
        .padding()
        .background(Color.plotlineBackground)
}
