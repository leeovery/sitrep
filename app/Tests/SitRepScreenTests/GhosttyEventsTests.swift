import CoreServices
import Darwin
import Foundation
import os
@testable import SitRepScreen
import Testing

/// A descriptor in words, as AEDebug prints it but shorter: a specifier or a test by its fields, a list by its items,
/// a code as its four characters, text quoted.
func rendered(_ descriptor: NSAppleEventDescriptor?) -> String {
    guard let descriptor else {
        return "none"
    }

    let field = { (key: String) in rendered(descriptor.forKeyword(code(key))) }

    switch descriptor.descriptorType {
    case typeObjectSpecifier:
        return "obj{want:\(field("want")),from:\(field("from")),form:\(field("form")),seld:\(field("seld"))}"
    case typeCompDescriptor:
        return "cmpd{relo:\(field("relo")),obj1:\(field("obj1")),obj2:\(field("obj2"))}"
    case typeAEList:
        return "[" + (0..<descriptor.numberOfItems).map { rendered(descriptor.atIndex($0 + 1)) }.joined(separator: ",") + "]"
    case typeNull:
        return "null"
    case typeObjectBeingExamined:
        return "exmn"
    case typeUnicodeText:
        return "\"\(descriptor.stringValue ?? "")\""
    case typeType, typeEnumerated, typeAbsoluteOrdinal:
        return "'\(fourCharacters(descriptor.data.withUnsafeBytes { $0.loadUnaligned(as: FourCharCode.self) }))'"
    default:
        return "\(fourCharacters(descriptor.descriptorType))(\(descriptor.stringValue ?? ""))"
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
/// answered in turn, a reply made as it is sent, or an error thrown.
final class Answering: Sendable {
    typealias Answer = @Sendable () throws -> NSAppleEventDescriptor

    struct Sent: Equatable {
        let event: String
        let direct: String
        let seconds: TimeInterval
        let pid: pid_t
    }

    private let answers: [Answer]
    private let state = OSAllocatedUnfairLock(initialState: [Sent]())

    init(_ answers: [Answer]) {
        self.answers = answers
    }

    var sent: [Sent] { state.withLock { $0 } }

    /// The events, sent to process 501.
    var events: GhosttyEvents {
        GhosttyEvents(ghostty: { 501 }) { [self] event, seconds in try send(event, seconds) }
    }

    private func send(_ event: NSAppleEventDescriptor, _ seconds: TimeInterval) throws -> NSAppleEventDescriptor {
        let pid = event.attributeDescriptor(forKeyword: keyAddressAttr)?.data.withUnsafeBytes { $0.loadUnaligned(as: pid_t.self) }
        let sent = Sent(
            event: fourCharacters(event.eventClass) + fourCharacters(event.eventID),
            direct: rendered(event.paramDescriptor(forKeyword: keyDirectObject)), seconds: seconds, pid: pid ?? 0
        )
        let index = state.withLock { state in
            state.append(sent)
            return state.count - 1
        }

        return try answers[min(index, answers.count - 1)]()
    }
}

/// An error a send throws, by its number, as `sendEvent` throws one.
func thrown(_ number: Int) -> Answering.Answer {
    { throw NSError(domain: NSOSStatusErrorDomain, code: number) }
}

/// A reply that says an error, by its number, with any words, as a handler's failing gives one.
func replied(_ number: Int32, said: String? = nil) -> Answering.Answer {
    { reply(error: number, said: said) }
}

/// Ghostty's events built by hand as AppleScript builds the CLI's program, each to the Ghostty running, within five
/// seconds, and their answers read, the codes from Ghostty's dictionary.
struct GhosttyEventsTests {
    private static let device = "/dev/ttys041"

    /// `tty of terminals contains` the device, in a whose clause.
    private static let holding = "cmpd{relo:'cont',obj1:obj{want:'prop',from:obj{want:'Gtrm',from:exmn,form:'indx',seld:'all '},form:'prop',seld:'Gtty'},obj2:\"\(device)\"}"

    private static var terminal: NSAppleEventDescriptor {
        named("Gtrm", "T1")
    }

    @Test func theLookupGetsTheTerminalsWhoseTtyIsTheDeviceFromTheGhosttyRunningWithinFiveSeconds() async throws {
        let answering = Answering([{ reply(list([Self.terminal])) }])

        #expect(try await answering.events.terminal(on: Self.device) != nil)
        #expect(answering.sent == [Answering.Sent(
            event: "coregetd",
            direct: "obj{want:'Gtrm',from:null,form:'test',seld:cmpd{relo:'=   ',obj1:obj{want:'prop',from:exmn,form:'prop',seld:'Gtty'},obj2:\"\(Self.device)\"}}",
            seconds: 5, pid: 501
        )])
        #expect(GhosttyEvents.answerSeconds == 5)
    }

    @Test func theTabsQuestionGetsWhetherTheTabsOfTheWindowsHoldingTheTerminalThatHoldItAreSelected() async throws {
        let answering = Answering([{ reply(list([list([NSAppleEventDescriptor(boolean: true)])])) }])

        _ = try await answering.events.isTabSelected(holding: Self.device)

        #expect(answering.sent.map(\.event) == ["coregetd"])
        #expect(answering.sent.first?.direct == "obj{want:'prop',from:obj{want:'Gtab',from:obj{want:'Gwnd',from:null,form:'test',seld:\(Self.holding)},form:'test',seld:\(Self.holding)},form:'prop',seld:'GTsl'}")
    }

    @Test func onlyATabAnsweredFalseInAListOfOneWindowsOneTabIsNotSelectedATerminalInNoWindowIsFocusedAsSelected() async throws {
        let cases: [(NSAppleEventDescriptor, Bool)] = [
            (list([list([NSAppleEventDescriptor(boolean: false)])]), false),
            (list([list([NSAppleEventDescriptor(boolean: true)])]), true),
            (list([]), true),
        ]

        for (answer, isSelected) in cases {
            let answer = Sendably(answer)

            #expect(try await Answering([{ reply(answer.descriptor) }]).events.isTabSelected(holding: Self.device) == isSelected)
        }
    }

    @Test func theFocusIsGhosttysFocusOfTheTerminalAsTheLookupNamedIt() async throws {
        let answering = Answering([{ reply(list([Self.terminal])) }, { reply() }])
        let found = try #require(try await answering.events.terminal(on: Self.device))

        try await answering.events.focus(found)

        #expect(answering.sent.map(\.event) == ["coregetd", "GhstFcus"])
        #expect(answering.sent.last?.direct == "obj{want:'Gtrm',from:null,form:'ID  ',seld:\"T1\"}")
    }

    @Test func aWindowIsActivatedAsGhosttyNamesTheWindowHoldingTheTerminalByActivateWindow() async throws {
        let answering = Answering([{ reply(list([named("Gwnd", "tab-group-1")])) }, { reply() }])

        try await answering.events.activateWindow(holding: Self.device)

        #expect(answering.sent.map(\.event) == ["coregetd", "GhstAcWn"])
        #expect(answering.sent.first?.direct == "obj{want:'Gwnd',from:null,form:'test',seld:\(Self.holding)}")
        #expect(answering.sent.last?.direct == "obj{want:'Gwnd',from:null,form:'ID  ',seld:\"tab-group-1\"}")
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
            return reply()
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
    /// where it does not know the event (-1708) or a term in it (-1728); not answering in time (-1712); else its error.
    @Test(arguments: [
        (thrown(-1712), GhosttyFailure.noAnswer),
        (thrown(-1743), .gave(-1743, said: nil)),
        (thrown(-1708), .tooOld),
        (thrown(-1728), .tooOld),
        (replied(-1728, said: "Can’t get every terminal whose tty = \"/dev/ttys041\"."), .tooOld),
        (replied(-1708), .tooOld),
        (replied(-10000, said: "AppleEvent handler failed."), .gave(-10000, said: "AppleEvent handler failed.")),
    ] as [(Answering.Answer, GhosttyFailure)])
    func aLookupsErrorsAreReadInPlainWords(answer: @escaping Answering.Answer, failure: GhosttyFailure) async {
        await #expect(throws: failure) {
            try await Answering([answer]).events.terminal(on: Self.device)
        }
    }

    /// A later event's no such object is a terminal gone since it was found, not a Ghostty too old.
    @Test func onlyTheLookupsUnknownTermsReadAsTooOldAFocusFailingSoIsItsError() async throws {
        let answering = Answering([{ reply(list([Self.terminal])) }, { reply(error: -1728, said: "Can’t get terminal id \"T1\".") }])
        let found = try #require(try await answering.events.terminal(on: Self.device))

        await #expect(throws: GhosttyFailure.gave(-1728, said: "Can’t get terminal id \"T1\".")) {
            try await answering.events.focus(found)
        }
        await #expect(throws: GhosttyFailure.noAnswer) {
            try await Answering([thrown(-1712)]).events.focus(found)
        }
    }

    @Test func aJumpStoppedLetsGoOfAnEventInFlightWhichRunsOnItsAnswerDropped() async {
        let release = DispatchSemaphore(value: 0)
        let answered = OSAllocatedUnfairLock(initialState: false)
        let events = GhosttyEvents(ghostty: { 501 }) { _, _ in
            release.wait()
            answered.withLock { $0 = true }
            return reply(list([named("Gtrm", "T1")]))
        }
        let asking = Task { try await events.terminal(on: Self.device) }

        try? await Task.sleep(for: .milliseconds(50))
        asking.cancel()

        await #expect(throws: CancellationError.self) { try await asking.value }
        #expect(!answered.withLock { $0 }, "let go before Ghostty answered")

        release.signal()
    }
}

/// A descriptor carried into a reply made on another thread: never changed once made.
private struct Sendably: @unchecked Sendable {
    let descriptor: NSAppleEventDescriptor

    init(_ descriptor: NSAppleEventDescriptor) {
        self.descriptor = descriptor
    }
}
