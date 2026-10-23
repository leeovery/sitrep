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
final class MenuAnchor {
    fileprivate weak var view: NSView?

    /// The menu under the anchor's view, left-aligned with it, 4 below it; returns once it has closed.
    func popUp(_ menu: NSMenu) {
        guard let view else {
            return
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.isFlipped ? view.bounds.maxY + 4 : -4), in: view)
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
