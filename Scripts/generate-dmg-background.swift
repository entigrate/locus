#!/usr/bin/env swift
// Generates Resources/dmg-background.png for the release DMG.
// Usage: swift Scripts/generate-dmg-background.swift

import AppKit

let width = 540
let height = 300

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let g = ctx.cgContext

// Gradient background — dark at top, lighter at bottom
let colors = [
    CGColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0),
    CGColor(red: 0.24, green: 0.24, blue: 0.28, alpha: 1.0),
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
g.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(height)), end: CGPoint(x: 0, y: 0), options: [])

let arrowY = CGFloat(height) - 150.0

// Arrow with shadow
g.setShadow(offset: CGSize(width: 0, height: -1), blur: 6, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.8))
g.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
g.setLineWidth(3.0)
g.setLineCap(.round)
g.move(to: CGPoint(x: 205, y: arrowY))
g.addLine(to: CGPoint(x: 325, y: arrowY))
g.strokePath()

g.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
g.move(to: CGPoint(x: 345, y: arrowY))
g.addLine(to: CGPoint(x: 322, y: arrowY + 12))
g.addLine(to: CGPoint(x: 322, y: arrowY - 12))
g.closePath()
g.fillPath()

g.setShadow(offset: .zero, blur: 0, color: nil)

// Text with dark outline + white fill
let text = "Drag to Applications" as NSString
let font = NSFont.systemFont(ofSize: 14, weight: .bold)
let textY = CGFloat(height) - 150 - 38 - font.ascender

let shadowAttrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black,
    .strokeColor: NSColor.black,
    .strokeWidth: NSNumber(value: -4.0),
]
let textSize = text.size(withAttributes: shadowAttrs)
let textX = (CGFloat(width) - textSize.width) / 2
text.draw(at: NSPoint(x: textX, y: textY), withAttributes: shadowAttrs)

let textAttrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
]
text.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttrs)

NSGraphicsContext.current = nil

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to create PNG")
}

let scriptPath = URL(fileURLWithPath: #file)
let projectDir = scriptPath.deletingLastPathComponent().deletingLastPathComponent()
let outputPath = projectDir.appendingPathComponent("Resources/dmg-background.png")
try! pngData.write(to: outputPath)
print("Created \(outputPath.path)")
