import CoreGraphics
import Foundation

// What the pointer does on the strip: a mark it rests on pours its tab out, a click jumps, and at Grows a press moved
// along the edge drags the strip.

extension Strip {
    /// Once a frame: what is under the pointer, and what the tab does about it. A drag carries the strip and nothing
    /// else.
    func updateHover() {
        guard !dragging else {
            return
        }

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

        var hot = onStrip ? onStripKey() : onTab ? live?.key : nil
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
                springTo(&tab.w, feel.reach, .reach)
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

    /// The mark under the pointer on the strip; on the notch at rest, its own tab once the column has drawn all the way
    /// back into it; nothing while the column is on its way in or out.
    private func onStripKey() -> MarkKey? {
        if layout.isEmpty, length == .grows {
            return drawnIn.x > 0.98 ? .empty : nil
        }
        return drawnIn.x > StripTuning.marksGo ? nil : sp.flatMap { keyAt($0.y) }
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

    /// The column, between its ends; the notch at rest is 7 deep, and as meniscus.html's, answers the pointer a little
    /// further out, and past its ends.
    var column: CGRect {
        let k = inNotch, out = StripTuning.notchHitY * k
        return CGRect(
            x: 0, y: yt.x - out, width: Swift.max(front + 0.5, StripTuning.notchHit * k), height: yb.x - yt.x + 2 * out
        )
    }

    func inStrip(_ p: Vec) -> Bool {
        inRect(p, column)
    }

    func inTab(_ p: Vec, _ tab: StripTab) -> Bool {
        guard let g = tab.g, g.w > 1 else {
            return false
        }

        let x = p.x - front
        return x >= -1 && x <= g.w + 2 && p.y >= g.yt - 2 && p.y <= g.yb + 2
    }

    /// A click on the strip or an open tab, in stage coordinates: on a tab or its mark, it jumps, whether or not the
    /// tab is out yet; on an away mark, nothing (its tab says why); on a count, its tab opens at once, and a row on its
    /// tab jumps, but for an away one's.
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
            return openCount(key)
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

    /// A press on the strip, in stage coordinates: at Grows, moved along the edge it drags the strip there.
    public func press(at point: CGPoint) {
        guard length == .grows, jumping == nil, inStrip(Vec(point.x, point.y)) else {
            return
        }

        press = (point.y, layout.top + layout.length / 2, false)
    }

    /// The press let go: the end of a drag, the pointer not opening the mark it is left on until it leaves it; or else
    /// a click.
    public func release(at point: CGPoint) {
        let held = press
        press = nil
        guard held?.moved == true else {
            return click(at: point)
        }

        dragging = false
        disarmed = inStrip(Vec(point.x, point.y)) ? keyAt(point.y) : nil
        relayout()
    }

    /// A press moved more than 4 along the edge is a drag: any tab draws back, and the strip's centre follows the
    /// pointer, the marks and the ends at once.
    func drag(to y: Double) {
        guard var held = press else {
            return
        }

        let dy = y - held.y0
        if !held.moved {
            guard abs(dy) > StripTuning.dragFrom else {
                return
            }

            held.moved = true
            press = held
            dragging = true
            tabs.forEach { drawBack($0) }
            cancel(.dwell, .grace)
            hot = nil
        }
        centre = clampCentre(held.centre + dy)
        relayout()
    }

    /// A count's tab, at once, and no jump.
    private func openCount(_ key: MarkKey) {
        disarmed = nil
        let live = liveTab()
        if let live, live.phase == .open {
            if live.key != key {
                glide(live, to: key)
            }
            return
        }
        if let live, live.key == key {
            return pour(live)
        }

        drawBack(live)
        pour(makeTab(key))
    }

    /// A click on an open tab, or one of a count's rows: it presses in and spins for 450ms, then draws back. An away
    /// session's takes no click: no window holds it.
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
