/// The strip's own constants (strip.html's, from `STRIP` to `GROW_AT`), each with its value unchanged and a name close
/// to its own.
enum StripTuning {
    /// The strip: the bezel grown, 36 of the same black, ...
    static let width = 36.0
    /// ... its top end curving into the bezel over this, as the notch's ends do.
    static let topEnd = 28.0

    /// A mark's ring, and the step from one to the next.
    static let mark = 24.0, pitch = 30.0
    static let padTop = 2.0, padBottom = 8.0
    /// The last needs you to the hairline, and the hairline to the next mark.
    static let hair = 21.5
    /// The pointer is on a mark within this of its centre, the hairline's gap included.
    static let near = 22.0

    /// A tab's body: its row, two lines, ...
    static let tabHeight = 52.0
    /// ... flared into the strip at both ends, its two front corners round.
    static let flare = 10.0, corner = 16.0
    static let tabMin = 240.0, tabMax = 360.0, tabSlack = 16.0
    /// A tab's body keeps this far from the screen's bottom.
    static let keep = 4.0
    /// Drawn back past the edge, the strip dents by a few points at most.
    static let dentGive = 3.0

    /// The count's tab: a row each for the rest.
    static let rowHeight = 43.0, rowGap = 2.0, rowsPad = 8.0

    /// A tab, a reach or a dent starts at least this far down the straight edge from where the top end ends, so the
    /// two never meet.
    static let spare = 3.0
    /// Give way: the top end drawn up into a fillet this tight under the menu bar.
    static let giveMin = 3.0
    /// Drawn up as far as this, the top end's S only gets shallower; further, it narrows too.
    static let giveSquash = 14.0
    /// The top end's S, as drawn in Paper: two cubics in the strip's own frame, x out from the screen's edge at a
    /// 36pt strip, y down from the menu bar.
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
}
