import Foundation

/// A spring's feel as SwiftUI's `.spring(response:dampingFraction:)`: the response in seconds.
public struct SpringParams: Equatable, Sendable {
    public var response: Double
    public var damping: Double

    public init(response: Double, damping: Double) {
        self.response = response
        self.damping = damping
    }
}

/// The prototype's springs (its `SPRINGS`), in its order; Bounce scales every one's damping.
public enum SpringKind: CaseIterable, Sendable {
    case attract, relax, home, pourH, pourW, cling, clingY, tongue, ret, ring, letGo, drain, land, rebound, ask

    /// What the readout calls it.
    public var label: String {
        switch self {
        case .attract: "attract"
        case .relax: "relax"
        case .home: "home"
        case .pourH: "pour h"
        case .pourW: "pour w"
        case .cling: "cling"
        case .clingY: "cling y"
        case .tongue: "tongue"
        case .ret: "return"
        case .ring: "ring"
        case .letGo: "release"
        case .drain: "drain"
        case .land: "land"
        case .rebound: "rebound"
        case .ask: "ask"
        }
    }

    /// As listed, before Bounce.
    var listed: SpringParams {
        switch self {
        case .attract: SpringParams(response: 0.20, damping: 0.75)
        case .relax: SpringParams(response: 0.45, damping: 0.55)
        case .home: SpringParams(response: 0.60, damping: 0.80)
        case .pourH: SpringParams(response: 0.40, damping: 0.75)
        case .pourW: SpringParams(response: 0.34, damping: 0.72)
        case .cling: SpringParams(response: 0.24, damping: 0.72)
        case .clingY: SpringParams(response: 0.16, damping: 0.86)
        case .tongue: SpringParams(response: 0.08, damping: 0.80)
        case .ret: SpringParams(response: 0.30, damping: 0.38)
        case .ring: SpringParams(response: 0.17, damping: 0.38)
        case .letGo: SpringParams(response: 0.30, damping: 0.50)
        // ×Bounce and capped at 1: about critical, so it eases in and never swings; the landing bounces.
        case .drain: SpringParams(response: 0.60, damping: 1.25)
        case .land: SpringParams(response: 0.19, damping: 0.31)
        case .rebound: SpringParams(response: 0.20, damping: 0.55)
        case .ask: SpringParams(response: 0.42, damping: 0.50)
        }
    }
}

extension Settings {
    /// Bounce: 0 scales every dampingFraction ×1.4 (capped at 1), 0.5 leaves it as listed, 1 scales it ×0.7.
    public var bounceScale: Double {
        bounce <= 0.5 ? lerp(1.4, 1, bounce / 0.5) : lerp(1, 0.7, (bounce - 0.5) / 0.5)
    }

    /// A spring after Bounce (the prototype's `SP`).
    public func sp(_ kind: SpringKind) -> SpringParams {
        let listed = kind.listed
        return SpringParams(response: listed.response, damping: min(1, listed.damping * bounceScale))
    }
}

/// The peak of an underdamped spring's answer to a kick v0 is about v0/ω · peakShare(ζ).
func peakShare(_ z: Double) -> Double {
    if z >= 0.999 {
        return 1 / M_E
    }

    let q = (1 - z * z).squareRoot()
    return exp(-z / q * atan2(q, z))
}

/// One spring. Two kinds share one state (x, and v in points per ms), so either can take over from the other
/// mid-flight and the velocity carries across:
///  - crit: critically damped, never past the target, for precision; `to`'s duration is the time to cover about
///    95% of the way;
///  - under: SwiftUI's `.spring(response:dampingFraction:)`, unit mass, stiffness k = (2π/response)², damping
///    c = 4π·dampingFraction/response, integrated semi-implicitly in substeps of at most 4ms.
struct Spring {
    enum Mode {
        case crit, under
    }

    var x: Double
    var v = 0.0
    var target: Double
    var mode = Mode.crit
    var omega = 0.03
    var k = 0.0
    var c = 0.0

    init(_ x: Double) {
        self.x = x
        target = x
    }

    /// Whether `step` takes it as settled.
    var isAtRest: Bool { abs(x - target) < 1e-3 && abs(v) < 1e-4 }

    mutating func to(_ target: Double, _ dur: Double) {
        self.target = target
        mode = .crit
        omega = 4.7 / max(1, dur)
    }

    mutating func springTo(_ target: Double, _ p: SpringParams) {
        self.target = target
        mode = .under
        let resp = max(0.02, p.response) * 1000
        k = pow(2 * Double.pi / resp, 2)
        c = 4 * Double.pi * p.damping / resp
    }

    mutating func snap(_ x: Double) {
        self.x = x
        target = x
        v = 0
    }

    /// Takes another's kind and feel, keeping its own place, target and speed (the prototype's `copySpring`).
    mutating func copySpring(_ src: Spring) {
        mode = src.mode
        omega = src.omega
        k = src.k
        c = src.c
    }

    /// The prototype's `stepSpring`.
    mutating func step(_ dt: Double) {
        let d = x - target
        if isAtRest {
            x = target
            v = 0
            return
        }

        switch mode {
        case .under:
            // substeps of at most 4ms, shorter for a stiff or heavily damped spring, which would otherwise blow up
            let longest = min(4, 0.5 / max(1e-6, c), 0.5 / max(1e-12, k).squareRoot())
            let n = Int(min(400, max(1, (dt / longest).rounded(.up))))
            let h = dt / Double(n)
            for _ in 0 ..< n {
                v += (-k * (x - target) - c * v) * h
                x += v * h
            }
        case .crit:
            let w = omega, e = exp(-w * dt), lead = v + w * d
            var nd = (d + lead * dt) * e
            var nv = (v - w * lead * dt) * e
            // a retarget mid-flight can't carry it past
            if nd * d < 0 {
                nd = 0
                nv = 0
            }
            x = target + nd
            v = nv
        }
    }
}

/// Every spring the shape is made of, by the prototype's names (its `S`).
struct Springs {
    var w, h, r, f: Spring
    /// The shape's centre, chasing the lip's home.
    var y: Spring
    /// The content's top edge.
    var ct = Spring(0)
    /// Anything needs Lee.
    var light: Spring
    /// The light, dimmed while the panel is out.
    var vis = Spring(1)
    /// The lip's slide along the edge after its tongue, off its home.
    var ay = Spring(0)
    /// The tongue: how far its tip stands out of the edge (a dent below 0) ...
    var ba = Spring(0)
    /// ... and where along the edge its tip is, stage y.
    var by: Spring
    /// Collapsing home after a leave: the shape's top end, stage y, ...
    var et = Spring(0)
    /// ... its bottom end, ...
    var eb = Spring(0)
    /// ... and the rebound past home that both carry, away from the exit.
    var rb = Spring(0)
    /// The landing's wobble on the lip's depth.
    var lw = Spring(0)

    init(lip: LipShape, lipY: Double, light: Double) {
        w = Spring(lip.w)
        h = Spring(lip.h)
        r = Spring(lip.r)
        f = Spring(lip.f)
        y = Spring(lipY)
        by = Spring(lipY)
        self.light = Spring(light)
    }

    /// Every one, in the prototype's order.
    static var all: [WritableKeyPath<Springs, Spring>] {
        [\.w, \.h, \.r, \.f, \.y, \.ct, \.light, \.vis, \.ay, \.ba, \.by, \.et, \.eb, \.rb, \.lw]
    }
}
