import AppKit
import SitRepMenu
import SitRepPanel

/// The words of the menu's items, as the status menu sets them: a session's row, a warning, a reload. Each title and
/// line under it is cut to what the menu's width leaves it (`MenuChrome`), its whole words its tooltip where either
/// was cut.
@MainActor
enum MenuWords {
    static let cut = MenuCut(title: MenuChrome.title, subtitle: MenuChrome.subtitle) { text, face in
        MainActor.assumeIsolated { MenuFonts.measure(text, face) }
    }

    /// A session's row: its mark, its time as its badge, and its words.
    static func row(_ item: NSMenuItem, _ session: Session, jump: String?, age: String, isHighlighted: Bool) {
        item.image = MenuImages.mark(session)
        item.badge = NSMenuItemBadge(string: age)
        describe(item, session, jump: jump, isHighlighted: isHighlighted)
    }

    /// A row's words: its first line, its subject in mono, a working row's fainter but under the pointer, where the
    /// highlight's ink takes over; an away row's in the disabled ink, as macOS draws a disabled item's.
    static func describe(_ item: NSMenuItem, _ session: Session, jump: String?, isHighlighted: Bool) {
        let line = session.menuLine.cut(by: cut)
        let ink: NSColor? = jump == nil ? .disabledControlTextColor
            : line.isFaint && !isHighlighted ? .secondaryLabelColor : nil
        let title = NSMutableAttributedString(string: line.words, attributes: [.font: MenuFonts.words])

        if let mono = line.mono {
            title.append(NSAttributedString(string: mono, attributes: [.font: MenuFonts.mono]))
        }
        if let more = line.more {
            title.append(NSAttributedString(string: more, attributes: [.font: MenuFonts.words]))
        }
        if let ink {
            title.addAttribute(.foregroundColor, value: ink, range: NSRange(location: 0, length: title.length))
        }
        describe(item, title, plain: line.plain, of: session.menuTitle, subtitle: session.sub)
    }

    /// What is wrong, and why, in bold and the label's ink.
    static func warn(_ item: NSMenuItem, _ words: String, subtitle: String) {
        let shown = cut.fit(words, in: .bold)
        let title = NSAttributedString(string: shown, attributes: [.font: MenuFonts.bold, .foregroundColor: NSColor.labelColor])

        item.image = MenuImages.symbol("exclamationmark.triangle")
        describe(item, title, plain: shown, of: words, subtitle: subtitle)
    }

    /// A plain title, cut, its whole words its tooltip where it was.
    static func plain(_ item: NSMenuItem, _ words: String) {
        item.title = cut.fit(words, in: .words)
        item.toolTip = item.title == words ? nil : words
    }

    /// Its title and the line under it. An item with an attributed title shows no subtitle before macOS 15, so before
    /// it the title is plain, and before 14.4, which has no subtitles, the line is its tooltip.
    private static func describe(_ item: NSMenuItem, _ title: NSAttributedString, plain: String, of whole: String, subtitle line: String) {
        let subtitle = cut.fit(line, in: .subtitle)
        let all = "\(whole)\n\(line)"
        let isCut = plain != whole || subtitle != line

        if #available(macOS 15, *) {
            item.attributedTitle = title
            item.subtitle = subtitle
            item.toolTip = isCut ? all : nil
        } else if #available(macOS 14.4, *) {
            item.attributedTitle = nil
            item.title = plain
            item.subtitle = subtitle
            item.toolTip = isCut ? all : nil
        } else {
            item.attributedTitle = nil
            item.title = plain
            item.toolTip = all
        }
    }
}

/// The fonts the menu draws its words in, by face, which the cut measures them in.
@MainActor
enum MenuFonts {
    static let words = NSFont.menuFont(ofSize: 0)
    static let mono = NSFont.monospacedSystemFont(ofSize: words.pointSize, weight: .regular)
    static let bold = NSFontManager.shared.convert(words, toHaveTrait: .boldFontMask)
    /// A subtitle's, which macOS sets at the small size (`MenuWidthTests` pins it).
    static let subtitle = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)

    static func font(_ face: MenuFace) -> NSFont {
        switch face {
        case .words: words
        case .mono: mono
        case .bold: bold
        case .subtitle: subtitle
        }
    }

    /// How wide the words are, drawn in the face's font.
    static func measure(_ text: String, _ face: MenuFace) -> Double {
        (text as NSString).size(withAttributes: [.font: font(face)]).width
    }
}

/// What AppKit adds round a session row's words, measured once on an offscreen menu laid out as the status menu's,
/// so the menu's longest rows come to `MenuCut.menuWidth`: the title gets the width less the mark's lane, the badge and
/// the insets; the line under it the same, but no more than AppKit sets on one line before it wraps, which grows the
/// row.
@MainActor
enum MenuChrome {
    static let title = MenuCut.menuWidth - around(MenuFonts.words, repeats: 20) { item, words in
        item.attributedTitle = NSAttributedString(string: words, attributes: [.font: MenuFonts.words])
        subtitled(item, "x")
    }

    static let subtitle = min(
        MenuCut.menuWidth - around(MenuFonts.subtitle, repeats: 3) { item, words in
            item.title = "x"
            subtitled(item, words)
        },
        longestOneLineSubtitle
    )

    /// A menu of one session's row, set by `words`, beside the commands with keys, as the status menu has them.
    static func menu(_ words: (NSMenuItem) -> Void) -> NSMenu {
        let menu = NSMenu()
        let row = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")

        menu.showsStateColumn = false
        row.image = MenuImages.tick(false)
        row.badge = NSMenuItemBadge(string: widestAge)
        words(row)
        menu.addItem(row)
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit SitRep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// The widest time a row's badge shows.
    private static let widestAge = ["now", "59m", "23h", "30d"].max { MenuFonts.measure($0, .words) < MenuFonts.measure($1, .words) }!

    /// How much wider the menu is than words that set its width, drawn in this font, rounded up: long enough to be
    /// wider than the commands, and for a subtitle short enough to stay on one line.
    private static func around(_ font: NSFont, repeats: Int, _ set: (NSMenuItem, String) -> Void) -> Double {
        let words = String(repeating: "abcdefghij ", count: repeats)
        let width = (words as NSString).size(withAttributes: [.font: font]).width

        return (menu { set($0, words) }.size.width - width).rounded(.up) + 1
    }

    /// Before macOS 14.4 an item has no line under its title.
    private static func subtitled(_ item: NSMenuItem, _ line: String) {
        if #available(macOS 14.4, *) {
            item.subtitle = line
        }
    }

    /// The widest line under a title that AppKit keeps on one line, found by halving.
    private static var longestOneLineSubtitle: Double {
        let oneLine = menu { $0.title = "x"; subtitled($0, "a") }.size.height
        var fits = 1, wraps = 200

        while wraps - fits > 1 {
            let middle = (fits + wraps) / 2

            if menu({ $0.title = "x"; subtitled($0, String(repeating: "a", count: middle)) }).size.height > oneLine {
                wraps = middle
            } else {
                fits = middle
            }
        }
        return MenuFonts.measure(String(repeating: "a", count: fits), .subtitle).rounded(.down) - 1
    }
}
