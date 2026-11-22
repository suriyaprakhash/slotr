import Foundation
import CoreGraphics

public enum SnapZone: String, CaseIterable, Identifiable, Codable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximize
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case leftThird
    case centerThird
    case rightThird
    case leftTwoThirds
    case rightTwoThirds
    case center
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .maximize: return "Full Screen"
        case .topLeftQuarter: return "Top Left"
        case .topRightQuarter: return "Top Right"
        case .bottomLeftQuarter: return "Bottom Left"
        case .bottomRightQuarter: return "Bottom Right"
        case .leftThird: return "Left 1/3"
        case .centerThird: return "Center 1/3"
        case .rightThird: return "Right 1/3"
        case .leftTwoThirds: return "Left 2/3"
        case .rightTwoThirds: return "Right 2/3"
        case .center: return "Center"
        }
    }
    
    public var iconName: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        case .topHalf: return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .topLeftQuarter: return "rectangle.inset.topleft.filled"
        case .topRightQuarter: return "rectangle.inset.topright.filled"
        case .bottomLeftQuarter: return "rectangle.inset.bottomleft.filled"
        case .bottomRightQuarter: return "rectangle.inset.bottomright.filled"
        case .leftThird: return "rectangle.split.3x1"
        case .centerThird: return "rectangle.split.3x1.fill"
        case .rightThird: return "rectangle.split.3x1"
        case .leftTwoThirds: return "rectangle.split.2x1"
        case .rightTwoThirds: return "rectangle.split.2x1"
        case .center: return "viewfinder"
        }
    }
    
    public var symbolText: String {
        switch self {
        case .leftHalf: return "◧"
        case .rightHalf: return "◨"
        case .topHalf: return "⬒"
        case .bottomHalf: return "⬓"
        case .maximize: return "⛶"
        case .topLeftQuarter: return "◸"
        case .topRightQuarter: return "◹"
        case .bottomLeftQuarter: return "◺"
        case .bottomRightQuarter: return "◿"
        case .leftThird: return "▎"
        case .centerThird: return " ▎ "
        case .rightThird: return "  ▎"
        case .leftTwoThirds: return "▌"
        case .rightTwoThirds: return " ▌"
        case .center: return "▣"
        }
    }
    
    /// Computes the target frame in Accessibility (Quartz) coordinates for a given screen's usable area
    public func targetFrame(for usableRect: CGRect) -> CGRect {
        let x = usableRect.origin.x
        let y = usableRect.origin.y
        let w = usableRect.size.width
        let h = usableRect.size.height
        
        switch self {
        case .leftHalf:
            return CGRect(x: x, y: y, width: w / 2.0, height: h)
        case .rightHalf:
            return CGRect(x: x + w / 2.0, y: y, width: w / 2.0, height: h)
        case .topHalf:
            return CGRect(x: x, y: y, width: w, height: h / 2.0)
        case .bottomHalf:
            return CGRect(x: x, y: y + h / 2.0, width: w, height: h / 2.0)
        case .maximize:
            return usableRect
        case .topLeftQuarter:
            return CGRect(x: x, y: y, width: w / 2.0, height: h / 2.0)
        case .topRightQuarter:
            return CGRect(x: x + w / 2.0, y: y, width: w / 2.0, height: h / 2.0)
        case .bottomLeftQuarter:
            return CGRect(x: x, y: y + h / 2.0, width: w / 2.0, height: h / 2.0)
        case .bottomRightQuarter:
            return CGRect(x: x + w / 2.0, y: y + h / 2.0, width: w / 2.0, height: h / 2.0)
        case .leftThird:
            return CGRect(x: x, y: y, width: w / 3.0, height: h)
        case .centerThird:
            return CGRect(x: x + w / 3.0, y: y, width: w / 3.0, height: h)
        case .rightThird:
            return CGRect(x: x + 2.0 * (w / 3.0), y: y, width: w / 3.0, height: h)
        case .leftTwoThirds:
            return CGRect(x: x, y: y, width: 2.0 * (w / 3.0), height: h)
        case .rightTwoThirds:
            return CGRect(x: x + w / 3.0, y: y, width: 2.0 * (w / 3.0), height: h)
        case .center:
            let cw = w * 0.72
            let ch = h * 0.80
            return CGRect(x: x + (w - cw) / 2.0, y: y + (h - ch) / 2.0, width: cw, height: ch)
        }
    }
}
