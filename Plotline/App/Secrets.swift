import Foundation

/// Helper to read API keys from environment variables or a bundled plist.
///
/// Priority: Environment Variables → Secrets.plist (bundle)
///
/// The plist is a default compiled into the build; an environment variable is
/// a deliberate act by whoever launched the process, so it wins. That order is
/// also what lets the cold-start UI test starve the app of TMDB by launching
/// it with `TMDB_API_KEY=""`, without a single line of test-only code inside
/// the binary that ships.
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

    /// Pure so the order can be asserted without a bundle or a process
    /// environment to stand in the way.
    ///
    /// An empty environment value counts as **set**: `TMDB_API_KEY=""` means
    /// "no key", not "fall through to the plist".
    static func resolve(
        _ key: String,
        environment: [String: String],
        plist: [String: String]
    ) -> String {
        environment[key] ?? plist[key] ?? ""
    }

    static var tmdbAPIKey: String {
        resolve("TMDB_API_KEY", environment: environment, plist: plistSecrets)
    }
}
