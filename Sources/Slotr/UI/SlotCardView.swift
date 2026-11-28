import SwiftUI

public struct SlotCardView: View {
    let slot: LayoutSlot
    var selectedDesktop: DesktopInfo? = nil
    
    @ObservedObject var slotManager = SlotManager.shared
    @ObservedObject var desktopManager = DesktopManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    public init(slot: LayoutSlot, selectedDesktop: DesktopInfo? = nil) {
        self.slot = slot
        self.selectedDesktop = selectedDesktop
    }
    
    public var body: some View {
        Group {
            if slot.isEmpty {
                emptySlotCard
            } else {
                populatedSlotCard
            }
        }
    }
    
    // MARK: - Populated Card
    
    private var populatedSlotCard: some View {
        HStack(spacing: 11) {
            // Left: Miniature Layout Wallpaper Preview
            MiniLayoutPreview(
                frames: slot.windows.map { CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) },
                referenceSize: slotReferenceSize,
                variant: slot.id,
                cornerRadius: 7
            )
            .frame(width: 68, height: 46)
            
            // Middle: Number Badge + Editable Name + App Icons + Shortcut
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("\(slot.id)")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.slotrBlue))
                    
                    if slotManager.editingSlotId == slot.id {
                        TextField("Slot Name", text: $slotManager.editingName, onCommit: {
                            slotManager.commitEditing()
                        })
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11.5, weight: .semibold))
                        .frame(maxWidth: 130)
                        
                        Button(action: { slotManager.commitEditing() }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.slotrBlue)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 4) {
                            Text(slot.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Button(action: {
                                slotManager.startEditing(slot: slot)
                            }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Rename Slot \(slot.id)")
                        }
                        .onTapGesture(count: 2) {
                            slotManager.startEditing(slot: slot)
                        }
                    }
                }
                
                HStack(spacing: 6) {
                    let uniqueApps = uniqueSavedApps
                    HStack(spacing: -4) {
                        ForEach(uniqueApps.prefix(3), id: \.bundleId) { app in
                            Image(nsImage: desktopManager.icon(bundleId: app.bundleId, appName: app.appName))
                                .resizable()
                                .frame(width: 17, height: 17)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.slotrCardBg(colorScheme), lineWidth: 1)
                                )
                                .help(app.appName)
                        }
                    }
                    
                    Text("\(slot.windows.count) win")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                    
                    if slot.id <= 8 {
                        MacKeycapBadge("⌃⌥\(slot.id)", compact: true)
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Right: Recall + Clear
            HStack(spacing: 6) {
                Button(action: {
                    slotManager.restoreLayout(from: slot.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("Recall")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.slotrBlue)
                    )
                }
                .buttonStyle(.plain)
                .help(slot.id <= 8 ? "Restore Slot \(slot.id) (⌃⌥\(slot.id))" : "Restore Slot \(slot.id)")
                
                Button(action: {
                    slotManager.clearSlot(slotId: slot.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.slotrSubtleSurface(colorScheme))
                        )
                }
                .buttonStyle(.plain)
                .help("Clear Slot \(slot.id)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.slotrCardBg(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.03), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Empty Card
    
    private var emptySlotCard: some View {
        HStack(spacing: 11) {
            Text("\(slot.id)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.slotrSubtleSurface(colorScheme)))
            
            VStack(alignment: .leading, spacing: 2) {
                if slotManager.editingSlotId == slot.id {
                    TextField("Slot Name", text: $slotManager.editingName, onCommit: {
                        slotManager.commitEditing()
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: 140)
                } else {
                    Text(slot.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.75))
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            slotManager.startEditing(slot: slot)
                        }
                }
                
                Text(slot.id <= 8 ? "Empty preset • ⌃⌥\(slot.id)" : "Empty preset")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 4)
            
            Button(action: captureAction) {
                Text(captureButtonTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.slotrCardBg(colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.slotrBorder(colorScheme), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(slot.id <= 8
                  ? "Capture windows into Slot \(slot.id) (⌃⌥⇧\(slot.id))"
                  : "Capture windows into Slot \(slot.id)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.slotrSubtleSurface(colorScheme).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.1, dash: [4.5, 3.5])
                )
                .foregroundColor(Color.slotrBorder(colorScheme).opacity(1.4))
        )
    }
    
    // MARK: - Helpers
    
    private var captureButtonTitle: String {
        if let desktop = selectedDesktop, !desktop.isEmpty {
            return "+ Capture Desktop \(desktop.index + 1)"
        }
        return "+ Capture Space"
    }
    
    private func captureAction() {
        if let desktop = selectedDesktop, !desktop.isEmpty {
            desktopManager.saveDesktop(desktop, toSlotId: slot.id)
        } else {
            slotManager.saveCurrentLayout(to: slot.id)
        }
    }
    
    private var slotReferenceSize: CGSize? {
        if let w = slot.screenWidth, let h = slot.screenHeight, w > 100, h > 100 {
            return CGSize(width: w, height: h)
        }
        return nil
    }
    
    private var uniqueSavedApps: [(bundleId: String, appName: String)] {
        var seen = Set<String>()
        var result: [(bundleId: String, appName: String)] = []
        for w in slot.windows {
            let key = w.bundleId.isEmpty ? w.appName : w.bundleId
            if seen.insert(key).inserted {
                result.append((w.bundleId, w.appName))
            }
        }
        return result
    }
}
