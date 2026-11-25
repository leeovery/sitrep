import CoreGraphics
import Foundation

/// An ask as the asks panel answers it (DESIGN, "Answering from the panel"): its title, the answers it offers in
/// Claude's order, a yes's one or a choice's options, and the one Claude recommends; none for a words ask, or a choice
/// with no options, which Lee answers in Claude. Its time is its line's on the row: its posting, or its reopening.
public struct PanelAsk: Equatable, Sendable {
    /// What it wants back, as the board says it, which its answer passes on, so one reshaped since is refused.
    public enum Wants: Sendable {
        case yes, choice, words
    }

    public let id: String
    public let title: String
    public let wants: Wants
    public let answers: [String]
    public let recommended: String?
    /// When its line began, ms on the wall clock.
    public let since: Double

    public init(
        id: String, title: String, wants: Wants, answers: [String] = [], recommended: String? = nil, since: Double
    ) {
        self.id = id
        self.title = title
        self.wants = wants
        self.answers = answers
        self.recommended = recommended.flatMap { answers.contains($0) ? $0 : nil }
        self.since = since
    }

    /// "Asked 4m ago" at this time on the wall clock, its age as a row words its time; under a minute, "Asked just
    /// now".
    public func askedText(at now: Double) -> String {
        Age(now - since) == .now ? "Asked just now" : "Asked \(Session.ageText(now - since)) ago"
    }

    /// When on the wall clock its age next reads differently: at its next whole minute.
    public func ageChanges(after now: Double) -> Double {
        Session.ageChanges(since: since, after: now)
    }
}

/// What on the asks panel takes a click.
public enum AsksPart: Hashable, Sendable {
    /// An answer's row, by its place among the ask's answers.
    case answer(Int)
    /// A page dot, by the place of its ask among the session's.
    case page(Int)
    case ignore, snooze, open
    /// The sending line's Undo.
    case undo
}

/// How the drawing sets the asks panel's words, which the layout leaves room for: the lines an ask's title wraps to
/// across the asks panel, at most three, and how wide words are in its foot's type.
public struct AsksMeasure: Sendable {
    public var titleLines: @Sendable (String) -> Int
    public var footWidth: @Sendable (String) -> Double

    public init(titleLines: @escaping @Sendable (String) -> Int, footWidth: @escaping @Sendable (String) -> Double) {
        self.titleLines = titleLines
        self.footWidth = footWidth
    }

    /// A rough measure, for a run that no drawing measures for: a title's line for each 40 characters, and 7 a
    /// character in the foot.
    public static let estimated = AsksMeasure(
        titleLines: { min(AsksLayout.titleMost, max(1, ($0.count + 39) / 40)) }, footWidth: { Double($0.count) * 7 }
    )
}

/// Where the asks panel lays out one ask, the same in black and in glass (Paper's board F): its top line, the session's
/// name and project and its page dots; the ask's title and its age; its answers' rows, none for an ask Lee answers in
/// Claude; and its foot, Ignore, Snooze ▾ and Open in Claude, which the sending line takes the place of while an
/// answer is held. Every box is in the asks panel's own frame, from its top left, 372 wide.
public struct AsksLayout: Equatable, Sendable {
    public static let width = 372.0, radius = 24.0
    /// How far it overlaps the list's front, on top of it, and how far its top stands above its row's.
    public static let overlap = 8.0, above = 12.0
    /// How far inside the screen's visible frame it keeps.
    public static let spare = 8.0
    static let padTop = 12.0, padSide = 12.0, padBottom = 14.0, between = 14.0
    /// Its rows' width, inside its sides.
    public static let inner = width - 2 * padSide
    static let topHeight = 28.0, topPadTop = 4.0
    /// The top line's and the ask's words stand this far in from the rows' sides.
    public static let textSide = 10.0
    public static let textLine = 16.0
    public static let titleLine = 22.0, titleMost = 3
    static let ageGap = 4.0
    public static let answerHeight = 38.0, answerRadius = 11.0
    static let answerGap = 6.0
    static let footHeight = 28.0, footPadLeft = 2.0, footGap = 2.0
    /// A foot's button's room round its words; the outlined pills', Open in Claude's and Undo's.
    public static let buttonPad = 8.0, pillHeight = 26.0, pillRadius = 13.0
    public static let openPad = 12.0, undoPad = 10.0
    /// Between Snooze and its chevron, and Open in Claude and its ↗.
    public static let wordsGap = 5.0
    public static let snoozeChevron = CGSize(width: 8, height: 5)
    /// The countdown's ring, and the room after it.
    public static let ring = 12.0, ringGap = 6.0

    /// The words the foot sets, which its buttons are as wide as.
    public static let ignoreWords = "Ignore", snoozeWords = "Snooze", openWords = "Open in Claude", openMark = "↗"
    public static let undoWords = "Undo"

    /// The top line's words: the session's name and project at the left, page dots at the right.
    public let top: CGRect
    public let title: CGRect
    public let titleLines: Int
    public let age: CGRect
    /// Each answer's row; none for an ask Lee answers in Claude.
    public let answers: [CGRect]
    public let foot: CGRect
    public let ignore, snooze, open: CGRect
    public let countdown: CGRect
    /// The sending line's words: "Sending" and the answer, or "Ignoring".
    public let sending: CGRect
    public let undo: CGRect
    public let height: Double

    /// One ask laid out, its title and its foot's words set as `measure` measures them.
    public init(_ ask: PanelAsk, measure: AsksMeasure) {
        let side = Self.padSide, text = side + Self.textSide, textWidth = Self.inner - 2 * Self.textSide
        let lines = min(Self.titleMost, max(1, measure.titleLines(ask.title)))
        let askTop = Self.padTop + Self.topHeight + Self.between
        let rows = ask.answers.count
        let answersTop = askTop + Double(lines) * Self.titleLine + Self.ageGap + Self.textLine + Self.between
        let answersHeight = Double(rows) * Self.answerHeight + Double(max(0, rows - 1)) * Self.answerGap
        let footTop = answersTop + (rows == 0 ? 0 : answersHeight + Self.between)
        let pillTop = footTop + (Self.footHeight - Self.pillHeight) / 2
        let right = side + Self.inner
        let word = { (words: String) in measure.footWidth(words) }

        top = CGRect(
            x: text, y: Self.padTop + Self.topPadTop, width: textWidth, height: Self.topHeight - Self.topPadTop
        )
        title = CGRect(x: text, y: askTop, width: textWidth, height: Double(lines) * Self.titleLine)
        titleLines = lines
        age = CGRect(x: text, y: title.maxY + Self.ageGap, width: textWidth, height: Self.textLine)
        answers = (0 ..< rows).map { row in
            CGRect(
                x: side, y: answersTop + Double(row) * (Self.answerHeight + Self.answerGap), width: Self.inner,
                height: Self.answerHeight
            )
        }
        foot = CGRect(x: side, y: footTop, width: Self.inner, height: Self.footHeight)
        ignore = CGRect(
            x: side + Self.footPadLeft, y: footTop, width: 2 * Self.buttonPad + word(Self.ignoreWords),
            height: Self.footHeight
        )
        snooze = CGRect(
            x: ignore.maxX + Self.footGap, y: footTop,
            width: 2 * Self.buttonPad + word(Self.snoozeWords) + Self.wordsGap + Self.snoozeChevron.width,
            height: Self.footHeight
        )

        let openWidth = 2 * Self.openPad + word(Self.openWords) + Self.wordsGap + word(Self.openMark)
        let undoWidth = 2 * Self.undoPad + word(Self.undoWords)

        open = CGRect(x: right - openWidth, y: pillTop, width: openWidth, height: Self.pillHeight)
        countdown = CGRect(
            x: text, y: footTop + (Self.footHeight - Self.ring) / 2, width: Self.ring, height: Self.ring
        )
        undo = CGRect(x: right - undoWidth, y: pillTop, width: undoWidth, height: Self.pillHeight)

        let sendingX = countdown.maxX + Self.ringGap

        sending = CGRect(
            x: sendingX, y: footTop + (Self.footHeight - Self.textLine) / 2,
            width: max(0, undo.minX - Self.textSide - sendingX), height: Self.textLine
        )
        height = foot.maxY + Self.padBottom
    }

    public var size: CGSize { CGSize(width: Self.width, height: height) }

    /// What a click at a point in its own frame lands on, showing the ask at `page` of `pages`: a page dot, which
    /// pages whatever is held; while an answer of its ask is held, Undo alone.
    public func part(at point: CGPoint, sending: Bool, page: Int, of pages: Int) -> AsksPart? {
        if let dot = dot(at: point, page: page, of: pages) {
            return .page(dot)
        }
        if sending {
            return undo.contains(point) ? .undo : nil
        }
        if let row = answers.firstIndex(where: { $0.contains(point) }) {
            return .answer(row)
        }
        if ignore.contains(point) {
            return .ignore
        }
        if snooze.contains(point) {
            return .snooze
        }
        return open.contains(point) ? .open : nil
    }

    /// The page dots at the top line's right, showing the ask at `page` of `pages`, the current one wide; none for one
    /// ask.
    public func dots(page: Int, of pages: Int) -> [CGRect] {
        guard pages > 1 else {
            return []
        }

        var x = top.maxX - Self.dotsWidth(pages)

        return (0 ..< pages).map { index in
            let width = index == page ? Self.currentDot : Self.dotSide
            let dot = CGRect(x: x, y: top.midY - Self.dotSide / 2, width: width, height: Self.dotSide)

            x += width + Self.dotGap
            return dot
        }
    }

    /// The dot a click at a point in its own frame is nearest across the dots and `dotReach` past either end, the top
    /// line's whole height: a dot 5 wide is no target to aim at (DESIGN, "Paging").
    private func dot(at point: CGPoint, page: Int, of pages: Int) -> Int? {
        let dots = dots(page: page, of: pages)

        guard let first = dots.first, let last = dots.last else {
            return nil
        }

        let reach = CGRect(
            x: first.minX - Self.dotReach, y: Self.padTop, width: last.maxX - first.minX + 2 * Self.dotReach,
            height: Self.topHeight
        )

        return reach.contains(point)
            ? dots.indices.min { Self.across(point.x, dots[$0]) < Self.across(point.x, dots[$1]) } : nil
    }

    /// How far a point across is from a box: none inside it.
    private static func across(_ x: Double, _ box: CGRect) -> Double {
        max(0, box.minX - x, x - box.maxX)
    }

    /// The page dots: 5 across, the current one 14, 4 apart; and how far past the first and the last a click is theirs.
    public static let dotSide = 5.0, currentDot = 14.0, dotGap = 4.0, dotReach = 6.0

    static func dotsWidth(_ pages: Int) -> Double {
        currentDot + Double(pages - 1) * (dotSide + dotGap)
    }

    /// Where it stands on the stage beside a row whose top is this far down it, in a list whose front is this far from
    /// the edge: past the front, overlapping it, its top line level with the row's, and moved just enough to keep
    /// inside the screen's visible frame, as a Mac submenu is.
    public func frame(besideRowAt rowTop: Double, front: Double, on stage: Stage) -> CGRect {
        let highest = stage.visibleTop + Self.spare
        let lowest = max(highest, stage.visibleBottom - Self.spare - height)

        return CGRect(
            x: front - Self.overlap, y: clamp(rowTop - Self.above, highest, lowest), width: Self.width, height: height
        )
    }

    /// How far from the edge the asks panel and its shadow reach, beside the open panel: what its window must hold.
    public static let reach = Tuning.panelDepth - overlap + width + 40

    /// An answer's row's keycap, its number or ↗ on it, and where its label and "recommended" go, in the row's frame.
    public static let keycap = CGRect(x: 10, y: 9, width: 20, height: 20)
    public static let keycapRadius = 6.0
    public static let labelX = 40.0, labelLine = 18.0, rowSide = 10.0, recommendedGap = 10.0
}

/// A Needs you row's arrow (DESIGN, "The row's arrow"): a button 40 by 26 at the row's right end, in its time's place,
/// 3 in from the row's lift, on its middle.
public enum RowArrow {
    public static let size = CGSize(width: 40, height: 26)
    public static let radius = 8.0, inset = 3.0
    /// How long, in seconds, its chevron takes to turn as its asks panel opens or closes.
    public static let turning = 0.2

    /// Its box in a row this big, in the row's own frame.
    public static func box(in row: CGSize) -> CGRect {
        CGRect(
            x: row.width - inset - size.width, y: (row.height - size.height) / 2, width: size.width,
            height: size.height
        )
    }

    /// Its chevron, 6 by 10, centred in the box's own frame, pointing right, or left, away from the screen's edge on
    /// the right.
    public static func chevron(pointsLeft: Bool) -> CGPath {
        let path = CGMutablePath()
        let origin = CGPoint(x: (size.width - 6) / 2, y: (size.height - 10) / 2)
        let points = [CGPoint(x: 1.2, y: 1.2), CGPoint(x: 4.8, y: 5), CGPoint(x: 1.2, y: 8.8)]

        path.addLines(between: points.map { CGPoint(x: origin.x + (pointsLeft ? 6 - $0.x : $0.x), y: origin.y + $0.y) })
        return path
    }
}
