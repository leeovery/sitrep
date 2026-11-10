import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepLines
import SitRepMenu
import Testing

/// Settings' General: Startup, Ghostty and New windows, and no longer "Your turn folds after", retired with "N earlier"
/// on 4 November 2026, as the card shows every your-turn row (board J).
@MainActor
struct GeneralPaneTests {
    @Test func itOffersNoFoldPeriod() async throws {
        let settings = await Hosted.settings(defaults: MemoryDefaults())
        let hosted = Hosted(Hosted.content(.general, settings), size: CGSize(width: 744, height: 620))

        #expect(hosted.all(NSPopUpButton.self).isEmpty)
        #expect(hosted.all(NSSwitch.self).count == 1)
    }

    /// New windows: zmx's command over tmux's, each a field of its own width against the card's right, SitRep's own
    /// greyed in it while Lee has given none.
    @Test func newWindowsHoldsZmxsCommandThenTmuxsEachShowingSitRepsOwnUntilOneIsGiven() async throws {
        let settings = await Hosted.settings(defaults: MemoryDefaults())
        let hosted = Hosted(Hosted.content(.general, settings), size: CGSize(width: 744, height: 620))
        let fields = hosted.all(NSTextField.self)

        #expect(fields.map(\.placeholderString) == ["zmx attach {session}", "tmux -S {socket} attach -t {pane}"])
        #expect(fields.map(\.stringValue) == ["", ""])
        for field in fields {
            #expect(hosted.frame(of: field).width == AttachRow.fieldWidth)
        }
    }

    @Test func eachFieldShowsTheCommandLeeGave() async throws {
        let defaults = MemoryDefaults()
        var app = AppSettings()

        app.zmxAttach = "portal open -s {session}"
        SavedSettings(defaults).save(app)

        let settings = await Hosted.settings(defaults: defaults)
        let hosted = Hosted(Hosted.content(.general, settings), size: CGSize(width: 744, height: 620))

        #expect(hosted.all(NSTextField.self).map(\.stringValue) == ["portal open -s {session}", ""])
    }
}
