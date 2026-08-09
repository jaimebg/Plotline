import CoreGraphics
import Foundation
import ImageIO

// verify.swift size <file.png>            -> "1320x2868"
// verify.swift pixel <file.png> <x> <y>   -> "E8A33D"
//
// Two jobs in one file on purpose: both read a PNG through ImageIO, and the
// release check and the slicer's test each need both.

func die(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(2)
}

func loadImage(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        die("cannot read \(path) as an image")
    }
    return image
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    die("usage: verify.swift size <file.png> | verify.swift pixel <file.png> <x> <y>")
}

switch args[1] {
case "size":
    let image = loadImage(args[2])
    print("\(image.width)x\(image.height)")

case "pixel":
    guard args.count == 5, let x = Int(args[3]), let y = Int(args[4]) else {
        die("usage: verify.swift pixel <file.png> <x> <y>")
    }
    let image = loadImage(args[2])
    guard x >= 0, y >= 0, x < image.width, y < image.height else {
        die("(\(x),\(y)) is outside \(image.width)x\(image.height)")
    }
    // Draw the single pixel into a known 8-bit RGBA context rather than
    // trusting the source's colour space, bit depth or alpha layout.
    var pixel = [UInt8](repeating: 0, count: 4)
    guard let context = CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        die("cannot create a sampling context")
    }
    context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y),
                                   width: image.width, height: image.height))
    print(String(format: "%02X%02X%02X", pixel[0], pixel[1], pixel[2]))

default:
    die("unknown command \(args[1])")
}
