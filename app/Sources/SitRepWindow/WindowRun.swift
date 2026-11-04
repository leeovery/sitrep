import Foundation
import SitRepCore
import SitRepPanel

/// The SitRep window as the app runs it, with nothing of the screen in it: the board from `watch`'s lines in the
/// order it shows, what Lee picked and what the window opens on, the sessions it follows for their detail, whose
/// boards `watch`'s lines carry, the asks of the page shown kept in place, the answers waiting out their two seconds,
/// what a snooze or a wake pressed on a card came to, finishing an away session, and which sessions show on screen.
/// Every input comes through here, at the time given; the views draw what it says, and the app runs what it asks for:
/// the sessions to follow, a look now, an answer, a snooze, a finish, a jump, a look at the screen.
public final class WindowRun {
    /// The board as `watch` last printed it.
    public private(set) var last = LastBoard()
    public private(set) var pick: Pick?
    /// The session picked last, which the window opens on when nothing needs Lee.
    public private(set) var lastSession: String?
    /// The window shows: only then does it follow sessions.
    public private(set) var isOpen = false
    /// The answers waiting out their two seconds.
    public var answers: Answers { details.answers }
    /// What Lee folded, its sections and Projects kept across launches; "N earlier" open, never kept.
    public private(set) var folds: Folds
    /// How long a your-turn row stays in Your turn before it folds into "N earlier": the list refolds at once as it
    /// changes.
    public var period: FoldPeriod
    /// What the Filter field holds, which narrows the list and never moves the pick. While it holds text every section
    /// with a match shows open, "N earlier" too, Lee's folds standing aside until it is cleared. As it clears, a pick
    /// made while it held text shows: Lee's folds unfold to show it, as for a pick made outside the list.
    public var filter = Filter() {
        didSet {
            guard filter.isEmpty != oldValue.isEmpty else {
                return
            }

            filtering = .open
            if filter.isEmpty, isPickedWhileFiltering, let pick {
                folds.unfold(toShow: pick, in: earlier(given))
            }
            isPickedWhileFiltering = false
        }
    }
    /// What Lee folded while the filter holds text, let go as it clears.
    private var filtering = Folds.open
    /// The pick was made while the filter held text, so it shows as the filter clears.
    private var isPickedWhileFiltering = false
    /// The wall clock, against which a your-turn row passes the fold period, and the calendar its days are in, which
    /// the window's wake times are worded on too.
    private let wall: () -> Date
    public let calendar: Calendar
    /// The list as `watch` gives it, before it is held.
    private var given = Listed()
    private var held = HeldOrder()
    private var picks = PickFollows()
    private var listed = Listed()
    /// Sessions new to needing Lee, by their ids, and the lines new on them, by their keys, washed from when they came.
    private var washed: [String: Date] = [:]
    /// The detail of the sessions the page shows, which the page builders read and keep.
    var details = Details()
    /// Which sessions show on screen, read while the window shows.
    private var looks = ScreenLooks()

    /// Opened on the session picked last, folded as Lee left it, a your-turn row folding into "N earlier" after the
    /// period given, against this wall clock, its days in the Gregorian calendar in the Mac's time zone, followed as it
    /// changes (`WakeTime.calendar`).
    public init(
        lastSession: String? = nil, folds: Folds = Folds(), period: FoldPeriod = .hour,
        wall: @escaping () -> Date = Date.init, calendar: Calendar = WakeTime.calendar
    ) {
        self.lastSession = lastSession
        self.folds = folds
        self.period = period
        self.wall = wall
        self.calendar = calendar
    }

    // MARK: The board

    /// The board as `watch` last printed it, heard at this time: the list takes it, held or not, a session new to
    /// needing Lee moving in at once, washed unless motion is reduced. A pick gone from the board gives way to what the
    /// window opens on. Then the sessions' boards the line carries are taken, each printed once, so
    /// only as the line comes, never again from the board kept stale; and stale, every answer written is on its way.
    public func show(_ last: LastBoard, at time: Date, reducesMotion: Bool) {
        let fresh = last.stale == nil ? last.board : nil
        let moving = fresh?.newRows ?? []

        self.last = last
        take(Listed(last), moving: moving)
        if !reducesMotion {
            (Array(moving) + (fresh?.new ?? [])).forEach { washed[$0] = time }
        }
        if let board = last.board {
            details.keepFinishingAway(on: board)
            if isOpen {
                keepShownOrRepick()
            }
        }
        if let fresh {
            for (session, carried) in fresh.boards {
                details.take(carried, of: session, lookedAt: fresh.at, washingAt: reducesMotion ? nil : time)
            }
        }
        keepOnItsWayUnwatched()
    }

    /// While the board is stale no board can come, so an answer written is on its way, as the write proved.
    private func keepOnItsWayUnwatched() {
        if last.stale != nil {
            details.unwatched()
        }
    }

    /// With no `watch` to run, the head says why.
    public func unrun(_ why: String) {
        take(Listed(unrun: why), moving: [])
    }

    /// The pointer came over the list, or left it, at this time.
    public func pointer(isIn: Bool, at time: Date) {
        held.pointer(isIn: isIn, at: time)
    }

    /// A region of the page found the pointer over it, or not, at this time: the page is held while any region has it.
    public func pointer(overPage isIn: Bool, from region: ObjectIdentifier, at time: Date) {
        details.pointer(overPage: isIn, from: region, at: time)
    }

    /// The window became key, or stopped being, at this time: in a window not key the pointer holds no page, as a
    /// pointer resting on a window Lee is not using would hold its closed asks for as long as it rests.
    public func window(isKey: Bool, at time: Date) {
        details.window(isKey: isKey, at: time)
        if isKey {
            looks.key(at: time)
        }
    }

    /// macOS said whether the window is visible: covered, or on another Space, it shows nothing, so it reads nothing of
    /// the screen.
    public func window(isVisible: Bool) {
        looks.visible(isVisible)
    }

    /// What has run out by this time: the second after the pointer left the list, or after the last pick made in it,
    /// and it takes `watch`'s order; the second after it left the page, and the closed asks leave it; a run of picks
    /// in the list stopped, and its last is followed.
    public func settle(at time: Date) {
        if held.settle(at: time) {
            take(given, moving: [])
        }
        details.settle(at: time)
        picks.settle(at: time)
    }

    /// The list as it now shows, and the pick on the row of it that holds it: a session's pick moves to its row in
    /// Snoozed as its other goes, and back as that one goes, on the same page.
    private func take(_ given: Listed, moving: Set<String>) {
        self.given = given
        listed = held.take(given, moving: moving)
        pick = pick.map(listed.held)
    }

    // MARK: Folding

    /// A heading clicked: what is under it folds, or unfolds; "N earlier" clicked, it opens, or folds; while the
    /// filter holds text, only until it clears.
    public func toggle(_ fold: Fold) {
        changeShownFolds { $0.toggle(fold) }
    }

    /// What shows folded: Lee's folds, or while the filter holds text, those folded since it began.
    private var shownFolds: Folds {
        filter.isEmpty ? folds : filtering
    }

    private func changeShownFolds(_ change: (inout Folds) -> Void) {
        if filter.isEmpty {
            change(&folds)
        } else {
            change(&filtering)
        }
    }

    // MARK: Opening and picking

    /// The window opens: on the pick given, as the edge opens it on a session; else on the oldest session that needs
    /// Lee, and with none, on the one picked last.
    public func open(on pick: Pick? = nil) {
        isOpen = true
        looks.open()
        folds.isEarlierOpen = false
        if let pick {
            self.pick(pick)
        } else {
            repick()
        }
    }

    /// The window closes: it follows nothing, and reads nothing of the screen, letting its reading go; the holds of the
    /// list and the page let go, as the pointer leaves with it, a finish asked about lapses, and the filter clears, as
    /// what it holds is not kept, showing nothing picked while it held text, as opening the window picks afresh.
    public func close() {
        isOpen = false
        looks.close()
        isPickedWhileFiltering = false
        filter = Filter()
        letGoOfHolds()
        details.dropAskingToFinish()
    }

    /// The window minimised: it shows no more, so it follows nothing and reads nothing of the screen, a run of picks
    /// waiting let go, as back from the Dock it follows its page at once, and the holds of the list and the page let
    /// go, as the pointer leaves with it, but it keeps its page and its reading of the screen.
    public func minimise() {
        isOpen = false
        looks.minimise()
        picks = PickFollows()
        letGoOfHolds()
    }

    /// The pointer gone with the window, which tells no exit: the list's hold lets go, and it takes `watch`'s order;
    /// the page's too, and the closed asks leave it.
    private func letGoOfHolds() {
        held.release()
        take(given, moving: [])
        details.letGoOfHold()
    }

    /// The window back from the Dock, on the page it had, which follows what it shows again, unless its pick has gone
    /// from the board meanwhile.
    public func restore() {
        isOpen = true
        looks.open()
        keepShownOrRepick()
    }

    /// The pick, where it still stands, keeps the asks of what it shows in place; else what the window opens on is
    /// picked afresh.
    private func keepShownOrRepick() {
        if stands(pick) {
            keepShown()
        } else {
            repick()
        }
    }

    /// The pick still stands: a session or a project while the board has it.
    private func stands(_ pick: Pick?) -> Bool {
        guard let pick else {
            return false
        }

        return last.board?.has(pick.page) == true
    }

    /// What the window opens on, picked afresh.
    private func repick() {
        pick = nil
        if let opening = last.board.flatMap(opening) {
            pick(opening)
        }
    }

    private func opening(_ board: Board) -> Pick? {
        if let needing = board.rows.first(where: \.needsLee) {
            return .session(needing.session)
        }
        if let lastSession, board.has(.session(lastSession)) {
            return .session(lastSession)
        }
        return listed.rows.first?.pick
    }

    /// Lee picked a session or a project by its name, from outside the list: what it shows is followed at once, its
    /// asks showing as last kept until its board comes. A session lands on its row outside Snoozed, and on its row in
    /// Snoozed only where it has no other. Its row shows: the section holding it unfolds, and "N earlier" opens where
    /// it is under it; Projects, for a project. Picking another page lets go of the last page's asks kept in place, of
    /// what its cards said of refusals, and of a finish asked about.
    public func pick(_ pick: Pick) {
        picks = PickFollows()

        let held = listed.held(pick)
        let listed = earlier(given)

        choose(held)
        changeShownFolds { $0.unfold(toShow: held, in: listed) }
    }

    /// Lee picked a row of the list at this time, by a click or an arrow key: as any pick, the row picked showing it,
    /// and holding it, a session's in Snoozed as its other; but the list's order held for a second after it, so no row
    /// moves between two presses of a key, and what it follows settled (`PickFollows`).
    public func pickInList(_ pick: Pick, at time: Date) {
        held.picked(at: time)
        picks.picked(at: time, following: following)
        choose(pick)
    }

    /// Return in the Filter field: the first match the list shows, picked.
    public func openFirstMatch() {
        if !filter.isEmpty, let first = Sidebar(earlier(listed).narrowed(by: filter), folds: shownFolds).first {
            pick(first)
        }
    }

    /// What is picked now, and the asks of the sessions it shows kept in place. A session's other row picked keeps its
    /// page as it was.
    private func choose(_ pick: Pick) {
        if pick.page != self.pick?.page {
            details.turnPage()
            if case let .session(id) = pick.page {
                lastSession = id
            }
        }
        if pick != self.pick {
            self.pick = pick
            isPickedWhileFiltering = !filter.isEmpty
        }
        keepShown()
    }

    /// Each session the page shows keeps its asks in place, from its board as last kept, which is its first where it
    /// is current.
    private func keepShown() {
        details.keep(shown)
    }

    /// The sessions the page shows.
    private var shown: [String] {
        switch pick?.page {
        case let .session(id)?: [id]
        case let .project(key)?: last.board?.projects.first { $0.key == key }?.sessions.map(\.id) ?? []
        case .snoozed?, nil: []
        }
    }

    // MARK: Following sessions' boards

    /// The sessions whose boards the window follows, for `watch` to carry on its lines: those the page shows, only
    /// while the window shows, but a run of picks in the list follows only its last, once the picks stop.
    public var following: Set<String> {
        isOpen ? picks.standing ?? Set(shown) : []
    }

    /// The sessions the window follows, as `watch` is to be told them now, after each change to the window: those
    /// left out break their spans, so their boards as kept are no longer current, as `watch` carries each afresh once
    /// it is followed again.
    public func follow() -> Set<String> {
        details.follow(following)
    }

    // MARK: On screen

    /// Whether a jump could reach the session, as the last look at the screen says, unknown where tmux or `ps` gave no
    /// answer for its windows; none before the first look, after one that failed, and for a session it did not list, as
    /// no window holds it.
    public func onScreen(of session: String) -> OnScreen? {
        looks.onScreen(of: session)
    }

    /// The run of `sitrep screen` to make at this time, where the window shows and a look is due with none under way.
    public func looksAtScreen(at time: Date) -> ScreenLook? {
        looks.look(at: time)
    }

    /// What that run came to, heard at this time. Whether what the window knows of the screen changed.
    public func looked(_ answer: ScreenAnswer, of look: ScreenLook, at time: Date) -> Bool {
        looks.looked(answer, of: look, at: time)
    }

    /// When the next look at the screen is due; none while one runs, or while the window does not show.
    public var nextScreenLook: Date? {
        looks.nextLook
    }

    // MARK: Answering

    /// A card's button pressed at this time: a yes, an option or ignore waits its two seconds; one that needs Claude
    /// Code's prompt jumps instead. The session to jump to, for those. Snooze is its menu's, which `snoozing` hears.
    public func press(_ button: Card.Button, on ask: AskAddress, at time: Date) -> String? {
        details.press(button, on: ask, at: time)
    }

    /// Escape: the answer pressed last on the page showing, still waiting, is taken back; one waiting on a page
    /// left goes as it would. Whether there was one.
    public func undo() -> Bool {
        details.undo(on: Set(shown)) != nil
    }

    /// The answers whose two seconds have run out by this time, for `sitrep answer`.
    public func due(at time: Date) -> [(ask: AskAddress, answer: Answer)] {
        details.due(at: time)
    }

    /// What `sitrep answer` came to, answering at this time: written, the card takes the word of the first board of
    /// its session from a look begun after then, or of one before that shows the answer, for where the answer is, and
    /// is on its way meanwhile while the board is stale; refused, the card says why, unless its board as last kept has
    /// the ask settled. Whether `watch` is to look now, as it is after anything written, so that board comes at once.
    public func answered(_ ask: AskAddress, _ written: WriteAnswer, at time: Date) -> Bool {
        switch written {
        case .written:
            details.written(ask, at: time)
            keepOnItsWayUnwatched()
            return true
        case let .refused(why):
            details.refused(ask, why)
            return false
        }
    }

    /// An ask in a project's view opened in place into its card, or closed back to its line.
    public func toggle(_ ask: AskAddress) {
        details.toggle(ask)
    }

    /// An item of Status, Notes, Parked or Resolved opened in place to the whole of it, or closed again. Picking
    /// another page closes them all.
    public func toggle(_ item: Item) {
        details.toggle(item)
    }

    // MARK: Snoozing

    /// A time chosen on a card's Snooze, or its Wake now pressed: what its card said of a refusal before gives way.
    public func snoozing(_ ask: AskAddress) {
        details.snoozing(ask)
    }

    /// What `sitrep snooze` came to for an ask of a card: written, the card goes after those waiting, asleep, as its
    /// session's next board has it; refused, the card says why. Whether `watch` is to look now.
    public func snoozed(_ ask: AskAddress, _ written: WriteAnswer) -> Bool {
        details.slept(ask, written, refused: Card.Line.notSnoozed)
    }

    /// What `sitrep wake` came to for an ask of a card, as `snoozed` says it.
    public func woke(_ ask: AskAddress, _ written: WriteAnswer) -> Bool {
        details.slept(ask, written, refused: Card.Line.notWoken)
    }

    // MARK: Finishing

    /// "✓ Finish this session" pressed: it asks first, in place.
    public func askToFinish(_ session: String) {
        details.askToFinish(session)
    }

    /// Cancel: the offer comes back, unless `sitrep finish` runs already.
    public func cancelFinish(_ session: String) {
        details.cancelFinish(session)
    }

    /// "Yes, finish it": `sitrep finish` runs, unless it already does.
    public func confirmFinish(_ session: String) -> Bool {
        details.confirmFinish(session)
    }

    /// What `sitrep finish` came to: written, it shows finishing until `watch`'s next line takes the session off the
    /// board; refused, it says why in place. Whether `watch` is to look now.
    public func finished(_ session: String, _ written: WriteAnswer) -> Bool {
        details.finished(session, written)
    }

    // MARK: What it shows

    /// The board down the left at this time, in the order it shows, narrowed by the filter, its washes under way, Your
    /// turn's rows past the fold period by the wall clock folding into "N earlier".
    public func listed(at time: Date) -> Listed {
        washed = Wash.live(washed, at: time)

        var shown = earlier(listed).narrowed(by: filter)

        shown.changeRows { row in
            guard row.section != .snoozed else {
                return
            }

            row.washed = washed[row.id]
            row.lines.indices.forEach { row.lines[$0].washed = washed[row.lines[$0].id] }
        }
        return shown
    }

    /// The sidebar's list at this time, as `listed(at:)` gives the board, folded as it shows. "N earlier" folds as its
    /// line goes, so it never comes back already open.
    public func sidebar(at time: Date) -> Sidebar {
        let shown = listed(at: time)

        if filter.isEmpty, !shown.rows.contains(where: \.isEarlier) {
            folds.isEarlierOpen = false
        }
        return Sidebar(shown, folds: shownFolds)
    }

    /// Its your-turn rows marked where they have passed the fold period by the wall clock.
    private func earlier(_ listed: Listed) -> Listed {
        let now = Self.ms(wall())
        var marked = listed

        marked.changeRows { row in
            row.isEarlier = row.section == .yourTurn && period.isPast(Self.ms(row.since), at: now, in: calendar)
        }
        return marked
    }

    /// When on the wall clock the next of Your turn's rows passes the fold period, folding into "N earlier".
    private var nextRefold: Date? {
        let now = Self.ms(wall())
        let folds = listed.rows(in: .yourTurn).compactMap { period.folds(Self.ms($0.since), in: calendar) }

        return folds.filter { $0 > now }.min().map { Date(timeIntervalSince1970: $0 / 1000) }
    }

    private static func ms(_ date: Date) -> Double {
        date.timeIntervalSince1970 * 1000
    }

    /// The right of the window at this time, its washes under way.
    public func page(at time: Date) -> Page {
        details.prune(at: time)
        guard let board = last.board else {
            return .empty(listed.head.title)
        }

        switch pick?.page {
        case let .session(id)?:
            return board.session(id).map { .session(sessionPage($0.session, of: $0.project, at: time)) }
                ?? .nothingOpen
        case let .project(key)?:
            return board.projects.first { $0.key == key }.map { .project(projectPage($0, on: board, at: time)) }
                ?? .nothingOpen
        case .snoozed?, nil:
            return board.projects.isEmpty ? .nothingOpen : .empty(listed.head.title)
        }
    }

    /// The next time something the window shows changes by time alone: an answer's wait running out, the list
    /// settling after the pointer left or a pick, the closed asks leaving a second after the pointer left the page, a
    /// wash ending, a run of picks in the list settling, a your-turn row folding into "N earlier".
    public var nextChange: Date? {
        let washes = washed.values.map { $0.addingTimeInterval(Wash.length / 1000) }
        let due = [details.nextChange, held.resortsAt, picks.dueAt, nextRefold]

        return (due.compactMap { $0 } + washes).min()
    }
}

extension Board {
    /// A session on the board, with its project.
    func session(_ id: String) -> (session: Session, project: Project)? {
        projects.lazy.compactMap { project in project.sessions.first { $0.id == id }.map { ($0, project) } }.first
    }

    /// Whether it holds the session or project picked.
    func has(_ pick: Pick) -> Bool {
        switch pick {
        case let .session(id), let .snoozed(id): session(id) != nil
        case let .project(key): projects.contains { $0.key == key }
        }
    }
}
