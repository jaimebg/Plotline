import SwiftUI

/// Reusable card for displaying a single statistic
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.plotlineCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack {
        StatCard(icon: "heart.fill", value: "42", label: "Favorites", color: .plotlinePrimary)
        StatCard(icon: "eye.fill", value: "18", label: "Watched", color: .plotlineSecondaryAccent)
    }
    .padding()
}
