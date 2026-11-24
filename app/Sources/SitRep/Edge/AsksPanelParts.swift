import AppKit
import SitRepEdge
import SitRepPanel

/// Where the asks panel draws its words and marks inside its layout's boxes, the same in black and in glass, which
/// differ only in what they fill and colour them with: the top line's name, project and page dots, the title's lines,
/// an answer's label and its "recommended", the foot's words, Snooze's chevron, the held answer's check, and the
/// pills' words.
@MainActor
enum AsksPanelParts {
    /// The top line: the session's name, kept whole first, 8 before its project; and its page dots at its right where
    /// the session has more than one ask, the current one wide.
    struct Top {
        let name: CGRect
        let project: CGRect
        let dots: [Dot]
    }

    struct Dot {
        let box: CGRect
        let isCurrent: Bool
    }

    static func top(_ asks: AsksShown) -> Top {
        let box = asks.layout.top, line = AsksLayout.textLine, gap = 8.0, y = box.midY - line / 2
        let dots = asks.pages > 1 ? Self.dots(asks.page, of: asks.pages, right: box.maxX, middle: box.midY) : []
        let room = box.width - (dots.isEmpty ? 0 : dotsWidth(asks.pages) + gap)
        let nameWidth = min(TextLine.width(TextLine.text(asks.session.name, EdgeStyle.asksName, EdgeStyle.ink)), room)
        let projectX = box.minX + nameWidth + gap

        return Top(
            name: CGRect(x: box.minX, y: y, width: nameWidth, height: line),
            project: CGRect(x: projectX, y: y, width: max(0, box.minX + room - projectX), height: line),
            dots: dots
        )
    }

    private static let dotGap = 4.0, dotSide = 5.0, currentDot = 14.0
    static let dotRadius = 3.0

    private static func dotsWidth(_ pages: Int) -> Double {
        currentDot + Double(pages - 1) * (dotSide + dotGap)
    }

    private static func dots(_ page: Int, of pages: Int, right: Double, middle: Double) -> [Dot] {
        var x = right - dotsWidth(pages)

        return (0 ..< pages).map { index in
            let width = index == page ? currentDot : dotSide
            let dot = Dot(
                box: CGRect(x: x, y: middle - dotSide / 2, width: width, height: dotSide), isCurrent: index == page
            )

            x += width + dotGap
            return dot
        }
    }

    /// The ask's title in this colour, broken into the lines the layout left room for, each with its box.
    static func titleLines(_ asks: AsksShown, colour: CGColor) -> [(text: NSAttributedString, box: CGRect)] {
        let layout = asks.layout, box = layout.title
        let title = TextLine.text(asks.ask.title, EdgeStyle.asksTitle, colour, kern: EdgeStyle.asksTitleKern)

        return TextLine.wrapped(title, width: box.width, most: layout.titleLines).enumerated().map { index, line in
            (line, CGRect(
                x: box.minX, y: box.minY + Double(index) * AsksLayout.titleLine, width: box.width,
                height: AsksLayout.titleLine
            ))
        }
    }

    /// What an answer's row reads: "Answer in Claude" for the one row of an ask answered there, else its answer; and
    /// "recommended" at its end for Claude's pick.
    static func label(_ index: Int, of ask: PanelAsk) -> (words: String, note: String?) {
        let words = ask.isInClaude ? "Answer in Claude" : ask.answers[index]

        return (words, ask.recommended == words && !ask.isInClaude ? "recommended" : nil)
    }

    /// Where a row's label goes after its keycap, and its note at its end, the label cut short before it, in the row's
    /// own frame.
    static func label(in row: CGSize, note: String?) -> (label: CGRect, note: CGRect?) {
        let line = AsksLayout.labelLine, y = (row.height - line) / 2
        var end = row.width - AsksLayout.rowSide
        var noteBox: CGRect?

        if let note {
            let width = TextLine.width(TextLine.text(note, EdgeStyle.asksNote, EdgeStyle.ink3))
            let drop = TextLine.drop(of: EdgeStyle.asksNote, to: EdgeStyle.asksLabel, lineHeight: line)

            noteBox = CGRect(x: end - width, y: y + drop, width: width, height: line)
            end -= width + AsksLayout.recommendedGap
        }
        return (CGRect(x: AsksLayout.labelX, y: y, width: max(0, end - AsksLayout.labelX), height: line), noteBox)
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

    /// The held answer's check, 11 across, in its keycap's place: its box in the row's frame, its path in the box's.
    static func check() -> (box: CGRect, path: CGPath) {
        let path = CGMutablePath(), side = 11.0, cap = AsksLayout.keycap

        path.addLines(between: [CGPoint(x: 2, y: 5.8), CGPoint(x: 4.4, y: 8.2), CGPoint(x: 9, y: 3)])
        return (CGRect(x: cap.midX - side / 2, y: cap.midY - side / 2, width: side, height: side), path)
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
            CGRect(x: markX, y: y, width: mark + 1, height: line)
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

    /// Whether its arc runs down, or has run out, in the render server.
    var isCounting: Bool { arc.animation(forKey: Self.key) != nil }

    private static let key = "countdown"
}

extension AsksMeasure {
    /// How the asks panel's words are set in black and in glass alike, for the run to lay it out: its title's lines,
    /// and its foot's words' widths.
    nonisolated static let drawn = AsksMeasure(
        titleLines: { title in
            MainActor.assumeIsolated {
                let text = TextLine.text(title, EdgeStyle.asksTitle, EdgeStyle.ink, kern: EdgeStyle.asksTitleKern)
                let width = AsksLayout.inner - 2 * AsksLayout.textSide

                return max(1, TextLine.wrapped(text, width: width, most: AsksLayout.titleMost).count)
            }
        },
        footWidth: { words in
            MainActor.assumeIsolated { TextLine.width(TextLine.text(words, EdgeStyle.asksFoot, EdgeStyle.ink)) }
        }
    )
}
