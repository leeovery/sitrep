import CoreGraphics
import Foundation

// What the pointer does on the strip: a mark it rests on pours its tab out, and a click jumps.

extension Strip {
    /// Once a frame: what is under the pointer, and what the tab does about it.
    func updateHover() {
        let live = liveTab()
        let onStrip = sp.map(inStrip) ?? false
        let onTab = sp.map { p in live.map { $0.phase == .open && inTab(p, $0) } ?? false } ?? false
        let isOver = onStrip || onTab
        if isOver != over {
            over = isOver
            if isOver {
                cancel(.settle)
            } else if pendingSort {
                settleLater()
            }
        }
        guard jumping == nil else {
            return
        }

        var hot = onStrip ? sp.flatMap { keyAt($0.y) } : onTab ? live?.key : nil
        if freeze, isOver, let live, live.phase == .open {
            // it keeps with its mark while the marks slide
            hot = live.key
        }
        if disarmed != nil, hot != disarmed {
            disarmed = nil
        }
        guard let hot else {
            return leave(live)
        }

        cancel(.grace)
        self.hot = hot
        guard disarmed != hot else {
            return
        }

        guard let live else {
            let tab = makeTab(hot)
            // reduced motion: no reach toward the pointer
            if !reducesMotion {
                springTo(&tab.w, settings.reach, .reach)
            }
            return startDwell(tab)
        }

        if live.phase == .reach, live.key != hot {
            live.key = hot
            springTo(&live.y, tabTargetY(hot, StripTuning.mark), .glide)
            startDwell(live)
        } else if live.phase == .open, live.key != hot {
            glide(live, to: hot)
        }
    }

    /// Nothing under the pointer: the dwell is off, a reach draws back at once, and an open tab after the grace.
    private func leave(_ live: StripTab?) {
        cancel(.dwell)
        if live?.phase == .reach {
            drawBack(live)
        } else if live?.phase == .open, !timers.has(.grace) {
            startGrace()
        }
        hot = nil
    }

    func inStrip(_ p: Vec) -> Bool {
        p.x <= StripTuning.width + 0.5 && p.y >= stage.menu && p.y <= stage.height
    }

    func inTab(_ p: Vec, _ tab: StripTab) -> Bool {
        guard let g = tab.g, g.w > 1 else {
            return false
        }

        let x = p.x - StripTuning.width
        return x >= -1 && x <= g.w + 2 && p.y >= g.yt - 2 && p.y <= g.yb + 2
    }

    /// A click on the strip or an open tab, in stage coordinates: on a tab or its mark, it jumps, whether or not the
    /// tab is out yet; on an away mark, nothing (its tab says why); on the count, its tab opens at once, and a row on
    /// its tab jumps.
    public func click(at point: CGPoint) {
        if let live = liveTab(), live.phase == .open, let shown = lastTabs.first(where: { $0.id == live.id }),
           shown.contains(point)
        {
            if case let .session(id) = live.key {
                jump(live, id, row: false)
            } else if let id = shown.row(at: point) {
                jump(live, id, row: true)
            }
            return
        }
        guard jumping == nil, inStrip(Vec(point.x, point.y)), let key = keyAt(point.y) else {
            return
        }
        guard case let .session(id) = key else {
            return openCount()
        }
        guard session(id)?.jumps == true else {
            return
        }

        if let live = liveTab(), live.phase == .open, live.key == key {
            jump(live, id, row: false)
        } else {
            jumpMark(key)
        }
    }

    /// A click on the count: its tab, at once, and no jump.
    private func openCount() {
        disarmed = nil
        let live = liveTab()
        if let live, live.phase == .open {
            if live.key != .more {
                glide(live, to: .more)
            }
            return
        }
        if let live, live.key == .more {
            return pour(live)
        }

        drawBack(live)
        pour(makeTab(.more))
    }

    /// A click on an open tab, or one of the count's rows: it presses in and spins for 450ms, then draws back. An
    /// away session's takes no click: no window holds it.
    func jump(_ tab: StripTab, _ id: String, row: Bool) {
        guard jumping == nil, tab.phase == .open, session(id)?.jumps == true else {
            return
        }

        jumping = .tab(tab, id)
        cancel(.grace, .dwell)
        if row {
            tab.current?.pressedRow = id
        } else {
            tab.current?.pressed = true
        }
        springTo(&tab.press, row ? 0 : 4, .press)
        later(.jumpGo, StripTuning.jumpSpin) { strip in
            strip.jumping = nil
            strip.disarmed = tab.key
            strip.drawBack(tab)
        }
    }

    /// A click on a mark whose tab isn't out, inside the dwell too: the reach draws back at once, the ring presses in
    /// and its own arc spins for the 450ms, then the jump.
    func jumpMark(_ key: MarkKey) {
        guard jumping == nil, let m = mark(key) else {
            return
        }

        tabs.forEach { drawBack($0) }
        cancel(.dwell, .grace)
        jumping = .mark(key)
        springTo(&m.sc, StripTuning.markPress, .press)
        later(.jumpGo, StripTuning.jumpSpin) { strip in
            strip.jumping = nil
            strip.disarmed = key
            strip.springTo(&m.sc, 1, .press)
        }
    }
}
