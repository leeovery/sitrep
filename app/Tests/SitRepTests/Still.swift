import AppKit
@testable import SitRep
import SwiftUI
import Testing

/// A drawing made offscreen into a PNG, as a Retina screen shows it: a view laid out at 2× (`displayScale`), or a layer
/// tree drawn as `Drawn` draws one, cut to what shows. For the stills a person reads, never a test's pixel counts.
@MainActor
enum Still {
    /// A view `size` points, in `scheme`, its pixels at 2×.
    static func png(
        _ view: some View, size: CGSize, scheme: ColorScheme = .dark, sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Data {
        let hosting = NSHostingView(rootView: view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, scheme)
            .environment(\.displayScale, 2))

        hosting.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()

        let screen = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds), sourceLocation: sourceLocation)
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int((size.width * 2).rounded()), pixelsHigh: Int((size.height * 2).rounded()),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: screen.colorSpaceName,
            bytesPerRow: 0, bitsPerPixel: 0
        )?.retagging(with: screen.colorSpace), sourceLocation: sourceLocation)

        bitmap.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return try png(bitmap, sourceLocation: sourceLocation)
    }

    /// A layer tree over `ground`, at 2×, cut to `rect` in its points from its top left, with `bezel` points of the
    /// display's black bezel beside its left edge, which an edge's shape flares into.
    static func png(
        _ layer: CALayer, over ground: CGColor, cut rect: CGRect, bezel: CGFloat = 0,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> Data {
        let drawn = try Drawn(layer, over: ground)
        let pixels = CGRect(x: rect.minX * 2, y: rect.minY * 2, width: rect.width * 2, height: rect.height * 2)
        let cut = try #require(drawn.bitmap.cgImage?.cropping(to: pixels.integral), sourceLocation: sourceLocation)
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(bezel * 2) + cut.width, pixelsHigh: cut.height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0,
            bitsPerPixel: 0
        )?.retagging(with: .sRGB), sourceLocation: sourceLocation)
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap), sourceLocation: sourceLocation).cgContext

        context.setFillColor(EdgeStyle.black)
        context.fill(CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
        context.draw(cut, in: CGRect(x: Int(bezel * 2), y: 0, width: cut.width, height: cut.height))
        bitmap.size = CGSize(width: bezel + rect.width, height: rect.height)
        return try png(bitmap, sourceLocation: sourceLocation)
    }

    private static func png(_ bitmap: NSBitmapImageRep, sourceLocation: SourceLocation) throws -> Data {
        try #require(bitmap.representation(using: .png, properties: [:]), sourceLocation: sourceLocation)
    }
}
