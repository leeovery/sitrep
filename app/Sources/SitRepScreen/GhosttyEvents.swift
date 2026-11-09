import AppKit
import CoreServices

/// Ghostty asked by Apple Events built by hand, as AppleScript builds them, never through `NSAppleScript`, which runs
/// on the main thread: each sent to the Ghostty running, by its process, so none ever launches it, on a thread of its
/// own, waiting at most `answerSeconds` for its answer. A jump stopped lets go of an event in flight, which is not
/// recalled; Ghostty handles events in the order sent, so a later jump's land after it.
///
/// The questions are the CLI's program's, an event each: the terminals on a device, `terminals whose tty is` it;
/// whether its tab is selected, `selected of (tabs of (windows whose tty of terminals contains` it`) whose tty of
/// terminals contains` it`)`; and, for a tab not selected, the window holding it, then `activate window`; then
/// `focus` the terminal found.
public struct GhosttyEvents: GhosttyScripting {
    /// How long each event waits for Ghostty's answer. With the screen locked, Ghostty answers nothing about its
    /// terminals, and an event's own limit is two minutes.
    public static let answerSeconds: TimeInterval = 5

    /// Sends an event, blocking until its answer, or for at most the time given: the reply; throws as the send fails.
    typealias Send = @Sendable (NSAppleEventDescriptor, TimeInterval) throws -> NSAppleEventDescriptor

    private let ghostty: @Sendable () -> pid_t?
    private let send: Send

    public init() {
        self.init(ghostty: Self.running) { event, seconds in
            try event.sendEvent(options: [.waitForReply, .canInteract], timeout: seconds)
        }
    }

    /// `ghostty` gives the Ghostty running, by its process; `send` sends an event to it.
    init(ghostty: @escaping @Sendable () -> pid_t?, send: @escaping Send) {
        self.ghostty = ghostty
        self.send = send
    }

    public func terminal(on device: String) async throws -> GhosttyObject? {
        guard ghostty() != nil else {
            return nil
        }

        return try await ask({ GhosttyEvent.terminals(on: device) }, isLookup: true).first.map(GhosttyObject.init)
    }

    public func isTabSelected(holding device: String) async throws -> Bool {
        try await !GhosttyEvent.isNotSelected(ask { GhosttyEvent.isSelected(tabHolding: device) })
    }

    /// The window holding the terminal, as Ghostty names it, then that window activated: none holding it, the
    /// terminal closed since it was found, fails as AppleScript fails to find the first item of nothing (-1719).
    public func activateWindow(holding device: String) async throws {
        guard let window = try await ask({ GhosttyEvent.windows(holding: device) }).first.map(GhosttyObject.init) else {
            throw GhosttyFailure.gave(GhosttyEvent.noSuchItem, said: nil)
        }

        try await tell { GhosttyEvent.activate(window) }
    }

    public func focus(_ terminal: GhosttyObject) async throws {
        try await tell { GhosttyEvent.focus(terminal) }
    }

    /// What Ghostty answered a question, its direct object as a list's items.
    private func ask(
        _ question: @escaping @Sendable () -> GhosttyEvent, isLookup: Bool = false
    ) async throws -> [NSAppleEventDescriptor] {
        try await answer(question, isLookup: isLookup).items
    }

    private func tell(_ command: @escaping @Sendable () -> GhosttyEvent) async throws {
        _ = try await answer(command, isLookup: false)
    }

    /// The event made and sent on a thread of its own, and its answer read there; throws Ghostty's failure, or
    /// `CancellationError` once the jump is stopped, letting the event go.
    private func answer(_ made: @escaping @Sendable () -> GhosttyEvent, isLookup: Bool) async throws -> Answered {
        guard let pid = ghostty() else {
            throw GhosttyFailure.gave(GhosttyEvent.noProcess, said: nil)
        }

        let answered = await onThread { [send] in
            Answered(Result { try send(made().addressed(to: pid), Self.answerSeconds) }, isLookup: isLookup)
        }

        guard let answered else {
            throw CancellationError()
        }

        if let failure = answered.failure {
            throw failure
        }

        return answered
    }

    /// The Ghostty running, by its process.
    @Sendable private static func running() -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: GhosttyDriver.bundle)
            .first { !$0.isTerminated }?.processIdentifier
    }
}

/// An answer, read on the thread that sent its event: what it says, or why it failed. Its descriptors are never changed
/// once read, so safe to hand to the jump.
private struct Answered: @unchecked Sendable {
    /// The direct object's items: none, one, or a list's.
    let items: [NSAppleEventDescriptor]
    let failure: GhosttyFailure?

    init(_ sent: Result<NSAppleEventDescriptor, any Error>, isLookup: Bool) {
        switch sent {
        case let .success(reply):
            failure = GhosttyEvent.failure(in: reply, isLookup: isLookup)
            items = failure == nil ? GhosttyEvent.items(of: reply.paramDescriptor(forKeyword: keyDirectObject)) : []
        case let .failure(error):
            failure = GhosttyEvent.failure(number: (error as NSError).code, said: nil, isLookup: isLookup)
            items = []
        }
    }
}

/// One Apple Event to Ghostty, as built, before it is addressed: its class and id, and its direct object.
struct GhosttyEvent {
    let eventClass: AEEventClass
    let eventID: AEEventID
    let direct: NSAppleEventDescriptor

    /// The event to the process.
    func addressed(to pid: pid_t) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: eventClass, eventID: eventID,
            targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
        )

        event.setParam(direct, forKeyword: keyDirectObject)
        return event
    }

    /// Ghostty's codes, from its dictionary (`sdef /Applications/Ghostty.app`, 1.4.0).
    enum Code {
        static let suite = code("Ghst")
        static let focus = code("Fcus")
        static let activateWindow = code("AcWn")
        static let window = code("Gwnd")
        static let tab = code("Gtab")
        static let terminal = code("Gtrm")
        /// A terminal's device.
        static let tty = code("Gtty")
        /// Whether a tab is its window's selected one.
        static let selected = code("GTsl")
    }

    /// AppleScript's error for an item of a list that has none: errAEIllegalIndex.
    static let noSuchItem = -1719
    /// The error for a process gone: procNotFound.
    static let noProcess = -600
    /// The error an event no handler takes gives: errAEEventNotHandled.
    static let notHandled = -1708
    /// The error a specifier the app cannot resolve gives: errAENoSuchObject.
    static let noSuchObject = -1728
    /// The error an event that waited its whole time gives: errAETimeout.
    static let timedOut = -1712

    /// `terminals whose tty is` the device.
    static func terminals(on device: String) -> GhosttyEvent {
        get(Specifier.whose(
            Code.terminal, of: Specifier.application,
            Specifier.comparison(Specifier.property(Code.tty, of: Specifier.examined), kAEEquals, device)
        ))
    }

    /// `windows whose tty of terminals contains` the device.
    static func windows(holding device: String) -> GhosttyEvent {
        get(holding(device, Code.window, of: Specifier.application))
    }

    /// `selected of (tabs of (windows whose tty of terminals contains` the device`) whose tty of terminals contains`
    /// it`)`.
    static func isSelected(tabHolding device: String) -> GhosttyEvent {
        get(Specifier.property(
            Code.selected,
            of: holding(device, Code.tab, of: holding(device, Code.window, of: Specifier.application))
        ))
    }

    static func activate(_ window: GhosttyObject) -> GhosttyEvent {
        GhosttyEvent(eventClass: Code.suite, eventID: Code.activateWindow, direct: window.descriptor)
    }

    static func focus(_ terminal: GhosttyObject) -> GhosttyEvent {
        GhosttyEvent(eventClass: Code.suite, eventID: Code.focus, direct: terminal.descriptor)
    }

    /// Ghostty's answer to whether a tab is selected is a list of lists, a window's and its tab's: `{{false}}` for one
    /// not selected; anything else, `{}` for a terminal in no window, is focused as one selected.
    static func isNotSelected(_ windows: [NSAppleEventDescriptor]) -> Bool {
        guard windows.count == 1, let tabs = windows.first.map({ items(of: $0) }), tabs.count == 1,
              let selected = tabs.first, [typeBoolean, typeTrue, typeFalse].contains(selected.descriptorType)
        else {
            return false
        }

        return !selected.booleanValue
    }

    /// What a reply's error says: none where it gave none.
    static func failure(in reply: NSAppleEventDescriptor, isLookup: Bool) -> GhosttyFailure? {
        guard let number = reply.paramDescriptor(forKeyword: keyErrorNumber)?.int32Value, number != 0 else {
            return nil
        }

        let said = reply.paramDescriptor(forKeyword: keyErrorString)?.stringValue

        return failure(number: Int(number), said: said, isLookup: isLookup)
    }

    /// An error read in plain words where it can be: Ghostty not answering in time, or, for the lookup, the first
    /// event, which names the terms a Ghostty before 1.4 lacks, too old to know them. osascript told those apart as
    /// AppleScript's own -2753 and -2741, which a hand-built event never gets: a Ghostty with no scripting is expected
    /// to take no Get Data (-1708), and one without a terminal's `tty` to resolve no specifier naming it (-1728). Both
    /// are unproven live until `LiveEventsTests` runs. Only the lookup's are read so, as a later event's no such object
    /// is a terminal gone since it was found.
    static func failure(number: Int, said: String?, isLookup: Bool) -> GhosttyFailure {
        switch number {
        case timedOut:
            .noAnswer
        case notHandled where isLookup, noSuchObject where isLookup:
            .tooOld
        default:
            .gave(number, said: said)
        }
    }

    /// A descriptor's items: a list's, else it alone; none for none, or a null.
    static func items(of descriptor: NSAppleEventDescriptor?) -> [NSAppleEventDescriptor] {
        guard let descriptor, descriptor.descriptorType != typeNull else {
            return []
        }
        guard descriptor.descriptorType == typeAEList else {
            return [descriptor]
        }

        return (0..<descriptor.numberOfItems).compactMap { descriptor.atIndex($0 + 1) }
    }

    /// The elements of a class in the container whose terminals include one on the device.
    private static func holding(_ device: String, _ type: FourCharCode, of container: NSAppleEventDescriptor)
        -> NSAppleEventDescriptor
    {
        let ttys = Specifier.property(Code.tty, of: Specifier.every(Code.terminal, of: Specifier.examined))

        return Specifier.whose(type, of: container, Specifier.comparison(ttys, kAEContains, device))
    }

    /// Get Data, the event AppleScript sends for a question.
    private static func get(_ specifier: NSAppleEventDescriptor) -> GhosttyEvent {
        GhosttyEvent(eventClass: kAECoreSuite, eventID: kAEGetData, direct: specifier)
    }
}

/// Object specifiers, built as AppleScript builds them: each a record of the class wanted, its container, and the form
/// and data that pick it out there.
enum Specifier {
    /// The application, the outermost container.
    static var application: NSAppleEventDescriptor {
        NSAppleEventDescriptor.null()
    }

    /// The object a whose clause is testing.
    static var examined: NSAppleEventDescriptor {
        NSAppleEventDescriptor(descriptorType: typeObjectBeingExamined, data: nil) ?? NSAppleEventDescriptor.null()
    }

    /// `every` element of the class.
    static func every(_ type: FourCharCode, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        var all = kAEAll
        let ordinal = NSAppleEventDescriptor(
            descriptorType: typeAbsoluteOrdinal, bytes: &all, length: MemoryLayout.size(ofValue: all)
        ) ?? NSAppleEventDescriptor.null()

        return object(type, of: container, form: DescType(formAbsolutePosition), ordinal)
    }

    /// A property, by its code.
    static func property(_ code: FourCharCode, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        object(
            DescType(cProperty), of: container, form: DescType(formPropertyID), NSAppleEventDescriptor(typeCode: code)
        )
    }

    /// The elements of the class whose test holds.
    static func whose(_ type: FourCharCode, of container: NSAppleEventDescriptor, _ test: NSAppleEventDescriptor)
        -> NSAppleEventDescriptor
    {
        object(type, of: container, form: DescType(formTest), test)
    }

    /// A test: the object's value compared with the text.
    static func comparison(_ object: NSAppleEventDescriptor, _ comparison: DescType, _ text: String)
        -> NSAppleEventDescriptor
    {
        record(typeCompDescriptor, [
            (AEKeyword(keyAECompOperator), NSAppleEventDescriptor(enumCode: comparison)),
            (AEKeyword(keyAEObject1), object),
            (AEKeyword(keyAEObject2), NSAppleEventDescriptor(string: text)),
        ])
    }

    private static func object(
        _ type: FourCharCode, of container: NSAppleEventDescriptor, form: DescType, _ data: NSAppleEventDescriptor
    ) -> NSAppleEventDescriptor {
        record(typeObjectSpecifier, [
            (AEKeyword(keyAEDesiredClass), NSAppleEventDescriptor(typeCode: type)),
            (AEKeyword(keyAEContainer), container),
            (AEKeyword(keyAEKeyForm), NSAppleEventDescriptor(enumCode: form)),
            (AEKeyword(keyAEKeyData), data),
        ])
    }

    /// A record of the type, its fields in order: a record coerced to it, as a specifier and a test are records.
    private static func record(_ type: DescType, _ fields: [(AEKeyword, NSAppleEventDescriptor)])
        -> NSAppleEventDescriptor
    {
        let record = NSAppleEventDescriptor.record().coerce(toDescriptorType: type) ?? NSAppleEventDescriptor.record()

        fields.forEach { record.setDescriptor($1, forKeyword: $0) }
        return record
    }
}

/// A four-character code as Apple Events name each class, property, event and form: `Gtrm`.
func code(_ text: String) -> FourCharCode {
    text.utf8.reduce(0) { $0 << 8 | FourCharCode($1) }
}
