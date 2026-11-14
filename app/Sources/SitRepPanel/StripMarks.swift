import CoreGraphics
import Foundation

/// A mark: its place along the strip, its scale and its opacity, each a spring.
final class StripMark {
    /// What it is, which a snooze or a wake renames as the session's row moves into Snoozed or out of it.
    var key: MarkKey
    /// Its session as last told; nil for a count, ...
    var session: Session?
    /// ... which holds this many.
    var count = 0
    var y = Spring(0)
    var sc = Spring(1)
    var op: Spring
    /// How far its ring has lifted under the pointer, 0 to 1.
    var lift = Spring(0)
    /// Not yet placed: its first place it takes at once.
    var fresh = true
    /// Gone into a count.
    var folded = false
    var removing = false
    /// When it arrived in Needs you, or one landed in it, when its ring flashes, and the arrival it shows: an ask's,
    /// washed, a stop's, or none.
    var arrived = -1e9
    var flashes: [Double] = []
    var shows = StripArrival.quiet
    /// A count's: the session whose arrival it shows.
    var arrivalOf: String?
    /// How it shows its arrival once it has grown into its place.
    var arrival = StripArrival.ask
    /// A count's look as it last showed, which it keeps as it goes; and whether it holds its section folded, which
    /// says how many it holds with no "+".
    var look: StripFrame.Mark.Look?
    var isFolded = false
    /// A new mark waiting to grow until the mark below has slid out of its way: which, and from where; ...
    var gap: (below: MarkKey, from: Double)?
    /// ... or until the strip has come out of the notch at rest.
    var waitsForColumn = false

    init(_ key: MarkKey, session: Session?, opacity: Double) {
        self.key = key
        self.session = session
        op = Spring(opacity)
    }

    func step(_ dt: Double) {
        y.step(dt)
        sc.step(dt)
        op.step(dt)
        lift.step(dt)
    }
}

/// How a mark coming into Needs you shows it arrived (DESIGN, "The strip", 14 November 2026): an ask washed and its
/// ring flashing; a session stopping, its ring flashing; or neither, where Lee has that pulse off.
enum StripArrival {
    case ask, stop, quiet

    /// What waits on Lee arriving, shown as his pulses say: flashing where he has its pulse on, else quiet.
    init(_ need: Need, pulses: Set<Need>) {
        guard pulses.contains(need) else {
            self = .quiet
            return
        }

        switch need {
        case .ask: self = .ask
        case .turn: self = .stop
        }
    }

    /// What it shows arrived: an ask, Lee's turn, or nothing.
    var need: Need? {
        switch self {
        case .ask: .ask
        case .stop: .turn
        case .quiet: nil
        }
    }
}

/// How the strip's places go: how many it has, and of each section, how many marks show and whether it has a count,
/// of those past its room or, folded, of them all.
struct StripAllotment: Equatable {
    let places: Int
    let shown: [BoardSection: Int]
    let counted: Set<BoardSection>

    /// A section's marks showing.
    func shown(_ section: BoardSection) -> Int {
        shown[section, default: 0]
    }
}

/// A section's count: its place, the sessions it holds by their marks' keys, and whether it holds the section
/// folded, all of it, or those past its room.
struct StripCount: Equatable {
    let y: Double
    let held: [String]
    let isFolded: Bool

    var n: Int { held.count }
}

/// One of the hairlines between two sections, and how much of it shows.
struct StripHair {
    var y = Spring(0)
    var op = Spring(0)

    mutating func step(_ dt: Double) {
        y.step(dt)
        op.step(dt)
    }

    /// At its place at once, as the screen changes.
    mutating func snapToPlace() {
        y.snap(y.target)
    }
}

/// Where everything goes, from the strip's order: each mark's place, each section's count and what it holds, the
/// hairlines', and where the strip runs.
struct StripLayout {
    var places: [(id: String, y: Double)] = []
    var counts: [BoardSection: StripCount] = [:]
    /// The hairline over each section after the first showing, by the section under it.
    var hairs: [BoardSection: Double] = [:]
    /// How many places it has.
    var count = 0
    /// The strip's top end, how long it runs, and its bottom end.
    var top = 0.0, length = 0.0, bottom = 0.0
    /// Nothing is running.
    var isEmpty = true

    /// The sections a hairline can go over: any after the first.
    static let hairlined = Array(BoardSection.allCases.dropFirst())

    func y(of id: String) -> Double? {
        places.first { $0.id == id }?.y
    }

    /// The sessions a section's count holds, none where it has none.
    func rest(of section: BoardSection) -> [String] {
        counts[section]?.held ?? []
    }

    /// The count holding a session, past its section's room or folded, if one does.
    func count(holding id: String) -> StripCount? {
        counts.values.first { $0.held.contains(id) }
    }
}

extension Strip {
    /// The strip's places: what the full height holds, each hairline taking 13pt more than a step, or Max, in Grows,
    /// if fewer, Max's slider running from five to what it holds; never under two, nor under one for each section
    /// showing. Each section takes its places in its turn, keeping one for each after it that holds any (14 November
    /// 2026): Needs you, its asks and its stopped, first, then Working, Snoozed last. A section folded takes one, its
    /// count. Past its room a section shows its first marks and, in its last place, its own count of the rest, the end
    /// of its order, so Needs you's stopped fold before its asks and its away before the rest.
    func allot(_ sizes: [BoardSection: Int]) -> StripAllotment {
        let showing = BoardSection.allCases.filter { sizes[$0, default: 0] > 0 }
        let full = fullPlaces(hairlines: Swift.max(0, showing.count - 1))
        var places = full
        if length == .grows, let most = maxLength.places(longest: full) {
            places = min(places, most)
        }
        places = Swift.max(2, showing.count, places)

        var shown: [BoardSection: Int] = [:], counted: Set<BoardSection> = [], left = places
        for (i, section) in showing.enumerated() {
            let room = left - (showing.count - 1 - i), n = sizes[section]!
            if folded.contains(section) {
                counted.insert(section)
                left -= 1
            } else if n <= room {
                shown[section] = n
                left -= n
            } else {
                shown[section] = room - 1
                counted.insert(section)
                left -= room
            }
        }
        return StripAllotment(places: places, shown: shown, counted: counted)
    }

    /// How many of the strip's marks each section holds, as its order stands, and this many more arriving in Needs
    /// you.
    func sizes(arriving: Int = 0) -> [BoardSection: Int] {
        display.reduce(into: [.needsYou: arriving]) { sizes, id in
            if let section = slot[id] {
                sizes[section, default: 0] += 1
            }
        }
    }

    /// A mark every 30pt from under the top end, a hairline between each two sections, and in each section's last
    /// place its count, past what fits or folded. The strip runs, at Grows, as long as its marks need (its two ends,
    /// Room inside each, the marks between), centred on the notch's place and held inside the screen; with nothing
    /// running, the notch at rest; past the full strip, or at Full, the full strip.
    func computeLayout() -> StripLayout {
        let groups = BoardSection.allCases.map { section in (section, display.filter { slot[$0] == section }) }
        let a = allot(Dictionary(uniqueKeysWithValues: groups.map { ($0.0, $0.1.count) }))
        let shown: [(key: MarkKey, section: BoardSection)] = groups.flatMap { section, ids in
            ids.prefix(a.shown(section)).map { (MarkKey.session($0), section) }
                + (a.counted.contains(section) ? [(MarkKey.count(section), section)] : [])
        }

        var rel: [Double] = [], y = 0.0, hairRel: [BoardSection: Double] = [:]
        for (i, place) in shown.enumerated() {
            if i > 0, shown[i - 1].section != place.section {
                let line = y + StripTuning.hair
                hairRel[place.section] = line
                y = line + StripTuning.hair
            } else if i > 0 {
                y += StripTuning.pitch
            }
            rel.append(y)
        }

        let full = stage.height - stage.menu - StripTuning.bottomEnd
        let need = display.isEmpty ? StripTuning.notchHeight : rel.last! + 2 * endPad
        let grows = length == .grows && need <= full
        let length = grows ? need : full
        let top = grows ? clamp(centre - length / 2, stage.menu, bottomEnd - length) : stage.menu
        let y0 = grows ? top + endPad : firstY

        var layout = StripLayout(
            hairs: hairRel.mapValues { y0 + $0 }, count: a.places, top: top, length: length,
            bottom: grows ? top + length : bottomEnd, isEmpty: display.isEmpty
        )
        let held = Dictionary(
            uniqueKeysWithValues: groups.map { section, ids in (section, ids.dropFirst(a.shown(section))) }
        )
        for (place, y) in zip(shown, rel.map { y0 + $0 }) {
            switch place.key {
            case let .session(id): layout.places.append((id, y))
            case let .count(section):
                layout.counts[section] = StripCount(
                    y: y, held: Array(held[section] ?? []), isFolded: folded.contains(section)
                )
            case .empty: break
            }
        }
        return layout
    }

    /// The shape changed (Room, Length or Max): any tab goes, the marks slide to their new places, and the next hover
    /// opens under the new shape. With nothing running there is nothing to move.
    func relayoutShape() {
        guard !display.isEmpty else {
            return
        }

        tabs.forEach(removeTab)
        cancel(.dwell, .grace, .jumpGo)
        if case let .mark(key) = jumping {
            mark(key)?.sc.snap(1)
        }
        jumping = nil
        hot = nil
        freeze = false
        relayout()
    }

    /// Lays the marks out again: they slide to their places, and fold into a count or out of it; the ends follow.
    func relayout(snapAll: Bool = false) {
        let before = layout
        layout = computeLayout()
        let onStrip = Set(display)
        var moved = false
        func move(_ spring: inout Spring, _ y: Double) -> Bool {
            guard abs(spring.target - y) >= 0.01 || snapAll else {
                return false
            }

            moved = true
            if snapAll {
                spring.snap(y)
            } else if dragging {
                // carried by a drag: they follow the pointer
                to(&spring, y, 50)
            } else if reducesMotion {
                // a cross-fade: it fades in at its place
                spring.snap(y)
                return true
            } else {
                spring.springTo(y, feel.sp(.slide))
            }
            return false
        }

        for m in marks where !m.removing {
            // a session lifted out to arrive has no place until it is in again, nor a count to go into
            guard case let .session(id) = m.key, onStrip.contains(id) else {
                continue
            }

            if let y = layout.y(of: id) {
                if m.fresh {
                    m.fresh = false
                    m.y.snap(y)
                    continue
                }
                if move(&m.y, y) {
                    m.op.x = 0
                }
                if m.folded {
                    m.folded = false
                    to(&m.op, 1, 180)
                } else if reducesMotion, m.op.x < 1 {
                    to(&m.op, 1, 160)
                }
            } else if let into = layout.count(holding: id) {
                fold(m, into: into.y, move)
            }
        }

        for section in StripLayout.hairlined {
            placeHair(section, move)
        }
        for section in BoardSection.allCases {
            placeCount(section, move)
        }

        if moved, let live = liveTab(), live.phase == .open {
            // Lee's choice: while marks slide, an open tab keeps with its mark
            freeze = true
        }
        layEnds(snapAll: snapAll)
        followCounts(before)
    }

    /// A mark going into a count, or one already in it whose count moved.
    private func fold(_ m: StripMark, into y: Double, _ move: (inout Spring, Double) -> Bool) {
        if m.fresh {
            m.fresh = false
            m.y.snap(y)
            m.op.x = 0
            m.folded = true
            to(&m.op, 0, 1)
        } else if !m.folded {
            m.folded = true
            _ = move(&m.y, y)
            to(&m.op, 0, 200)
        } else if abs(m.y.target - y) > 0.01 {
            _ = move(&m.y, y)
        }
    }

    /// The hairline over a section: it fades in where it comes, slides, or fades out where it goes.
    private func placeHair(_ section: BoardSection, _ move: (inout Spring, Double) -> Bool) {
        guard let y = layout.hairs[section] else {
            return to(&hairs[section]!.op, 0, 200)
        }

        if hairs[section]!.op.target < 0.5 {
            hairs[section]!.y.snap(y)
            to(&hairs[section]!.op, 1, 220)
        } else {
            _ = move(&hairs[section]!.y, y)
        }
    }

    /// A section's count: it arrives growing, slides, or goes.
    private func placeCount(_ section: BoardSection, _ move: (inout Spring, Double) -> Bool) {
        guard let spec = layout.counts[section] else {
            if let c = counts[section], !c.removing {
                c.removing = true
                to(&c.op, 0, 200)
            }
            return
        }

        let c = counts[section] ?? StripMark(.count(section), session: nil, opacity: 0)
        counts[section] = c
        c.count = spec.n
        c.isFolded = spec.isFolded
        if c.removing || c.op.target < 0.5 {
            c.removing = false
            c.y.snap(spec.y)
            c.sc.x = 0.6
            springTo(&c.sc, 1, .arrive)
            to(&c.op, 1, 180)
        } else if move(&c.y, spec.y) {
            c.op.x = 0
        }
    }

    /// A count's tab follows what it holds, and goes with it; the notch at rest's says nothing is running only while
    /// nothing is.
    private func followCounts(_ before: StripLayout) {
        guard let live = liveTab() else {
            return
        }

        if let section = live.key.section, live.phase == .open {
            if layout.counts[section] == nil {
                drawBack(live)
            } else if layout.rest(of: section) != before.rest(of: section) {
                relayer(live, live.key, 0)
            }
        }
        if live.key == .empty, !(layout.isEmpty && length == .grows) {
            drawBack(live)
        }
    }

    /// The strip's ends, to where the layout has it run, on the marks' slide spring: quicker by Lead as it grows, so
    /// the black is there before the marks, slower by it otherwise, so as it shrinks the marks are in before the black
    /// follows; at once, carried by a drag. Emptied, once its last marks have faded, the column narrows and shortens
    /// into the notch at rest on the morph spring; and a first session grows it back out. Under reduced motion the
    /// strip takes its new length, or the notch's shape, at once, the old shape fading out over it.
    private func layEnds(snapAll: Bool) {
        let top = layout.top, bottom = layout.bottom, toNotch = length == .grows && layout.isEmpty
        let shifts = abs(yt.target - top) > 0.01 || abs(yb.target - bottom) > 0.01
        if reducesMotion, !snapAll, shifts || drawnIn.target != (toNotch ? 1 : 0) {
            fade = (lastStrip ?? CGMutablePath(), t)
        }
        if snapAll || reducesMotion {
            yt.snap(top)
            yb.snap(bottom)
        } else if shifts, dragging {
            to(&yt, top, 50)
            to(&yb, bottom, 50)
        } else if shifts {
            let growing = bottom - top > yb.target - yt.target + 0.01
            yt.springTo(top, feel.ends(growing: growing))
            yb.springTo(bottom, feel.ends(growing: growing))
        }

        if toNotch {
            if drawnIn.target < 1, !timers.has(.morph) {
                if snapAll || reducesMotion {
                    drawnIn.snap(1)
                } else {
                    later(.morph, StripTuning.morphWait) { $0.springTo(&$0.drawnIn, 1, .morph) }
                }
            }
        } else {
            cancel(.morph)
            if drawnIn.target > 0 {
                if snapAll {
                    drawnIn.snap(0)
                } else {
                    springTo(&drawnIn, 0, .morph)
                }
            }
        }
    }

    /// Grows: the notch's place, held so the notch at rest stays inside the screen.
    func clampCentre(_ y: Double) -> Double {
        let half = StripTuning.notchHeight / 2
        return clamp(y, stage.menu + half, Swift.max(stage.menu + half, bottomEnd - half))
    }

    func markOf(_ s: Session) -> StripMark {
        if let m = mark(.session(s.markID)) {
            return m
        }

        let m = StripMark(.session(s.markID), session: s, opacity: 1)
        marks.append(m)
        return m
    }

    func mark(_ key: MarkKey) -> StripMark? {
        switch key {
        case .session: marks.first { $0.key == key }
        case let .count(section): counts[section]
        case .empty: nil
        }
    }

    /// The y a key's mark sits at, by the layout (where marks are going): a folded session's, its count's.
    func yOf(_ key: MarkKey) -> Double {
        switch key {
        case let .session(id): layout.y(of: id) ?? layout.count(holding: id)?.y ?? 0
        case let .count(section): layout.counts[section]?.y ?? 0
        case .empty: layout.top + layout.length / 2
        }
    }

    /// Where a session's own mark is going, by its key, by the layout, never a place it slides through on the way: half
    /// the strip's depth in, at its place's height. Nil while it has no place of its own, folded into a count or not
    /// yet on the strip.
    public func markTarget(of id: String) -> CGPoint? {
        layout.y(of: id).map { CGPoint(x: front / 2, y: $0) }
    }

    /// The mark under the pointer's height: the nearest centre, within `near`.
    func keyAt(_ y: Double) -> MarkKey? {
        let sessions = layout.places.map { (MarkKey.session($0.id), $0.y) }
        let counts = BoardSection.allCases.compactMap { section in
            layout.counts[section].map { (MarkKey.count(section), $0.y) }
        }
        var best: MarkKey?, bd = Double.infinity
        for (key, py) in sessions + counts where abs(py - y) < bd {
            bd = abs(py - y)
            best = key
        }
        return bd <= StripTuning.near ? best : nil
    }

    /// The strip takes the panel's order, the marks sliding to their places.
    func resort() {
        cancel(.settle)
        takeOrder()
        pendingSort = false
        relayout()
    }

    /// The marks in the panel's order, and the section each sits in: Needs you's, its asks and its stopped, over the
    /// hairline (14 November 2026; its asks alone until then), Working's under it, and Snoozed's under their own.
    func takeOrder() {
        display = sessions.map(\.markID)
        slot = Dictionary(sessions.map { ($0.markID, $0.section) }) { first, _ in first }
    }

    func settleLater() {
        if !timers.has(.settle) {
            later(.settle, feel.settle) { $0.resort() }
        }
    }

    /// A change shown in place: a count's tab holding it takes its new words, and its own tab with what else changed
    /// (`show`).
    func changed(_ s: Session) {
        mark(.session(s.markID))?.session = s
        if let live = liveTab(), live.phase == .open, let section = live.key.section,
           layout.rest(of: section).contains(s.markID)
        {
            relayer(live, live.key, 0)
        }
        pendingSort = true
        if !over {
            settleLater()
        }
    }

    /// A new needs you moves in at once, under the needs you the panel's order has above it, or first where it has
    /// none. Past needs you's room an ask takes its place all the same while a stopped mark shows below it, the last
    /// of them going into the count (Lee, 14 November 2026); else it lands in the count, and the marks showing stay
    /// where they are. Taking a place, the marks below slide down a step, and it grows into its place as the mark
    /// below gets out of the way, showing its arrival as `how` says. Landing in the count, it leaves the count's flash
    /// to its caller, which knows what else the update put there.
    func insertNeeds(_ s: Session, _ how: StripArrival) {
        let end = display.prefix { slot[$0] == .needsYou }.count
        let above = sessions.prefix { $0.markID != s.markID }.last { slot[$0.markID] == .needsYou }
        var i = above.flatMap { display.firstIndex(of: $0.markID) }.map { $0 + 1 } ?? 0
        let a = allot(sizes(arriving: 1))
        if a.counted.contains(.needsYou), i < a.shown(.needsYou) {
            if s.need == .ask, let stop = lastStopShowing(from: i, end: end) {
                pushOut(at: stop.at, shown: stop.shown)
            } else {
                i = a.shown(.needsYou)
            }
        }
        display.insert(s.markID, at: i)
        slot[s.markID] = .needsYou
        let m = markOf(s)
        m.arrival = how
        relayout()
        guard !layout.rest(of: .needsYou).contains(s.markID) else {
            return
        }

        m.op.snap(0)
        guard !reducesMotion else {
            to(&m.op, 1, 160)
            return arrive(m, how)
        }

        m.sc.snap(0.3)
        let next = display[(i + 1)...].first { layout.y(of: $0) != nil }.map(MarkKey.session)
        let below = next ?? BoardSection.allCases.map(MarkKey.count).first { key in
            key.section.flatMap { layout.counts[$0] } != nil && mark(key) != nil
        }
        let spring = below.flatMap(mark)?.y
        m.gap = spring.flatMap { abs($0.target - $0.x) > 1 ? (below!, $0.x) : nil }
        if drawnIn.x > StripTuning.marksGo {
            // out of the notch at rest: it grows in once the column is out
            m.waitsForColumn = true
        } else if m.gap == nil {
            grow(m)
        }
    }

    /// The last stopped mark showing at place `i` or under it, of the `end` on the needs you side, and how many of
    /// them show; nil with none. What shows is worked out from the order as it stands, never the layout, which a
    /// session lifted out to arrive has left stale: its place under the hairline gone, Needs you may have more room.
    private func lastStopShowing(from i: Int, end: Int) -> (at: Int, shown: Int)? {
        let room = allot(sizes()), shown = room.counted.contains(.needsYou) ? room.shown(.needsYou) : end

        return display.prefix(shown).lastIndex { session($0)?.need == .turn }.flatMap { $0 >= i ? ($0, shown) : nil }
    }

    /// The stopped mark at `at` made the last of the `shown` showing, so the ask going in above it pushes it into the
    /// count; any tab of its draws back, as a mark's leaving does.
    private func pushOut(at index: Int, shown: Int) {
        let id = display.remove(at: index)

        display.insert(id, at: shown - 1)
        tabs.filter { $0.key == .session(id) }.forEach(drawBack)
    }

    func grow(_ m: StripMark) {
        m.gap = nil
        m.waitsForColumn = false
        guard !m.folded else {
            // it went into a count before it grew in: it stays out of sight there
            return m.sc.snap(1)
        }

        springTo(&m.sc, 1, .arrive)
        to(&m.op, 1, 100)
        arrive(m, m.arrival)
    }

    /// Just arrived: its ring flashes Swells times, 450ms apart, and an ask's is washed; a quiet arrival shows neither,
    /// and ends any earlier one's still showing, so an ask's flash never runs on after its session stops. Arrivals in
    /// one moment, as several landing in the count in one update, add up: an ask's shows over a stop's, and neither
    /// gives way to a later one.
    func arrive(_ m: StripMark, _ how: StripArrival) {
        if m.arrived == t {
            if how == .ask {
                m.shows = .ask
            }
            return
        }
        guard how != .quiet else {
            m.arrived = -1e9
            m.flashes = []
            m.shows = .quiet
            return
        }

        m.arrived = t
        m.shows = how
        m.flashes = (0 ..< Swift.max(0, feel.swells)).map { t + Double($0) * StripTuning.flashGap }
    }

    /// A new mark waiting grows once the strip is out of the notch at rest, or once the mark below has slid `growAt`
    /// of its step.
    func growIfClear(_ m: StripMark) {
        if m.waitsForColumn {
            if drawnIn.x <= StripTuning.marksGo {
                grow(m)
            }
            return
        }
        guard let gap = m.gap else {
            return
        }
        guard let below = mark(gap.below)?.y else {
            return grow(m)
        }

        let span = below.target - gap.from
        if abs(span) < 1 || (below.x - gap.from) / span >= StripTuning.growAt {
            grow(m)
        }
    }

    /// Sessions on the strip arriving in needs you, taken from their places to move in as a new needs you does,
    /// unplaced and out of any count: any tab of theirs draws back, as a mark's leaving does.
    func lift(_ crossing: [Session]) {
        let ids = Set(crossing.map(\.markID))

        for tab in tabs {
            if case let .session(id) = tab.key, ids.contains(id) {
                drawBack(tab)
            }
        }
        for s in crossing {
            if let m = mark(.session(s.markID)) {
                m.session = s
                m.fresh = true
                m.folded = false
            }
        }
        display.removeAll(where: ids.contains)
        ids.forEach { slot[$0] = nil }
    }

    /// A mark already on the needs you side arriving again, a new line needing Lee or its session stopping: its ring
    /// flashes where it is, or its count's, past its room or folded, as `how` says; quiet, its own mark's earlier
    /// arrival ends.
    func flashInPlace(_ s: Session, _ how: StripArrival) {
        if layout.rest(of: .needsYou).contains(s.markID) {
            landInCount(s, how)
        } else if let m = mark(.session(s.markID)) {
            m.arrival = how
            arrive(m, how)
        }
    }

    /// One arriving in needs you's count, past its room or folded: the count flashes as `how` says, for it, unless an
    /// ask's landing there in the same moment outshows it; quiet, it keeps what an earlier arrival there shows, unless
    /// that was this session's own, which ends.
    func landInCount(_ s: Session, _ how: StripArrival) {
        guard let count = counts[.needsYou], how != .quiet || count.arrivalOf == s.markID else {
            return
        }

        arrive(count, how)
        if count.shows == .quiet {
            count.arrivalOf = nil
        } else if count.shows == how {
            count.arrivalOf = s.markID
        }
    }

    /// Sessions leaving: each mark fades and shrinks where it is, and the rest close up; Grows, the strip shrinks with
    /// them, with nothing left into the notch at rest.
    func leave(_ gone: Set<String>) {
        for tab in tabs {
            if case let .session(id) = tab.key, gone.contains(id) {
                drawBack(tab)
            }
        }
        for m in marks where !m.removing {
            if case let .session(id) = m.key, gone.contains(id) {
                m.removing = true
                to(&m.op, 0, 200)
                springTo(&m.sc, 0.6, .slide)
            }
        }
        display.removeAll(where: gone.contains)
        gone.forEach { slot[$0] = nil }
        relayout()
    }
}
