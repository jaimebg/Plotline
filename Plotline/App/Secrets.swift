import Foundation

/// Helper to read API keys from Secrets.plist
enum Secrets {
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            #if DEBUG
            print("⚠️ Warning: Could not load Secrets.plist")
            #endif
            return [:]
        }
        return plist
    }()

    /// TMDB API Key
    static var tmdbAPIKey: String {
        secrets["TMDB_API_KEY"] as? String ?? ""
    }

    /// OMDb API Key
    static var omdbAPIKey: String {
        secrets["OMDB_API_KEY"] as? String ?? ""
    }
}
