import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import SwiftUI
import Testing

/// A column of the window as the window lays it out, made, never shown: the real `SidebarColumn`, or the real
/// `ListColumn`, in the window's split, the other columns blank, at Lee's 1260 × 1069 unless given another height, over
/// a run of a board the real `watch` printed. Its frames are read as Paper's drawing gives them: x from the column's
/// left, y from the window's top.
///
/// The sidebar's list scrolls through macOS 26's soft scroll edge, and the list beside the page under the toolbar's,
/// each of which draws its rows where nothing offscreen reads them: the lists' frames are AppKit's, and what a row draws
/// is read from the row drawn alone.
@MainActor
struct HostedSidebar {
    /// Which of the window's columns is hosted.
    enum Column {
        case sidebar, list
    }

    let window: NSWindow
    let view: NSView
    /// The column's list.
    let board: NSTableView
    let field: NSSearchField?
    let split: NSSplitViewController
    private let hosted: NSHostingController<AnyView>
    private let dressed: (AnyView) -> AnyView
    private let column: Column

    /// `bottomSafeArea` gives the column the bottom safe area a window on screen has, which an offscreen one does not;
    /// `isKey` tells it its window is key, which one never shown never is; `reducesMotion`, SitRep's Reduce motion on.
    init(
        _ run: WindowRun, column: Column = .sidebar, height: CGFloat = 1069, bottomSafeArea: CGFloat = 0,
        actions: WindowActions = WindowActions(), isKey: Bool = false, reducesMotion: Bool = false
    ) throws {
        let dressed = { (content: AnyView) in
            let keyed = isKey ? AnyView(content.environment(\.controlActiveState, .key)) : content

            return AnyView(
                keyed.environment(\.windowActions, actions).environment(\.reducesWindowMotion, reducesMotion)
                    .environment(\.colorScheme, .dark)
            )
        }
        let hosted = NSHostingController(rootView: dressed(Self.content(of: run, column, at: Self.now(of: run))))
        let blank = { NSHostingController(rootView: Color.clear) as NSViewController }

        hosted.sizingOptions = []
        split = column == .sidebar
            ? SitRepWindow.split(sidebar: hosted, list: blank(), page: blank())
            : SitRepWindow.split(sidebar: blank(), list: hosted, page: blank())
        window = SitRepWindow.window(split)
        window.setContentSize(CGSize(width: 1260, height: height))
        hosted.view.additionalSafeAreaInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottomSafeArea, right: 0)
        window.contentView?.layoutSubtreeIfNeeded()
        view = hosted.view
        self.hosted = hosted
        self.dressed = dressed
        self.column = column

        board = try #require(Self.views(NSTableView.self, in: view).first)
        field = Self.views(NSSearchField.self, in: view).first
    }

    /// The column drawn again over the run as it is at this time, as a board coming in draws it.
    func show(_ run: WindowRun, at now: Date) {
        hosted.rootView = dressed(Self.content(of: run, column, at: now))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private static func content(of run: WindowRun, _ column: Column, at now: Date) -> AnyView {
        switch column {
        case .sidebar: AnyView(SidebarColumn(places: run.places, root: run.location.root, filter: run.filter))
        case .list: AnyView(list(of: run, at: now))
        }
    }

    /// The time of the board the run shows.
    private static func now(of run: WindowRun) -> Date {
        run.last.board?.at ?? printed
    }

    /// The run's list as its window draws it, at this time.
    @ViewBuilder static func list(of run: WindowRun, at now: Date) -> some View {
        if let list = run.list(at: now) {
            ListColumn(list: list, picked: run.location.picked?.pick, head: run.head, filter: run.filter, now: now)
        }
    }

    /// A rect of a view inside the column, in the drawing's terms.
    func frame(of inner: NSView, _ rect: CGRect? = nil) -> CGRect {
        let inWindow = inner.convert(rect ?? inner.bounds, to: nil)
        let column = view.convert(view.bounds, to: nil)
        let height = window.contentView?.frame.height ?? 0

        return CGRect(x: inWindow.minX - column.minX, y: height - inWindow.maxY, width: inWindow.width, height: inWindow.height)
    }

    /// The list's rows, in order.
    var rows: [CGRect] {
        (0 ..< board.numberOfRows).map { frame(of: board, board.rect(ofRow: $0)) }
    }

    /// The column's bottom, from the window's top.
    var glassBottom: CGFloat {
        frame(of: view).maxY
    }

    /// The column as it draws itself, its points the column's.
    func drawn() throws -> Drawn {
        try Drawn(view)
    }

    /// The first board `watch` printed, unless given another it printed, the window open on it, its wall clock at the
    /// moment the line was printed, unless given another.
    static func opened(_ line: String = Lines.watch[0], wall: Date? = nil) -> WindowRun {
        var last = LastBoard()
        let at = (try? Board.read(line).at) ?? printed
        let run = WindowRun(wall: { wall ?? at })

        last.begin()
        _ = last.hear(.line(line), at: at)
        run.show(last, at: at, reducesMotion: false)
        run.open()
        return run
    }

    /// When the real `watch` printed its first line.
    static let printed = try! Board.read(Lines.watch[0]).at

    static func views<Kind: NSView>(_ kind: Kind.Type, in view: NSView) -> [Kind] {
        view.subviews.flatMap { ($0 as? Kind).map { [$0] } ?? views(kind, in: $0) }
    }
}

extension Drawn {
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
