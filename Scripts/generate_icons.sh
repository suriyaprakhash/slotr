#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ICONSET_DIR="/tmp/Slotr.iconset"
CLANG_CACHE="/tmp/clang-cache"
MASTER_PNG="/tmp/slotr_master_1024.png"

mkdir -p "${ICONSET_DIR}" "${CLANG_CACHE}" "${PROJECT_DIR}/Resources"

echo "🎨 Rendering 1024x1024 master icon for Slotr..."

cat << 'EOF' > /tmp/gen_master.swift
import Cocoa
import CoreGraphics

func renderMaster(pixels: Int) -> CGImage? {
    let size = CGFloat(pixels)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: pixels * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { return nil }
    
    // Draw rounded background squircle
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.2237 // Apple continuous corner ratio
    let clipPath = CGPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04),
                          cornerWidth: cornerRadius,
                          cornerHeight: cornerRadius,
                          transform: nil)
    ctx.addPath(clipPath)
    ctx.clip()
    
    // Background Gradient: Deep midnight slate to rich indigo
    let colors = [
        NSColor(red: 0.08, green: 0.12, blue: 0.24, alpha: 1.0).cgColor,
        NSColor(red: 0.03, green: 0.05, blue: 0.12, alpha: 1.0).cgColor
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: size * 0.5, y: size * 0.96),
                               end: CGPoint(x: size * 0.5, y: size * 0.04),
                               options: [])
    }
    
    // Outer border glow
    ctx.addPath(clipPath)
    ctx.setStrokeColor(NSColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 0.45).cgColor)
    ctx.setLineWidth(size * 0.02)
    ctx.strokePath()
    
    // Window Frame illustration
    let winRect = CGRect(x: size * 0.17, y: size * 0.26, width: size * 0.66, height: size * 0.53)
    let winCorner = size * 0.045
    let winPath = CGPath(roundedRect: winRect, cornerWidth: winCorner, cornerHeight: winCorner, transform: nil)
    
    // Window fill
    ctx.addPath(winPath)
    ctx.setFillColor(NSColor(red: 0.11, green: 0.16, blue: 0.30, alpha: 0.90).cgColor)
    ctx.fillPath()
    
    ctx.addPath(winPath)
    ctx.setStrokeColor(NSColor(red: 0.38, green: 0.62, blue: 0.95, alpha: 0.7).cgColor)
    ctx.setLineWidth(size * 0.016)
    ctx.strokePath()
    
    // Title bar traffic lights
    let dotRadius = size * 0.015
    let dotY = winRect.maxY - size * 0.046
    let dotColors = [
        NSColor(red: 0.98, green: 0.36, blue: 0.35, alpha: 1.0),
        NSColor(red: 0.99, green: 0.73, blue: 0.22, alpha: 1.0),
        NSColor(red: 0.24, green: 0.78, blue: 0.35, alpha: 1.0)
    ]
    for (i, col) in dotColors.enumerated() {
        let dotX = winRect.minX + size * 0.045 + CGFloat(i) * size * 0.038
        ctx.setFillColor(col.cgColor)
        ctx.fillEllipse(in: CGRect(x: dotX - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
    }
    
    // Snap Split: Left half snapped in electric cyan
    let contentY = winRect.minY + size * 0.022
    let contentH = winRect.height - size * 0.082
    let halfW = (winRect.width - size * 0.03) / 2
    
    let leftHalf = CGRect(x: winRect.minX + size * 0.012, y: contentY, width: halfW, height: contentH)
    let leftPath = CGPath(roundedRect: leftHalf, cornerWidth: size * 0.025, cornerHeight: size * 0.025, transform: nil)
    ctx.addPath(leftPath)
    ctx.setFillColor(NSColor(red: 0.12, green: 0.58, blue: 0.95, alpha: 0.82).cgColor)
    ctx.fillPath()
    ctx.addPath(leftPath)
    ctx.setStrokeColor(NSColor(red: 0.40, green: 0.85, blue: 1.0, alpha: 0.95).cgColor)
    ctx.setLineWidth(size * 0.012)
    ctx.strokePath()
    
    // Right half (dashed window placeholder)
    let rightHalf = CGRect(x: winRect.minX + halfW + size * 0.018, y: contentY, width: halfW, height: contentH)
    let rightPath = CGPath(roundedRect: rightHalf, cornerWidth: size * 0.025, cornerHeight: size * 0.025, transform: nil)
    ctx.addPath(rightPath)
    ctx.setFillColor(NSColor(red: 0.07, green: 0.10, blue: 0.20, alpha: 0.45).cgColor)
    ctx.fillPath()
    ctx.addPath(rightPath)
    ctx.setStrokeColor(NSColor(red: 0.3, green: 0.45, blue: 0.7, alpha: 0.6).cgColor)
    let dashes: [CGFloat] = [size * 0.02, size * 0.015]
    ctx.setLineDash(phase: 0, lengths: dashes)
    ctx.setLineWidth(size * 0.01)
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    
    // 8 Layout Slots indicator dots at the bottom
    let slotDotRadius = size * 0.019
    let slotY = size * 0.14
    let spacing = size * 0.075
    let startX = (size - (7.0 * spacing)) / 2.0
    for i in 0..<8 {
        let x = startX + CGFloat(i) * spacing
        let dotRect = CGRect(x: x - slotDotRadius, y: slotY - slotDotRadius, width: slotDotRadius * 2, height: slotDotRadius * 2)
        if i == 0 || i == 1 || i == 3 {
            ctx.setFillColor(NSColor(red: 0.18, green: 0.82, blue: 1.0, alpha: 0.95).cgColor)
        } else {
            ctx.setFillColor(NSColor(red: 0.22, green: 0.30, blue: 0.45, alpha: 0.55).cgColor)
        }
        ctx.fillEllipse(in: dotRect)
    }
    
    return ctx.makeImage()
}

guard let cgImage = renderMaster(pixels: 1024) else {
    print("Failed to render master image")
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: cgImage)
if let pngData = rep.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "/tmp/slotr_master_1024.png"))
    print("Master 1024x1024 image created")
}
EOF

swiftc -module-cache-path "${CLANG_CACHE}" /tmp/gen_master.swift -o /tmp/gen_master
/tmp/gen_master

echo "📐 Resizing with sips..."
sips -z 16 16     "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null
sips -z 32 32     "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null
sips -z 64 64     "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null
sips -z 256 256   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null
sips -z 512 512   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "${MASTER_PNG}" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null
cp "${MASTER_PNG}" "${ICONSET_DIR}/icon_512x512@2x.png"

echo "🔨 Packing into AppIcon.icns..."
cat << 'EOF' > /tmp/pack_icns.swift
import Foundation

func buildIcns(from pngMap: [(tag: String, path: String)], outputPath: String) -> Bool {
    var body = Data()
    
    for item in pngMap {
        guard let pngData = try? Data(contentsOf: URL(fileURLWithPath: item.path)) else {
            continue
        }
        guard let tagData = item.tag.data(using: .ascii), tagData.count == 4 else { continue }
        
        var chunkSize = UInt32(8 + pngData.count).bigEndian
        body.append(tagData)
        withUnsafeBytes(of: &chunkSize) { body.append(contentsOf: $0) }
        body.append(pngData)
    }
    
    var header = Data()
    header.append("icns".data(using: .ascii)!)
    var totalSize = UInt32(8 + body.count).bigEndian
    withUnsafeBytes(of: &totalSize) { header.append(contentsOf: $0) }
    header.append(body)
    
    do {
        try header.write(to: URL(fileURLWithPath: outputPath))
        return true
    } catch {
        return false
    }
}

let map: [(String, String)] = [
    ("icp4", "/tmp/Slotr.iconset/icon_16x16.png"),
    ("ic11", "/tmp/Slotr.iconset/icon_16x16@2x.png"),
    ("icp5", "/tmp/Slotr.iconset/icon_32x32.png"),
    ("ic12", "/tmp/Slotr.iconset/icon_32x32@2x.png"),
    ("ic07", "/tmp/Slotr.iconset/icon_128x128.png"),
    ("ic13", "/tmp/Slotr.iconset/icon_128x128@2x.png"),
    ("ic08", "/tmp/Slotr.iconset/icon_256x256.png"),
    ("ic14", "/tmp/Slotr.iconset/icon_256x256@2x.png"),
    ("ic09", "/tmp/Slotr.iconset/icon_512x512.png"),
    ("ic10", "/tmp/Slotr.iconset/icon_512x512@2x.png")
]

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns"
_ = buildIcns(from: map, outputPath: outPath)
EOF

swiftc -module-cache-path "${CLANG_CACHE}" /tmp/pack_icns.swift -o /tmp/pack_icns
/tmp/pack_icns "${PROJECT_DIR}/Resources/AppIcon.icns"

rm -rf "${ICONSET_DIR}" "${MASTER_PNG}" /tmp/gen_master.swift /tmp/gen_master /tmp/pack_icns.swift /tmp/pack_icns
echo "✅ AppIcon.icns successfully generated at ${PROJECT_DIR}/Resources/AppIcon.icns"
