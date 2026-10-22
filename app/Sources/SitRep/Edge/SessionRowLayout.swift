import CoreGraphics
import SitRepPanel

/// Where a session's row in the panel lays its parts, as the prototype's rows lay them out, the same in black and in
/// glass: each line's mark at the left, its title beside it and its time at the right, the lines 4 apart as board D
/// sets a row with several; then its project and session under the last. A row of one line fills the row's 55 of
/// `Content(laying:)`: 10 above, the two lines' 34, and 11 below; each line more adds its 18 and the 4 over it
/// (`Item.lineStep`).
struct SessionRowLayout {
    /// One of the row's lines: its mark's centre, its title's box and its time's.
    struct Line {
        let mark: CGPoint
        let title, age: CGRect
    }

    /// The oldest first; never none.
    let lines: [Line]
    let sub: CGRect

    static let radius = 14.0
    /// Between the title and a question's "+2".
    static let moreGap = 4.0
    private static let pad = (top: 10.0, side: 10.0), gap = 10.0
    private static let markBox = CGSize(width: 12, height: 18), ageWidth = 36.0
    private static let titleLine = 18.0, subLine = 16.0

    init(size: CGSize, lines count: Int = 1) {
        let textX = Self.pad.side + Self.markBox.width + Self.gap
        let textWidth = size.width - textX - Self.gap - Self.ageWidth - Self.pad.side
        let lines = (0 ..< max(1, count)).map { index in
            let top = Self.pad.top + Item.lineStep * Double(index)

            return Line(
                mark: CGPoint(x: Self.pad.side + Self.markBox.width / 2, y: top + Self.markBox.height / 2),
                title: CGRect(x: textX, y: top, width: textWidth, height: Self.titleLine),
                age: CGRect(x: size.width - Self.pad.side - Self.ageWidth, y: top, width: Self.ageWidth, height: Self.titleLine)
            )
        }

        self.lines = lines
        sub = CGRect(x: textX, y: lines[lines.count - 1].title.maxY, width: textWidth, height: Self.subLine)
    }

    /// The first line's: where a working row's arc turns, and a pressed row's spinner.
    var mark: CGPoint { lines[0].mark }
    var title: CGRect { lines[0].title }
    var age: CGRect { lines[0].age }
}

/// The panel's head: how many need Lee at the left, how many sessions at the right, on one line.
enum HeadLayout {
    static let line = 16.0, inset = (left: 10.0, right: 8.0)
}

/// The rule between what needs Lee and the rest: a point high, inset as a row's text is.
enum DividerLayout {
    static func rule(width: Double) -> CGRect { CGRect(x: 10, y: 2, width: width - 20, height: 1) }
}
