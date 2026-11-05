import CoreGraphics
import SitRepPanel
import SwiftUI

/// A path as a shape: it fills where it is, whatever the frame.
struct Outline: Shape {
    let path: Path

    func path(in _: CGRect) -> Path { path }
}

/// How thick Liquid Glass looks, which it takes from its shape's size alone: a shape whose bounds are under about 64pt
/// at their narrower is thin glass, one past about 72pt thick, with nothing between, and a shape rebuilt each frame
/// crossing from one to the other changes at once, in an animation or not (both measured on macOS 26).
enum GlassThickness {
    /// The path as thick glass whatever its own size: with a point of it far off the top of the view at either side,
    /// outside its frame and its window, so its bounds are as wide as the view, on either edge, and over 100pt tall.
    static func thick(_ path: CGPath, width: Double) -> Path {
        let made = CGMutablePath()
        made.addPath(path)
        made.addRect(CGRect(x: 0, y: -100, width: 1, height: 1))
        made.addRect(CGRect(x: width - 1, y: -100, width: 1, height: 1))
        return Path(made)
    }
}

/// The colours on glass beside its label colours.
enum GlassInk {
    /// Needs you: Claude's orange, as on the black.
    static let orange = Color(cgColor: EdgeStyle.color(LiveLight.orange))
    /// The same, for a spinner's arc.
    static let orangeArc = NSColor(cgColor: EdgeStyle.color(LiveLight.orange)) ?? .systemOrange
}

/// An arc turning round a track, once in a period, or held still with none: a working row's mark on the glass. Black's
/// arc, turned by Core Animation in the render server: the app does no work as it turns, and no update of the views
/// round it, animated or not, restarts it.
struct Spinner: NSViewRepresentable {
    /// In the label colours, which the view resolves for the glass's appearance.
    let track: NSColor?
    let arc: NSColor
    let period: Double?

    func makeNSView(context _: Context) -> SpinnerView { SpinnerView() }

    func updateNSView(_ view: SpinnerView, context _: Context) {
        view.show(track: track, arc: arc, period: period)
    }
}

/// The spinner's view: the arc in a layer of its own, as big as the view. Decoration: a click passes through it to
/// what it sits in, a list's row or a button.
@MainActor
final class SpinnerView: NSView {
    private let spinner = Arc()
    private var colours: (track: NSColor?, arc: NSColor) = (nil, .clear)
    private var period: Double? = 1.0

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(spinner.layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    override func hitTest(_: NSPoint) -> NSView? { nil }

    /// Internal only for the tests, which read it.
    var isTurning: Bool {
        spinner.isTurning
    }

    func show(track: NSColor?, arc: NSColor, period: Double?) {
        colours = (track, arc)
        self.period = period
        paint()
        follow()
    }

    override func layout() {
        super.layout()
        still { spinner.fit(bounds) }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        paint()
    }

    /// Back in a window, its turn is added again if the window took it.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        follow()
    }

    /// Turning once a period, or held still with none.
    private func follow() {
        if let period {
            spinner.turn(every: period)
        } else {
            spinner.hold()
        }
    }

    private func paint() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            still {
                spinner.track.strokeColor = colours.track?.cgColor
                spinner.arc.strokeColor = colours.arc.cgColor
            }
        }
    }
}

/// A working title on glass: in the secondary label colour, with the primary sweeping along it every 2.5s, as the
/// black's shimmer does: the title again in the primary, shown through the black's band of light, which Core
/// Animation carries along it in the render server, so the app does no work as it sweeps.
@available(macOS 26, *)
struct Shimmering: View {
    let text: Text
    let width: Double

    var body: some View {
        text.foregroundStyle(.secondary)
            .overlay(alignment: .leading) {
                Sweep(lit: AnyView(text.foregroundStyle(.primary).lineLimit(1).truncationMode(.tail)), width: width)
            }
    }
}

/// The lit title in a view of its own, masked by the band of light, on the glass.
struct Sweep: NSViewRepresentable {
    let lit: AnyView
    let width: Double

    func makeNSView(context _: Context) -> SweepView { SweepView() }

    func updateNSView(_ view: SweepView, context _: Context) {
        view.show(lit, width: width)
    }
}

/// The lit title's view. Decoration, as the arc's is: a click passes through it to what it sits in, and VoiceOver
/// reads the title once, from the words under it.
@MainActor
final class SweepView: NSView {
    private let lit = Unheard(rootView: AnyView(EmptyView()))
    private var band: ShimmerBand?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        lit.sizingOptions = []
        addSubview(lit)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    override func hitTest(_: NSPoint) -> NSView? { nil }

    override func isAccessibilityElement() -> Bool { false }

    override func accessibilityChildren() -> [Any]? { [] }

    /// Internal only for the tests, which read it.
    var isSweeping: Bool {
        band?.layer.animation(forKey: Self.key) != nil
    }

    func show(_ title: AnyView, width: Double) {
        lit.rootView = AnyView(
            title.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).accessibilityHidden(true)
        )
        if band.map({ $0.layer.bounds.width != 3 * width }) ?? true {
            light(width)
        }
    }

    override func layout() {
        super.layout()
        lit.frame = bounds
        if let band {
            still { band.layer.frame.size.height = bounds.height }
        }
    }

    /// Back in a window, the sweep is added again if the window took it.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let band, band.layer.animation(forKey: Self.key) == nil {
            band.layer.add(band.sweep, forKey: Self.key)
        }
    }

    /// A band for a title this wide, sweeping from now on.
    private func light(_ width: Double) {
        let made = ShimmerBand(width: width, height: bounds.height)
        made.layer.add(made.sweep, forKey: Self.key)
        layer?.mask = made.layer
        band = made
    }

    private static let key = "sweep"
}

/// The lit words, which take no click and say nothing to VoiceOver.
private final class Unheard: NSHostingView<AnyView> {
    override func hitTest(_: NSPoint) -> NSView? { nil }

    override func isAccessibilityElement() -> Bool { false }

    override func accessibilityChildren() -> [Any]? { [] }
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
