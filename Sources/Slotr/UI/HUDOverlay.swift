import Cocoa
import SwiftUI

public class HUDOverlay {
    public static let shared = HUDOverlay()
    
    private var hudPanel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    
    private init() {}
    
    public func show(message: String, icon: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissWorkItem?.cancel()
            
            if self.hudPanel == nil {
                let panel = NSPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 260, height: 130),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.level = .floating
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = true
                panel.isMovableByWindowBackground = false
                self.hudPanel = panel
            }
            
            guard let panel = self.hudPanel else { return }
            
            let contentView = NSHostingView(
                rootView: HUDContentView(message: message, icon: icon)
            )
            panel.contentView = contentView
            
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let x = screenRect.origin.x + (screenRect.width - 260) / 2.0
                let y = screenRect.origin.y + (screenRect.height - 130) / 2.0
                panel.setFrame(NSRect(x: x, y: y, width: 260, height: 130), display: true)
            }
            
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()
            
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().alphaValue = 1.0
            }
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, let panel = self.hudPanel else { return }
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.25
                    panel.animator().alphaValue = 0.0
                }, completionHandler: {
                    panel.orderOut(nil)
                })
            }
            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: workItem)
        }
    }
}

private struct HUDContentView: View {
    let message: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 260, height: 130)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
    }
}
