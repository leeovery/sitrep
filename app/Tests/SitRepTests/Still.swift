import AppKit
import SwiftUI
import Testing

/// A view drawn offscreen into a PNG, as a Retina screen shows it: laid out at 2× (`displayScale`). For the stills a
/// person reads, never a test's pixel counts.
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

    private static func png(_ bitmap: NSBitmapImageRep, sourceLocation: SourceLocation) throws -> Data {
        try #require(bitmap.representation(using: .png, properties: [:]), sourceLocation: sourceLocation)
    }
}
