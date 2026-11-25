import SitRepCore

extension Answers {
    /// Lee's answers through the plugin's CLI, a refusal told in a banner `post` posts, as a snooze's is, naming the
    /// ask as `board`, the last one heard, shows it.
    convenience init(
        plugin: Plugin, post: @escaping @MainActor (Banner) -> Void, board: @escaping @MainActor () -> Board?
    ) {
        self.init(
            answer: { answering in
                await plugin.ask({ await $0.answer(answering) }, unrun: WriteAnswer.refused)
            },
            post: post,
            board: board
        )
    }
}
