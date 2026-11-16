import AppKit
import SwiftUI
import Testing

/// A view drawn offscreen over black, in the dark, to read its pixels by the view's own points from its top left.
@MainActor
struct Drawn {
    let bitmap: NSBitmapImageRep
    let scale: CGFloat

    /// Offscreen, at 2× whatever the screen's scale, as a Retina screen draws it, so what a test counts in pixels holds
    /// on any Mac.
    init(_ view: some View, size: CGSize) throws {
        let hosting = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height)
            .background(Color.black)
            .environment(\.colorScheme, .dark))

        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        let screen = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))

        bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int((size.width * 2).rounded()), pixelsHigh: Int((size.height * 2).rounded()),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: screen.colorSpaceName,
            bytesPerRow: 0, bitsPerPixel: 0
        )?.retagging(with: screen.colorSpace))
        bitmap.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        scale = 2
    }

    /// A view as it draws where it is, as in a window, which lays it out to the window's pixels.
    init(_ view: NSView) throws {
        bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        scale = CGFloat(bitmap.pixelsHigh) / view.bounds.height
    }

    /// A layer as Core Animation draws it, at 2×, over black: under a flipped root, as the edge lays its layers out
    /// from the top left, each drawn at a `contentsScale` of 2.
    init(_ layer: CALayer) throws {
        let size = layer.bounds.size
        let root = CALayer()

        bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int((size.width * 2).rounded()), pixelsHigh: Int((size.height * 2).rounded()),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )?.retagging(with: .sRGB))
        scale = 2
        root.isGeometryFlipped = true
        root.frame = CGRect(origin: .zero, size: size)
        root.addSublayer(layer)
        Self.display(root)

        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap)).cgContext

        context.setFillColor(.black)
        context.fill(CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        // `render(in:)` lays the root's sublayers out from its bottom, flipped or not, while its text is drawn the
        // flipped root's way up: the context's own flip sets both right.
        context.translateBy(x: 0, y: CGFloat(bitmap.pixelsHigh))
        context.scaleBy(x: scale, y: -scale)
        root.render(in: context)
        bitmap.size = size
    }

    private static func display(_ layer: CALayer) {
        layer.contentsScale = 2
        layer.displayIfNeeded()
        layer.sublayers?.forEach(display)
    }

    /// A window's drawing, read at 2×, counting a page's half points as whole pixels. A window lays its views out to
    /// its screen's pixels, and none can be made to take another scale, so a screen at any other says so here rather
    /// than failing a test's counts.
    func atTwice() throws -> Drawn {
        try #require(scale == 2, "Laid out at the screen's \(scale)×; these tests read it at 2×")
        return self
    }

    /// The pixels in `rect`, row by row, in sRGB.
    func pixels(in rect: CGRect) -> [NSColor] {
        let columns = Int((rect.minX * scale).rounded())..<Int((rect.maxX * scale).rounded())
        let rows = Int((rect.minY * scale).rounded())..<Int((rect.maxY * scale).rounded())

        return rows.flatMap { y in
            columns.compactMap { x in bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) }
        }
    }

    /// The brightest pixel in `rect`: the full colour of what is drawn there, as words' and strokes' edges blend
    /// into the black.
    func brightest(in rect: CGRect) throws -> NSColor {
        try #require(pixels(in: rect).max { $0.lightness < $1.lightness })
    }

    /// The pixel under this point.
    func pixel(at point: CGPoint) -> NSColor? {
        bitmap.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))?.usingColorSpace(.sRGB)
    }

    /// The pixel under this point as stored, in the drawing's own colour space, as a capture of the live window is
    /// read.
    func stored(at point: CGPoint) -> NSColor? {
        bitmap.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))
    }

    /// The bounds of what is drawn inside `rect` over what is drawn at `ground`, in points to the pixel; nil with
    /// nothing.
    func drawnBox(in rect: CGRect, ground: CGPoint) -> CGRect? {
        guard let ground = pixel(at: ground) else {
            return nil
        }

        let step = 1 / scale
        let pixels = stride(from: rect.minY, to: rect.maxY, by: step).flatMap { y in
            stride(from: rect.minX, to: rect.maxX, by: step).map { CGRect(x: $0, y: y, width: step, height: step) }
        }
        let drawn = pixels.filter { pixel(at: $0.origin).map { Self.differ($0, ground) } ?? false }

        return drawn.dropFirst().reduce(drawn.first) { box, pixel in box?.union(pixel) }
    }

    /// Two colours apart by more than a hair, in their light or their cover.
    private static func differ(_ one: NSColor, _ other: NSColor) -> Bool {
        abs(one.lightness - other.lightness) > 0.12 || abs(one.alphaComponent - other.alphaComponent) > 0.08
            || abs(one.redComponent - other.redComponent) > 0.08 || abs(one.blueComponent - other.blueComponent) > 0.08
    }
}

extension NSColor {
    var lightness: CGFloat {
        redComponent + greenComponent + blueComponent
    }

    var isWhite: Bool {
        min(redComponent, greenComponent, blueComponent) > 0.9
    }

    /// A system colour as the dark appearance gives it, in this colour space.
    func dark(in space: NSColorSpace) -> NSColor {
        var resolved = self

        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            resolved = usingColorSpace(space) ?? self
        }
        return resolved
    }

    /// Alike to within a step of 8 bits in each channel and in its cover.
    func isAlike(_ other: NSColor) -> Bool {
        [
            (redComponent, other.redComponent), (greenComponent, other.greenComponent),
            (blueComponent, other.blueComponent), (alphaComponent, other.alphaComponent),
        ].allSatisfy { abs($0 - $1) <= 1.5 / 255 }
    }
}
