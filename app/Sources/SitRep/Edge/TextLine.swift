import AppKit

/// One line of text set as the prototype's CSS sets it: centred by its ascent and descent in its line box, on one
/// line, cut short with an ellipsis where it overflows. Drawn once with Core Text (CATextLayer drops a line it has
/// to cut short); a frame never draws it again.
final class TextLine: CALayer {
    enum Alignment {
        case left, right
    }

    /// How wide the line is drawn, cut short or not.
    let width: CGFloat

    private let line: CTLine
    private let origin: CGPoint

    /// Room above and below the line box, so no accent or descender is cut off at its edge.
    private static let bleed = 2.0

    init(_ text: NSAttributedString, in box: CGRect, alignment: Alignment = .left) {
        let whole = CTLineCreateWithAttributedString(text)
        let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(
            string: "…", attributes: text.length > 0 ? text.attributes(at: text.length - 1, effectiveRange: nil) : [:]
        ))

        line = Self.cut(whole, to: box.width, with: ellipsis)
        width = CTLineGetTypographicBounds(line, nil, nil, nil)
        origin = CGPoint(
            x: alignment == .right ? box.width - width : 0,
            y: Self.bleed + Self.baseline(text, lineHeight: box.height)
        )
        super.init()

        frame = box.insetBy(dx: 0, dy: -Self.bleed)
        setNeedsDisplay()
    }

    /// The line cut short with the ellipsis to fit the width. Core Text's own cut overruns the width it is given by
    /// as much as the ellipsis (3.5 at 13 medium, measured), so it is cut again, narrower by the overrun, until it fits.
    /// Where Core Text cuts none, the room narrower than the ellipsis, the ellipsis alone, or nothing where even that
    /// would overrun. A line that fits is kept whole first, as Core Text gives no line at all for a room narrower than
    /// its ellipsis, even one the whole line fits: a count of one figure, "3".
    private static func cut(_ whole: CTLine, to width: CGFloat, with ellipsis: CTLine) -> CTLine {
        if CTLineGetTypographicBounds(whole, nil, nil, nil) <= width {
            return whole
        }

        var room = width

        while room > 0, let line = CTLineCreateTruncatedLine(whole, room, .end, ellipsis) {
            let overrun = CTLineGetTypographicBounds(line, nil, nil, nil) - width

            guard overrun > 0 else {
                return line
            }
            room -= max(overrun, 0.5)
        }
        return CTLineGetTypographicBounds(ellipsis, nil, nil, nil) <= width
            ? ellipsis
            : CTLineCreateWithAttributedString(NSAttributedString())
    }

    override init(layer: Any) {
        let other = layer as! TextLine

        width = other.width
        line = other.line
        origin = other.origin
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// Core Animation hands a layer under a flipped root a context with y down, in which Core Text would draw the
    /// glyphs upside down: the text matrix turns them back.
    override func draw(in context: CGContext) {
        let flipped = contentsAreFlipped()

        context.textMatrix = CGAffineTransform(scaleX: 1, y: flipped ? -1 : 1)
        context.textPosition = CGPoint(x: origin.x, y: flipped ? origin.y : bounds.height - origin.y)
        CTLineDraw(line, context)
    }

    static func text(_ string: String, _ font: NSFont, _ color: CGColor, kern: CGFloat = 0) -> NSMutableAttributedString {
        NSMutableAttributedString(string: string, attributes: [
            .font: font,
            .kern: kern,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
    }

    /// How wide the text is set whole, on one line.
    static func width(_ text: NSAttributedString) -> CGFloat {
        CTLineGetTypographicBounds(CTLineCreateWithAttributedString(text), nil, nil, nil)
    }

    /// How far down a line of `lower` sits in a line box as tall as one of `upper`'s for their baselines to meet, as
    /// two sizes on one baseline: a your-turn row's project after its words.
    static func drop(of lower: NSFont, to upper: NSFont, lineHeight: CGFloat) -> CGFloat {
        baseline(text("A", upper, .black), lineHeight: lineHeight) - baseline(text("A", lower, .black), lineHeight: lineHeight)
    }

    /// Where the baseline sits below the line box's top.
    static func baseline(_ text: NSAttributedString, lineHeight: CGFloat) -> CGFloat {
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0

        CTLineGetTypographicBounds(CTLineCreateWithAttributedString(text), &ascent, &descent, &leading)

        return (lineHeight - ascent - descent) / 2 + ascent
    }
}
