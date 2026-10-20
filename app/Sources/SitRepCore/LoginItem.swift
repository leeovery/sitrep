import ServiceManagement

/// General's "Open at login", from the login item's real status.
public struct LoginItem: Equatable {
    /// What choosing the item does.
    public enum Choice: Equatable {
        case register
        case unregister
        /// macOS wants Lee's approval, which only System Settings' Login Items gives.
        case openSettings
    }

    public let choice: Choice

    public init(_ status: SMAppService.Status) {
        choice = switch status {
        case .enabled: .unregister
        case .requiresApproval: .openSettings
        default: .register
        }
    }

    /// Whether it starts at login: only then does choosing it stop that.
    public var isOn: Bool { choice == .unregister }

    public var needsApproval: Bool { choice == .openSettings }

    /// The line under the switch, while macOS waits on Lee.
    public var line: String? {
        needsApproval ? "Waiting for your approval in System Settings" : nil
    }
}

extension SMAppService.Status {
    /// The status in words, for the log.
    public var words: String {
        switch self {
        case .notRegistered: "not registered"
        case .enabled: "enabled"
        case .requiresApproval: "requires approval"
        case .notFound: "not found"
        @unknown default: "unknown (\(rawValue))"
        }
    }
}
