import AppKit
@testable import SitRep
import enum SitRepPanel.BoardSection
import struct SitRepPanel.Earlier
@testable import SitRepWindow
import SwiftUI
import Testing

/// The sidebar's words in board D's whites, the card's type at the window's size: each row kind's at rest, and on the
/// emphasized selection of the list that has the window's focus, the words white and the rest white at 80%. The orange
/// stays orange.
@MainActor
struct SelectedWordsTests {
    private static let now = Date()
    private static let since = now.addingTimeInterval(-3600)
    /// A row's width inside the sidebar's 16 either side.
    private static let width: CGFloat = 264

    private static func row(
        _ section: BoardSection, _ mark: Mark, _ line: Listed.Line, washed: Date? = nil
    ) -> Listed.Row {
        Listed.Row(
            id: "sr-1", name: "Name", project: "Mono", section: section, mark: mark, isAway: false, since: since,
            lines: [line], washed: washed
        )
    }

    private static func line(_ lead: String, code: String? = nil, subject: String? = nil, washed: Date? = nil) -> Listed.Line {
        Listed.Line(id: "k1", lead: lead, code: code, subject: subject, more: nil, since: since, washed: washed)
    }

    private static func asking(washed: Date? = nil) -> Listed.Row {
        row(.needsYou, .needs, line("Name", washed: washed), washed: washed)
    }

    private static let working = row(.working, .working, line("Running", code: "swift test"))
    private static let waiting = row(.working, .onItsWork, line("Waiting on", subject: "agents"))
    private static let turn = row(.yourTurn, .turn, line("Name"))

    private static func drawn(_ view: some View, height: CGFloat, on prominence: BackgroundProminence) throws -> Drawn {
        try Drawn(view.environment(\.backgroundProminence, prominence), size: CGSize(width: width, height: height))
    }

    private static func drawn(_ row: Listed.Row, on prominence: BackgroundProminence = .standard) throws -> Drawn {
        let height = row.section == .yourTurn ? WindowStyle.oneLineHeight : WindowStyle.twoLineHeight

        return try drawn(SidebarSessionRow(row: row, filter: Filter(), now: now), height: height, on: prominence)
    }

    /// A two-line row's parts as the cell lays them out, 16 in from the sidebar's edge: the mark's slot, its first line's
    /// words, the project and session's line under them, and the age at the first line's trailing end.
    nonisolated private static let slot = CGRect(x: 0, y: 4, width: 26, height: 16)
    nonisolated private static let title = CGRect(x: 30, y: 4, width: 40, height: 16)
    nonisolated private static let project = CGRect(x: 30, y: 21, width: 60, height: 14)
    nonisolated private static let age = CGRect(x: 234, y: 4, width: 30, height: 16)
    /// A working row's subject, after its verb, "Running".
    nonisolated private static let subject = CGRect(x: 90, y: 4, width: 60, height: 16)
    /// A your-turn row's parts on its one line: its words, its project at its right, and its time.
    nonisolated private static let turnWords = CGRect(x: 30, y: 6, width: 40, height: 16)
    nonisolated private static let turnProject = CGRect(x: 190, y: 6, width: 40, height: 16)
    nonisolated private static let turnTime = CGRect(x: 234, y: 6, width: 30, height: 16)

    /// The grey of what is drawn there is white at this opacity over black, as a fill of it draws.
    private static func expectGrey(_ colour: NSColor, _ opacity: CGFloat, sourceLocation: SourceLocation = #_sourceLocation) {
        let channels = [colour.redComponent, colour.greenComponent, colour.blueComponent]
        let white = try? Drawn(Color.white.opacity(opacity), size: CGSize(width: 2, height: 2)).brightest(in: CGRect(x: 0, y: 0, width: 2, height: 2))
        let grey = white?.redComponent ?? -1

        #expect(
            channels.allSatisfy { abs($0 - grey) <= 0.03 }, "\(channels) is not white at \(opacity), \(grey)",
            sourceLocation: sourceLocation
        )
    }

    @Test func aNeedsYouRowsWordsAreWhiteOnTheSelectionAndTheLabelColourElsewhere() throws {
        #expect(try Self.drawn(Self.asking(), on: .increased).brightest(in: Self.title).isWhite)
        Self.expectGrey(try Self.drawn(Self.asking()).brightest(in: Self.title), 0.85)
    }

    /// Board D's 80%, over the black here as over the accent.
    @Test(arguments: [project, age])
    func aNeedsYouRowsSecondLineAndAgesAreWhiteAt80PercentOnTheSelection(part: CGRect) throws {
        Self.expectGrey(try Self.drawn(Self.asking(), on: .increased).brightest(in: part), 0.8)
    }

    @Test(arguments: [project, age])
    func aTwoLineRowsSecondLineAndAgeAreWhiteAt55PercentElsewhere(part: CGRect) throws {
        Self.expectGrey(try Self.drawn(Self.asking()).brightest(in: part), 0.55)
        Self.expectGrey(try Self.drawn(Self.working).brightest(in: part), 0.55)
    }

    /// A working row's verb medium in white at 55%, its command after it in mono at 35%, as is what else it acts on.
    @Test func aWorkingRowsVerbIsWhiteAt55PercentWhatItActsOnAt35() throws {
        Self.expectGrey(try Self.drawn(Self.working).brightest(in: Self.title), 0.55)
        Self.expectGrey(try Self.drawn(Self.working).brightest(in: Self.subject), 0.35)
        Self.expectGrey(try Self.drawn(Self.waiting).brightest(in: CGRect(x: 110, y: 4, width: 40, height: 16)), 0.35)
    }

    /// On the selection its verb goes white, what it acts on, its second line and its age white at 80%.
    @Test func aWorkingRowsVerbIsWhiteOnTheSelectionTheRestAt80Percent() throws {
        let picked = try Self.drawn(Self.working, on: .increased)

        #expect(try picked.brightest(in: Self.title).isWhite)
        for part in [Self.subject, Self.project, Self.age] {
            Self.expectGrey(try picked.brightest(in: part), 0.8)
        }
    }

    /// What Claude left Lee in white at 85%, its project at 35%, its time at 55%.
    @Test func aYourTurnRowsWordsProjectAndTimeAreInBoardDsWhites() throws {
        let drawn = try Self.drawn(Self.turn)

        Self.expectGrey(try drawn.brightest(in: Self.turnWords), 0.85)
        Self.expectGrey(try drawn.brightest(in: Self.turnProject), 0.35)
        Self.expectGrey(try drawn.brightest(in: Self.turnTime), 0.55)
    }

    @Test func aYourTurnRowsWordsAreWhiteOnTheSelectionTheRestAt80Percent() throws {
        let picked = try Self.drawn(Self.turn, on: .increased)

        #expect(try picked.brightest(in: Self.turnWords).isWhite)
        Self.expectGrey(try picked.brightest(in: Self.turnProject), 0.8)
        Self.expectGrey(try picked.brightest(in: Self.turnTime), 0.8)
    }

    /// "8 earlier" in white at 55%, its ring and its projects at 25%.
    @Test func nEarliersWordsAreSofterThanARowsItsProjectsFaint() throws {
        let earlier = EarlierRow(earlier: Earlier(projects: ["Kit", "Fumi"], isOpen: false))
        let drawn = try Self.drawn(earlier, height: WindowStyle.oneLineHeight, on: .standard)

        Self.expectGrey(try drawn.brightest(in: CGRect(x: 30, y: 6, width: 50, height: 16)), 0.55)
        Self.expectGrey(try drawn.brightest(in: CGRect(x: 0, y: 6, width: 26, height: 16)), 0.25)
        Self.expectGrey(try drawn.brightest(in: CGRect(x: 100, y: 6, width: 40, height: 16)), 0.25)
    }

    @Test func aProjectsNameIsWhiteAt85PercentAndWhiteOnTheSelection() throws {
        let project = { (prominence: BackgroundProminence) in
            try Self.drawn(
                SidebarLine(
                    line: .project(Listed.Project(id: "kit", name: "Kit")), isRuled: false, picked: nil,
                    filter: Filter(), now: Self.now
                ).environment(\.isStill, true),
                height: WindowStyle.oneLineHeight, on: prominence
            )
        }
        let name = CGRect(x: 40, y: 6, width: 30, height: 16)

        Self.expectGrey(try project(.standard).brightest(in: name), 0.85)
        #expect(try project(.increased).brightest(in: name).isWhite)
    }

    /// A heading's name in white at 55%; its count, past the widest gap in its words, in orange for Needs you, else
    /// white at 30%.
    @Test(arguments: [BoardSection.needsYou, .working])
    func aHeadingsCountIsOrangeForNeedsYouElseWhiteAt30Percent(section: BoardSection) throws {
        let heading = FoldHeading(heading: Sidebar.Heading(fold: .section(section), count: 4, isFolded: false), isRuled: false)
            .environment(\.isStill, true)
        let drawn = try Drawn(heading, size: CGSize(width: 296, height: WindowStyle.headingGap + WindowStyle.headingHeight))
        let inked = stride(from: CGFloat(16), to: 265, by: 0.5).filter { x in
            drawn.pixels(in: CGRect(x: x, y: 10, width: 0.5, height: 24)).contains { $0.lightness > 0.3 }
        }
        let gap = try #require(zip(inked, inked.dropFirst()).max { $0.1 - $0.0 < $1.1 - $1.0 })
        let count = try drawn.brightest(in: CGRect(x: gap.1, y: 10, width: try #require(inked.last) + 0.5 - gap.1, height: 24))

        Self.expectGrey(try drawn.brightest(in: CGRect(x: 16, y: 10, width: gap.0 - 16, height: 24)), 0.55)
        if section == .needsYou {
            #expect(count.redComponent > 0.85 && count.blueComponent < 0.35)
        } else {
            Self.expectGrey(count, 0.3)
        }
    }

    @Test(arguments: [BackgroundProminence.standard, .increased])
    func theAsksDotStaysOrange(on prominence: BackgroundProminence) throws {
        let dot = try Self.drawn(Self.asking(), on: prominence).brightest(in: Self.slot)

        #expect(dot.redComponent > 0.85 && dot.blueComponent < 0.35)
    }

    @Test(arguments: [Mark.turn, .working])
    func aGreyMarkGoesBrighterOnTheSelection(mark: Mark) throws {
        let row = mark == .turn ? Self.turn : Self.working
        let slot = mark == .turn ? CGRect(x: 0, y: 6, width: 26, height: 16) : Self.slot
        let selected = try Self.drawn(row, on: .increased).brightest(in: slot)
        let elsewhere = try Self.drawn(row).brightest(in: slot)

        #expect(selected.lightness > elsewhere.lightness)
    }

    @Test func aWashingAgeStaysOrangeOnTheSelection() throws {
        let age = try Self.drawn(Self.asking(washed: Self.now), on: .increased).brightest(in: Self.age)

        #expect(age.redComponent > 0.85 && age.blueComponent < 0.35)
    }

    /// Of a washing row's lines, only a new one's age is orange: one already waiting keeps its own.
    @Test func aWashingRowsOlderLineKeepsItsAgesInk() throws {
        var row = Self.asking(washed: Self.now)
        row.lines[0].washed = nil

        let age = try Self.drawn(row).brightest(in: Self.age)

        #expect(!(age.redComponent > 0.85 && age.blueComponent < 0.35))
    }
}
