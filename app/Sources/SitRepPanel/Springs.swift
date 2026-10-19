import Foundation

/// A spring's feel as SwiftUI's `.spring(response:dampingFraction:)`: the response in seconds.
struct SpringParams: Equatable, Sendable {
    var response: Double
    var damping: Double

    /// After Bounce, its damping scaled and capped at 1, and its response divided by a speed.
    func after(bounce scale: Double, speed: Double = 1) -> SpringParams {
        SpringParams(response: response / speed, damping: min(1, damping * scale))
    }
}

/// What every form's feel shares: Bounce, which scales every spring's damping.
protocol Feel {
    var bounce: Double { get }
}

extension Feel {
    /// At 0 ×1.4, at 0.5 as listed, at 1 ×0.7; a damping it scales is capped at 1.
    var bounceScale: Double {
        bounce <= 0.5 ? lerp(1.4, 1, bounce / 0.5) : lerp(1, 0.7, (bounce - 0.5) / 0.5)
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

/// How far past its target an underdamped spring swings on its first overshoot, as a share of the way it came.
func overshootShare(_ z: Double) -> Double {
    z >= 1 ? 0 : exp(-Double.pi * z / (1 - z * z).squareRoot())
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

    /// The outward speed that takes it, on its own spring, to a peak of x, found by bisection on a look-ahead of it
    /// (the prototype's `kickTo`); its own speed when it is there already.
    func kick(toPeak x: Double) -> Double {
        guard self.x < x else {
            return v
        }

        func peak(_ v: Double) -> Double {
            var look = self
            look.v = v
            var top = look.x, ms = 0
            while ms < 1000, look.v >= 0 {
                look.step(1)
                top = max(top, look.x)
                ms += 1
            }
            return top
        }

        var lo = 0.0, hi = 10.0
        for _ in 0 ..< 32 {
            let v = (lo + hi) / 2
            if peak(v) > x {
                hi = v
            } else {
                lo = v
            }
        }
        return lo
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
