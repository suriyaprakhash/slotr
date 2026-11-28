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
    
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let backgroundRect = rect.insetBy(dx: size * 0.04, dy: size * 0.04)
    let cornerRadius = size * 0.25
    let clipPath = CGPath(roundedRect: backgroundRect,
                          cornerWidth: cornerRadius,
                          cornerHeight: cornerRadius,
                          transform: nil)
    ctx.addPath(clipPath)
    ctx.clip()
    
    // Keep the bundle icon aligned with SlotrLogoMark in the app.
    let colors = [
        NSColor(red: 0.118, green: 0.161, blue: 0.231, alpha: 1.0).cgColor,
        NSColor(red: 0.059, green: 0.090, blue: 0.165, alpha: 1.0).cgColor
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: size * 0.5, y: size * 0.96),
                               end: CGPoint(x: size * 0.5, y: size * 0.04),
                               options: [])
    }
    
    ctx.addPath(clipPath)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.15).cgColor)
    ctx.setLineWidth(size * 0.028)
    ctx.strokePath()
    
    let padding = size * 0.19
    let spacing = size * 0.07
    let corner = size * 0.06
    let contentSize = size - padding * 2
    let columnSize = (contentSize - spacing) / 2
    let leftRect = CGRect(x: padding, y: padding, width: columnSize, height: contentSize)
    let rightX = leftRect.maxX + spacing
    let upperRect = CGRect(x: rightX, y: padding + columnSize + spacing, width: columnSize, height: columnSize)
    let lowerRect = CGRect(x: rightX, y: padding, width: columnSize, height: columnSize)

    let shapes: [(CGRect, NSColor)] = [
        (leftRect, NSColor(red: 0.220, green: 0.741, blue: 0.973, alpha: 1.0)),
        (upperRect, NSColor(red: 0.008, green: 0.518, blue: 0.780, alpha: 0.9)),
        (lowerRect, NSColor(red: 0.490, green: 0.827, blue: 0.988, alpha: 0.75))
    ]
    for (shapeRect, color) in shapes {
        let path = CGPath(roundedRect: shapeRect, cornerWidth: corner, cornerHeight: corner, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
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
