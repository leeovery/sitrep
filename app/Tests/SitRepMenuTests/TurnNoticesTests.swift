@testable import SitRepCore
import SitRepMenu
import SitRepTestSupport
import Testing

/// What a session moving into Lee's turn sends and plays (DESIGN, "Settings", Notifications, 13 November 2026): once
/// for each turn, as it moves in from working or on its own work, never from needing him, from his turn itself or from
/// off the board, nor for one there as SitRep starts or on any run's first line; a notification saying so, a click on
/// it carrying the session on, and his turn's own sound, each while its switch is on, and off by default.
struct TurnNoticesTests {
    private static func turn(ended since: Int = 1_792_445_400_000) -> WatchLine.Row {
        bootstrap(.init("turn:sr-boot", .yourTurn, first: "Write round 4 into the spec", since: since))
    }

    private static let working = bootstrap(.init("work:sr-boot", .working, first: "Writing", since: 1_792_445_000_000))

    private static let onItsWork = bootstrap(
        .init("work:sr-boot", .onItsWork, first: "Waiting on 3 agents", since: 1_792_445_000_000)
    )

    private static let asking = bootstrap(
        .init("ask:sr-boot:k1", .ask, first: "Approve round 4", since: 1_792_445_500_000)
    )

    /// Litware's The installer, its row of this line.
    private static func bootstrap(_ line: WatchLine.Row.Line) -> WatchLine.Row {
        WatchLine.Row(session: "sr-boot", name: "The installer", projectName: "Litware", lines: [line])
    }

    /// A board of these rows.
    private static func line(_ rows: WatchLine.Row...) -> Heard {
        .line(Watched.line(rows: rows))
    }

    /// Working, then at Lee's turn: the board a session moves into his turn on.
    private static let ended = heard([line(working), line(turn())])

    /// As Lee leaves them, but with his turn's notification and sound on.
    private static var turnsOn: AppSettings {
        var settings = AppSettings()

        settings.notifiesTurns = true
        settings.playsTurnSound = true
        return settings
    }

    @Test func aSessionMovingIntoLeesTurnFromWorkingOrOnItsOwnWorkIsNew() {
        #expect(Self.ended.newTurns == ["sr-boot"])
        #expect(heard([Self.line(Self.onItsWork), Self.line(Self.turn())]).newTurns == ["sr-boot"])
    }

    /// Claude asks and ends its turn as one, so the session goes from working to needing Lee, and only once he snoozes
    /// the ask, or answers it from another window, to his turn: from a turn long ended, his own doing, which is none.
    @Test func aSessionComingToLeesTurnFromNeedingHimIsNotNew() {
        #expect(heard([Self.line(Self.working), Self.line(Self.asking), Self.line(Self.turn())]).newTurns.isEmpty)
    }

    /// A window joining a session at Lee's turn, a resume or a second Claude on it, restarts its turn's time; it moved
    /// into nothing.
    @Test func aWindowJoiningASessionAtLeesTurnIsNotNew() {
        let joined = Self.turn(ended: 1_792_445_600_000)

        #expect(heard([Self.line(Self.working), Self.line(Self.turn()), Self.line(joined)]).newTurns.isEmpty)
    }

    @Test func noneIsNewOnTheFirstBoardSinceSitRepStarted() {
        #expect(heard([Self.line(Self.turn())]).newTurns.isEmpty)
    }

    @Test func noneIsNewOnARunsFirstLine() {
        let restarted = heard([Self.line(Self.working), .exited(.status(1), stderr: "")], [Self.line(Self.turn())])

        #expect(restarted.isRunsFirst && restarted.newTurns.isEmpty)
    }

    /// The same turn on the next board is not new again; nor is it as its session comes back to it, its ask
    /// answered, or flickers back to it from working, the turn's end unmoved.
    @Test func oneTurnIsNewOnce() {
        #expect(heard([Self.line(Self.working), Self.line(Self.turn()), Self.line(Self.turn())]).newTurns.isEmpty)
        #expect(heard([
            Self.line(Self.working), Self.line(Self.turn()), Self.line(Self.asking), Self.line(Self.turn()),
        ]).newTurns.isEmpty)
        #expect(heard([
            Self.line(Self.working), Self.line(Self.turn()), Self.line(Self.working), Self.line(Self.turn()),
        ]).newTurns.isEmpty)
    }

    /// Lee replies and Claude ends its next turn: new again.
    @Test func theNextTurnIsNewAgain() {
        let later = Self.turn(ended: 1_792_445_600_000)
        let next = heard([Self.line(Self.working), Self.line(Self.turn()), Self.line(Self.working), Self.line(later)])

        #expect(next.newTurns == ["sr-boot"])
    }

    /// A session new to the board at Lee's turn, as one a window attaches to, moved into nothing.
    @Test func aSessionNewToTheBoardAtLeesTurnIsNotNew() {
        #expect(heard([.line(Watched.line(rows: [])), Self.line(Self.turn())]).newTurns.isEmpty)
    }

    @Test func aStaleBoardSendsNothing() {
        let stale = heard([Self.line(Self.working), Self.line(Self.turn()), .exited(.status(1), stderr: "")])

        #expect(Notices.due(stale, Self.turnsOn).isEmpty)
        #expect(Chime.due(stale, Self.turnsOn) == nil)
    }

    // MARK: What it sends and plays

    /// "Stopped", its project and session, then what Claude left Lee, silently, a click on it carrying it on.
    @Test func itsNotificationSaysItIsLeesTurnAndCarriesTheSessionOn() {
        #expect(Notices.due(Self.ended, Self.turnsOn) == [
            Banner(
                title: "Stopped", subtitle: "Litware · The installer", body: "Write round 4 into the spec",
                work: "sr-boot"
            ),
        ])
    }

    @Test func itsSoundIsItsOwn() {
        var settings = Self.turnsOn

        settings.turnSound = "Pop"
        #expect(Chime.due(Self.ended, settings) == "Pop")
    }

    /// Off by default, each of them; and each switch on its own, apart from a new ask's.
    @Test func eachIsOffByDefaultAndOnByItsOwnSwitch() {
        var notifies = AppSettings(), plays = AppSettings()

        notifies.notifiesTurns = true
        plays.playsTurnSound = true

        #expect(Notices.due(Self.ended, AppSettings()).isEmpty && Chime.due(Self.ended, AppSettings()) == nil)
        #expect(Notices.due(Self.ended, notifies).count == 1 && Chime.due(Self.ended, notifies) == nil)
        #expect(Notices.due(Self.ended, plays).isEmpty && Chime.due(Self.ended, plays) == "Tink")
        #expect(Notices.due(Self.ended, .notifyingAsks).isEmpty)
    }

    /// A board bringing a new ask and Lee's turn plays the ask's sound alone, once.
    @Test func aNewAsksSoundPlaysOverNoTurnsOnTheSameBoard() {
        let other = WatchLine.Row(
            session: "sr-other", name: "Other", projectName: "Litware",
            lines: [.init("work:sr-other", .working, first: "Writing", since: 1_792_445_000_000)]
        )
        let both = heard([
            Self.line(Self.working, other),
            .line(Watched.line(rows: [Watched.rows[0], Self.turn(), other], new: ["ask:sr-l5c9tz:k1"])),
        ])

        #expect(both.newTurns == ["sr-boot"])
        #expect(Chime.due(both, Self.turnsOn) == "Glass")
    }
}
