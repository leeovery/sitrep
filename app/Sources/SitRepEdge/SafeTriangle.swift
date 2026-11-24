import CoreGraphics

/// The way from the list to the asks panel, as a Mac submenu keeps its own: from where the pointer last was on the
/// list to the asks panel's near side, the triangle it crosses holds the panel open while the pointer keeps closing on
/// the asks panel, and for `lasts` at most. A pointer resting there, turning away, or out of it is off the panel at
/// once, and the way holds no more until the pointer is back on the list.
struct SafeTriangle {
    /// Where the pointer last was on the list.
    private var from: CGPoint?
    /// Since it left the list, when, and how far from the asks panel it last was.
    private var way: (since: Double, distance: Double)?

    /// How long, ms, the way holds after the pointer leaves the list. The longest way off both, from the right edge's
    /// arrow at the row's far end to the last answer below a one-row list, is about 300pt: crossed at a deliberate
    /// 0.75pt/ms, it takes 400ms. Longer adds nothing for a pointer on its way, since one resting or turning away is
    /// off at once.
    static let lasts = 400.0

    /// The triangle that holds the pointer at this time, on its way from the list to `target`, the asks panel on the
    /// stage; nil where none does.
    mutating func holding(_ pointer: CGPoint?, onList: Bool, toward target: CGRect?, at time: Double) -> CGPath? {
        guard let pointer, let target, !target.contains(pointer) else {
            return forget()
        }
        guard !onList else {
            from = pointer
            way = nil
            return nil
        }
        guard let from else {
            return nil
        }

        let triangle = Self.triangle(from, to: target), distance = Self.distance(pointer, to: target)
        let was = way ?? (since: time, distance: Self.distance(from, to: target))

        guard triangle.contains(pointer), distance < was.distance, time - was.since <= Self.lasts else {
            return forget()
        }

        way = (was.since, distance)
        return triangle
    }

    private mutating func forget() -> CGPath? {
        from = nil
        way = nil
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
