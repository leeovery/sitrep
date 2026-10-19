import Foundation

/// A mark: its place along the strip, its scale and its opacity, each a spring.
final class StripMark {
    let key: MarkKey
    /// Its session as last told; nil for the count, ...
    var session: StripSession?
    /// ... which holds this many.
    var count = 0
    var y = Spring(0)
    var sc = Spring(1)
    var op: Spring
    /// How far its ring has lifted under the pointer, 0 to 1.
    var lift = Spring(0)
    /// Not yet placed: its first place it takes at once.
    var fresh = true
    /// Gone into the count.
    var folded = false
    var removing = false
    /// When it arrived as a new needs you, and when its ring flashes.
    var arrived = -1e9
    var flashes: [Double] = []
    /// A new mark waiting to grow until the mark below has slid out of its way: which, and from where.
    var gap: (below: MarkKey, from: Double)?

    init(_ key: MarkKey, session: StripSession?, opacity: Double) {
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

/// Where everything goes, from the strip's order: each mark's place, the count's and what it holds, and the
/// hairline's.
struct StripLayout {
    var places: [(id: String, y: Double)] = []
    var more: (y: Double, n: Int)?
    var rest: [String] = []
    var hair: Double?

    func y(of id: String) -> Double? {
        places.first { $0.id == id }?.y
    }
}

extension Strip {
    /// A mark every 30pt from under the top end, the hairline under needs you, and past what fits, the count in the
    /// last place. Needs you never folds.
    func computeLayout() -> StripLayout {
        let ids = display
        let y0 = firstY, maxY = lastY
        var ys: [Double] = [], y = y0, hair: Double?
        for (i, id) in ids.enumerated() {
            if i > 0, needsSlot.contains(ids[i - 1]), !needsSlot.contains(id) {
                let line = y + StripTuning.hair
                hair = line
                y = line + StripTuning.hair
            } else if i > 0 {
                y += StripTuning.pitch
            }
            ys.append(y)
        }

        let fit = ys.filter { $0 <= maxY }.count
        let keep = max(fit - 1, ids.filter(needsSlot.contains).count)
        func places(_ n: Int) -> [(id: String, y: Double)] { zip(ids.prefix(n), ys).map { (id: $0, y: $1) } }
        guard fit < ids.count, keep < ids.count else {
            return StripLayout(places: places(ids.count), hair: hair)
        }

        // the count is never needs you, so it sits under the hairline
        return StripLayout(
            places: places(keep), more: (ys[keep], ids.count - keep), rest: Array(ids[keep...]), hair: hair
        )
    }

    /// Room changed: any tab goes, the marks slide to their new places, and the next hover opens under the new shape.
    func relayoutShape() {
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

    /// Lays the marks out again: they slide to their places, and fold into the count or out of it.
    func relayout(snapAll: Bool = false) {
        let prevRest = layout.rest
        layout = computeLayout()
        var moved = false
        func move(_ spring: inout Spring, _ y: Double) -> Bool {
            guard abs(spring.target - y) >= 0.01 || snapAll else {
                return false
            }

            moved = true
            if snapAll || reducesMotion {
                spring.snap(y)
            } else {
                spring.springTo(y, settings.sp(.slide))
            }
            // under reduced motion, a cross-fade: it fades in at its place
            return reducesMotion && !snapAll
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
            } else if let into = layout.more {
                if m.fresh {
                    m.fresh = false
                    m.y.snap(into.y)
                    m.op.x = 0
                    m.folded = true
                    to(&m.op, 0, 1)
                } else if !m.folded {
                    m.folded = true
                    _ = move(&m.y, into.y)
                    to(&m.op, 0, 200)
                }
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

        placeCount(move)

        if moved, let live = liveTab(), live.phase == .open {
            // Lee's choice: while marks slide, an open tab keeps with its mark
            freeze = true
        }
        // the count's tab follows what it holds
        if let live = liveTab(), live.key == .more, live.phase == .open {
            if layout.more == nil {
                drawBack(live)
            } else if layout.rest != prevRest {
                relayer(live, .more, 0)
            }
        }
    }

    /// The count in the last place: it arrives growing, slides, or goes.
    private func placeCount(_ move: (inout Spring, Double) -> Bool) {
        guard let into = layout.more else {
            if let more, !more.removing {
                more.removing = true
                to(&more.op, 0, 200)
            }
            return
        }

        let c = more ?? StripMark(.more, session: nil, opacity: 0)
        more = c
        c.count = into.n
        if c.removing || c.op.target < 0.5 {
            c.removing = false
            c.y.snap(into.y)
            c.sc.x = 0.6
            springTo(&c.sc, 1, .arrive)
            to(&c.op, 1, 180)
        } else if move(&c.y, into.y) {
            c.op.x = 0
        }
    }

    func markOf(_ s: StripSession) -> StripMark {
        if let m = mark(.session(s.id)) {
            return m
        }

        let m = StripMark(.session(s.id), session: s, opacity: 1)
        marks.append(m)
        return m
    }

    func mark(_ key: MarkKey) -> StripMark? {
        key == .more ? more : marks.first { $0.key == key }
    }

    /// The y a key's mark sits at, by the layout (where marks are going).
    func yOf(_ key: MarkKey) -> Double {
        let count = layout.more?.y ?? 0
        guard case let .session(id) = key else {
            return count
        }

        return layout.y(of: id) ?? count
    }

    /// The mark under the pointer's height: the nearest centre, within `near`.
    func keyAt(_ y: Double) -> MarkKey? {
        var best: MarkKey?, bd = Double.infinity
        let count = layout.more.map { [(MarkKey.more, $0.y)] } ?? []
        for (key, py) in layout.places.map({ (MarkKey.session($0.id), $0.y) }) + count where abs(py - y) < bd {
            bd = abs(py - y)
            best = key
        }
        return bd <= StripTuning.near ? best : nil
    }

    /// The strip's order: a full sort, the marks sliding to their places.
    func resort() {
        cancel(.settle)
        display = StripSession.sorted(sessions).map(\.id)
        needsSlot = Set(sessions.filter { $0.kind == .needs }.map(\.id))
        pendingSort = false
        relayout()
    }

    func settleLater() {
        if !timers.has(.settle) {
            later(.settle, settings.settle) { $0.resort() }
        }
    }

    /// A change shown in place: an open tab of it, or the count's holding it, takes its new words.
    func changed(_ s: StripSession) {
        mark(.session(s.id))?.session = s
        for tab in tabs where tab.phase == .open && tab.key == .session(s.id) {
            relayer(tab, tab.key, 0)
        }
        if let live = liveTab(), live.phase == .open, live.key == .more, layout.rest.contains(s.id) {
            relayer(live, .more, 0)
        }
        pendingSort = true
        if !over {
            settleLater()
        }
    }

    /// A new needs you moves in at once: after the needs you that aren't away (it is the newest of them), or for an
    /// away one, after the away ones too. The marks below slide down a step, and it grows into its place as the mark
    /// below gets out of the way, washed, its ring flashing.
    func insertNeeds(_ s: StripSession) {
        let end = display.prefix { needsSlot.contains($0) }.count
        let i = s.away ? end : display.prefix(end).firstIndex { session($0)?.away == true } ?? end
        display.insert(s.id, at: i)
        needsSlot.insert(s.id)
        let m = markOf(s)
        relayout()
        m.op.snap(0)
        guard !reducesMotion else {
            to(&m.op, 1, 160)
            return arrive(m)
        }

        m.sc.snap(0.3)
        let next = display[(i + 1)...].first { layout.y(of: $0) != nil }.map(MarkKey.session)
        let below = next ?? (layout.more != nil && more != nil ? .more : nil)
        let spring = below.flatMap(mark)?.y
        m.gap = spring.flatMap { abs($0.target - $0.x) > 1 ? (below!, $0.x) : nil }
        if m.gap == nil {
            grow(m)
        }
    }

    func grow(_ m: StripMark) {
        m.gap = nil
        springTo(&m.sc, 1, .arrive)
        to(&m.op, 1, 100)
        arrive(m)
    }

    /// Just arrived: its ring flashes Swells times, 450ms apart.
    func arrive(_ m: StripMark) {
        m.arrived = t
        m.flashes = (0 ..< Int(settings.swells)).map { t + Double($0) * StripTuning.flashGap }
    }

    /// A new mark waiting on the mark below grows once that has slid `growAt` of its step.
    func growIfClear(_ m: StripMark) {
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
}
