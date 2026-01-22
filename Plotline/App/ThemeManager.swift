import SwiftUI

/// App theme options
enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .system: return .secondary
        case .light: return .plotlineGold
        case .dark: return .plotlinePrimary
        }
    }
}

@Observable
final class ThemeManager {
    private static let storageKey = "appTheme"
    static let shared = ThemeManager()

    var currentTheme: AppTheme {
        didSet { persistTheme() }
    }

    var colorScheme: ColorScheme? {
        currentTheme.colorScheme
    }

    private init() {
        self.currentTheme = UserDefaults.standard.string(forKey: Self.storageKey)
            .flatMap(AppTheme.init(rawValue:)) ?? .system
    }

    private func persistTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: Self.storageKey)
    }
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
