@testable import SitRepCore
import Testing

@MainActor
struct OneJumpTests {
    @Test func aJumpRunsWhenNoneIs() async {
        let oneJump = OneJump()
        var jumped = false

        #expect(await oneJump.run { jumped = true })
        #expect(jumped)
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
        #expect(!(await oneJump.run { Issue.record("a second jump ran beside the first") }))

        finish.yield()
        #expect(await first.value)
        #expect(!oneJump.isRunning)
        #expect(await oneJump.run {})
    }
}
