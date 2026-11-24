import CoreGraphics

/// The way from the list to the asks panel, as a Mac submenu keeps its own: from where the pointer last was on the
/// list to the asks panel's near side, the triangle it crosses holds the panel open while the pointer keeps closing on
/// the asks panel, and for `lasts` at most. Closing in is judged over `window`, not from one step to the next, so a
/// step with no new sample of the pointer, or a point of jitter, leaves it as it was; a pointer resting there longer
/// than `window`, turning away, or out of it is off the panel at once, and the way holds no more until the pointer
/// is back on the list. The way starts as the pointer moves off the list: the list going from under a still pointer
/// starts none.
struct SafeTriangle {
    /// Where the pointer last was on the list, and when.
    private var from: (point: CGPoint, time: Double)?
    /// The pointer's samples on the way, each with how far it was from the asks panel: the last one at or before
    /// `window` ago, and every one since; none while nothing holds it.
    private var samples: [(time: Double, point: CGPoint, distance: Double)] = []

    /// How long, ms, the way holds after the pointer leaves the list. The longest way off both, from the right edge's
    /// arrow at the row's far end to the last answer below a one-row list, is about 300pt: crossed at a deliberate
    /// 0.75pt/ms, it takes 400ms. Longer adds nothing for a pointer on its way, since one resting or turning away is
    /// off at once.
    static let lasts = 400.0
    /// How long, ms, closing in is judged over, and a pointer rests before it is resting. A mouse reports at 125Hz or
    /// more and a trackpad at about 90Hz, so a pointer on its way gives several samples in it at any display's rate,
    /// and a turn away ends the way within it.
    static let window = 80.0
    /// How much further, pt, the pointer may be from the asks panel than `window` before, as a hand's jitter takes it.
    static let jitter = 1.0

    /// Whether it holds the pointer, which must then be judged as time passes, whether or not it moves.
    var holds: Bool { !samples.isEmpty }

    /// The triangle that holds the pointer at this time, on its way from the list to `target`, the asks panel on the
    /// stage; nil where none does.
    mutating func holding(_ pointer: CGPoint?, onList: Bool, toward target: CGRect?, at time: Double) -> CGPath? {
        guard let pointer, let target, !target.contains(pointer) else {
            return forget()
        }
        guard !onList else {
            from = (pointer, time)
            samples = []
            return nil
        }
        guard let from, !samples.isEmpty || pointer != from.point, time - from.time <= Self.lasts else {
            return forget()
        }

        let triangle = Self.triangle(from.point, to: target)

        if samples.isEmpty {
            samples = [(from.time, from.point, Self.distance(from.point, to: target))]
        }

        let last = samples[samples.count - 1]

        guard pointer != last.point else {
            return time - last.time <= Self.window ? triangle : forget()
        }

        let distance = Self.distance(pointer, to: target)
        let then = samples.lastIndex { $0.time <= time - Self.window } ?? 0

        guard triangle.contains(pointer), distance < samples[then].distance + Self.jitter else {
            return forget()
        }

        samples.removeFirst(then)
        samples.append((time, pointer, distance))
        return triangle
    }

    private mutating func forget() -> CGPath? {
        from = nil
        samples = []
        return nil
    }

    /// From a point to the near side's two corners of a box further from the edge.
    private static func triangle(_ from: CGPoint, to target: CGRect) -> CGPath {
        let triangle = CGMutablePath()

        triangle.addLines(between: [
            from, CGPoint(x: target.minX, y: target.minY), CGPoint(x: target.minX, y: target.maxY),
        ])
        triangle.closeSubpath()
        return triangle
    }

    private static func distance(_ point: CGPoint, to box: CGRect) -> Double {
        hypot(max(box.minX - point.x, 0, point.x - box.maxX), max(box.minY - point.y, 0, point.y - box.maxY))
    }
}
