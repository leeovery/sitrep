import SitRepPanel

public extension StripMeasure {
    /// Every tab's words the one width: a session's row, a count's rows and the notch at rest's alike.
    static func uniform(_ width: Double) -> StripMeasure {
        StripMeasure(row: { _ in width }, rows: { _ in width }, idle: { width })
    }
}
