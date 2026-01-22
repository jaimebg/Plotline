import SwiftUI

/// Settings screen with theme options and app information
struct SettingsView: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Appearance Section
                Section {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeOptionRow(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                themeManager.currentTheme = theme
                            }
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Defaults to system appearance when not set.")
                }

                // MARK: - About Section
                Section("About") {
                    InfoRow(label: "Version", value: appVersion)
                    InfoRow(label: "Build", value: buildNumber)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - App Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Theme Option Row

private struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: theme.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(theme.iconColor)
                    .frame(width: 32)

                Text(theme.rawValue)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.plotlinePrimary)
                    .opacity(isSelected ? 1 : 0)
                    .symbolEffect(.bounce, value: isSelected)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(\.themeManager, ThemeManager.shared)
}
