import CoreGraphics
import Foundation

// What the pointer does on the strip: a mark it rests on pours its tab out, a click jumps, and at Grows a press moved
// along the edge drags the strip.

extension Strip {
    /// Once a frame: what is under the pointer, and what the tab does about it. A drag carries the strip and nothing
    /// else, and crossing to the other edge it takes no pointer.
    func updateHover() {
        guard !dragging, !crossing else {
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
        sw.x > 1 && inRect(p, column)
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
    /// tab jumps, but for an away one's. Crossing to the other edge, it takes none. The session it jumps to, if it does.
    @discardableResult
    public func click(at point: CGPoint) -> Session? {
        guard !crossing else {
            return nil
        }

        if let (live, shown) = openTab(at: point) {
            if case let .session(id) = live.key {
                return jump(live, id, row: false)
            }
            return shown.row(at: point).flatMap { jump(live, $0, row: true) }
        }
        guard jumping == nil, inStrip(Vec(point.x, point.y)), let key = keyAt(point.y) else {
            return nil
        }
        guard case let .session(id) = key else {
            openCount(key)
            return nil
        }
        guard let session = session(id), session.jumps else {
            return nil
        }

        if let live = liveTab(), live.phase == .open, live.key == key {
            return jump(live, id, row: false)
        }
        return jumpMark(key) ? session : nil
    }

    /// The jump answered: a click's spin ends now, rather than at its 450ms.
    public func jumpAnswered() {
        if timers.has(.jumpGo) {
            cancel(.jumpGo)
            endJump()
        }
    }

    /// A press, in stage coordinates: on the strip, which moved may become a drag; on an open tab, which only clicks.
    public func press(at point: CGPoint) {
        guard jumping == nil, !crossing else {
            return
        }

        if inStrip(Vec(point.x, point.y)) {
            press = NotchDrag(at: point, home: layout.top + layout.length / 2)
        } else {
            pressesTab = openTab(at: point) != nil
        }
    }

    /// The press let go: the end of a drag, the pointer not opening the mark it is left on until it leaves it, and past
    /// the screen's middle the strip crossing to the other edge (`cross`); or else a click, unless it `clicks` not, as
    /// while a jump runs. A press refused, or given up, lets go on nothing.
    @discardableResult
    public func release(at point: CGPoint, clicks: Bool = true) -> StripRelease {
        let onTab = pressesTab

        pressesTab = false
        guard let held = press else {
            return onTab ? clicked(at: point, clicks) : .nothing
        }

        press = nil
        guard held.isCarrying else {
            return clicked(at: point, clicks)
        }

        dragging = false
        disarmed = inStrip(Vec(point.x, point.y)) ? keyAt(point.y) : nil
        relayout()
        if held.isAcross {
            cross()
        }
        return .dropped(along: length == .grows ? centre / stage.height : nil, across: held.isAcross)
    }

    private func clicked(at point: CGPoint, _ clicks: Bool) -> StripRelease {
        clicks ? click(at: point).map(StripRelease.jump) ?? .nothing : .nothing
    }

    /// The open tab under a point, and its words as last drawn.
    private func openTab(at point: CGPoint) -> (StripTab, StripFrame.Tab)? {
        guard let live = liveTab(), live.phase == .open, let shown = lastTabs.first(where: { $0.id == live.id }),
              shown.contains(point)
        else {
            return nil
        }

        return (live, shown)
    }

    /// A press moved into a drag, which carries the strip till it lets go.
    public var isDragging: Bool { dragging }

    /// While a drag carries the strip, whether the pointer is past the screen's middle, where letting go takes the
    /// strip to the other edge.
    public var isAcross: Bool { dragging && press?.isAcross == true }

    /// A press moved more than 4 is a drag: any tab draws back, and at Grows the strip's centre follows the pointer
    /// along the edge, the marks and the ends at once. At Full it runs the screen's height, and goes nowhere along it.
    func drag(to p: Vec) {
        guard var held = press else {
            return
        }

        if held.move(to: CGPoint(x: p.x, y: p.y), width: stage.width) {
            dragging = true
            tabs.forEach { drawBack($0) }
            cancel(.dwell, .grace)
            hot = nil
        }
        press = held
        guard held.isCarrying else {
            return
        }

        if length == .grows {
            centre = clampCentre(held.notchY)
        }
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

    /// A click on an open tab, or one of a count's rows: it presses in and spins until the jump answers, 450ms at
    /// most, then draws back. An away session's takes no click: no window holds it. The session it jumps to, if it
    /// does.
    func jump(_ tab: StripTab, _ id: String, row: Bool) -> Session? {
        guard jumping == nil, tab.phase == .open, let session = session(id), session.jumps else {
            return nil
        }

        jumping = .tab(tab, id)
        cancel(.grace, .dwell)
        if row {
            tab.current?.pressedRow = id
        } else {
            tab.current?.pressed = true
        }
        springTo(&tab.press, row ? 0 : 4, .press)
        later(.jumpGo, StripTuning.jumpSpin) { $0.endJump() }
        return session
    }

    /// A click on a mark whose tab isn't out, inside the dwell too: the reach draws back at once, the ring presses in
    /// and its own arc spins until the jump answers, 450ms at most. Whether it took the click.
    func jumpMark(_ key: MarkKey) -> Bool {
        guard jumping == nil, let m = mark(key) else {
            return false
        }

        tabs.forEach { drawBack($0) }
        cancel(.dwell, .grace)
        jumping = .mark(key)
        springTo(&m.sc, StripTuning.markPress, .press)
        later(.jumpGo, StripTuning.jumpSpin) { $0.endJump() }
        return true
    }

    /// The spin over: a tab draws back, a ring springs back out, and neither opens again under the pointer until it
    /// leaves.
    private func endJump() {
        switch jumping {
        case let .tab(tab, _):
            jumping = nil
            disarmed = tab.key
            drawBack(tab)
        case let .mark(key):
            jumping = nil
            disarmed = key
            if let m = mark(key) {
                springTo(&m.sc, 1, .press)
            }
        case nil:
            break
        }
    }
}

/// What a press on the strip came to as it let go.
public enum StripRelease: Equatable {
    case nothing
    /// A click that jumps to this session.
    case jump(Session)
    /// A drag let the strip go: how far down the screen its centre was left, 0 to 1, where it went along the edge (at
    /// Grows); and whether it was let go past the screen's middle, for the other edge.
    case dropped(along: Double?, across: Bool)
}
