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
}

extension NSColor {
    var lightness: CGFloat {
        redComponent + greenComponent + blueComponent
    }

    var isWhite: Bool {
        min(redComponent, greenComponent, blueComponent) > 0.9
    }

    /// Whether it is no lighter than `grey` in any channel.
    func isGrey(atMost grey: CGFloat) -> Bool {
        max(redComponent, greenComponent, blueComponent) <= grey
    }
}
