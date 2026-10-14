@testable import SitRepCore
import Testing

@MainActor
struct OneJumpTests {
    @Test func aJumpRunsWhenNoneIs() async {
        let oneJump = OneJump()
        #expect(await oneJump.run { JumpAnswer.jumped } == .jumped)
        #expect(!oneJump.isRunning)
    }

    @Test func aSecondJumpWhileOneRunsIsRefused() async {
        let oneJump = OneJump()
        let (started, start) = AsyncStream<Void>.makeStream()
        let (finished, finish) = AsyncStream<Void>.makeStream()
        let first = Task {
            await oneJump.run {
                start.yield()
                for await _ in finished { break }
            }
        }

        for await _ in started { break }
        #expect(oneJump.isRunning)
        #expect(await oneJump.run { Issue.record("a second jump ran beside the first") } == nil)

        finish.yield()
        #expect(await first.value != nil)
        #expect(!oneJump.isRunning)
        #expect(await oneJump.run { JumpAnswer.refused("Fumi is not on screen.") } == .refused("Fumi is not on screen."))
    }
}
