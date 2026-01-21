import SwiftUI

/// App theme options
enum AppTheme: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .light: return .plotlineGold
        case .dark: return .plotlinePrimary
        }
    }
}

/// Observable theme manager for app-wide theme control
@Observable
final class ThemeManager {
    private static let storageKey = "appTheme"
    static let shared = ThemeManager()

    var currentTheme: AppTheme? {
        didSet { persistTheme() }
    }

    /// Returns nil to follow system, or explicit color scheme
    var colorScheme: ColorScheme? {
        currentTheme?.colorScheme
    }

    private init() {
        self.currentTheme = UserDefaults.standard.string(forKey: Self.storageKey)
            .flatMap(AppTheme.init(rawValue:))
    }

    private func persistTheme() {
        if let theme = currentTheme {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
        }
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
