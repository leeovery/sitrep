import CoreGraphics
import Foundation

/// A point or a direction in the panel's plane: x is depth from the screen's edge into the screen, y runs down.
typealias Vec = SIMD2<Double>

extension Vec {
    var length: Double { hypot(x, y) }

    /// The JS's `Math.hypot(...) || 1`: a length to divide by, never zero.
    var divisor: Double { length > 0 ? length : 1 }
}

extension CGPoint {
    init(_ v: Vec) {
        self.init(x: v.x, y: v.y)
    }
}

func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double { min(b, max(a, x)) }

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

func lerp(_ a: Vec, _ b: Vec, _ t: Double) -> Vec { a + (b - a) * t }

func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }

func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }

func easeInOut(_ t: Double) -> Double { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }

/// The JS's `toFixed`: a number printed with this many decimals.
func fixed(_ x: Double, _ decimals: Int) -> String { String(format: "%.\(decimals)f", x) }
