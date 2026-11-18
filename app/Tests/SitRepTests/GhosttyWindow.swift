import AppKit
import CoreText
import Testing

/// A terminal's cells as `screens/window.ts` writes them: each row's runs painted alike, from the column each starts
/// at, their colours worked out, and the cursor.
struct Terminal: Decodable {
    struct Run: Decodable {
        let column: Int
        let text: String
        let ink: String
        let ground: String?
        let bold: Bool?
        let italic: Bool?
    }

    struct Cursor: Decodable {
        let row: Int
        let column: Int
        let color: String
    }

    let columns: Int
    let background: String
    let rows: [[Run]]
    let cursor: Cursor
}

/// The terminal's type, as Lee's Ghostty sets it: JetBrainsMono Nerd Font Mono at 15, its cell as wide as the font's
/// advance and as tall as its line, to the pixel.
struct TerminalFonts {
    static let size = 15.0

    let regular: CTFont
    let bold: CTFont
    let italic: CTFont
    let boldItalic: CTFont

    init(sourceLocation: SourceLocation = #_sourceLocation) throws {
        let font = { (style: String) throws -> CTFont in
            let name = "JetBrainsMonoNFM-\(style)"
            let made = CTFontCreateWithName(name as CFString, Self.size, nil)

            // CoreText gives another font where it has none of the name: app/screens draws in Lee's own
            try #require(
                CTFontCopyPostScriptName(made) as String == name,
                "JetBrainsMono Nerd Font Mono is not installed", sourceLocation: sourceLocation
            )
            return made
        }

        regular = try font("Regular")
        bold = try font("Bold")
        italic = try font("Italic")
        boldItalic = try font("BoldItalic")
    }

    func font(bold isBold: Bool, italic isItalic: Bool) -> CTFont {
        switch (isBold, isItalic) {
        case (true, true): boldItalic
        case (true, false): bold
        case (false, true): italic
        case (false, false): regular
        }
    }

    /// The cell: the advance of the font's M across, its ascent, descent and leading down, each to the pixel at 2×.
    var cell: CGSize {
        var glyph = CGGlyph(), character = UniChar(("M" as Unicode.Scalar).value), advance = CGSize.zero

        CTFontGetGlyphsForCharacters(regular, &character, &glyph, 1)
        CTFontGetAdvancesForGlyphs(regular, .horizontal, &glyph, &advance, 1)

        let line = CTFontGetAscent(regular) + CTFontGetDescent(regular) + CTFontGetLeading(regular)

        return CGSize(width: pixels(advance.width), height: (line * Canvas.scale).rounded(.up) / Canvas.scale)
    }

    /// How far down its cell a row's baseline is.
    var baseline: Double { pixels(CTFontGetAscent(regular)) }

    private func pixels(_ points: Double) -> Double {
        (points * Canvas.scale).rounded() / Canvas.scale
    }
}

/// A Ghostty window on Lee's Mac, drawn as his Ghostty draws it: its cells in his font over Nord Wave, padded 20 across
/// and 18 down, under a titlebar of the terminal's own background with the three lights and the tab's blue rule, its
/// corners rounded, its shadow on the desktop. The box-drawing characters are drawn as lines across their cells, as
/// Ghostty draws them, so rules and trees join; every other character is the font's, or the system's where the font
/// has none.
struct GhosttyWindow {
    static let padding = CGSize(width: 20, height: 18)
    static let titlebar = 28.0
    static let radius = 12.0
    /// Ghostty's `background-opacity`.
    static let opacity = 0.98
    static let lights: [UInt32] = [0xFF5F57, 0xFEBC2E, 0x28C840]

    let terminal: Terminal
    let fonts: TerminalFonts
    let cell: CGSize

    init(_ terminal: Terminal, fonts: TerminalFonts) {
        self.terminal = terminal
        self.fonts = fonts
        cell = fonts.cell
    }

    var size: CGSize {
        CGSize(
            width: Double(terminal.columns) * cell.width + 2 * Self.padding.width,
            height: Self.titlebar + Double(terminal.rows.count) * cell.height + 2 * Self.padding.height
        )
    }

    /// The window with its top left at `origin`, in the canvas's points.
    func draw(at origin: CGPoint, on canvas: Canvas) throws {
        let context = canvas.context, frame = CGRect(origin: origin, size: size)
        let shape = CGPath(roundedRect: frame, cornerWidth: Self.radius, cornerHeight: Self.radius, transform: nil)

        context.saveGState()
        // the shadow's offset is the device's, y up: it falls below the window
        context.setShadow(offset: CGSize(width: 0, height: -20), blur: 50, color: ReadmeDesktop.colour(0, alpha: 0.5))
        context.setAlpha(Self.opacity)
        context.addPath(shape)
        context.setFillColor(try ReadmeDesktop.colour(terminal.background))
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(shape)
        context.clip()
        drawTitlebar(in: frame, context)
        context.translateBy(x: frame.minX + Self.padding.width, y: frame.minY + Self.titlebar + Self.padding.height)
        try drawCursor(context)
        for (row, runs) in terminal.rows.enumerated() {
            try draw(runs, row: row, context)
        }
        context.restoreGState()
        drawRim(shape, context)
    }

    /// The three lights, and the tab's rule under the titlebar, brighter toward its right where the tab is.
    private func drawTitlebar(in frame: CGRect, _ context: CGContext) {
        for (i, light) in Self.lights.enumerated() {
            let centre = CGPoint(x: frame.minX + 18 + Double(i) * 20, y: frame.minY + Self.titlebar / 2)

            context.setFillColor(ReadmeDesktop.colour(light))
            context.fillEllipse(in: CGRect(x: centre.x - 6, y: centre.y - 6, width: 12, height: 12))
            context.setStrokeColor(ReadmeDesktop.colour(0, alpha: 0.18))
            context.setLineWidth(0.5)
            context.strokeEllipse(in: CGRect(x: centre.x - 5.75, y: centre.y - 5.75, width: 11.5, height: 11.5))
        }

        let rule = frame.minY + Self.titlebar - 1

        context.setFillColor(ReadmeDesktop.colour(0x81A1C1, alpha: 0.28))
        context.fill(CGRect(x: frame.minX, y: rule, width: frame.width, height: 1))
        context.setFillColor(ReadmeDesktop.colour(0x81A1C1))
        context.fill(CGRect(x: frame.minX + frame.width * 0.58, y: rule - 0.5, width: frame.width * 0.24, height: 1.5))
    }

    /// The window's edge as macOS draws a dark one: a dark line round it, and a light rim inside that.
    private func drawRim(_ shape: CGPath, _ context: CGContext) {
        let inner = shape.boundingBox.insetBy(dx: 1, dy: 1)
        let rim = CGPath(roundedRect: inner, cornerWidth: Self.radius - 1, cornerHeight: Self.radius - 1, transform: nil)

        context.saveGState()
        context.setLineWidth(1)
        context.addPath(shape)
        context.setStrokeColor(ReadmeDesktop.colour(0, alpha: 0.6))
        context.strokePath()
        context.addPath(rim)
        context.setStrokeColor(ReadmeDesktop.colour(0xFFFFFF, alpha: 0.12))
        context.strokePath()
        context.restoreGState()
    }

    private func drawCursor(_ context: CGContext) throws {
        let cursor = terminal.cursor

        context.setFillColor(try ReadmeDesktop.colour(cursor.color))
        context.fill(box(row: cursor.row, column: cursor.column, width: 1))
    }

    /// A row's runs: each its background, then each of its characters in its own cell.
    private func draw(_ runs: [Terminal.Run], row: Int, _ context: CGContext) throws {
        for run in runs {
            let scalars = Array(run.text.unicodeScalars), ink = try ReadmeDesktop.colour(run.ink)

            if let ground = run.ground {
                context.setFillColor(try ReadmeDesktop.colour(ground))
                context.fill(box(row: row, column: run.column, width: scalars.count))
            }
            for (i, scalar) in scalars.enumerated() where scalar != " " {
                let at = box(row: row, column: run.column + i, width: 1)

                if let join = BoxDrawing.joins[scalar] {
                    BoxDrawing.stroke(join, in: at, ink: ink, context)
                } else {
                    glyph(scalar, in: at, ink: ink, font: fonts.font(bold: run.bold == true, italic: run.italic == true), context)
                }
            }
        }
    }

    /// A character on its cell's baseline, centred in the cell where the font that has it draws it another width.
    private func glyph(_ scalar: Unicode.Scalar, in cell: CGRect, ink: CGColor, font: CTFont, _ context: CGContext) {
        let words = NSAttributedString(string: String(scalar), attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink,
        ])
        let line = CTLineCreateWithAttributedString(words)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)

        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: cell.minX + (cell.width - width) / 2, y: cell.minY + fonts.baseline)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func box(row: Int, column: Int, width: Int) -> CGRect {
        CGRect(
            x: Double(column) * cell.width, y: Double(row) * cell.height, width: Double(width) * cell.width,
            height: cell.height
        )
    }
}

/// The box-drawing characters the screen has, drawn as Ghostty draws them: from the cell's middle to each side each
/// joins, light 1 point, heavy 2, the round corners as arcs, so they meet the next cell's.
enum BoxDrawing {
    struct Join: OptionSet {
        let rawValue: Int

        static let up = Join(rawValue: 1)
        static let right = Join(rawValue: 2)
        static let down = Join(rawValue: 4)
        static let left = Join(rawValue: 8)
        static let round = Join(rawValue: 16)
        static let heavy = Join(rawValue: 32)
    }

    static let joins: [Unicode.Scalar: Join] = [
        "─": [.left, .right], "━": [.left, .right, .heavy], "│": [.up, .down], "├": [.up, .down, .right],
        "└": [.up, .right], "┌": [.down, .right], "┐": [.down, .left], "┘": [.up, .left],
        "╭": [.down, .right, .round], "╮": [.down, .left, .round], "╰": [.up, .right, .round],
        "╯": [.up, .left, .round],
    ]

    static func stroke(_ join: Join, in cell: CGRect, ink: CGColor, _ context: CGContext) {
        let middle = CGPoint(x: cell.midX, y: cell.midY), path = CGMutablePath()

        if join.contains(.round) {
            let toY = join.contains(.up) ? cell.minY : cell.maxY, toX = join.contains(.left) ? cell.minX : cell.maxX
            let r = cell.width / 2
            let bend = CGPoint(x: middle.x, y: join.contains(.up) ? middle.y - r : middle.y + r)

            path.move(to: CGPoint(x: middle.x, y: toY))
            path.addLine(to: bend)
            path.addArc(tangent1End: middle, tangent2End: CGPoint(x: toX, y: middle.y), radius: r)
            path.addLine(to: CGPoint(x: toX, y: middle.y))
        } else {
            let ends: [(Join, CGPoint)] = [
                (.up, CGPoint(x: middle.x, y: cell.minY)), (.down, CGPoint(x: middle.x, y: cell.maxY)),
                (.left, CGPoint(x: cell.minX, y: middle.y)), (.right, CGPoint(x: cell.maxX, y: middle.y)),
            ]

            for (side, end) in ends where join.contains(side) {
                path.move(to: middle)
                path.addLine(to: end)
            }
        }
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(ink)
        context.setLineWidth(join.contains(.heavy) ? 2 : 1)
        context.setLineCap(.square)
        context.strokePath()
        context.restoreGState()
    }
}
