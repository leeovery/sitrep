@testable import SitRepNotices
import SitRepTestSupport
import Testing

/// The front handed back by hiding the helper, over an app and a clock of its own.
@MainActor
@Suite(.backstop)
struct FrontTests {
    @MainActor
    final class App {
        var isActive = false
        var hides = 0
        var now = ContinuousClock.now
    }

    private let app = App()

    private func front() -> Front {
        Front(isActive: { [app] in app.isActive }, hide: { [app] in app.hides += 1 }, now: { [app] in app.now })
    }

    @Test func activeItHidesAtOnce() {
        let front = front()

        app.isActive = true
        front.handBack()

        #expect(app.hides == 1)
    }

    /// A click that started the helper is told before macOS's activation lands.
    @Test func notYetActiveItHidesAsItBecomesActive() {
        let front = front()

        front.handBack()

        #expect(app.hides == 0)

        app.now += .milliseconds(300)
        front.activated()

        #expect(app.hides == 1)
    }

    /// An activation of its own, later, is never hidden.
    @Test func anActivationAfterASecondIsNotHidden() {
        let front = front()

        front.handBack()
        app.now += .milliseconds(1_200)
        front.activated()

        #expect(app.hides == 0)
    }

    @Test func itHidesForOneActivationAlone() {
        let front = front()

        front.handBack()
        front.activated()
        front.activated()

        #expect(app.hides == 1)
    }

    @Test func anActivationWithNothingToHandBackHidesNothing() {
        let front = front()

        front.activated()

        #expect(app.hides == 0)
    }
}
