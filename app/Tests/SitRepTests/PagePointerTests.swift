import AppKit
@testable import SitRep
import Testing

/// The page's region tells where the pointer is as AppKit knows it: crossings through its one tracking area, heard
/// whether or not SitRep is active; and, where AppKit sends no entry for a pointer that has not moved, the pointer
/// found as the region moves into a window, as the window becomes key, and as it comes back from the Dock. Out of its
/// window, the pointer is over it no longer. The pointer is given, as no test moves Lee's.
@MainActor
struct PagePointerTests {
    /// A region 100 square at the foot of a window twice as wide, and what it told.
    @MainActor private final class Hosted {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.borderless], backing: .buffered,
            defer: true
        )
        let region = PagePointerView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        var pointer = NSPoint(x: 50, y: 50)
        var told: [Bool] = []

        init() {
            window.isReleasedWhenClosed = false
            region.pointer = { [unowned self] _ in pointer }
            region.told = { [unowned self] in told.append($0) }
        }

        func placed() async {
            window.contentView?.addSubview(region)
            await PagePointerTests.settle()
        }
    }

    /// What the region tells after AppKit's change, told: queued on the main queue, which runs it once the test lets
    /// go of the main actor.
    private static func settle() async {
        await Task.yield()
    }

    @Test func itsOneTrackingAreaHearsThePointerWhetherOrNotSitRepIsActive() throws {
        let region = PagePointerView(frame: .zero)
        let area = try #require(region.trackingAreas.first)

        #expect(region.trackingAreas.count == 1)
        #expect(area.options.isSuperset(of: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]))
    }

    @Test(arguments: [(NSPoint(x: 50, y: 50), true), (NSPoint(x: 150, y: 50), false)])
    func movedIntoAWindowItTellsWhetherThePointerIsOverIt(pointer: NSPoint, isOver: Bool) async {
        let hosted = Hosted()

        hosted.pointer = pointer
        await hosted.placed()
        #expect(hosted.told == [isOver])
    }

    @Test(arguments: [NSWindow.didBecomeKeyNotification, NSWindow.didDeminiaturizeNotification])
    func itFindsThePointerAsItsWindowAsks(_ asked: Notification.Name) async {
        let hosted = Hosted()

        hosted.pointer = NSPoint(x: 150, y: 50)
        await hosted.placed()
        hosted.pointer = NSPoint(x: 50, y: 50)
        NotificationCenter.default.post(name: asked, object: hosted.window)
        await Self.settle()
        #expect(hosted.told == [false, true])
    }

    @Test func outOfItsWindowThePointerIsOverItNoLongerNorDoesThatWindowAskIt() async {
        let hosted = Hosted()

        await hosted.placed()
        hosted.region.removeFromSuperview()
        await Self.settle()
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: hosted.window)
        await Self.settle()
        #expect(hosted.told == [true, false])
    }

    @Test func itTakesNoPress() {
        let region = PagePointerView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))

        #expect(region.hitTest(NSPoint(x: 50, y: 50)) == nil)
    }
}
