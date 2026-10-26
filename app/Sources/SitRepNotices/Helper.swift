import os
import SitRepRelay

/// What macOS lets the helper do with notifications.
@MainActor
protocol Notifying {
    func post(_ notice: Notice) async
    func leave() async -> NoticeLeave
    /// macOS asked for leave, unless Lee answered already; then the leave.
    func ask() async -> NoticeLeave
}

/// The SitRep the helper serves: the app it sits in.
@MainActor
protocol SitRepApp {
    /// Its pid, while it runs.
    func running() -> Int32?
    /// Started without activating it: its pid, or nil where it would not start.
    func launch() async -> Int32?
    /// `ended` told once the app with this pid ends.
    func watch(_ pid: Int32, ended: @escaping @MainActor () -> Void)
}

/// The helper's work, between SitRep and macOS's notifications. A click activates the helper, which has no window, so
/// macOS has no Space to take Lee to; the helper relays it, and SitRep jumps as from any other click. A click that
/// started the helper while SitRep was not running starts SitRep, and is held until SitRep says it listens. A click on
/// a banner naming no session hands the front back, as nothing jumps, as does a click whose jump SitRep refused. The
/// helper quits as its SitRep ends.
@MainActor
final class Helper {
    /// The helper's own app.
    struct Own {
        let pid: Int32
        let quit: @MainActor () -> Void
        /// The front given back to the app Lee was in, which the click's activation took it from.
        let handBack: @MainActor () -> Void
    }

    private let notifications: Notifying
    private let sitRep: SitRepApp
    private let send: (Letter<ToSitRep>) -> Void
    private let own: Own
    private let logger = Logger(helper: "notices")
    /// The pid of the SitRep it serves, once found or started.
    private var pid: Int32?
    private var isSitRepListening = false
    /// Clicks heard before SitRep listens, in order.
    private var held: [String] = []
    /// The banner being posted, the next waiting on it, so they show in the order SitRep sent them.
    private var posting: Task<Void, Never>?

    init(notifications: Notifying, sitRep: SitRepApp, send: @escaping (Letter<ToSitRep>) -> Void, own: Own) {
        self.notifications = notifications
        self.sitRep = sitRep
        self.send = send
        self.own = own
    }

    /// Finds SitRep, or starts it; watches for it ending; says the helper listens. With no SitRep, it quits.
    func start() async {
        var pid = sitRep.running()

        if pid == nil {
            pid = await sitRep.launch()
        }
        guard let pid else {
            logger.error("SitRep would not start: quitting")

            return own.quit()
        }

        self.pid = pid
        sitRep.watch(pid, ended: own.quit)
        relay(.ready(helper: own.pid))
    }

    /// A letter from SitRep; one from another SitRep, or before the helper knows its own, is passed over.
    func heard(_ letter: Letter<ToHelper>) {
        guard let pid, let message = letter.message(for: pid) else {
            return
        }

        switch message {
        case .ready: sitRepListens()
        case let .post(notice): post(notice)
        case let .status(id): answer(id, notifications.leave)
        case let .ask(id): answer(id, notifications.ask)
        case .handBack: own.handBack()
        }
    }

    /// A banner clicked: one naming a session relayed to SitRep, or held until it listens; one naming none hands the
    /// front back.
    func clicked(_ work: String?) {
        guard let work else {
            return own.handBack()
        }

        if isSitRepListening {
            relay(.clicked(work: work))
        } else {
            held.append(work)
        }
    }

    /// SitRep's `ready` answered with the helper's, as SitRep may have missed it, and the clicks held handed on. Each
    /// is answered, as SitRep says it again while it has not heard the helper; SitRep answers only a helper's first,
    /// so the two stop.
    private func sitRepListens() {
        isSitRepListening = true
        relay(.ready(helper: own.pid))
        held.forEach { relay(.clicked(work: $0)) }
        held = []
    }

    private func post(_ notice: Notice) {
        let previous = posting

        posting = Task { [notifications] in
            await previous?.value
            await notifications.post(notice)
        }
    }

    private func answer(_ id: String, _ leave: @escaping @MainActor () async -> NoticeLeave) {
        Task { relay(.status(await leave(), id: id)) }
    }

    private func relay(_ message: ToSitRep) {
        if let pid {
            send(Letter(message, pid: pid))
        }
    }
}
