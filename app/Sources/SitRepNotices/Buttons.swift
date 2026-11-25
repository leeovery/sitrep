import Foundation
import SitRepRelay
import UserNotifications

/// A new ask's banner's buttons (DESIGN, "The menu bar", "Its buttons"), under a category of the banner's own: a yes's
/// one button, a choice's options Claude's pick first, or Reply with Send for a words ask. None brings an app forward,
/// and each asks for the Mac unlocked, so no answer goes from a locked screen. A response is read back by the button's
/// place among the ask's answers, which the banner's userInfo carries, never by its title, which two options could
/// share.
enum Buttons {
    /// What a response to a banner is.
    enum Response: Equatable, Sendable {
        /// A click on its body, naming the session it jumps to, if any.
        case click(work: String?)
        case answer(NoticeAnswer)
        /// An action not of its ask's, passed over.
        case passedOver
    }

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

    /// The ask a banner's buttons answer, if it has any.
    static func ask(_ userInfo: [AnyHashable: Any]) -> NoticeAsk? {
        (userInfo as? [String: String]).flatMap(NoticeAsk.init(fields:))
    }

    /// A response read: a click on the banner's body (`UNNotificationDefaultActionIdentifier`), or one of its buttons.
    static func response(to action: String, typed: String?, userInfo: [AnyHashable: Any]) -> Response {
        guard action != UNNotificationDefaultActionIdentifier else {
            return .click(work: work(userInfo))
        }

        return answer(to: action, typed: typed, userInfo: userInfo).map(Response.answer) ?? .passedOver
    }

    /// The answer a button's response gives: its answer's words, or the words typed in Reply, trimmed, empty where
    /// none were, for SitRep to say nothing went; nil for an action not one of its ask's.
    static func answer(to action: String, typed: String?, userInfo: [AnyHashable: Any]) -> NoticeAnswer? {
        guard let ask = ask(userInfo) else {
            return nil
        }

        let words = action == reply ? replied(typed, to: ask) : pressed(action, of: ask)

        return words.map { NoticeAnswer(to: ask, words: $0) }
    }

    /// The whole set to register, as `setNotificationCategories` replaces it: a category for each banner still
    /// delivered with an ask, by its request's id, and those `recent`ly posted, which Notification Center may not list
    /// as delivered yet. Built from what is known, never read back, as a read may miss a set not yet landed.
    static func categories(
        delivered: [String: NoticeAsk], recent: [UNNotificationCategory]
    ) -> Set<UNNotificationCategory> {
        let all = delivered.map { category($1, id: $0) } + recent
        let byId = Dictionary(all.map { ($0.identifier, $0) }) { _, recent in recent }

        return Set(byId.values)
    }

    private static func actions(_ wants: NoticeAsk.Wants) -> [UNNotificationAction] {
        guard wants != .words else {
            return [
                UNTextInputNotificationAction(
                    identifier: reply, title: "Reply", options: .authenticationRequired, textInputButtonTitle: "Send",
                    textInputPlaceholder: ""
                ),
            ]
        }

        return answers(wants).enumerated().map { index, words in
            UNNotificationAction(
                identifier: answerPrefix + String(index), title: words, options: .authenticationRequired
            )
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
        ask.wants == .words ? typed?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" : nil
    }
}
