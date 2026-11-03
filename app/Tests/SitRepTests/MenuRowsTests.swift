import AppKit
@testable import SitRep
import SitRepMenu
import SitRepPanel
import Testing

/// The menu's session rows as the status menu sets them: a working row's arc turning while the menu is open with a
/// working row in it, from its frames drawn once; an away ask's hollow ring; and the line under a row's title kept
/// showing as its title, its time and its arc are set again. Each image read from its pixels at 2×.
@MainActor
struct MenuRowsTests {
    private static let working = Session(
        id: "sr-work01", project: Sample.project, kind: .working, title: Sample.writing.title,
        code: Sample.writing.code, sub: Sample.place, since: 0
    )
    private static func asking(away: Bool) -> Session {
        Session(
            id: "sr-ask001", project: Sample.project, name: "Session", kind: .needs, away: away,
            lines: [Session.Line(title: Sample.needsYou, since: 0)], sub: Sample.project
        )
    }

    private static let yourTurn = Session(
        id: "sr-turn01", project: Sample.project, kind: .turn, title: Sample.yourTurn, sub: Sample.place, since: 0
    )

    // MARK: The arc

    /// Thirty frames, the first the still one, each turning the arc a step further clockwise from the top, so shown in
    /// turn they go round once in a second's thirty steps.
    @Test func theArcsFramesTurnItClockwiseAStepAtATime() throws {
        #expect(MenuImages.arc.count == MenuTurn.frames)
        #expect(MenuTurn.frames == 30)

        let start = try Self.arcAngle(MenuImages.arc[0])

        // from the top round to the right: the quarter's middle up and to the right, y running down
        #expect(abs(Self.turned(from: -45, to: start)) < 3)
        for frame in [1, 7, 15, 22, 29] {
            let angle = try Self.arcAngle(MenuImages.arc[frame])

            #expect(abs(Self.turned(from: start + 12 * Double(frame), to: angle)) < 3)
        }
    }

    @Test func aWorkingRowShowsTheFrameItsTurnHasReached() {
        let item = NSMenuItem()

        MenuWords.row(item, Self.working, jump: "sr-work01", age: "2m", now: 0, isHighlighted: false, turn: 7)
        #expect(item.image === MenuImages.arc[7])
        #expect(MenuImages.mark(Self.working) === MenuImages.arc[0])
    }

    /// Its frame is the clock's, as every arc's turn is (`Arc.phase`): a second's thirty steps, round again each
    /// second, so the menu's arcs turn in step with the panel's.
    @Test func theFrameIsTheClocksPlaceInASecond() {
        #expect(MenuTurn.frame(at: 1000) == 0)
        #expect(MenuTurn.frame(at: 1000.5) == 15)
        #expect(MenuTurn.frame(at: 1000 + 7.5 / 30) == 7)
        #expect(MenuTurn.frame(at: 1001.999) == 29)
        #expect(Arc.phase(every: 1.2, at: 1000.9) == 1000.9.truncatingRemainder(dividingBy: 1.2))
    }

    /// Open with a working row in it, it turns; closed, it stops, its arcs still again at the first frame.
    @Test func itTurnsWhileTheMenuIsOpenWithAWorkingRow() {
        let (menu, entries) = Self.menu(Self.working, Self.asking(away: false))
        let turn = MenuTurn(menu)

        turn.follow(entries, isOpen: true, reducesMotion: false)
        #expect(turn.isTurning)

        turn.step(at: 1000.5)
        #expect(menu.item(at: 0)?.image === MenuImages.arc[15])

        turn.stop()
        #expect(!turn.isTurning)
        #expect(turn.frame == 0)
        #expect(menu.item(at: 0)?.image === MenuImages.arc[0])
    }

    /// With no working row, nothing runs, open or not: the timer starts only for an arc to turn.
    @Test func withNoWorkingRowItNeverStarts() {
        let (menu, entries) = Self.menu(Self.asking(away: false), Self.yourTurn)
        let turn = MenuTurn(menu)

        turn.follow(entries, isOpen: true, reducesMotion: false)
        #expect(!turn.isTurning)
    }

    /// Drawn again as rows come and go while it is open: a working row come starts it, the last one gone stops it,
    /// and the menu drawn closed stops it too.
    @Test func itStartsAndStopsAsWorkingRowsComeAndGo() {
        let (menu, withWorking) = Self.menu(Self.working, Self.asking(away: false))
        let without = Array(withWorking.dropFirst())
        let turn = MenuTurn(menu)

        turn.follow(without, isOpen: true, reducesMotion: false)
        #expect(!turn.isTurning)
        turn.follow(withWorking, isOpen: true, reducesMotion: false)
        #expect(turn.isTurning)
        turn.follow(without, isOpen: true, reducesMotion: false)
        #expect(!turn.isTurning)
        turn.follow(withWorking, isOpen: true, reducesMotion: false)
        turn.follow(withWorking, isOpen: false, reducesMotion: false)
        #expect(!turn.isTurning)
    }

    @Test func underReducedMotionItNeverStarts() {
        let (menu, entries) = Self.menu(Self.working)
        let turn = MenuTurn(menu)

        turn.follow(entries, isOpen: true, reducesMotion: true)
        #expect(!turn.isTurning)
        #expect(turn.frame == 0)
    }

    /// A step sets only the working rows' images; every other row's is left as it was set.
    @Test func aStepSwapsOnlyTheWorkingRowsArcs() {
        let (menu, entries) = Self.menu(Self.asking(away: false), Self.working, Self.yourTurn)
        let others = [0, 2].map { menu.item(at: $0)?.image }
        let turn = MenuTurn(menu)

        turn.follow(entries, isOpen: true, reducesMotion: false)
        turn.step(at: 1000.5)
        #expect(menu.item(at: 1)?.image === MenuImages.arc[15])
        #expect(menu.item(at: 0)?.image === others[0] && menu.item(at: 2)?.image === others[1])
        turn.stop()
    }

    /// A menu of these sessions' rows, set as the status menu sets them, and its entries.
    private static func menu(_ sessions: Session...) -> (NSMenu, [MenuEntry]) {
        let menu = NSMenu()
        let entries = sessions.map { MenuEntry.row($0, jump: $0.id) }

        for session in sessions {
            let item = NSMenuItem()

            MenuWords.row(item, session, jump: session.id, age: "2m", now: 0, isHighlighted: false)
            menu.addItem(item)
        }
        return (menu, entries)
    }

    /// The arc's quarter, its strokes' middle as an angle from the image's centre, y down, so the angles run
    /// clockwise.
    private static func arcAngle(_ image: NSImage) throws -> Double {
        let bitmap = try Self.drawn(image)
        let arc = (0 ..< 32).flatMap { y in (0 ..< 32).map { (x: $0, y: y) } }.filter { at in
            (bitmap.colorAt(x: at.x, y: at.y)?.alphaComponent ?? 0) > 0.4
        }
        let x = arc.map { Double($0.x) + 0.5 - 16 }.reduce(0, +), y = arc.map { Double($0.y) + 0.5 - 16 }.reduce(0, +)

        try #require(!arc.isEmpty)
        return atan2(y, x) * 180 / .pi
    }

    /// How far round from one angle to another, the short way, in degrees.
    private static func turned(from one: Double, to other: Double) -> Double {
        let turn = (other - one).truncatingRemainder(dividingBy: 360)

        return turn > 180 ? turn - 360 : turn < -180 ? turn + 360 : turn
    }

    // MARK: The away ask

    /// An ask no window holds: the needs dot's 7 across, hollow, its 1.5 ring in the needs orange, no glow outside it;
    /// not a template image, as the dot is not, so a disabled item does not grey it to nothing.
    @Test func anAwayAsksMarkIsAHollowOrangeRingWithNoGlow() throws {
        let ring = MenuImages.mark(Self.asking(away: true))
        let dot = MenuImages.mark(Self.asking(away: false))
        let drawn = try Self.drawn(ring), lit = try Self.drawn(dot)
        let edge = try #require(drawn.colorAt(x: 16, y: 10)?.usingColorSpace(.sRGB))

        #expect(!ring.isTemplate)
        #expect(edge.alphaComponent > 0.9 && edge.redComponent > 0.8 && edge.blueComponent < 0.4)
        #expect((drawn.colorAt(x: 16, y: 16)?.alphaComponent ?? 1) < 0.05)
        #expect((drawn.colorAt(x: 16, y: 7)?.alphaComponent ?? 1) < 0.05)
        // the dot's glow reaches where the ring draws nothing
        #expect((lit.colorAt(x: 16, y: 7)?.alphaComponent ?? 0) > 0.05)
    }

    /// The image drawn at 2× into a clear bitmap, its top row first.
    private static func drawn(_ image: NSImage) throws -> NSBitmapImageRep {
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))

        bitmap.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    // MARK: The line under the title

    /// Set again with the words it has, as each move of the pointer sets the rows it leaves and reaches, a row's title
    /// is left alone: on macOS 26 a title set, even to the one it has, blanks the line under it in the menu as it
    /// shows, and the line set again as it was puts nothing back.
    @available(macOS 15, *)
    @Test func aRowSetAgainAsItWasKeepsItsTitle() {
        let item = Recorded()

        MenuWords.row(item, Self.asking(away: false), jump: "sr-ask001", age: "1h", now: 0, isHighlighted: false)
        item.sets = []
        MenuWords.describe(item, Self.asking(away: false), jump: "sr-ask001", now: 0, isHighlighted: true)
        #expect(item.sets == ["subtitle \(Sample.project)"])
    }

    /// A working row under the pointer takes its title's grey off, which sets its title: the line under it is taken
    /// off and put back after, so it shows again, at rest and under the pointer alike.
    @available(macOS 15, *)
    @Test func aRowWhoseTitleChangesHasItsLinePutBackAfter() {
        let item = Recorded()

        MenuWords.row(item, Self.working, jump: "sr-work01", age: "2m", now: 0, isHighlighted: false)
        item.sets = []
        MenuWords.describe(item, Self.working, jump: "sr-work01", now: 0, isHighlighted: true)
        #expect(item.sets == ["title", "subtitle nil", "subtitle \(Sample.place)"])
        #expect(item.subtitle == Sample.place)
    }

    /// The line under a row's title as the open menu shows it, in the view it makes for the row, kept as the row's
    /// time and arc are set again, each as an open menu passes it on, the two on the one row in the one pass: the
    /// status menu sets them while open and never sets the line again after. A title set, as the view is told of it,
    /// does blank the line, so the view read here is one that shows the loss.
    @Test(.enabled(if: ShownItem.isReachable)) func aRowsTimeAndArcSetAgainKeepTheLineUnderItsTitle() throws {
        let (menu, _) = Self.menu(Self.working, Self.asking(away: false))
        let shown = try #require(ShownItem(menu, at: 0))
        let item = try #require(menu.item(at: 0))

        #expect(shown.words.contains(Sample.place))
        for round in 0 ..< 3 {
            shown.set(item, badge: NSMenuItemBadge(string: "\(round)m"))
            shown.set(item, image: MenuImages.arc[round + 1])
        }
        #expect(shown.words.contains(Sample.place))
        shown.highlight(true)
        shown.set(item, image: MenuImages.arc[9])
        shown.highlight(false)
        #expect(shown.words.contains(Sample.place))

        shown.set(item, title: NSAttributedString(string: "Reading "))
        #expect(!shown.words.contains(Sample.place))
    }

    /// A row of a menu in the view the menu shows it in, made offscreen as the menu makes it as it opens, through
    /// AppKit's own private calls, which this macOS has (`isReachable`); each change to the row passed on to the view
    /// as an open menu passes it.
    @MainActor
    private struct ShownItem {
        let view: NSView
        /// Never ordered in: the view's only for it to lay out in, offscreen.
        private let window: NSWindow

        nonisolated static var isReachable: Bool {
            NSMenu.instancesRespond(to: NSSelectorFromString("_menuImpl"))
        }

        init?(_ menu: NSMenu, at index: Int) {
            typealias Make = @convention(c) (AnyObject, Selector, Int, AnyObject?) -> NSView?
            let make = NSSelectorFromString("makeViewForMenuItemAtIndex:withFilterQuery:")

            menu.update()
            guard let impl = menu.perform(NSSelectorFromString("_menuImpl"))?.takeUnretainedValue() as? NSObject,
                  impl.responds(to: make),
                  let view = unsafeBitCast(impl.method(for: make), to: Make.self)(impl, make, index, nil)
            else {
                return nil
            }

            let window = NSWindow(
                contentRect: NSRect(x: -5000, y: -5000, width: 340, height: 44), styleMask: [.borderless],
                backing: .buffered, defer: true
            )

            window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 44))
            view.frame = NSRect(x: 0, y: 0, width: 340, height: 44)
            window.contentView?.addSubview(view)
            self.view = view
            self.window = window
        }

        /// The title and the line under it as the view shows them.
        var words: String {
            view.layoutSubtreeIfNeeded()
            return (view.value(forKey: "_titleTextField") as? NSTextField)?.stringValue ?? ""
        }

        /// Under the pointer or not, as the menu shows it.
        func highlight(_ isHighlighted: Bool) {
            typealias Set = @convention(c) (AnyObject, Selector, Bool) -> Void
            let selector = NSSelectorFromString("setHighlighted:")

            unsafeBitCast(view.method(for: selector), to: Set.self)(view, selector, isHighlighted)
        }

        func set(_ item: NSMenuItem, badge: NSMenuItemBadge) {
            let was = item.badge

            item.badge = badge
            changed("Badge", from: was, to: badge)
        }

        func set(_ item: NSMenuItem, image: NSImage) {
            let was = item.image

            item.image = image
            changed("Image", from: was, to: image)
        }

        func set(_ item: NSMenuItem, title: NSAttributedString) {
            let was = item.attributedTitle

            item.attributedTitle = title
            changed("AttributedTitle", from: was, to: title)
        }

        private func changed(_ what: String, from was: AnyObject?, to now: AnyObject?) {
            typealias Change = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> Void
            let selector = NSSelectorFromString("_didChange\(what)From:to:")

            unsafeBitCast(view.method(for: selector), to: Change.self)(view, selector, was, now)
        }
    }

    /// A menu item that notes each title and line under it set on it, in order.
    @available(macOS 15, *)
    private final class Recorded: NSMenuItem {
        var sets: [String] = []

        override var attributedTitle: NSAttributedString? {
            get { super.attributedTitle }
            set {
                sets.append("title")
                super.attributedTitle = newValue
            }
        }

        override var subtitle: String? {
            get { super.subtitle }
            set {
                sets.append("subtitle \(newValue ?? "nil")")
                super.subtitle = newValue
            }
        }
    }
}
