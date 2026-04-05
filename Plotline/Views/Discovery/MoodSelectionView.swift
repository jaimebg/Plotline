import SwiftUI

/// A 2-column grid of selectable mood chips for the recommendation flow
struct MoodSelectionView: View {
    let moods: [MoodFilter]
    let selectedMoods: [MoodFilter]
    let onToggle: (MoodFilter) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(moods) { mood in
                MoodChip(
                    mood: mood,
                    isSelected: selectedMoods.contains(mood),
                    onTap: { onToggle(mood) }
                )
            }
        }
    }
}

// MARK: - Mood Chip

private struct MoodChip: View {
    let mood: MoodFilter
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: mood.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.plotlineGold : .secondary)

                Text(mood.label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.plotlineGold.opacity(0.2) : Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? Color.plotlineGold : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Preview

#Preview {
    MoodSelectionView(
        moods: MoodFilter.all,
        selectedMoods: [MoodFilter.all[0]],
        onToggle: { _ in }
    )
    .padding()
    .background(Color.plotlineBackground)
}
