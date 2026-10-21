import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// The sidebar as the window lays it out, made, never shown: the real `BoardColumn` in the window's split, at Lee's
/// 1260 × 1069 unless given another height, over a run of a board the real `watch` printed. Its frames are read as
/// Paper's drawing gives them: x from the glass's left, y from the window's top.
@MainActor
struct HostedSidebar {
    let window: NSWindow
    let view: NSView
    /// The board's list, and Settings' at its foot.
    let board: NSTableView
    let foot: NSTableView
    let field: NSSearchField

    /// `bottomSafeArea` gives the sidebar the bottom safe area a window on screen has, which an offscreen one does not.
    init(
        _ run: WindowRun, height: CGFloat = 1069, bottomSafeArea: CGFloat = 0, actions: WindowActions = WindowActions()
    ) throws {
        let now = Self.printed
        let column = BoardColumn(
            sidebar: run.sidebar(at: now), spot: run.spot, pick: run.pick, filter: run.filter, now: now
        )
        let sidebar = NSHostingController(rootView: column.environment(\.windowActions, actions).environment(\.colorScheme, .dark))

        sidebar.sizingOptions = []
        window = SitRepWindow.window(SitRepWindow.split(sidebar: sidebar, page: NSHostingController(rootView: Color.clear)))
        window.setContentSize(CGSize(width: 1260, height: height))
        sidebar.view.additionalSafeAreaInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottomSafeArea, right: 0)
        window.contentView?.layoutSubtreeIfNeeded()
        view = sidebar.view

        let tables = Self.views(NSTableView.self, in: view)

        board = try #require(tables.max { $0.top < $1.top })
        foot = try #require(tables.min { $0.top < $1.top })
        field = try #require(Self.views(NSSearchField.self, in: view).first)
    }

    /// A rect of a view inside the sidebar, in the drawing's terms.
    func frame(of inner: NSView, _ rect: CGRect? = nil) -> CGRect {
        let inWindow = inner.convert(rect ?? inner.bounds, to: nil)
        let glass = view.convert(view.bounds, to: nil)
        let height = window.contentView?.frame.height ?? 0

        return CGRect(x: inWindow.minX - glass.minX, y: height - inWindow.maxY, width: inWindow.width, height: inWindow.height)
    }

    /// The board's rows, in order.
    var rows: [CGRect] {
        (0 ..< board.numberOfRows).map { frame(of: board, board.rect(ofRow: $0)) }
    }

    var footRow: CGRect {
        frame(of: foot, foot.rect(ofRow: 0))
    }

    /// The glass's bottom, from the window's top.
    var glassBottom: CGFloat {
        frame(of: view).maxY
    }

    /// The sidebar as it draws itself, its points the glass's, so a y from the window's top is 8 more.
    func drawn() throws -> Drawn {
        try Drawn(view: view)
    }

    /// How far down the window the glass starts, which the drawing's points are counted from.
    var glassTop: CGFloat {
        frame(of: view).minY
    }

    /// The first board `watch` printed, the window open on it.
    static func opened() -> WindowRun {
        var last = LastBoard()
        let run = WindowRun()

        last.begin()
        _ = last.hear(.line(Lines.watch[0]), at: printed)
        _ = run.show(last, at: printed, reducesMotion: false)
        _ = run.open()
        return run
    }

    /// When the real `watch` printed its first line.
    static let printed = try! Board.read(Lines.watch[0]).at

    private static func views<Kind: NSView>(_ kind: Kind.Type, in view: NSView) -> [Kind] {
        view.subviews.flatMap { ($0 as? Kind).map { [$0] } ?? views(kind, in: $0) }
    }
}

private extension NSView {
    /// Its top edge in its window, higher up the greater.
    var top: CGFloat {
        convert(bounds, to: nil).maxY
    }
}

extension Drawn {
    /// The pixel under this point.
    func pixel(at point: CGPoint) -> NSColor? {
        bitmap.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))?.usingColorSpace(.sRGB)
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
