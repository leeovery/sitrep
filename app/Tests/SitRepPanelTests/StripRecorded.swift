import CoreGraphics
@testable import SitRepPanel

/// A frame of the strip as its prototype recorded it (`StripRecording.swift`).
struct StripRecorded {
    struct Tab {
        let key: String
        let phase: StripTab.Phase
        let w, h, y, press, alpha: Double
        /// Each of its words' opacity, by its key, in its order.
        let words: [Words]
        /// While it is out, where its top and its bottom meet the strip's ends.
        let top, bottom: End?
    }

    /// Where a tab's fillet leaves the strip's edge, on the screen, its radius, the edge's direction there in degrees,
    /// and whether that is on the S or the straight edge.
    struct End {
        enum On { case s, edge }

        let x, y, rho, phi: Double
        let on: On
    }

    struct Words: Equatable {
        let key: String
        let alpha: Double
    }

    /// A spring's three: for a mark its centre, scale and opacity; for the hairline its y and opacity.
    struct Mark {
        let y, sc, op: Double
    }

    let t: Double
    /// The pointer as the strip took it; nil off the page.
    let p: CGPoint?
    let hair: Mark
    /// "mark s6" or "tab s7": a click jumping.
    let jumping: String?
    let tabs: [Tab]
    /// The scenario's marks, in its order; nil for one not on the strip.
    let marks: [Mark?]
    let more: Mark?

    static func R(
        _ t: Double, _ p: CGPoint?, hair: Mark, jumping: String? = nil, tabs: [Tab] = [], marks: [Mark?] = [],
        more: Mark? = nil
    ) -> Self {
        Self(t: t, p: p, hair: hair, jumping: jumping, tabs: tabs, marks: marks, more: more)
    }

    static func T(
        _ key: String, _ phase: StripTab.Phase, w: Double, h: Double, y: Double, press: Double, alpha: Double,
        words: [Words], top: End? = nil, bottom: End? = nil
    ) -> Tab {
        Tab(key: key, phase: phase, w: w, h: h, y: y, press: press, alpha: alpha, words: words, top: top, bottom: bottom)
    }

    static func E(_ x: Double, _ y: Double, _ rho: Double, _ phi: Double, _ on: End.On) -> End {
        End(x: x, y: y, rho: rho, phi: phi, on: on)
    }

    static func W(_ key: String, _ alpha: Double) -> Words { Words(key: key, alpha: alpha) }

    static func M(_ y: Double, _ sc: Double, _ op: Double) -> Mark { Mark(y: y, sc: sc, op: op) }

    static func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
}
