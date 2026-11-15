#!/usr/bin/env swift
//
// flatten-icons.swift - strip the alpha channel from app icon PNGs.
//
// Usage:  swift Scripts/flatten-icons.swift <icon.png>...
// Exit:   0 = every file flattened, 1 = at least one failed.
//
// App Store Connect rejects an app icon with an alpha channel (ITMS-90717).
// A fully opaque icon is redrawn without the channel, so its pixels do not
// change. An icon with any translucent pixel is composited over its dominant
// opaque edge colour (black when the edge has none) and the script says so,
// because that does change what the icon looks like.
//
// No third-party dependencies: CoreGraphics and ImageIO only. The source
// colour space is kept.
//

import CoreGraphics
import Foundation
import ImageIO

struct RGBA: Hashable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

func fail(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func colorSpace(of image: CGImage) -> CGColorSpace {
    guard let space = image.colorSpace, space.model == .rgb else {
        return CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }
    return space
}

/// Straight (non-premultiplied) RGBA8 pixels, read through a premultiplied context.
func readPixels(_ image: CGImage) -> [RGBA]? {
    let width = image.width
    let height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace(of: image),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { return nil }
    return stride(from: 0, to: bytes.count, by: 4).map { offset in
        RGBA(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2], alpha: bytes[offset + 3])
    }
}

func dominantEdgeColor(_ pixels: [RGBA], width: Int, height: Int) -> CGColor {
    var counts: [RGBA: Int] = [:]
    for index in pixels.indices {
        let x = index % width
        let y = index / width
        guard x == 0 || y == 0 || x == width - 1 || y == height - 1 else { continue }
        let pixel = pixels[index]
        guard pixel.alpha == 255 else { continue }
        counts[pixel, default: 0] += 1
    }
    guard let dominant = counts.max(by: { $0.value < $1.value })?.key else {
        return CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }
    return CGColor(
        red: CGFloat(dominant.red) / 255,
        green: CGFloat(dominant.green) / 255,
        blue: CGFloat(dominant.blue) / 255,
        alpha: 1
    )
}

func flatten(_ url: URL) -> Bool {
    guard let image = loadImage(url), let pixels = readPixels(image) else {
        fail("\(url.lastPathComponent): could not read")
        return false
    }
    let width = image.width
    let height = image.height
    let translucent = pixels.filter { $0.alpha < 255 }.count

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace(of: image),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        fail("\(url.lastPathComponent): could not create an opaque context")
        return false
    }
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    if translucent > 0 {
        context.setFillColor(dominantEdgeColor(pixels, width: width, height: height))
        context.fill(bounds)
    }
    context.draw(image, in: bounds)

    guard
        let flattened = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else {
        fail("\(url.lastPathComponent): could not encode")
        return false
    }
    CGImageDestinationAddImage(destination, flattened, nil)
    guard CGImageDestinationFinalize(destination) else {
        fail("\(url.lastPathComponent): could not write")
        return false
    }

    let note = translucent == 0 ? "opaque, channel stripped" : "\(translucent) translucent px composited over edge colour"
    print("\(url.lastPathComponent): \(note)")
    return true
}

let paths = CommandLine.arguments.dropFirst()
guard !paths.isEmpty else {
    fail("usage: flatten-icons.swift <icon.png>...")
    exit(1)
}
let results = paths.map { flatten(URL(fileURLWithPath: $0)) }
exit(results.allSatisfy { $0 } ? 0 : 1)
