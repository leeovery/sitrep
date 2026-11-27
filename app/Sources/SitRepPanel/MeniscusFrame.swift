import CoreGraphics
import Foundation

extension Meniscus {
    func render(_ g: MeniscusGeometry) -> Frame {
        let moved = g.bump.map { displaced(g, outlineOf(g), $0, ringAt: ringAt) }
        let hit = hitRect(g)
        let panel = renderPanel(g, dentAt: moved?.centre)
        let outline = shapePath(g, moved?.points), shape = moved == nil ? outline : shapePath(g, nil)
        lastHit = hit
        if let panel {
            lastPanel = panel
        }
        lastOutline = outline
        lastShape = shape
        let (alpha, fading) = fadeOutlines()
        let swaps = swapsEdge
        swapsEdge = false
        return Frame(
            time: t, phase: phase, outline: outline, shape: shape, outlineAlpha: alpha, fading: fading, panel: panel,
            light: renderLight(g), hitRect: hit, isMoving: isMoving, lift: clamp(S.lift.x, 0, 1), swapsEdge: swaps
        )
    }

    /// The hit area: the live notch plus a little, reaching past the edge; only a sliver once the panel is out.
    func hitRect(_ g: MeniscusGeometry) -> CGRect {
        let notch = resting, closed = phase == .closed
        return hitArea(w: closed ? g.w : notch.w, h: closed ? g.h : notch.h, cy: closed ? g.cy : S.y.x, live: isLive)
    }

    /// The content, clipped to the black's body; nil while closed.
    func renderPanel(_ g: MeniscusGeometry, dentAt centre: OutlinePoint?) -> Frame.Panel? {
        guard phase != .closed else {
            return nil
        }

        let W = Tuning.panelDepth, H = panelHeight, top = S.ct.x
        let bodyTop = g.top + g.ft, bodyBot = g.top + g.h - g.fb
        // a dent in the edge pulls the content's clip in with it on its side, so no fading row shows past the black
        var dent = 0.0, n0 = Vec(0, 0)
        if let b = g.bump, let centre, b.a < 0 {
            dent = -b.a * centre.taper
            n0 = centre.n
        }
        let it = max(0, bodyTop - top + dent * max(0, -n0.y))
        let ib = max(0, top + H - bodyBot + dent * max(0, n0.y))
        let front = max(0, W - g.w + dent * max(0, n0.x))
        let cap = min(g.w / 2, (bodyBot - bodyTop) / 2)
        let (head, items) = renderRows()
        return Frame.Panel(
            frame: CGRect(x: 0, y: top, width: W, height: H),
            clip: CGRect(x: 0, y: top + it, width: max(0, W - front), height: max(0, H - it - ib)),
            topRadius: max(0, min(g.rt, cap)), bottomRadius: max(0, min(g.rb, cap)),
            head: head, items: items, pressed: jumping
        )
    }

    /// The light: on the notch's centre line, halfway into its depth at the base. Its level is only whether anything
    /// needs Lee, and the dimming while the panel is out.
    func renderLight(_ g: MeniscusGeometry) -> Frame.Light {
        Frame.Light(
            centre: CGPoint(x: max(0, g.w) / 2, y: g.cy),
            level: clamp(S.light.x, 0, 1) * clamp(S.vis.x, 0, 1),
            lastAsk: flash
        )
    }

    /// Anything still moving, or able to move with the pointer held still: a spring not at rest, a timer pending, a
    /// leave still playing out, a tongue hanging at Hold, rows landing or fading, a cross-fade, or the pointer in the
    /// attraction's field with its trail still fresh, where a snap waits on the trail going still. A pointer parked in
    /// the field changes nothing once its trail has gone still.
    var isMoving: Bool {
        MeniscusSprings.all.contains { !S[keyPath: $0].isAtRest }
            || !timers.isEmpty
            || snap != nil || ends != nil || landing != nil || ringing || cling.hang != nil
            || isRevealing || fade != nil
            || attract.dx.isFinite && trailIsFresh
    }
}
