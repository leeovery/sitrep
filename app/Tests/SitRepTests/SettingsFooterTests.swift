import AppKit
@testable import SitRep
@testable import SitRepWindow
import SwiftUI
import Testing

/// Settings at the sidebar's foot as the window lays it out, against spec 2.5: a rule of 0.5, 276 wide and centred, 8
/// under it the row, 32 tall, then 10 to the glass's bottom; the list ending at the rule, its last row 12 over it. A
/// window on screen gives the sidebar a bottom safe area that an offscreen one does not, so each holds whatever bottom
/// safe area the sidebar has. It is never picked: under the pointer it shows a row's quiet fill; a click opens the
/// Settings window, and VoiceOver reads it as a button. What the row tells SwiftUI it tells after AppKit's change
/// (`settle`).
@MainActor
struct SettingsFooterTests {
    /// The rule from the drawing's pixels, the row's frame its own.
    @Test(arguments: [0, 10, 27.5])
    func theFootIsARuleThen8ThenItsRow32Then10ToTheGlasssBottom(bottomSafeArea: CGFloat) throws {
        let side = try HostedSidebar(HostedSidebar.opened(), bottomSafeArea: bottomSafeArea)
        let row = try Self.row(of: side)
        let glass = side.glassBottom - side.glassTop
        let drawn = try side.drawn()
        let above = CGRect(x: 0, y: row.minY - 20, width: 296, height: 20)
        let rule = try #require(drawn.drawnBox(in: above, ground: CGPoint(x: 4, y: above.midY)))

        #expect(row == CGRect(x: 0, y: glass - 10 - 32, width: 296, height: 32))
        #expect(rule == CGRect(x: 10, y: row.minY - 8 - 0.5, width: 276, height: 0.5))
    }

    /// In a window too short for the board, scrolled to its end: no row of it passes behind the foot.
    @Test(arguments: [0, 10, 27.5])
    func theListEndsAtTheRuleItsLastRow12OverIt(bottomSafeArea: CGFloat) throws {
        let side = try HostedSidebar(HostedSidebar.opened(), height: 400, bottomSafeArea: bottomSafeArea)
        let scroll = try Self.scrolledToItsEnd(side)
        let last = try #require(side.rows.last)
        let rule = try side.footRow().minY - WindowStyle.footerTop - WindowStyle.rule

        #expect(side.frame(of: scroll).maxY == rule)
        #expect(rule - last.maxY == 12)
    }

    /// The gear centred on the mark's slot, at 29, in the accent; "Settings" at a title's 46.
    @Test func itsRowIsASessionRowsGearAndWord() throws {
        let side = try HostedSidebar(HostedSidebar.opened())
        let drawn = try side.drawn()
        let row = try Self.row(of: side)
        let gear = try #require(drawn.drawnBox(in: Self.gear(in: row), ground: Self.ground(row)))
        let word = try #require(drawn.drawnBox(in: Self.word(in: row), ground: Self.ground(row)))
        let accent = try drawn.brightest(in: gear)

        #expect(abs(gear.midX - 29) <= 0.5 && abs(gear.width - 15) <= 1)
        #expect(abs(gear.midY - row.midY) <= 0.5)
        #expect((46 ... 47.5).contains(word.minX))
        #expect(accent.blueComponent > 0.8 && accent.redComponent < 0.4)
    }

    /// With focus on it in the key window, it draws no selection, its gear still the accent: it shows focus by the
    /// system's ring alone.
    @Test func itNeverDrawsASelection() async throws {
        let side = try HostedSidebar(HostedSidebar.opened(), isKey: true)

        side.window.makeFirstResponder(side.foot)
        await Self.settle()

        let drawn = try side.drawn()
        let row = try Self.row(of: side)
        let accent = try drawn.brightest(in: Self.gear(in: row))

        #expect(try #require(drawn.stored(at: CGPoint(x: 270, y: row.midY))).alphaComponent == 0)
        #expect(accent.blueComponent > 0.8 && accent.redComponent < 0.4)
    }

    /// Under the pointer and not picked, a session row's quiet fill, 6% white over the glass; gone as the pointer
    /// leaves. The pointer's crossings come through the row's one tracking area (`cross`).
    @Test func underThePointerItsRowTakesARowsQuietFill() async throws {
        let side = try HostedSidebar(HostedSidebar.opened())
        let foot = try #require(side.foot)
        let place = CGPoint(x: 270, y: try Self.row(of: side).midY)

        foot.updateTrackingAreas()
        let area = try #require(foot.trackingAreas.first)
        try Self.cross(.mouseEntered, area, in: side.window)
        await Self.settle()
        let hovered = try #require(side.drawn().stored(at: place))
        try Self.cross(.mouseExited, area, in: side.window)
        await Self.settle()
        let left = try #require(side.drawn().stored(at: place))

        #expect(foot.trackingAreas.count == 1)
        #expect(area.options.isSuperset(of: [.mouseEnteredAndExited, .inVisibleRect]))
        #expect(hovered.isAlike(try #require(NSColor(WindowStyle.sidebarHover).usingColorSpace(.sRGB))))
        #expect(left.alphaComponent == 0)
    }

    /// A window out of sight, closed, minimised or ordered out, sends no exit, nor does a row taken out of its window.
    @Test(arguments: [false, true])
    func theHoverGoesAsItsWindowGoesOutOfSightOrItLeavesIt(leavesItsWindow: Bool) async throws {
        let side = try HostedSidebar(HostedSidebar.opened())
        let foot = try #require(side.foot)
        let host = try #require(foot.superview)
        let place = CGPoint(x: 270, y: try Self.row(of: side).midY)

        try Self.cross(.mouseEntered, try #require(foot.trackingAreas.first), in: side.window)
        await Self.settle()
        try #require(try side.drawn().stored(at: place)?.alphaComponent != 0)
        if leavesItsWindow {
            foot.removeFromSuperview()
            await Self.settle()
            host.addSubview(foot)
        } else {
            NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: side.window)
            await Self.settle()
        }

        #expect(try side.drawn().stored(at: place)?.alphaComponent == 0)
    }

    /// A press anywhere across the row lands on it, past what it draws, and opens the Settings window, picking nothing
    /// on the board; in a window not key too.
    @Test(arguments: [20, 150, 290])
    func aClickOnItsRowOpensSettings(x: CGFloat) throws {
        let asked = Asked()
        let side = try HostedSidebar(HostedSidebar.opened(), actions: asked.actions)
        let foot = try #require(side.foot)
        let press = try Self.press(at: foot.convert(CGPoint(x: x, y: foot.bounds.midY), to: nil), in: side.window)

        try #require(Self.hit(press, in: side.window) === foot)
        foot.mouseDown(with: press)
        #expect(asked.opens == 1)
        #expect(asked.picks.isEmpty)
        #expect(foot.acceptsFirstMouse(for: press))
    }

    /// A Control-click is the Mac's right-click: it opens nothing, and focus stays where it was.
    @Test func aControlClickOpensNothing() throws {
        let asked = Asked()
        let side = try HostedSidebar(HostedSidebar.opened(), actions: asked.actions)
        let foot = try #require(side.foot)
        let press = try Self.press(
            at: foot.convert(CGPoint(x: 150, y: foot.bounds.midY), to: nil), with: .control, in: side.window
        )

        side.window.makeFirstResponder(side.board)
        foot.mouseDown(with: press)
        #expect(asked.opens == 0)
        #expect(side.window.firstResponder === side.board)
    }

    /// The list ends at the rule: a press on it or the space round it lands on none of the list's rows.
    @Test func aClickOnTheFootOutsideItsRowLandsOnNothingUnderIt() throws {
        let side = try HostedSidebar(HostedSidebar.opened(), height: 400)
        let foot = try #require(side.foot)
        let ys = [foot.bounds.maxY + 4, foot.bounds.maxY + WindowStyle.footerTop + 0.25, -4]

        for y in ys {
            let press = try Self.press(at: foot.convert(CGPoint(x: 150, y: y), to: nil), in: side.window)
            let hit = try #require(Self.hit(press, in: side.window))

            #expect(hit !== foot && !hit.isDescendant(of: side.board))
            #expect(hit.isDescendant(of: side.view))
        }
    }

    /// A button, "Settings", which a press of VoiceOver's opens, with no value and never selected.
    @Test func voiceOverReadsItsRowAsAButton() throws {
        let asked = Asked()
        let foot = try #require(try HostedSidebar(HostedSidebar.opened(), actions: asked.actions).foot)

        #expect(foot.isAccessibilityElement() && foot.accessibilityRole() == .button)
        #expect(foot.accessibilityLabel() == "Settings")
        #expect(foot.accessibilityValue() == nil && !foot.isAccessibilitySelected())
        #expect(foot.accessibilityPerformPress())
        #expect(asked.opens == 1)
    }

    /// As Tab reaches it, the system's focus ring, round a row's shape.
    @Test func itsFocusRingIsARowsShape() throws {
        let foot = try #require(try HostedSidebar(HostedSidebar.opened()).foot)

        #expect(foot.focusRingType == .default)
        #expect(foot.focusRingMaskBounds == CGRect(x: 10, y: 0, width: 276, height: 32))
    }

    /// Settings' row, its y from the glass's top, as the drawing's are.
    private static func row(of side: HostedSidebar) throws -> CGRect {
        try side.footRow().offsetBy(dx: 0, dy: -side.glassTop)
    }

    private static func gear(in row: CGRect) -> CGRect {
        CGRect(x: 16, y: row.minY, width: 26, height: 32)
    }

    private static func word(in row: CGRect) -> CGRect {
        CGRect(x: 42, y: row.minY, width: 150, height: 32)
    }

    /// The glass beside the row, left of its selection.
    private static func ground(_ row: CGRect) -> CGPoint {
        CGPoint(x: 4, y: row.midY)
    }

    private static func scrolledToItsEnd(_ side: HostedSidebar) throws -> NSScrollView {
        let scroll = try #require(side.board.enclosingScrollView)
        let clip = scroll.contentView
        let end = side.board.frame.height - clip.bounds.height + scroll.contentInsets.bottom

        clip.scroll(to: NSPoint(x: 0, y: end))
        scroll.reflectScrolledClipView(clip)
        return scroll
    }

    /// A press at this point in the window.
    private static func press(
        at point: CGPoint, with modifiers: NSEvent.ModifierFlags = [], in window: NSWindow
    ) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: point, modifierFlags: modifiers, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
    }

    /// What the row tells SwiftUI after AppKit's change, told: queued on the main queue, which runs it once the test
    /// lets go of the main actor.
    private static func settle() async {
        await Task.yield()
    }

    /// The view a press lands on, as the window finds it: a window never shown hands no press on.
    private static func hit(_ press: NSEvent, in window: NSWindow) -> NSView? {
        let frame = window.contentView?.superview

        return frame?.hitTest(frame?.convert(press.locationInWindow, from: nil) ?? .zero)
    }

    /// The pointer crossing into a tracking area, or out of it, as the window server reports it, the event's tracking
    /// number the area's own, handed to the owner the event names. AppKit hands a window never shown no crossing, by
    /// `sendEvent` of the window's or the app's (measured).
    private static func cross(_ type: NSEvent.EventType, _ area: NSTrackingArea, in window: NSWindow) throws {
        let event = try #require(NSEvent.enterExitEvent(
            with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, eventNumber: 0, trackingNumber: Int(bitPattern: Unmanaged.passUnretained(area).toOpaque()),
            userData: nil
        ))
        let owner = try #require(event.trackingArea?.owner as? NSResponder)

        if type == .mouseEntered {
            owner.mouseEntered(with: event)
        } else {
            owner.mouseExited(with: event)
        }
    }

}

/// What the foot asked the window for: the Settings window, and no pick.
@MainActor
private final class Asked {
    var opens = 0
    var picks: [Pick] = []

    var actions: WindowActions {
        WindowActions(pick: { self.picks.append($0) }, openSettings: { self.opens += 1 })
    }
}
