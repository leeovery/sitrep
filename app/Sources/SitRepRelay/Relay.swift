import Foundation

/// The relay between SitRep and its notices helper: a distributed notification each way, named under the helper's
/// bundle id, its letter in its userInfo. Local to this Mac.
@MainActor
public final class Relay<Out: Relayed, In: Relayed> {
    private let center = DistributedNotificationCenter.default()
    private let helper: String
    private var listening: Observer?

    /// The relay under the helper's bundle id.
    public init(helper: String) {
        self.helper = helper
    }

    /// Delivered at once: AppKit suspends delivery to an app that is not active, as neither side is as a rule, and
    /// `deliverImmediately` from the sender overrides that.
    public func send(_ letter: Letter<Out>) {
        center.postNotificationName(name(Out.self), object: nil, userInfo: letter.userInfo, deliverImmediately: true)
    }

    /// Each letter that comes, on the main thread, to `heard` alone; anything else under the name is passed over.
    public func listen(_ heard: @escaping @MainActor (Letter<In>) -> Void) {
        listening = Observer(center.addObserver(forName: name(In.self), object: nil, queue: .main) { notification in
            guard let letter = Letter<In>(userInfo: notification.userInfo) else {
                return
            }

            MainActor.assumeIsolated { heard(letter) }
        })
    }

    private func name<Message: Relayed>(_: Message.Type) -> Notification.Name {
        Notification.Name("\(helper).\(Message.way)")
    }
}

/// An observer of the distributed center, removed as it is let go: the center keeps one until it is removed, whatever
/// becomes of its token, so a relay gone, or listening again, would leave it hearing still.
private final class Observer {
    private let token: NSObjectProtocol

    init(_ token: NSObjectProtocol) {
        self.token = token
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(token)
    }
}
