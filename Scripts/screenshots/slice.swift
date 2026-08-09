import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// slice.swift <sheet.png> <frameWidth> <count> <outDir> <startIndex>
//
// Cuts one wide sheet into equal-width frames. The width check is the point:
// a sheet that came back short — a render that ran out of memory, a stylesheet
// that failed to load — would otherwise be cut into frames that are each the
// right size and all wrong.

func die(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(code)
}

let args = CommandLine.arguments
guard args.count == 6,
      let frameWidth = Int(args[2]),
      let count = Int(args[3]),
      let startIndex = Int(args[5]) else {
    die("usage: slice.swift <sheet.png> <frameWidth> <count> <outDir> <startIndex>", 2)
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    die("cannot read \(args[1]) as an image", 1)
}

guard sheet.width == frameWidth * count else {
    die("sheet is \(sheet.width)px wide; \(count) frames of \(frameWidth) need \(frameWidth * count)", 1)
}

let outDir = URL(fileURLWithPath: args[4])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for i in 0..<count {
    let rect = CGRect(x: i * frameWidth, y: 0, width: frameWidth, height: sheet.height)
    guard let frame = sheet.cropping(to: rect) else {
        die("cropping frame \(i + 1) failed", 1)
    }
    let url = outDir.appendingPathComponent(String(format: "%02d.png", startIndex + i))
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        die("cannot write \(url.path)", 1)
    }
    CGImageDestinationAddImage(destination, frame, nil)
    guard CGImageDestinationFinalize(destination) else {
        die("finalising \(url.path) failed", 1)
    }
    print("\(url.lastPathComponent) \(frame.width)x\(frame.height)")
}
