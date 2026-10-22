import AppKit
@testable import SitRep
@testable import SitRepWindow
import SwiftUI
import Testing

/// The sidebar's words in the system's label colours, drawn on what is behind them: on the emphasized selection of the
/// list that has the window's focus the system turns the title white and the soft words and marks brighter, as on its
/// own rows; the orange stays orange. Elsewhere each keeps its own.
@MainActor
struct SelectedWordsTests {
    private static let now = Date()

    private static func row(_ mark: Mark = .needs, isAway: Bool = false, washed: Date? = nil) -> Listed.Row {
        Listed.Row(
            id: "sr-1", name: "Name", project: "Mono", mark: mark, isAway: isAway,
            since: now.addingTimeInterval(-3600), washed: washed
        )
    }

    private static func drawn(_ view: some View, on prominence: BackgroundProminence) throws -> Drawn {
        try Drawn(
            view.environment(\.backgroundProminence, prominence),
            size: CGSize(width: 264, height: WindowStyle.twoLineHeight)
        )
    }

    private static func asking(_ row: Listed.Row, on prominence: BackgroundProminence) throws -> Drawn {
        try drawn(SidebarSessionRow(row: row, filter: Filter(), showsProject: true, now: now), on: prominence)
    }

    /// The row's parts as the cell lays them out, 16 in from the sidebar's edge: the mark's slot, the title's line,
    /// the project's line under it, and the age on the title's line at the trailing end.
    nonisolated private static let slot = CGRect(x: 0, y: 4, width: 26, height: 16)
    nonisolated private static let title = CGRect(x: 30, y: 4, width: 60, height: 16)
    nonisolated private static let project = CGRect(x: 30, y: 21, width: 60, height: 14)
    nonisolated private static let age = CGRect(x: 230, y: 4, width: 34, height: 16)

    @Test func theTitleIsWhiteOnTheSelectionAndTheLabelColourElsewhere() throws {
        #expect(try Self.asking(Self.row(), on: .increased).brightest(in: Self.title).isWhite)
        #expect(try Self.asking(Self.row(), on: .standard).brightest(in: Self.title).isGrey(atMost: 0.9))
    }

    @Test(arguments: [title, project, age])
    func theSoftWordsGoBrighterOnTheSelection(part: CGRect) throws {
        let selected = try Self.asking(Self.row(), on: .increased).brightest(in: part)
        let elsewhere = try Self.asking(Self.row(), on: .standard).brightest(in: part)

        #expect(selected.lightness > elsewhere.lightness)
    }

    @Test func theProjectsLineAndTheAgeAreTheSecondaryColourElsewhere() throws {
        let elsewhere = try Self.asking(Self.row(), on: .standard)

        #expect(try elsewhere.brightest(in: Self.project).isGrey(atMost: 0.65))
        #expect(try elsewhere.brightest(in: Self.age).isGrey(atMost: 0.65))
    }

    @Test(arguments: [BackgroundProminence.standard, .increased])
    func theAsksDotStaysOrange(on prominence: BackgroundProminence) throws {
        let dot = try Self.asking(Self.row(), on: prominence).brightest(in: Self.slot)

        #expect(dot.redComponent > 0.85 && dot.blueComponent < 0.35)
    }

    @Test(arguments: [Mark.turn, .working, .away])
    func aGreyMarkGoesBrighterOnTheSelection(mark: Mark) throws {
        let row = Self.row(mark, isAway: mark == .away)
        let selected = try Self.asking(row, on: .increased).brightest(in: Self.slot)
        let elsewhere = try Self.asking(row, on: .standard).brightest(in: Self.slot)

        #expect(selected.lightness > elsewhere.lightness)
    }

    @Test func aWashingAgeStaysOrangeOnTheSelection() throws {
        let age = try Self.asking(Self.row(washed: Self.now), on: .increased).brightest(in: Self.age)

        #expect(age.redComponent > 0.85 && age.blueComponent < 0.35)
    }

    @Test func noAgeShowsOnARowWithoutAnAsk() throws {
        let age = try Self.asking(Self.row(.turn), on: .standard).brightest(in: Self.age)

        #expect(age.lightness < 0.05)
    }

    /// The heading draws the system's selection itself, and on its accent its words go brighter as a row's do.
    @Test func aPickedHeadingsWordsGoBrighterOnlyWhileTheListHasTheKeyWindowsFocus() throws {
        let heading = { (isEmphasized: Bool) in
            FoldHeading(
                heading: Sidebar.Heading(fold: .project("p"), name: "Switchboard", isFolded: false, asking: 0, waiting: 0),
                isRuled: false, isPicked: true, isEmphasized: isEmphasized, filter: Filter()
            )
            .environment(\.isStill, true)
        }
        let name = CGRect(x: 16, y: WindowStyle.headingGap + 4, width: 80, height: 16)
        let emphasized = try Self.drawn(heading(true), on: .standard).brightest(in: name)
        let not = try Self.drawn(heading(false), on: .standard).brightest(in: name)

        #expect(emphasized.lightness > not.lightness)
    }
}
