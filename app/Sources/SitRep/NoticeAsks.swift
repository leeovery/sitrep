import SitRepCore
import SitRepRelay

/// A new ask's banner's ask, between core's word for it and the relay's, which the helper reads without linking core:
/// the two shapes mirror each other, one each way.
extension NoticeAsk {
    init(_ ask: Banner.Ask) {
        let wants: Wants = switch ask.wants {
        case let .yes(yes): .yes(yes)
        case let .choice(options): .choice(options)
        case .words: .words
        }

        self.init(id: ask.id, session: ask.session, wants: wants)
    }
}

extension Banner.Ask {
    init(_ ask: NoticeAsk) {
        let wants: Wants = switch ask.wants {
        case let .yes(yes): .yes(yes)
        case let .choice(options): .choice(options)
        case .words: .words
        }

        self.init(id: ask.id, session: ask.session, wants: wants)
    }
}
