import AppKit
@testable import SitRep
import SitRepPanel
import Testing

/// The menu's session rows as the status menu sets them: a working row's arc turning while the menu is open, from its
/// frames drawn once; an away ask's hollow ring; and the line under a row's title kept showing as its title is set
/// again. Each image read from its pixels at 2×.
@MainActor
struct MenuRowsTests {
    private static let working = Session(
        id: "sr-macapp", project: "SitRep", kind: .working, title: "Writing ", code: "Sample.swift",
        sub: "SitRep · The Mac app", since: 0
    )
    private static func asking(away: Bool) -> Session {
        Session(
            id: "sr-kit", project: "Kit", name: "The bootstrap", kind: .needs, away: away,
            lines: [Session.Line(title: "Which edge?", since: 0)], sub: "Kit"
        )
    }

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

        MenuWords.row(item, Self.working, jump: "sr-macapp", age: "2m", now: 0, isHighlighted: false, turn: 7)
        #expect(item.image === MenuImages.arc[7])
        #expect(MenuImages.mark(Self.working) === MenuImages.arc[0])
    }

    /// Opened, it steps through the frames, showing each; closed, it stops, still again at the first frame.
    @Test func itTurnsFromTheMenuOpeningToItsClosing() {
        var shown = 0
        let turn = MenuTurn { shown += 1 }

        turn.start(reducesMotion: false)
        #expect(turn.isTurning)
        turn.step()
        turn.step()
        #expect(turn.frame == 2 && shown == 2)

        turn.stop()
        #expect(!turn.isTurning)
        #expect(turn.frame == 0 && shown == 3)
    }

    @Test func aTurnGoesRoundToTheFirstFrameAgain() {
        let turn = MenuTurn {}

        (0 ..< MenuTurn.frames).forEach { _ in turn.step() }
        #expect(turn.frame == 0)
    }

    @Test func underReducedMotionItNeverStarts() {
        let turn = MenuTurn {}

        turn.start(reducesMotion: true)
        #expect(!turn.isTurning)
        #expect(turn.frame == 0)
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

        MenuWords.row(item, Self.asking(away: false), jump: "sr-kit", age: "1h", now: 0, isHighlighted: false)
        item.sets = []
        MenuWords.describe(item, Self.asking(away: false), jump: "sr-kit", now: 0, isHighlighted: true)
        #expect(item.sets == ["subtitle Kit"])
    }

    /// A working row under the pointer takes its title's grey off, which sets its title: the line under it is taken
    /// off and put back after, so it shows again, at rest and under the pointer alike.
    @available(macOS 15, *)
    @Test func aRowWhoseTitleChangesHasItsLinePutBackAfter() {
        let item = Recorded()

        MenuWords.row(item, Self.working, jump: "sr-macapp", age: "2m", now: 0, isHighlighted: false)
        item.sets = []
        MenuWords.describe(item, Self.working, jump: "sr-macapp", now: 0, isHighlighted: true)
        #expect(item.sets == ["title", "subtitle nil", "subtitle SitRep · The Mac app"])
        #expect(item.subtitle == "SitRep · The Mac app")
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
