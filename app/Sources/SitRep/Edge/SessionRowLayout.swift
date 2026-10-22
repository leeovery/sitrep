import CoreGraphics
import SitRepPanel

/// Where a session's row in the panel lays its parts, as the prototype's rows lay them out, the same in black and in
/// glass: its mark at the left, its title beside it and its time at the right; then the line under them. A row fills
/// the row's 55 of `Content(laying:)`: 10 above, the two lines' 34, and 11 below. Under the pointer its button takes
/// its time's place (`Opener`).
struct SessionRowLayout {
    /// The mark's centre: where a working row's arc turns.
    let mark: CGPoint
    let title, age, sub: CGRect
    /// The button that opens its session in the SitRep window.
    let opener: CGRect

    static let radius = 14.0
    /// A your-turn row's on one line, board D's.
    static let turnRadius = 10.0
    /// Between a session's name and its "+2", board F's.
    static let countGap = 6.0
    /// Between a your-turn row's words and its project.
    static let projectGap = 12.0
    static let pad = (top: 10.0, side: 10.0), gap = 10.0
    static let markBox = CGSize(width: 12, height: 18), ageWidth = 36.0
    static let titleLine = 18.0
    private static let subLine = 16.0

    init(size: CGSize) {
        let textX = Self.pad.side + Self.markBox.width + Self.gap
        let textWidth = size.width - textX - Self.gap - Self.ageWidth - Self.pad.side
        let top = Self.pad.top

        mark = CGPoint(x: Self.pad.side + Self.markBox.width / 2, y: top + Self.markBox.height / 2)
        title = CGRect(x: textX, y: top, width: textWidth, height: Self.titleLine)
        age = CGRect(x: size.width - Self.pad.side - Self.ageWidth, y: top, width: Self.ageWidth, height: Self.titleLine)
        sub = CGRect(x: textX, y: title.maxY, width: textWidth, height: Self.subLine)
        opener = Opener.frame(in: size)
    }

    /// A your-turn row on one line, as board D lays it out on the card: its mark, its words, its project in a lane
    /// at the right of them, its own width and 12 after the words, never cut while the words are, and its time in the
    /// 36 lane, each in a line of 18 on the row's middle. `sub` is the project's lane.
    init(turn size: CGSize, project: Double) {
        let top = (size.height - Self.titleLine) / 2
        let textX = Self.pad.side + Self.markBox.width + Self.gap
        let middle = size.width - textX - Self.gap - Self.ageWidth - Self.pad.side
        let project = min(project, middle)

        mark = CGPoint(x: Self.pad.side + Self.markBox.width / 2, y: size.height / 2)
        title = CGRect(x: textX, y: top, width: max(0, middle - project - Self.projectGap), height: Self.titleLine)
        age = CGRect(x: size.width - Self.pad.side - Self.ageWidth, y: top, width: Self.ageWidth, height: Self.titleLine)
        sub = CGRect(x: textX + middle - project, y: top, width: project, height: Self.titleLine)
        opener = Opener.frame(in: size)
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

/// "N earlier", as board D lays it out in its 34: its ring in a row's mark lane; "8 earlier" its own width, then 7
/// after it its sessions' projects, cut short, each on a line of 18 on its middle; its chevron in a box of 15 by 24
/// 7.5 in from the right.
enum EarlierLayout {
    static let gap = 7.0

    static func mark(in size: CGSize) -> CGPoint {
        CGPoint(x: SessionRowLayout.pad.side + SessionRowLayout.markBox.width / 2, y: size.height / 2)
    }

    /// The words' line, from the mark lane to the chevron's box.
    static func words(in size: CGSize) -> CGRect {
        let x = SessionRowLayout.pad.side + SessionRowLayout.markBox.width + SessionRowLayout.gap
        let line = SessionRowLayout.titleLine

        return CGRect(x: x, y: (size.height - line) / 2, width: chevron(in: size).minX - SessionRowLayout.gap - x, height: line)
    }

    static func chevron(in size: CGSize) -> CGRect {
        CardChevron.placed(right: size.width - 7.5, middle: size.height / 2)
    }
}

/// The chevron an eyebrow and "N earlier" end with, board D's: 10 by 6 pointing down while what it heads is open, 6
/// by 10 pointing right while it is folded, centred in its box of 15 by 24, stroked 1.5 with round caps and joins.
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

/// The glyph on a row's button that opens its session in the SitRep window, board F's: a window with its sidebar, a
/// rounded rect 11.5 by 9.5, its corners 2, and a line down it 4.75 in, stroked 1.5, 13 by 11 overall.
enum OpenerGlyph {
    static let size = CGSize(width: 13, height: 11), stroke = 1.5

    /// Its path in its own 13 by 11.
    static var path: CGPath {
        let path = CGMutablePath(), inset = stroke / 2

        path.addRoundedRect(
            in: CGRect(x: inset, y: inset, width: 11.5, height: 9.5), cornerWidth: 2, cornerHeight: 2
        )
        path.move(to: CGPoint(x: 4.75, y: inset))
        path.addLine(to: CGPoint(x: 4.75, y: size.height - inset))
        return path
    }

    /// Centred in a box.
    static func placed(in box: CGRect) -> CGRect {
        CGRect(
            x: box.midX - size.width / 2, y: box.midY - size.height / 2, width: size.width, height: size.height
        )
    }
}

/// The rule between what needs Lee and the rest: a point high, inset as a row's text is.
enum DividerLayout {
    static func rule(width: Double) -> CGRect { CGRect(x: 10, y: 2, width: width - 20, height: 1) }
}
