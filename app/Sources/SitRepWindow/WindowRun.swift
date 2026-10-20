import Foundation
import SitRepCore
import SitRepPanel

/// A run of `sitrep board --json` the window asks for: the session, and its ticket, so only the latest asked for a
/// session is taken, however the runs' answers cross.
public struct Read: Hashable, Sendable {
    public let session: String
    let ticket: Int
}

/// The SitRep window as the app runs it, with nothing of the screen in it: the board from `watch`'s lines in the
/// order it shows, what Lee picked and what the window opens on, the sessions' boards it reads for their detail, the
/// asks of the page shown kept in place, the answers waiting out their two seconds, and finishing an away session. Every
/// input comes through here, at the time given; the views draw what it says, and the app runs what it asks for: a
/// read of a session's board, an answer, a finish, a jump.
public final class WindowRun {
    /// The board as `watch` last printed it.
    public private(set) var last = LastBoard()
    public private(set) var pick: Pick?
    /// The session picked last, which the window opens on when nothing needs Lee.
    public private(set) var lastSession: String?
    /// The window shows: only then are sessions' boards read.
    public private(set) var isOpen = false
    public private(set) var answers = Answers()
    /// The list as `watch` gives it, before it is held.
    private var given = Listed()
    private var held = HeldOrder()
    private var listed = Listed()
    /// Sessions new to needing Lee, washed from when they came.
    private var washed: [String: Date] = [:]
    private var boards: [String: SessionBoard] = [:]
    private var failed: [String: String] = [:]
    private var tickets: [String: Int] = [:]
    /// The asks of each session the page shows, kept in place while it stands.
    private var frozen: [String: Frozen] = [:]
    private var finishing: [String: Finish] = [:]
    /// The asks opened in place in a project's view.
    private var opened: Set<AskAddress> = []

    public init(lastSession: String? = nil) {
        self.lastSession = lastSession
    }

    // MARK: The board

    /// The board as `watch` last printed it, heard at this time: the list takes it, held or not, a session new to
    /// needing Lee moving in at once, washed unless motion is reduced; the sessions shown are read again where `watch`
    /// says their boards changed, or all of them on a board resumed after `watch` was down. A pick gone from the board
    /// gives way to what the window opens on. The reads to run.
    public func show(_ last: LastBoard, at time: Date, reducesMotion: Bool) -> [Read] {
        let board = last.board
        let moving = last.stale == nil ? board.map(Self.newToNeedingLee) ?? [] : []

        self.last = last
        take(Listed(last), moving: moving)
        if !reducesMotion {
            moving.forEach { washed[$0] = time }
        }
        if let board {
            finishing = finishing.filter { board.session($0.key)?.session.doing.isAway ?? false }
        }
        guard isOpen, let board else {
            return []
        }
        guard let pick, board.has(pick) else {
            return repick()
        }

        keepShown()
        return reads(last.isResumed ? shown : shown.filter(board.changed.contains))
    }

    /// With no `watch` to run, the head says why.
    public func unrun(_ why: String) {
        take(Listed(unrun: why), moving: [])
    }

    /// The pointer came over the list, or left it, at this time.
    public func pointer(isIn: Bool, at time: Date) {
        held.pointer(isIn: isIn, at: time)
    }

    /// The second after the pointer left the list has run out by this time: it takes `watch`'s order.
    public func settle(at time: Date) {
        if held.settle(at: time) {
            take(given, moving: [])
        }
    }

    private func take(_ given: Listed, moving: Set<String>) {
        self.given = given
        listed = held.take(given, moving: moving)
    }

    // MARK: Opening and picking

    /// The window opens: on the oldest session that needs Lee; with none, on the one picked last. The reads to run.
    public func open() -> [Read] {
        isOpen = true
        return repick()
    }

    /// The window closes: the list's hold lets go, as the pointer leaves with it, and a finish asked about lapses.
    public func close() {
        isOpen = false
        held.release()
        take(given, moving: [])
        dropAskingToFinish()
    }

    /// What the window opens on, picked afresh.
    private func repick() -> [Read] {
        pick = nil
        return last.board.flatMap(opening).map { self.pick($0) } ?? []
    }

    private func opening(_ board: Board) -> Pick? {
        if let needing = board.rows.first(where: \.needsLee) {
            return .session(needing.session)
        }
        if let lastSession, board.has(.session(lastSession)) {
            return .session(lastSession)
        }
        return listed.sessions.first.map { .session($0.id) }
    }

    /// Lee picked a session, or a project by its name: what it shows is read, its asks showing as last read until
    /// then. Picking another lets go of the last page's asks kept in place, of what its cards said of refusals, and
    /// of a finish asked about. The reads to run.
    public func pick(_ pick: Pick) -> [Read] {
        if pick != self.pick {
            self.pick = pick
            frozen = [:]
            opened = []
            answers.forgetRefusals()
            dropAskingToFinish()
            if case let .session(id) = pick {
                lastSession = id
            }
        }
        keepShown()
        return reads(shown)
    }

    /// Each session the page shows keeps its asks in place, from its board as last read.
    private func keepShown() {
        for session in shown where frozen[session] == nil {
            frozen[session] = Frozen(session: session, read: boards[session])
        }
    }

    /// The sessions the page shows, which are read.
    private var shown: [String] {
        switch pick {
        case let .session(id)?: [id]
        case let .project(key)?: last.board?.projects.first { $0.key == key }?.sessions.map(\.id) ?? []
        case nil: []
        }
    }

    // MARK: Reading sessions' boards

    private func reads(_ sessions: [String]) -> [Read] {
        sessions.map { session in
            let ticket = tickets[session, default: 0] + 1

            tickets[session] = ticket
            return Read(session: session, ticket: ticket)
        }
    }

    /// What a read of a session's board came to, at this time: only the latest asked for a session is taken. A
    /// failure keeps what was read before.
    public func read(_ read: Read, gave answer: BoardAnswer, at time: Date, reducesMotion: Bool) {
        guard tickets[read.session] == read.ticket else {
            return
        }

        switch answer {
        case let .board(board):
            boards[read.session] = board
            failed[read.session] = nil
            answers.settle(board.asks, of: read.session, read: read.ticket)
            frozen[read.session]?.take(board, washingAt: reducesMotion ? nil : time)
        case let .failed(why):
            failed[read.session] = why
        }
    }

    // MARK: Answering

    /// A card's button pressed at this time: a yes, an option or ignore waits its two seconds; one that needs Claude
    /// Code's prompt jumps instead. The session to jump to, for those.
    public func press(_ button: Card.Button, on ask: AskAddress, at time: Date) -> String? {
        guard let answer = button.answer else {
            return ask.session
        }

        answers.press(answer, on: ask, at: time)
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

    /// What `sitrep answer` came to: written, the session is read again, if it shows, and the card takes the word
    /// of the first read asked for since, for where the answer is; refused, the card says why, unless the board as
    /// read has the ask settled. The reads to run.
    public func answered(_ ask: AskAddress, _ written: WriteAnswer) -> [Read] {
        switch written {
        case .written:
            answers.written(ask, after: tickets[ask.session, default: 0])
            return reads(shown.filter { $0 == ask.session })
        case let .refused(why):
            answers.refused(ask, why, on: boards[ask.session]?.asks)
            return []
        }
    }

    /// An ask in a project's view opened in place into its card, or closed back to its line.
    public func toggle(_ ask: AskAddress) {
        if opened.remove(ask) == nil {
            opened.insert(ask)
        }
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
    /// board; refused, it says why in place.
    public func finished(_ session: String, _ written: WriteAnswer) {
        if case let .refused(why) = written {
            finishing[session] = .refused(why)
        }
    }

    /// A finish asked about, or refused, lapses as the page changes; one running goes on.
    private func dropAskingToFinish() {
        finishing = finishing.filter { $0.value == .finishing }
    }

    // MARK: What it shows

    /// The board down the left at this time, in the order it shows, its washes under way.
    public func listed(at time: Date) -> Listed {
        washed = Wash.live(washed, at: time)

        var shown = listed

        shown.projects = shown.projects.map { project in
            var project = project

            project.sessions = project.sessions.map { row in
                var row = row

                row.washed = washed[row.id]
                return row
            }
            return project
        }
        return shown
    }

    /// The right of the window at this time, its washes under way.
    public func page(at time: Date) -> Page {
        for session in frozen.keys {
            frozen[session]?.prune(at: time)
        }
        guard let board = last.board else {
            return .empty(listed.head.title)
        }

        switch pick {
        case let .session(id)?:
            return board.session(id).map { .session(sessionPage($0.session, of: $0.project, at: time)) }
                ?? .nothingOpen
        case let .project(key)?:
            return board.projects.first { $0.key == key }.map { .project(projectPage($0, on: board, at: time)) }
                ?? .nothingOpen
        case nil:
            return board.projects.isEmpty ? .nothingOpen : .empty(listed.head.title)
        }
    }

    /// The next time something the window shows changes by time alone: an answer's wait running out, the list
    /// settling after the pointer left, a wash ending.
    public var nextChange: Date? {
        let washes = (Array(washed.values) + frozen.values.flatMap(\.washed.values))
            .map { $0.addingTimeInterval(Wash.length / 1000) }

        return ([answers.nextDue, held.resortsAt].compactMap { $0 } + washes).min()
    }

    /// Something moves at this time, which the views draw each frame: a wash, or an answer's wait draining.
    public func isMoving(at time: Date) -> Bool {
        answers.nextDue != nil || !Wash.live(washed, at: time).isEmpty
            || frozen.values.contains { !Wash.live($0.washed, at: time).isEmpty }
    }

    private func sessionPage(_ session: Board.Session, of project: Board.Project, at time: Date) -> SessionPage {
        let read = boards[session.id]
        let isAway = session.doing.isAway

        return SessionPage(
            id: session.id, projectKey: project.key, projectName: project.name, name: session.name,
            summary: session.summary, doing: session.doing, jumps: !isAway, waiting: session.waiting,
            asks: cards(of: session, at: time),
            status: Status(now: session.now, next: session.next, updated: read?.log.first { $0.kind == .status }?.at),
            notes: read.map { Self.notes($0.log, of: session, named: false) } ?? [],
            parked: read?.parked.map { Parked(id: $0.id, session: nil, title: $0.title, at: $0.at) } ?? [],
            resolved: read.map { Self.resolved($0, leaving: frozen[session.id]?.kept ?? []) } ?? [],
            finish: isAway ? finishing[session.id] ?? .offered : nil,
            isRead: read != nil,
            failure: failed[session.id]
        )
    }

    private func projectPage(_ project: Board.Project, on board: Board, at time: Date) -> ProjectPage {
        let needs = board.rows.filter { $0.project == project.key && $0.needsLee }
        let read = project.sessions.compactMap { session in boards[session.id].map { (session, $0) } }

        return ProjectPage(
            key: project.key, name: project.name, waiting: needs.count, open: project.open,
            sessions: project.sessions.map { session in
                ProjectPage.Session(
                    id: session.id, name: session.name, mark: Mark(session.state), isAway: session.doing.isAway,
                    doing: session.doing,
                    waiting: needs.filter { $0.session == session.id }.count, since: session.since
                )
            },
            asksWaiting: project.sessions.map(\.waiting).reduce(0, +),
            asks: project.sessions.flatMap { session in
                cards(of: session, at: time).map { card in
                    ProjectPage.Ask(session: session.name, card: card, isOpened: opened.contains(card.id))
                }
            }.sorted { $0.card.since > $1.card.since },
            notes: Array(read.flatMap { Self.notes($1.log, of: $0, named: true) }.sorted { $0.at > $1.at }.prefix(Self.projectNotes)),
            parked: read.flatMap { session, read in
                read.parked.map { Parked(id: "\(session.id):\($0.id)", session: session.name, title: $0.title, at: $0.at) }
            }.sorted { $0.at < $1.at }
        )
    }

    /// A session's asks as cards: kept in place while the page stands, else as last read, the newest first.
    private func cards(of session: Board.Session, at time: Date) -> [Card] {
        let kept = frozen[session.id]
        let asks = kept?.asks ?? (boards[session.id]?.asks.reversed() ?? []).map { ($0, nil) }
        let washes = Wash.live(kept?.washed ?? [:], at: time)

        return asks.map { ask, closed in
            let address = AskAddress(session: session.id, ask: ask.id)

            return Card(ask, of: session.id, doing: session.doing, pending: answers.pending[address], closed: closed, washed: washes[ask.id])
        }
    }

    /// How many of its latest notes a project's view lists, as many as a session's board carries.
    private static let projectNotes = 8

    /// A session's log lines as notes, each by an id that stays as lines come: its session's and its own, or, for
    /// a line without one, its kind and time. In a project's view each names its session.
    private static func notes(_ log: [SessionBoard.Line], of session: Board.Session, named: Bool) -> [Note] {
        log.map { line in
            let own = line.id ?? "\(line.kind.rawValue)@\(line.at.timeIntervalSince1970)"

            return Note(id: "\(session.id):\(own)", session: named ? session.name : nil, text: line.text, at: line.at)
        }
    }

    private static func resolved(_ board: SessionBoard, leaving kept: Set<String>) -> [Resolved] {
        board.resolved.filter { !kept.contains($0.id) }.map { resolved in
            Resolved(id: resolved.id, title: resolved.ask.title, closed: resolved.closedAt ?? resolved.ask.at, how: Card.closed(resolved.id, in: board))
        }
    }

    /// The sessions whose rows `watch` says are new and need Lee.
    private static func newToNeedingLee(_ board: Board) -> Set<String> {
        let new = Set(board.new)

        return Set(board.rows.filter { new.contains($0.key) }.map(\.session))
    }
}

extension Board {
    /// A session on the board, with its project.
    func session(_ id: String) -> (session: Session, project: Project)? {
        projects.lazy.compactMap { project in project.sessions.first { $0.id == id }.map { ($0, project) } }.first
    }

    func has(_ pick: Pick) -> Bool {
        switch pick {
        case let .session(id): session(id) != nil
        case let .project(key): projects.contains { $0.key == key }
        }
    }
}
