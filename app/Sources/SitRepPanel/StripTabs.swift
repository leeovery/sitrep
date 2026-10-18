import CoreGraphics
import Foundation

/// A tab: a mark's panel row poured out of the strip, or the count's rows. Its depth out of the strip, its body's
/// height and its centre along the strip are springs, as are a click pressing it in and, under reduced motion, its
/// fade.
final class StripTab {
    enum Phase {
        /// The edge bowing toward the pointer during the dwell; ...
        case reach
        /// ... poured out; ...
        case open
        /// ... drawing back into the strip.
        case closing
    }

    let id: Int
    var key: MarkKey
    var phase = Phase.reach
    var w = Spring(0)
    var h = Spring(StripTuning.mark)
    var y: Spring
    var press = Spring(0)
    var alpha = Spring(1)
    /// Its words: the newest last, those going still fading out.
    var words: [StripWords] = []
    /// Its shape as last drawn, which the pointer is hit-tested against.
    var g: TabGeometry?
    var outline: CGPath?
    var closeT0 = 0.0

    init(id: Int, key: MarkKey, y: Double) {
        self.id = id
        self.key = key
        self.y = Spring(y)
    }

    func step(_ dt: Double) {
        w.step(dt)
        h.step(dt)
        y.step(dt)
        press.step(dt)
        alpha.step(dt)
    }

    /// The words that are staying.
    var current: StripWords? { words.last { !$0.out } }
}

/// A tab's words, coming in or going out: a session's row, or the count's rows.
final class StripWords {
    let id: Int
    let key: MarkKey
    let content: StripFrame.Words.Content
    /// Their width, as wide as the row needs from 240 to 360, and height.
    let W, Hb: Double
    var inT0: Double, inDur = 0.0, inDelay = 0.0
    /// The way the pointer went: they come in, or go out, moving that way.
    var dir = 0.0
    var out = false, outT0 = 0.0, outDur = StripTuning.outFade
    /// Pouring: they come in with the depth.
    var pour = false
    /// A click pressing the row in, its age turning into a spinner; or one of the count's rows, by its session.
    var pressed = false
    var pressedRow: String?

    init(id: Int, key: MarkKey, content: StripFrame.Words.Content, W: Double, Hb: Double, at t: Double) {
        self.id = id
        self.key = key
        self.content = content
        self.W = W
        self.Hb = Hb
        inT0 = t
    }

    func goOut(at t: Double, in dur: Double, dir: Double) {
        out = true
        outT0 = t
        outDur = dur
        self.dir = dir
    }
}

extension Strip {
    func liveTab() -> StripTab? {
        tabs.first { $0.phase == .reach || $0.phase == .open }
    }

    func makeTab(_ key: MarkKey) -> StripTab {
        let tab = StripTab(id: nextSerial(), key: key, y: mark(key)?.y.x ?? yOf(key))
        tabs.append(tab)
        return tab
    }

    func removeTab(_ tab: StripTab) {
        tabs.removeAll { $0 === tab }
        cancel(.draw(tab.id))
    }

    var tabMax: Double { max(StripTuning.tabMin, min(StripTuning.tabMax, stage.width - StripTuning.width - 48)) }

    /// The tallest a tab's body may be: the count's, at its tallest, scrolls.
    var maxBody: Double { botClear - minCy(0, topClear) }

    /// A tab's words: its panel row, or for the count, the rest as rows.
    func buildWords(_ key: MarkKey) -> StripWords {
        let content: StripFrame.Words.Content, natural: Double, Hb: Double
        switch key {
        case .more:
            let rows = layout.rest.compactMap(session)
            let n = Double(rows.count)
            content = .rows(rows)
            natural = measure.rows(rows)
            Hb = min(maxBody, StripTuning.rowsPad * 2 + n * StripTuning.rowHeight + max(0, n - 1) * StripTuning.rowGap)
        case let .session(id):
            let s = session(id)!
            content = .row(s)
            natural = measure.row(s)
            Hb = StripTuning.tabHeight
        }
        let W = clamp(natural.rounded(.up) + StripTuning.tabSlack, StripTuning.tabMin, tabMax)
        return StripWords(id: nextSerial(), key: key, content: content, W: W, Hb: Hb, at: t)
    }

    /// The words change: the old ones fade out, moving away, as the new come in.
    @discardableResult
    func relayer(_ tab: StripTab, _ key: MarkKey, _ dir: Double) -> StripWords {
        for words in tab.words where !words.out {
            words.goOut(at: t, in: max(1, settings.fade * StripTuning.outShare), dir: dir)
        }
        let words = buildWords(key)
        words.inDelay = settings.fade * StripTuning.inFrom
        words.inDur = settings.fade * (1 - StripTuning.inFrom)
        words.dir = dir
        tab.words.append(words)
        return words
    }

    /// The dwell: the pointer rests on a mark before the first tab pours out; meanwhile the edge reaches toward it.
    func startDwell(_ tab: StripTab) {
        cancel(.dwell)
        guard settings.dwell > 0 else {
            return pour(tab)
        }

        later(.dwell, settings.dwell) { strip in
            if tab.phase == .reach {
                strip.pour(tab)
            }
        }
    }

    /// The row pours out of the strip: the depth out to the row's width, the body from the mark's 24 to the row's 52.
    func pour(_ tab: StripTab) {
        cancel(.dwell)
        tab.phase = .open
        let words = buildWords(tab.key)
        words.pour = true
        if reducesMotion {
            words.inDur = 140
            tab.alpha.x = 0
            to(&tab.alpha, 1, 140)
        }
        tab.words.append(words)
        springTo(&tab.w, words.W, .pour)
        springTo(&tab.h, words.Hb, .grow)
        let ty = tabTargetY(tab.key, words.Hb)
        if abs(ty - tab.y.target) > 0.01 {
            springTo(&tab.y, ty, .glide)
        }
    }

    /// Along the strip to the next mark: its place and width spring there, the words crossing the way the pointer
    /// went.
    func glide(_ tab: StripTab, to key: MarkKey) {
        let delta = yOf(key) - yOf(tab.key)
        tab.key = key
        if reducesMotion {
            crossfade(tab)
        }
        let words = relayer(tab, key, delta < 0 ? -1 : 1)
        springTo(&tab.y, tabTargetY(key, words.Hb), .glide)
        springTo(&tab.w, words.W, .width)
        springTo(&tab.h, words.Hb, .width)
    }

    /// Back into the strip: the words go first, then the black, on the draw spring, a little past into a dent.
    func drawBack(_ tab: StripTab?) {
        guard let tab, tab.phase != .closing else {
            return
        }

        let wasReach = tab.phase == .reach
        tab.phase = .closing
        tab.closeT0 = t
        cancel(.grace)
        for words in tab.words where !words.out {
            words.goOut(at: t, in: StripTuning.outFade, dir: 0)
        }
        guard !reducesMotion else {
            to(&tab.alpha, 0, 140)
            return later(.draw(tab.id), 170) { $0.removeTab(tab) }
        }

        if wasReach {
            back(tab)
        } else {
            later(.draw(tab.id), StripTuning.closeAt / settings.close) { $0.back(tab) }
        }
    }

    private func back(_ tab: StripTab) {
        springTo(&tab.w, 0, .draw)
        springTo(&tab.h, StripTuning.mark, .draw)
        springTo(&tab.press, 0, .press)
    }

    /// The pointer off the strip and the tab: the grace, shorter the faster it went.
    func startGrace() {
        let fast = smooth(clamp(pointerSpeed() / StripTuning.fastLeave, 0, 1))
        later(.grace, lerp(settings.grace, settings.grace * StripTuning.graceFast, fast)) { $0.drawBack($0.liveTab()) }
    }

    /// Under reduced motion, a tab's black cross-fades from where it was to where it is.
    func crossfade(_ tab: StripTab) {
        fade = (tab.outline ?? CGMutablePath(), t)
        tab.alpha.x = 0
        to(&tab.alpha, 1, 140)
    }

    /// The tabs that have drawn all the way back go; one that keeps with its mark follows it while the marks slide.
    func stepTabs() {
        for tab in tabs where tab.phase == .closing && !reducesMotion && t - tab.closeT0 > 60 && tab.w.target == 0
            && abs(tab.w.x) < 0.2 && abs(tab.w.v) < 0.004
        {
            removeTab(tab)
        }
        guard freeze else {
            return
        }

        let live = liveTab()
        let sliding = marks.contains { !$0.removing && !still($0.y) }
        if let live, live.phase == .open, let src = mark(live.key)?.y {
            live.y = src
        }
        if !sliding || live == nil {
            freeze = false
        }
    }

    func still(_ s: Spring) -> Bool {
        abs(s.x - s.target) < StripTuning.settled && abs(s.v) < 0.01
    }
}
