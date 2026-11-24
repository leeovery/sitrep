import Foundation
import SitRepRelay
import UserNotifications

/// A new ask's banner's buttons (DESIGN, "The menu bar", "Its buttons"), under a category of the banner's own: a yes's
/// one button, a choice's options in Claude's order, or Reply with Send for a words ask; none brings an app forward. A
/// response is read back by the button's place among the ask's answers, which the banner's userInfo carries, never by
/// its title, which two options could share.
enum Buttons {
    /// The action of a words ask's Reply.
    static let reply = "reply"
    /// The userInfo key carrying the id of the work a banner jumps to.
    private static let workKey = "work"
    private static let answerPrefix = "answer."

    /// The category a banner answering this ask is posted under, by the banner's own id.
    static func category(_ ask: NoticeAsk, id: String) -> UNNotificationCategory {
        UNNotificationCategory(identifier: id, actions: actions(ask.wants), intentIdentifiers: [])
    }

    /// What a banner carries: the session its click jumps to, and the ask its buttons answer.
    static func userInfo(_ notice: Notice) -> [String: String] {
        (notice.ask?.fields ?? [:]).merging(notice.work.map { [workKey: $0] } ?? [:]) { _, work in work }
    }

    /// The session a banner's click jumps to, if it names one.
    static func work(_ userInfo: [AnyHashable: Any]) -> String? {
        userInfo[workKey] as? String
    }

    /// The answer a button's response gives: its answer's words, or the words typed in Reply; nil for an action not
    /// one of its ask's, or for Reply sent empty, which sends nothing.
    static func answer(to action: String, typed: String?, userInfo: [AnyHashable: Any]) -> NoticeAnswer? {
        guard let ask = (userInfo as? [String: String]).flatMap(NoticeAsk.init(fields:)) else {
            return nil
        }

        let words = action == reply ? replied(typed, to: ask) : pressed(action, of: ask)

        return words.map { NoticeAnswer(ask: ask.id, session: ask.session, words: $0) }
    }

    /// The categories to register as a banner is posted under `category`: its own, and those `needed` names, of the
    /// banners still delivered; every other dropped, as `setNotificationCategories` replaces the whole set.
    static func registered(
        _ categories: Set<UNNotificationCategory>, adding category: UNNotificationCategory, needed: Set<String>
    ) -> Set<UNNotificationCategory> {
        categories.filter { needed.contains($0.identifier) && $0.identifier != category.identifier }.union([category])
    }

    private static func actions(_ wants: NoticeAsk.Wants) -> [UNNotificationAction] {
        guard wants != .words else {
            return [
                UNTextInputNotificationAction(
                    identifier: reply, title: "Reply", options: [], textInputButtonTitle: "Send",
                    textInputPlaceholder: ""
                ),
            ]
        }

        return answers(wants).enumerated().map { index, words in
            UNNotificationAction(identifier: answerPrefix + String(index), title: words, options: [])
        }
    }

    /// The words each button answers with, in its order: a yes's, or a choice's options.
    private static func answers(_ wants: NoticeAsk.Wants) -> [String] {
        switch wants {
        case let .yes(yes): [yes]
        case let .choice(options): options
        case .words: []
        }
    }

    private static func pressed(_ action: String, of ask: NoticeAsk) -> String? {
        let answers = answers(ask.wants)

        guard action.hasPrefix(answerPrefix), let index = Int(action.dropFirst(answerPrefix.count)),
              answers.indices.contains(index)
        else {
            return nil
        }

        return answers[index]
    }

    private static func replied(_ typed: String?, to ask: NoticeAsk) -> String? {
        let words = typed?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ask.wants == .words && !words.isEmpty ? words : nil
    }
}
