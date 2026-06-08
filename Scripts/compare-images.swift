#!/usr/bin/env swift
//
// compare-images.swift - native pixel comparison for the snapshot harness.
//
// Usage:  swift compare-images.swift <baseline.png> <candidate.png> [diff-out.png]
// Env:    CHANNEL_TOLERANCE (0-255, default 8) - per-channel noise allowance
//         PIXEL_FRACTION    (0-1,   default 0.005) - max share of differing pixels
// Exit:   0 = within tolerance, 1 = differs, 2 = error.
//
// No third-party dependencies: rasterizes both PNGs into a common RGBA8
// bitmap via CoreGraphics and counts pixels whose channels diverge beyond the
// tolerance. On a real difference it writes a diff image (changed pixels in
// red over a dimmed baseline).
//

import CoreGraphics
import Foundation
import ImageIO

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    die("usage: compare-images.swift <baseline.png> <candidate.png> [diff-out.png]")
}
let baselinePath = arguments[1]
let candidatePath = arguments[2]
let diffPath: String? = arguments.count >= 4 ? arguments[3] : nil

let environment = ProcessInfo.processInfo.environment
let channelTolerance = Int(environment["CHANNEL_TOLERANCE"] ?? "") ?? 8
let pixelFraction = Double(environment["PIXEL_FRACTION"] ?? "") ?? 0.005

func loadImage(_ path: String) -> CGImage? {
    guard
        let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        return nil
    }
    return image
}

func rasterize(_ image: CGImage) -> (width: Int, height: Int, pixels: [UInt8])? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return nil }
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let success = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    return success ? (width, height, pixels) : nil
}

func writeDiff(_ pixels: [UInt8], width: Int, height: Int, to path: String) {
    var pixels = pixels
    pixels.withUnsafeMutableBytes { buffer in
        guard
            let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil
            )
        else {
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}

guard let baseImage = loadImage(baselinePath), let candImage = loadImage(candidatePath) else {
    die("could not read images")
}
guard let base = rasterize(baseImage), let cand = rasterize(candImage) else {
    die("could not rasterize images")
}

if base.width != cand.width || base.height != cand.height {
    print("size mismatch baseline=\(base.width)x\(base.height) candidate=\(cand.width)x\(cand.height)")
    exit(1)
}

let total = base.width * base.height
var differing = 0
var diff = diffPath != nil ? [UInt8](repeating: 0, count: total * 4) : []

for index in 0..<total {
    let offset = index * 4
    let dr = abs(Int(base.pixels[offset]) - Int(cand.pixels[offset]))
    let dg = abs(Int(base.pixels[offset + 1]) - Int(cand.pixels[offset + 1]))
    let db = abs(Int(base.pixels[offset + 2]) - Int(cand.pixels[offset + 2]))
    let changed = dr > channelTolerance || dg > channelTolerance || db > channelTolerance
    if changed { differing += 1 }
    if diffPath != nil {
        if changed {
            diff[offset] = 255
            diff[offset + 1] = 0
            diff[offset + 2] = 0
            diff[offset + 3] = 255
        } else {
            let grey = UInt8((Int(base.pixels[offset]) + Int(base.pixels[offset + 1]) + Int(base.pixels[offset + 2])) / 6 + 24)
            diff[offset] = grey
            diff[offset + 1] = grey
            diff[offset + 2] = grey
            diff[offset + 3] = 255
        }
    }
}

let fraction = Double(differing) / Double(total)
let differs = fraction > pixelFraction

if differs, let diffPath {
    writeDiff(diff, width: base.width, height: base.height, to: diffPath)
}

print(String(format: "%.3f%% differ (%d/%d px)", fraction * 100, differing, total))
exit(differs ? 1 : 0)
