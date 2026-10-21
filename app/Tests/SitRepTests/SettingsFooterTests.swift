import AppKit
@testable import SitRep
@testable import SitRepWindow
import SwiftUI
import Testing

/// Settings at the sidebar's foot as the window lays it out, against spec 2.5: a rule of 0.5, 276 wide and centred, 8
/// under it the row, 32 tall, then 10 to the glass's bottom; the list ending at the rule, its last row 12 over it. A
/// window on screen gives the sidebar a bottom safe area that an offscreen one does not, so each holds whatever bottom
/// safe area the sidebar has. Picked, the row draws the system's selection itself; under the pointer, a row's quiet
/// fill; a click picks it, and VoiceOver reads it as a choice, selected while Settings shows. What the row tells
/// SwiftUI it tells after AppKit's change (`settle`).
@MainActor
struct SettingsFooterTests {
    /// Picked, so the selection draws the row's 276 by 32, in from the sidebar's edges; every frame from the drawing's
    /// pixels but the row's own.
    @Test(arguments: [0, 10, 27.5])
    func theFootIsARuleThen8ThenItsRow32Then10ToTheGlasssBottom(bottomSafeArea: CGFloat) throws {
        let side = try HostedSidebar(Self.onSettings(), bottomSafeArea: bottomSafeArea)
        let row = try Self.row(of: side)
        let glass = side.glassBottom - side.glassTop
        let drawn = try side.drawn()
        let above = CGRect(x: 0, y: row.minY - 20, width: 296, height: 20)
        let rule = try #require(drawn.drawnBox(in: above, ground: CGPoint(x: 4, y: above.midY)))
        let below = CGRect(x: 0, y: rule.maxY, width: 296, height: glass - rule.maxY)
        let selection = try #require(drawn.drawnBox(in: below, ground: CGPoint(x: 4, y: row.midY)))

        #expect(row == CGRect(x: 0, y: glass - 10 - 32, width: 296, height: 32))
        #expect(rule == CGRect(x: 10, y: row.minY - 8 - 0.5, width: 276, height: 0.5))
        #expect(selection == CGRect(x: 10, y: row.minY, width: 276, height: 32))
    }

    /// In a window too short for the board, scrolled to its end: no row of it passes behind the foot.
    @Test(arguments: [0, 10, 27.5])
    func theListEndsAtTheRuleItsLastRow12OverIt(bottomSafeArea: CGFloat) throws {
        let side = try HostedSidebar(HostedSidebar.opened(), height: 400, bottomSafeArea: bottomSafeArea)
        let scroll = try Self.scrolledToItsEnd(side)
        let last = try #require(side.rows.last)
        let rule = try side.footRow().minY - WindowStyle.footerTop - WindowStyle.footerRule

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

    /// The system's grey, opaque, until its row has the key window's focus, as in a window not key or with focus on the
    /// board's list; then the accent, its gear white, as the emphasized selection turns it.
    @Test(arguments: [(false, true), (true, false), (true, true)])
    func pickedItsSelectionIsTheSystemsGreyUntilItsRowHasTheKeyWindowsFocus(isKey: Bool, isFocused: Bool) async throws {
        let side = try HostedSidebar(Self.onSettings(), isKey: isKey)
        let isEmphasized = isKey && isFocused

        side.window.makeFirstResponder(isFocused ? side.foot : side.board)
        await Self.settle()

        let drawn = try side.drawn()
        let row = try Self.row(of: side)
        let fill = try #require(drawn.stored(at: CGPoint(x: 270, y: row.midY)))
        let gear = try drawn.brightest(in: Self.gear(in: row))
        let system: NSColor = isEmphasized
            ? .selectedContentBackgroundColor : .unemphasizedSelectedContentBackgroundColor

        #expect(Self.same(fill, Self.dark(system, in: drawn.bitmap.colorSpace)))
        #expect(gear.isWhite == isEmphasized)
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
        #expect(Self.same(hovered, try #require(NSColor(WindowStyle.sidebarHover).usingColorSpace(.sRGB))))
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

    /// A press anywhere across the row lands on it, past what it draws, picks Settings, and gives it focus, as a press
    /// on a list's row does; in a window not key too.
    @Test(arguments: [20, 150, 290])
    func aClickOnItsRowPicksSettingsItsRowTakingFocus(x: CGFloat) throws {
        let picks = Picks()
        let side = try HostedSidebar(HostedSidebar.opened(), actions: WindowActions(pick: { picks.made.append($0) }))
        let foot = try #require(side.foot)
        let press = try Self.press(at: foot.convert(CGPoint(x: x, y: foot.bounds.midY), to: nil), in: side.window)

        try #require(Self.hit(press, in: side.window) === foot)
        foot.mouseDown(with: press)
        #expect(picks.made == [.settings])
        #expect(side.window.firstResponder === foot)
        #expect(foot.acceptsFirstMouse(for: press))
    }

    /// A Control-click is the Mac's right-click: it picks nothing, and focus stays where it was.
    @Test func aControlClickPicksNothing() throws {
        let picks = Picks()
        let side = try HostedSidebar(HostedSidebar.opened(), actions: WindowActions(pick: { picks.made.append($0) }))
        let foot = try #require(side.foot)
        let press = try Self.press(
            at: foot.convert(CGPoint(x: 150, y: foot.bounds.midY), to: nil), with: .control, in: side.window
        )

        side.window.makeFirstResponder(side.board)
        foot.mouseDown(with: press)
        #expect(picks.made.isEmpty)
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

    /// One of the sidebar's choices, a radio button, whose value VoiceOver reads as selected or not.
    @Test func voiceOverReadsItsRowAsAChoiceSelectedWhileSettingsShows() throws {
        let picks = Picks()
        let actions = WindowActions(pick: { picks.made.append($0) })
        let unpicked = try #require(try HostedSidebar(HostedSidebar.opened(), actions: actions).foot)
        let picked = try #require(try HostedSidebar(Self.onSettings()).foot)

        #expect(unpicked.isAccessibilityElement() && unpicked.accessibilityRole() == .radioButton)
        #expect(unpicked.accessibilityLabel() == "Settings")
        #expect(unpicked.accessibilityValue() as? NSNumber == 0 && picked.accessibilityValue() as? NSNumber == 1)
        #expect(!unpicked.isAccessibilitySelected() && picked.isAccessibilitySelected())
        #expect(unpicked.accessibilityPerformPress())
        #expect(picks.made == [.settings])
    }

    /// Not picked, as Tab reaches it, the system's focus ring, round the selection's shape.
    @Test func notPickedItsFocusRingIsTheSelectionsShape() throws {
        let foot = try #require(try HostedSidebar(HostedSidebar.opened()).foot)

        #expect(foot.focusRingType == .default)
        #expect(foot.focusRingMaskBounds == CGRect(x: 10, y: 0, width: 276, height: 32))
    }

    /// Picked, it shows focus as a list's row does, by its selection alone.
    @Test func pickedItDrawsNoFocusRing() throws {
        let foot = try #require(try HostedSidebar(Self.onSettings()).foot)

        #expect(foot.focusRingType == .none)
    }

    private static func onSettings() -> WindowRun {
        let run = HostedSidebar.opened()

        _ = run.pick(.settings)
        return run
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

    /// A system colour as the dark appearance gives it, in this colour space.
    private static func dark(_ colour: NSColor, in space: NSColorSpace) -> NSColor {
        var resolved = colour

        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            resolved = colour.usingColorSpace(space) ?? colour
        }
        return resolved
    }

    /// Two colours alike to within a step of 8 bits in each channel and in their cover.
    private static func same(_ one: NSColor, _ other: NSColor) -> Bool {
        [
            (one.redComponent, other.redComponent), (one.greenComponent, other.greenComponent),
            (one.blueComponent, other.blueComponent), (one.alphaComponent, other.alphaComponent),
        ].allSatisfy { abs($0 - $1) <= 1.5 / 255 }
    }
}

/// What the foot asked the window to pick.
@MainActor
private final class Picks {
    var made: [Pick] = []
}
