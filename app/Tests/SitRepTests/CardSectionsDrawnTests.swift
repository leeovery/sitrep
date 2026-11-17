import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// The card's sections as drawn, against Paper's boards D and J taken relative to the built rows: the eyebrows, and
/// every row on one line, 30 tall, Needs you's asks and turns and Working's, in black and in glass, each read from its
/// pixels at 2×; and the card's content, with no hairline and no "N earlier".
@MainActor
@Suite(.backstop)
struct CardSectionsDrawnTests {
    private static let width = 344.0
    private static let ground = CGPoint(x: 1, y: 1)
    private static let size = CGSize(width: width, height: Item.lineHeight)

    /// A section's eyebrow counting 5: Needs you's asks, or another section whole.
    private static func eyebrow(_ section: BoardSection, isFolded: Bool = false) -> Eyebrow {
        let count = Eyebrow.Count(5, need: section == .needsYou ? .ask : nil)

        return Eyebrow(section: section, counts: [count], isFolded: isFolded, above: 0)
    }

    private static func black(_ eyebrow: Eyebrow) throws -> Drawn {
        try Drawn(CardParts.eyebrow(eyebrow, size: CGSize(width: width, height: Item.eyebrowHeight)))
    }

    /// Its brightest red, green and blue in `rect`, as stored.
    private static func colour(_ drawn: Drawn, in rect: CGRect) -> [CGFloat] {
        let step = 1 / drawn.scale
        let points = stride(from: rect.minY, to: rect.maxY, by: step).flatMap { y in
            stride(from: rect.minX, to: rect.maxX, by: step).map { CGPoint(x: $0, y: y) }
        }
        let brightest = points.compactMap(drawn.stored).max { $0.lightness < $1.lightness }

        return brightest.map { [$0.redComponent, $0.greenComponent, $0.blueComponent] } ?? []
    }

    private static func isClose(_ colour: [CGFloat], to wanted: [CGFloat], within: CGFloat = 3 / 255) -> Bool {
        colour.count == 3 && zip(colour, wanted).allSatisfy { abs($0 - $1) <= within }
    }

    private static let orange: [CGFloat] = [0xE9, 0x64, 0x3D].map { CGFloat($0) / 255 }

    private static func white(_ alpha: CGFloat) -> [CGFloat] { [alpha, alpha, alpha] }

    private static func rgb(_ hex: UInt32) -> [CGFloat] {
        [hex >> 16 & 0xFF, hex >> 8 & 0xFF, hex & 0xFF].map { CGFloat($0) / 255 }
    }

    // MARK: Eyebrows, black

    /// Its name 10 in, in its line of 14 on the 28's middle, in white at 55%; its count 6 after it.
    @Test func anEyebrowsNameSits10InOnItsMiddleInWhiteAt55() throws {
        let drawn = try Self.black(Self.eyebrow(.working))
        let name = try #require(drawn.drawnBox(in: CGRect(x: 0, y: 0, width: 100, height: 28), ground: Self.ground))
        let named = TextLine.width(TextLine.text("Working", EdgeStyle.eyebrowTitle, EdgeStyle.eyebrow))

        #expect((10 ... 11).contains(name.minX))
        #expect(name.minY >= 7 && name.maxY <= 21)
        #expect(Self.isClose(Self.colour(drawn, in: CGRect(x: 10, y: 7, width: named, height: 14)), to: Self.white(0.55)))

        let count = try #require(drawn.drawnBox(in: CGRect(x: 10 + named + 2, y: 0, width: 40, height: 28), ground: Self.ground))

        #expect(abs(count.minX - (10 + named + 6)) <= 1)
    }

    /// Needs you's asks in Claude's orange; Working's count in white at 30%.
    @Test(arguments: [(BoardSection.needsYou, true), (.working, false)])
    func anEyebrowsCountIsOrangeForNeedsYouElseFaint(section: BoardSection, isOrange: Bool) throws {
        let drawn = try Self.black(Self.eyebrow(section))
        let named = TextLine.width(TextLine.text(section.title, EdgeStyle.eyebrowTitle, EdgeStyle.eyebrow))
        let count = Self.colour(drawn, in: CGRect(x: 10 + named + 4, y: 7, width: 20, height: 14))

        #expect(Self.isClose(count, to: isOrange ? Self.orange : Self.white(0.30)))
    }

    private static func needsYou(asks: Int, stopped: Int) -> Eyebrow {
        let counts = [Eyebrow.Count(asks, need: .ask), Eyebrow.Count(stopped, need: .turn)].filter { $0.value > 0 }

        return Eyebrow(section: .needsYou, counts: counts, isFolded: false, above: 0)
    }

    /// Needs you's two counts side by side, 6 after its name and 6 apart, its asks in orange then its stopped in blue,
    /// each only above zero, each gap measured from the figures before it: 2 and 8, 24 and 305, asks alone and stopped
    /// alone.
    @Test(arguments: [(2, 8), (24, 305), (2, 0), (0, 8)])
    func needsYousCountsAreItsAsksInOrangeThenItsStoppedInBlue(asks: Int, stopped: Int) throws {
        let drawn = try Self.black(Self.needsYou(asks: asks, stopped: stopped))
        let named = TextLine.width(TextLine.text("Needs you", EdgeStyle.eyebrowTitle, EdgeStyle.eyebrow))
        let wanted = [(asks, Self.orange), (stopped, Self.rgb(0x3F93FB))].filter { $0.0 > 0 }
        var start = 10 + named + 6

        for (value, colour) in wanted {
            let wide = TextLine.width(TextLine.text("\(value)", EdgeStyle.eyebrowFigures, EdgeStyle.orange))
            let lane = CGRect(x: start - 2, y: 0, width: wide + 3, height: 28)
            let figure = try #require(drawn.drawnBox(in: lane, ground: Self.ground))

            #expect(abs(figure.minX - start) <= 1)
            #expect(Self.isClose(Self.colour(drawn, in: figure), to: colour))
            start += wide + 6
        }

        let rest = CGRect(x: start - 4, y: 0, width: Self.width - 30 - start, height: 28)

        #expect(drawn.drawnBox(in: rest, ground: Self.ground) == nil)
    }

    /// Its chevron in white at 25%, ending where a row's time does, 10 in: 10 by 6 pointing down while open, 6 by 10
    /// pointing right while folded, each with its stroke's round caps.
    @Test(arguments: [false, true])
    func anEyebrowsChevronPointsDownOpenAndRightFolded(isFolded: Bool) throws {
        let drawn = try Self.black(Self.eyebrow(.needsYou, isFolded: isFolded))
        let lane = CGRect(x: Self.width - 7.5 - 15, y: 2, width: 15, height: 24)
        let chevron = try #require(drawn.drawnBox(in: lane, ground: Self.ground))
        let (wide, tall) = isFolded ? (6.0, 10.0) : (10.0, 6.0)

        #expect(abs(chevron.width - wide) <= 1.5 && abs(chevron.height - tall) <= 1.5)
        #expect(abs(chevron.midY - 14) <= 0.5)
        #expect(abs(chevron.midX - (Self.width - 15)) <= 0.5)
        #expect(Self.isClose(Self.colour(drawn, in: chevron), to: Self.white(0.25)))
    }

    // MARK: Rows, black

    private static let long = "What Claude left you is longer than the row could ever hold on its one line, so it is cut short"

    /// A row on one line, as the card lays it out, its time five minutes on.
    private static func row(_ session: Session) throws -> (row: SessionRow, drawn: Drawn) {
        let row = SessionRow(session, size: Self.size)

        row.showAge(at: 5 * 60_000)
        return (row, try Drawn(row.layer))
    }

    /// A Needs you row: its session's name, and a line for each ask.
    private static func needs(_ name: String, lines: Int = 1, project: String = "Litware", away: Bool = false) -> Session {
        Session(
            id: "n", project: project, name: name, kind: .needs, away: away,
            lines: (0 ..< lines).map { Session.Line(ask: "k\($0)", title: "Ask \($0)", since: 0) }, sub: project
        )
    }

    private static func turn(_ title: String, project: String = "Wingtip") -> Session {
        Session(id: "a", project: project, kind: .turn, title: title, sub: "\(project) · Inventory", since: 0)
    }

    private static func working(_ title: String, code: String? = nil, project: String = "Coho") -> Session {
        Session(id: "w", project: project, kind: .working, title: title, code: code, sub: "\(project) · Fix", since: 0)
    }

    /// On its own work, still, so its colours read as drawn: "Waiting on" what it waits on.
    private static func waiting(_ subject: String, project: String = "Litware") -> Session {
        Session(
            id: "o", project: project, kind: .onItsWork, title: "Waiting on ", subject: subject, sub: "\(project) · Boot",
            since: 0
        )
    }

    private static func width(_ words: String, _ font: NSFont) -> CGFloat {
        TextLine.width(TextLine.text(words, font, EdgeStyle.ink, kern: EdgeStyle.tightKern(font)))
    }

    /// Every row 30 tall, its lift's corners 10, whatever its section, so two lifts side by side meet.
    @Test func everyRowIsOneLine30TallItsLift10() throws {
        for session in [Self.needs("Inventory"), Self.turn("Inventory settled"), Self.working("Running ", code: "swift test")] {
            let row = try Self.row(session).row

            #expect(row.layer.bounds.height == 30)
            #expect(row.layer.cornerRadius == 10)
        }
        #expect(SessionRowLayout.radius == 10)
    }

    /// Needs you: its orange dot, 7 across with its glow, in the mark lane on the row's middle, at 16 by 15.
    @Test func aNeedsYouRowsDotIsOrangeOnItsMiddle() throws {
        let drawn = try Self.row(Self.needs("Inventory")).drawn
        let dot = try #require(drawn.pixel(at: CGPoint(x: 16, y: 15)))
        let glow = try #require(drawn.pixel(at: CGPoint(x: 16, y: 10.5)))

        #expect(Self.isClose(Self.colour(drawn, in: CGRect(x: 14, y: 13, width: 4, height: 4)), to: Self.orange))
        #expect(dot.redComponent > 0.75 && dot.blueComponent < 0.35)
        #expect(glow.lightness > 0.05)
    }

    /// Its session's name from 32, 13 medium in the text colour, wider than a your-turn row's regular of the same
    /// words; its "3" 6 after it, in the soft grey.
    @Test func aNeedsYouRowsNameIs13MediumAndItsCount6After() throws {
        let name = "Inventory"
        let drawn = try Self.row(Self.needs(name, lines: 3)).drawn
        let medium = Self.width(name, EdgeStyle.lineMedium)
        let title = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: 6 + medium + 2, height: 22), ground: Self.ground))
        let count = try #require(drawn.drawnBox(in: CGRect(x: 32 + medium + 3, y: 4, width: 30, height: 22), ground: Self.ground))
        let regular = try #require(Self.row(Self.turn(name)).drawn.drawnBox(
            in: CGRect(x: 26, y: 4, width: 6 + medium + 2, height: 22), ground: Self.ground
        ))

        #expect((32 ... 33.5).contains(title.minX))
        #expect(title.width <= medium + 0.5 && title.width >= medium - 3)
        #expect(title.width - regular.width > 1)
        #expect(Self.isClose(Self.colour(drawn, in: title), to: Self.rgb(0xF5F5F7)))
        #expect(abs(count.minX - (32 + medium + SessionRowLayout.countGap)) <= 1.5)
        #expect(Self.isClose(Self.colour(drawn, in: count), to: Self.rgb(0x98989F)))
    }

    /// Its project in the lane at the right, faint, never cut while its name is; its time in the 36 lane.
    @Test func aNeedsYouRowsProjectIsInItsLaneNeverCut() throws {
        let project = "Wide World Importers"
        let drawn = try Self.row(Self.needs(Self.long, lines: 2, project: project)).drawn
        let whole = TextLine.width(TextLine.text(project, EdgeStyle.sub, EdgeStyle.ink3))
        let lane = CGRect(x: 288 - whole - 1, y: 4, width: whole + 2, height: 22)
        let drawnProject = try #require(drawn.drawnBox(in: lane, ground: Self.ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: lane.minX - 26, height: 22), ground: Self.ground))
        let age = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 4, width: 54, height: 22), ground: Self.ground))

        #expect(abs(drawnProject.maxX - 288) <= 1 && abs(drawnProject.width - whole) <= 1.5)
        #expect(words.maxX <= 288 - whole - 12 + 0.5)
        #expect(Self.isClose(Self.colour(drawn, in: drawnProject), to: Self.rgb(0x5C5C63)))
        #expect((332.5 ... 334.5).contains(age.maxX))
    }

    /// Your turn, today's one line: its blue dot, 7 across with its glow, as an ask's orange one, at 16 by 15 (13
    /// November 2026; an open white ring 9 across until then).
    @Test func aYourTurnRowsDotIsBlueOnItsMiddle() throws {
        let drawn = try Self.row(Self.turn("Inventory settled")).drawn
        let dot = try #require(drawn.pixel(at: CGPoint(x: 16, y: 15)))
        let glow = try #require(drawn.pixel(at: CGPoint(x: 16, y: 10.5)))

        #expect(Self.isClose(Self.colour(drawn, in: CGRect(x: 14, y: 13, width: 4, height: 4)), to: Self.rgb(0x3F93FB)))
        #expect(dot.blueComponent > 0.75 && dot.redComponent < 0.35)
        #expect(glow.lightness > 0.05)
    }

    /// What Claude left Lee from 32, 13 regular in the text colour; its project in the lane, faint; its time faint.
    @Test func aYourTurnRowsWordsAre13RegularWithItsProjectAtTheRight() throws {
        let words = "Inventory settled"
        let drawn = try Self.row(Self.turn(words)).drawn
        let regular = Self.width(words, EdgeStyle.line)
        let box = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: 6 + regular + 2, height: 22), ground: Self.ground))
        let project = TextLine.width(TextLine.text("Wingtip", EdgeStyle.sub, EdgeStyle.ink3))
        let lane = try #require(drawn.drawnBox(in: CGRect(x: 288 - project - 1, y: 4, width: project + 2, height: 22), ground: Self.ground))
        let age = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 4, width: 54, height: 22), ground: Self.ground))

        #expect((32 ... 33.5).contains(box.minX))
        #expect(box.width <= regular + 0.5 && box.width >= regular - 3)
        #expect(Self.isClose(Self.colour(drawn, in: box), to: Self.rgb(0xF5F5F7)))
        #expect(Self.isClose(Self.colour(drawn, in: lane), to: Self.rgb(0x5C5C63)))
        #expect(Self.isClose(Self.colour(drawn, in: age), to: Self.rgb(0x5C5C63)))
    }

    /// Its arc 11 across in the mark lane on the row's middle, at 16 by 15.
    @Test func aWorkingRowsArcIsOnItsMiddle() throws {
        let drawn = try Self.row(Self.working("Running ", code: "swift test")).drawn
        let arc = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 2, width: 24, height: 26), ground: Self.ground))

        #expect(abs(arc.midX - 16) <= 0.5 && abs(arc.midY - 15) <= 0.5)
        #expect(abs(arc.width - 11) <= 1.5)
    }

    /// Its verb 13 medium in #B4B4BA, from 32; 6 after it what it waits on, 13 regular in #8E8E95.
    @Test func aWorkingRowsVerbIs13MediumAndItsSubject6After() throws {
        let drawn = try Self.row(Self.waiting("3 agents")).drawn
        let verb = Self.width("Waiting on", EdgeStyle.lineMedium)
        let lead = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: 6 + verb, height: 22), ground: Self.ground))
        let subject = try #require(drawn.drawnBox(in: CGRect(x: 32 + verb + 2, y: 4, width: 120, height: 22), ground: Self.ground))
        let set = TextLine.width(TextLine.text("3 agents", EdgeStyle.line, EdgeStyle.grey, kern: EdgeStyle.tightKern(EdgeStyle.line)))

        #expect((32 ... 33.5).contains(lead.minX))
        #expect(abs(lead.width - verb) <= 1.5)
        #expect(abs(subject.minX - (32 + verb + LineTitle.gap)) <= 1.5)
        #expect(abs(subject.width - set) <= 1.5)
        #expect(Self.isClose(Self.colour(drawn, in: lead), to: Self.rgb(0xB4B4BA)))
        #expect(Self.isClose(Self.colour(drawn, in: subject), to: Self.rgb(0x8E8E95)))
    }

    /// A command after the verb is set in mono at 12, 6 after it.
    @Test func aWorkingRowsCommandIsMono12() throws {
        let drawn = try Self.row(Self.working("Running ", code: "swift test")).drawn
        let verb = Self.width("Running", EdgeStyle.lineMedium)
        let code = try #require(drawn.drawnBox(in: CGRect(x: 32 + verb + 2, y: 4, width: 150, height: 22), ground: Self.ground))
        let set = TextLine.width(TextLine.text("swift test", EdgeStyle.lineCode, EdgeStyle.grey))

        #expect(abs(code.minX - (32 + verb + LineTitle.gap)) <= 1.5)
        // drawn inside its set width by the glyphs' side bearings, wider in mono
        #expect(code.width <= set + 0.5 && code.width >= set - 3)
    }

    /// Its project in a lane at the right, its own width, ending 10 before the time lane, faint: never cut while the
    /// words before it are, which end 12 before it. The session's name shows nowhere on it.
    @Test func aWorkingRowsProjectIsNeverCutWhileItsWordsAre() throws {
        let project = "Wide World Importers"
        let drawn = try Self.row(Self.waiting(Self.long, project: project)).drawn
        let whole = TextLine.width(TextLine.text(project, EdgeStyle.sub, EdgeStyle.ink3))
        let lane = CGRect(x: 288 - whole - 1, y: 4, width: whole + 2, height: 22)
        let drawnProject = try #require(drawn.drawnBox(in: lane, ground: Self.ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: lane.minX - 26, height: 22), ground: Self.ground))

        #expect(abs(drawnProject.maxX - 288) <= 1)
        #expect(abs(drawnProject.width - whole) <= 1.5)
        #expect(words.maxX <= 288 - whole - 12 + 0.5)
        #expect(Self.isClose(Self.colour(drawn, in: drawnProject), to: Self.rgb(0x5C5C63)))
    }

    @Test func aWorkingRowsTimeIsInItsLane() throws {
        let drawn = try Self.row(Self.working("Running ", code: "swift test")).drawn
        let age = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 4, width: 54, height: 22), ground: Self.ground))

        #expect((332.5 ... 334.5).contains(age.maxX))
        #expect(age.minY >= 6 && age.maxY <= 24)
    }

    // MARK: The black card's content

    private static let mixed = [
        Session(id: "k", project: "Litware", name: "The installer", kind: .needs, ask: "k1", title: "Approve the plan", sub: "Litware", since: 0),
        Session(id: "t", project: "Wingtip", kind: .turn, title: "Inventory settled", sub: "Wingtip · Inventory", since: 0),
        Session(id: "e", project: "Humongous", kind: .turn, title: "Plan saved", sub: "Humongous · Plan", since: -86_400_000),
        Session(id: "w", project: "BlueYonder", kind: .working, title: "Running the tests", sub: "BlueYonder · Fix", since: 0),
    ]

    /// No head and no hairline: every row on one line, 30 tall, every turn, however old, in Needs you under its ask,
    /// each eyebrow after the first 14 under the row above it.
    @Test func theCardDrawsEveryRowOnOneLineWithNoHairline() throws {
        let content = PanelContent()
        let laid = Content(laying: Item.card(Self.mixed, folds: CardFolds()), headed: false)

        content.show(PanelList(head: nil, content: laid))

        expectEvery(["needs:k", "turn:t", "turn:e", "w"]) { content.rows[$0]?.row.layer.bounds.height == 30 }
        #expect(!laid.items.contains(.divider))
        #expect(laid.items.map(\.key) == ["eyebrow:needsYou", "needs:k", "turn:t", "turn:e", "eyebrow:working", "w"])
        #expect(laid.itemFrame(4).minY == laid.itemFrame(3).maxY)
        #expect(laid.itemFrame(4).height == CGFloat(14 + 28))
    }

    // MARK: Glass

    /// On glass, as the black lays it out: its name from 10, its count orange for Needs you, its chevron ending 10
    /// in.
    @available(macOS 26, *)
    @Test(arguments: [(BoardSection.needsYou, true), (.working, false)])
    func onGlassAnEyebrowIsLaidOutAsTheBlacks(section: BoardSection, isOrange: Bool) throws {
        let size = CGSize(width: Self.width, height: Item.eyebrowHeight)
        let drawn = try Drawn(GlassEyebrow(eyebrow: Self.eyebrow(section), size: size), size: size)
        let name = try #require(drawn.drawnBox(in: CGRect(x: 0, y: 0, width: 60, height: 28), ground: Self.ground))
        let named = TextLine.width(TextLine.text(section.title, EdgeStyle.eyebrowTitle, EdgeStyle.eyebrow))
        let count = Self.colour(drawn, in: CGRect(x: 10 + named + 4, y: 7, width: 20, height: 14))
        let chevron = try #require(drawn.drawnBox(in: CGRect(x: Self.width - 22.5, y: 2, width: 15, height: 24), ground: Self.ground))

        #expect((10 ... 11).contains(name.minX))
        #expect(abs(chevron.midX - (Self.width - 15)) <= 0.5 && abs(chevron.midY - 14) <= 0.5)
        #expect(chevron.width > chevron.height)
        // the window stores its own colour space, so the orange reads as warm, the rest as grey
        #expect(count.count == 3 && (count[0] - count[2] > 0.3) == isOrange)
    }

    /// On glass, Needs you's two counts as the black's: its asks warm, then its stopped blue, 6 apart.
    @available(macOS 26, *)
    @Test func onGlassNeedsYousCountsAreItsAsksThenItsStopped() throws {
        let size = CGSize(width: Self.width, height: Item.eyebrowHeight)
        let drawn = try Drawn(GlassEyebrow(eyebrow: Self.needsYou(asks: 2, stopped: 8), size: size), size: size)
        let named = TextLine.width(TextLine.text("Needs you", EdgeStyle.eyebrowTitle, EdgeStyle.eyebrow))
        let wide = TextLine.width(TextLine.text("2", EdgeStyle.eyebrowFigures, EdgeStyle.orange))
        let asks = Self.colour(drawn, in: CGRect(x: 10 + named + 6, y: 7, width: wide, height: 14))
        let stopped = Self.colour(drawn, in: CGRect(x: 10 + named + 6 + wide + 6, y: 7, width: wide, height: 14))

        // the window stores its own colour space, so each reads by its lean, warm or blue
        #expect(asks.count == 3 && asks[0] - asks[2] > 0.3)
        #expect(stopped.count == 3 && stopped[2] - stopped[0] > 0.3)
    }

    @available(macOS 26, *)
    private static func glass(_ session: Session) throws -> Drawn {
        let row = GlassSessionRow(session: session, size: Self.size, hovered: false, pressed: false, now: 5 * 60_000, wash: 0)

        return try Drawn(row, size: Self.size)
    }

    /// On glass, every row on one line as the black's: its mark at 16 by 15, its words from 32, its project never cut,
    /// ending 10 before the time lane; a Needs you row's name in medium, wider than a your-turn row's regular.
    @available(macOS 26, *)
    @Test func onGlassEveryRowIsOneLineAsTheBlacks() throws {
        let project = "Wide World Importers"
        let whole = TextLine.width(TextLine.text(project, EdgeStyle.sub, EdgeStyle.ink3))
        let lane = CGRect(x: 288 - whole - 1, y: 4, width: whole + 2, height: 22)

        for session in [Self.needs(Self.long, project: project), Self.turn(Self.long, project: project), Self.waiting(Self.long, project: project)] {
            let drawn = try Self.glass(session)
            let mark = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 2, width: 24, height: 26), ground: Self.ground))
            let drawnProject = try #require(drawn.drawnBox(in: lane, ground: Self.ground))
            let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: lane.minX - 26, height: 22), ground: Self.ground))

            #expect(abs(mark.midX - 16) <= 0.5 && abs(mark.midY - 15) <= 0.5)
            #expect((32 ... 33.5).contains(words.minX))
            #expect(words.maxX <= 288 - whole - 12 + 0.5)
            #expect(abs(drawnProject.maxX - 288) <= 1 && abs(drawnProject.width - whole) <= 1.5)
        }

        let name = "Inventory"
        let line = CGRect(x: 26, y: 4, width: 6 + Self.width(name, EdgeStyle.lineMedium) + 2, height: 22)
        let medium = try #require(Self.glass(Self.needs(name)).drawnBox(in: line, ground: Self.ground))
        let regular = try #require(Self.glass(Self.turn(name)).drawnBox(in: line, ground: Self.ground))

        #expect(medium.width - regular.width > 1)
    }

    /// How wide words are inked on glass in this font and label colour, drawn whole on a line of their own from this
    /// far in, so their edges fall on the pixels, and as faint, as a row's do.
    @available(macOS 26, *)
    private static func inked(
        _ words: String, _ font: NSFont, _ ink: HierarchicalShapeStyle, from x: Double,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> CGFloat {
        let size = CGSize(width: Self.width, height: Item.lineHeight)
        let text = Text(words).font(Font(font)).foregroundStyle(ink).fixedSize().offset(x: x)
        let drawn = try Drawn(text.frame(width: size.width, alignment: .leading), size: size)
        let box = drawn.drawnBox(in: CGRect(origin: .zero, size: size), ground: Self.ground)

        return try #require(box, sourceLocation: sourceLocation).width
    }

    /// Words its font's kerning pairs set wider than they set with the pairs off: what a line set unkerned would cut.
    private static func requireWidenedByPairs(
        _ words: String, _ font: NSFont, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> CGFloat {
        let paired = TextLine.width(NSAttributedString(string: words, attributes: [.font: font]))
        let unpaired = TextLine.width(NSAttributedString(string: words, attributes: [.font: font, .kern: 0]))

        try #require(paired > unpaired, sourceLocation: sourceLocation)
        return paired
    }

    /// On glass, a project its kerning pairs widen is drawn whole in its lane, ending 10 before the time lane, as the
    /// black and glass both set it kerned.
    @available(macOS 26, *)
    @Test(arguments: ["Lucerne Publishing", "Coho Winery"])
    func onGlassAProjectItsPairsWidenIsDrawnWhole(project: String) throws {
        let set = try Self.requireWidenedByPairs(project, EdgeStyle.sub)
        let drawn = try Self.glass(Self.turn("Inventory settled", project: project))
        let lane = try #require(drawn.drawnBox(in: CGRect(x: 288 - set - 4, y: 4, width: set + 6, height: 22), ground: Self.ground))
        let whole = try Self.inked(project, EdgeStyle.sub, .tertiary, from: 288 - set)

        #expect(abs(lane.maxX - 288) <= 1)
        #expect((whole - 0.5 ... whole + 0.5).contains(lane.width), "inked \(lane.width) of \(whole)")
    }

    /// On glass, a wake in October, whose month its kerning pairs widen, is drawn whole in its time's place, ending at
    /// 334.
    @available(macOS 26, *)
    @Test func onGlassAnOctoberWakeIsDrawnWhole() throws {
        var utc = Calendar(identifier: .gregorian)

        utc.timeZone = try #require(TimeZone(identifier: "UTC"))

        let october = Double(273 * 86_400 + 9 * 3_600) * 1000
        let turn = Session(
            id: "t", project: "Wingtip", name: "Inventory", kind: .snoozedTurn,
            lines: [Session.Line(title: "Settled", since: 0)], sub: "Wingtip", wakesAt: october
        )
        let words = turn.timeText(at: 0, in: utc)

        try #require(words == "1 Oct 09:00")

        let set = try Self.requireWidenedByPairs(words, EdgeStyle.age)
        let row = GlassSessionRow(session: turn, size: Self.size, hovered: false, pressed: false, now: 0, wash: 0, calendar: utc)
        let drawn = try Drawn(row, size: Self.size)
        let time = try #require(drawn.drawnBox(in: CGRect(x: 330 - set, y: 4, width: set + 14, height: 22), ground: Self.ground))
        let whole = try Self.inked(words, EdgeStyle.age, .secondary, from: 334 - set)

        #expect(abs(time.maxX - 334) <= 1.5)
        #expect((whole - 0.5 ... whole + 0.5).contains(time.width), "inked \(time.width) of \(whole)")
    }

    /// On glass, a turn snoozed is a dot 7 across at 16 by 15, as a snoozed ask's is, its blue dimmed
    /// (`NeedsYouMarksTests`); "until it moves" in its time's place, ending at 334, as wide as glass sets it. Kerning
    /// narrows the phrase, so this guards its place, not its kerning (`onGlassAnOctoberWakeIsDrawnWhole` does that).
    @available(macOS 26, *)
    @Test func onGlassASnoozedTurnIsADotUntilItMoves() throws {
        let turn = Session(id: "t", project: "Wingtip", name: "Inventory", kind: .snoozedTurn, title: "Settled", sub: "Wingtip", since: 0)
        let drawn = try Self.glass(turn)
        let dot = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 2, width: 24, height: 26), ground: Self.ground))
        let wide = TextLine.width(TextLine.text(WakeTime.untilItMoves, EdgeStyle.age, EdgeStyle.ink2))
        let time = try #require(drawn.drawnBox(in: CGRect(x: 330 - wide, y: 4, width: wide + 14, height: 22), ground: Self.ground))
        let whole = try Self.inked(WakeTime.untilItMoves, EdgeStyle.age, .secondary, from: 334 - wide)

        #expect(abs(dot.width - 7) <= 1 && abs(dot.height - 7) <= 1)
        #expect(abs(dot.midX - 16) <= 0.5 && abs(dot.midY - 15) <= 0.5)
        #expect(abs(time.maxX - 334) <= 1.5 && abs(time.width - whole) <= 1)
    }
}
