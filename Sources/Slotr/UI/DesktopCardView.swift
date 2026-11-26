import SwiftUI

public struct DesktopCardView: View {
    let desktop: DesktopInfo
    @ObservedObject var desktopManager = DesktopManager.shared
    
    public init(desktop: DesktopInfo) {
        self.desktop = desktop
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Desktop name + Active badge
            HStack(spacing: 5) {
                Image(systemName: "square.on.square.dashed")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text(desktop.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                
                Spacer()
                
                if desktop.isCurrent {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text("Active")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
            }
            
            // App Preview: icons of the apps running on this desktop
            HStack(spacing: 4) {
                if desktop.isEmpty {
                    Text("No apps")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    let apps = desktop.uniqueApps
                    ForEach(apps.prefix(4)) { app in
                        Image(nsImage: desktopManager.icon(for: app))
                            .resizable()
                            .frame(width: 16, height: 16)
                            .cornerRadius(3)
                            .help(app.appName)
                    }
                    
                    if apps.count > 4 {
                        Text("+\(apps.count - 4)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            // Orientation + window count
            HStack(spacing: 4) {
                Image(systemName: desktop.orientation.iconName)
                    .font(.system(size: 9))
                Text(desktop.orientation.label)
                    .font(.system(size: 9, weight: .medium))
                
                Spacer()
                
                if !desktop.isEmpty {
                    Text("\(desktop.windows.count) win")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.secondary)
            
            // Slot It Button
            Button(action: {
                desktopManager.slotIt(desktop)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 10))
                    Text("Slot It")
                        .font(.system(size: 10.5, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(desktop.isEmpty ? Color.primary.opacity(0.25) : Color.blue)
                )
            }
            .buttonStyle(.plain)
            .disabled(desktop.isEmpty)
            .help("Save this desktop's layout into the first empty slot")
        }
        .padding(9)
        .frame(width: 168)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            desktop.isCurrent ? Color.blue.opacity(0.5) : Color.primary.opacity(0.07),
                            lineWidth: desktop.isCurrent ? 1.5 : 1
                        )
                )
        )
    }
}
