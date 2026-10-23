import AppKit
import SwiftUI

/// Over what it covers, a right-click, or a Control-click, brings up the AppKit menu it makes then, as the card's rows
/// do, so the sidebar's menus are the card's, their times at the right (`SnoozeMenu`), which SwiftUI's own menus set no
/// place for. Every other click, and the pointer, pass through it to what is under it.
struct ContextMenuArea: NSViewRepresentable {
    let menu: () -> NSMenu

    func makeNSView(context _: Context) -> Area {
        Area()
    }

    func updateNSView(_ area: Area, context _: Context) {
        area.makeMenu = menu
    }

    final class Area: NSView {
        var makeMenu: () -> NSMenu = { NSMenu() }

        /// Only a click that brings up a menu finds it.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent, Self.bringsUpMenu(event) else {
                return nil
            }
            return super.hitTest(point)
        }

        override func rightMouseDown(with event: NSEvent) {
            NSMenu.popUpContextMenu(makeMenu(), with: event, for: self)
        }

        /// Only a Control-click comes here (`hitTest`).
        override func mouseDown(with event: NSEvent) {
            NSMenu.popUpContextMenu(makeMenu(), with: event, for: self)
        }

        static func bringsUpMenu(_ event: NSEvent) -> Bool {
            event.type == .rightMouseDown || event.type == .leftMouseDown && event.modifierFlags.contains(.control)
        }
    }
}

/// Where a button's AppKit menu drops down from: the view it stands on, which a press pops the menu up under.
@MainActor
final class MenuAnchor: NSObject {
    fileprivate weak var view: NSView?
    private var dropping: (menu: NSMenu, closed: () -> Void)?

    /// The menu under the anchor's view, left-aligned with it, 4 below it, then `closed` as it closes. It drops on the
    /// run loop's next turn, from a timer in the common modes, so what the press changed has drawn first; and a timer
    /// fires outside any block of the main queue, so the menu's tracking loop goes on draining it, the main actor's work
    /// with it, `watch`'s lines and every wait the window runs. Popped from a block of the main queue, as a `Task` on
    /// the main actor is, the menu would hold it until it closed.
    func popUp(_ menu: NSMenu, closed: @escaping () -> Void) {
        dropping = (menu, closed)
        perform(#selector(drop), with: nil, afterDelay: 0, inModes: [.common])
    }

    @objc private func drop() {
        guard let (menu, closed) = dropping else {
            return
        }

        dropping = nil
        if let view {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.isFlipped ? view.bounds.maxY + 4 : -4), in: view)
        }
        closed()
    }
}

/// The view a `MenuAnchor` stands on, behind what it anchors.
struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor

    func makeNSView(context _: Context) -> NSView {
        let view = NSView()

        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context _: Context) {
        anchor.view = view
    }
}
