import Foundation

/// Helper to read API keys from bundle plist or environment variables.
///
/// Priority: Secrets.plist (bundle) → Environment Variables
///
/// For command-line builds (xcodebuild): Add keys to Plotline/Secrets.plist
/// For Xcode builds: Either use plist or set environment variables in scheme
enum Secrets {
    private static let environment = ProcessInfo.processInfo.environment
    private static let plistSecrets: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else {
            return [:]
        }
        return dict
    }()

    static var tmdbAPIKey: String {
        plistSecrets["TMDB_API_KEY"] ?? environment["TMDB_API_KEY"] ?? ""
    }

    static var omdbAPIKey: String {
        plistSecrets["OMDB_API_KEY"] ?? environment["OMDB_API_KEY"] ?? ""
    }
}
