import AppKit
import SitRepMenu
import SwiftUI

/// SitRep's icon at 30, its name in the system's semibold and its version: the menu's header, in the highlight's ink
/// while it is highlighted.
struct AppHeader: View {
    var isHighlighted = false

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: AppIcon.header).frame(width: AppIcon.headerSize, height: AppIcon.headerSize)
            VStack(alignment: .leading, spacing: 1) {
                Text("SitRep").font(.system(size: 13, weight: .semibold))
                Text(Self.version)
                    .font(.system(size: 11))
                    .foregroundStyle(isHighlighted ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
            }
            .foregroundStyle(isHighlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
    }

    /// The version `app/build` stamps in the Info.plist, which the plugin shares.
    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).map { "Version \($0)" }
            ?? "Not built with app/build"
    }
}

/// SitRep's app icon as macOS renders it for the bundle, masked and drawn at the size it shows at, not the Info.plist's
/// largest picture scaled down, whose edge showed a dark fringe at 30: each made once.
@MainActor
enum AppIcon {
    static let headerSize: CGFloat = 30
    static let header = image(headerSize)
    /// In the drawn notification's banner.
    static let banner = image(34)
    /// In About SitRep.
    static let about = image(112)

    private static func image(_ size: CGFloat) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

        icon.size = NSSize(width: size, height: size)
        return icon
    }
}

enum MenuHeader {
    /// The header as a menu item's view.
    @MainActor
    static func view() -> MenuHeaderView {
        MenuHeaderView()
    }
}

/// The menu's header as its item's view, which a click opens About SitRep from (DESIGN, "About SitRep"): under the
/// pointer, or the keys, it takes the menu's own highlight, the accent behind it and its words in white, and a click
/// sends its item's action, as any item's does. It is as wide as the menu, so the highlight runs across it, and set at
/// that width: a view that stretches with the menu keeps the width it was stretched to, which the menu is never
/// narrower than.
final class MenuHeaderView: NSView {
    private let highlight = NSVisualEffectView()
    private let words = NSHostingView(rootView: AppHeader())

    /// Where the menu draws its highlight, in from its edges, and how round.
    private static let inset: CGFloat = 5
    private static let radius: CGFloat = 6

    var isHighlighted = false {
        didSet {
            if isHighlighted != oldValue {
                highlight.isHidden = !isHighlighted
                words.rootView = AppHeader(isHighlighted: isHighlighted)
            }
        }
    }

    init() {
        let size = words.fittingSize

        super.init(frame: NSRect(x: 0, y: 0, width: MenuCut.menuWidth, height: size.height + 12))
        highlight.material = .selection
        highlight.state = .active
        highlight.isEmphasized = true
        highlight.maskImage = Self.mask
        highlight.frame = bounds.insetBy(dx: Self.inset, dy: 0)
        highlight.isHidden = true
        words.frame = NSRect(x: 14, y: 6, width: size.width, height: size.height)
        addSubview(highlight)
        addSubview(words)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// The whole header takes the click, never the words inside it.
    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func mouseUp(with event: NSEvent) {
        guard let item = enclosingMenuItem, let menu = item.menu else {
            return
        }

        menu.cancelTracking()
        menu.performActionForItem(at: menu.index(of: item))
    }

    /// The highlight's rounded corners, as a mask that stretches to its size.
    private static let mask = {
        let side = radius * 2 + 1
        let mask = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }

        mask.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        mask.resizingMode = .stretch
        return mask
    }()
}
