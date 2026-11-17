import CoreServices
import Darwin
import Foundation
import os
@testable import SitRepScreen
import SitRepTestSupport
import Testing

/// A descriptor in words, as AEDebug prints it but shorter: a specifier or a test by its fields, a list by its items,
/// a code as its four characters after its type's (`type'Gtrm'`, `enum'test'`, `abso'all '`), text quoted. Its whole
/// data is read, the length before the value: a code not four bytes long, or a null or the examined object carrying
/// any, AppleScript never sends, so it is rendered by its type and length alone, matching no expectation.
func rendered(_ descriptor: NSAppleEventDescriptor?) -> String {
    guard let descriptor else {
        return "none"
    }

    let field = { (key: String) in rendered(descriptor.forKeyword(code(key))) }
    let type = descriptor.descriptorType
    let length = descriptor.data.count
    let unlike = "\(fourCharacters(type))(\(length) bytes)"

    switch type {
    case typeObjectSpecifier:
        return "obj{want:\(field("want")),from:\(field("from")),form:\(field("form")),seld:\(field("seld"))}"
    case typeCompDescriptor:
        return "cmpd{relo:\(field("relo")),obj1:\(field("obj1")),obj2:\(field("obj2"))}"
    case typeAEList:
        return "[" + (0..<descriptor.numberOfItems).map { rendered(descriptor.atIndex($0 + 1)) }.joined(separator: ",") + "]"
    case typeNull:
        return length == 0 ? "null" : unlike
    case typeObjectBeingExamined:
        return length == 0 ? "exmn" : unlike
    case typeUnicodeText:
        return "\"\(descriptor.stringValue ?? "")\""
    case typeAERecord:
        return "reco{" + fields(of: descriptor).map { "\($0):\($1)" }.joined(separator: ",") + "}"
    case typeType, typeEnumerated, typeAbsoluteOrdinal:
        guard length == MemoryLayout<FourCharCode>.size else {
            return unlike
        }

        let value = descriptor.data.withUnsafeBytes { $0.loadUnaligned(as: FourCharCode.self) }

        return "\(fourCharacters(type))'\(fourCharacters(value))'"
    default:
        return "\(fourCharacters(type))(\(descriptor.stringValue ?? ""))"
    }
}

/// A record's fields, or an event's parameters, each by its keyword's four characters, in the order they are kept,
/// rendered.
func fields(of descriptor: NSAppleEventDescriptor) -> [(String, String)] {
    (0..<descriptor.numberOfItems).map { index in
        let keyword = descriptor.keywordForDescriptor(at: index + 1)

        return (fourCharacters(keyword), rendered(descriptor.forKeyword(keyword)))
    }
}

func fourCharacters(_ code: FourCharCode) -> String {
    String(decoding: [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }, as: UTF8.self)
}

/// A reply as Ghostty gives one: its direct object, or an error by its number, with any words.
func reply(_ direct: NSAppleEventDescriptor? = nil, error: Int32? = nil, said: String? = nil) -> NSAppleEventDescriptor {
    let reply = NSAppleEventDescriptor.appleEvent(
        withEventClass: code("aevt"), eventID: code("ansr"), targetDescriptor: nil,
        returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
    )

    direct.map { reply.setParam($0, forKeyword: keyDirectObject) }
    error.map { reply.setParam(NSAppleEventDescriptor(int32: $0), forKeyword: keyErrorNumber) }
    said.map { reply.setParam(NSAppleEventDescriptor(string: $0), forKeyword: keyErrorString) }
    return reply
}

func list(_ items: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor {
    let list = NSAppleEventDescriptor.list()

    items.enumerated().forEach { list.insert($1, at: $0 + 1) }
    return list
}

/// An object as Ghostty names one in an answer: by its id.
func named(_ type: String, _ id: String) -> NSAppleEventDescriptor {
    let specifier = NSAppleEventDescriptor.record().coerce(toDescriptorType: typeObjectSpecifier) ?? NSAppleEventDescriptor.record()

    specifier.setDescriptor(NSAppleEventDescriptor(typeCode: code(type)), forKeyword: code("want"))
    specifier.setDescriptor(NSAppleEventDescriptor.null(), forKeyword: code("from"))
    specifier.setDescriptor(NSAppleEventDescriptor(enumCode: code("ID  ")), forKeyword: code("form"))
    specifier.setDescriptor(NSAppleEventDescriptor(string: id), forKeyword: code("seld"))
    return specifier
}

/// Ghostty's side of the events: each event sent kept, in words, with its time limit and the process it went to; each
/// answered in turn, as made when it is sent.
final class Answering: Sendable {
    typealias Answer = @Sendable () -> GhosttyEvents.Sent

    /// An event: its class and id, its direct object, `none` for none, its time limit, its process, and any other
    /// parameters, by keyword.
    struct Asked: Equatable {
        let event: String
        let direct: String
        let seconds: TimeInterval
        let pid: pid_t
        var parameters: [String: String] = [:]
    }

    private let answers: [Answer]
    private let state = OSAllocatedUnfairLock(initialState: [Asked]())

    init(sending answers: [Answer]) {
        self.answers = answers
    }

    /// Ghostty replying to each in turn, every send going through.
    convenience init(_ replies: [@Sendable () -> NSAppleEventDescriptor]) {
        self.init(sending: replies.map { reply in { GhosttyEvents.Sent(status: 0, reply: reply()) } })
    }

    var asked: [Asked] { state.withLock { $0 } }

    /// The events, sent to process 501.
    var events: GhosttyEvents {
        GhosttyEvents(ghostty: { 501 }) { [self] event, seconds in send(event, seconds) }
    }

    private func send(_ event: NSAppleEventDescriptor, _ seconds: TimeInterval) -> GhosttyEvents.Sent {
        let pid = event.attributeDescriptor(forKeyword: keyAddressAttr)?.data.withUnsafeBytes { $0.loadUnaligned(as: pid_t.self) }
        let asked = Asked(
            event: fourCharacters(event.eventClass) + fourCharacters(event.eventID),
            direct: rendered(event.paramDescriptor(forKeyword: keyDirectObject)), seconds: seconds, pid: pid ?? 0,
            parameters: Dictionary(uniqueKeysWithValues: fields(of: event).filter { $0.0 != "----" })
        )
        let index = state.withLock { state in
            state.append(asked)
            return state.count - 1
        }

        return answers[min(index, answers.count - 1)]()
    }
}

/// A send the Apple Event Manager failed, by its error's number, as at the event's time limit or with the leave to
/// control Ghostty refused: its reply empty, or, where Ghostty's handler gave the error, saying it with Ghostty's words.
func unsent(_ number: Int, said: String? = nil) -> Answering.Answer {
    { GhosttyEvents.Sent(status: number, reply: said.map { reply(error: Int32(number), said: $0) } ?? reply()) }
}

/// A send that went through, its reply saying an error, by its number, with any words, as a handler's failing gives one.
func replied(_ number: Int32, said: String? = nil) -> Answering.Answer {
    { GhosttyEvents.Sent(status: 0, reply: reply(error: number, said: said)) }
}

/// Ghostty's events built by hand as AppleScript builds the CLI's program, each to the Ghostty running, within five
/// seconds, and their answers read, the codes from Ghostty's dictionary.
@Suite(.backstop)
struct GhosttyEventsTests {
    private static let device = "/dev/ttys041"

    /// `tty of terminals contains` the device, in a whose clause.
    private static let holding = "cmpd{relo:enum'cont',obj1:obj{want:type'prop',from:obj{want:type'Gtrm',from:exmn,form:enum'indx',seld:abso'all '},form:enum'prop',seld:type'Gtty'},obj2:\"\(device)\"}"

    private static var terminal: NSAppleEventDescriptor {
        named("Gtrm", "T1")
    }

    @Test func theLookupGetsTheTerminalsWhoseTtyIsTheDeviceFromTheGhosttyRunningWithinFiveSeconds() async throws {
        let answering = Answering([{ reply(list([Self.terminal])) }])

        #expect(try await answering.events.terminal(on: Self.device) != nil)
        #expect(answering.asked == [Answering.Asked(
            event: "coregetd",
            direct: "obj{want:type'Gtrm',from:null,form:enum'test',seld:cmpd{relo:enum'=   ',obj1:obj{want:type'prop',from:exmn,form:enum'prop',seld:type'Gtty'},obj2:\"\(Self.device)\"}}",
            seconds: 5, pid: 501
        )])
        #expect(GhosttyEvents.answerSeconds == 5)
    }

    @Test func theTabsQuestionGetsWhetherTheTabsOfTheWindowsHoldingTheTerminalThatHoldItAreSelected() async throws {
        let answering = Answering([{ reply(list([list([NSAppleEventDescriptor(boolean: true)])])) }])

        _ = try await answering.events.isTabSelected(holding: Self.device)

        #expect(answering.asked.map(\.event) == ["coregetd"])
        #expect(answering.asked.first?.direct == "obj{want:type'prop',from:obj{want:type'Gtab',from:obj{want:type'Gwnd',from:null,form:enum'test',seld:\(Self.holding)},form:enum'test',seld:\(Self.holding)},form:enum'prop',seld:type'GTsl'}")
    }

    @Test func onlyATabAnsweredFalseInAListOfOneWindowsOneTabIsNotSelectedATerminalInNoWindowIsFocusedAsSelected() async throws {
        let no = NSAppleEventDescriptor(boolean: false)
        let typedFalse = try #require(NSAppleEventDescriptor(descriptorType: typeFalse, data: nil))
        let typedTrue = try #require(NSAppleEventDescriptor(descriptorType: typeTrue, data: nil))
        let cases: [(NSAppleEventDescriptor, Bool)] = [
            (list([list([no])]), false),
            (list([list([NSAppleEventDescriptor(boolean: true)])]), true),
            (list([list([no]), list([no])]), true),
            (list([list([no, no])]), true),
            (list([list([NSAppleEventDescriptor(int32: 0)])]), true),
            (list([list([typedFalse])]), false),
            (list([list([typedTrue])]), true),
            (list([]), true),
        ]

        for (answer, isSelected) in cases {
            let answer = Sendably(answer)
            let events = Answering([{ reply(answer.descriptor) }]).events
            let answered = try await events.isTabSelected(holding: Self.device)

            #expect(answered == isSelected, "\(answer.descriptor)")
        }
    }

    @Test func theFocusIsGhosttysFocusOfTheTerminalAsTheLookupNamedIt() async throws {
        let answering = Answering([{ reply(list([Self.terminal])) }, { reply() }])
        let found = try #require(try await answering.events.terminal(on: Self.device))

        try await answering.events.focus(found)

        #expect(answering.asked.map(\.event) == ["coregetd", "GhstFcus"])
        #expect(answering.asked.last?.direct == "obj{want:type'Gtrm',from:null,form:enum'ID  ',seld:\"T1\"}")
    }

    @Test func aWindowIsActivatedAsGhosttyNamesTheWindowHoldingTheTerminalByActivateWindow() async throws {
        let answering = Answering([{ reply(list([named("Gwnd", "tab-group-1")])) }, { reply() }])

        try await answering.events.activateWindow(holding: Self.device)

        #expect(answering.asked.map(\.event) == ["coregetd", "GhstAcWn"])
        #expect(answering.asked.first?.direct == "obj{want:type'Gwnd',from:null,form:enum'test',seld:\(Self.holding)}")
        #expect(answering.asked.last?.direct == "obj{want:type'Gwnd',from:null,form:enum'ID  ',seld:\"tab-group-1\"}")
    }

    @Test func noWindowHoldingTheTerminalAsOneClosedSinceItWasFoundFailsAsAppleScriptFailsToFindTheFirstOfNothing() async {
        await #expect(throws: GhosttyFailure.gave(-1719, said: nil)) {
            try await Answering([{ reply(list([])) }]).events.activateWindow(holding: Self.device)
        }
    }

    @Test func ghosttyNotRunningIsSentNothingWhichWouldLaunchItAndHasNoTerminalOnTheDevice() async throws {
        let sent = OSAllocatedUnfairLock(initialState: 0)
        let events = GhosttyEvents(ghostty: { nil }) { _, _ in
            sent.withLock { $0 += 1 }
            return GhosttyEvents.Sent(status: 0, reply: reply())
        }

        #expect(try await events.terminal(on: Self.device) == nil)
        #expect(sent.withLock { $0 } == 0)
    }

    @Test func aLookupAnsweringNoneOrNothingIsNoTerminalOnTheDevice() async throws {
        for answer in [Answering([{ reply(list([])) }]), Answering([{ reply() }])] {
            #expect(try await answer.events.terminal(on: Self.device) == nil)
        }
    }

    /// The errors a lookup, the first event, which names the terms a Ghostty before 1.4 lacks, is read as: too old
    /// where it does not know the event (-1708) or a term in it (-1728); not answering in time (-1712); else its error,
    /// with the words Ghostty's reply gave, whether the send failed by it or went through saying it.
    @Test(arguments: [
        (unsent(-1712), GhosttyFailure.noAnswer),
        (unsent(-1743), .gave(-1743, said: nil)),
        (unsent(-1708), .tooOld),
        (unsent(-1728), .tooOld),
        (unsent(-10000, said: "AppleEvent handler failed."), .gave(-10000, said: "AppleEvent handler failed.")),
        (replied(-1728, said: "Can’t get every terminal whose tty = \"/dev/ttys041\"."), .tooOld),
        (replied(-1708), .tooOld),
        (replied(-10000, said: "AppleEvent handler failed."), .gave(-10000, said: "AppleEvent handler failed.")),
    ] as [(Answering.Answer, GhosttyFailure)])
    func aLookupsErrorsAreReadInPlainWords(answer: @escaping Answering.Answer, failure: GhosttyFailure) async {
        await #expect(throws: failure) {
            try await Answering(sending: [answer]).events.terminal(on: Self.device)
        }
    }

    /// A later event's no such object is a terminal gone since it was found, not a Ghostty too old; its error keeps
    /// Ghostty's words, however the send told it.
    @Test func onlyTheLookupsUnknownTermsReadAsTooOldAFocusFailingSoIsItsErrorInGhosttysWords() async throws {
        let gone = "Can’t get terminal id \"T1\"."
        let found = try #require(try await Answering([{ reply(list([Self.terminal])) }]).events.terminal(on: Self.device))

        for failing in [replied(-1728, said: gone), unsent(-1728, said: gone)] {
            await #expect(throws: GhosttyFailure.gave(-1728, said: gone)) {
                try await Answering(sending: [failing]).events.focus(found)
            }
        }
        await #expect(throws: GhosttyFailure.noAnswer) {
            try await Answering(sending: [unsent(-1712)]).events.focus(found)
        }
    }

    // MARK: A window opened

    /// Ghostty's defaults for a new surface, as `new surface configuration` answers: a record of its fields.
    private static var configuration: NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()

        record.setDescriptor(NSAppleEventDescriptor(string: "/Users/me"), forKeyword: code("GScD"))
        return record
    }

    /// `focused terminal of selected tab of` the window Ghostty named.
    private static let newTerminal = "obj{want:type'prop',from:obj{want:type'prop',from:obj{want:type'Gwnd',from:null,form:enum'ID  ',seld:\"tab-group-9\"},form:enum'prop',seld:type'GWsT'},form:enum'prop',seld:type'GTfT'}"

    /// The probe's way, live on 10 November 2026: a new surface configuration, its `initial input` the command and a
    /// return, Ghostty's other defaults kept, and a new window with it; never `command`.
    @Test func aWindowIsOpenedWithANewConfigurationWhoseInitialInputIsTheCommandAndAReturn() async throws {
        let answering = Answering([{ reply(Self.configuration) }, { reply(named("Gwnd", "tab-group-9")) }])

        _ = try await answering.events.openWindow(running: "zmx attach 'litware · restore-card'", sending: {})

        #expect(answering.asked == [
            Answering.Asked(event: "GhstNSCf", direct: "none", seconds: 5, pid: 501),
            Answering.Asked(
                event: "GhstNWin", direct: "none", seconds: 5, pid: 501,
                parameters: ["GNwS": "reco{GScD:\"/Users/me\",GScI:\"zmx attach 'litware · restore-card'\n\"}"]
            ),
        ])
    }

    @Test func theNewWindowsTerminalIsTheFocusedTerminalOfItsSelectedTabWhichTheFocusNames() async throws {
        let answering = Answering([{ reply(Self.configuration) }, { reply(named("Gwnd", "tab-group-9")) }, { reply() }])

        guard case let .opened(opened) = try await answering.events.openWindow(running: "zmx attach litware", sending: {}),
              let terminal = opened
        else {
            Issue.record("no window's terminal")
            return
        }

        #expect(rendered(terminal.descriptor) == Self.newTerminal)

        try await answering.events.focus(terminal)

        #expect(answering.asked.map(\.event) == ["GhstNSCf", "GhstNWin", "GhstFcus"])
        #expect(answering.asked.last?.direct == Self.newTerminal)
    }

    /// Once `new window` has answered, a window is open, whether or not the answer names it.
    @Test func aNewWindowAnsweredWithoutNamingItIsOpenedWithNoTerminalToFocus() async throws {
        let answering = Answering([{ reply(Self.configuration) }, { reply() }])

        guard case .opened(nil) = try await answering.events.openWindow(running: "zmx attach litware", sending: {}) else {
            Issue.record("not opened, or a terminal named")
            return
        }
    }

    @Test func ghosttyNotRunningIsSentNothingAndOpensNothingAsANewWindowWouldLaunchIt() async throws {
        let sent = OSAllocatedUnfairLock(initialState: 0)
        let events = GhosttyEvents(ghostty: { nil }) { _, _ in
            sent.withLock { $0 += 1 }
            return GhosttyEvents.Sent(status: 0, reply: reply())
        }

        guard case .notRunning = try await events.openWindow(running: "zmx attach litware", sending: {}) else {
            Issue.record("opened with Ghostty not running")
            return
        }
        #expect(sent.withLock { $0 } == 0)
    }

    /// No handler for `new surface configuration`, an opening's first event, is a Ghostty too old to open a window;
    /// a later event's is Ghostty's error, as is a configuration answered with nothing, AppleScript's first of nothing.
    /// A new window not answered in time may still open, and is said so.
    @Test(arguments: [
        ([replied(-1708)], GhosttyFailure.cannotOpen),
        ([unsent(-1708)], .cannotOpen),
        ([unsent(-1712)], .noAnswer),
        ([{ GhosttyEvents.Sent(status: 0, reply: reply(GhosttyEventsTests.configuration)) }, replied(-1708)], .gave(-1708, said: nil)),
        ([{ GhosttyEvents.Sent(status: 0, reply: reply(GhosttyEventsTests.configuration)) }, unsent(-1712)], .windowUnanswered),
        ([{ GhosttyEvents.Sent(status: 0, reply: reply()) }], .gave(-1719, said: nil)),
    ] as [([Answering.Answer], GhosttyFailure)])
    func anOpeningsErrorsAreReadInPlainWords(answers: [Answering.Answer], failure: GhosttyFailure) async {
        await #expect(throws: failure) {
            try await Answering(sending: answers).events.openWindow(running: "zmx attach litware", sending: {})
        }
    }

    /// The window is marked asked for just before `new window` goes, after the configuration came back: never where
    /// the configuration failed, so nothing asking for a window went.
    @Test func theWindowIsMarkedAskedForJustBeforeNewWindowGoesNeverWhereNoneWent() async throws {
        let marks = OSAllocatedUnfairLock(initialState: [Int]())
        let answering = Answering([{ reply(Self.configuration) }, { reply(named("Gwnd", "tab-group-9")) }])

        _ = try await answering.events.openWindow(running: "zmx attach litware") { [answering] in
            marks.withLock { $0.append(answering.asked.count) }
        }
        #expect(marks.withLock { $0 } == [1], "after the configuration's event, before the window's")

        let failing = Answering(sending: [replied(-1708)])
        let none = OSAllocatedUnfairLock(initialState: 0)

        await #expect(throws: GhosttyFailure.cannotOpen) {
            try await failing.events.openWindow(running: "zmx attach litware") { none.withLock { $0 += 1 } }
        }
        #expect(none.withLock { $0 } == 0)
    }

    @Test func aJumpStoppedLetsGoOfAnEventInFlightWhichRunsOnItsAnswerDropped() async throws {
        let (entered, enter) = AsyncStream.makeStream(of: Void.self)
        let release = DispatchSemaphore(value: 0)
        let answered = OSAllocatedUnfairLock(initialState: false)
        let events = GhosttyEvents(ghostty: { 501 }) { _, _ in
            enter.yield()
            release.wait()
            answered.withLock { $0 = true }
            return GhosttyEvents.Sent(status: 0, reply: reply(list([named("Gtrm", "T1")])))
        }
        let asking = Task { try await events.terminal(on: Self.device) }

        defer { release.signal() }
        try await first(of: entered, within: .seconds(10))
        asking.cancel()

        let ended = try await result(of: asking, within: .seconds(10))

        #expect(throws: CancellationError.self) { try ended.get() }
        #expect(!answered.withLock { $0 }, "let go before Ghostty answered")
    }
}

/// A descriptor carried into a reply made on another thread: never changed once made.
private struct Sendably: @unchecked Sendable {
    let descriptor: NSAppleEventDescriptor

    init(_ descriptor: NSAppleEventDescriptor) {
        self.descriptor = descriptor
    }
}
