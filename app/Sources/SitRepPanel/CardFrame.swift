import CoreGraphics
import Foundation

extension Card {
    func render(_ g: CardGeometry) -> Frame {
        let outline = shapePath(g)
        let hit = hitRect(g)
        let panel = renderPanel(g)
        lastHit = hit
        if let panel {
            lastPanel = panel
        }
        lastOutline = outline
        let (alpha, fading) = fadeOutlines()
        return Frame(
            time: t, phase: phase, outline: outline, outlineAlpha: alpha, fading: fading, panel: panel,
            light: Frame.Light(
                centre: CGPoint(x: g.w / 2, y: g.cy),
                level: clamp(S.light.x, 0, 1) * clamp(S.vis.x, 0, 1),
                lastAsk: flash
            ),
            hitRect: hit, isMoving: isMoving
        )
    }

    /// The content, centred on the card and clipped to it, its outer corners rounding with the card's; nil while
    /// closed.
    func renderPanel(_ g: CardGeometry) -> Frame.Panel? {
        guard phase != .closed else {
            return nil
        }

        let W = Tuning.panelDepth, H = panelLength, top = g.cy - H / 2
        let it = max(0, g.top - top), ib = max(0, top + H - g.bottom), front = max(0, W - g.w)
        let (head, items) = renderRows()
        return Frame.Panel(
            frame: CGRect(x: 0, y: top, width: W, height: H),
            clip: CGRect(x: 0, y: top + it, width: W - front, height: max(0, H - it - ib)),
            topRadius: g.r, bottomRadius: g.r,
            head: head, items: items
        )
    }

    /// Anything still moving: a spring not at rest, a timer pending, rows landing or fading, or a cross-fade. A
    /// pointer held still moves nothing: the nudge goes only by where it is.
    var isMoving: Bool {
        CardSprings.all.contains { !S[keyPath: $0].isAtRest } || !timers.isEmpty || isRevealing || fade != nil
    }
}
