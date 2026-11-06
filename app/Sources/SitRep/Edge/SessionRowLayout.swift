import CoreGraphics
import SitRepPanel

/// Where a session's row on the card lays its parts, the same in black and in glass, every row on one line (board J):
/// its mark, its words, its project in a lane at the right of them, its own width and 12 after the words, never cut
/// while the words are, and its time in the 36 lane, or a Snoozed row's wider wake, which the lane grows to fit, each
/// in a line of 18 on the row's middle.
struct SessionRowLayout {
    /// The mark's centre: where a working row's arc turns.
    let mark: CGPoint
    /// Its words, and its project's lane.
    let title, age, project: CGRect

    /// Board D's lift, so the lifts of two rows meet.
    static let radius = 10.0
    /// Between a session's name and its count, board F's.
    static let countGap = 6.0
    /// Between a row's words and its project.
    static let projectGap = 12.0
    static let side = 10.0, gap = 10.0
    static let markWidth = 12.0, ageWidth = 36.0
    static let titleLine = 18.0

    /// A row this big whose project is this wide, and its time too: the 36 lane, or a Snoozed row's wider wake.
    init(size: CGSize, project: Double, time: Double = 0) {
        let lane = max(Self.ageWidth, time)
        let top = (size.height - Self.titleLine) / 2
        let textX = Self.side + Self.markWidth + Self.gap
        let middle = max(0, size.width - textX - Self.gap - lane - Self.side)
        let projectWidth = min(project, middle)

        mark = CGPoint(x: Self.side + Self.markWidth / 2, y: size.height / 2)
        title = CGRect(x: textX, y: top, width: max(0, middle - projectWidth - Self.projectGap), height: Self.titleLine)
        age = CGRect(x: size.width - Self.side - lane, y: top, width: lane, height: Self.titleLine)
        self.project = CGRect(x: textX + middle - projectWidth, y: top, width: projectWidth, height: Self.titleLine)
    }
}

/// The panel's head: how many need Lee at the left, how many sessions at the right, on one line.
enum HeadLayout {
    static let line = 16.0, inset = (left: 10.0, right: 8.0)
}

/// A section's eyebrow, as board D lays it out in its 28, the same in black and in glass: its name 10 in, its count 6
/// after it, on one line of 14 on its middle; its chevron in a box of 15 by 24 7.5 in from the right, so the chevron
/// ends where a row's time does.
enum EyebrowLayout {
    static let gap = 6.0, line = 14.0

    static func label(in size: CGSize) -> CGRect {
        CGRect(x: 10, y: (size.height - line) / 2, width: size.width - 10 - 7.5 - CardChevron.box.width, height: line)
    }

    static func chevron(in size: CGSize) -> CGRect {
        CardChevron.placed(right: size.width - 7.5, middle: size.height / 2)
    }
}

/// The chevron an eyebrow ends with, board D's: 10 by 6 pointing down while its section is open, 6 by 10 pointing
/// right while it is folded, centred in its box of 15 by 24, stroked 1.5 with round caps and joins.
enum CardChevron {
    static let box = CGSize(width: 15, height: 24), stroke = 1.5

    static func placed(right: Double, middle: Double) -> CGRect {
        CGRect(x: right - box.width, y: middle - box.height / 2, width: box.width, height: box.height)
    }

    /// Its path in its box's own frame: pointing down, or right.
    static func path(isOpen: Bool) -> CGPath {
        let path = CGMutablePath()
        let size = isOpen ? CGSize(width: 10, height: 6) : CGSize(width: 6, height: 10)
        let origin = CGPoint(x: (box.width - size.width) / 2, y: (box.height - size.height) / 2)
        let points = isOpen
            ? [CGPoint(x: 1.2, y: 1.2), CGPoint(x: 5, y: 4.8), CGPoint(x: 8.8, y: 1.2)]
            : [CGPoint(x: 1.2, y: 1.2), CGPoint(x: 4.8, y: 5), CGPoint(x: 1.2, y: 8.8)]

        path.addLines(between: points.map { CGPoint(x: origin.x + $0.x, y: origin.y + $0.y) })
        return path
    }
}
