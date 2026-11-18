import AppKit
@testable import SitRep
import Testing

/// The Mac the README's pictures share (`app/screens`): a 14-inch MacBook Pro's screen, under its menu bar, and its
/// wallpaper, so the Ghostty window and the notch read as one desktop. The wallpaper is drawn here, in code: deep blue
/// to violet, soft and quiet, so the black of the notch and the window stand out on it.
enum ReadmeDesktop {
    static let screen = CGSize(width: 1512, height: 982)
    static let menuBar = 37.0

    /// Soft lights over the wallpaper's ground: where each centres, as shares of the screen, how far it reaches, as a
    /// share of the screen's width, its colour and how strong it is at its middle.
    private static let lights: [(at: CGPoint, reach: Double, colour: UInt32, strength: Double)] = [
        (CGPoint(x: 0.78, y: 0.16), 0.62, 0x5B3FA8, 0.75),
        (CGPoint(x: 0.10, y: 0.88), 0.66, 0x1F4FA8, 0.7),
        (CGPoint(x: 0.97, y: 0.98), 0.42, 0x8A3E98, 0.5),
        (CGPoint(x: 0.36, y: 0.30), 0.38, 0x3466C8, 0.3),
        (CGPoint(x: 0.60, y: 0.70), 0.30, 0x6A44B8, 0.25),
    ]

    /// The wallpaper's part under `cut`, in the screen's points from its top left, into a context drawn y down in
    /// `cut`'s points from its origin.
    static func drawWallpaper(_ cut: CGRect, in context: CGContext) throws {
        let ground = try gradient([colour(0x0B1033), colour(0x1A1446), colour(0x26164F)], at: [0, 0.55, 1])

        context.saveGState()
        context.clip(to: CGRect(origin: .zero, size: cut.size))
        context.translateBy(x: -cut.minX, y: -cut.minY)
        context.drawLinearGradient(
            ground, start: .zero, end: CGPoint(x: screen.width, y: screen.height),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        for light in lights {
            let centre = CGPoint(x: light.at.x * screen.width, y: light.at.y * screen.height)
            let glow = try gradient(
                [
                    colour(light.colour, alpha: light.strength), colour(light.colour, alpha: light.strength * 0.4),
                    colour(light.colour, alpha: 0),
                ],
                at: [0, 0.45, 1]
            )

            context.drawRadialGradient(
                glow, startCenter: centre, startRadius: 0, endCenter: centre,
                endRadius: light.reach * screen.width, options: []
            )
        }
        context.restoreGState()
    }

    private static func gradient(_ colours: [CGColor], at stops: [CGFloat]) throws -> CGGradient {
        try #require(CGGradient(colorsSpace: EdgeStyle.sRGB, colors: colours as CFArray, locations: stops))
    }

    /// A colour as the pictures give one, in sRGB.
    static func colour(_ hex: UInt32, alpha: Double = 1) -> CGColor {
        CGColor(
            srgbRed: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha
        )
    }

    /// A colour as the terminal's cells give one, `#rrggbb`.
    static func colour(_ hex: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> CGColor {
        let value = try #require(UInt32(hex.dropFirst(), radix: 16), "not a colour: \(hex)", sourceLocation: sourceLocation)

        return colour(value)
    }
}

/// A picture `size` points, its pixels at 2×, as a Retina screen shows it, drawn y down from its top left.
final class Canvas {
    static let scale = 2.0

    let size: CGSize
    let context: CGContext

    init(_ size: CGSize, sourceLocation: SourceLocation = #_sourceLocation) throws {
        self.size = size
        context = try #require(
            CGContext(
                data: nil, width: Int((size.width * Self.scale).rounded()),
                height: Int((size.height * Self.scale).rounded()), bitsPerComponent: 8, bytesPerRow: 0,
                space: EdgeStyle.sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            sourceLocation: sourceLocation
        )
        context.translateBy(x: 0, y: size.height * Self.scale)
        context.scaleBy(x: Self.scale, y: -Self.scale)
    }

    func image(sourceLocation: SourceLocation = #_sourceLocation) throws -> CGImage {
        try #require(context.makeImage(), sourceLocation: sourceLocation)
    }

    /// Its pixels as a PNG, sized in points, so it reads at 2×.
    func png(sourceLocation: SourceLocation = #_sourceLocation) throws -> Data {
        let bitmap = NSBitmapImageRep(cgImage: try image(sourceLocation: sourceLocation))

        bitmap.size = size
        return try #require(bitmap.representation(using: .png, properties: [:]), sourceLocation: sourceLocation)
    }

    /// An image drawn upright over `rect`, in this canvas's points.
    func draw(_ image: CGImage, in rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}
