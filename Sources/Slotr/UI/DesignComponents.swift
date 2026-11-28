import SwiftUI
import AppKit

// MARK: - Palette & Tokens

public extension Color {
    static let slotrBlue = Color(red: 0.0, green: 0.478, blue: 1.0) // #007aff
    static let slotrSky = Color(red: 0.220, green: 0.741, blue: 0.973) // #38bdf8
    static let slotrSkyDeep = Color(red: 0.008, green: 0.518, blue: 0.780) // #0284c7
    static let slotrSkyLight = Color(red: 0.490, green: 0.827, blue: 0.988) // #7dd3fc
    
    static func slotrMainBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.110, green: 0.110, blue: 0.125) // #1c1c20
            : Color(red: 0.984, green: 0.984, blue: 0.992) // #fbfbfd
    }
    
    static func slotrCardBg(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.153, green: 0.153, blue: 0.173) // #27272c
            : Color.white
    }
    
    static func slotrSubtleSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.045)
    }
    
    static func slotrBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.09)
            : Color.black.opacity(0.08)
    }
}

// MARK: - Native macOS Vibrancy

public struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    public init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Slotr Vector Logo Mark

public struct SlotrLogoMark: View {
    var size: CGFloat = 36
    
    public init(size: CGFloat = 36) {
        self.size = size
    }
    
    public var body: some View {
        let radius = size * 0.25
        let pad = size * 0.19
        
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.118, green: 0.161, blue: 0.231), // #1e293b
                            Color(red: 0.059, green: 0.090, blue: 0.165)  // #0f172a
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
            
            HStack(spacing: size * 0.07) {
                RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                    .fill(Color.slotrSky)
                
                VStack(spacing: size * 0.07) {
                    RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                        .fill(Color.slotrSkyDeep.opacity(0.9))
                    RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                        .fill(Color.slotrSkyLight.opacity(0.75))
                }
            }
            .padding(pad)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sequoia Abstract Wallpaper Background

public struct SequoiaWallpaperView: View {
    @Environment(\.colorScheme) private var colorScheme
    var variant: Int = 0
    
    public init(variant: Int = 0) {
        self.variant = variant
    }
    
    public var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.059, green: 0.090, blue: 0.165), // #0f172a
                        Color(red: 0.118, green: 0.106, blue: 0.294), // #1e1b4b
                        Color(red: 0.192, green: 0.063, blue: 0.259)  // #311042
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color(red: 0.118, green: 0.227, blue: 0.541).opacity(0.75), .clear],
                    center: UnitPoint(x: 0.2, y: 0.25),
                    startRadius: 2,
                    endRadius: 90
                )
                RadialGradient(
                    colors: [Color(red: 0.345, green: 0.110, blue: 0.529).opacity(0.65), .clear],
                    center: UnitPoint(x: 0.82, y: 0.22),
                    startRadius: 2,
                    endRadius: 95
                )
                RadialGradient(
                    colors: [Color(red: 0.514, green: 0.094, blue: 0.263).opacity(0.6), .clear],
                    center: UnitPoint(x: 0.62, y: 0.85),
                    startRadius: 2,
                    endRadius: 90
                )
            } else {
                let isWarm = (variant % 3 == 1)
                LinearGradient(
                    colors: isWarm
                        ? [
                            Color(red: 0.98, green: 0.54, blue: 0.42),
                            Color(red: 0.92, green: 0.38, blue: 0.56),
                            Color(red: 0.55, green: 0.45, blue: 0.85)
                        ]
                        : [
                            Color(red: 0.212, green: 0.820, blue: 0.863), // #36d1dc
                            Color(red: 0.357, green: 0.525, blue: 0.898), // #5b86e5
                            Color(red: 0.690, green: 0.416, blue: 0.702)  // #b06ab3
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color(red: 1.0, green: 0.604, blue: 0.463).opacity(0.75), .clear],
                    center: UnitPoint(x: 0.16, y: 0.20),
                    startRadius: 2,
                    endRadius: 80
                )
                RadialGradient(
                    colors: [Color(red: 1.0, green: 0.420, blue: 0.616).opacity(0.65), .clear],
                    center: UnitPoint(x: 0.78, y: 0.85),
                    startRadius: 2,
                    endRadius: 85
                )
            }
        }
    }
}

// MARK: - Miniature Layout Preview

public struct MiniLayoutPreview: View {
    let frames: [CGRect]
    let explicitBounds: CGRect?
    let referenceSize: CGSize
    var variant: Int = 0
    var cornerRadius: CGFloat = 7
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(
        frames: [CGRect],
        referenceBounds: CGRect? = nil,
        referenceSize: CGSize? = nil,
        variant: Int = 0,
        cornerRadius: CGFloat = 7
    ) {
        self.frames = frames
        if let referenceBounds, referenceBounds.width > 100, referenceBounds.height > 100 {
            self.explicitBounds = referenceBounds
            self.referenceSize = referenceBounds.size
        } else if let referenceSize, referenceSize.width > 100, referenceSize.height > 100 {
            self.explicitBounds = nil
            self.referenceSize = referenceSize
        } else {
            self.explicitBounds = nil
            let mainSize = NSScreen.screens.first?.frame.size ?? NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)
            self.referenceSize = mainSize
        }
        self.variant = variant
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let bounds = normalizedBoundingBox()
            
            ZStack(alignment: .topLeading) {
                SequoiaWallpaperView(variant: variant)
                
                ForEach(Array(frames.prefix(8).enumerated()), id: \.offset) { idx, rect in
                    let rawX = (rect.minX - bounds.minX) / max(1, bounds.width)
                    let rawY = (rect.minY - bounds.minY) / max(1, bounds.height)
                    let normX = max(0, min(0.88, rawX))
                    let normY = max(0, min(0.86, rawY))
                    let normW = max(0.10, min(1.0 - normX, rect.width / max(1, bounds.width)))
                    let normH = max(0.12, min(1.0 - normY, rect.height / max(1, bounds.height)))
                    
                    let pad: CGFloat = 3
                    let innerW = max(4, w - pad * 2)
                    let innerH = max(4, h - pad * 2)
                    let winW = max(8, normW * innerW - 2)
                    let winH = max(7, normH * innerH - 2)
                    
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(
                            idx == 0
                            ? (colorScheme == .dark ? Color.white.opacity(0.92) : Color.white.opacity(0.95))
                            : (colorScheme == .dark ? Color.white.opacity(0.74) : Color.white.opacity(0.84))
                        )
                        .overlay(
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(idx == 0 ? Color.slotrBlue.opacity(0.80) : Color.black.opacity(0.16))
                                    .frame(height: max(2, min(4, winH * 0.22)))
                                Spacer(minLength: 0)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
                        .frame(width: winW, height: winH)
                        .offset(x: pad + normX * innerW + 1, y: pad + normY * innerH + 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), lineWidth: 1)
        )
    }
    
    private func normalizedBoundingBox() -> CGRect {
        if let explicitBounds {
            return explicitBounds
        }
        guard !frames.isEmpty else {
            return CGRect(origin: .zero, size: referenceSize)
        }
        var minX = frames.map(\.minX).min() ?? 0
        var minY = frames.map(\.minY).min() ?? 0
        var maxX = frames.map(\.maxX).max() ?? referenceSize.width
        var maxY = frames.map(\.maxY).max() ?? referenceSize.height
        
        // Anchor within primary screen size if frames are inside it so relative positions stay intuitive
        if minX >= 0, minY >= 0, maxX <= referenceSize.width + 40, maxY <= referenceSize.height + 40 {
            minX = 0
            minY = 0
            maxX = referenceSize.width
            maxY = referenceSize.height
        }
        return CGRect(
            x: minX,
            y: minY,
            width: max(referenceSize.width * 0.5, maxX - minX),
            height: max(referenceSize.height * 0.5, maxY - minY)
        )
    }
}

// MARK: - Geometric Snap Zone Diagram

public struct SnapZoneDiagram: View {
    let zone: SnapZone
    var width: CGFloat = 24
    var height: CGFloat = 16
    var isActive: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(zone: SnapZone, width: CGFloat = 24, height: CGFloat = 16, isActive: Bool = false) {
        self.zone = zone
        self.width = width
        self.height = height
        self.isActive = isActive
    }
    
    public var body: some View {
        let norm = zone.normalizedPreviewRect
        let inset: CGFloat = 2
        let innerW = max(2, width - inset * 2)
        let innerH = max(2, height - inset * 2)
        
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .stroke(
                            isActive ? Color.slotrBlue : Color.primary.opacity(0.28),
                            lineWidth: 1.2
                        )
                )
            
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isActive ? Color.slotrBlue : Color.primary.opacity(0.72))
                .frame(
                    width: max(3, norm.width * innerW),
                    height: max(3, norm.height * innerH)
                )
                .offset(
                    x: inset + norm.minX * innerW,
                    y: inset + norm.minY * innerH
                )
        }
        .frame(width: width, height: height)
    }
}

// MARK: - macOS Keycap Badge

public struct MacKeycapBadge: View {
    let text: String
    var compact: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    public init(_ text: String, compact: Bool = false) {
        self.text = text
        self.compact = compact
    }
    
    public var body: some View {
        Text(text)
            .font(.system(size: compact ? 9.5 : 11, weight: .medium, design: .rounded))
            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.75))
            .frame(minWidth: compact ? 16 : 22, minHeight: compact ? 16 : 22)
            .padding(.horizontal, compact ? 4 : 6)
            .background(
                RoundedRectangle(cornerRadius: compact ? 4 : 5.5, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 4 : 5.5, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10), lineWidth: 0.75)
            )
    }
}

public struct ShortcutKeySequence: View {
    let keys: [String]
    
    public init(_ keys: [String]) {
        self.keys = keys
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                MacKeycapBadge(key)
            }
        }
    }
}
