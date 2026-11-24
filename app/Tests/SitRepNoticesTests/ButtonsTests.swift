@testable import SitRepNotices
import SitRepRelay
import SitRepTestSupport
import Testing
import UserNotifications

/// A new ask's banner's buttons (DESIGN, "The menu bar", "Its buttons"): the category each shape of ask is posted under,
/// a response read back to a click or an answer, and the whole set built to register. Built and read, never
/// registered.
@Suite(.backstop)
struct ButtonsTests {
    private static let yes = NoticeAsk(id: "k1", session: "sr-nw0001", wants: .yes("Go"))
    /// Two options alike but for their case, which only their places tell apart.
    private static let choice = NoticeAsk(
        id: "k2", session: "sr-nw0001", wants: .choice(["Left, the notch's edge", "Right", "right"])
    )
    private static let words = NoticeAsk(id: "k3", session: "sr-nw0001", wants: .words)

    /// Each button's title and options, and, for a text field, its button's words.
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

    // MARK: The buttons

    /// None brings an app forward, and each asks for the Mac unlocked.
    @Test func aYesHasOneButtonItsYes() {
        let category = Buttons.category(Self.yes, id: "b1")

        #expect(category.identifier == "b1")
        #expect(Self.drawn(category) == [Drawn(title: "Go", options: .authenticationRequired, send: nil)])
    }

    @Test func aChoiceHasAButtonForEachOptionInClaudesOrder() {
        let category = Buttons.category(Self.choice, id: "b2")

        #expect(Self.drawn(category) == ["Left, the notch's edge", "Right", "right"].map {
            Drawn(title: $0, options: .authenticationRequired, send: nil)
        })
    }

    @Test func aWordsAskHasReplyWithSend() {
        let category = Buttons.category(Self.words, id: "b3")

        #expect(Self.drawn(category) == [Drawn(title: "Reply", options: .authenticationRequired, send: "Send")])
        #expect(category.actions.map(\.identifier) == [Buttons.reply])
    }

    /// The banner carries its click's session beside its ask, so its body still jumps.
    @Test func aBannerCarriesItsSessionAndItsAsk() {
        let userInfo = Self.userInfo(Self.choice)

        #expect(Buttons.work(userInfo) == "sr-nw0001")
        #expect(Buttons.ask(userInfo) == Self.choice)
    }

    /// The test notification, a refusal's and Lee's turn's carry no ask, and no session where they name none.
    @Test func aBannerWithNoAskCarriesNone() {
        let userInfo = Buttons.userInfo(Notice(title: "Not answered", subtitle: nil, body: "Answered already", work: nil))

        #expect(userInfo.isEmpty)
    }

    // MARK: A response read

    @Test func eachButtonAnswersWithItsOwnOptionByItsPlace() {
        let userInfo = Self.userInfo(Self.choice)
        let answers = Buttons.category(Self.choice, id: "b2").actions.map {
            Buttons.answer(to: $0.identifier, typed: nil, userInfo: userInfo)
        }

        #expect(answers == ["Left, the notch's edge", "Right", "right"].map {
            NoticeAnswer(to: Self.choice, words: $0)
        })
    }

    @Test func aYesButtonAnswersItsAskWithItsYes() {
        let action = Buttons.category(Self.yes, id: "b1").actions[0].identifier

        #expect(Buttons.answer(to: action, typed: nil, userInfo: Self.userInfo(Self.yes)) == NoticeAnswer(
            to: Self.yes, words: "Go"
        ))
    }

    @Test func replyAnswersWithTheWordsTyped() {
        #expect(Buttons.answer(to: Buttons.reply, typed: " 12 passed, 0 failed\n", userInfo: Self.userInfo(Self.words))
            == NoticeAnswer(to: Self.words, words: "12 passed, 0 failed"))
    }

    /// Relayed with no words, for SitRep to say nothing went, as macOS has closed the banner.
    @Test(arguments: [nil, "", "  \n "])
    func replySentEmptyAnswersWithNoWords(typed: String?) {
        #expect(Buttons.answer(to: Buttons.reply, typed: typed, userInfo: Self.userInfo(Self.words)) == NoticeAnswer(
            to: Self.words, words: ""
        ))
    }

    /// An action the banner's ask has not, past its options, Reply on a choice, or one the helper never made.
    @Test(arguments: [
        ("answer.3", choice), ("answer.-1", choice), ("answer.", choice), ("Right", choice), (Buttons.reply, choice),
        ("answer.0", words), (UNNotificationDismissActionIdentifier, yes),
    ])
    func anActionNotOfItsAskAnswersNothing(action: String, ask: NoticeAsk) {
        #expect(Buttons.response(to: action, typed: "Right", userInfo: Self.userInfo(ask)) == Buttons.Response.none)
    }

    @Test func aBannerWithNoAskAnswersNothing() {
        #expect(Buttons.response(to: "answer.0", typed: nil, userInfo: ["work": "sr-nw0001"]) == Buttons.Response.none)
    }

    /// A click on a banner's body jumps, buttons or none, whatever was typed.
    @Test func aClickOnTheBodyIsAClickNamingItsSession() {
        let click = UNNotificationDefaultActionIdentifier

        #expect(
            Buttons.response(to: click, typed: "Go", userInfo: Self.userInfo(Self.yes)) == .click(work: "sr-nw0001")
        )
        #expect(Buttons.response(to: click, typed: nil, userInfo: [:]) == .click(work: nil))
    }

    @Test func aButtonOrReplyIsAnAnswer() {
        #expect(Buttons.response(to: "answer.1", typed: nil, userInfo: Self.userInfo(Self.choice))
            == .answer(NoticeAnswer(to: Self.choice, words: "Right")))
        #expect(Buttons.response(to: Buttons.reply, typed: "Done", userInfo: Self.userInfo(Self.words))
            == .answer(NoticeAnswer(to: Self.words, words: "Done")))
    }

    // MARK: The set registered

    /// `setNotificationCategories` replaces the whole set: each banner still delivered with an ask keeps its buttons,
    /// rebuilt from the ask it carries under its own id, beside those posted lately.
    @Test func theSetIsTheDeliveredBannersAndThoseLatelyPosted() {
        let categories = Buttons.categories(
            delivered: ["b1": Self.yes, "b3": Self.words], recent: [Buttons.category(Self.choice, id: "b4")]
        )

        #expect(Set(categories.map(\.identifier)) == ["b1", "b3", "b4"])
        #expect(categories.first { $0.identifier == "b1" }?.actions.map(\.title) == ["Go"])
        #expect(categories.first { $0.identifier == "b3" }?.actions.map(\.title) == ["Reply"])
    }

    /// One delivered that was also posted lately is in the set once.
    @Test func aBannerBothDeliveredAndLatelyPostedIsInTheSetOnce() {
        let categories = Buttons.categories(delivered: ["b1": Self.yes], recent: [Buttons.category(Self.yes, id: "b1")])

        #expect(categories.map(\.identifier) == ["b1"])
    }
}
