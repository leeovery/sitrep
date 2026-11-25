import SitRepCore
import SitRepRelay

/// A new ask's banner's ask, in the relay's words, which the helper reads without linking core.
extension NoticeAsk {
    init(_ ask: AskOf) {
        self.init(id: ask.ask, session: ask.session)
    }
}
