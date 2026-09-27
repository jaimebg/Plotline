import Foundation
import Testing
import UIKit
@testable import Plotline

@Suite("Image cache cost")
struct ImageCacheTests {
    /// The cache holds decoded bitmaps, so that is what its cost counts:
    /// four bytes per pixel at the image's scale.
    @Test("cost is the decoded bitmap size")
    func decodedSize() {
        #expect(ImageCache.cost(width: 100, height: 150, scale: 1) == 100 * 150 * 4)
        #expect(ImageCache.cost(width: 100, height: 150, scale: 3) == 300 * 450 * 4)
    }

    @Test("a degenerate image costs nothing rather than trapping")
    func degenerate() {
        #expect(ImageCache.cost(width: 0, height: 150, scale: 2) == 0)
        #expect(ImageCache.cost(width: .infinity, height: 1, scale: 1) == 0)
    }

    @Test("a real image is measured from its size and scale")
    func realImage() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 20), format: format).image { _ in }
        #expect(ImageCache.cost(of: image) == 20 * 40 * 4)
    }
}
