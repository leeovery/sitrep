import CoreGraphics

/// Where a session's row in the panel lays its parts, as the prototype's rows lay them out, the same in black and in
/// glass: its mark at the left, its title and its project and work beside it, its age at the right.
struct SessionRowLayout {
    let mark: CGPoint
    let title, sub, age: CGRect

    static let radius = 14.0
    private static let pad = (top: 10.0, side: 10.0), gap = 10.0
    private static let markBox = CGSize(width: 12, height: 18), ageWidth = 36.0
    private static let titleLine = 18.0, subLine = 16.0

    init(size: CGSize) {
        let textX = Self.pad.side + Self.markBox.width + Self.gap
        let textWidth = size.width - textX - Self.gap - Self.ageWidth - Self.pad.side

        mark = CGPoint(x: Self.pad.side + Self.markBox.width / 2, y: Self.pad.top + Self.markBox.height / 2)
        title = CGRect(x: textX, y: Self.pad.top, width: textWidth, height: Self.titleLine)
        sub = CGRect(x: textX, y: title.maxY, width: textWidth, height: Self.subLine)
        age = CGRect(
            x: size.width - Self.pad.side - Self.ageWidth, y: Self.pad.top, width: Self.ageWidth, height: Self.titleLine
        )
    }
}

/// The panel's head: how many need Lee at the left, how many sessions at the right, on one line.
enum HeadLayout {
    static let line = 16.0, inset = (left: 10.0, right: 8.0)
}

/// The rule between what needs Lee and the rest: a point high, inset as a row's text is.
enum DividerLayout {
    static func rule(width: Double) -> CGRect { CGRect(x: 10, y: 2, width: width - 20, height: 1) }
}
