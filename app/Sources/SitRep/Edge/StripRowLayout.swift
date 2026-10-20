import AppKit
import SitRepEdge
import SitRepPanel

/// Where a tab lays a session's row in its words' box, as the prototype's `.tl` lays it out, the same in black and in
/// glass: the title and the line under it at the left, centred down the box, and the time at the right, where the
/// spinner turns while a click jumps.
struct StripRowLayout {
    let title, sub, age, spinner: CGRect

    static let pad = (left: 12.0, right: 14.0), gap = 10.0
    /// The time's lane is as wide as its words, and no narrower than this.
    static let ageMin = 18.0
    private static let titleLine = 18.0, subLine = 16.0, lines = 3.0, ageTop = 8.0, spinnerSize = 11.0

    /// A session's row, its time's lane as wide as its time reads now.
    @MainActor
    init(_ session: Session, note: StripNote, in size: CGSize, now: Double) {
        self.init(in: size, lane: Self.ageWidth(note.age(session, at: now)))
    }

    /// A time's lane: as wide as the time is set in black, and no narrower than `ageMin`.
    @MainActor
    static func ageWidth(_ text: String) -> Double {
        max(ageMin, TextLine.width(ageLine(text)))
    }

    /// A time as the black sets it.
    @MainActor
    static func ageLine(_ text: String) -> NSAttributedString {
        TextLine.text(text, EdgeStyle.age, EdgeStyle.ink3)
    }

    /// The notch at rest's two lines: as a row's, with no time.
    static func idle(in size: CGSize) -> Self {
        Self(in: size, lane: nil)
    }

    private init(in size: CGSize, lane: Double?) {
        let laneX = size.width - Self.pad.right - (lane ?? 0)
        let textWidth = laneX - (lane == nil ? 0 : Self.gap) - Self.pad.left
        let top = (size.height - 1 - (Self.titleLine + Self.lines + Self.subLine)) / 2

        title = CGRect(x: Self.pad.left, y: top, width: textWidth, height: Self.titleLine)
        sub = CGRect(x: Self.pad.left, y: title.maxY + Self.lines, width: textWidth, height: Self.subLine)
        age = CGRect(x: laneX, y: Self.ageTop, width: lane ?? 0, height: Self.titleLine)
        spinner = CGRect(
            x: age.maxX - Self.spinnerSize, y: Self.ageTop + (Self.titleLine - Self.spinnerSize) / 2,
            width: Self.spinnerSize, height: Self.spinnerSize
        )
    }

    /// Where a time is set as it ticks: right-aligned in its lane, free to run into the gap before it as it grows.
    var ageBox: CGRect {
        CGRect(x: age.minX - Self.gap, y: age.minY, width: age.width + Self.gap, height: age.height)
    }
}

/// Where a count's tab lays each of its rows: a box that lifts under the pointer, and its two lines.
struct StripRowsLayout {
    let box, title, sub: CGRect

    static let radius = 10.0
    private static let side = 6.0, top = 5.0, titleLine = 17.0, subLine = 14.0, lines = 2.0

    init(_ index: Int, width: Double) {
        let inner = width - StripRowLayout.pad.left - StripRowLayout.pad.right
        let pitch = StripFrame.Words.rowHeight + StripFrame.Words.rowGap

        box = CGRect(
            x: StripRowLayout.pad.left - Self.side, y: StripFrame.Words.rowsPad + Double(index) * pitch,
            width: inner + 2 * Self.side, height: StripFrame.Words.rowHeight
        )
        title = CGRect(x: Self.side, y: Self.top, width: inner, height: Self.titleLine)
        sub = CGRect(x: Self.side, y: title.maxY + Self.lines, width: inner, height: Self.subLine)
    }
}
