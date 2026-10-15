import AppKit

/// One line of text set as the prototype's CSS sets it: centred by its ascent and descent in its line box, on one
/// line, cut short with an ellipsis where it overflows. Drawn once with Core Text (CATextLayer drops a line it has
/// to cut short); a frame never draws it again.
final class TextLine: CALayer {
    enum Alignment {
        case left, right
    }

    private let line: CTLine
    private let origin: CGPoint

    /// Room above and below the line box, so no accent or descender is cut off at its edge.
    private static let bleed = 2.0

    init(_ text: NSAttributedString, in box: CGRect, alignment: Alignment = .left) {
        let whole = CTLineCreateWithAttributedString(text)
        let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(
            string: "…", attributes: text.length > 0 ? text.attributes(at: text.length - 1, effectiveRange: nil) : [:]
        ))

        line = CTLineCreateTruncatedLine(whole, box.width, .end, ellipsis) ?? whole

        let width = CTLineGetTypographicBounds(line, nil, nil, nil)

        origin = CGPoint(
            x: alignment == .right ? box.width - width : 0,
            y: Self.bleed + Self.baseline(text, lineHeight: box.height)
        )
        super.init()

        frame = box.insetBy(dx: 0, dy: -Self.bleed)
        setNeedsDisplay()
    }

    override init(layer: Any) {
        let other = layer as! TextLine

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

    /// Where the baseline sits below the line box's top.
    static func baseline(_ text: NSAttributedString, lineHeight: CGFloat) -> CGFloat {
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0

        CTLineGetTypographicBounds(CTLineCreateWithAttributedString(text), &ascent, &descent, &leading)

        return (lineHeight - ascent - descent) / 2 + ascent
    }
}
