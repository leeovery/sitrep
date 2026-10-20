import AppKit
@testable import SitRep
import SitRepMenu
import Testing

/// The menu keeps about Spaceman's width: its words cut to the width in the fonts they are drawn in, and a header
/// that never stretches it.
@MainActor
struct MenuWidthTests {
    private static let cut = MenuCut { text, face in MainActor.assumeIsolated { MenuFonts.measure(text, face) } }

    /// A title as the menu sets it, in its fonts, and how wide it draws.
    private static func drawn(_ title: MenuTitle) -> Double {
        let drawn = NSMutableAttributedString(string: title.words, attributes: [.font: MenuFonts.words])

        if let mono = title.mono {
            drawn.append(NSAttributedString(string: mono, attributes: [.font: MenuFonts.mono]))
        }
        if let more = title.more {
            drawn.append(NSAttributedString(string: more, attributes: [.font: MenuFonts.words]))
        }
        return drawn.size().width
    }

    @Test func aLongRowDrawsNoWiderThanTheMenusWidth() {
        let title = MenuTitle(
            words: "Two Turnstile bug fixes from the Laravel skills review, one PR each: Httpable::report() inverted, and the dispatcher rate limiter registered in a deferred provider.",
            mono: nil, more: nil, isFaint: false
        )
        let cut = title.cut(by: Self.cut)

        #expect(cut.words.hasSuffix("…"))
        #expect(Self.drawn(cut) <= MenuCut.width)
        #expect(Self.drawn(cut) > MenuCut.width - 20)
    }

    @Test func aSubjectInMonoIsCutByItsOwnFont() {
        let title = MenuTitle(
            words: "Allow Bash: ", mono: "swift test --package-path app --filter MenuWidthTests --parallel --num-workers 4",
            more: nil, isFaint: false
        )
        let cut = title.cut(by: Self.cut)

        #expect(cut.words == "Allow Bash: ")
        #expect(cut.mono?.hasSuffix("…") == true)
        #expect(Self.drawn(cut) <= MenuCut.width)
    }

    @Test func aShortRowIsLeftWhole() {
        let title = MenuTitle(words: "Wait for Lee to review PR #21", mono: nil, more: nil, isFaint: false)

        #expect(title.cut(by: Self.cut) == title)
    }

    @Test func theHeaderKeepsItsOwnWidthSoItNeverHoldsTheMenuWide() {
        let header = MenuHeader.view()

        #expect(!header.autoresizingMask.contains(.width))
        #expect(header.frame.width < 200)
    }
}

/// How a row or a button shows: lightly under the pointer or keyboard focus, strongly picked or pressed.
struct HighlightTests {
    @Test func thePickedRowShowsStrongestWhateverElse() {
        #expect(Highlight.of(isPicked: true, isPressed: false, isHovered: true, isFocused: true) == .picked)
        #expect(Highlight.of(isPicked: false, isPressed: true, isHovered: false, isFocused: false) == .picked)
    }

    @Test func keyboardFocusShowsAsThePointersHighlightDoes() {
        #expect(Highlight.of(isPicked: false, isPressed: false, isHovered: false, isFocused: true) == .hover)
        #expect(Highlight.of(isPicked: false, isPressed: false, isHovered: true, isFocused: false) == .hover)
    }

    @Test func aRowWithNothingOnItShowsNothing() {
        #expect(Highlight.of(isPicked: false, isPressed: false, isHovered: false, isFocused: false) == .none)
    }
}
