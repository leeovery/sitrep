import CoreGraphics
@testable import SitRepPanel

/// The strip driven as the view will drive it: a frame every 1/60s, the pointer where a scenario puts it. The screen
/// is the recording's, 626 tall under a 26pt menu bar, and the sessions its prototype's. Unless a test says otherwise
/// the strip is at Full, as the prototype was when most of its scenarios were recorded, and Max is Full.
struct StripLab {
    static let frameMS = 1000.0 / 60
    static let stage = StripStage(width: 1076, height: 626, menu: 26)
    /// How many marks the full strip holds on the recording's screen, at Lee's Room: Max's slider's right end.
    static let longest = 16

    /// Max where it gives the recording's screen this many places, as the prototype's Max set them in marks.
    static func maxLength(marks: Int?) -> StripMax {
        marks.map { StripMax(share: Double($0 - StripMax.fewest) / Double(longest - StripMax.fewest)) } ?? .full
    }

    let model: Strip
    var now = 1000.0
    var pointer: CGPoint?
    var reducesMotion: Bool
    private(set) var frame: StripFrame

    init(
        sessions: [Session] = Self.prototype, length: StripLength = .full, maxMarks: Int? = nil,
        feel: StripFeel = .lees, pointer: CGPoint? = nil, reducesMotion: Bool = false
    ) {
        self.pointer = pointer
        self.reducesMotion = reducesMotion
        let input = StripInput(time: now, pointer: pointer, stage: Self.stage, reducesMotion: reducesMotion)
        model = Strip(
            feel: feel, length: length, maxLength: Self.maxLength(marks: maxMarks), sessions: Self.core(sessions),
            measure: Self.measure, input
        )
        frame = model.frame(input)
        // as the recorder runs the page 1200ms before a scenario, a frame every 16ms, in which a count there from the
        // start grows in; whole steps, so a step of 16 is 16 and not 15.999..., which springs integrate otherwise
        if pointer == nil {
            for _ in 0 ..< 75 {
                step(at: now + 16)
            }
        }
    }

    /// The board with a new ask on it, new on its line.
    func newAsk(_ ask: Session) {
        show(model.sessions + [ask], new: [ask.id])
    }

    /// The board with these on it too, none of them new: sessions that started, or asks on a first line.
    func add(_ sessions: [Session]) {
        show(model.sessions + sessions)
    }

    /// The board with a session's row changed, holding a line new on it that needs Lee.
    func arrive(_ session: Session) {
        show(model.sessions.map { $0.id == session.id ? session : $0 }, new: [session.id])
    }

    /// The board with a session's row changed.
    func change(_ session: Session) {
        show(model.sessions.map { $0.id == session.id ? session : $0 })
    }

    /// The board with these gone from it.
    func remove(_ ids: [String]) {
        show(model.sessions.filter { !ids.contains($0.id) })
    }

    private func show(_ sessions: [Session], new: Set<String> = []) {
        model.show(Self.core(sessions), new: new)
    }

    /// The rows in the order core gave them as the prototype's timelines were recorded, which the recordings hold
    /// them to: needs you, oldest first, away ones last; your turn, newest first; working, longest running first; on
    /// its own work, which they never had, last; on a tie, as they were. Core has since put working, then on its own
    /// work, before your turn (`core/rows.ts`), which the strip draws as it comes.
    static func core(_ sessions: [Session]) -> [Session] {
        func key(_ row: (offset: Int, element: Session)) -> (Int, Double, Int) {
            let s = row.element
            return switch s.kind {
            case .needs: (s.away ? 1 : 0, s.since, row.offset)
            case .turn: (2, -s.since, row.offset)
            case .working: (3, s.since, row.offset)
            case .onItsWork: (4, s.since, row.offset)
            }
        }
        return sessions.enumerated().sorted { key($0) < key($1) }.map(\.element)
    }

    mutating func step() {
        step(at: now + Self.frameMS)
    }

    mutating func step(at time: Double) {
        now = time
        frame = model.frame(StripInput(time: now, pointer: pointer, stage: Self.stage, reducesMotion: reducesMotion))
    }

    /// Frames with the pointer where it is, for up to this long or until the condition holds: whether it did.
    @discardableResult
    mutating func wait(_ ms: Double, until done: (Self) -> Bool = { _ in false }) -> Bool {
        let end = now + ms
        while now < end {
            step()
            if done(self) {
                return true
            }
        }
        return false
    }

    /// Frames until nothing moves, up to a limit: whether it came to rest.
    @discardableResult
    mutating func settle(within ms: Double = 5000) -> Bool {
        wait(ms) { !$0.frame.isMoving }
    }

    /// The pointer on a mark's centre, x 18 into the strip.
    func on(_ id: String) -> CGPoint {
        on(.session(id))
    }

    func on(_ key: MarkKey) -> CGPoint {
        CGPoint(x: 18, y: model.yOf(key))
    }

    /// The pointer on a mark until its tab is out and still.
    mutating func open(_ id: String) {
        open(.session(id))
    }

    mutating func open(_ key: MarkKey) {
        pointer = on(key)
        wait(1000) { $0.model.liveTab()?.phase == .open }
        settle()
    }

    /// The pointer on an open tab, past the strip, then moving straight down off it this far a frame, until it is off
    /// the strip and the tab: the sim time it left them.
    mutating func leave(by step: Double) -> Double {
        pointer = CGPoint(x: 200, y: live!.y.x)
        wait(100)
        while model.over, pointer!.y < Self.stage.height {
            pointer!.y += step
            self.step()
        }
        return model.t
    }

    var live: StripTab? { model.liveTab() }

    /// The mark's spring's three as they are now.
    func mark(_ id: String) -> StripRecorded.Mark? {
        model.mark(.session(id)).map { StripRecorded.Mark(y: $0.y.x, sc: $0.sc.x, op: $0.op.x) }
    }

    /// The scenario's first action, then a frame at each of the recording's times after it, with the pointer as the
    /// strip took it, and each later action after the first frame at or past its time, as the recorder ran them.
    mutating func play(
        _ recorded: [StripRecorded], marks ids: [String] = [], _ actions: [(at: Double, act: (inout Self) -> Void)]
    ) -> [StripPlayed] {
        let start = now
        var due = actions
        while let first = due.first, first.at <= 0 {
            first.act(&self)
            due.removeFirst()
        }
        return recorded.map { r in
            pointer = r.p
            step(at: start + r.t)
            let played = StripPlayed(self, marks: ids)
            while let next = due.first, r.t >= next.at {
                next.act(&self)
                due.removeFirst()
            }
            return played
        }
    }
}

/// A frame as the model played it, in the recording's terms.
struct StripPlayed {
    let t: Double
    let hair: StripRecorded.Mark
    let ends: StripRecorded.Ends
    let jumping: String?
    let tabs: [StripRecorded.Tab]
    let marks: [StripRecorded.Mark?]
    let more, moreNeeds: StripRecorded.Count?

    init(_ lab: StripLab, marks ids: [String]) {
        let model = lab.model
        t = lab.now
        hair = StripRecorded.Mark(y: model.hair.x, sc: 1, op: model.hairOp.x)
        ends = StripRecorded.Ends(top: model.yt.x, bottom: model.yb.x, drawnIn: model.drawnIn.x)
        jumping = switch model.jumping {
        case let .tab(_, id): "tab \(id)"
        case let .mark(key): "mark \(key.name)"
        case nil: nil
        }
        tabs = zip(model.tabs, lab.frame.tabs).map { tab, shown in
            let g = model.tabGeometry(tab), fit = g.w > 0.01 ? model.tabFit(g) : nil
            return StripRecorded.Tab(
                key: tab.key.name, phase: tab.phase, w: tab.w.x, h: tab.h.x, y: tab.y.x, press: tab.press.x,
                alpha: tab.alpha.x, words: shown.words.map { StripRecorded.Words(key: $0.key.name, alpha: $0.alpha) },
                top: fit.map { .init($0.top, y: model.yt.x + $0.top.y) },
                bottom: fit.map { .init($0.bottom, y: model.yb.x - $0.bottom.y) }
            )
        }
        marks = ids.map(lab.mark)
        func count(_ m: StripMark?) -> StripRecorded.Count? {
            m.map { StripRecorded.Count(n: $0.count, mark: StripRecorded.Mark(y: $0.y.x, sc: $0.sc.x, op: $0.op.x)) }
        }
        more = count(model.more)
        moreNeeds = count(model.moreNeeds)
    }

    /// The same strip as the prototype's: the springs and the fillets to the recording's six decimals, the words'
    /// opacity to the browser's three.
    func matches(_ r: StripRecorded) -> Bool {
        same(hair, r.hair) && same(ends, r.ends) && jumping == r.jumping
            && tabs.count == r.tabs.count && zip(tabs, r.tabs).allSatisfy(same)
            && marks.count == r.marks.count && zip(marks, r.marks).allSatisfy(same)
            && same(more, r.more) && same(moreNeeds, r.moreNeeds)
    }

    /// The worst gap between the two, over every spring.
    func error(against r: StripRecorded) -> Double {
        let tabGaps = zip(tabs, r.tabs).flatMap { a, b in
            [a.w - b.w, a.h - b.h, a.y - b.y, a.press - b.press, a.alpha - b.alpha]
        }
        let markGaps = zip(marks, r.marks).flatMap { a, b in
            a.flatMap { a in b.map { b in [a.y - b.y, a.sc - b.sc, a.op - b.op] } } ?? []
        }
        let endGaps = [ends.top - r.ends.top, ends.bottom - r.ends.bottom, ends.drawnIn - r.ends.drawnIn]
        return ([hair.y - r.hair.y, hair.op - r.hair.op] + endGaps + tabGaps + markGaps).map(abs).max() ?? 0
    }

    /// The worst gap between the two over the tabs' fillets: where each leaves the edge, its radius and its angle.
    func fitError(against r: StripRecorded) -> Double {
        zip(tabs, r.tabs).flatMap { a, b in [(a.top, b.top), (a.bottom, b.bottom)] }.flatMap { a, b in
            a.flatMap { a in b.map { b in [a.x - b.x, a.y - b.y, a.rho - b.rho, a.phi - b.phi].map(abs) } } ?? []
        }.max() ?? 0
    }

    /// The worst gap in the words' opacity.
    func wordsError(against r: StripRecorded) -> Double {
        zip(tabs, r.tabs).flatMap { zip($0.words, $1.words).map { abs($0.alpha - $1.alpha) } }.max() ?? 0
    }

    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-6 }

    private func same(_ a: StripRecorded.Ends, _ b: StripRecorded.Ends) -> Bool {
        close(a.top, b.top) && close(a.bottom, b.bottom) && close(a.drawnIn, b.drawnIn)
    }

    private func same(_ a: StripRecorded.Count?, _ b: StripRecorded.Count?) -> Bool {
        guard let a, let b else {
            return a == nil && b == nil
        }

        return a.n == b.n && same(a.mark, b.mark)
    }

    private func same(_ a: StripRecorded.Mark?, _ b: StripRecorded.Mark?) -> Bool {
        guard let a, let b else {
            return a == nil && b == nil
        }

        return close(a.y, b.y) && close(a.sc, b.sc) && close(a.op, b.op)
    }

    private func same(_ a: StripRecorded.Tab, _ b: StripRecorded.Tab) -> Bool {
        a.key == b.key && a.phase == b.phase && close(a.w, b.w) && close(a.h, b.h) && close(a.y, b.y)
            && close(a.press, b.press) && close(a.alpha, b.alpha)
            && a.words.map(\.key) == b.words.map(\.key)
            && zip(a.words, b.words).allSatisfy { abs($0.alpha - $1.alpha) < 6e-4 }
            && same(a.top, b.top) && same(a.bottom, b.bottom)
    }

    private func same(_ a: StripRecorded.End?, _ b: StripRecorded.End?) -> Bool {
        guard let a, let b else {
            return a == nil && b == nil
        }

        return a.on == b.on && close(a.x, b.x) && close(a.y, b.y) && close(a.rho, b.rho) && close(a.phi, b.phi)
    }
}

extension StripRecorded.End {
    /// A fillet as the model fits it, on the screen at this height.
    init(_ fit: StripFit, y: Double) {
        self.init(x: fit.x, y: y, rho: fit.rho, phi: fit.phi * 180 / .pi, on: fit.onS ? .s : .edge)
    }
}

extension MarkKey {
    /// As the recording names it: the session's id, "more", "moreNeeds", or "empty".
    var name: String {
        switch self {
        case let .session(id): id
        case .more: "more"
        case .moreNeeds: "moreNeeds"
        case .empty: "empty"
        }
    }
}

extension StripLab {
    private static let minute = 60_000.0, hour = 60 * minute, day = 24 * hour

    /// The prototype's eight sessions (its `SESSIONS`), ids in the order it adds them, each come to stand where it is
    /// as long ago as the prototype has it.
    static let prototype = [
        Session(id: "s1", project: "SitRep", kind: .needs, title: "Approve the round 2 drawings", sub: "SitRep · The Mac app", since: -1 * hour),
        Session(id: "s2", project: "Switchboard", kind: .needs, title: "Keep the old dashboard cache?", sub: "Switchboard · Dashboard memory fix", since: -12 * minute),
        Session(id: "s3", project: "agntc", kind: .needs, title: "Allow Bash ", code: "gh release create v0.5.3", sub: "agntc · v0.5.3: moved-skill remedy", since: -4 * minute),
        Session(id: "s4", project: "Terrace", kind: .needs, away: true, title: "Approve the plan for the tool", sub: "No window holds it. Carry it on in Claude.", since: -1 * day),
        Session(id: "s5", project: "Fumi", kind: .turn, title: "The management window is sketched", sub: "Fumi · Management window discussion", since: -20 * minute),
        Session(id: "s6", project: "Goosemates", kind: .turn, title: "Waiting for the next round of feedback", sub: "Goosemates · Settle the older open questions", since: -3 * hour),
        Session(id: "s7", project: "DocMan", kind: .working, title: "Running the exception reporting tests", sub: "DocMan · Fix inverted exception reporting", since: -12 * minute),
        Session(id: "s8", project: "Turnstile", kind: .working, title: "Fixing the limiter's reset", sub: "Turnstile · Exception reporting", since: -3 * minute),
    ]

    /// The prototype's first new ask.
    static var ask: Session { asks[0] }

    /// The prototype's new asks (its `ASKS`), round its five again to eight.
    static let asks = (0 ..< 8).map { i in
        let ask = fiveAsks[i % fiveAsks.count]
        return Session(
            id: "s\(9 + i)", project: ask.project, kind: .needs, title: ask.title, code: ask.code, more: ask.more,
            sub: ask.sub, since: 0
        )
    }

    private static let fiveAsks: [(project: String, title: String, code: String?, more: String?, sub: String, then: String)] = [
        ("Mint", "Choose the diff budget", nil, nil, "Mint · Token-aware diff sizing", "Sizing the diffs"),
        ("Fabric", "Allow Bash ", "aws sso login --profile dev", nil, "Fabric · Atlas overload from llm-manager", "Signing in to the dev account"),
        ("Switchboard", "Give the go for stage 3", nil, nil, "Switchboard · Milestone 7 stages 4 to 14", "Running stage 3"),
        ("Aircon", "Which unit is the bedroom?", nil, "+2", "Aircon · Aircon local control", "Naming the units"),
        ("Agentic Workflows", "Approve the reshaped review workflow", nil, nil, "Agentic Workflows · Reshape the workflows", "Reshaping the workflows"),
    ]

    /// The prototype's Ask answered, on its sessions: the oldest needs you a window holds, SitRep's, starts working.
    static var answered: Session {
        var s = prototype[0]
        s.kind = .working
        s.lines[0].title = "Drawing the strip in Paper"
        s.lines[0].since = 0
        return s
    }

    /// One of the new asks answered, as the prototype answers it: it starts working on what it does once answered.
    static func answered(ask id: String) -> Session {
        var s = asks.first { $0.id == id }!
        s.kind = .working
        s.lines[0].title = fiveAsks.first { $0.project == s.project }!.then
        s.lines[0].code = nil
        s.lines[0].more = nil
        s.lines[0].since = 1
        return s
    }

    /// The prototype's Too many: twenty-two more, past what the strip holds.
    static let tooMany: [Session] = [
        ("Aircon", Session.Kind.working, "Probing the unit's local API", "Aircon · Aircon local control", 40.0),
        ("Kit", .working, "Writing the bootstrap's tests", "Kit · The bootstrap", 35),
        ("Mint", .turn, "The diff sizing is drafted", "Mint · Token-aware diff sizing", 50),
        ("Fabric", .working, "Reading the Atlas logs", "Fabric · Atlas overload from llm-manager", 25),
        ("Agentic Workflows", .working, "Reshaping the review workflow", "Agentic Workflows · Reshape the workflows", 22),
        ("Agentic Skills", .turn, "The Laravel skills are reviewed", "Agentic Skills · Review the Laravel skills", 90),
        ("Switchboard", .working, "Running the usage ledger tests", "Switchboard · Usage", 18),
        ("SitRep", .working, "Building the app", "SitRep · Jump to session", 16),
        ("DocMan", .turn, "The upload fix is up for review", "DocMan · Upload limits", 75),
        ("Turnstile", .working, "Profiling the dispatcher", "Turnstile · Dispatcher limiter", 14),
        ("Goosemates", .working, "Drafting the release notes", "Goosemates · Release 2.4", 11),
        ("agntc", .turn, "v0.5.3 is tagged", "agntc · Release notes", 30),
        ("Terrace", .working, "Sketching the tool", "Terrace · The first cut", 9),
        ("Fumi", .working, "Wiring the management window", "Fumi · Management window", 8),
        ("Mint", .working, "Counting tokens per hunk", "Mint · Hunk budgets", 7),
        ("Kit", .turn, "The dotfiles are linked", "Kit · Dotfiles", 120),
        ("Aircon", .working, "Mapping the units", "Aircon · Discovery", 6),
        ("Fabric", .turn, "The plan for the dev account is ready", "Fabric · Dev account", 60),
        ("Switchboard", .turn, "Stage 4 is done", "Switchboard · Milestone 7 stages 4 to 14", 45),
        ("SitRep", .working, "Tracing the jump outside tmux", "SitRep · Jump test outside tmux", 5),
        ("DocMan", .working, "Rebasing onto main", "DocMan · Upload limits", 4),
        ("Turnstile", .turn, "The limiter fix is in", "Turnstile · Exception reporting", 100),
    ].enumerated().map { i, extra in
        Session(
            id: "s\(9 + i)", project: extra.0, kind: extra.1, title: extra.2, sub: extra.3, since: -extra.4 * minute
        )
    }

    /// The words as wide as the browser measured them, by their lines; any other, as narrow as a tab gets.
    static var measure: StripMeasure {
        func width(_ lines: String) -> Double {
            (StripRecorded.widths[lines] ?? StripTuning.tabMin) - StripTuning.tabSlack
        }
        return StripMeasure(
            row: { width(lines($0)) },
            rows: { width($0.map(lines).joined(separator: "\n")) },
            idle: { width("\(StripFrame.Words.Content.idleTitle)|\(StripFrame.Words.Content.idleLine2)") }
        )
    }

    /// A row's two lines as the prototype set them, whose widths it recorded: its oldest line's title, command and
    /// "+2", an ask's words where the app now shows its session's name; the line under it.
    private static func lines(_ s: Session) -> String {
        let line = s.lines[0]

        return "\(line.title)\(line.code ?? "")\(line.more ?? "")|\(s.sub)"
    }
}
