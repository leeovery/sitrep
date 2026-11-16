import Foundation
import SitRepRelay
import Testing

/// The relay's letters, through the userInfo a distributed notification carries.
struct LetterTests {
    private static let notice = Notice(title: "Pick a name", subtitle: "Trey Research · Build the desktop app", body: "", work: "sr-a8n2xc")

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

    @Test(arguments: [ToSitRep.ready(helper: 5150), .clicked(work: "sr-a8n2xc")] + NoticeLeave.all.map { ToSitRep.status($0, id: "c") })
    func eachMessageToSitRepArrivesAsSent(message: ToSitRep) {
        let letter = Letter(message, pid: 4012)

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
    ])
    func toSitRepAnythingElseIsNoLetter(userInfo: [String: String]) {
        #expect(Letter<ToSitRep>(userInfo: userInfo) == nil)
    }

    @Test func aUserInfoNotAllStringsIsNoLetter() {
        #expect(Letter<ToHelper>(userInfo: ["kind": "ready", "pid": 4012]) == nil)
    }
}
