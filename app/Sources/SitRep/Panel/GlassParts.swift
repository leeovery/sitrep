import CoreGraphics
import SitRepPanel
import SwiftUI

/// A path as a shape: it fills where it is, whatever the frame.
struct Outline: Shape {
    let path: Path

    func path(in _: CGRect) -> Path { path }
}

/// A rectangle with its two front corners rounded, as the panel's content and a tab's words are clipped.
struct FrontRounded: Shape {
    let rect: CGRect
    let top: Double
    let bottom: Double

    func path(in _: CGRect) -> Path { Path(PanelContent.clipPath(rect, top: top, bottom: bottom)) }
}

/// How thick Liquid Glass looks, which it takes from its shape's size alone: a shape whose bounds are under about 64pt
/// at their narrower is thin glass, one past about 72pt thick, with nothing between, and a shape rebuilt each frame
/// crossing from one to the other changes at once, in an animation or not (both measured on macOS 26).
enum GlassThickness {
    /// The path as thick glass whatever its own size: with a point of it far off the top of the view, outside its
    /// frame and its window, so its bounds are as wide as the view and over 100pt tall.
    static func thick(_ path: CGPath, width: Double) -> Path {
        let made = CGMutablePath()
        made.addPath(path)
        made.addRect(CGRect(x: width - 1, y: -100, width: 1, height: 1))
        return Path(made)
    }
}

/// The colours on glass beside its label colours.
enum GlassInk {
    /// Needs you: Claude's orange, as on the black.
    static let orange = Color(cgColor: PanelStyle.color(LiveLight.orange))
}

/// An arc turning round a track, once in a period: a working mark's or row's, a jumping one's, a jumping row's age.
@available(macOS 26, *)
struct Spinner: View {
    let track: AnyShapeStyle?
    let arc: AnyShapeStyle
    let period: Double
    let line: Double
    @State private var turned = false

    var body: some View {
        ZStack {
            if let track {
                Circle().inset(by: line / 2).stroke(track, lineWidth: line)
            }
            Circle()
                .inset(by: line / 2)
                .trim(from: 0, to: 0.25)
                .stroke(arc, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .rotationEffect(.degrees(turned ? 360 : 0))
        .onAppear {
            withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
                turned = true
            }
        }
    }
}

/// A working title on glass: in the secondary label colour, with the primary sweeping along it every 2.5s, as the
/// black's shimmer does.
@available(macOS 26, *)
struct Shimmering: View {
    let text: Text
    let width: Double
    @State private var swept = false

    var body: some View {
        text.foregroundStyle(.secondary)
            .overlay(alignment: .leading) {
                text.foregroundStyle(.primary)
                    .mask(alignment: .leading) {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0), .init(color: .clear, location: 0.36),
                                .init(color: .black, location: 0.5), .init(color: .clear, location: 0.64),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: 3 * width)
                        .offset(x: swept ? 0 : -2 * width)
                    }
            }
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    swept = true
                }
            }
    }
}

extension View {
    /// Set on one line in a box, cut short at its end.
    func placed(in box: CGRect, alignment: Alignment = .leading) -> some View {
        lineLimit(1)
            .truncationMode(.tail)
            .frame(width: box.width, height: box.height, alignment: alignment)
            .offset(x: box.minX, y: box.minY)
    }
}
