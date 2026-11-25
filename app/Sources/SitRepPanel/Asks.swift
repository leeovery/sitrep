import CoreGraphics
import Foundation

/// An ask as the asks panel answers it (DESIGN, "Answering from the panel"): its title, the answers it offers as the
/// board lists them, a yes's one or a choice's options, Claude's pick first, and the one Claude recommends; none for a
/// words ask, or a choice with no options, which Lee answers in Claude. Its time is its line's on the row: its
/// posting, or its reopening.
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
/// across the asks panel, at most three; the lines an answer wraps to across its row, at most two, Claude's pick's
/// with its tag after it; and how wide words are in its foot's type.
public struct AsksMeasure: Sendable {
    public var titleLines: @Sendable (String) -> Int
    public var answerLines: @Sendable (_ answer: String, _ isPick: Bool) -> Int
    public var footWidth: @Sendable (String) -> Double

    public init(
        titleLines: @escaping @Sendable (String) -> Int,
        answerLines: @escaping @Sendable (_ answer: String, _ isPick: Bool) -> Int = { _, _ in 1 },
        footWidth: @escaping @Sendable (String) -> Double
    ) {
        self.titleLines = titleLines
        self.answerLines = answerLines
        self.footWidth = footWidth
    }

    /// A rough measure, for a run that no drawing measures for: a title's line for each 40 characters, an answer's for
    /// each 45, its pick's tag counting 16, and 7 a character in the foot.
    public static let estimated = AsksMeasure(
        titleLines: { min(AsksLayout.titleMost, max(1, ($0.count + 39) / 40)) },
        answerLines: { min(AsksLayout.answerMost, max(1, ($0.count + ($1 ? 16 : 0) + 44) / 45)) },
        footWidth: { Double($0.count) * 7 }
    )
}

/// Where the asks panel lays out one ask (Paper's boards F and H3): its top line, the session's name and project and
/// its page dots; the ask's title and its age; its answers' rows, each as tall as the lines its words wrap to, none for
/// an ask Lee answers in Claude; and its foot, Ignore, Snooze ▾ where Snooze offers a time, and Open in Claude, which
/// the sending line takes the place of while an answer is held. Every box is in the asks panel's own frame, from its
/// top left, 372 wide.
public struct AsksLayout: Equatable, Sendable {
    public static let width = 372.0, radius = 24.0
    /// How far it overlaps the list's front, on top of it, and how far its top stands above its row's.
    public static let overlap = 8.0, above = 12.0
    /// How far inside the screen's visible frame it keeps.
    public static let spare = 8.0
    static let padTop = 12.0, padSide = 12.0, padBottom = 14.0
    /// Between its parts: the top line, the ask, its answers and its foot.
    public static let between = 14.0
    /// Its rows' width, inside its sides.
    public static let inner = width - 2 * padSide
    static let topHeight = 28.0, topPadTop = 4.0
    /// The top line's and the ask's words stand this far in from the rows' sides.
    public static let textSide = 10.0
    public static let textLine = 16.0
    public static let titleLine = 22.0, titleMost = 3
    static let ageGap = 4.0
    /// An answer's row: at least 38 tall, its words 12 in from its sides and 9 from its top and bottom, on lines of 18,
    /// two at most.
    public static let answerHeight = 38.0, answerRadius = 11.0
    public static let answerPadSide = 12.0, answerPadTop = 9.0, answerLine = 18.0, answerMost = 2
    /// How wide an answer's words are set across its row.
    public static let answerWidth = inner - 2 * answerPadSide
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
    /// The lines each answer's words wrap to on its row.
    public let answerLines: [Int]
    public let foot: CGRect
    public let ignore, open: CGRect
    /// None while Snooze offers no time, as Lee switched every one off, or each has passed for today.
    public let snooze: CGRect?
    public let countdown: CGRect
    /// The sending line's words: "Sending" and the answer, or "Ignoring".
    public let sending: CGRect
    public let undo: CGRect
    public let height: Double

    /// One ask laid out, its title, its answers and its foot's words set as `measure` measures them, Snooze ▾ in its
    /// foot where it `offersSnooze`.
    public init(_ ask: PanelAsk, measure: AsksMeasure, offersSnooze: Bool = true) {
        let side = Self.padSide, text = side + Self.textSide, textWidth = Self.inner - 2 * Self.textSide
        let lines = min(Self.titleMost, max(1, measure.titleLines(ask.title)))
        let askTop = Self.padTop + Self.topHeight + Self.between
        let answersTop = askTop + Double(lines) * Self.titleLine + Self.ageGap + Self.textLine + Self.between
        let answerLines = ask.answers.map { answer in
            min(Self.answerMost, max(1, measure.answerLines(answer, answer == ask.recommended)))
        }
        let answers = Self.rows(answerLines, from: answersTop)
        let footTop = answers.last.map { $0.maxY + Self.between } ?? answersTop
        let pillTop = footTop + (Self.footHeight - Self.pillHeight) / 2
        let right = side + Self.inner
        let word = { (words: String) in measure.footWidth(words) }

        top = CGRect(
            x: text, y: Self.padTop + Self.topPadTop, width: textWidth, height: Self.topHeight - Self.topPadTop
        )
        title = CGRect(x: text, y: askTop, width: textWidth, height: Double(lines) * Self.titleLine)
        titleLines = lines
        age = CGRect(x: text, y: title.maxY + Self.ageGap, width: textWidth, height: Self.textLine)
        self.answers = answers
        self.answerLines = answerLines
        foot = CGRect(x: side, y: footTop, width: Self.inner, height: Self.footHeight)
        ignore = CGRect(
            x: side + Self.footPadLeft, y: footTop, width: 2 * Self.buttonPad + word(Self.ignoreWords),
            height: Self.footHeight
        )
        snooze = offersSnooze ? CGRect(
            x: ignore.maxX + Self.footGap, y: footTop,
            width: 2 * Self.buttonPad + word(Self.snoozeWords) + Self.wordsGap + Self.snoozeChevron.width,
            height: Self.footHeight
        ) : nil

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

    /// The answers' rows from this far down, each as tall as its lines with their room above and below, 38 at least,
    /// 6 apart.
    private static func rows(_ lines: [Int], from top: Double) -> [CGRect] {
        var y = top

        return lines.map { lines in
            let height = max(answerHeight, 2 * answerPadTop + Double(lines) * answerLine)
            let row = CGRect(x: padSide, y: y, width: inner, height: height)

            y = row.maxY + answerGap
            return row
        }
    }

    /// What a click at a point in its own frame lands on, showing the ask at `page` of `pages`: a page dot, which
    /// pages whatever is held; while an answer of its ask is held, Undo alone.
    public func part(at point: CGPoint, sending: Bool, page: Int, of pages: Int) -> AsksPart? {
        part(at: point, sending: sending, progress: Double(page), of: pages)
    }

    /// What a click lands on (above), its page dots standing as a slide between two asks has come to `progress`
    /// (`dots(at:of:)`): a click on a dot lands on the dot drawn there.
    public func part(at point: CGPoint, sending: Bool, progress: Double, of pages: Int) -> AsksPart? {
        if let dot = dot(at: point, progress: progress, of: pages) {
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
        if snooze?.contains(point) == true {
            return .snooze
        }
        return open.contains(point) ? .open : nil
    }

    /// The page dots at the top line's right, showing the ask at `page` of `pages`, the current one wide; none for one
    /// ask.
    public func dots(page: Int, of pages: Int) -> [CGRect] {
        dots(at: Double(page), of: pages)
    }

    /// The page dots as a slide between two asks has come to `progress`, a page and a share of the way to the next
    /// (DESIGN, "Paging"): each as wide as it is near it, the wide one passing from dot to dot, their run as long
    /// throughout.
    public func dots(at progress: Double, of pages: Int) -> [CGRect] {
        guard pages > 1 else {
            return []
        }

        var x = top.maxX - Self.dotsWidth(pages)

        return (0 ..< pages).map { index in
            let width = Self.dotSide + (Self.currentDot - Self.dotSide) * Self.nearness(of: index, to: progress)
            let dot = CGRect(x: x, y: top.midY - Self.dotSide / 2, width: width, height: Self.dotSide)

            x += width + Self.dotGap
            return dot
        }
    }

    /// How near a dot is to a slide's progress, 1 on it, 0 a page or more from it: how much of the current dot it is.
    public static func nearness(of dot: Int, to progress: Double) -> Double {
        max(0, 1 - abs(progress - Double(dot)))
    }

    /// The dot a click at a point in its own frame is nearest across the dots and `dotReach` past either end, the top
    /// line's whole height: a dot 5 wide is no target to aim at (DESIGN, "Paging").
    private func dot(at point: CGPoint, progress: Double, of pages: Int) -> Int? {
        let dots = dots(at: progress, of: pages)

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
    /// the edge, as tall as this ask, or as `height` while a slide takes it between two asks': past the front,
    /// overlapping it, its top line level with the row's, and moved just enough to keep inside the screen's visible
    /// frame, as a Mac submenu is.
    public func frame(besideRowAt rowTop: Double, front: Double, on stage: Stage, height: Double? = nil) -> CGRect {
        frame(besideRowAt: rowTop, front: front, within: stage.visibleTop ... stage.visibleBottom, height: height)
    }

    /// Where it stands on the stage beside a row, as `frame(besideRowAt:front:on:height:)` places it, kept inside
    /// `visible`, from the highest it may stand on the stage to the lowest.
    public func frame(
        besideRowAt rowTop: Double, front: Double, within visible: ClosedRange<Double>, height: Double? = nil
    ) -> CGRect {
        let height = height ?? self.height
        let highest = visible.lowerBound + Self.spare
        let lowest = max(highest, visible.upperBound - Self.spare - height)

        return CGRect(
            x: front - Self.overlap, y: clamp(rowTop - Self.above, highest, lowest), width: Self.width, height: height
        )
    }

    /// How far from the edge the asks panel and its shadow reach, beside the open panel: what its window must hold.
    public static let reach = reach(beside: Tuning.panelDepth)

    /// How far from the edge the asks panel and its shadow reach beside a list whose front is this far from it.
    public static func reach(beside front: Double) -> Double {
        front - overlap + width + 40
    }

    /// Where an answer's lines go in a row this big, as many as it wraps to, on its middle.
    public static func answerBoxes(in row: CGSize, lines: Int) -> [CGRect] {
        let top = (row.height - Double(lines) * answerLine) / 2

        return (0 ..< lines).map { line in
            CGRect(
                x: answerPadSide, y: top + Double(line) * answerLine, width: row.width - 2 * answerPadSide,
                height: answerLine
            )
        }
    }

    /// The held answer's check, 11 across, at its row's trailing end on its middle, as a panel row's time is; and the
    /// room its words leave it there.
    public static let checkSide = 11.0, checkGap = 8.0

    public static func check(in row: CGSize) -> CGRect {
        CGRect(
            x: row.width - answerPadSide - checkSide, y: (row.height - checkSide) / 2, width: checkSide,
            height: checkSide
        )
    }
}

/// A Needs you row's arrow (DESIGN, "The row's arrow"), at the end of its row it points toward, where the asks panel
/// opens: on the left edge a button 40 by 26 at the row's right end, in its time's place, 3 in from the row's lift; on
/// the right edge 26 by 26 at its left end, in its dot's place, centred on the dot. Each on the row's middle. A strip's
/// tab has its arrow 40 by 26 at its front end on either edge, the tab's words making room for it.
public enum RowArrow {
    public static let size = CGSize(width: 40, height: 26)
    public static let radius = 8.0, inset = 3.0
    /// How far from a row's left its dot's centre stands, where the right edge's arrow stands (`SessionRowLayout`).
    public static let dotSlot = 16.0
    /// How long, in seconds, its chevron takes to turn as its asks panel opens or closes.
    public static let turning = 0.2

    /// Its box in a row this big, in the row's own frame, read left to right: at the row's right end, or pointing
    /// left, on the right edge, centred on its dot.
    public static func box(in row: CGSize, pointsLeft: Bool = false) -> CGRect {
        guard pointsLeft else {
            return tabBox(in: row, pointsLeft: false)
        }

        let side = size.height

        return CGRect(x: dotSlot - side / 2, y: (row.height - side) / 2, width: side, height: side)
    }

    /// Its box in a strip's tab's words this big, in their own frame, read left to right: at their end it points
    /// toward.
    public static func tabBox(in words: CGSize, pointsLeft: Bool) -> CGRect {
        CGRect(
            x: pointsLeft ? inset : words.width - inset - size.width, y: (words.height - size.height) / 2,
            width: size.width, height: size.height
        )
    }

    /// Its chevron, 6 by 10, centred in a box this big, in the box's own frame, pointing right, or left, away from the
    /// screen's edge on the right.
    public static func chevron(pointsLeft: Bool, in box: CGSize = size) -> CGPath {
        let path = CGMutablePath()
        let origin = CGPoint(x: (box.width - 6) / 2, y: (box.height - 10) / 2)
        let points = [CGPoint(x: 1.2, y: 1.2), CGPoint(x: 4.8, y: 5), CGPoint(x: 1.2, y: 8.8)]

        path.addLines(between: points.map { CGPoint(x: origin.x + (pointsLeft ? 6 - $0.x : $0.x), y: origin.y + $0.y) })
        return path
    }
}
