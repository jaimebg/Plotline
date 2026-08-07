import Foundation
import Testing
@testable import Plotline

/// The brand red is out of the interface, and this keeps it out.
///
/// `plotlinePrimary` (#C40C0C) used to tint glyphs, chips and chart marks all
/// over the app, and read as an error state everywhere it appeared. It was
/// replaced by `plotlineAccent`, which adapts to light and dark. The red now
/// survives in exactly one role: as the value behind `chartLow`, the low end of
/// the episode rating scale, where it is drawn as a mark with white numerals on
/// top of it and never as text.
///
/// Nothing in a rendered SwiftUI tree can assert that, so this suite reads the
/// view sources from disk — the same technique, and for the same reason, as
/// `WatchAttributionSourceTests`.
@Suite("The brand red stays out of the views")
struct AccentColorSourceTests {
    /// Every symbol that resolves to #C40C0C. `chartLow` is deliberately
    /// absent: it is how the rating scale names its low end.
    private static let forbidden = ["plotlinePrimary", "rottenRed", "metacriticRed"]

    private static let scannedDirectories = ["Plotline/Views", "Plotline/App"]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PlotlineTests/
            .deletingLastPathComponent()   // repo root
    }

    private static func swiftFiles() -> [URL] {
        scannedDirectories.flatMap { directory -> [URL] in
            let root = repoRoot.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                return []
            }
            return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        }
    }

    @Test("no view or app file reaches for the brand red")
    func viewsDoNotUseTheBrandRed() throws {
        let files = Self.swiftFiles()

        // A source scan that finds nothing passes for the wrong reason. There
        // are around 49 files under these two directories.
        #expect(
            files.count > 40,
            "the scan found \(files.count) Swift files, which means the paths are wrong rather than that the app shrank"
        )

        var offenders: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for symbol in Self.forbidden where source.contains(symbol) {
                offenders.append("\(file.lastPathComponent) uses \(symbol)")
            }
        }

        #expect(
            offenders.isEmpty,
            "the brand red is meant to survive only as chartLow, the low end of the rating scale: \(offenders.joined(separator: ", "))"
        )
    }
}
