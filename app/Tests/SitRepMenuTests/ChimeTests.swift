@testable import SitRepCore
import SitRepMenu
import Testing

/// The sound a board plays: Lee's chosen one, once for the asks new on it, while his switch is on.
struct ChimeTests {
    private static let newAsk = Watched.line(new: ["ask:sr-ledger:k1"])
    /// A board after the run's first, with the ask new on it.
    private static let asked = heard([.line(Watched.line(rows: [])), .line(newAsk)])

    private static func chosen(_ sound: String = "Glass", isOn: Bool = true) -> AppSettings {
        var settings = AppSettings()

        settings.sound = sound
        settings.playsSound = isOn
        return settings
    }

    @Test func aNewAskPlaysTheSoundLeeChose() {
        #expect(Chime.due(Self.asked, Self.chosen("Submarine")) == "Submarine")
    }

    @Test func severalNewAsksOnOneBoardPlayItOnce() {
        let both = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["ask:sr-ledger:k1", "ask:sr-plan:k2"]))])

        #expect(Chime.due(both, Self.chosen()) == "Glass")
    }

    /// Core's `new` carries an ask its snooze's time woke as it carries one that landed (tests/watch.test.ts, "a snooze
    /// running out is a line the moment it does").
    @Test func anAskItsSnoozesTimeWokePlaysIt() {
        let woken = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["ask:sr-plan:k2"]))])

        #expect(Chime.due(woken, Self.chosen()) == "Glass")
    }

    @Test func withTheSwitchOffNothingPlays() {
        #expect(Chime.due(Self.asked, Self.chosen(isOn: false)) == nil)
    }

    @Test func aWindowsNewStopPlaysNothing() {
        let stopped = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["stop:sr-dash:w1:1792445500000"]))])

        #expect(Chime.due(stopped, Self.chosen()) == nil)
    }

    @Test func aRunsFirstBoardPlaysNothingThoughItCarriedNew() {
        #expect(Chime.due(heard([.line(Self.newAsk)]), Self.chosen()) == nil)
    }

    @Test func aStaleBoardPlaysNothingAgain() {
        let stale = heard([.line(Watched.line(rows: [])), .line(Self.newAsk), .exited(.status(1), stderr: "")])

        #expect(Chime.due(stale, Self.chosen()) == nil)
    }

    /// Banners are silent, so the sound plays whether or not they are on.
    @Test func itPlaysWhetherOrNotBannersAreOn() {
        var settings = Self.chosen()

        settings.notifiesNewAsks = false
        #expect(Chime.due(Self.asked, settings) == "Glass")
        settings.notifiesNewAsks = true
        #expect(Chime.due(Self.asked, settings) == "Glass")
    }
}
