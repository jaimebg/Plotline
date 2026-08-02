import SwiftUI

/// Carries pending navigation from Siri App Intents into the view hierarchy.
///
/// `SearchPlotlineIntent` and friends run outside the view tree, so they hand
/// their result over through the shared app group; `PlotlineApp` picks it up on
/// activation and publishes it here for `MainTabView` and `DiscoveryView`.
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
