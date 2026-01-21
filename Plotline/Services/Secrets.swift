import Foundation

/// Loads API keys from Secrets.plist
enum Secrets {
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            fatalError("Secrets.plist not found. Add it to the project with your API keys.")
        }
        return plist
    }()

    static var tmdbAPIKey: String {
        secrets["TMDB_API_KEY"] as? String ?? ""
    }

    static var omdbAPIKey: String {
        secrets["OMDB_API_KEY"] as? String ?? ""
    }
}
