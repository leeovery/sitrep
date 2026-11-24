@testable import SitRepNotices
import SitRepRelay
import SitRepTestSupport
import Testing
import UserNotifications

/// A new ask's banner's buttons (DESIGN, "The menu bar", "Its buttons"): the category each shape of ask is posted under,
/// a response read back to its answer, and the categories kept as each banner posts. Built and read, never registered.
@Suite(.backstop)
struct ButtonsTests {
    private static let yes = NoticeAsk(id: "k1", session: "sr-nw0001", wants: .yes("Go"))
    /// Two options alike but for their case, which only their places tell apart.
    private static let choice = NoticeAsk(
        id: "k2", session: "sr-nw0001", wants: .choice(["Left, the notch's edge", "Right", "right"])
    )
    private static let words = NoticeAsk(id: "k3", session: "sr-nw0001", wants: .words)

    /// Each button's title and options, and whether it is a text field, its button's words and placeholder.
    private struct Drawn: Equatable {
        let title: String
        let options: UNNotificationActionOptions
        let send: String?
    }

    private static func drawn(_ category: UNNotificationCategory) -> [Drawn] {
        category.actions.map { action in
            Drawn(
                title: action.title, options: action.options,
                send: (action as? UNTextInputNotificationAction)?.textInputButtonTitle
            )
        }
    }

    private static func userInfo(_ ask: NoticeAsk) -> [AnyHashable: Any] {
        Buttons.userInfo(Notice(title: "Pick the export format", subtitle: nil, body: "", work: ask.session, ask: ask))
    }

    @Test func aYesHasOneButtonItsYesBringingNothingForward() {
        let category = Buttons.category(Self.yes, id: "b1")

        #expect(category.identifier == "b1")
        #expect(Self.drawn(category) == [Drawn(title: "Go", options: [], send: nil)])
    }

    @Test func aChoiceHasAButtonForEachOptionInClaudesOrder() {
        let category = Buttons.category(Self.choice, id: "b2")

        #expect(Self.drawn(category).map(\.title) == ["Left, the notch's edge", "Right", "right"])
        #expect(category.actions.allSatisfy { $0.options.isEmpty && !($0 is UNTextInputNotificationAction) })
    }

    @Test func aWordsAskHasReplyWithSend() {
        let category = Buttons.category(Self.words, id: "b3")

        #expect(Self.drawn(category) == [Drawn(title: "Reply", options: [], send: "Send")])
        #expect(category.actions.map(\.identifier) == [Buttons.reply])
    }

    /// The banner carries its click's session beside its ask, so its body still jumps.
    @Test func aBannerCarriesItsSessionAndItsAsk() {
        let userInfo = Self.userInfo(Self.choice)

        #expect(Buttons.work(userInfo) == "sr-nw0001")
        #expect(NoticeAsk(fields: userInfo as? [String: String] ?? [:]) == Self.choice)
    }

    /// The test notification, a refusal's and Lee's turn's carry no ask, and no session where they name none.
    @Test func aBannerWithNoAskCarriesNone() {
        let userInfo = Buttons.userInfo(Notice(title: "Not answered", subtitle: nil, body: "Answered already", work: nil))

        #expect(userInfo.isEmpty)
    }

    @Test func eachButtonAnswersWithItsOwnOptionByItsPlace() {
        let userInfo = Self.userInfo(Self.choice)
        let answers = Buttons.category(Self.choice, id: "b2").actions.map {
            Buttons.answer(to: $0.identifier, typed: nil, userInfo: userInfo)?.words
        }

        #expect(answers == ["Left, the notch's edge", "Right", "right"])
    }

    @Test func aYesButtonAnswersItsAskWithItsYes() {
        let action = Buttons.category(Self.yes, id: "b1").actions[0].identifier

        #expect(Buttons.answer(to: action, typed: nil, userInfo: Self.userInfo(Self.yes)) == NoticeAnswer(
            ask: "k1", session: "sr-nw0001", words: "Go"
        ))
    }

    @Test func replyAnswersWithTheWordsTyped() {
        #expect(Buttons.answer(to: Buttons.reply, typed: " 12 passed, 0 failed\n", userInfo: Self.userInfo(Self.words))
            == NoticeAnswer(ask: "k3", session: "sr-nw0001", words: "12 passed, 0 failed"))
    }

    @Test(arguments: [nil, "", "  \n "])
    func replySentEmptySendsNothing(typed: String?) {
        #expect(Buttons.answer(to: Buttons.reply, typed: typed, userInfo: Self.userInfo(Self.words)) == nil)
    }

    /// An action the banner's ask has not, past its options, Reply on a choice, or one the helper never made.
    @Test(arguments: [
        ("answer.3", choice), ("answer.-1", choice), ("answer.", choice), ("Right", choice), (Buttons.reply, choice),
        ("answer.0", words), (UNNotificationDismissActionIdentifier, yes),
    ])
    func anActionNotOfItsAskAnswersNothing(action: String, ask: NoticeAsk) {
        #expect(Buttons.answer(to: action, typed: "Right", userInfo: Self.userInfo(ask)) == nil)
    }

    @Test func aBannerWithNoAskAnswersNothing() {
        #expect(Buttons.answer(to: "answer.0", typed: nil, userInfo: ["work": "sr-nw0001"]) == nil)
    }

    /// `setNotificationCategories` replaces the whole set: a banner still delivered keeps its buttons, one gone gives
    /// its category up, and the banner posting adds its own.
    @Test func registeringKeepsWhatDeliveredBannersNeedAndDropsTheRest() {
        let registered: Set = [
            Buttons.category(Self.yes, id: "b1"), Buttons.category(Self.choice, id: "b2"),
            Buttons.category(Self.words, id: "b3"),
        ]
        let adding = Buttons.category(Self.yes, id: "b4")

        let kept = Buttons.registered(registered, adding: adding, needed: ["b1", "b3", "b9"])

        #expect(Set(kept.map(\.identifier)) == ["b1", "b3", "b4"])
        #expect(kept.first { $0.identifier == "b3" }?.actions.first?.title == "Reply")
    }

    @Test func registeringWithNothingDeliveredKeepsTheNewOneAlone() {
        let kept = Buttons.registered(
            [Buttons.category(Self.yes, id: "b1")], adding: Buttons.category(Self.words, id: "b2"), needed: []
        )

        #expect(kept.map(\.identifier) == ["b2"])
    }
}
