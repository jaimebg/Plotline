import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// strip.swift <out.png> <targetWidth> <frame.png>...
//
// Joins equal-sized frames left to right and scales the join down to
// <targetWidth>. This is the inverse of slice.swift: the marketing frames were
// cut from one continuous sheet, so putting them back in order reproduces that
// sheet exactly — the rating curve and the device scenes that run across frame
// boundaries line back up on their own.
//
// Every frame must match the first one's dimensions. Mixing an iPhone frame
// into an iPad strip, or a stale re-render of a different size, would otherwise
// produce a banner that is the right width and silently misaligned.

func die(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(code)
}

let args = CommandLine.arguments
guard args.count >= 4, let targetWidth = Int(args[2]), targetWidth > 0 else {
    die("usage: strip.swift <out.png> <targetWidth> <frame.png>...", 2)
}

let outURL = URL(fileURLWithPath: args[1])
let framePaths = Array(args.dropFirst(3))

let frames: [CGImage] = framePaths.map { path in
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        die("cannot read \(path) as an image", 1)
    }
    return image
}

let frameWidth = frames[0].width
let frameHeight = frames[0].height
for (path, frame) in zip(framePaths, frames) where frame.width != frameWidth || frame.height != frameHeight {
    die("\(path) is \(frame.width)x\(frame.height); the first frame is \(frameWidth)x\(frameHeight)", 1)
}

let joinedWidth = frameWidth * frames.count
let scale = Double(targetWidth) / Double(joinedWidth)
let outHeight = Int((Double(frameHeight) * scale).rounded())

guard let context = CGContext(
    data: nil,
    width: targetWidth,
    height: outHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    die("cannot create a \(targetWidth)x\(outHeight) context", 1)
}
context.interpolationQuality = .high

// Each frame is drawn into its own slot at the output scale rather than
// composed at full size first: a 10560px-wide intermediate costs ~120 MB and
// buys nothing, because the slot boundaries fall on the same seams either way.
let slotWidth = Double(targetWidth) / Double(frames.count)
for (index, frame) in frames.enumerated() {
    let rect = CGRect(
        x: Double(index) * slotWidth,
        y: 0,
        width: slotWidth,
        height: Double(outHeight)
    )
    context.draw(frame, in: rect)
}

guard let output = context.makeImage() else {
    die("rendering the strip failed", 1)
}
guard let destination = CGImageDestinationCreateWithURL(
    outURL as CFURL, UTType.png.identifier as CFString, 1, nil
) else {
    die("cannot write \(outURL.path)", 1)
}
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else {
    die("finalising \(outURL.path) failed", 1)
}

print("\(outURL.lastPathComponent) \(output.width)x\(output.height) from \(frames.count) frames of \(frameWidth)x\(frameHeight)")
