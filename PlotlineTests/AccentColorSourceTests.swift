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
/// This scans `Plotline/Views`, `Plotline/App` and `Plotline/Extensions` (minus
/// `Color+Plotline.swift`, which must keep the declarations) for the forbidden
/// identifiers and for the raw hex literal, so a leak cannot slip through
/// either as a renamed alias or as a literal that bypasses the named symbols
/// entirely. It does not scan the rest of the repo, so a leak outside these
/// three directories would not be caught.
///
/// Nothing in a rendered SwiftUI tree can assert that, so this suite reads the
/// view sources from disk — the same technique, and for the same reason, as
/// `WatchAttributionSourceTests`.
@Suite("The brand red stays out of the views")
struct AccentColorSourceTests {
    /// Every symbol that resolves to #C40C0C, plus the literal itself.
    /// `chartLow` is deliberately absent: it is how the rating scale names
    /// its low end.
    private static let forbidden = ["plotlinePrimary", "rottenRed", "metacriticRed", "C40C0C"]

    private static let scannedDirectories = ["Plotline/Views", "Plotline/App", "Plotline/Extensions"]

    /// The one file allowed to hold the declarations above, by filename
    /// rather than by directory exclusion — everything else in
    /// `Plotline/Extensions` is still scanned.
    private static let exemptFilename = "Color+Plotline.swift"

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
            return walker.compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" && $0.lastPathComponent != exemptFilename }
        }
    }

    @Test("no view, app, or extension file reaches for the brand red")
    func viewsDoNotUseTheBrandRed() throws {
        let files = Self.swiftFiles()

        // A source scan that finds nothing passes for the wrong reason. There
        // are around 51 files under these three directories, once
        // Color+Plotline.swift is excluded.
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
