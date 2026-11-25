import AppKit
@testable import SitRep
@testable import SitRepEdge
@testable import SitRepPanel
import Testing

/// The strip with the asks panel open beside a tab, drawn by the real run into the real surface on the README desktop,
/// for `AsksPanelStillsTests`: Help desk redesign's tab poured out on its mark, its arrow pressed, the pointer on the
/// asks panel's title.
@MainActor
enum StripStills {
    private static let frameMS = 1000.0 / 60

    /// The still at this edge, over this board, its times as of `now` on the wall clock, into `folder`.
    static func shoot(on edge: ScreenEdge, board: PanelBoard, at now: Double, into folder: URL) throws {
        let mirror = edge.stripMirror(wide: true), onRight = edge.edge == .right
        let setting = StripRun.Setting(stage: edge.stripStage, reducesMotion: false, mirror: mirror)
        let run = StripRun(
            at: 0, in: setting, EdgeSettings(), asksMeasure: AsksMeasure.drawn, measure: StripWordsLayer.measure
        )

        run.show(board, moment(run, nil, setting))

        let mark = CGPoint(x: 18, y: run.strip.yOf(.session("sr-nw0001")))

        step(run, for: 3000, mark, setting) { run.strip.liveTab()?.phase == .open && !run.frame.isMoving }

        let arrow = try arrow(run, mirror: mirror)

        step(run, for: frameMS, arrow, setting)
        try #require(run.press(moment(run, arrow, setting)) == .asks)

        let asks = try #require(run.asksShown), title = asks.layout.title
        let onTitle = CGPoint(
            x: onRight ? asks.frame.maxX - title.midX : asks.frame.minX + title.midX, y: asks.frame.minY + title.midY
        )

        step(run, for: 6 * frameMS, onTitle, setting)

        let surface = StripSurface(), window = edge.stripWindow(wide: true).size

        surface.appearance = NSAppearance(named: .darkAqua)
        surface.frame = CGRect(origin: .zero, size: window)
        surface.draw(run, in: setting, mirror: mirror, now: now)

        let cut = CGRect(x: 0, y: asks.frame.minY - 40, width: window.width, height: asks.frame.height + 80)
        let shot = try EdgeShot(surface, cut: cut, hung: edge.stripStage.menu, onRight: onRight)
            .shoot(turned: Running.at(0.3))

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try shot.png().write(to: folder.appending(path: "11-strip-asks-\(onRight ? "right" : "left").png"))
    }

    /// The middle of the open tab's arrow on the stage, at the tab's front end.
    private static func arrow(_ run: StripRun, mirror: CGAffineTransform) throws -> CGPoint {
        let tab = try #require(run.frame.tabs.first { $0.isLive }), words = try #require(tab.words.last)
        let box = RowArrow.tabBox(in: words.frame.size, pointsLeft: mirror.a < 0)
        let x = mirror.a < 0 ? tab.box.minX + words.frame.maxX - box.midX : tab.box.minX + words.frame.minX + box.midX

        return CGPoint(x: x, y: tab.box.minY + words.frame.minY + box.midY)
    }

    private static func moment(_ run: StripRun, _ pointer: CGPoint?, _ setting: StripRun.Setting) -> StripRun.Moment {
        let time = run.time + frameMS

        return StripRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: setting)
    }

    private static func step(
        _ run: StripRun, for ms: Double, _ pointer: CGPoint, _ setting: StripRun.Setting,
        until done: () -> Bool = { false }
    ) {
        let end = run.time + ms

        while run.time < end, !done() {
            run.step(moment(run, pointer, setting))
        }
    }
}
