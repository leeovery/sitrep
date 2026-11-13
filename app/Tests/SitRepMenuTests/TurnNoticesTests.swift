@testable import SitRepCore
import SitRepMenu
import Testing

/// What a session moving into Lee's turn sends and plays (DESIGN, "Settings", Notifications, 13 November 2026): once
/// for each turn, as it moves in from working or on its own work, never from needing him, from his turn itself or from
/// off the board, nor for one there as SitRep starts or on any run's first line; a notification saying so, a click on
/// it carrying the session on, and his turn's own sound, each while its switch is on, and off by default.
struct TurnNoticesTests {
    private static func turn(ended since: Int = 1_792_445_400_000) -> String {
        Watched.row(
            "turn:sr-boot", "yourTurn", session: "sr-boot", project: "kit", lead: "Write round 4 into DESIGN.md",
            second: "Kit · The bootstrap", since: since
        )
    }

    private static let working = Watched.row(
        "work:sr-boot", "working", session: "sr-boot", project: "kit", lead: "Writing", second: "Kit · The bootstrap",
        since: 1_792_445_000_000
    )

    private static let onItsWork = Watched.row(
        "work:sr-boot", "onItsWork", session: "sr-boot", project: "kit", lead: "Waiting on 3 agents",
        second: "Kit · The bootstrap", since: 1_792_445_000_000
    )

    private static let asking = Watched.row(
        "ask:sr-boot:k1", "ask", session: "sr-boot", project: "kit", lead: "Approve round 4",
        second: "Kit · The bootstrap", since: 1_792_445_500_000
    )

    /// A board of these rows.
    private static func line(_ rows: String...) -> Heard {
        .line(Watched.line(needYou: 0, rows: rows))
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
        #expect(heard([.line(Watched.line(needYou: 0, rows: [])), Self.line(Self.turn())]).newTurns.isEmpty)
    }

    @Test func aStaleBoardSendsNothing() {
        let stale = heard([Self.line(Self.working), Self.line(Self.turn()), .exited(.status(1), stderr: "")])

        #expect(Notices.due(stale, Self.turnsOn).isEmpty)
        #expect(Chime.due(stale, Self.turnsOn) == nil)
    }

    // MARK: What it sends and plays

    /// "Your turn", its project and session, then what Claude left Lee, silently, a click on it carrying it on.
    @Test func itsNotificationSaysItIsLeesTurnAndCarriesTheSessionOn() {
        #expect(Notices.due(Self.ended, Self.turnsOn) == [
            Banner(
                title: "Your turn", subtitle: "Kit · The bootstrap", body: "Write round 4 into DESIGN.md",
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
        let other = Watched.row(
            "work:sr-other", "working", session: "sr-other", project: "kit", lead: "Writing", second: "Kit · Other",
            since: 1_792_445_000_000
        )
        let both = heard([
            Self.line(Self.working, other),
            .line(Watched.line(rows: [Watched.rows[0], Self.turn(), other], new: ["ask:sr-ledger:k1"])),
        ])

        #expect(both.newTurns == ["sr-boot"])
        #expect(Chime.due(both, Self.turnsOn) == "Glass")
    }
}
