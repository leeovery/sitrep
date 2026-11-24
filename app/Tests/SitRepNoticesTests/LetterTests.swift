import Foundation
import SitRepRelay
import SitRepTestSupport
import Testing

/// The relay's letters, through the userInfo a distributed notification carries.
@Suite(.backstop)
struct LetterTests {
    private static let notice = Notice(title: "Pick a name", subtitle: "Trey Research · Build the desktop app", body: "", work: "sr-a8n2xc")

    private static func withAsk(_ ask: NoticeAsk) -> Notice {
        Notice(title: notice.title, subtitle: notice.subtitle, body: notice.body, work: notice.work, ask: ask)
    }

    private static func carried<M: Relayed>(_ letter: Letter<M>) -> Letter<M>? {
        Letter(userInfo: letter.userInfo)
    }

    @Test(arguments: [
        ToHelper.ready, .handBack, .post(notice), .post(Notice(title: "Not snoozed", subtitle: nil, body: "Gone", work: nil)),
        .status(id: "a"), .ask(id: "b"),
    ])
    func eachMessageToTheHelperArrivesAsSent(message: ToHelper) {
        let letter = Letter(message, pid: 4012)

        #expect(Self.carried(letter) == letter)
    }

    /// A new ask's banner carries its ask whatever it wants: a yes's words, a choice's options in Claude's order, or
    /// words.
    @Test(arguments: [
        NoticeAsk.Wants.yes("Go"), .choice(["Left, the notch's edge", "Right", "Both"]), .choice(["Only"]), .words,
    ])
    func aNewAsksBannerArrivesWithItsAsk(wants: NoticeAsk.Wants) {
        let ask = NoticeAsk(id: "k2", session: "sr-a8n2xc", wants: wants)
        let letter = Letter(ToHelper.post(Self.withAsk(ask)), pid: 4012)

        #expect(Self.carried(letter) == letter)
        #expect(PropertyListSerialization.propertyList(letter.userInfo, isValidFor: .binary))
    }

    /// A post from before banners had buttons, or one whose ask does not read, is a banner with none.
    @Test(arguments: [
        [:],
        ["ask": "k2", "session": "sr-a8n2xc", "wants": "a drawing"],
        ["ask": "k2", "session": "sr-a8n2xc", "wants": "choice"],
        ["ask": "k2", "session": "sr-a8n2xc", "wants": "yes"],
        ["ask": "k2", "wants": "words"],
        ["session": "sr-a8n2xc", "wants": "words"],
    ])
    func aPostWhoseAskDoesNotReadIsABannerWithNoButtons(ask: [String: String]) {
        let post = ["kind": "post", "title": "Pick a name", "body": "", "work": "sr-a8n2xc", "pid": "4012"]
        let fields = ask.merging(post) { ask, _ in ask }

        #expect(Letter<ToHelper>(userInfo: fields)?.message == .post(Notice(
            title: "Pick a name", subtitle: nil, body: "", work: "sr-a8n2xc"
        )))
    }

    /// The options read in their order, up to the first missing: none past a gap.
    @Test func aChoicesOptionsReadInOrderToTheFirstGap() {
        let fields = [
            "ask": "k2", "session": "sr-a8n2xc", "wants": "choice", "option.0": "Left", "option.1": "Right",
            "option.3": "Lost",
        ]

        #expect(NoticeAsk(fields: fields)?.wants == .choice(["Left", "Right"]))
    }

    @Test(arguments: [ToSitRep.ready(helper: 5150), .clicked(work: "sr-a8n2xc")] + NoticeLeave.all.map { ToSitRep.status($0, id: "c") })
    func eachMessageToSitRepArrivesAsSent(message: ToSitRep) {
        let letter = Letter(message, pid: 4012)

        #expect(Self.carried(letter) == letter)
    }

    /// A button's answer, or the words typed in Reply.
    @Test(arguments: ["Right", "12 passed, 0 failed"])
    func anAnswerArrivesAsSent(words: String) {
        let letter = Letter(ToSitRep.answered(NoticeAnswer(ask: "k2", session: "sr-a8n2xc", words: words)), pid: 4012)

        #expect(Self.carried(letter) == letter)
    }

    @Test func aLetterIsAPlistAsADistributedNotificationMustCarry() {
        let userInfo = Letter(ToHelper.post(Self.notice), pid: 4012).userInfo

        #expect(PropertyListSerialization.propertyList(userInfo, isValidFor: .binary))
    }

    @Test func aLetterOpensOnlyForItsOwnSitRep() {
        let letter = Letter(ToSitRep.clicked(work: "sr-a8n2xc"), pid: 4012)

        #expect(letter.message(for: 4012) == .clicked(work: "sr-a8n2xc"))
        #expect(letter.message(for: 977) == nil)
    }

    @Test(arguments: [
        ["kind": "ready"],
        ["kind": "wave", "pid": "4012"],
        ["kind": "post", "body": "No title", "pid": "4012"],
        ["kind": "status", "pid": "4012"],
        ["kind": "ready", "pid": "not a pid"],
    ])
    func anythingElseIsNoLetter(userInfo: [String: String]) {
        #expect(Letter<ToHelper>(userInfo: userInfo) == nil)
    }

    @Test(arguments: [
        ["kind": "status", "leave": "sometimes", "id": "c", "pid": "4012"],
        ["kind": "ready", "pid": "4012"],
        ["kind": "ready", "helper": "not a pid", "pid": "4012"],
        ["kind": "answered", "ask": "k2", "session": "sr-a8n2xc", "pid": "4012"],
        ["kind": "answered", "session": "sr-a8n2xc", "words": "Right", "pid": "4012"],
        ["kind": "answered", "ask": "k2", "words": "Right", "pid": "4012"],
    ])
    func toSitRepAnythingElseIsNoLetter(userInfo: [String: String]) {
        #expect(Letter<ToSitRep>(userInfo: userInfo) == nil)
    }

    @Test func aUserInfoNotAllStringsIsNoLetter() {
        #expect(Letter<ToHelper>(userInfo: ["kind": "ready", "pid": 4012]) == nil)
    }
}
