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
    /// The pid of the helper listening, whose ready SitRep answered.
    private var listening: Int32?
    /// What waits for a helper to listen, in order. Nothing waits while one listens.
    private var waiting: [ToHelper] = []
    /// Requests the helper has yet to answer, by id.
    private var answers: [String: CheckedContinuation<NoticeLeave?, Never>] = [:]
    private var onClick: (String, @escaping () -> Void) -> Void = { _, _ in }

    init(
        pid: Int32, send: @escaping (Letter<ToHelper>) -> Void, launch: @escaping () -> Void,
        answerWithin: Duration = .seconds(2)
    ) {
        self.pid = pid
        self.send = send
        self.launch = launch
        self.answerWithin = answerWithin
    }

    /// Clicks told to `onClick`, with the session and what hands the front back should its jump be refused; SitRep
    /// says it listens, and starts the helper. Before launching ends, so a click that started SitRep, held by the
    /// helper, is heard.
    func start(onClick: @escaping (_ work: String, _ refused: @escaping () -> Void) -> Void) {
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
        case let .ready(helper): helperListens(helper)
        case let .clicked(work): onClick(work) { [weak self] in self?.deliver(.handBack) }
        case let .status(leave, id): answer(id, leave)
        }
    }

    /// A helper ended. The one listening leaves what it was sent unanswered, as unknown, and what comes next waits for
    /// another, started only then, so a helper that ends as it starts is not started over and over. Any other is one
    /// SitRep no longer hears from, whose end was told after the next said it listens: that one is watched now.
    func helperEnded(_ helper: Int32) {
        guard helper == listening else {
            if listening != nil {
                launch()
            }

            return
        }

        listening = nil
        forgetAnswers()
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
                waiting.removeAll { $0.request == id }
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

    /// Every request unknown: each was sent to a helper now gone, as nothing waits while one listens.
    private func forgetAnswers() {
        answers.keys.forEach { answer($0, nil) }
    }

    /// A helper's first `ready` answered with SitRep's, as it may have missed SitRep's, and what waits sent. It is
    /// watched for ending through `launch`, which finds it running, whoever started it: SitRep, or macOS for a click.
    /// One that takes the place of another still thought listening leaves the other's requests unknown.
    private func helperListens(_ helper: Int32) {
        guard helper != listening else {
            return
        }

        if listening != nil {
            forgetAnswers()
        }
        listening = helper
        launch()
        say(.ready)
        waiting.forEach(say)
        waiting = []
    }

    private func deliver(_ message: ToHelper) {
        if listening != nil {
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

private extension ToHelper {
    /// The id of a request, which its answer gives back.
    var request: String? {
        switch self {
        case let .status(id), let .ask(id): id
        case .ready, .post, .handBack: nil
        }
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

        relay.listen { [weak banners] in banners?.heard($0) }
        app.ended = { [weak banners] in banners?.helperEnded($0) }

        return banners
    }
}

/// The notices helper as an app: started where it is not running, once at a time, and watched for ending. Opened
/// where it runs already, as when it says it listens, it is the one running that is watched.
@MainActor
private final class HelperApp {
    /// Told the pid of the helper that ended.
    var ended: (Int32) -> Void = { _ in }
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
                watching(try await Apps.open(bundle))
            } catch {
                logger.error("Notices helper not started: \(error.localizedDescription, privacy: .public)")
                isOpen = false
            }
        }
    }

    private func watching(_ helper: NSRunningApplication) {
        let pid = helper.processIdentifier

        watch = EndWatch(helper) { [weak self] in
            self?.isOpen = false
            self?.ended(pid)
        }
    }
}
