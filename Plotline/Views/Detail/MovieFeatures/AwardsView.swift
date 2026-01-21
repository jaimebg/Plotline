import SwiftUI

/// Awards display section for movies with expandable accordion
struct AwardsView: View {
    let awards: AwardsData
    @State private var expandedCategory: AwardCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Awards")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.primary)

            // Awards badges
            HStack(spacing: 12) {
                if awards.hasOscarWins {
                    AwardBadge(
                        category: .oscars,
                        icon: "trophy.fill",
                        count: awards.oscarWins,
                        label: "Oscar\(awards.oscarWins == 1 ? "" : "s")",
                        color: .plotlineGold,
                        isExpanded: expandedCategory == .oscars
                    ) {
                        toggleCategory(.oscars)
                    }
                } else if awards.hasOscarNominations {
                    AwardBadge(
                        category: .oscarNoms,
                        icon: "star.fill",
                        count: awards.oscarNominations,
                        label: "Oscar Noms",
                        color: .plotlineGold.opacity(0.8),
                        isExpanded: expandedCategory == .oscarNoms
                    ) {
                        toggleCategory(.oscarNoms)
                    }
                }

                if awards.totalWins > 0 {
                    AwardBadge(
                        category: .wins,
                        icon: "medal.fill",
                        count: awards.totalWins,
                        label: "Total Wins",
                        color: .plotlineSecondaryAccent,
                        isExpanded: expandedCategory == .wins
                    ) {
                        toggleCategory(.wins)
                    }
                }

                if awards.totalNominations > 0 {
                    AwardBadge(
                        category: .nominations,
                        icon: "hand.thumbsup.fill",
                        count: awards.totalNominations,
                        label: "Nominations",
                        color: .plotlineTertiary,
                        isExpanded: expandedCategory == .nominations
                    ) {
                        toggleCategory(.nominations)
                    }
                }

                Spacer()
            }

            // Expanded accordion content
            if let category = expandedCategory {
                AccordionContent(category: category, awards: awards) {
                    expandedCategory = nil
                }
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .padding()
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: expandedCategory)
    }

    private func toggleCategory(_ category: AwardCategory) {
        if expandedCategory == category {
            expandedCategory = nil
        } else {
            expandedCategory = category
        }
    }
}

// MARK: - Award Category

enum AwardCategory: String, CaseIterable {
    case oscars = "Academy Awards"
    case oscarNoms = "Oscar Nominations"
    case wins = "Total Wins"
    case nominations = "Total Nominations"

    var color: Color {
        switch self {
        case .oscars: return .plotlineGold
        case .oscarNoms: return .plotlineGold.opacity(0.8)
        case .wins: return .plotlineSecondaryAccent
        case .nominations: return .plotlineTertiary
        }
    }

    var icon: String {
        switch self {
        case .oscars: return "trophy.fill"
        case .oscarNoms: return "star.fill"
        case .wins: return "medal.fill"
        case .nominations: return "hand.thumbsup.fill"
        }
    }
}

// MARK: - Award Badge Component

struct AwardBadge: View {
    let category: AwardCategory
    let icon: String
    let count: Int
    let label: String
    let color: Color
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(isExpanded ? 0.3 : 0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            .overlay(
                Circle()
                    .strokeBorder(color, lineWidth: isExpanded ? 2 : 0)
            )

            Text("\(count)")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .scaleEffect(isExpanded ? 1.05 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
}

// MARK: - Accordion Content

struct AccordionContent: View {
    let category: AwardCategory
    let awards: AwardsData
    let onClose: () -> Void

    private var details: [(icon: String, text: String)] {
        switch category {
        case .oscars:
            var items: [(String, String)] = [
                ("trophy.fill", "\(awards.oscarWins) Academy Award\(awards.oscarWins == 1 ? "" : "s") Won")
            ]
            if awards.oscarNominations > awards.oscarWins {
                let additionalNoms = awards.oscarNominations - awards.oscarWins
                items.append(("star", "+\(additionalNoms) additional nomination\(additionalNoms == 1 ? "" : "s")"))
            }
            return items

        case .oscarNoms:
            return [
                ("star.fill", "\(awards.oscarNominations) Oscar Nomination\(awards.oscarNominations == 1 ? "" : "s")")
            ]

        case .wins:
            var items: [(String, String)] = []
            if awards.oscarWins > 0 {
                items.append(("trophy.fill", "\(awards.oscarWins) Oscar\(awards.oscarWins == 1 ? "" : "s")"))
            }
            let otherWins = awards.totalWins - awards.oscarWins
            if otherWins > 0 {
                items.append(("medal.fill", "\(otherWins) other award\(otherWins == 1 ? "" : "s")"))
            }
            return items

        case .nominations:
            var items: [(String, String)] = []
            if awards.oscarNominations > 0 {
                items.append(("star.fill", "\(awards.oscarNominations) Oscar nomination\(awards.oscarNominations == 1 ? "" : "s")"))
            }
            let otherNoms = awards.totalNominations - awards.oscarNominations
            if otherNoms > 0 {
                items.append(("hand.thumbsup", "\(otherNoms) other nomination\(otherNoms == 1 ? "" : "s")"))
            }
            return items
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Circle())
                    .onTapGesture(perform: onClose)
            }
            .foregroundStyle(.primary)
            .padding(.leading, 12)
            .padding(.vertical, 8)
            .background(category.color.opacity(0.2))

            // Detail items
            ForEach(Array(details.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.caption)
                        .foregroundStyle(category.color)
                        .frame(width: 20)

                    Text(item.text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(category.color.opacity(0.08))

                if index < details.count - 1 {
                    Divider()
                        .background(category.color.opacity(0.3))
                }
            }

            // Raw string footer
            if !awards.rawString.isEmpty {
                Text(awards.rawString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.plotlineCard.opacity(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(category.color.opacity(0.3), lineWidth: 1)
        )
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
