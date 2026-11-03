import AppKit
import SitRepCore
import SitRepMenu
import SitRepPanel

/// The menu bar item and its native menu (DESIGN, "The menu bar item"): the header, a click opening About SitRep; what
/// it speaks up with; the panel's sessions from the app's one `watch`, a click jumping to each; the SitRep window;
/// Show; the welcome, Settings and quitting. Its glyph lights while anything needs Lee. Each board, and each opening,
/// patches the menu in place (`MenuChanges`), so an open menu keeps the item under the pointer; while it is open its
/// times tick and its working arcs turn (`MenuTurn`).
///
/// An NSStatusItem rather than SwiftUI's MenuBarExtra: a menu-style MenuBarExtra tells nothing as its menu opens, and
/// NSMenuDelegate does.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let works: Works
    private let preferences: Preferences
    private let openWindow: () -> Void
    private let openSettings: () -> Void
    private let openAbout: () -> Void
    private let openWelcome: () -> Void
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private lazy var header = MenuHeaderView()
    private var board = MenuBoard(LastBoard())
    private var last = LastBoard()
    private var trouble: PluginTrouble?
    /// What the menu's items show, one entry to an item, in its order.
    private var entries: [MenuEntry] = []
    private var isOpen = false
    private var ticking: Timer?
    private lazy var turn = MenuTurn { [weak self] in self?.turnArcs() }
    /// The item under the pointer, whose words take the highlight's own ink.
    private weak var highlighted: NSMenuItem?

    /// `openWindow` opens the SitRep window, `openSettings` the Settings window, `openAbout` About SitRep,
    /// `openWelcome` the welcome window at its first step.
    init(
        works: Works, preferences: Preferences, openWindow: @escaping () -> Void, openSettings: @escaping () -> Void,
        openAbout: @escaping () -> Void, openWelcome: @escaping () -> Void
    ) {
        self.works = works
        self.preferences = preferences
        self.openWindow = openWindow
        self.openSettings = openSettings
        self.openAbout = openAbout
        self.openWelcome = openWelcome
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

    /// Show may have changed in Settings since it was drawn. Open, its working arcs turn.
    func menuWillOpen(_ menu: NSMenu) {
        isOpen = true
        draw()
        turn.start(reducesMotion: Displays.reducesMotion(preferences.edge))
    }

    func menuDidClose(_ menu: NSMenu) {
        isOpen = false
        highlighted = nil
        header.isHighlighted = false
        ticking?.invalidate()
        ticking = nil
        turn.stop()
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        let was = highlighted

        highlighted = item
        header.isHighlighted = item?.view === header
        for item in [was, item].compactMap(\.self) {
            let offset = menu.index(of: item)

            if entries.indices.contains(offset), case let .row(session, jump) = entries[offset] {
                MenuWords.describe(
                    item, session, jump: jump, now: Displays.wallNow, isHighlighted: item === highlighted
                )
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
            item.target = self
            item.action = #selector(about)
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
            MenuWords.plain(item, reload.label)
            item.representedObject = reload.session
        case let .trouble(trouble):
            warn(item, trouble.title, subtitle: trouble.detail)
        case let .unread(why):
            warn(item, MenuBoard.unreadTitle, subtitle: why)
        case let .row(session, jump):
            item.target = self
            item.action = jump == nil ? nil : #selector(jump(_:))
            item.representedObject = jump
            let now = Displays.wallNow

            MenuWords.row(
                item, session, jump: jump, age: session.ageText(at: now), now: now, isHighlighted: item === highlighted,
                turn: turn.frame
            )
        case let .more(title):
            command(item, title, "ellipsis", #selector(openTheWindow))
        case .openWindow:
            command(item, "Open SitRep Window", "macwindow", #selector(openTheWindow))
        case let .show(show, isTicked):
            command(item, show.title, nil, #selector(choose(_:)))
            item.image = MenuImages.tick(isTicked)
            item.representedObject = show.rawValue
        case .welcome:
            command(item, MenuBoard.welcomeTitle, "hand.wave", #selector(welcome))
        case .settings:
            command(item, "Settings…", "gearshape", #selector(settings), key: ",")
        case .quit:
            command(item, "Quit SitRep", "power", #selector(quit), key: "q")
        }
    }

    /// What is wrong, and why: no command, so disabled, but set in the label's ink so macOS does not dim it, as it is
    /// what matters most.
    private func warn(_ item: NSMenuItem, _ words: String, subtitle: String) {
        item.action = nil
        MenuWords.warn(item, words, subtitle: subtitle)
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

    /// The rows' times, and a wake's countdown, each drawn again as it next reads differently, and the timer set for
    /// the rows now showing.
    private func tick() {
        let now = Displays.wallNow

        for (offset, entry) in entries.enumerated() {
            guard case let .row(session, jump) = entry, let item = menu.item(at: offset) else {
                continue
            }

            let age = session.ageText(at: now)

            if item.badge?.stringValue != age {
                item.badge = NSMenuItemBadge(string: age)
            }
            if session.until != nil {
                MenuWords.describe(item, session, jump: jump, now: now, isHighlighted: item === highlighted)
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

    /// The working rows' arcs at the frame their turn has reached.
    private func turnArcs() {
        for (offset, entry) in entries.enumerated() {
            if case let .row(session, _) = entry, session.kind == .working, let item = menu.item(at: offset) {
                item.image = MenuImages.mark(session, turn: turn.frame)
            }
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

    @objc private func welcome() {
        openWelcome()
    }

    @objc private func settings() {
        openSettings()
    }

    @objc private func about() {
        openAbout()
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
