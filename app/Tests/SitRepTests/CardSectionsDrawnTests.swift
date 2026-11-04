import AppKit
@testable import SitRep
import SitRepEdge
import SitRepPanel
import SwiftUI
import Testing

/// The card's sections as drawn, against Paper's boards D and I taken relative to the built rows: the eyebrows, a
/// your-turn row on two lines, a Working row on one line and "N earlier", in black and in glass, each read from its
/// pixels at 2×.
@MainActor
struct CardSectionsDrawnTests {
    private static let width = 344.0
    private static let ground = CGPoint(x: 1, y: 1)

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

    private static func rgb(_ hex: UInt32) -> [CGFloat] {
        [hex >> 16 & 0xFF, hex >> 8 & 0xFF, hex & 0xFF].map { CGFloat($0) / 255 }
    }

    // MARK: A your-turn row, black

    private static func turn(_ title: String, project: String = "Fumi") -> Session {
        Session(id: "a", project: project, kind: .turn, title: title, sub: "\(project) · Licensing", since: 0)
    }

    /// A your-turn row drawn whole, as the card lays it out: its item's height, less the gap under it.
    private static func turnRow(_ session: Session) throws -> (row: SessionRow, drawn: Drawn) {
        let row = SessionRow(session, size: CGSize(width: width, height: Item.session(session).height - Item.rowGap))

        row.showAge(at: 5 * 60_000)
        return (row, try Drawn(row.layer))
    }

    private static let long = "What Claude left you is longer than the row could ever hold on its one line, so it is cut short"

    /// Two lines, 49 tall like a Needs you row; its ring 9 across, in white, in the mark lane on the first line, at 16
    /// by 16, the Needs you dot's place.
    @Test func aYourTurnRowIsTwoLines49TallWithItsRingOnTheFirst() throws {
        let (row, drawn) = try Self.turnRow(Self.turn("Licensing settled"))
        let ring = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 5, width: 24, height: 22), ground: Self.ground))

        #expect(row.layer.bounds.height == 49 && !row.isOneLine)
        #expect(abs(ring.midX - 16) <= 0.5 && abs(ring.midY - 16) <= 0.5)
        #expect(abs(ring.width - 9) <= 0.5 && abs(ring.height - 9) <= 0.5)
        #expect(Self.isClose(Self.colour(drawn, in: ring), to: Self.rgb(0xF5F5F7)))
        #expect(row.layer.cornerRadius == 10)
    }

    /// What Claude left Lee, from 32 on the first line, 14 regular, narrower than the medium a Needs you row's name of
    /// the same words is drawn in, in the text colour, cut short before the time.
    @Test func aYourTurnRowsWordsAre14Regular() throws {
        let words = "Licensing settled"
        let line = CGRect(x: 26, y: 5, width: 250, height: 20)
        let drawn = try Self.turnRow(Self.turn(words)).drawn
        let needs = Session(id: "n", project: "Fumi", name: words, kind: .needs, title: "Ask", sub: "Fumi", since: 0)
        let box = try #require(drawn.drawnBox(in: line, ground: Self.ground))
        let named = try #require(Self.turnRow(needs).drawn.drawnBox(in: line, ground: Self.ground))
        let regular = TextLine.width(TextLine.text(words, EdgeStyle.subject, EdgeStyle.ink, kern: EdgeStyle.tightKern(EdgeStyle.subject)))
        let cut = try #require(Self.turnRow(Self.turn(Self.long)).drawn.drawnBox(
            in: CGRect(x: 26, y: 5, width: 270, height: 20), ground: Self.ground
        ))

        #expect((32 ... 33.5).contains(box.minX))
        // drawn inside its set width by the glyphs' side bearings
        #expect(box.width <= regular + 0.5 && box.width >= regular - 3)
        #expect(named.width - box.width > 1)
        #expect(Self.isClose(Self.colour(drawn, in: box), to: Self.rgb(0xF5F5F7)))
        #expect(cut.maxX <= 288.5)
    }

    /// Under its words, "project · session" from 32, 12 in the soft grey.
    @Test func aYourTurnRowsSecondLineIsItsProjectAndSession() throws {
        let drawn = try Self.turnRow(Self.turn("Licensing settled")).drawn
        let line = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 25, width: 300, height: 16), ground: Self.ground))
        let set = TextLine.width(TextLine.text("Fumi · Licensing", EdgeStyle.sub, EdgeStyle.ink2))

        #expect((32 ... 33.5).contains(line.minX))
        #expect(line.width <= set + 0.5 && line.width >= set - 3)
        #expect(Self.isClose(Self.colour(drawn, in: line), to: Self.rgb(0x98989F)))
    }

    /// Its time faint, in the lane ending at 334, on the first line.
    @Test func aYourTurnRowsTimeIsFaintOnItsFirstLine() throws {
        let drawn = try Self.turnRow(Self.turn("Licensing settled")).drawn
        let age = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 5, width: 54, height: 22), ground: Self.ground))

        #expect((332.5 ... 334.5).contains(age.maxX))
        #expect(age.minY >= 7 && age.maxY <= 25)
        #expect(Self.isClose(Self.colour(drawn, in: age), to: Self.rgb(0x5C5C63)))
    }

    // MARK: A Working row, black

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

    private static func lineRow(_ session: Session) throws -> (row: SessionRow, drawn: Drawn) {
        let row = SessionRow(session, size: CGSize(width: width, height: Item.lineHeight), oneLine: true)

        row.showAge(at: 5 * 60_000)
        return (row, try Drawn(row.layer))
    }

    private static func verbWidth(_ verb: String) -> CGFloat {
        TextLine.width(TextLine.text(verb, EdgeStyle.lineVerb, EdgeStyle.ink, kern: EdgeStyle.tightKern(EdgeStyle.lineVerb)))
    }

    /// One line, 30 tall, its arc 11 across in the mark lane on the row's middle, at 16 by 15; its lift's corners 14.
    @Test func aWorkingRowIsOneLine30TallWithItsArc() throws {
        let (row, drawn) = try Self.lineRow(Self.working("Running ", code: "swift test"))
        let arc = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 2, width: 24, height: 26), ground: Self.ground))

        #expect(row.layer.bounds.height == 30 && row.isOneLine)
        #expect(abs(arc.midX - 16) <= 0.5 && abs(arc.midY - 15) <= 0.5)
        #expect(abs(arc.width - 11) <= 1.5)
        #expect(row.layer.cornerRadius == 14)
    }

    /// Its verb 13 medium in #B4B4BA, from 32; 6 after it what it waits on, 13 regular in #8E8E95.
    @Test func aWorkingRowsVerbIs13MediumAndItsSubject6After() throws {
        let drawn = try Self.lineRow(Self.waiting("3 agents")).drawn
        let verb = Self.verbWidth("Waiting on")
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
        let drawn = try Self.lineRow(Self.working("Running ", code: "swift test")).drawn
        let verb = Self.verbWidth("Running")
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
        let drawn = try Self.lineRow(Self.waiting(Self.long, project: project)).drawn
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
        let drawn = try Self.lineRow(Self.working("Running ", code: "swift test")).drawn
        let age = try #require(drawn.drawnBox(in: CGRect(x: 290, y: 4, width: 54, height: 22), ground: Self.ground))

        #expect((332.5 ... 334.5).contains(age.maxX))
        #expect(age.minY >= 6 && age.maxY <= 24)
    }

    // MARK: N earlier, black

    private static func earlier(_ projects: [String], isOpen: Bool = false) -> Earlier {
        Earlier(projects.enumerated().map { Self.turnSession("s\($0)", project: $1) }, isOpen: isOpen)
    }

    private static func turnSession(_ id: String, project: String) -> Session {
        Session(id: id, project: project, kind: .turn, title: "Your turn", sub: "", since: 0)
    }

    private static func black(_ earlier: Earlier) throws -> Drawn {
        try Drawn(CardParts.earlier(earlier, size: CGSize(width: width, height: Item.earlierHeight)).layer)
    }

    /// Its ring in white at 35%, "8 earlier" in the soft grey from 32, and the projects faint after it.
    @Test func nEarliersRingWordsAndProjects() throws {
        let earlier = Self.earlier(["Terrace", "Fumi", "Terrace"])
        let drawn = try Self.black(earlier)
        let ring = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 4, width: 24, height: 26), ground: Self.ground))
        let title = TextLine.width(TextLine.text("3 earlier", EdgeStyle.line, EdgeStyle.ink2, kern: EdgeStyle.tightKern(EdgeStyle.line)))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: title + 8, height: 26), ground: Self.ground))

        #expect(earlier.projects == ["Terrace", "Fumi"])
        #expect(abs(ring.midX - 16) <= 0.5 && abs(ring.midY - 17) <= 0.5 && abs(ring.width - 9) <= 0.5)
        #expect(Self.isClose(Self.colour(drawn, in: ring), to: Self.white(0.35)))
        #expect((32 ... 33.5).contains(words.minX))
        #expect(Self.isClose(Self.colour(drawn, in: CGRect(x: 32, y: 8, width: title, height: 18)), to: [0x98, 0x98, 0x9F].map { CGFloat($0) / 255 }))
        #expect(Self.isClose(Self.colour(drawn, in: CGRect(x: 32 + title + 7, y: 8, width: 60, height: 18)), to: [0x5C, 0x5C, 0x63].map { CGFloat($0) / 255 }))
    }

    /// The projects cut short before the chevron's box, which keeps its chevron: right while folded, down while open.
    @Test(arguments: [false, true])
    func nEarliersProjectsAreCutBeforeItsChevron(isOpen: Bool) throws {
        let many = ["Terrace", "Fumi", "Fabric", "Turnstile", "DocMan", "Goosemates", "Switchboard", "Harness", "Kit"]
        let drawn = try Self.black(Self.earlier(many, isOpen: isOpen))
        let box = CGRect(x: Self.width - 7.5 - 15, y: 5, width: 15, height: 24)
        let projects = try #require(drawn.drawnBox(in: CGRect(x: 100, y: 4, width: box.minX - 100, height: 26), ground: Self.ground))
        let chevron = try #require(drawn.drawnBox(in: box, ground: Self.ground))

        #expect(projects.maxX <= box.minX - 10 + 0.5)
        #expect(isOpen ? chevron.width > chevron.height : chevron.height > chevron.width)
    }

    // MARK: The black card's content

    private static let mixed = [
        Session(id: "k", project: "Kit", kind: .needs, title: "Approve the plan", sub: "Kit · The bootstrap", since: 0),
        Session(id: "w", project: "DocMan", kind: .working, title: "Running the tests", sub: "DocMan · Fix", since: 0),
        Session(id: "t", project: "Fumi", kind: .turn, title: "Licensing settled", sub: "Fumi · Licensing", since: 0),
        Session(id: "e", project: "Terrace", kind: .turn, title: "Plan saved", sub: "Terrace · Plan", since: 0),
    ]

    private static func cardList(folds: CardFolds = CardFolds()) -> PanelList {
        PanelList(head: nil, content: Content(laying: Item.card(mixed, folds: folds) { $0.id == "e" }, headed: false))
    }

    /// No head: nothing drawn over the first eyebrow; Your turn's rows whole, over the hairline, and Working's on one
    /// line under it.
    @Test func theCardDrawsYourTurnWholeAndWorkingOnOneLine() throws {
        let content = PanelContent()

        content.show(Self.cardList())

        let turn = try #require(content.rows["turn:t"]?.row), working = try #require(content.rows["w"]?.row)

        #expect(!turn.isOneLine && turn.layer.bounds.height == 49)
        #expect(working.isOneLine && working.layer.bounds.height == 30)
        #expect(content.earlier?.key == "earlier")
    }

    /// "N earlier" lifts under the pointer as a row does; an eyebrow never does.
    @Test func nEarlierLiftsUnderThePointer() throws {
        let content = PanelContent(), list = Self.cardList()
        let index = try #require(list.content.items.firstIndex { $0.key == "earlier" })

        content.show(list)
        content.show(Self.scene(hover: index, list))

        #expect(content.earlier?.line.isHighlighted == true)

        content.show(Self.scene(hover: 0, list))
        #expect(content.earlier?.line.isHighlighted == false)
    }

    private static func scene(hover: Int, _ list: PanelList) -> NotchScene {
        let stage = Stage(height: 982, visibleTop: 24, visibleBottom: 982, notchY: 491)
        let input = { (time: Double) in
            Input(time: time, pointer: CGPoint(x: 3, y: 491), needsLee: false, stage: stage, content: list.content)
        }
        let notch = Meniscus(input(0))
        var time = 0.0, frame = notch.frame(input(0))

        while notch.phase != .open, time < 2000 {
            time += 1000 / 60
            frame = notch.frame(input(time))
        }
        return NotchScene(frame: frame, hover: hover, scroll: 0, time: time, now: 0, mirror: .identity)
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

    /// On glass, a Working row on one line, as the black's: its mark at 16 by 15, its verb from 32 and what it waits
    /// on 6 after it, its project never cut, ending 10 before the time lane.
    @available(macOS 26, *)
    @Test func onGlassAWorkingRowIsOneLineAsTheBlacks() throws {
        let project = "Agentic Workflows"
        let size = CGSize(width: Self.width, height: Item.lineHeight)
        let row = GlassSessionRow(
            session: Self.waiting(Self.long, project: project), size: size, oneLine: true, hovered: false,
            pressed: false, now: 5 * 60_000, wash: 0
        )
        let drawn = try Drawn(row, size: size)
        let whole = TextLine.width(TextLine.text(project, EdgeStyle.sub, EdgeStyle.ink3))
        let verb = Self.verbWidth("Waiting on")
        let mark = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 2, width: 24, height: 26), ground: Self.ground))
        let lane = CGRect(x: 288 - whole - 1, y: 4, width: whole + 2, height: 22)
        let drawnProject = try #require(drawn.drawnBox(in: lane, ground: Self.ground))
        let lead = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: 6 + verb, height: 22), ground: Self.ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 32 + verb + 2, y: 4, width: lane.minX - verb - 34, height: 22), ground: Self.ground))

        #expect(abs(mark.midX - 16) <= 0.5 && abs(mark.midY - 15) <= 0.5)
        #expect((32 ... 33.5).contains(lead.minX))
        #expect(abs(words.minX - (32 + verb + LineTitle.gap)) <= 1.5)
        #expect(words.maxX <= 288 - whole - 12 + 0.5)
        #expect(abs(drawnProject.maxX - 288) <= 1 && abs(drawnProject.width - whole) <= 1.5)
    }

    /// On glass, a your-turn row drawn whole, as the black's: its ring 9 across at 16 by 16, its words from 32 on the
    /// first line, its project and session under them.
    @available(macOS 26, *)
    @Test func onGlassAYourTurnRowIsTwoLinesAsTheBlacks() throws {
        let size = CGSize(width: Self.width, height: Item.rowHeight)
        let row = GlassSessionRow(
            session: Self.turn("Licensing settled"), size: size, oneLine: false, hovered: false, pressed: false,
            now: 5 * 60_000, wash: 0
        )
        let drawn = try Drawn(row, size: size)
        let ring = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 5, width: 24, height: 22), ground: Self.ground))
        let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 5, width: 250, height: 20), ground: Self.ground))
        let second = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 25, width: 250, height: 16), ground: Self.ground))

        #expect(abs(ring.midX - 16) <= 0.5 && abs(ring.midY - 16) <= 0.5 && abs(ring.width - 9) <= 0.5)
        #expect((32 ... 33.5).contains(words.minX) && (32 ... 33.5).contains(second.minX))
    }

    /// On glass, "N earlier" as the black's: its words from 32, its chevron right while folded.
    @available(macOS 26, *)
    @Test func onGlassNEarlierIsLaidOutAsTheBlacks() throws {
        let size = CGSize(width: Self.width, height: Item.earlierHeight)
        let drawn = try Drawn(GlassEarlier(earlier: Self.earlier(["Terrace", "Fumi"]), size: size, lit: false), size: size)
        let words = try #require(drawn.drawnBox(in: CGRect(x: 26, y: 4, width: 100, height: 26), ground: Self.ground))
        let chevron = try #require(drawn.drawnBox(in: CGRect(x: Self.width - 22.5, y: 5, width: 15, height: 24), ground: Self.ground))

        #expect((32 ... 33.5).contains(words.minX))
        #expect(chevron.height > chevron.width)
        #expect(abs(chevron.midY - 17) <= 0.5)
    }
}
