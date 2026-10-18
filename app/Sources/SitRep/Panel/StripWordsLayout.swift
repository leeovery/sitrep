import CoreGraphics
import SitRepPanel

/// Where a session's row lays its parts in its words' box, as the prototype's `.tl` lays them out, the same in black
/// and in glass: the title and the line under it at the left, centred down the box, and the age at the right, where
/// the spinner turns while a click jumps.
@MainActor
struct StripRowLayout {
    let title, sub, age, spinner: CGRect

    static let pad = (left: 12.0, right: 14.0), gap = 10.0
    private static let titleLine = 18.0, subLine = 16.0, lines = 3.0, ageTop = 8.0, spinner = 11.0

    init(_ session: StripSession, in size: CGSize, now: Double) {
        let ageWidth = StripWordsLayer.ageWidth(session, at: now)
        let laneX = size.width - Self.pad.right - ageWidth
        let textWidth = laneX - Self.gap - Self.pad.left
        let top = (size.height - 1 - (Self.titleLine + Self.lines + Self.subLine)) / 2

        title = CGRect(x: Self.pad.left, y: top, width: textWidth, height: Self.titleLine)
        sub = CGRect(x: Self.pad.left, y: title.maxY + Self.lines, width: textWidth, height: Self.subLine)
        age = CGRect(x: laneX, y: Self.ageTop, width: ageWidth, height: Self.titleLine)
        spinner = CGRect(
            x: age.maxX - Self.spinner, y: Self.ageTop + (Self.titleLine - Self.spinner) / 2, width: Self.spinner,
            height: Self.spinner
        )
    }
}

/// Where the count's tab lays each of its rows: a box that lifts under the pointer, and its two lines.
@MainActor
struct StripRowsLayout {
    let box, title, sub: CGRect

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
