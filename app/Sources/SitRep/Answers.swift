import SitRepCore
import SitRepRelay

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

    /// A banner's answer the notices helper relayed, sent at once, as a banner has nowhere to show an Undo.
    func send(_ answer: NoticeAnswer) {
        send(Answering(.words(answer.words), to: answer.ask, of: answer.session))
    }
}
