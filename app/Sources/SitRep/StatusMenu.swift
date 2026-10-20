import AppKit
import SitRepCore
import SitRepMenu
import SitRepPanel

/// The menu bar item and its native menu (DESIGN, "The menu bar item"): the header; what it speaks up with; the
/// panel's sessions from the app's one `watch`, a click jumping to each; the SitRep window; Show; Settings and
/// quitting. Its glyph lights while anything needs Lee. Each board, and each opening, patches the menu in place
/// (`MenuChanges`), so an open menu keeps the item under the pointer; while it is open its times tick.
///
/// An NSStatusItem rather than SwiftUI's MenuBarExtra: a menu-style MenuBarExtra tells nothing as its menu opens, and
/// NSMenuDelegate does.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let works: Works
    private let preferences: Preferences
    private let openWindow: () -> Void
    private let openSettings: () -> Void
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private lazy var header = MenuHeader.view()
    private var board = MenuBoard(LastBoard())
    private var last = LastBoard()
    private var trouble: PluginTrouble?
    /// What the menu's items show, one entry to an item, in its order.
    private var entries: [MenuEntry] = []
    private var isOpen = false
    private var ticking: Timer?
    /// The item under the pointer, whose words take the highlight's own ink.
    private weak var highlighted: NSMenuItem?

    /// `openWindow` opens the SitRep window, `openSettings` Settings on the pane last used.
    init(works: Works, preferences: Preferences, openWindow: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.works = works
        self.preferences = preferences
        self.openWindow = openWindow
        self.openSettings = openSettings
        super.init()

        menu.delegate = self
        // The tick is Show's image, in the one lane, so there is no state column.
        menu.showsStateColumn = false
        item.menu = menu
        draw()
    }

    /// The board as `watch` last printed it.
    func show(_ last: LastBoard) {
        self.last = last
        take(MenuBoard(last, trouble: trouble))
    }

    /// The trouble SitRep met seeing to the plugin, which it speaks up with first, over the board of the plugin it
    /// runs meanwhile; nil once it has none.
    func speak(of trouble: PluginTrouble?) {
        self.trouble = trouble
        take(MenuBoard(last, trouble: trouble))
    }

    /// With no plugin to run, it speaks up with the trouble that left it none.
    func unrun(_ trouble: PluginTrouble) {
        take(MenuBoard(unrun: trouble))
    }

    private func take(_ board: MenuBoard) {
        guard board != self.board else {
            return
        }

        self.board = board
        draw()
    }

    /// Show may have changed in Settings since it was drawn.
    func menuWillOpen(_ menu: NSMenu) {
        isOpen = true
        draw()
    }

    func menuDidClose(_ menu: NSMenu) {
        isOpen = false
        highlighted = nil
        ticking?.invalidate()
        ticking = nil
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        let was = highlighted

        highlighted = item
        for item in [was, item].compactMap(\.self) {
            let offset = menu.index(of: item)

            if entries.indices.contains(offset), case let .row(session, jump) = entries[offset] {
                describe(item, session, jump: jump)
            }
        }
    }

    /// The glyph, and the menu patched to what it should show: items gone taken out, those come put in, and those
    /// kept set again where they changed. Open, its times are set for the rows now showing.
    private func draw() {
        item.button?.image = MenuImages.glyph(board.glyph)

        let next = board.entries(showing: preferences.edge.show)
        let changes = MenuChanges(from: entries, to: next)

        for offset in changes.removals {
            menu.removeItem(at: offset)
        }
        for placed in changes.insertions {
            menu.insertItem(made(placed.entry), at: placed.offset)
        }
        for placed in changes.changes {
            if let item = menu.item(at: placed.offset) {
                set(item, to: placed.entry)
            }
        }
        entries = next
        if isOpen {
            tick()
        }
    }

    private func made(_ entry: MenuEntry) -> NSMenuItem {
        switch entry {
        case .separator:
            return .separator()
        case let .heading(_, title):
            return .sectionHeader(title: title)
        case .header:
            let item = NSMenuItem()

            item.view = header
            return item
        default:
            let item = NSMenuItem()

            set(item, to: entry)
            return item
        }
    }

    private func set(_ item: NSMenuItem, to entry: MenuEntry) {
        switch entry {
        case .header, .separator:
            break
        case let .heading(_, title):
            item.title = title
        case let .reload(reload):
            command(item, reload.label, "arrow.clockwise", #selector(jump(_:)))
            item.representedObject = reload.session
        case let .trouble(trouble):
            warn(item, trouble.title, subtitle: trouble.detail)
        case let .unread(why):
            warn(item, MenuBoard.unreadTitle, subtitle: why)
        case let .row(session, jump):
            item.image = MenuImages.mark(session)
            item.target = self
            item.action = jump == nil ? nil : #selector(jump(_:))
            item.representedObject = jump
            item.badge = NSMenuItemBadge(string: session.ageText(at: Displays.wallNow))
            describe(item, session, jump: jump)
        case let .more(title):
            command(item, title, "ellipsis", #selector(openTheWindow))
        case .openWindow:
            command(item, "Open SitRep Window", "macwindow", #selector(openTheWindow))
        case let .show(show, isTicked):
            command(item, show.title, nil, #selector(choose(_:)))
            item.image = MenuImages.tick(isTicked)
            item.representedObject = show.rawValue
        case .settings:
            command(item, "Settings…", "gearshape", #selector(settings), key: ",")
        case .quit:
            command(item, "Quit SitRep", "power", #selector(quit), key: "q")
        }
    }

    /// What is wrong, and why: no command, so disabled, but set in the label's ink so macOS does not dim it, as it is
    /// what matters most.
    private func warn(_ item: NSMenuItem, _ words: String, subtitle: String) {
        let title = NSAttributedString(string: words, attributes: [.font: Self.font.bold, .foregroundColor: NSColor.labelColor])

        item.action = nil
        item.image = MenuImages.symbol("exclamationmark.triangle")
        describe(item, title, plain: words, subtitle: subtitle)
    }

    private func command(_ item: NSMenuItem, _ title: String, _ symbol: String?, _ action: Selector, key: String = "") {
        item.title = title
        item.target = self
        item.action = action
        item.keyEquivalent = key
        if let symbol {
            item.image = MenuImages.symbol(symbol)
        }
    }

    /// A row's words: its first line, its subject in mono, a working row's fainter but under the pointer, where the
    /// highlight's ink takes over; an away row's in the disabled ink, as macOS draws a disabled item's.
    private func describe(_ item: NSMenuItem, _ session: Session, jump: String?) {
        let line = session.menuLine
        let ink: NSColor? = jump == nil ? .disabledControlTextColor
            : line.isFaint && item !== highlighted ? .secondaryLabelColor : nil
        let title = NSMutableAttributedString(string: line.words, attributes: [.font: Self.font])

        if let mono = line.mono {
            title.append(NSAttributedString(string: mono, attributes: [.font: Self.mono]))
        }
        if let more = line.more {
            title.append(NSAttributedString(string: more, attributes: [.font: Self.font]))
        }
        if let ink {
            title.addAttribute(.foregroundColor, value: ink, range: NSRange(location: 0, length: title.length))
        }
        describe(item, title, plain: session.menuTitle, subtitle: session.sub)
    }

    /// Its title and the line under it. An item with an attributed title shows no subtitle before macOS 15, so before
    /// it the title is plain, and before 14.4, which has no subtitles, the line is its tooltip.
    private func describe(_ item: NSMenuItem, _ title: NSAttributedString, plain: String, subtitle: String) {
        if #available(macOS 15, *) {
            item.attributedTitle = title
            item.subtitle = subtitle
        } else if #available(macOS 14.4, *) {
            item.attributedTitle = nil
            item.title = plain
            item.subtitle = subtitle
        } else {
            item.attributedTitle = nil
            item.title = plain
            item.toolTip = subtitle
        }
    }

    private static let font = NSFont.menuFont(ofSize: 0)
    private static let mono = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)

    /// The rows' times, each drawn again as it next reads differently, and the timer set for the rows now showing.
    private func tick() {
        let now = Displays.wallNow

        for (offset, entry) in entries.enumerated() {
            guard case let .row(session, _) = entry, let item = menu.item(at: offset) else {
                continue
            }

            let age = session.ageText(at: now)

            if item.badge?.stringValue != age {
                item.badge = NSMenuItemBadge(string: age)
            }
        }

        ticking?.invalidate()
        ticking = board.nextTick(after: now).map { next in
            let timer = Timer(timeInterval: max(0.1, (next - now) / 1000), repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }

            RunLoop.main.add(timer, forMode: .common)
            return timer
        }
    }

    @objc private func jump(_ sender: NSMenuItem) {
        if let session = sender.representedObject as? String {
            works.jump(to: session)
        }
    }

    @objc private func choose(_ sender: NSMenuItem) {
        if let show = (sender.representedObject as? String).flatMap(EdgeSettings.Show.init) {
            preferences.edit { $0.show = show }
        }
    }

    @objc private func openTheWindow() {
        openWindow()
    }

    @objc private func settings() {
        openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// Asked as the menu opens, so the sessions' items show disabled while a jump runs, however long ago they were drawn.
extension StatusMenu: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        item.action != #selector(jump(_:)) || !works.isJumping
    }
}

extension EdgeSettings.Show {
    /// As the menu and Settings name it.
    var title: String {
        switch self {
        case .notch: "Notch"
        case .strip: "Strip"
        case .nothing: "Nothing"
        }
    }
}

private extension NSFont {
    var bold: NSFont { NSFontManager.shared.convert(self, toHaveTrait: .boldFontMask) }
}
