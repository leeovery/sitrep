/// The strip's own constants (`prototypes/strip/strip.html`'s, from `STRIP` to `COVER_TO`), each with its value
/// unchanged and a name close to its own.
enum StripTuning {
    /// The strip: the bezel grown, 36 of the same black, ...
    static let width = 36.0
    /// ... its top end curving into the bezel over this, as the notch's ends do.
    static let topEnd = 28.0

    /// A mark's ring, and the step from one to the next.
    static let mark = 24.0, pitch = 30.0
    static let padTop = 2.0
    /// The last needs you to the hairline, and the hairline to the next mark.
    static let hair = 21.5
    /// The pointer is on a mark within this of its centre, the hairline's gap included.
    static let near = 22.0

    /// A tab's body: its row, two lines, ...
    static let tabHeight = 52.0
    /// ... flared into the strip at both ends, its two front corners round.
    static let flare = 10.0, corner = 16.0
    static let tabMin = 240.0, tabMax = 360.0, tabSlack = 16.0
    /// The first mark's open tab's top under the menu bar, at Room 0: 16.
    static let tabTop = topEnd + padTop + mark / 2 - tabHeight / 2
    /// A tab's edge meets the S's lower curve in a fillet of up to the flare's, that never leaves the S higher than
    /// where it has turned this, so its tight curve and its bump read whole above it; with too little room the fillet
    /// tightens, to this at the least.
    static let fitKeep = 70 * Double.pi / 180, fitMin = 2.0
    /// Drawn back past the edge, the strip dents by a few points at most.
    static let dentGive = 3.0
    /// A mark's ring lifts under the pointer, and settles back, over this long (the prototype's transition).
    static let liftFade = 110.0

    /// The count's tab: a row each for the rest.
    static let rowHeight = 43.0, rowGap = 2.0, rowsPad = 8.0

    /// The bottom end, the top's S mirrored, leaves the screen's edge this far over the screen's bottom.
    static let bottomEnd = 26.0
    /// The top end's S, as drawn in Paper: two cubics in the strip's own frame, x out from the screen's edge at a
    /// 36pt strip, y down from the menu bar; the bottom end is it mirrored.
    static let sCurve: [Vec] = [Vec(0, 0), Vec(0, 6), Vec(4, 9), Vec(12, 11), Vec(26, 14), Vec(36, 18), Vec(36, 28)]

    /// A click on a mark presses its ring in to this.
    static let markPress = 0.88

    /// A leave this fast, points per ms, gets the shortest grace, this share of Grace.
    static let fastLeave = 1.5, graceFast = 0.2

    /// The words come in as the depth goes from this share of the tab's width to this.
    static let textFrom = 0.55, textTo = 0.95
    /// Gliding, the old words go in this share of Fade, the new come from this share of it to its end, this far
    /// apart.
    static let outShare = 0.5, inFrom = 0.35, shift = 6.0
    /// Drawing back, the words go in this, ...
    static let outFade = 60.0
    /// ... and the black starts back this far into it (÷ Close).
    static let closeAt = 30.0

    static let jumpSpin = 450.0
    /// A new mark's ring flashes this far apart, as the notch swells, ...
    static let flashGap = 450.0
    /// ... and it is washed orange this long, then fades.
    static let washHold = 1500.0, washFade = 500.0
    /// A new mark starts growing once the mark below has slid this share of its step.
    static let growAt = 0.45

    /// A spring within this of its target, and all but still, has settled.
    static let settled = 0.5

    /// With both needs you and the rest on the strip, the hairline takes this much more than a step.
    static let hairExtra = 2 * hair - pitch

    /// With nothing running, Grows, it draws back into the notch at rest, meniscus.html's: this deep and this long,
    /// each end its S-curve (0,0) (0,17) (7,13) (7,29), split in two as the strip's S is drawn, so one morphs into the
    /// other point for point.
    static let notchWidth = 7.0, notchHeight = 76.0, notchEnd = 29.0
    static let notchCurve: [Vec] = [
        Vec(0, 0), Vec(0, 8.5), Vec(1.75, 11.75), Vec(3.5, 14.875), Vec(5.25, 18),
        Vec(notchWidth, 21), Vec(notchWidth, notchEnd),
    ]
    /// A tab out of the notch at rest sits centred on it.
    static let notchClear = (notchHeight - tabHeight) / 2
    /// Emptied, the column waits this long for its last marks to fade, then narrows, ...
    static let morphWait = 120.0
    /// ... and the marks fade as it narrows from this share of the way to the notch to this.
    static let marksGo = 0.2, marksGone = 0.7
    /// The notch at rest answers the pointer this far out from the edge, and this far past its ends.
    static let notchHit = 12.0, notchHitY = 4.0
    /// A ring isn't drawn past the strip's black: as an end sweeps over it, it fades across the end's S, gone this far
    /// from the end, all there this far.
    static let coverFrom = 8.0, coverTo = 22.0
}
