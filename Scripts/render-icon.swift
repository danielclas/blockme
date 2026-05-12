#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render-icon.swift <output.png>\n", stderr)
    exit(64)
}

let outputPath = CommandLine.arguments[1]
let size = 1024
let canvas = NSRect(x: 0, y: 0, width: size, height: size)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to allocate bitmap.\n", stderr)
    exit(1)
}

bitmap.size = canvas.size

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Failed to create graphics context.\n", stderr)
    exit(1)
}
NSGraphicsContext.current = context

NSColor.clear.setFill()
canvas.fill()

let iconRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 230, yRadius: 230)

let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0.10, alpha: 0.18)
shadow.shadowOffset = NSSize(width: 0, height: -24)
shadow.shadowBlurRadius = 38
shadow.set()

let background = NSGradient(
    starting: NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.92, alpha: 1.0),
    ending: NSColor(calibratedRed: 0.92, green: 0.89, blue: 0.81, alpha: 1.0)
)
background?.draw(in: iconPath, angle: -32)

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

NSColor(calibratedRed: 0.85, green: 0.80, blue: 0.72, alpha: 1.0).setStroke()
iconPath.lineWidth = 2
iconPath.stroke()

let highlightRect = NSRect(x: 162, y: 612, width: 700, height: 264)
let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: 108, yRadius: 108)
let highlight = NSGradient(
    starting: NSColor(calibratedWhite: 1.0, alpha: 0.56),
    ending: NSColor(calibratedRed: 0.97, green: 0.94, blue: 0.87, alpha: 0.18)
)
highlight?.draw(in: highlightPath, angle: -18)

let letter = "b" as NSString
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let font = NSFont.systemFont(ofSize: 620, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedWhite: 0.09, alpha: 1.0),
    .paragraphStyle: paragraph,
]

let textSize = letter.size(withAttributes: attributes)
let textOrigin = NSPoint(
    x: round((canvas.width - textSize.width) / 2),
    y: round((canvas.height - textSize.height) / 2) - 18
)
letter.draw(at: textOrigin, withAttributes: attributes)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG.\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
