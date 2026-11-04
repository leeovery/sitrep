import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import SwiftUI
import Testing

/// The card's sections as drawn, against Paper's boards D and J taken relative to the built rows: the eyebrows, and
/// every row on one line, 30 tall, Needs you's, Your turn's and Working's, in black and in glass, each read from its
/// pixels at 2×; and the card's content, with no hairline and no "N earlier".
@MainActor
struct CardSectionsDrawnTests {
    private static let width = 344.0
    private static let ground = CGPoint(x: 1, y: 1)
    private static let size = CGSize(width: width, height: Item.lineHeight)

    private static func eyebrow(_ section: BoardSection, count: Int = 5, isFolded: Bool = false) -> Eyebrow {
        Eyebrow(section: section, count: count, isFolded: isFolded, above: 0)
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

    /// Needs you's count in Claude's orange; Your turn's and Working's in white at 30%.
    @Test(arguments: [(BoardSection.needsYou, true), (.working, false), (.yourTurn, false)])
    func anEyebrowsCountIsOrangeForNeedsYouElseFaint(section: BoardSection, isOrange: Bool) throws {
        let drawn = try Self.black(Self.eyebrow(section))
        let named = TextLine.width(TextLine.text(section.title, EdgeStyle.eyebrowTitle, EdgeStyle.eyebrow))
        let count = Self.colour(drawn, in: CGRect(x: 10 + named + 4, y: 7, width: 20, height: 14))

        #expect(Self.isClose(count, to: isOrange ? Self.orange : Self.white(0.30)))
    }

    /// Its chevron in white at 25%, ending where a row's time does, 10 in: 10 by 6 pointing down while open, 6 by 10
    /// pointing right while folded, each with its stroke's round caps.
    @Test(arguments: [false, true])
    func anEyebrowsChevronPointsDownOpenAndRightFolded(isFolded: Bool) throws {
        let drawn = try Self.black(Self.eyebrow(.yourTurn, isFolded: isFolded))
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
    private static func needs(_ name: String, lines: Int = 1, project: String = "Kit", away: Bool = false) -> Session {
        Session(
            id: "n", project: project, name: name, kind: .needs, away: away,
            lines: (0 ..< lines).map { Session.Line(ask: "k\($0)", title: "Ask \($0)", since: 0) }, sub: project
        )
    }

    private static func turn(_ title: String, project: String = "Fumi") -> Session {
        Session(id: "a", project: project, kind: .turn, title: title, sub: "\(project) · Licensing", since: 0)
    }

    private static func working(_ title: String, code: String? = nil, project: String = "DocMan") -> Session {
        Session(id: "w", project: project, kind: .working, title: title, code: code, sub: "\(project) · Fix", since: 0)
    }

    /// On its own work, still, so its colours read as drawn: "Waiting on" what it waits on.
    private static func waiting(_ subject: String, project: String = "Kit") -> Session {
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
        for session in [Self.needs("Licensing"), Self.turn("Licensing settled"), Self.working("Running ", code: "swift test")] {
            let row = try Self.row(session).row

            #expect(row.layer.bounds.height == 30)
            #expect(row.layer.cornerRadius == 10)
        }
        #expect(SessionRowLayout.radius == 10)
    }

    /// Needs you: its orange dot, 7 across with its glow, in the mark lane on the row's middle, at 16 by 15.
    @Test func aNeedsYouRowsDotIsOrangeOnItsMiddle() throws {
        let drawn = try Self.row(Self.needs("Licensing")).drawn
        let dot = try #require(drawn.pixel(at: CGPoint(x: 16, y: 15)))
        let glow = try #require(drawn.pixel(at: CGPoint(x: 16, y: 10.5)))

        #expect(Self.isClose(Self.colour(drawn, in: CGRect(x: 14, y: 13, width: 4, height: 4)), to: Self.orange))
        #expect(dot.redComponent > 0.75 && dot.blueComponent < 0.35)
        #expect(glow.lightness > 0.05)
    }

    /// Its session's name from 32, 13 medium in the text colour, wider than a your-turn row's regular of the same
    /// words; its "+2" 6 after it, in the soft grey.
    @Test func aNeedsYouRowsNameIs13MediumAndItsCount6After() throws {
        let name = "Licensing"
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
        let project = "Agentic Workflows"
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

    /// Your turn, today's one line: its open white ring 9 across at 16 by 15.
    @Test func aYourTurnRowsRingIsOpenAndWhite() throws {
        let drawn = try Self.row(Self.turn("Licensing settled")).drawn
        let ring = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 2, width: 24, height: 26), ground: Self.ground))
        let inside = try #require(drawn.pixel(at: CGPoint(x: 16, y: 15)))

        #expect(abs(ring.midX - 16) <= 0.5 && abs(ring.midY - 15) <= 0.5)
        #expect(abs(ring.width - 9) <= 0.5 && abs(ring.height - 9) <= 0.5)
        #expect(Self.isClose(Self.colour(drawn, in: ring), to: Self.rgb(0xF5F5F7)))
        #expect(inside.lightness < 0.1)
    }

    /// What Claude left Lee from 32, 13 regular in the text colour; its project in the lane, faint; its time faint.
    @Test func aYourTurnRowsWordsAre13RegularWithItsProjectAtTheRight() throws {
        let words = "Licensing settled"
        let drawn = try Self.row(Self.turn(words)).drawn
        let regular = Self.width(words, EdgeStyle.line)
        let box = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: 6 + regular + 2, height: 22), ground: Self.ground))
        let project = TextLine.width(TextLine.text("Fumi", EdgeStyle.sub, EdgeStyle.ink3))
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
        let project = "Agentic Workflows"
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
        Session(id: "k", project: "Kit", name: "The bootstrap", kind: .needs, ask: "k1", title: "Approve the plan", sub: "Kit", since: 0),
        Session(id: "t", project: "Fumi", kind: .turn, title: "Licensing settled", sub: "Fumi · Licensing", since: 0),
        Session(id: "e", project: "Terrace", kind: .turn, title: "Plan saved", sub: "Terrace · Plan", since: -86_400_000),
        Session(id: "w", project: "DocMan", kind: .working, title: "Running the tests", sub: "DocMan · Fix", since: 0),
    ]

    /// No head and no hairline: every row on one line, 30 tall, Your turn's every one, however old, each eyebrow after
    /// the first 14 under the row above it.
    @Test func theCardDrawsEveryRowOnOneLineWithNoHairline() throws {
        let content = PanelContent()
        let laid = Content(laying: Item.card(Self.mixed, folds: CardFolds()), headed: false)

        content.show(PanelList(head: nil, content: laid))

        #expect(["needs:k", "turn:t", "turn:e", "w"].allSatisfy { content.rows[$0]?.row.layer.bounds.height == 30 })
        #expect(!laid.items.contains(.divider))
        #expect(laid.itemFrame(2).minY == laid.itemFrame(1).maxY)
        #expect(laid.itemFrame(2).height == CGFloat(14 + 28))
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

    @available(macOS 26, *)
    private static func glass(_ session: Session) throws -> Drawn {
        let row = GlassSessionRow(session: session, size: Self.size, hovered: false, pressed: false, now: 5 * 60_000, wash: 0)

        return try Drawn(row, size: Self.size)
    }

    /// On glass, every row on one line as the black's: its mark at 16 by 15, its words from 32, its project never cut,
    /// ending 10 before the time lane; a Needs you row's name in medium, wider than a your-turn row's regular.
    @available(macOS 26, *)
    @Test func onGlassEveryRowIsOneLineAsTheBlacks() throws {
        let project = "Agentic Workflows"
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

        let name = "Licensing"
        let line = CGRect(x: 26, y: 4, width: 6 + Self.width(name, EdgeStyle.lineMedium) + 2, height: 22)
        let medium = try #require(Self.glass(Self.needs(name)).drawnBox(in: line, ground: Self.ground))
        let regular = try #require(Self.glass(Self.turn(name)).drawnBox(in: line, ground: Self.ground))

        #expect(medium.width - regular.width > 1)
    }
}
