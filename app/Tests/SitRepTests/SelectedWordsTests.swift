import AppKit
@testable import SitRep
@testable import SitRepWindow
import SwiftUI
import Testing

/// The sidebar's rows drawn on what is behind them: on the selection of the list that has the window's focus, the
/// accent, every soft or faint word and every grey of a mark goes white, the working arc's track a dimmer white, as
/// the system's own rows' do; its orange stays orange. Elsewhere, each keeps its own.
@MainActor
struct SelectedWordsTests {
    private static let now = Date()
    private static let width: CGFloat = 280
    private static let height: CGFloat = 40

    private static func row(_ mark: Mark = .turn, isAway: Bool = false, washed: Date? = nil) -> Listed.Row {
        Listed.Row(
            id: "sr-1", name: "Name", project: "Mono", mark: mark, isAway: isAway,
            since: now.addingTimeInterval(-3600), washed: washed
        )
    }

    private static func drawn(_ view: some View, on prominence: BackgroundProminence) throws -> Drawn {
        try Drawn(
            view.environment(\.backgroundProminence, prominence).environment(\.reducesWindowMotion, true),
            size: CGSize(width: width, height: height)
        )
    }

    private static func session(_ row: Listed.Row, showsProject: Bool = false, on prominence: BackgroundProminence) throws -> Drawn {
        try drawn(
            SessionRowView(row: row, isPicked: false, filter: Filter(), showsProject: showsProject, now: now),
            on: prominence
        )
    }

    /// The row's time, in its 28 at the trailing end.
    private static let age = CGRect(x: width - 28, y: 0, width: 28, height: height)
    /// The Needs you row's project line, under its name.
    private static let projectLine = CGRect(x: 22, y: 23, width: 200, height: height - 23)
    /// The mark's lane, 12 wide, its 9-point ring centred in the row: the arc stands from 12 o'clock to 3 at rest, so
    /// its upper right holds the arc, and its lower left the track alone.
    private static let lane = CGRect(x: 0, y: 0, width: 12, height: height)
    private static let arc = CGRect(x: 6, y: height / 2 - 5, width: 6, height: 5)
    private static let track = CGRect(x: 0, y: height / 2, width: 6, height: 5)

    @Test func aSessionsAgeIsWhiteOnTheSelectionAndFaintElsewhere() throws {
        #expect(try Self.session(Self.row(), on: .increased).brightest(in: Self.age).isWhite)
        #expect(try Self.session(Self.row(), on: .standard).brightest(in: Self.age).isGrey(atMost: 0.42))
    }

    @Test func aWashingAgeStaysOrangeOnTheSelection() throws {
        let age = try Self.session(Self.row(washed: Self.now), on: .increased).brightest(in: Self.age)

        #expect(age.redComponent > 0.85)
        #expect(age.blueComponent < 0.35)
    }

    @Test func theNeedsYouRowsProjectLineIsWhiteOnTheSelectionAndSoftElsewhere() throws {
        let selected = try Self.session(Self.row(), showsProject: true, on: .increased)
        let elsewhere = try Self.session(Self.row(), showsProject: true, on: .standard)

        #expect(try selected.brightest(in: Self.projectLine).isWhite)
        #expect(try elsewhere.brightest(in: Self.projectLine).isGrey(atMost: 0.65))
    }

    @Test func aProjectHeadingIsWhiteOnTheSelectionAndSoftElsewhere() throws {
        let heading = ProjectRows(
            project: Listed.Project(id: "p", name: "Switchboard", waiting: 0, sessions: []),
            pick: nil, filter: Filter(), now: Self.now
        )
        let words = CGRect(x: 0, y: 0, width: 200, height: Self.height)

        #expect(try Self.drawn(heading, on: .increased).brightest(in: words).isWhite)
        #expect(try Self.drawn(heading, on: .standard).brightest(in: words).isGrey(atMost: 0.65))
    }

    @Test func theAwayDotIsWhiteOnTheSelectionAndFaintElsewhere() throws {
        let away = Self.row(.away, isAway: true)

        #expect(try Self.session(away, on: .increased).brightest(in: Self.lane).isWhite)
        #expect(try Self.session(away, on: .standard).brightest(in: Self.lane).isGrey(atMost: 0.32))
    }

    @Test func theWorkingArcIsWhiteOverADimmerWhiteTrackOnTheSelection() throws {
        let selected = try Self.session(Self.row(.working), on: .increased)
        let track = try selected.brightest(in: Self.track)

        #expect(try selected.brightest(in: Self.arc).isWhite)
        #expect(track.isGrey(atMost: 0.4))
        #expect(track.lightness > 3 * 0.25)
    }

    @Test func elsewhereTheWorkingArcAndItsTrackKeepTheirGreys() throws {
        let elsewhere = try Self.session(Self.row(.working), on: .standard)

        #expect(try elsewhere.brightest(in: Self.arc).isGrey(atMost: 0.85))
        #expect(try elsewhere.brightest(in: Self.track).isGrey(atMost: 0.22))
    }
}
