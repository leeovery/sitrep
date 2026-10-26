import Foundation
import SitRepRelay
import Testing

/// The relay's letters, through the userInfo a distributed notification carries.
struct LetterTests {
    private static let notice = Notice(title: "Pick a name", subtitle: "SitRep · Build the Mac app", body: "", work: "sr-aw3bgs")

    private static func carried<M: Relayed>(_ letter: Letter<M>) -> Letter<M>? {
        Letter(userInfo: letter.userInfo)
    }

    @Test(arguments: [
        ToHelper.ready, .post(notice), .post(Notice(title: "Not snoozed", subtitle: nil, body: "Gone", work: nil)),
        .status(id: "a"), .ask(id: "b"),
    ])
    func eachMessageToTheHelperArrivesAsSent(message: ToHelper) {
        let letter = Letter(message, pid: 4012)

        #expect(Self.carried(letter) == letter)
    }

    @Test(arguments: [ToSitRep.ready, .clicked(work: "sr-aw3bgs")] + NoticeLeave.all.map { ToSitRep.status($0, id: "c") })
    func eachMessageToSitRepArrivesAsSent(message: ToSitRep) {
        let letter = Letter(message, pid: 4012)

        #expect(Self.carried(letter) == letter)
    }

    @Test func aLetterIsAPlistAsADistributedNotificationMustCarry() {
        let userInfo = Letter(ToHelper.post(Self.notice), pid: 4012).userInfo

        #expect(PropertyListSerialization.propertyList(userInfo, isValidFor: .binary))
    }

    @Test func aLetterOpensOnlyForItsOwnSitRep() {
        let letter = Letter(ToSitRep.clicked(work: "sr-aw3bgs"), pid: 4012)

        #expect(letter.message(for: 4012) == .clicked(work: "sr-aw3bgs"))
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

    @Test func aStatusWithALeaveNotKnownIsNoLetter() {
        #expect(Letter<ToSitRep>(userInfo: ["kind": "status", "leave": "sometimes", "id": "c", "pid": "4012"]) == nil)
    }

    @Test func aUserInfoNotAllStringsIsNoLetter() {
        #expect(Letter<ToHelper>(userInfo: ["kind": "ready", "pid": 4012]) == nil)
    }
}
