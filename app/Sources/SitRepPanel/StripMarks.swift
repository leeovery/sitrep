import CoreGraphics
import Foundation

/// A mark: its place along the strip, its scale and its opacity, each a spring.
final class StripMark {
    let key: MarkKey
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
    /// When it arrived as a new needs you, or an ask landed in it, and when its ring flashes.
    var arrived = -1e9
    var flashes: [Double] = []
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

/// How the strip's places go: how many it has, and of needs you's and the rest's, how many marks show and whether
/// each folds the rest into its count.
struct StripAllotment: Equatable {
    let places: Int
    let asks: Int, foldsAsks: Bool
    let others: Int, foldsOthers: Bool
}

/// Where everything goes, from the strip's order: each mark's place, the counts' and what each holds, the hairline's,
/// and where the strip runs.
struct StripLayout {
    var places: [(id: String, y: Double)] = []
    /// The grey count, in the last place, ...
    var more: (y: Double, n: Int)?
    var rest: [String] = []
    /// ... and needs you's own orange one, at the end of its group.
    var moreNeeds: (y: Double, n: Int)?
    var restNeeds: [String] = []
    var hair: Double?
    /// How many places it has.
    var count = 0
    /// The strip's top end, how long it runs, and its bottom end.
    var top = 0.0, length = 0.0, bottom = 0.0
    /// Nothing is running.
    var isEmpty = true

    func y(of id: String) -> Double? {
        places.first { $0.id == id }?.y
    }

    func spec(of count: MarkKey) -> (y: Double, n: Int)? {
        count == .more ? more : moreNeeds
    }
}

extension Strip {
    /// The strip's places: what the full height holds, or Max, in Grows, if fewer, Max's slider running from five to
    /// what it holds; never under two. Needs you gets them first, but for one for your turn and working when there are
    /// any. Past its room, its first marks and, in its last place, its own count of the rest, newest and away ones
    /// last; then your turn and working, past theirs, their marks and the grey count in the last place.
    func allot(asks: Int, others: Int) -> StripAllotment {
        let full = fullPlaces(hairline: asks > 0 && others > 0)
        var places = full
        if length == .grows, let most = maxLength.places(longest: full) {
            places = min(places, most)
        }
        places = Swift.max(2, places)

        var shownAsks = asks, foldsAsks = false, shownOthers = others, foldsOthers = false
        if asks + others > places {
            let room = others > 0 ? places - 1 : places
            if asks > room {
                shownAsks = room - 1
                foldsAsks = true
            }
            let left = places - shownAsks - (foldsAsks ? 1 : 0)
            if others > left {
                shownOthers = left - 1
                foldsOthers = true
            }
        }
        return StripAllotment(
            places: places, asks: shownAsks, foldsAsks: foldsAsks, others: shownOthers, foldsOthers: foldsOthers
        )
    }

    /// A mark every 30pt from under the top end, the hairline under needs you, and past what fits, the counts. The
    /// strip runs, at Grows, as long as its marks need (its two ends, Room inside each, the marks between), centred on
    /// the notch's place and held inside the screen; with nothing running, the notch at rest; past the full strip, or
    /// at Full, the full strip.
    func computeLayout() -> StripLayout {
        let needs = display.filter(needsSlot.contains), others = display.filter { !needsSlot.contains($0) }
        let a = allot(asks: needs.count, others: others.count)
        let shown: [MarkKey] = needs.prefix(a.asks).map(MarkKey.session) + (a.foldsAsks ? [.moreNeeds] : [])
            + others.prefix(a.others).map(MarkKey.session) + (a.foldsOthers ? [.more] : [])
        func isNeeds(_ key: MarkKey) -> Bool {
            if case let .session(id) = key {
                return needsSlot.contains(id)
            }
            return key == .moreNeeds
        }

        var rel: [Double] = [], y = 0.0, hairRel: Double?
        for (i, key) in shown.enumerated() {
            if i > 0, isNeeds(shown[i - 1]), !isNeeds(key) {
                let line = y + StripTuning.hair
                hairRel = line
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
            rest: a.foldsOthers ? Array(others[a.others...]) : [],
            restNeeds: a.foldsAsks ? Array(needs[a.asks...]) : [], hair: hairRel.map { y0 + $0 }, count: a.places,
            top: top, length: length, bottom: grows ? top + length : bottomEnd, isEmpty: display.isEmpty
        )
        for (key, y) in zip(shown, rel.map { y0 + $0 }) {
            switch key {
            case let .session(id): layout.places.append((id, y))
            case .more: layout.more = (y, others.count - a.others)
            case .moreNeeds: layout.moreNeeds = (y, needs.count - a.asks)
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
        let foldsAsks = Set(layout.restNeeds)
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
            guard case let .session(id) = m.key else {
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
            } else if let into = foldsAsks.contains(id) ? layout.moreNeeds : layout.more {
                fold(m, into: into.y, move)
            }
        }

        if let y = layout.hair {
            if hairOp.target < 0.5 {
                hair.snap(y)
                to(&hairOp, 1, 220)
            } else {
                _ = move(&hair, y)
            }
        } else {
            to(&hairOp, 0, 200)
        }

        placeCount(\.more, layout.more, .more, move)
        placeCount(\.moreNeeds, layout.moreNeeds, .moreNeeds, move)

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

    /// A count: it arrives growing, slides, or goes.
    private func placeCount(
        _ slot: ReferenceWritableKeyPath<Strip, StripMark?>, _ spec: (y: Double, n: Int)?, _ key: MarkKey,
        _ move: (inout Spring, Double) -> Bool
    ) {
        guard let spec else {
            if let c = self[keyPath: slot], !c.removing {
                c.removing = true
                to(&c.op, 0, 200)
            }
            return
        }

        let c = self[keyPath: slot] ?? StripMark(key, session: nil, opacity: 0)
        self[keyPath: slot] = c
        c.count = spec.n
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

        let holds = [(MarkKey.more, layout.rest, before.rest), (.moreNeeds, layout.restNeeds, before.restNeeds)]
        for (key, held, was) in holds
            where live.key == key && live.phase == .open
        {
            if layout.spec(of: key) == nil {
                drawBack(live)
            } else if held != was {
                relayer(live, key, 0)
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
        if let m = mark(.session(s.id)) {
            return m
        }

        let m = StripMark(.session(s.id), session: s, opacity: 1)
        marks.append(m)
        return m
    }

    func mark(_ key: MarkKey) -> StripMark? {
        switch key {
        case .session: marks.first { $0.key == key }
        case .more: more
        case .moreNeeds: moreNeeds
        case .empty: nil
        }
    }

    /// The y a key's mark sits at, by the layout (where marks are going): a folded session's, its count's.
    func yOf(_ key: MarkKey) -> Double {
        switch key {
        case let .session(id):
            if let y = layout.y(of: id) {
                return y
            }
            if let into = layout.moreNeeds, layout.restNeeds.contains(id) {
                return into.y
            }
            return layout.more?.y ?? 0
        case .more, .moreNeeds: return layout.spec(of: key)?.y ?? 0
        case .empty: return layout.top + layout.length / 2
        }
    }

    /// The mark under the pointer's height: the nearest centre, within `near`.
    func keyAt(_ y: Double) -> MarkKey? {
        let sessions = layout.places.map { (MarkKey.session($0.id), $0.y) }
        let counts = [(MarkKey.more, layout.more?.y), (.moreNeeds, layout.moreNeeds?.y)].compactMap { key, y in
            y.map { (key, $0) }
        }
        var best: MarkKey?, bd = Double.infinity
        for (key, py) in sessions + counts where abs(py - y) < bd {
            bd = abs(py - y)
            best = key
        }
        return bd <= StripTuning.near ? best : nil
    }

    /// The strip takes core's order, the marks sliding to their places.
    func resort() {
        cancel(.settle)
        display = sessions.map(\.id)
        needsSlot = Set(sessions.filter { $0.kind == .needs }.map(\.id))
        pendingSort = false
        relayout()
    }

    func settleLater() {
        if !timers.has(.settle) {
            later(.settle, feel.settle) { $0.resort() }
        }
    }

    /// A change shown in place: an open tab of it, or a count's holding it, takes its new words.
    func changed(_ s: Session) {
        mark(.session(s.id))?.session = s
        for tab in tabs where tab.phase == .open && tab.key == .session(s.id) {
            relayer(tab, tab.key, 0)
        }
        if let live = liveTab(), live.phase == .open, live.key.isCount,
           (live.key == .more ? layout.rest : layout.restNeeds).contains(s.id)
        {
            relayer(live, live.key, 0)
        }
        pendingSort = true
        if !over {
            settleLater()
        }
    }

    /// A new needs you moves in at once, under the needs you core has above it, or first where core has none. Past
    /// needs you's room it lands in its count, which flashes, and the marks showing stay where they are; else the
    /// marks below slide down a step, and it grows into its place as the mark below gets out of the way, washed, its
    /// ring flashing.
    func insertNeeds(_ s: Session) {
        let end = display.prefix { needsSlot.contains($0) }.count
        let above = sessions.prefix { $0.id != s.id }.last { needsSlot.contains($0.id) }
        var i = above.flatMap { display.firstIndex(of: $0.id) }.map { $0 + 1 } ?? 0
        let a = allot(asks: end + 1, others: display.count - end)
        if a.foldsAsks, i < a.asks {
            i = a.asks
        }
        display.insert(s.id, at: i)
        needsSlot.insert(s.id)
        let m = markOf(s)
        relayout()
        if layout.restNeeds.contains(s.id) {
            if let count = moreNeeds {
                arrive(count)
            }
            return
        }

        m.op.snap(0)
        guard !reducesMotion else {
            to(&m.op, 1, 160)
            return arrive(m)
        }

        m.sc.snap(0.3)
        let next = display[(i + 1)...].first { layout.y(of: $0) != nil }.map(MarkKey.session)
        let below = next ?? [MarkKey.moreNeeds, .more].first { layout.spec(of: $0) != nil && mark($0) != nil }
        let spring = below.flatMap(mark)?.y
        m.gap = spring.flatMap { abs($0.target - $0.x) > 1 ? (below!, $0.x) : nil }
        if drawnIn.x > StripTuning.marksGo {
            // out of the notch at rest: it grows in once the column is out
            m.waitsForColumn = true
        } else if m.gap == nil {
            grow(m)
        }
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
        arrive(m)
    }

    /// Just arrived: its ring flashes Swells times, 450ms apart.
    func arrive(_ m: StripMark) {
        m.arrived = t
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

    /// Sessions leaving: each mark fades and shrinks where it is, and the rest close up; Grows, the strip shrinks with
    /// them, with nothing left into the notch at rest.
    func leave(_ gone: Set<String>) {
        for tab in tabs {
            if case let .session(id) = tab.key, gone.contains(id) {
                drawBack(tab)
            }
        }
        for m in marks where !m.removing {
            if let id = m.session?.id, gone.contains(id) {
                m.removing = true
                to(&m.op, 0, 200)
                springTo(&m.sc, 0.6, .slide)
            }
        }
        display.removeAll(where: gone.contains)
        needsSlot.subtract(gone)
        relayout()
    }
}
