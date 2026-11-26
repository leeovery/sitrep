import AppKit
import SitRepEdge
import SitRepPanel

/// Where the asks panel draws its words and marks inside its layout's boxes: the top line's name, project and page
/// dots, the title's lines, an answer's label and its "recommended", the foot's words, Snooze's chevron, the held
/// answer's check, and the pills' words.
@MainActor
enum AsksPanelParts {
    /// The top line's words: the session's name, kept whole first, 8 before its project, which ends before its page
    /// dots (`dots`).
    struct Top {
        let name: CGRect
        let project: CGRect
    }

    /// A page dot, and how much of the current one it is, 1 for the ask shown at rest, passing to the next as its
    /// asks slide.
    struct Dot {
        let box: CGRect
        let current: Double
    }

    static func top(_ asks: AsksShown) -> Top {
        let box = asks.layout.top, line = AsksLayout.textLine, gap = 8.0, y = box.midY - line / 2
        let firstDot = asks.layout.dots(page: asks.page, of: asks.pages).first
        let room = (firstDot.map { $0.minX - gap } ?? box.maxX) - box.minX
        let whole = TextLine.width(TextLine.text(asks.session.name, EdgeStyle.asksName, EdgeStyle.ink))
        let projectX = box.minX + min(whole, room) + gap

        return Top(
            name: CGRect(x: box.minX, y: y, width: min(whole + Self.slack, room), height: line),
            project: CGRect(x: projectX, y: y, width: max(0, box.minX + room - projectX), height: line)
        )
    }

    /// The page dots at the top line's right where the session has more than one ask, the current one wide, as far as
    /// its asks have slid: their run as long throughout, so the words before them never move.
    static func dots(_ asks: AsksShown) -> [Dot] {
        asks.layout.dots(at: asks.progress, of: asks.pages).enumerated().map { index, box in
            Dot(box: box, current: AsksLayout.nearness(of: index, to: asks.progress))
        }
    }

    /// Room past words set whole in a box as wide as Core Text sets them, which SwiftUI may set a hair wider and cut.
    private static let slack = 1.0

    static let dotRadius = 3.0

    /// The ask's title in this colour, broken into the lines the layout left room for, each with its box, with the
    /// slack past it that words set whole take.
    static func titleLines(_ asks: AsksShown, colour: CGColor) -> [(text: NSAttributedString, box: CGRect)] {
        let layout = asks.layout, box = layout.title
        let title = TextLine.text(asks.ask.title, EdgeStyle.asksTitle, colour, kern: EdgeStyle.asksTitleKern)

        return TextLine.wrapped(title, width: box.width, most: layout.titleLines).enumerated().map { index, line in
            (line, CGRect(
                x: box.minX, y: box.minY + Double(index) * AsksLayout.titleLine, width: box.width + Self.slack,
                height: AsksLayout.titleLine
            ))
        }
    }

    /// An answer's row as it shows (Paper's board H3): Claude's pick, in lilac, or not; its ground, held, lifted
    /// under the pointer, or filled; and the number its keycap shows, while it shows one (DESIGN, "Keys").
    struct AnswerRow: Equatable {
        enum Ground {
            /// The answer held.
            case held
            /// Under the pointer.
            case lifted
            case filled
        }

        let ground: Ground
        let isPick: Bool
        let number: Int?

        var isHeld: Bool { ground == .held }
    }

    /// An answer's row as it shows: numbered while the asks panel shows keycaps, the first nine alone.
    static func answerRow(_ index: Int, of asks: AsksShown) -> AnswerRow {
        let isHeld = asks.sending.map { $0.row == index } ?? false
        let ground: AnswerRow.Ground = isHeld ? .held : asks.hover == .answer(index) ? .lifted : .filled

        return AnswerRow(
            ground: ground, isPick: asks.ask.answers[index] == asks.ask.recommended,
            number: asks.keycaps && index < AsksLayout.keycapsMost ? index + 1 : nil
        )
    }

    /// One line of an answer's words on its row, and Claude's pick's tag after them where it falls on this line.
    struct AnswerLine: Equatable {
        let words: String
        let tag: String?
    }

    /// Claude's pick's tag after its words, and on a line of its own.
    static let pickTag = "  ·  Recommended", pickTagAlone = "Recommended"

    /// An answer's lines on its row as they show, each with its box in the row's frame and the slack past it that
    /// words set whole take: across the row short of its keycap's room, held or not, keycaps or none, on no more lines
    /// than the layout left it, so the row keeps its height and its words their lines. A tag on a line of its own is
    /// lowered onto the words' baseline.
    static func answerLines(_ index: Int, of asks: AsksShown) -> [(line: AnswerLine, box: CGRect)] {
        let row = asks.layout.answers[index].size, shows = answerRow(index, of: asks)
        let lines = answerLines(
            asks.ask.answers[index], isPick: shows.isPick, width: AsksLayout.answerWidth,
            most: asks.layout.answerLines[index]
        )
        let boxes = AsksLayout.answerBoxes(in: row, lines: lines.count)

        return zip(lines, boxes).map { line, box in
            let drop = line.words.isEmpty
                ? TextLine.drop(of: EdgeStyle.asksNote, to: EdgeStyle.asksLabel, lineHeight: box.height) : 0

            return (line, CGRect(x: box.minX, y: box.minY + drop, width: box.width + Self.slack, height: box.height))
        }
    }

    /// An answer's words wrapped to `width`, on `most` lines at most, the last cut short with "…" where they run past
    /// it; Claude's pick's tag after its words on their last line, else alone on the line after while there is one,
    /// else after its words cut short before it, so it always shows (Paper's board H3).
    static func answerLines(_ answer: String, isPick: Bool, width: Double, most: Int) -> [AnswerLine] {
        let ranges = breaks(answer, width: width), words = answer as NSString
        let lines = ranges.map { trimmed(words.substring(with: $0)) }

        guard !lines.isEmpty else {
            return []
        }

        let tagWidth = isPick ? Self.width(of: pickTag, EdgeStyle.asksNote) : 0
        let tag = isPick ? pickTag : nil

        if lines.count <= most, let last = lines.last, answerWidth(last) + tagWidth <= width {
            return lines.dropLast().map { AnswerLine(words: $0, tag: nil) } + [AnswerLine(words: last, tag: tag)]
        }
        if isPick, lines.count < most {
            return lines.map { AnswerLine(words: $0, tag: nil) } + [AnswerLine(words: "", tag: pickTagAlone)]
        }

        // Core Text's breaks and the trimmed lines' re-measure can disagree, as in mixed right-to-left words, so a
        // last line can land here short of `most`: keeping at most all but the last keeps the index in range.
        let kept = lines.prefix(min(most, lines.count) - 1).map { AnswerLine(words: $0, tag: nil) }
        let rest = words.substring(from: ranges[kept.count].location)

        return kept + [AnswerLine(words: cut(rest, to: width - tagWidth), tag: tag)]
    }

    /// The ranges of an answer's lines, broken where Core Text breaks them across `width`.
    private static func breaks(_ answer: String, width: Double) -> [NSRange] {
        let text = answerText(answer, colour: EdgeStyle.ink)
        let typesetter = CTTypesetterCreateWithAttributedString(text)
        var ranges: [NSRange] = [], start = 0

        while start < text.length {
            let count = max(1, CTTypesetterSuggestLineBreak(typesetter, start, width))

            ranges.append(NSRange(location: start, length: count))
            start += count
        }
        return ranges
    }

    /// Words cut short to fit `width`, an ellipsis after the most of them that fit with it; whole where they fit.
    private static func cut(_ words: String, to width: Double) -> String {
        let whole = trimmed(words)

        guard answerWidth(whole) > width else {
            return whole
        }

        let characters = Array(whole)
        var fits = 0, over = characters.count

        while over - fits > 1 {
            let middle = (fits + over) / 2

            if answerWidth(Self.ellipsized(characters.prefix(middle))) <= width {
                fits = middle
            } else {
                over = middle
            }
        }
        return ellipsized(characters.prefix(fits))
    }

    private static func ellipsized(_ characters: ArraySlice<Character>) -> String {
        trimmed(String(characters)) + "…"
    }

    private static func trimmed(_ words: String) -> String {
        String(words.reversed().drop { $0.isWhitespace }.reversed())
    }

    /// An answer's words as they are set: 13 medium, spaced at -0.01em.
    static func answerText(_ words: String, colour: CGColor) -> NSMutableAttributedString {
        TextLine.text(words, EdgeStyle.asksLabel, colour, kern: EdgeStyle.tightKern(EdgeStyle.asksLabel))
    }

    private static func answerWidth(_ words: String) -> Double {
        TextLine.width(answerText(words, colour: EdgeStyle.ink))
    }

    private static func width(of words: String, _ font: NSFont) -> Double {
        TextLine.width(TextLine.text(words, font, EdgeStyle.ink))
    }

    /// A foot button's words, inside its padding on its middle.
    static func footWords(in box: CGRect) -> CGRect {
        let line = AsksLayout.textLine

        return CGRect(x: box.minX + AsksLayout.buttonPad, y: box.midY - line / 2, width: box.width, height: line)
    }

    /// Snooze's chevron, pointing down, after its words: its box, and its path in the box's own frame.
    static func snoozeChevron(in box: CGRect) -> (box: CGRect, path: CGPath) {
        let size = AsksLayout.snoozeChevron, scale = size.width / 10
        let path = CGMutablePath()

        path.addLines(between: [CGPoint(x: 1.2, y: 1.2), CGPoint(x: 5, y: 4.8), CGPoint(x: 8.8, y: 1.2)].map {
            CGPoint(x: $0.x * scale, y: $0.y * scale)
        })
        return (
            CGRect(
                x: box.maxX - AsksLayout.buttonPad - size.width, y: box.midY - size.height / 2, width: size.width,
                height: size.height
            ),
            path
        )
    }

    /// The held answer's check, 11 across, in its keycap's room (`AsksLayout.check`), in a row this big whose words
    /// wrap to `lines`: its box in the row's frame, its path in the box's.
    static func check(in row: CGSize, lines: Int) -> (box: CGRect, path: CGPath) {
        let path = CGMutablePath()

        path.addLines(between: [CGPoint(x: 2, y: 5.8), CGPoint(x: 4.4, y: 8.2), CGPoint(x: 9, y: 3)])
        return (AsksLayout.check(in: row, lines: lines), path)
    }

    /// A keycap's number, 11 semibold in the soft grey, centred in the keycap: its words, and their box in the
    /// keycap's frame.
    static func keycapNumber(_ number: Int) -> (text: NSAttributedString, box: CGRect) {
        let text = TextLine.text("\(number)", EdgeStyle.asksKeycap, EdgeStyle.ink2)
        let width = TextLine.width(text) + Self.slack, side = AsksLayout.keycapSide, line = AsksLayout.textLine

        return (text, CGRect(x: (side - width) / 2, y: (side - line) / 2, width: width, height: line))
    }

    static let checkWidth = 1.6, strokeWidth = 1.5

    /// Open in Claude's words and its ↗ after them, in the pill's own frame.
    static func openWords(in pill: CGSize) -> (words: CGRect, mark: CGRect) {
        let line = AsksLayout.textLine, y = (pill.height - line) / 2
        let words = TextLine.width(TextLine.text(AsksLayout.openWords, EdgeStyle.asksFoot, EdgeStyle.ink))
        let markX = AsksLayout.openPad + words + AsksLayout.wordsGap
        let mark = TextLine.width(TextLine.text(AsksLayout.openMark, EdgeStyle.asksFoot, EdgeStyle.ink2))

        return (
            CGRect(x: AsksLayout.openPad, y: y, width: pill.width, height: line),
            CGRect(x: markX, y: y, width: mark + Self.slack, height: line)
        )
    }

    /// Undo's word, in the pill's own frame.
    static func undoWords(in pill: CGSize) -> CGRect {
        let line = AsksLayout.textLine

        return CGRect(x: AsksLayout.undoPad, y: (pill.height - line) / 2, width: pill.width, height: line)
    }

    /// What the sending line says before the answer's words: "Sending", or "Ignoring" for an ignore, which has none.
    static func sendingLead(_ sending: Sending) -> String {
        sending.words == nil ? "Ignoring" : "Sending "
    }
}

/// The asks panel's two shadows, as a submenu's: 14 down blurred 36 at 65%, and toward the list, 4 across blurred 12
/// at 50%. Core Animation's radius, and SwiftUI's, halve the CSS blur.
enum AsksShadow {
    struct Cast {
        let offset: CGSize
        let radius: Double
        let opacity: Double
    }

    static func casts(pointsLeft: Bool) -> [Cast] {
        [
            Cast(offset: CGSize(width: 0, height: 14), radius: 18, opacity: Double(0xA6) / 255),
            Cast(offset: CGSize(width: pointsLeft ? 4 : -4, height: 0), radius: 6, opacity: Double(0x80) / 255),
        ]
    }
}

/// The countdown of an answer held: a track, and over it an arc from 12 o'clock running down from full to nothing as
/// the answer's two seconds run out, in the render server from what is left at the time it is told.
@MainActor
final class CountdownRing {
    let track = CAShapeLayer()
    let arc = CAShapeLayer()

    init(in box: CGRect) {
        let centre = CGPoint(x: box.width / 2, y: box.height / 2), circle = CGMutablePath()

        circle.addArc(center: centre, radius: 4.75, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: false)
        for shape in [track, arc] {
            shape.frame = box
            shape.path = circle
            shape.fillColor = nil
            shape.lineWidth = AsksPanelParts.strokeWidth
            shape.lineCap = .round
            shape.lineJoin = .round
        }
    }

    /// The arc as much of it as is left of the answer's two seconds at `now` on the wall clock, running down to none.
    func count(_ sending: Sending, at now: Double) {
        let left = sending.left(at: now)
        let run = CABasicAnimation(keyPath: "strokeEnd")

        arc.strokeEnd = left
        arc.removeAnimation(forKey: Self.key)
        run.fromValue = left
        run.toValue = 0
        run.duration = left * (sending.goesAt - sending.heldAt) / 1000
        run.fillMode = .forwards
        run.isRemovedOnCompletion = false
        if run.duration > 0 {
            arc.add(run, forKey: Self.key)
        }
    }

    private static let key = "countdown"
}

extension AsksMeasure {
    /// How the asks panel's words are set, for the run to lay it out: its title's lines,
    /// its answers' lines, and its foot's words' widths.
    nonisolated static let drawn = AsksMeasure(
        titleLines: { title in
            MainActor.assumeIsolated {
                let text = TextLine.text(title, EdgeStyle.asksTitle, EdgeStyle.ink, kern: EdgeStyle.asksTitleKern)
                let width = AsksLayout.inner - 2 * AsksLayout.textSide

                return max(1, TextLine.wrapped(text, width: width, most: AsksLayout.titleMost).count)
            }
        },
        answerLines: { answer, isPick in
            MainActor.assumeIsolated {
                AsksPanelParts.answerLines(
                    answer, isPick: isPick, width: AsksLayout.answerWidth, most: AsksLayout.answerMost
                ).count
            }
        },
        footWidth: { words in
            MainActor.assumeIsolated { TextLine.width(TextLine.text(words, EdgeStyle.asksFoot, EdgeStyle.ink)) }
        }
    )
}
