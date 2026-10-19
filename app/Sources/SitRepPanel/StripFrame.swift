import CoreGraphics
import Foundation

/// What the view draws of the strip for one frame, in the edge's stage coordinates: x into the screen from its edge,
/// y down from its top.
public struct StripFrame {
    /// The sim clock, ms.
    public let time: Double
    /// The strip's black: one closed path, from its top end to its bottom end, starting a little past the screen's
    /// edge.
    public let strip: CGPath
    public let tabs: [Tab]
    /// Under reduced motion, a black it cross-fades from.
    public let fading: Frame.Fading?
    /// Every mark, the counts last.
    public let marks: [Mark]
    public let hairline: Hairline
    /// Whether anything can still change with the pointer held still.
    public let isMoving: Bool
    /// Whether the strip took the pointer as on it or its open tab, last frame: a frame off them tells it it left.
    public let isOver: Bool
    /// A press on the strip is held, which may yet drag it: the pointer is the strip's till it lets go.
    public let isHeld: Bool
    /// The strip's whole column, which takes the pointer and clicks.
    public let column: CGRect

    /// Whether a click here lands on the strip, a mark or an open tab, rather than passing through to what is beneath.
    public func hits(_ point: CGPoint) -> Bool {
        isHeld || inRect(Vec(point.x, point.y), column) || tabs.contains { $0.isLive && $0.contains(point) }
    }

    /// Whether the view should keep frames coming: while anything moves, while a press is held, while the pointer is
    /// on the strip or a tab, and for a frame after it leaves them. Otherwise frames can stop until the pointer comes
    /// back or Lee acts.
    public func wantsFrames(pointer: CGPoint?) -> Bool {
        isMoving || isOver || isHeld || pointer.map { p in
            inRect(Vec(p.x, p.y), column)
                || tabs.contains { $0.outline.boundingBoxOfPath.insetBy(dx: -2, dy: -2).contains(p) }
        } ?? false
    }

    /// A tab: its black, and its words clipped to its body as the black pours out, the front corners rounding with it.
    public struct Tab {
        public let id: Int
        public let key: MarkKey
        public let outline: CGPath
        public let alpha: Double
        /// Poured out: it takes the pointer, and a click.
        public let isLive: Bool
        /// The words' box: as wide as the widest of them and as tall as the tallest, centred on the tab's body,
        /// against the strip.
        public let box: CGRect
        /// The part of it shown: the body, short of the front, its two front corners rounded this much.
        public let clip: CGRect
        public let radius: Double
        public let words: [Words]

        /// Whether a point is on the words as shown: inside the clip, and inside the rounding of its front corners.
        public func contains(_ point: CGPoint) -> Bool {
            frontRounded(clip, top: radius, bottom: radius, contains: point)
        }

        /// A count's tab: the session whose row is under a point, as its rows lie scrolled, the newest words' first.
        public func row(at point: CGPoint) -> String? {
            guard let words = words.last, case let .rows(rows) = words.content else {
                return nil
            }

            let pitch = StripTuning.rowHeight + StripTuning.rowGap
            let y = point.y - box.minY - words.frame.minY - StripTuning.rowsPad + words.scroll
            let i = Int((y / pitch).rounded(.down))
            let onRow = y >= 0 && rows.indices.contains(i) && y - Double(i) * pitch <= StripTuning.rowHeight
            return onRow ? rows[i].id : nil
        }
    }

    /// A tab's words, in its box, coming in or going out.
    public struct Words {
        public enum Content: Equatable, Sendable {
            /// A session's row: its title, its project and work (or why an away ask's takes no click), its age.
            case row(StripSession)
            /// A count's: a row for each it holds.
            case rows([StripSession])
            /// The notch at rest's: nothing is running.
            case idle

            /// The notch at rest's two lines.
            public static let idleTitle = "Nothing running", idleLine2 = "SitRep · sessions show here as they start"
        }

        /// A count's rows as its tab lays them: this far in from its top, each this tall, this far apart.
        public static let rowsPad = StripTuning.rowsPad, rowHeight = StripTuning.rowHeight, rowGap = StripTuning.rowGap

        /// The same words keep their id from frame to frame.
        public let id: Int
        /// Whose they are.
        public let key: MarkKey
        public let content: Content
        /// Their own box in the tab's: against the strip, centred down it.
        public let frame: CGRect
        /// A count's rows, scrolled this far through them.
        public let scroll: Double
        public let alpha: Double
        /// How far along the strip they still are from their place, coming in or going out the way the pointer went.
        public let dy: Double
        /// A click pressing them in, the age a spinner; or one of a count's rows pressing in.
        public let isPressed: Bool
        public let pressedRow: String?
    }

    /// A mark: two letters, or a count, in a 24pt ring whose colour carries the state.
    public struct Mark {
        public enum Look: Sendable {
            /// Orange, with the panel dot's glow, the letters white; away, the letters dim; your turn, white; working,
            /// a grey track with a pale arc turning; the grey count, a grey ring; needs you's count, orange with its
            /// glow, the letters white.
            case needs, away, turn, working, count, needsCount
        }

        public let key: MarkKey
        public let text: String
        public let look: Look
        public let centre: CGPoint
        public let scale: Double
        /// Its own fade, and as the strip's end sweeps over it or the column narrows into the notch at rest.
        public let alpha: Double
        /// Under the pointer, or its tab out: the ring lifts, ...
        public let isLifted: Bool
        /// ... this far, 0 to 1, easing in over 110ms and back out as it is left: the views draw it as it is.
        public let lift: Double
        /// A click on it jumping: the ring presses in and its own arc turns.
        public let isJumping: Bool
        /// Just arrived, or an ask just landed in it: how washed orange inside the ring, and how bright the ring
        /// flashes, 0 to 1.
        public let wash: Double
        public let flash: Double

        /// The ring is 24 across.
        public static let size = StripTuning.mark
    }

    /// The hairline under needs you: 16 long, centred across the strip.
    public struct Hairline {
        public let x: Double
        public let y: Double
        public let alpha: Double
    }
}

extension Strip {
    func render() -> StripFrame {
        let geometries = tabs.map { tab in
            let g = tabGeometry(tab)
            tab.g = g
            return g
        }
        let shown = zip(tabs, geometries).map(renderTab)
        lastTabs = shown
        let strip = stripPath(geometries)
        lastStrip = strip
        let fading = renderFade()
        return StripFrame(
            time: t, strip: strip, tabs: shown, fading: fading, marks: renderMarks(),
            hairline: StripFrame.Hairline(
                x: front / 2, y: hair.x, alpha: clamp(hairOp.x, 0, 1) * marksShown * covered(hair.x, 0.5)
            ),
            isMoving: isMoving, isOver: over || hot != nil, isHeld: press != nil, column: column
        )
    }

    /// A tab's words, over its black, clipped to its body as the black pours out; those gone out are dropped.
    func renderTab(_ tab: StripTab, _ g: TabGeometry) -> StripFrame.Tab {
        let outline = tabPath(g)
        tab.outline = outline
        let Wm = tab.words.map(\.W).max().map { max(1, $0) } ?? 1
        let Hm = tab.words.map(\.Hb).max().map { max(1, $0) } ?? 1
        let w = clamp(g.w, 0, Wm)
        let box = CGRect(x: front, y: g.cy - Hm / 2, width: Wm, height: Hm)
        let inset = max(0, (Hm - g.h) / 2)
        let clip = CGRect(x: box.minX, y: box.minY + inset, width: Wm - max(0, Wm - w), height: max(0, Hm - 2 * inset))
        let alpha = clamp(tab.alpha.x, 0, 1)
        return StripFrame.Tab(
            id: tab.id, key: tab.key, outline: outline, alpha: alpha, isLive: tab.phase == .open, box: box, clip: clip,
            radius: min(g.r, w), words: tab.words.compactMap { paint($0, of: tab, Hm: Hm, alpha: alpha) }
        )
    }

    /// One of a tab's words as they show now: pouring, they come in with the depth from 55% of it to 95%; gliding,
    /// the new fade in as the old fade out, each moving the way the pointer went. Nil once gone out, and dropped.
    private func paint(_ words: StripWords, of tab: StripTab, Hm: Double, alpha: Double) -> StripFrame.Words? {
        let from = StripTuning.textFrom, to = StripTuning.textTo
        let reveal = words.pour && tab.phase == .open && !reducesMotion
            ? clamp((max(0, tab.w.x) / max(1, words.W) - from) / (to - from), 0, 1) : 1
        if words.pour, reveal >= 1 {
            words.pour = false
        }
        let inA = words.inDur > 0 ? easeOut(clamp((t - words.inT0 - words.inDelay) / words.inDur, 0, 1)) : 1
        let outA = words.out ? 1 - clamp((t - words.outT0) / words.outDur, 0, 1) : 1
        if words.out, outA <= 0 {
            tab.words.removeAll { $0 === words }
            return nil
        }

        let dy = words.out ? -(1 - outA) * StripTuning.shift * words.dir : (1 - inA) * StripTuning.shift * words.dir
        return StripFrame.Words(
            id: words.id, key: words.key, content: words.content,
            frame: CGRect(x: 0, y: (Hm - words.Hb) / 2, width: words.W, height: words.Hb), scroll: words.scroll,
            alpha: easeOut(reveal) * inA * outA * alpha, dy: dy, isPressed: words.pressed, pressedRow: words.pressedRow
        )
    }

    /// The marks: those gone faded out are dropped; a new one waiting grows once it's clear; one just arrived, and
    /// needs you's count as an ask lands in it, is washed orange inside its ring, its glow brighter, for two seconds,
    /// its ring flashing.
    func renderMarks() -> [StripFrame.Mark] {
        let live = liveTab()
        let lifted = hot ?? (live?.phase == .open ? live?.key : nil)
        marks.removeAll { $0.removing && $0.op.x < 0.01 && $0.op.target == 0 }
        if let more, more.removing, more.op.x < 0.01 {
            self.more = nil
        }
        if let moreNeeds, moreNeeds.removing, moreNeeds.op.x < 0.01 {
            self.moreNeeds = nil
        }

        var shown: [StripFrame.Mark] = []
        for m in marks {
            growIfClear(m)
            guard let s = m.session else {
                continue
            }

            let look: StripFrame.Mark.Look = switch s.kind {
            case .needs: s.away ? .away : .needs
            case .turn: .turn
            case .working: .working
            }
            shown.append(paint(m, s.letters, look, lifted: lifted == m.key && !s.away, washes: s.kind == .needs))
        }
        if let more {
            shown.append(paint(more, "+\(more.count)", .count, lifted: lifted == .more, washes: false))
        }
        if let moreNeeds {
            let lift = lifted == .moreNeeds
            shown.append(paint(moreNeeds, "+\(moreNeeds.count)", .needsCount, lifted: lift, washes: true))
        }
        return shown
    }

    private func paint(
        _ m: StripMark, _ text: String, _ look: StripFrame.Mark.Look, lifted: Bool, washes: Bool
    ) -> StripFrame.Mark {
        let isJumping = if case let .mark(key) = jumping { key == m.key } else { false }
        let lift = lifted ? 1.0 : 0
        if m.lift.target != lift {
            to(&m.lift, lift, StripTuning.liftFade)
        }
        let e = t - m.arrived
        let arriving = washes && e >= 0 && e < StripTuning.washHold + StripTuning.washFade
        let wash = e < StripTuning.washHold ? 1 : 1 - smooth((e - StripTuning.washHold) / StripTuning.washFade)
        // under reduced motion, a leaving ring fades where it was, with the old shape, though the strip has gone
        let shown = m.removing && reducesMotion ? 1 : marksShown * covered(m.y.x, StripTuning.mark / 2)
        return StripFrame.Mark(
            key: m.key, text: text, look: look, centre: CGPoint(x: front / 2, y: m.y.x), scale: m.sc.x,
            alpha: clamp(m.op.x, 0, 1) * shown, isLifted: lifted, lift: clamp(m.lift.x, 0, 1), isJumping: isJumping,
            wash: arriving ? wash : 0, flash: arriving ? flash(m) : 0
        )
    }

    /// The ring's flash: up in 70ms, then dying away over about 150, at each of its flashes.
    func flash(_ m: StripMark) -> Double {
        func at(_ e: Double) -> Double { e < 70 ? e / 70 : exp(-(e - 70) / 150) }
        return m.flashes.map { t - $0 }.filter { $0 >= 0 }.map(at).max() ?? 0
    }

    /// The marks fade as the column narrows into the notch at rest, and come back as it widens out of it.
    var marksShown: Double {
        1 - smooth(clamp((lip.x - StripTuning.marksGo) / (StripTuning.marksGone - StripTuning.marksGo), 0, 1))
    }

    /// How much of a ring this tall the strip's ends leave showing: as an end sweeps over it, growing or shrinking, it
    /// fades across the end's S.
    func covered(_ y: Double, _ r: Double) -> Double {
        let clear = min(y - r - yt.x, yb.x - y - r)
        return clamp((clear - StripTuning.coverFrom) / (StripTuning.coverTo - StripTuning.coverFrom), 0, 1)
    }

    /// Under reduced motion, the cross-fade's old black: fading out over 160ms, gone after 400.
    private func renderFade() -> Frame.Fading? {
        guard let fade, t - fade.t0 <= 400 else {
            fade = nil
            return nil
        }

        return Frame.Fading(outline: fade.outline, alpha: 1 - clamp((t - fade.t0) / 160, 0, 1))
    }

    /// Anything still moving: a spring not at rest, a timer pending, a tab's words coming or going, a mark just
    /// arrived or waiting to grow, a cross-fade, or marks sliding under a tab that keeps with them.
    var isMoving: Bool {
        let all = marks + counts
        let markSprings: [Spring] = all.flatMap { [$0.y, $0.sc, $0.op, $0.lift] }
        let tabSprings: [Spring] = tabs.flatMap { [$0.w, $0.h, $0.y, $0.press, $0.alpha] }
        let springing = ([hair, hairOp, yt, yb, lip] + markSprings + tabSprings).contains { !$0.isAtRest }
        let washing = all.contains { m in
            t - m.arrived < StripTuning.washHold + StripTuning.washFade || m.gap != nil || m.waitLip
        }
        let words = tabs.contains { tab in
            tab.words.contains { $0.out || $0.pour || t - $0.inT0 < $0.inDelay + $0.inDur }
        }
        return springing || !timers.isEmpty || washing || words || fade != nil || freeze
    }
}
