import AppKit
import os
import SitRepCore
import SitRepRelay

/// macOS banners, which SitRep's notices helper posts (DESIGN, "The menu bar"). SitRep decides what to post and when;
/// the helper, a windowless app inside SitRep.app, posts it, reads and asks macOS's leave, and relays a click on one
/// that names a session, so the click activates the helper, never SitRep, whose window would take Lee to its own Space
/// ahead of the jump. What SitRep says before the helper listens waits for it, the helper started.
@MainActor
final class Banners {
    private let pid: Int32
    private let send: (Letter<ToHelper>) -> Void
    private let launch: () -> Void
    private let answerWithin: Duration
    private var isHelperListening = false
    /// What waits for the helper to listen, in order.
    private var waiting: [ToHelper] = []
    /// Requests the helper has yet to answer, by id.
    private var answers: [String: CheckedContinuation<NoticeLeave?, Never>] = [:]
    private var onClick: (String) -> Void = { _ in }

    init(
        pid: Int32, send: @escaping (Letter<ToHelper>) -> Void, launch: @escaping () -> Void,
        answerWithin: Duration = .seconds(2)
    ) {
        self.pid = pid
        self.send = send
        self.launch = launch
        self.answerWithin = answerWithin
    }

    /// Clicks told to `onClick`; SitRep says it listens, and starts the helper. Before launching ends, so a click that
    /// started SitRep, held by the helper, is heard.
    func start(onClick: @escaping (String) -> Void) {
        self.onClick = onClick
        say(.ready)
        launch()
    }

    /// A letter from the helper; one for another SitRep is passed over.
    func heard(_ letter: Letter<ToSitRep>) {
        guard let message = letter.message(for: pid) else {
            return
        }

        switch message {
        case .ready: helperListens()
        case let .clicked(work): onClick(work)
        case let .status(leave, id): answer(id, leave)
        }
    }

    /// The helper gone: what it had yet to answer is unknown, and what comes next waits for it, started again.
    func helperEnded() {
        isHelperListening = false
        answers.keys.forEach { answer($0, nil) }
        if !waiting.isEmpty {
            launch()
        }
    }

    func post(_ banner: Banner) {
        deliver(.post(Notice(title: banner.title, subtitle: banner.subtitle, body: banner.body, work: banner.work)))
    }

    /// What macOS lets SitRep do with notifications; nil when the helper does not answer in time.
    func leave() async -> NoticeLeave? {
        await request(within: answerWithin) { .status(id: $0) }
    }

    /// macOS asked for leave to show banners, unless Lee answered already: done once Lee has answered.
    func ask() async {
        _ = await request(within: nil) { .ask(id: $0) }
    }

    private func request(within: Duration?, _ message: (String) -> ToHelper) async -> NoticeLeave? {
        let id = UUID().uuidString

        if let within {
            Task {
                try? await Task.sleep(for: within)
                answer(id, nil)
            }
        }

        return await withCheckedContinuation {
            answers[id] = $0
            deliver(message(id))
        }
    }

    private func answer(_ id: String, _ leave: NoticeLeave?) {
        answers.removeValue(forKey: id)?.resume(returning: leave)
    }

    /// The helper's first `ready` answered with SitRep's, as the helper may have missed it, and what waits sent.
    private func helperListens() {
        guard !isHelperListening else {
            return
        }

        isHelperListening = true
        say(.ready)
        waiting.forEach(say)
        waiting = []
    }

    private func deliver(_ message: ToHelper) {
        if isHelperListening {
            say(message)
        } else {
            waiting.append(message)
            launch()
        }
    }

    private func say(_ message: ToHelper) {
        send(Letter(message, pid: pid))
    }
}

extension Banners {
    /// The notices helper's bundle id, under which the relay's names go.
    static var helper: String {
        NoticeHelper.id(of: Bundle.main.bundleIdentifier ?? "com.leeovery.sitrep")
    }

    /// Banners through the helper in SitRep.app, over the relay.
    static func live() -> Banners {
        let relay = Relay<ToHelper, ToSitRep>(helper: helper)
        let app = HelperApp(Bundle.main.bundleURL.appending(path: NoticeHelper.place))
        let banners = Banners(
            pid: ProcessInfo.processInfo.processIdentifier, send: relay.send, launch: { app.open() }
        )

        relay.listen { [unowned banners] in banners.heard($0) }
        app.ended = { [unowned banners] in banners.helperEnded() }

        return banners
    }
}

/// The notices helper as an app: started where it is not running, once at a time, and watched for ending.
@MainActor
private final class HelperApp {
    var ended: () -> Void = {}
    private let bundle: URL
    private let logger = Logger(sitrep: "banner")
    private var isOpen = false
    private var watch: EndWatch?

    init(_ bundle: URL) {
        self.bundle = bundle
    }

    func open() {
        guard !isOpen else {
            return
        }

        isOpen = true
        Task {
            do {
                watch = EndWatch(try await Apps.open(bundle)) { [self] in
                    isOpen = false
                    ended()
                }
            } catch {
                logger.error("Notices helper not started: \(error.localizedDescription, privacy: .public)")
                isOpen = false
            }
        }
    }
}
