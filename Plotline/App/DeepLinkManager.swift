import SwiftUI

/// Carries pending navigation from Siri App Intents into the view hierarchy.
///
/// `PlotlineApp.init()` registers the app's single instance as an App Intents
/// dependency, so `SearchPlotlineIntent` writes to it directly. `MainTabView`
/// and `DiscoveryView` consume a pending value both when it changes and when
/// they first appear, because on a cold launch the intent can run before
/// either view exists.
@Observable
final class DeepLinkManager {
    var pendingTab: AppTab?
    var pendingSearchQuery: String?
}

// MARK: - Environment Key

struct DeepLinkManagerKey: EnvironmentKey {
    static let defaultValue = DeepLinkManager()
}

extension EnvironmentValues {
    var deepLinkManager: DeepLinkManager {
        get { self[DeepLinkManagerKey.self] }
        set { self[DeepLinkManagerKey.self] = newValue }
    }
}
