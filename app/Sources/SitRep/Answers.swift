import SitRepCore

extension Answers {
    /// Lee's answers through the plugin's CLI, a refusal told in a banner `post` posts, as a snooze's is.
    convenience init(plugin: Plugin, post: @escaping @MainActor (Banner) -> Void) {
        self.init(
            answer: { answering in
                await plugin.ask(
                    { await $0.answer(answering.ask, of: answering.session, with: answering.answer) },
                    unrun: WriteAnswer.refused
                )
            },
            post: post
        )
    }
}
