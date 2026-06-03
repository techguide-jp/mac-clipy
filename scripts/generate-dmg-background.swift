#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

enum DMGBackgroundError: Error {
    case bitmapContext
    case cgImage
    case pngData
    case missingOutputPath
}

let width = 660
let height = 400

guard CommandLine.arguments.count >= 2 else {
    throw DMGBackgroundError.missingOutputPath
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: sRGB,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    throw DMGBackgroundError.bitmapContext
}

let canvas = CGRect(x: 0, y: 0, width: width, height: height)
let topColor = CGColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 1.0)
let bottomColor = CGColor(red: 0.10, green: 0.15, blue: 0.20, alpha: 1.0)
let accentColor = CGColor(red: 0.07, green: 0.72, blue: 0.65, alpha: 1.0)
let panelColor = CGColor(red: 0.94, green: 0.97, blue: 0.98, alpha: 0.10)
let lineColor = CGColor(red: 0.72, green: 0.82, blue: 0.88, alpha: 0.18)

context.clear(canvas)
let gradient = CGGradient(
    colorsSpace: sRGB,
    colors: [topColor, bottomColor] as CFArray,
    locations: [0, 1]
)
if let gradient {
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: height),
        end: CGPoint(x: width, y: 0),
        options: []
    )
} else {
    context.setFillColor(topColor)
    context.fill(canvas)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

context.setStrokeColor(lineColor)
context.setLineWidth(1)
for index in 0 ... 7 {
    let offset = CGFloat(index) * 96
    context.move(to: CGPoint(x: offset, y: 0))
    context.addLine(to: CGPoint(x: offset + 220, y: CGFloat(height)))
}

context.strokePath()

context.setFillColor(panelColor)
context.addPath(roundedRect(CGRect(x: 36, y: 36, width: 588, height: 328), radius: 28))
context.fillPath()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 36, weight: .bold),
    .foregroundColor: NSColor.white
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 16, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.72)
]
let hintAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.54)
]

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

("MacClipy" as NSString).draw(
    at: CGPoint(x: 52, y: 316),
    withAttributes: titleAttributes
)
("アプリケーションにドラッグしてインストール" as NSString).draw(
    at: CGPoint(x: 53, y: 288),
    withAttributes: subtitleAttributes
)
("初回起動で警告が出る場合は README の手順を確認してください" as NSString).draw(
    at: CGPoint(x: 53, y: 66),
    withAttributes: hintAttributes
)

NSGraphicsContext.restoreGraphicsState()

let arrowStart = CGPoint(x: 270, y: 206)
let arrowEnd = CGPoint(x: 390, y: 206)
context.setStrokeColor(accentColor)
context.setLineWidth(7)
context.setLineCap(.round)
context.move(to: arrowStart)
context.addLine(to: arrowEnd)
context.strokePath()

let arrowHead = CGMutablePath()
arrowHead.move(to: CGPoint(x: 386, y: 226))
arrowHead.addLine(to: CGPoint(x: 420, y: 206))
arrowHead.addLine(to: CGPoint(x: 386, y: 186))
arrowHead.closeSubpath()
context.setFillColor(accentColor)
context.addPath(arrowHead)
context.fillPath()

context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
context.setLineWidth(1.5)
context.addPath(roundedRect(CGRect(x: 48, y: 48, width: 564, height: 304), radius: 22))
context.strokePath()

guard let cgImage = context.makeImage() else {
    throw DMGBackgroundError.cgImage
}

let representation = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = representation.representation(using: .png, properties: [:]) else {
    throw DMGBackgroundError.pngData
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)

print("Created \(outputURL.path)")
