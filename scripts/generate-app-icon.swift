#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

enum IconGenerationError: Error {
    case bitmapContext
    case cgImage
    case pngData
    case invalidFourCC(String)
}

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = rootURL.appendingPathComponent("Sources/MacClipy/Resources/AppIcon.icns")
let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("MacClipy-\(UUID().uuidString).iconset")
let shouldKeepIconset = ProcessInfo.processInfo.environment["KEEP_ICONSET"] == "1"

try FileManager.default.createDirectory(
    at: iconsetURL,
    withIntermediateDirectories: true
)
defer {
    if shouldKeepIconset {
        print("Kept \(iconsetURL.path)")
    } else {
        try? FileManager.default.removeItem(at: iconsetURL)
    }
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
let backgroundColor = CGColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 1.0)
let panelColor = CGColor(red: 0.97, green: 0.99, blue: 1.0, alpha: 1.0)
let mutedLineColor = CGColor(red: 0.12, green: 0.17, blue: 0.22, alpha: 1.0)
let accentColor = CGColor(red: 0.07, green: 0.72, blue: 0.65, alpha: 1.0)
let shadowColor = CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.24)

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func scaled(_ value: CGFloat, for pixels: Int) -> CGFloat {
    value * CGFloat(pixels) / 1024.0
}

func drawIcon(pixels: Int) throws -> Data {
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw IconGenerationError.bitmapContext
    }

    let canvas = CGRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels))
    context.clear(canvas)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    context.setFillColor(backgroundColor)
    context.addPath(roundedRect(canvas.insetBy(dx: scaled(42, for: pixels), dy: scaled(42, for: pixels)), radius: scaled(200, for: pixels)))
    context.fillPath()

    let clipboard = CGRect(
        x: scaled(248, for: pixels),
        y: scaled(178, for: pixels),
        width: scaled(528, for: pixels),
        height: scaled(650, for: pixels)
    )
    context.setShadow(offset: CGSize(width: 0, height: -scaled(22, for: pixels)), blur: scaled(48, for: pixels), color: shadowColor)
    context.setFillColor(panelColor)
    context.addPath(roundedRect(clipboard, radius: scaled(62, for: pixels)))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0)

    let clipOuter = CGRect(
        x: scaled(356, for: pixels),
        y: scaled(704, for: pixels),
        width: scaled(312, for: pixels),
        height: scaled(148, for: pixels)
    )
    context.setFillColor(panelColor)
    context.addPath(roundedRect(clipOuter, radius: scaled(56, for: pixels)))
    context.fillPath()

    let clipInner = clipOuter.insetBy(dx: scaled(76, for: pixels), dy: scaled(38, for: pixels))
    context.setFillColor(backgroundColor)
    context.addPath(roundedRect(clipInner, radius: scaled(34, for: pixels)))
    context.fillPath()

    let lines = [
        CGRect(x: 360, y: 588, width: 304, height: 34),
        CGRect(x: 360, y: 492, width: 230, height: 34),
        CGRect(x: 360, y: 396, width: 282, height: 34)
    ]
    context.setFillColor(mutedLineColor)
    for line in lines {
        let rect = CGRect(
            x: scaled(line.origin.x, for: pixels),
            y: scaled(line.origin.y, for: pixels),
            width: scaled(line.width, for: pixels),
            height: scaled(line.height, for: pixels)
        )
        context.addPath(roundedRect(rect, radius: scaled(17, for: pixels)))
        context.fillPath()
    }

    let dots = [
        CGRect(x: 312, y: 586, width: 36, height: 36),
        CGRect(x: 312, y: 490, width: 36, height: 36),
        CGRect(x: 312, y: 394, width: 36, height: 36)
    ]
    context.setFillColor(accentColor)
    for dot in dots {
        let rect = CGRect(
            x: scaled(dot.origin.x, for: pixels),
            y: scaled(dot.origin.y, for: pixels),
            width: scaled(dot.width, for: pixels),
            height: scaled(dot.height, for: pixels)
        )
        context.fillEllipse(in: rect)
    }

    let historyCenter = CGPoint(x: scaled(674, for: pixels), y: scaled(290, for: pixels))
    context.setStrokeColor(accentColor)
    context.setLineWidth(scaled(54, for: pixels))
    context.setLineCap(.round)
    context.addArc(
        center: historyCenter,
        radius: scaled(114, for: pixels),
        startAngle: CGFloat(18) * CGFloat.pi / 180,
        endAngle: CGFloat(302) * CGFloat.pi / 180,
        clockwise: false
    )
    context.strokePath()

    let arrowPath = CGMutablePath()
    arrowPath.move(to: CGPoint(x: scaled(748, for: pixels), y: scaled(394, for: pixels)))
    arrowPath.addLine(to: CGPoint(x: scaled(828, for: pixels), y: scaled(392, for: pixels)))
    arrowPath.addLine(to: CGPoint(x: scaled(792, for: pixels), y: scaled(322, for: pixels)))
    arrowPath.closeSubpath()
    context.setFillColor(accentColor)
    context.addPath(arrowPath)
    context.fillPath()

    guard let cgImage = context.makeImage() else {
        throw IconGenerationError.cgImage
    }
    let representation = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = representation.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.pngData
    }
    return pngData
}

let iconFiles: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

var pngDataByName: [String: Data] = [:]

for iconFile in iconFiles {
    let pngData = try drawIcon(pixels: iconFile.pixels)
    pngDataByName[iconFile.name] = pngData
    try pngData.write(to: iconsetURL.appendingPathComponent(iconFile.name), options: .atomic)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

func fourCC(_ code: String) throws -> Data {
    guard let data = code.data(using: .ascii), data.count == 4 else {
        throw IconGenerationError.invalidFourCC(code)
    }
    return data
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { rawBuffer in
        data.append(contentsOf: rawBuffer)
    }
}

let icnsEntries: [(type: String, fileName: String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")
]

var body = Data()
for entry in icnsEntries {
    guard let pngData = pngDataByName[entry.fileName] else {
        throw IconGenerationError.pngData
    }
    let typeData = try fourCC(entry.type)
    body.append(typeData)
    appendUInt32(UInt32(pngData.count + 8), to: &body)
    body.append(pngData)
}

var icnsData = Data()
let icnsTypeData = try fourCC("icns")
icnsData.append(icnsTypeData)
appendUInt32(UInt32(body.count + 8), to: &icnsData)
icnsData.append(body)
try icnsData.write(to: outputURL, options: .atomic)

print("Created \(outputURL.path)")
