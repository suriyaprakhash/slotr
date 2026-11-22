import SwiftUI

public struct SlotCardView: View {
    let slot: LayoutSlot
    @ObservedObject var slotManager = SlotManager.shared
    
    public init(slot: LayoutSlot) {
        self.slot = slot
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Header Row: Slot Number Badge, Name, and Date/Status
            HStack(spacing: 8) {
                // Slot Number Indicator
                Text("\(slot.id)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(slot.isEmpty ? .secondary : .white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(slot.isEmpty ? Color.primary.opacity(0.1) : Color.blue)
                    )
                
                // Slot Title (editable)
                if slotManager.editingSlotId == slot.id {
                    TextField("Slot Name", text: $slotManager.editingName, onCommit: {
                        slotManager.commitEditing()
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11.5, weight: .semibold))
                    .frame(maxWidth: 140)
                    
                    Button(action: {
                        slotManager.commitEditing()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 4) {
                        Text(slot.name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Button(action: {
                            slotManager.startEditing(slot: slot)
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Status / Timestamp
                if slot.isEmpty {
                    Text("Empty")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(4)
                } else {
                    Text(slot.formattedDate)
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            // App Pills Preview (if not empty)
            if !slot.isEmpty {
                HStack(spacing: 4) {
                    let uniqueApps = Array(Set(slot.windows.map { $0.appName })).prefix(3)
                    ForEach(uniqueApps, id: \.self) { appName in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.green.opacity(0.8))
                                .frame(width: 5, height: 5)
                            Text(appName)
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                    }
                    
                    if slot.windows.count > uniqueApps.count {
                        Text("+\(slot.windows.count - uniqueApps.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 6) {
                // Recall Button
                Button(action: {
                    slotManager.restoreLayout(from: slot.id)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("Recall")
                            .font(.system(size: 10.5, weight: .semibold))
                        Spacer()
                        Text("⌃⌥\(slot.id)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .opacity(0.7)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundColor(slot.isEmpty ? .secondary : .white)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(slot.isEmpty ? Color.primary.opacity(0.06) : Color.blue)
                    )
                }
                .buttonStyle(.plain)
                .disabled(slot.isEmpty)
                
                // Save Button
                Button(action: {
                    slotManager.saveCurrentLayout(to: slot.id)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 10))
                        Text("Save")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Save current layout to Slot \(slot.id) (⌃⌥⇧\(slot.id))")
                
                // Clear Button (if not empty)
                if !slot.isEmpty {
                    Button(action: {
                        slotManager.clearSlot(slotId: slot.id)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Slot \(slot.id)")
                }
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                )
        )
    }
}
