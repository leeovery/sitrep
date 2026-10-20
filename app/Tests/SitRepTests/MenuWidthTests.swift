import AppKit
@testable import SitRep
import SitRepMenu
import SitRepPanel
import Testing

/// The menu at about Spaceman's width: a real menu, laid out offscreen as the status menu builds it, its header, its
/// longest rows with their marks, lines and badges, and its commands with keys, measured by AppKit.
@MainActor
struct MenuWidthTests {
    private static let long = "Two Turnstile bug fixes from the Laravel skills review, one PR each: Httpable::report() inverted, and the dispatcher rate limiter registered in a deferred provider."
    private static let longLine = "Turnstile · Exception reporting and dispatcher limiter fixes, and the queue's retry rules as well"

    private static func session(_ title: String, code: String? = nil, more: String? = nil, sub: String = longLine) -> Session {
        Session(id: title, project: "Turnstile", kind: .needs, title: title, code: code, more: more, sub: sub, since: 0)
    }

    /// The menu: the header, these rows as the status menu sets them, each with the widest time, and its commands.
    private static func menu(_ sessions: [Session], header: Bool = true) -> NSMenu {
        let menu = NSMenu()

        menu.showsStateColumn = false
        if header {
            let item = NSMenuItem()

            item.view = MenuHeader.view()
            menu.addItem(item)
        }
        for session in sessions {
            let item = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")

            MenuWords.row(item, session, jump: session.id, age: "59m", isHighlighted: false)
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem(title: "Open SitRep Window", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit SitRep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @Test func theLongestRowsComeToTheMenusWidthAtMost() {
        let width = Self.menu([
            Self.session(Self.long),
            Self.session("Allow Bash: ", code: "swift test --package-path app --filter MenuWidthTests --parallel --num-workers 4"),
            Self.session("Which of the three ways should the dispatcher's limiter be registered in the end?", more: "+2"),
        ]).size.width

        #expect(width <= MenuCut.menuWidth)
        #expect(width > MenuCut.menuWidth - 12)
    }

    @Test func noRowGrowsPastAOneLineRowsHeight() {
        let short = Self.menu([Self.session("Wait for review", sub: "Turnstile · Fixes")], header: false).size.height
        let long = Self.menu([Self.session(Self.long)], header: false).size.height

        #expect(long == short)
    }

    @Test func aWarningsReasonStaysOnOneLineToo() {
        let item = NSMenuItem()
        let menu = NSMenu()

        MenuWords.warn(item, "SitRep can't read the board", subtitle: "sitrep watch ended with status 1: " + Self.longLine + Self.longLine)
        menu.addItem(item)

        let oneLine = NSMenu()
        let short = NSMenuItem()

        MenuWords.warn(short, "SitRep can't read the board", subtitle: "watch ended")
        oneLine.addItem(short)
        #expect(menu.size.height == oneLine.size.height)
        #expect(item.toolTip?.hasSuffix(Self.longLine) == true)
    }

    @Test func aShortRowIsLeftWholeWithNoTooltip() {
        let item = NSMenuItem()

        MenuWords.row(item, Self.session("Wait for Lee to review PR #21", sub: "Turnstile · Fixes"), jump: "a", age: "2h", isHighlighted: false)
        #expect(item.attributedTitle?.string == "Wait for Lee to review PR #21")
        #expect(item.toolTip == nil)
    }

    /// The header used to stretch to the menu, and a view stretched keeps the width it was stretched to, which the
    /// menu is never narrower than.
    @Test func theHeaderDoesNotStretchWithTheMenu() {
        #expect(!MenuHeader.view().autoresizingMask.contains(.width))
    }

    /// Two lines under a title a hundred points apart, measured in the subtitle's font, widen the menu by a hundred
    /// points: macOS draws subtitles in it, at the small size, where the menu's own size would widen it by 109.
    @available(macOS 14.4, *)
    @Test func aSubtitleIsDrawnAtTheSmallSize() {
        func width(of points: Double) -> Double {
            var words = ""

            while MenuFonts.measure(words + "a", .subtitle) <= points {
                words += "a"
            }
            return MenuChrome.menu { $0.title = "x"; $0.subtitle = words }.size.width
        }

        #expect(abs(width(of: 260) - width(of: 160) - 100) <= 3)
    }
}

/// How a row or a button shows: lightly under the pointer, strongly picked or pressed.
struct HighlightTests {
    @Test func thePickedRowShowsStrongestWhateverElse() {
        #expect(Highlight.of(isPicked: true, isPressed: false, isHovered: true) == .picked)
        #expect(Highlight.of(isPicked: false, isPressed: true, isHovered: false) == .picked)
    }

    @Test func underThePointerItShowsLightly() {
        #expect(Highlight.of(isPicked: false, isPressed: false, isHovered: true) == .hover)
    }

    @Test func aRowWithNothingOnItShowsNothing() {
        #expect(Highlight.of(isPicked: false, isPressed: false, isHovered: false) == .none)
    }
}
