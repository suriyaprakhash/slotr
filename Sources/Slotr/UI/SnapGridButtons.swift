import SwiftUI

public struct SnapGridButtons: View {
    @ObservedObject var windowManager = WindowManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 10) {
            // Main Halves & Maximize
            HStack(spacing: 8) {
                SnapButton(zone: .leftHalf, shortcut: "⌃⌥←")
                SnapButton(zone: .maximize, shortcut: "⌃⌥↑")
                SnapButton(zone: .rightHalf, shortcut: "⌃⌥→")
            }
            
            // Top/Bottom & Center
            HStack(spacing: 8) {
                SnapButton(zone: .topHalf)
                SnapButton(zone: .center, shortcut: "⌃⌥C")
                SnapButton(zone: .bottomHalf)
            }
            
            // Four Quarters
            HStack(spacing: 8) {
                SnapButton(zone: .topLeftQuarter)
                SnapButton(zone: .topRightQuarter)
                SnapButton(zone: .bottomLeftQuarter)
                SnapButton(zone: .bottomRightQuarter)
            }
            
            // Thirds
            HStack(spacing: 8) {
                SnapButton(zone: .leftThird)
                SnapButton(zone: .centerThird)
                SnapButton(zone: .rightThird)
                SnapButton(zone: .leftTwoThirds)
                SnapButton(zone: .rightTwoThirds)
            }
            
            // Undo / Restore Original Size Button
            Button(action: {
                windowManager.restoreOriginalWindowSize()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Restore Original Size & Position")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("⌃⌥↓")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SnapButton: View {
    let zone: SnapZone
    var shortcut: String? = nil
    
    var body: some View {
        Button(action: {
            WindowManager.shared.snapActiveWindow(to: zone)
        }) {
            VStack(spacing: 3) {
                Image(systemName: zone.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(zone.title)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(SnapGridButtonStyle())
        .help(shortcut != nil ? "\(zone.title) (\(shortcut!))" : zone.title)
    }
}

private struct SnapGridButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(configuration.isPressed ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}
