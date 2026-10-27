import Foundation
import SitRepCore
import struct SitRepEdge.PanelBoard
import SitRepPanel

/// The SitRep window as the app runs it, with nothing of the screen in it: the board from `watch`'s lines in the
/// order it shows, what Lee picked and what the window opens on, the sessions it follows for their detail, whose
/// boards `watch`'s lines carry, the asks of the page shown kept in place, the answers waiting out their two seconds,
/// what a snooze or a wake pressed on a card came to, and finishing an away session. Every input comes through here,
/// at the time given; the views draw what it says, and the app runs what it asks for: the sessions to follow, a look
/// now, an answer, a snooze, a finish, a jump.
public final class WindowRun {
    /// The board as `watch` last printed it.
    public private(set) var last = LastBoard()
    public private(set) var pick: Pick?
    /// The session picked last, which the window opens on when nothing needs Lee.
    public private(set) var lastSession: String?
    /// The window shows: only then does it follow sessions.
    public private(set) var isOpen = false
    public private(set) var answers = Answers()
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
    /// Each session's board as a line last carried it, kept while it is not followed, so it shows again as last kept.
    private var boards: [String: SessionBoard] = [:]
    /// The sessions `watch` was last told to follow.
    private var told: Set<String> = []
    /// The sessions told without a break since their boards as kept came, a restart of `watch` no break: `watch`
    /// carries each again only as it changes, so a page made for one has its board as kept for its first.
    private var current: Set<String> = []
    /// Why the latest line to carry a session's board carried none, over its board as last kept.
    private var failed: [String: String] = [:]
    /// The asks of each session the page shows, in the order they first showed while it stands, those closed kept in
    /// their places while the page is held.
    private var frozen: [String: Frozen] = [:]
    /// The page held while the pointer is over it in the window key, and for a second after: only while it is does a
    /// closed ask keep its place, so nothing below it moves under the pointer either.
    private var pageHeld = Hold()
    /// The page's regions saying the pointer is over them: each says so under its own identity, so one going as another
    /// comes cannot cross the two.
    private var regionsUnderPointer: Set<ObjectIdentifier> = []
    private var isKey = false
    private var finishing: [String: Finish] = [:]
    /// What `sitrep snooze` or `wake` refused, by the ask, for its card to say until it is pressed again or another
    /// page is picked.
    private var unslept: [AskAddress: Card.Line] = [:]
    /// The asks opened in place in a project's view.
    private var opened: Set<AskAddress> = []
    /// The items of Status, Notes, Parked and Resolved opened in place.
    private var openedItems: Set<Item> = []

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
    /// window opens on; Settings stays. Then the sessions' boards the line carries are taken, each printed once, so
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
            finishing = finishing.filter { board.session($0.key)?.session.doing.isAway ?? false }
            if isOpen {
                keepShownOrRepick()
            }
        }
        for (session, board) in fresh?.boards ?? [:] {
            take(board, of: session, at: reducesMotion ? nil : time)
        }
        keepOnItsWayUnwatched()
    }

    /// While the board is stale no board can come, so an answer written is on its way, as the write proved.
    private func keepOnItsWayUnwatched() {
        if last.stale != nil {
            answers.unwatched()
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
        if isIn {
            regionsUnderPointer.insert(region)
        } else {
            regionsUnderPointer.remove(region)
        }
        holdPage(at: time)
    }

    /// The window became key, or stopped being, at this time: in a window not key the pointer holds no page, as a
    /// pointer resting on a window Lee is not using would hold its closed asks for as long as it rests.
    public func window(isKey: Bool, at time: Date) {
        self.isKey = isKey
        holdPage(at: time)
    }

    private func holdPage(at time: Date) {
        pageHeld.pointer(isIn: !regionsUnderPointer.isEmpty && isKey, at: time)
    }

    /// What has run out by this time: the second after the pointer left the list, or after the last pick made in it,
    /// and it takes `watch`'s order; the second after it left the page, and the closed asks leave it; a run of picks
    /// in the list stopped, and its last is followed.
    public func settle(at time: Date) {
        if held.settle(at: time) {
            take(given, moving: [])
        }
        pageHeld.settle(at: time)
        letGoOfClosedAsks()
        picks.settle(at: time)
    }

    /// Unless the page is held, the closed asks leave it, for Resolved; one with Lee's press on it still pending stays
    /// until the press settles.
    private func letGoOfClosedAsks() {
        guard !pageHeld.isHeld else {
            return
        }

        let answering = Dictionary(grouping: answers.pending.keys, by: \.session).mapValues { Set($0.map(\.ask)) }

        for session in frozen.keys {
            frozen[session]?.letGoOfClosed(but: answering[session] ?? [])
        }
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

    /// The window opens: on the pick given, as ⌘, opens it on Settings; else on the oldest session that needs Lee,
    /// and with none, on the one picked last.
    public func open(on pick: Pick? = nil) {
        isOpen = true
        folds.isEarlierOpen = false
        if let pick {
            self.pick(pick)
        } else {
            repick()
        }
    }

    /// The window closes: it follows nothing; the holds of the list and the page let go, as the pointer leaves with
    /// it, a finish asked about lapses, and the filter clears, as what it holds is not kept, showing nothing picked
    /// while it held text, as opening the window picks afresh.
    public func close() {
        isOpen = false
        isPickedWhileFiltering = false
        filter = Filter()
        letGoOfHolds()
        dropAskingToFinish()
    }

    /// The window minimised: it shows no more, so it follows nothing, a run of picks waiting let go, as back from the
    /// Dock it follows its page at once, and the holds of the list and the page let go, as the pointer leaves with it,
    /// but it keeps its page.
    public func minimise() {
        isOpen = false
        picks = PickFollows()
        letGoOfHolds()
    }

    /// The pointer gone with the window, which tells no exit: the list's hold lets go, and it takes `watch`'s order;
    /// the page's too, and the closed asks leave it.
    private func letGoOfHolds() {
        held.release()
        take(given, moving: [])
        regionsUnderPointer = []
        pageHeld.release()
        letGoOfClosedAsks()
    }

    /// The window back from the Dock, on the page it had, which follows what it shows again, unless its pick has gone
    /// from the board meanwhile.
    public func restore() {
        isOpen = true
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

    /// The pick still stands: Settings whatever the board, a session or a project while the board has it.
    private func stands(_ pick: Pick?) -> Bool {
        guard let pick else {
            return false
        }

        return pick == .settings || last.board?.has(pick.page) == true
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

    /// Lee picked a session, a project by its name, or Settings, from outside the list: what it shows is followed at
    /// once, its asks showing as last kept until its board comes; Settings follows nothing. A session lands on its row
    /// outside Snoozed, and on its row in Snoozed only where it has no other. Its row shows: the section holding it
    /// unfolds, and "N earlier" opens where it is under it; Projects, for a project. Picking another page lets go of
    /// the last page's asks kept in place, of what its cards said of refusals, and of a finish asked about.
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
            frozen = [:]
            opened = []
            openedItems = []
            unslept = [:]
            answers.forgetRefusals()
            dropAskingToFinish()
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
        for session in shown where frozen[session] == nil {
            frozen[session] = Frozen(session: session, kept: boards[session], isCurrent: current.contains(session))
        }
    }

    /// The sessions the page shows.
    private var shown: [String] {
        switch pick?.page {
        case let .session(id)?: [id]
        case let .project(key)?: last.board?.projects.first { $0.key == key }?.sessions.map(\.id) ?? []
        case .snoozed?, .settings?, nil: []
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
        told = following
        current.formIntersection(told)
        return told
    }

    /// What a session's page says where a line carries no board of it, `watch` finding no such session.
    static let notOnTheBoard = "This session isn't on the board."

    /// What a session's page with no board kept says while the board is stale, so no board can come: the head's
    /// words for it, and why.
    private var unwatched: String? {
        last.stale.map { "\(PanelBoard.unread.title). \($0)" }
    }

    /// A session's board as a line carried it, what is new on it washed from this time, if one is given, and current
    /// while it is followed; or none, as `watch` found no such session, which says so over its board as last kept, and
    /// keeps it, no longer current.
    private func take(_ board: SessionBoard?, of session: String, at time: Date?) {
        guard let board else {
            failed[session] = Self.notOnTheBoard
            current.remove(session)
            answers.noBoard(of: session)
            return
        }

        if told.contains(session) {
            current.insert(session)
        }
        boards[session] = board
        failed[session] = nil
        answers.settle(board.asks, of: session)
        frozen[session]?.take(board, washingAt: time)
        letGoOfClosedAsks()
    }

    // MARK: Answering

    /// A card's button pressed at this time: a yes, an option or ignore waits its two seconds; one that needs Claude
    /// Code's prompt jumps instead. The session to jump to, for those. Snooze is its menu's, which `snoozing` hears.
    public func press(_ button: Card.Button, on ask: AskAddress, at time: Date) -> String? {
        if case .inClaude = button {
            return ask.session
        }
        if let answer = button.answer {
            answers.press(answer, on: ask, at: time)
        }
        return nil
    }

    /// Escape: the answer pressed last on the page showing, still waiting, is taken back; one waiting on a page
    /// left goes as it would. Whether there was one.
    public func undo() -> Bool {
        answers.undo(on: Set(shown)) != nil
    }

    /// The answers whose two seconds have run out by this time, for `sitrep answer`.
    public func due(at time: Date) -> [(ask: AskAddress, answer: Answer)] {
        answers.due(at: time)
    }

    /// What `sitrep answer` came to: written, the card takes the word of the first board of its session to have it
    /// written, for where the answer is, and is on its way meanwhile while the board is stale; refused, the card says
    /// why, unless its board as last kept has the ask settled. Whether `watch` is to look now, as it is after anything
    /// written, so that board comes at once.
    public func answered(_ ask: AskAddress, _ written: WriteAnswer) -> Bool {
        switch written {
        case .written:
            answers.written(ask)
            keepOnItsWayUnwatched()
            return true
        case let .refused(why):
            answers.refused(ask, why, on: boards[ask.session]?.asks)
            return false
        }
    }

    /// An ask in a project's view opened in place into its card, or closed back to its line.
    public func toggle(_ ask: AskAddress) {
        if opened.remove(ask) == nil {
            opened.insert(ask)
        }
    }

    /// An item of Status, Notes, Parked or Resolved opened in place to the whole of it, or closed again. Picking
    /// another page closes them all.
    public func toggle(_ item: Item) {
        if openedItems.remove(item) == nil {
            openedItems.insert(item)
        }
    }

    // MARK: Snoozing

    /// A time chosen on a card's Snooze, or its Wake now pressed: what its card said of a refusal before gives way.
    public func snoozing(_ ask: AskAddress) {
        unslept[ask] = nil
    }

    /// What `sitrep snooze` came to for an ask of a card: written, the card goes after those waiting, asleep, as its
    /// session's next board has it; refused, the card says why. Whether `watch` is to look now.
    public func snoozed(_ ask: AskAddress, _ written: WriteAnswer) -> Bool {
        slept(ask, written, refused: Card.Line.notSnoozed)
    }

    /// What `sitrep wake` came to for an ask of a card, as `snoozed` says it.
    public func woke(_ ask: AskAddress, _ written: WriteAnswer) -> Bool {
        slept(ask, written, refused: Card.Line.notWoken)
    }

    private func slept(_ ask: AskAddress, _ written: WriteAnswer, refused: (String) -> Card.Line) -> Bool {
        guard case let .refused(why) = written else {
            return true
        }

        unslept[ask] = refused(why)
        return false
    }

    // MARK: Finishing

    /// "✓ Finish this session" pressed: it asks first, in place.
    public func askToFinish(_ session: String) {
        finishing[session] = .asking
    }

    /// Cancel: the offer comes back, unless `sitrep finish` runs already.
    public func cancelFinish(_ session: String) {
        if finishing[session] != .finishing {
            finishing[session] = nil
        }
    }

    /// "Yes, finish it": `sitrep finish` runs, unless it already does.
    public func confirmFinish(_ session: String) -> Bool {
        guard finishing[session] == .asking else {
            return false
        }

        finishing[session] = .finishing
        return true
    }

    /// What `sitrep finish` came to: written, it shows finishing until `watch`'s next line takes the session off the
    /// board; refused, it says why in place. Whether `watch` is to look now.
    public func finished(_ session: String, _ written: WriteAnswer) -> Bool {
        guard case let .refused(why) = written else {
            return true
        }

        finishing[session] = .refused(why)
        return false
    }

    /// A finish asked about, or refused, lapses as the page changes; one running goes on.
    private func dropAskingToFinish() {
        finishing = finishing.filter { $0.value == .finishing }
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
        for session in frozen.keys {
            frozen[session]?.prune(at: time)
        }
        if pick == .settings {
            return .settings
        }
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
        case .snoozed?, .settings?, nil:
            return board.projects.isEmpty ? .nothingOpen : .empty(listed.head.title)
        }
    }

    /// The next time something the window shows changes by time alone: an answer's wait running out, the list
    /// settling after the pointer left or a pick, the closed asks leaving a second after the pointer left the page, a
    /// wash ending, a run of picks in the list settling, a your-turn row folding into "N earlier".
    public var nextChange: Date? {
        let washes = (Array(washed.values) + frozen.values.flatMap(\.washed.values))
            .map { $0.addingTimeInterval(Wash.length / 1000) }
        let due = [answers.nextDue, held.resortsAt, pageHeld.endsAt, picks.dueAt, nextRefold]

        return (due.compactMap { $0 } + washes).min()
    }

    private func sessionPage(_ session: Board.Session, of project: Board.Project, at time: Date) -> SessionPage {
        let kept = boards[session.id]
        let isAway = session.doing.isAway
        let status = Status(now: session.now, next: session.next, updated: kept?.log.first { $0.kind == .status }?.at)
        let notes = kept.map { Self.notes($0.log, of: session, named: false) } ?? []
        let parked = kept?.parked.map { Parked(id: $0.id, session: nil, title: $0.title, where: $0.where, at: $0.at) } ?? []
        let resolved = kept.map { Self.resolved($0, leaving: frozen[session.id]?.kept ?? []) } ?? []
        let items = status.now.enumerated().map { Item.status($0.offset, $0.element) } + (status.next.map { [Item.next($0)] } ?? [])
            + notes.map { .note($0.id) } + parked.map { .parked($0.id) } + resolved.map { .resolved($0.id) }

        return SessionPage(
            id: session.id, projectKey: project.key, projectName: project.name, name: session.name,
            summary: session.summary, doing: session.doing, jumps: !isAway, waiting: session.waiting,
            snoozed: session.snoozed, asks: cards(of: session, at: time), status: status, notes: notes,
            parked: parked, resolved: resolved,
            finish: isAway ? finishing[session.id] ?? .offered : nil,
            hasBoard: kept != nil,
            failure: failed[session.id] ?? (kept == nil ? unwatched : nil),
            opened: keepOpen(items)
        )
    }

    /// The items opened that the page still shows, the rest let go, so one gone cannot open again by its key.
    private func keepOpen(_ shown: [Item]) -> Set<Item> {
        openedItems.formIntersection(shown)
        return openedItems
    }

    private func projectPage(_ project: Board.Project, on board: Board, at time: Date) -> ProjectPage {
        let needs = board.rows.filter { $0.project == project.key && $0.needsLee }
        let waiting = { (rows: [Board.Row]) in rows.map(\.lines.count).reduce(0, +) }
        let kept = project.sessions.compactMap { session in boards[session.id].map { (session, $0) } }
        let named = project.sessions.count > 1
        let notes = Array(kept.flatMap { Self.notes($1.log, of: $0, named: named) }.sorted { $0.at > $1.at }.prefix(Self.projectNotes))
        let parked = kept.flatMap { session, board in
            board.parked.map {
                Parked(
                    id: "\(session.id):\($0.id)", session: named ? session.name : nil, title: $0.title, where: $0.where,
                    at: $0.at
                )
            }
        }.sorted { $0.at < $1.at }

        return ProjectPage(
            key: project.key, name: project.name, waiting: waiting(needs), open: project.open,
            sessions: project.sessions.map { session in
                ProjectPage.Session(
                    id: session.id, name: session.name, mark: Mark(session.state), isAway: session.doing.isAway,
                    doing: session.doing,
                    waiting: waiting(needs.filter { $0.session == session.id }), since: session.since
                )
            },
            asksWaiting: project.sessions.map(\.waiting).reduce(0, +),
            asks: project.sessions.flatMap { session in
                cards(of: session, at: time).map { card in
                    ProjectPage.Ask(session: named ? session.name : nil, card: card, isOpened: opened.contains(card.id))
                }
            }.sorted { $0.card.since > $1.card.since },
            notes: notes,
            parked: parked,
            opened: keepOpen(notes.map { .note($0.id) } + parked.map { .parked($0.id) })
        )
    }

    /// A session's asks as cards: in the order they first showed on the page, those closed while it was held kept in
    /// their places, else as last kept, the newest first; those asleep after them, the soonest to wake first.
    private func cards(of session: Board.Session, at time: Date) -> [Card] {
        let kept = frozen[session.id]
        let asks = kept?.asks ?? (boards[session.id]?.asks.reversed() ?? []).map { ($0, nil) }
        let washes = Wash.live(kept?.washed ?? [:], at: time)
        let cards = asks.map { ask, closed in
            let address = AskAddress(session: session.id, ask: ask.id)

            return Card(
                ask, of: session.id, doing: session.doing, pending: answers.pending[address], closed: closed,
                washed: washes[ask.id], unslept: unslept[address]
            )
        }
        let asleep = cards.compactMap { card in card.snoozedUntil.map { (card, $0) } }

        return cards.filter { $0.snoozedUntil == nil } + asleep.sorted { $0.1 < $1.1 }.map(\.0)
    }

    /// How many of its latest notes a project's view lists, as many as a session's board carries.
    private static let projectNotes = 8

    /// A session's log lines as notes, each by an id that stays as lines come: its session's and its own; for a line
    /// without one, its kind, time, writer and words, and among lines alike in all of those, which of them it is,
    /// counted from the oldest, as new lines come at the top. In a project's view of several sessions each names its
    /// session.
    private static func notes(_ log: [SessionBoard.Line], of session: Board.Session, named: Bool) -> [Note] {
        var seen: [String: Int] = [:]
        let ids = log.reversed().map { line in
            let own = line.id ?? "\(line.kind.rawValue)@\(line.at.timeIntervalSince1970):\(line.by):\(line.text)"
            let repeats = seen[own, default: 0]

            seen[own] = repeats + 1
            return repeats == 0 ? own : "\(own)#\(repeats)"
        }

        return zip(log, ids.reversed()).map { line, own in
            Note(id: "\(session.id):\(own)", session: named ? session.name : nil, text: line.text, detail: line.detail, at: line.at)
        }
    }

    private static func resolved(_ board: SessionBoard, leaving kept: Set<String>) -> [Resolved] {
        board.resolved.filter { !kept.contains($0.id) }.map { resolved in
            let how = Card.closed(resolved.id, in: board)

            return Resolved(
                id: resolved.id, title: resolved.ask.title, closed: resolved.closedAt ?? resolved.ask.at, how: how,
                answer: how == .sent ? resolved.ask.reply?.words : nil
            )
        }
    }

}

extension Board {
    /// A session on the board, with its project.
    func session(_ id: String) -> (session: Session, project: Project)? {
        projects.lazy.compactMap { project in project.sessions.first { $0.id == id }.map { ($0, project) } }.first
    }

    /// Whether it holds the session or project picked; Settings is no part of it.
    func has(_ pick: Pick) -> Bool {
        switch pick {
        case let .session(id), let .snoozed(id): session(id) != nil
        case let .project(key): projects.contains { $0.key == key }
        case .settings: false
        }
    }
}
