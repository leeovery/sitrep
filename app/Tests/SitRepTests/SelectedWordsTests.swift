import AppKit
@testable import SitRep
import enum SitRepPanel.BoardSection
@testable import SitRepWindow
import SwiftUI
import Testing

/// The rows' words in board D's whites, the card's type at the window's size: each row kind's at rest, and on the
/// emphasized selection of the list that has the window's focus, the words white and the rest white at 80%. The orange
/// stays orange: Needs you's dot, its count, the one orange count, and a washing age.
@MainActor
struct SelectedWordsTests {
    private static let now = Date()
    private static let since = now.addingTimeInterval(-3600)
    /// A row's width inside the list's 16 either side.
    private static let width: CGFloat = 268
    /// A row's width inside the sidebar's.
    private static let sidebarWidth: CGFloat = 204

    private static func row(_ section: BoardSection, _ mark: Mark, _ line: Listed.Line) -> Listed.Row {
        Listed.Row(
            id: "sr-1", name: "Name", project: "Mono", section: section, mark: mark, isAway: false, since: since,
            lines: [line]
        )
    }

    private static func line(_ lead: String, code: String? = nil, subject: String? = nil, washed: Date? = nil) -> Listed.Line {
        Listed.Line(id: "k1", lead: lead, code: code, subject: subject, more: nil, since: since, washed: washed)
    }

    /// A line of Needs you, an ask, washing where it is new.
    private static func asking(washed: Date? = nil) -> PlaceList.Row {
        let waiting = Self.line("Pick the colour", washed: washed)

        return .line(PlaceList.LineRow(session: row(.needsYou, .needs, waiting), line: waiting))
    }

    private static let asleep = {
        var sleeping = Self.line("Pick the colour")

        sleeping.wakesAt = now.addingTimeInterval(3600)
        return PlaceList.Row.line(PlaceList.LineRow(session: row(.snoozed, .snoozed, sleeping), line: sleeping))
    }()

    private static let working = PlaceList.Row.session(row(.working, .working, line("Running", code: "swift test")))
    private static let waiting = PlaceList.Row.session(row(.working, .onItsWork, line("Waiting on", subject: "agents")))
    private static let turn = PlaceList.Row.session(row(.yourTurn, .turn, line("Name")))

    private static func drawn(
        _ view: some View, width: CGFloat = width, height: CGFloat, on prominence: BackgroundProminence
    ) throws -> Drawn {
        try Drawn(view.environment(\.backgroundProminence, prominence), size: CGSize(width: width, height: height))
    }

    private static func drawn(_ row: PlaceList.Row, on prominence: BackgroundProminence = .standard) throws -> Drawn {
        let height = switch row {
        case .line: WindowStyle.lineHeight
        case let .session(session): session.section == .yourTurn ? WindowStyle.oneLineHeight : WindowStyle.twoLineHeight
        }

        return try drawn(ListRow(row: row, filter: Filter(), now: now), height: height, on: prominence)
    }

    /// A line's parts as the cell lays them out, 16 in from the list's edge, 10 down: the mark's slot, its session's
    /// name, the line's words under it, and the age at the name's trailing end.
    nonisolated private static let lineSlot = CGRect(x: 0, y: 10, width: 26, height: 16)
    nonisolated private static let lineName = CGRect(x: 30, y: 10, width: 40, height: 16)
    nonisolated private static let lineWords = CGRect(x: 30, y: 28, width: 60, height: 16)
    nonisolated private static let lineAge = CGRect(x: 238, y: 10, width: 30, height: 16)
    /// A working row's parts: the mark's slot, its verb, what it acts on, its project and session's line under them,
    /// and its age.
    nonisolated private static let slot = CGRect(x: 0, y: 4, width: 26, height: 16)
    nonisolated private static let title = CGRect(x: 30, y: 4, width: 40, height: 16)
    nonisolated private static let subject = CGRect(x: 90, y: 4, width: 60, height: 16)
    nonisolated private static let project = CGRect(x: 30, y: 21, width: 60, height: 14)
    nonisolated private static let age = CGRect(x: 238, y: 4, width: 30, height: 16)
    /// A your-turn row's parts on its one line: its words, its project at its right, and its time.
    nonisolated private static let turnWords = CGRect(x: 30, y: 6, width: 40, height: 16)
    nonisolated private static let turnProject = CGRect(x: 194, y: 6, width: 40, height: 16)
    nonisolated private static let turnTime = CGRect(x: 238, y: 6, width: 30, height: 16)

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

    private static func isOrange(_ colour: NSColor) -> Bool {
        colour.redComponent > 0.85 && colour.blueComponent < 0.35
    }

    @Test func aLinesNameIsWhiteOnTheSelectionAndTheLabelColourElsewhere() throws {
        #expect(try Self.drawn(Self.asking(), on: .increased).brightest(in: Self.lineName).isWhite)
        Self.expectGrey(try Self.drawn(Self.asking()).brightest(in: Self.lineName), 0.85)
    }

    /// An ask asleep's name, at 60% at rest, goes white on the selection as any row's words do.
    @Test func anAskAsleepsNameIsWhiteOnTheSelection() throws {
        #expect(try Self.drawn(Self.asleep, on: .increased).brightest(in: Self.lineName).isWhite)
        Self.expectGrey(try Self.drawn(Self.asleep).brightest(in: Self.lineName), 0.6)
    }

    /// Board D's 80%, over the black here as over the accent.
    @Test(arguments: [lineWords, lineAge])
    func aLinesWordsAndAgeAreWhiteAt80PercentOnTheSelection(part: CGRect) throws {
        Self.expectGrey(try Self.drawn(Self.asking(), on: .increased).brightest(in: part), 0.8)
    }

    @Test(arguments: [lineWords, lineAge])
    func aLinesWordsAndAgeAreWhiteAt55PercentElsewhere(part: CGRect) throws {
        Self.expectGrey(try Self.drawn(Self.asking()).brightest(in: part), 0.55)
    }

    @Test(arguments: [project, age])
    func aWorkingRowsSecondLineAndAgeAreWhiteAt55PercentElsewhere(part: CGRect) throws {
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

    /// "2 earlier" in white at 55%, its ring and its projects at 25%.
    @Test func nEarliersWordsAreSofterThanARowsItsProjectsFaint() throws {
        let earlier = { (project: String) in
            PlaceList.Row.session(Listed.Row(
                id: project, name: "Name", project: project, section: .yourTurn, mark: .turn, isAway: false,
                since: Self.since, lines: [Self.line("Name")], isEarlier: true
            ))
        }
        let fold = PlaceList.Fold(kind: .earlier, rows: [earlier("Kit"), earlier("Fumi")], isOpen: false)
        let drawn = try Self.drawn(
            FoldRow(fold: fold, place: .yourTurn), height: WindowStyle.oneLineHeight, on: .standard
        )

        Self.expectGrey(try drawn.brightest(in: CGRect(x: 30, y: 6, width: 50, height: 16)), 0.55)
        Self.expectGrey(try drawn.brightest(in: CGRect(x: 0, y: 6, width: 26, height: 16)), 0.25)
        Self.expectGrey(try drawn.brightest(in: CGRect(x: 100, y: 6, width: 40, height: 16)), 0.25)
    }

    @Test func aProjectsNameIsWhiteAt85PercentAndWhiteOnTheSelection() throws {
        let project = { (prominence: BackgroundProminence) in
            try Self.drawn(
                ProjectRow(
                    project: Places.Project(id: "kit", name: "Kit", mark: .needs, sessions: 2, isQuiet: false),
                    filter: Filter()
                ),
                width: Self.sidebarWidth, height: WindowStyle.placeHeight, on: prominence
            )
        }
        let name = CGRect(x: 30, y: 8, width: 30, height: 16)

        Self.expectGrey(try project(.standard).brightest(in: name), 0.85)
        #expect(try project(.increased).brightest(in: name).isWhite)
    }

    /// A quiet project's name at 55%, and no count.
    @Test func aQuietProjectsNameIsSoftAndUncounted() throws {
        let quiet = try Self.drawn(
            ProjectRow(
                project: Places.Project(id: "kit", name: "Kit", mark: .nothingWaiting, sessions: 1, isQuiet: true),
                filter: Filter()
            ),
            width: Self.sidebarWidth, height: WindowStyle.placeHeight, on: .standard
        )

        Self.expectGrey(try quiet.brightest(in: CGRect(x: 30, y: 8, width: 30, height: 16)), 0.55)
        #expect(try quiet.brightest(in: Self.count).lightness < 0.1)
    }

    /// A place's name in white at 85%; its count in the lane at its end, orange for Needs you, the one orange count,
    /// else white at 35%.
    @Test(arguments: [Place.needsYou, .yourTurn, .working, .parked])
    func aPlacesCountIsOrangeForNeedsYouElseGrey(place: Place) throws {
        let drawn = try Self.drawn(
            PlaceRow(place: place, count: 4), width: Self.sidebarWidth, height: WindowStyle.placeHeight, on: .standard
        )
        let count = try drawn.brightest(in: Self.count)

        Self.expectGrey(try drawn.brightest(in: CGRect(x: 30, y: 8, width: 40, height: 16)), 0.85)
        if place == .needsYou {
            #expect(Self.isOrange(count))
        } else {
            Self.expectGrey(count, 0.35)
        }
    }

    /// Needs you's count stays orange on the selection; none drawn at nought.
    @Test func needsYousCountStaysOrangeOnTheSelectionAndNoneShowsAtNought() throws {
        let picked = try Self.drawn(
            PlaceRow(place: .needsYou, count: 4), width: Self.sidebarWidth, height: WindowStyle.placeHeight,
            on: .increased
        )
        let nought = try Self.drawn(
            PlaceRow(place: .yourTurn, count: 0), width: Self.sidebarWidth, height: WindowStyle.placeHeight,
            on: .standard
        )

        #expect(Self.isOrange(try picked.brightest(in: Self.count)))
        #expect(try nought.brightest(in: Self.count).lightness < 0.1)
    }

    /// A sidebar row's count lane, 26 at its end.
    nonisolated private static let count = CGRect(x: 178, y: 8, width: 26, height: 16)

    @Test(arguments: [BackgroundProminence.standard, .increased])
    func theAsksDotStaysOrange(on prominence: BackgroundProminence) throws {
        #expect(Self.isOrange(try Self.drawn(Self.asking(), on: prominence).brightest(in: Self.lineSlot)))
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
        #expect(Self.isOrange(try Self.drawn(Self.asking(washed: Self.now), on: .increased).brightest(in: Self.lineAge)))
    }

    /// Only a new line's age is orange: one already waiting keeps its own ink.
    @Test func aLineAlreadyWaitingKeepsItsAgesInk() throws {
        #expect(!Self.isOrange(try Self.drawn(Self.asking()).brightest(in: Self.lineAge)))
    }
}
