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

    /// A banner's answer the notices helper relayed, sent at once, as a banner has nowhere to show an Undo, unless it
    /// cannot answer the ask as `board` holds it.
    func send(_ answer: NoticeAnswer, on board: Board?) {
        send(answer.words, from: Banner.Ask(answer.ask), on: board)
    }
}

private extension Banner.Ask {
    init(_ ask: NoticeAsk) {
        let wants: Wants = switch ask.wants {
        case let .yes(yes): .yes(yes)
        case let .choice(options): .choice(options)
        case .words: .words
        }

        self.init(id: ask.id, session: ask.session, wants: wants)
    }
}
