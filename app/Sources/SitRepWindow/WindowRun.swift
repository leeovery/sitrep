import Foundation
import SitRepCore
import SitRepPanel

/// The SitRep window as the app runs it, with nothing of the screen in it: the board from `watch`'s lines in the
/// order its columns show it, where the window is and where it has been, the sessions it follows for their detail,
/// whose boards `watch`'s lines carry, the asks of the page shown kept in place, the answers waiting out their two
/// seconds, what a snooze or a wake pressed on a card came to, finishing an away session, and which sessions show on
/// screen. Every input comes through here, at the time given; the views draw what it says, and the app runs what it
/// asks for: the sessions to follow, a look now, an answer, a snooze, a finish, a jump, a look at the screen.
public final class WindowRun {
    /// The board as `watch` last printed it.
    public private(set) var last = LastBoard()
    /// Where the window is, and has been, from when it opened, for Back and Forward; none while it is closed.
    private var history: History?
    /// Where the window was left, which it opens on when nothing needs Lee.
    private var remembered: Location?
    /// A session opened from outside the window before a board was heard, landed on the first board unless Lee goes
    /// somewhere first; and whether the window opened afresh onto it.
    private var landing: (session: String, isAfresh: Bool)?
    /// The window shows: only then does it follow sessions.
    public private(set) var isOpen = false
    /// The answers waiting out their two seconds.
    public var answers: Answers { details.answers }
    /// What the Filter field holds, which narrows the list and the projects and never moves where the window is. A
    /// fold at the list's foot shows open while it holds text, and a click on it then changes nothing; as it clears,
    /// the folds are as they were, but the fold holding the pick opens, so the pick shows. Lee typing in it is Lee
    /// doing something himself, so a session opened from outside waiting on the first board lands no more.
    public var filter = Filter() {
        didSet {
            guard filter != oldValue else {
                return
            }

            landing = nil
            if filter.isEmpty {
                openTheFoldOverThePick()
            }
            keepTheList()
        }
    }
    /// The places whose fold at the list's foot is open, "N snoozed" or "N earlier": never kept, each folded as the
    /// window opens.
    private var openFolds: Set<Place> = []
    /// The pick was a your-turn row under "N earlier" as the window last settled: one the clock folds in since opens
    /// the fold, as the clock is not Lee closing it over his pick.
    private var pickWasEarlier = false
    /// How many times a session opened from outside while no board had come has landed, on the board that came: the
    /// window puts focus on the list for each, as for any open from outside.
    public private(set) var landedLater = 0
    /// When Lee last looked at each session on the board: the time its page last stopped showing.
    public private(set) var looked: LastLooked
    /// The session whose page shows, as the window last changed.
    private var showing: String?
    /// The wall clock, against which a your-turn row passes the fold period and a session's page stops showing; and the
    /// calendar the window's wake times are worded in.
    private let wall: () -> Date
    public let calendar: Calendar
    /// The board as `watch` gives it, before it is held.
    private var given = Listed()
    private var held = HeldLists()
    private var picks = PickFollows()
    /// The lines new on the board, by their keys, washed from when they came.
    private var washed: [String: Date] = [:]
    /// The detail of the sessions the page shows, which the page builders read and keep.
    var details = Details()
    /// Which sessions show on screen, read while the window shows.
    private var looks = ScreenLooks()

    /// Opened where it was left, and with when Lee last looked at each session, as given, a your-turn row folding into
    /// "N earlier" against this wall clock, its wake times worded in the Gregorian calendar in the Mac's time zone,
    /// followed as it changes (`WakeTime.calendar`).
    public init(
        remembered: Location? = nil, looked: LastLooked = LastLooked(), wall: @escaping () -> Date = Date.init,
        calendar: Calendar = WakeTime.calendar
    ) {
        self.remembered = remembered
        self.looked = looked
        self.wall = wall
        self.calendar = calendar
    }

    /// Where the window is: open or minimised, where its history has it; closed, where it was left.
    public var location: Location {
        history?.location ?? remembered ?? .place(.needsYou)
    }

    /// Back, or Forward, has a step to go to.
    public var canGoBack: Bool { history?.canGoBack ?? false }
    public var canGoForward: Bool { history?.canGoForward ?? false }

    // MARK: The board

    /// The board as `watch` last printed it, heard at this time: the columns take it, held or not, a line new on it
    /// moving in at once, washed unless motion is reduced. Where the window is stays wherever it still stands on it
    /// (`History.keep(on:arranged:)`), and a session opened from outside before any board lands; when Lee last looked
    /// at a session is kept only while it is on the board. Then the sessions' boards the line carries are taken, each
    /// printed once, so only as the line comes, never again from the board kept stale; and stale, every answer written
    /// is on its way.
    public func show(_ last: LastBoard, at time: Date, reducesMotion: Bool) {
        let fresh = last.stale == nil ? last.board : nil
        let isFirstBoard = !given.hasBoard

        self.last = last
        take(Listed(last))
        if !reducesMotion {
            fresh?.new.forEach { washed[$0] = time }
        }
        if let board = last.board {
            details.keepFinishingAway(on: board)
        }
        keepOnTheBoard(isFirstBoard: isFirstBoard)
        if given.hasBoard {
            looked.keep(only: Set(given.homes.keys))
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
        take(Listed(unrun: why))
    }

    /// How the board stands, as the panel's head words it, for the list's place where it lists nothing.
    public var head: Head { given.head }

    /// The pointer came over a column, the list or the projects, or left it, at this time.
    public func pointer(over column: HeldLists.Column, isIn: Bool, at time: Date) {
        held.pointer(over: column, isIn: isIn, at: time)
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

    /// macOS said whether the window is visible: covered, hidden or on another Space, it shows nothing, so it reads
    /// nothing of the screen, and a session's page showing stops showing.
    public func window(isVisible: Bool) {
        looks.visible(isVisible)
        keepLooked()
    }

    /// What has run out by this time: the second after the pointer left a column, or after the last pick made in it,
    /// and it takes `watch`'s order; the second after it left the page, and the closed asks leave it; a run of picks
    /// in the list stopped, and its last is followed; a wash ended, let go wherever the window is, so no wash that
    /// ended is waited for; a your-turn row passing the fold period, the fold opening where it folds the pick in. With
    /// no list showing, as a page fills the window, the pointer is over no list, whose view, gone, says nothing of it.
    public func settle(at time: Date) {
        washed = Wash.live(washed, at: time)
        if location.place == nil {
            held.pointer(over: .list, isIn: false, at: time)
        }
        if held.settle(at: time) {
            take(given)
        }
        details.settle(at: time)
        picks.settle(at: time)
        openTheFoldTheClockClosedOverThePick()
        keepTheList()
    }

    /// The pick folded into "N earlier" by the clock since the window last settled: the fold opens, so it shows.
    private func openTheFoldTheClockClosedOverThePick() {
        let isEarlier = location.place == .yourTurn && PlaceList(.yourTurn, in: listed).folds(location.picked?.pick)

        if isEarlier, !pickWasEarlier {
            openFolds.insert(.yourTurn)
        }
        pickWasEarlier = isEarlier
    }

    /// The board in the order the columns show it (`keepTheList()`).
    private func take(_ given: Listed) {
        self.given = given
        held.take(given)
        keepTheList()
    }

    /// The lists as they now show, after anything that changes them: each place's fold gone from its list, its rows
    /// gone, closed, so it never comes back already open; and the pick standing where its list shows it.
    private func keepTheList() {
        let listed = listed

        openFolds = openFolds.filter { PlaceList($0, in: listed).fold != nil }
        if let place = location.place {
            // arranged first: it reads where the window is, which the history's change below would hold exclusively
            let list = arranged(place)

            history?.stand(in: list)
        }
    }

    /// Where the window is, and every step back and forward, as each stands on the board, the fold over the pick
    /// opening where the board moved it, or on the first board, which the pick was waiting on; then a session opened
    /// from outside before a board was heard, landed, the list to take focus.
    private func keepOnTheBoard(isFirstBoard: Bool) {
        let listed = listed
        let before = location

        // arranged narrows Parked by the scope before the change, which a scope dropped by the board may have been;
        // move ends by standing the pick in the list as it now narrows (`keepTheList()`)
        move { $0.keep(on: listed, arranged: { self.arranged($0) }) }
        if location != before || isFirstBoard {
            openTheFoldOverThePick()
        }
        if let landing, land(landing.session, isAfresh: landing.isAfresh) {
            landedLater += 1
        }
    }

    // MARK: Opening and closing

    /// The window opens afresh, where `History(opening:remembered:)` says: on Needs you's first line, else where it was
    /// left, its folds closed but the one over the pick, with no step to go back to. Opened by "Open in SitRep" on a
    /// session, it opens onto where that lands instead, with no step back to a page Lee never saw.
    public func open(landing session: String? = nil) {
        let leaf = location.leaf

        isOpen = true
        looks.open()
        openFolds = []
        history = History(opening: listed, remembered: location)
        turned(from: leaf)
        openTheFoldOverThePick()
        if let session {
            filter = Filter()
            land(session, isAfresh: true)
        }
    }

    /// The window closes: it follows nothing, and reads nothing of the screen, letting its reading go; a session's page
    /// showing stops showing; where it is becomes where it was left, its history let go; the holds of the columns and
    /// the page let go, as the pointer leaves with it, a finish asked about lapses, and the filter clears, as what it
    /// holds is not kept.
    public func close() {
        isOpen = false
        looks.close()
        keepLooked()
        remembered = location
        history = nil
        landing = nil
        filter = Filter()
        letGoOfHolds()
        details.dropAskingToFinish()
    }

    /// The window minimised: it shows no more, so it follows nothing and reads nothing of the screen, a session's page
    /// showing stops showing, a run of picks waiting let go, as back from the Dock it follows its page at once, and the
    /// holds of the columns and the page let go, as the pointer leaves with it, but it keeps where it is, its history
    /// and its reading of the screen.
    public func minimise() {
        isOpen = false
        looks.minimise()
        keepLooked()
        picks = PickFollows()
        letGoOfHolds()
    }

    /// The app quits: a session's page showing stops showing.
    public func quit() {
        keepLooked(showing: nil)
    }

    /// The pointer gone with the window, which tells no exit: the columns' holds let go, and they take `watch`'s order;
    /// the page's too, and the closed asks leave it.
    private func letGoOfHolds() {
        held.release()
        take(given)
        details.letGoOfHold()
    }

    /// The window back from the Dock, where it was, as that stands on the boards heard meanwhile, which it follows
    /// again.
    public func restore() {
        isOpen = true
        looks.open()
        keepShown()
        keepLooked()
    }

    // MARK: Going somewhere

    /// "Open in SitRep" on a session, from the card or the menu, while the window is open: where
    /// `Location.opening(session:on:)` says, as Lee would go there himself, the fold over its row opening and the
    /// filter cleared as it is asked for, which could hide its row; before a board is heard, on the first one, unless
    /// Lee goes somewhere first. A second asked for while the first waits replaces it, the window still opening onto
    /// it where it opened afresh for the first. Its page is followed at once.
    public func land(_ session: String) {
        let isAfresh = landing?.isAfresh ?? false

        filter = Filter()
        land(session, isAfresh: isAfresh)
    }

    /// Landed as a step, or, the window opening afresh onto it, as where it opens (`History.open(onto:)`). Whether it
    /// landed; with no board heard, it waits for the first.
    @discardableResult
    private func land(_ session: String, isAfresh: Bool) -> Bool {
        let landing = Location.opening(session: session, on: listed)
        var landed = false

        self.landing = history != nil && landing == .awaitingBoard ? (session, isAfresh) : nil
        picks = PickFollows()
        move { history in
            landed = isAfresh ? history.open(onto: landing) : history.land(landing)
        }
        openTheFoldOverThePick()
        return landed
    }

    /// A row of the sidebar clicked, a place or a project: there, as a step Back returns from, unless it is there
    /// already (`Location.clicking(_:)`). The projects hold their order under the pointer, not for a click.
    public func click(_ root: Root) {
        if let location = location.clicking(root) {
            go(to: location, by: .sidebar)
        }
    }

    /// To the location, the way given, as a step Back returns from: a session opened from a project's page, a project
    /// from a session's, Parked narrowed to a session or a project, a parked item's session.
    public func go(to location: Location, by way: History.Way) {
        wentSomewhere()
        move { $0.go(to: location, by: way) }
    }

    /// Back a step, where there is one.
    public func goBack() {
        wentSomewhere()
        move { $0.goBack() }
        openTheFoldOverThePick()
    }

    /// Forward a step, where Back left one.
    public func goForward() {
        wentSomewhere()
        move { $0.goForward() }
        openTheFoldOverThePick()
    }

    /// Lee went somewhere himself: a run of picks waiting is let go, and so is a session opened from outside waiting
    /// on the first board, which would otherwise take him from where he went.
    private func wentSomewhere() {
        picks = PickFollows()
        landing = nil
    }

    /// Lee picked a row of the list at this time, by a click: it replaces the step the window is on, making none, the
    /// list's order held for a second after it, so no row moves between two presses of a key, and what it follows
    /// settled (`PickFollows`). Whether it picked it: a row a board has just dropped, which the list still drew, picks
    /// nothing.
    @discardableResult
    public func pickInList(_ pick: ListPick, at time: Date) -> Bool {
        guard let place = location.place, let selection = arranged(place).selection(of: pick) else {
            return false
        }

        pickInList(selection, at: time)
        return true
    }

    /// ↓, or ↑, in the list at this time: the row after the pick, or before it, as the list shows it, from where the pick
    /// stood where the list no longer shows it (`PlaceList.step(from:down:)`), picked as a click picks it; nowhere past
    /// either end.
    public func step(down: Bool, at time: Date) {
        if let place = location.place, let next = arranged(place).step(from: location.picked, down: down) {
            pickInList(next, at: time)
        }
    }

    private func pickInList(_ selection: Selection, at time: Date) {
        landing = nil
        held.picked(in: .list, at: time)
        picks.picked(at: time, following: following)
        move { $0.pick(selection) }
    }

    /// Return in the Filter field: the first match the list shows, picked; with none, or no list beside the page, the
    /// first project that matches, opened.
    public func openFirstMatch() {
        guard !filter.isEmpty else {
            return
        }

        if let place = location.place, let first = arranged(place).shown.first {
            wentSomewhere()
            move { $0.pick(arranged(place).selection(of: first.pick)) }
        } else if let project = places.projects.first {
            go(to: .project(project.id), by: .sidebar)
        }
    }

    /// The fold at a place's list's foot clicked, "N snoozed" or "N earlier": it opens in place, or folds; while the
    /// filter holds text, which shows it open, nothing changes.
    public func toggleFold(of place: Place) {
        if filter.isEmpty {
            openFolds.formSymmetricDifference([place])
            keepTheList()
        }
    }

    /// The history moved as given, while the window is open or minimised. Another page turned to lets go of the last
    /// page's asks kept in place, of what is opened in place, of what its cards said of refusals and of a finish asked
    /// about; and each session the page shows keeps its asks in place.
    private func move(_ change: (inout History) -> Void) {
        guard var history else {
            return
        }

        let leaf = history.location.leaf

        change(&history)
        self.history = history
        turned(from: leaf)
        keepTheList()
    }

    private func turned(from leaf: Leaf) {
        if location.leaf != leaf {
            details.turnPage()
        }
        keepShown()
        keepLooked()
    }

    // MARK: Where Lee looked

    /// The session whose page shows to Lee, beside a place's list or filling the window, alike, while the window shows;
    /// none for a parked item's page, which is not its session's, a project's, or a place with nothing picked.
    private var sessionShowing: String? {
        guard looks.isShowing, case let .session(id)? = location.page else {
            return nil
        }
        return id
    }

    /// What shows now, as the window changed (`keepLooked(showing:)`).
    private func keepLooked() {
        keepLooked(showing: sessionShowing)
    }

    /// The session whose page shows now, as given: a session's page showing before and not now, Lee looked at it now,
    /// by the wall clock. Only then, so while it shows its look holds still.
    private func keepLooked(showing now: String?) {
        if let showing, showing != now {
            looked.stopped(showing: showing, at: wall())
        }
        showing = now
    }

    /// The fold at the list's foot holding the pick, opened, so the pick shows: as a session opened from outside lands
    /// under it, and as the filter clears.
    private func openTheFoldOverThePick() {
        if let place = location.place, PlaceList(place, in: listed).folds(location.picked?.pick) {
            openFolds.insert(place)
        }
    }

    /// Each session the page shows keeps its asks in place, from its board as last kept, which is its first where it
    /// is current.
    private func keepShown() {
        details.keep(Array(shown))
    }

    /// The sessions the page shows (`Location.following(on:)`).
    private var shown: Set<String> {
        location.following(on: given)
    }

    // MARK: Following sessions' boards

    /// The sessions whose boards the window follows, for `watch` to carry on its lines: those the page shows, only
    /// while the window shows, but a run of picks in the list follows only its last, once the picks stop.
    public var following: Set<String> {
        isOpen ? picks.standing ?? shown : []
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

    /// The terminal app showing the session, as the last look at the screen says; none where none is known to.
    public func appShowing(_ session: String) -> String? {
        looks.app(of: session)
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
        let carried = last.board?.session(ask.session)?.session.asks.first { $0.id == ask.ask }

        return details.press(button, on: ask, carried: carried, at: time)
    }

    /// Escape: the answer pressed last on the page showing, still waiting, is taken back; one waiting on a page
    /// left goes as it would. Whether there was one.
    public func undo() -> Bool {
        details.undo(where: undoes) != nil
    }

    /// Whether Escape reaches an answer on this ask: beside a place's list, only on the card leading, as the session's
    /// other asks are rows of their own, not on screen; filling the window, on any ask of the sessions it shows.
    private func undoes(_ ask: AskAddress) -> Bool {
        guard location.place != nil else {
            return shown.contains(ask.session)
        }
        return location.picked?.pick.lineKey == ask.key
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

    /// An item opened in place to the whole of it, or closed again (`Item`). Another page turned to closes them all.
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

    /// The sidebar under the Filter field: the places with the board's counts, then the projects the filter keeps, in
    /// the order the projects' column shows.
    public var places: Places {
        held.arranged(Places(listed, filter: filter))
    }

    /// The list beside the page at this time, where the window is on a place, in the order it shows, narrowed by the
    /// filter, its washes under way, Your turn's rows past the fold period by the wall clock under "N earlier"; none
    /// for a project's page or a session's, which fill the window.
    public func list(at time: Date) -> PlaceList? {
        guard let place = location.place else {
            return nil
        }

        return held.arranged(list(of: place, in: washing(listed, at: time)))
    }

    /// A place's list as it shows, held, filtered, folded and narrowed, with no washes.
    func arranged(_ place: Place) -> PlaceList {
        held.arranged(list(of: place, in: listed))
    }

    /// A place's list on this board, filtered and folded, Parked's narrowed to its scope where the window is on it.
    private func list(of place: Place, in listed: Listed) -> PlaceList {
        let scope = location.place == place ? location.scope : .all

        return PlaceList(place, in: listed, filter: filter, isFoldOpen: openFolds.contains(place), scope: scope)
    }

    /// The board with its washes under way at this time: each line new on the board, outside Snoozed, whose rows
    /// never wash.
    private func washing(_ listed: Listed, at time: Date) -> Listed {
        let live = Wash.live(washed, at: time)
        var shown = listed

        shown.changeRows { row in
            if row.section != .snoozed {
                row.lines.indices.forEach { row.lines[$0].washed = live[row.lines[$0].id] }
            }
        }
        return shown
    }

    /// How long a your-turn row stays in Your turn before it folds into "N earlier", from its turn's end: the window's
    /// own, since Settings' "Your turn folds after" went with the card's "N earlier" (board J2, 4 November 2026).
    private static let foldPeriod: TimeInterval = 3600

    /// The board, its your-turn rows marked where they have passed the fold period by the wall clock.
    private var listed: Listed {
        let now = wall()
        var marked = given

        marked.changeRows { row in
            row.isEarlier = row.section == .yourTurn && Self.folds(row) <= now
        }
        return marked
    }

    /// When on the wall clock the next of Your turn's rows passes the fold period, folding into "N earlier".
    private var nextRefold: Date? {
        let now = wall()

        return given.rows(in: .yourTurn).map(Self.folds).filter { $0 > now }.min()
    }

    /// When a your-turn row folds into "N earlier".
    private static func folds(_ row: Listed.Row) -> Date {
        row.since.addingTimeInterval(foldPeriod)
    }

    /// The page at this time, its washes under way: beside a place's list, the session its pick shows, led by the
    /// picked line's card, or the parked item picked, or with nothing picked how the board stands; filling the window,
    /// a project's page or a session's.
    public func page(at time: Date) -> Page {
        details.prune(at: time)
        guard let board = last.board else {
            return .empty(given.head.title)
        }

        switch location {
        case let .place(_, picked, _):
            guard let id = picked?.session else {
                return board.projects.isEmpty ? .nothingOpen : .empty(given.head.title)
            }
            if case let .parked(_, item) = picked?.pick {
                return parkedPage(item, of: id, on: board)
            }
            return board.session(id).map { found in
                .detail(sessionPage(found.session, of: found.project, on: board, as: .detail, leading: picked?.pick, at: time))
            }
                ?? .nothingOpen
        case let .project(key):
            return board.projects.first { $0.key == key }.map { .project(projectPage($0, at: time)) }
                ?? .nothingOpen
        case let .session(id, _):
            return board.session(id).map { found in
                .session(sessionPage(found.session, of: found.project, on: board, as: .full, at: time))
            }
                ?? .nothingOpen
        }
    }

    /// The next time something the window shows changes by time alone: an answer's wait running out, a column
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
}
