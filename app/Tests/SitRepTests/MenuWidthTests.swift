import AppKit
@testable import SitRep
import SitRepMenu
import SitRepPanel
import Testing

/// The menu at about Spaceman's width: a real menu, laid out offscreen as the status menu builds it, its header, its
/// longest rows with their marks, lines and badges, and its commands with keys, measured by AppKit.
@MainActor
struct MenuWidthTests {
    private static let long = "Two Coho bug fixes from the code review, one PR each: the totals report reversed, and the import queue's retry limit read before its settings load."
    /// Words as wide as this many points in the face, to within a hair space: as wide as a cut can land.
    private static func filled(to points: Double, in face: MenuFace) -> String {
        var words = ""

        for piece in ["a", ".", "\u{200A}"] {
            while MenuFonts.measure(words + piece + ".", face) <= points {
                words += piece
            }
        }
        return words + "."
    }
    private static let longLine = "Coho · Report totals and import queue fixes, and the queue's retry rules as well"

    /// A row whose line is these words, as a your-turn row's is: a row needing Lee shows its session's name.
    private static func session(_ title: String, code: String? = nil, more: String? = nil, sub: String = longLine) -> Session {
        Session(id: title, project: "Coho", kind: .turn, title: title, code: code, more: more, sub: sub, since: 0)
    }

    /// The menu: the header, these rows as the status menu sets them, each with the widest time, and its commands.
    private static func menu(_ sessions: [Session], header: Bool = true) -> NSMenu {
        let menu = NSMenu()

        menu.showsStateColumn = false
        if header {
            let item = NSMenuItem()

            item.view = MenuHeaderView()
            menu.addItem(item)
        }
        for session in sessions {
            let item = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")

            MenuWords.row(item, session, age: MenuChrome.widestAge, now: 0, isHighlighted: false)
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem(title: "Show Welcome Window", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit SitRep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @Test func theLongestRowsComeToTheMenusWidthAtMost() {
        let width = Self.menu([
            Self.session(Self.long),
            Self.session("Allow Bash: ", code: "swift test --package-path app --filter MenuWidthTests --parallel --num-workers 4"),
            Self.session("Which of the three ways should the import queue's retry rule be written in the end?", more: "+2"),
        ]).size.width

        #expect(width <= MenuCut.menuWidth)
        #expect(width > MenuCut.menuWidth - 12)
    }

    /// A title and a line under it as wide as their shares, as the cut can leave them, come to the width at most.
    @Test func rowsAtTheEdgeOfTheirSharesComeToTheMenusWidthAtMost() {
        let title = Self.filled(to: MenuChrome.title, in: .words)
        let line = Self.filled(to: MenuChrome.subtitle, in: .subtitle)
        let width = Self.menu([
            Self.session(title, sub: "Coho · Fixes"), Self.session("Wait for review", sub: line),
        ]).size.width

        #expect(MenuFonts.measure(title, .words) > MenuChrome.title - 1)
        #expect(MenuFonts.measure(line, .subtitle) > MenuChrome.subtitle - 1)
        #expect(width <= MenuCut.menuWidth)
    }

    @Test func noRowGrowsPastAOneLineRowsHeight() {
        let short = Self.menu([Self.session("Wait for review", sub: "Coho · Fixes")], header: false).size.height
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

        MenuWords.row(item, Self.session("Wait for the review of PR #21", sub: "Coho · Fixes"), age: "2h", now: 0, isHighlighted: false)
        #expect(item.attributedTitle?.string == "Wait for the review of PR #21")
        #expect(item.toolTip == nil)
    }

    /// The header used to stretch to the menu, and a view stretched keeps the width it was stretched to, which the
    /// menu is never narrower than.
    @Test func theHeaderDoesNotStretchWithTheMenu() {
        #expect(!MenuHeaderView().autoresizingMask.contains(.width))
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
