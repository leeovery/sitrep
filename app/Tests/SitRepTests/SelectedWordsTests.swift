@testable import SitRep
import SitRepWindow
import SwiftUI
import Testing

/// The sidebar's words on what is behind them: on the row selected in a list with focus, its selection the accent,
/// every tone goes white, as the system's own rows' words do; elsewhere, the grey selection of a list without focus
/// among it, each keeps its own.
struct SelectedWordsTests {
    @Test(arguments: [Tone.text, .soft, .faint])
    func onTheSelectionOfAListWithFocusEveryToneIsWhite(tone: Tone) {
        #expect(WindowStyle.colour(tone, on: .increased) == .white)
    }

    @Test func elsewhereEachToneKeepsItsGrey() {
        #expect(WindowStyle.colour(.text, on: .standard) == WindowStyle.text)
        #expect(WindowStyle.colour(.soft, on: .standard) == WindowStyle.soft)
        #expect(WindowStyle.colour(.faint, on: .standard) == WindowStyle.faint)
    }

    @Test func onTheSelectionOfAListWithFocusAMarksGreysGoWhiteItsTrackDimmer() {
        #expect(WindowStyle.colour(WindowStyle.awayDot, on: .increased) == .white)
        #expect(WindowStyle.colour(WindowStyle.arc, on: .increased) == .white)
        #expect(
            WindowStyle.colour(WindowStyle.track, on: .increased, selected: WindowStyle.selectedTrack)
                == .white.opacity(Double(0x4D) / 255)
        )
    }

    @Test func elsewhereAMarkKeepsItsOwn() {
        #expect(WindowStyle.colour(WindowStyle.awayDot, on: .standard) == WindowStyle.awayDot)
        #expect(
            WindowStyle.colour(WindowStyle.track, on: .standard, selected: WindowStyle.selectedTrack) == WindowStyle.track
        )
    }
}
