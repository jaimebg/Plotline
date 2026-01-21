import Foundation

/// Helper to read API keys from environment variables.
/// Set these in Xcode: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
enum Secrets {
    private static let environment = ProcessInfo.processInfo.environment

    static var tmdbAPIKey: String { environment["TMDB_API_KEY"] ?? "" }
    static var omdbAPIKey: String { environment["OMDB_API_KEY"] ?? "" }
}
