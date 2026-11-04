import Foundation
import SitRepCore
import SitRepPanel

/// The detail of the sessions the window's page shows, as `WindowRun` keeps it: each session's board as a line last
/// carried it, the sessions told to `watch` and those current since, why a line carried none, the asks of the page
/// kept in place while it is held, the answers waiting out their two seconds, finishing an away session, what a snooze
/// or a wake pressed on a card came to, and what is opened in place; and from these, a session's asks as cards and
/// what it resolved.
struct Details: Equatable, Sendable {
    /// The answers waiting out their two seconds.
    private(set) var answers = Answers()
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
    /// The items of Status, Notes, Parked and Resolved opened in place.
    private var openedItems: Set<Item> = []

    // MARK: Holding the page

    /// A region of the page found the pointer over it, or not, at this time: the page is held while any region has it.
    mutating func pointer(overPage isIn: Bool, from region: ObjectIdentifier, at time: Date) {
        if isIn {
            regionsUnderPointer.insert(region)
        } else {
            regionsUnderPointer.remove(region)
        }
        holdPage(at: time)
    }

    /// The window became key, or stopped being, at this time: in a window not key the pointer holds no page, as a
    /// pointer resting on a window Lee is not using would hold its closed asks for as long as it rests.
    mutating func window(isKey: Bool, at time: Date) {
        self.isKey = isKey
        holdPage(at: time)
    }

    private mutating func holdPage(at time: Date) {
        pageHeld.pointer(isIn: !regionsUnderPointer.isEmpty && isKey, at: time)
    }

    /// What has run out by this time: the second after the pointer left the page, and the closed asks leave it.
    mutating func settle(at time: Date) {
        pageHeld.settle(at: time)
        letGoOfClosedAsks()
    }

    /// The pointer gone with the window, which tells no exit: the page's hold lets go, and the closed asks leave it.
    mutating func letGoOfHold() {
        regionsUnderPointer = []
        pageHeld.release()
        letGoOfClosedAsks()
    }

    /// Unless the page is held, the closed asks leave it, for Resolved; one with Lee's press on it still pending stays
    /// until the press settles.
    private mutating func letGoOfClosedAsks() {
        guard !pageHeld.isHeld else {
            return
        }

        let answering = Dictionary(grouping: answers.pending.keys, by: \.session).mapValues { Set($0.map(\.ask)) }

        for session in frozen.keys {
            frozen[session]?.letGoOfClosed(but: answering[session] ?? [])
        }
    }

    // MARK: The page shown

    /// Another page picked: it lets go of the last page's asks kept in place, of what is opened in place, of what its
    /// cards said of refusals, and of a finish asked about.
    mutating func turnPage() {
        frozen = [:]
        openedItems = []
        unslept = [:]
        answers.forgetRefusals()
        dropAskingToFinish()
    }

    /// Each session the page shows keeps its asks in place, from its board as last kept, which is its first where it
    /// is current.
    mutating func keep(_ shown: [String]) {
        for session in shown where frozen[session] == nil {
            frozen[session] = Frozen(session: session, kept: boards[session], isCurrent: current.contains(session))
        }
    }

    /// The washes ended by this time let go.
    mutating func prune(at time: Date) {
        for session in frozen.keys {
            frozen[session]?.prune(at: time)
        }
    }

    /// The next time the detail changes by time alone: an answer's wait running out, the closed asks leaving a second
    /// after the pointer left the page, a wash ending.
    var nextChange: Date? {
        let washes = frozen.values.flatMap(\.washed.values).map { $0.addingTimeInterval(Wash.length / 1000) }

        return ([answers.nextDue, pageHeld.endsAt].compactMap { $0 } + washes).min()
    }

    // MARK: Following sessions' boards

    /// What a session's page says where a line carries no board of it, `watch` finding no such session.
    static let notOnTheBoard = "This session isn't on the board."

    /// What a session's page says where a line carries a board of it this app cannot read.
    static let unreadBoard = "sitrep watch gave a board of this session that this SitRep cannot read."

    /// The sessions `watch` is told to follow now: those left out break their spans, so their boards as kept are no
    /// longer current, as `watch` carries each afresh once it is followed again.
    mutating func follow(_ sessions: Set<String>) -> Set<String> {
        told = sessions
        current.formIntersection(told)
        return told
    }

    /// A session's board as a line carried it, from a look `watch` began at this time, what is new on it washed from
    /// this other time, if one is given, and current while it is followed. Or none, as `watch` found no such session,
    /// or none this app can read: either says so over its board as last kept, and keeps it, no longer current.
    mutating func take(_ carried: Board.Carried, of session: String, lookedAt look: Date, washingAt time: Date?) {
        guard case let .board(board) = carried else {
            failed[session] = carried == .notFound ? Self.notOnTheBoard : Self.unreadBoard
            current.remove(session)
            answers.noBoard(of: session)
            return
        }

        if told.contains(session) {
            current.insert(session)
        }
        boards[session] = board
        failed[session] = nil
        answers.settle(board.asks, of: session, lookedAt: look)
        frozen[session]?.take(board, washingAt: time)
        letGoOfClosedAsks()
    }

    /// A session's board as last kept.
    func board(of session: String) -> SessionBoard? {
        boards[session]
    }

    /// Why the latest line to carry a session's board carried none.
    func failure(of session: String) -> String? {
        failed[session]
    }

    // MARK: Answering

    /// A card's button pressed at this time: a yes, an option or ignore waits its two seconds; one that needs Claude
    /// Code's prompt jumps instead. The session to jump to, for those.
    mutating func press(_ button: Card.Button, on ask: AskAddress, at time: Date) -> String? {
        if case .inClaude = button {
            return ask.session
        }
        if let answer = button.answer {
            answers.press(answer, on: ask, at: time)
        }
        return nil
    }

    /// The answer pressed last on these sessions, still waiting, taken back, if there was one.
    mutating func undo(on sessions: Set<String>) -> AskAddress? {
        answers.undo(on: sessions)
    }

    /// The answers whose two seconds have run out by this time.
    mutating func due(at time: Date) -> [(ask: AskAddress, answer: Answer)] {
        answers.due(at: time)
    }

    /// An answer written at this time.
    mutating func written(_ ask: AskAddress, at time: Date) {
        answers.written(ask, at: time)
    }

    /// An answer refused, in its words, unless its session's board as last kept has the ask settled.
    mutating func refused(_ ask: AskAddress, _ why: String) {
        answers.refused(ask, why, on: boards[ask.session]?.asks)
    }

    /// The board stale, so no board can come: an answer written is on its way.
    mutating func unwatched() {
        answers.unwatched()
    }

    // MARK: Opening in place

    /// An item of Status, Notes, Parked or Resolved opened in place to the whole of it, or closed again.
    mutating func toggle(_ item: Item) {
        if openedItems.remove(item) == nil {
            openedItems.insert(item)
        }
    }

    /// The items opened that the page still shows, the rest let go, so one gone cannot open again by its key.
    mutating func keepOpen(_ shown: [Item]) -> Set<Item> {
        openedItems.formIntersection(shown)
        return openedItems
    }

    // MARK: Snoozing

    /// A time chosen on a card's Snooze, or its Wake now pressed: what its card said of a refusal before gives way.
    mutating func snoozing(_ ask: AskAddress) {
        unslept[ask] = nil
    }

    /// What `sitrep snooze` or `wake` came to for an ask of a card: refused, the card says why, in these words.
    /// Whether `watch` is to look now.
    mutating func slept(_ ask: AskAddress, _ written: WriteAnswer, refused: (String) -> Card.Line) -> Bool {
        guard case let .refused(why) = written else {
            return true
        }

        unslept[ask] = refused(why)
        return false
    }

    // MARK: Finishing

    /// Where a session's finish stands: offered, unless it is asked about, running or refused.
    func finish(of session: String) -> Finish {
        finishing[session] ?? .offered
    }

    /// "✓ Finish this session" pressed: it asks first, in place.
    mutating func askToFinish(_ session: String) {
        finishing[session] = .asking
    }

    /// Cancel: the offer comes back, unless `sitrep finish` runs already.
    mutating func cancelFinish(_ session: String) {
        if finishing[session] != .finishing {
            finishing[session] = nil
        }
    }

    /// "Yes, finish it": `sitrep finish` runs, unless it already does.
    mutating func confirmFinish(_ session: String) -> Bool {
        guard finishing[session] == .asking else {
            return false
        }

        finishing[session] = .finishing
        return true
    }

    /// What `sitrep finish` came to: refused, it says why in place. Whether `watch` is to look now.
    mutating func finished(_ session: String, _ written: WriteAnswer) -> Bool {
        guard case let .refused(why) = written else {
            return true
        }

        finishing[session] = .refused(why)
        return false
    }

    /// A finish asked about, or refused, lapses as the page changes; one running goes on.
    mutating func dropAskingToFinish() {
        finishing = finishing.filter { $0.value == .finishing }
    }

    /// Only the finishes of sessions the board still has away stand.
    mutating func keepFinishingAway(on board: Board) {
        finishing = finishing.filter { board.session($0.key)?.session.doing.isAway ?? false }
    }

    // MARK: Building

    /// A session's asks as cards: in the order they first showed on the page, those closed while it was held kept in
    /// their places, else as last kept, the newest first; those asleep after them, the soonest to wake first.
    func cards(of session: Board.Session, at time: Date) -> [Card] {
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

    /// A session's resolved asks as last kept, those still keeping their place among its asks aside.
    func resolved(of session: String) -> [Resolved] {
        boards[session].map { Self.resolved($0, leaving: frozen[session]?.kept ?? []) } ?? []
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
