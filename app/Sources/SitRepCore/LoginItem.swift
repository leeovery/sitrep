import ServiceManagement

/// The "Start at login" item, from the login item's real status.
public struct LoginItem: Equatable {
    /// What choosing the item does.
    public enum Choice: Equatable {
        case register
        case unregister
        /// macOS wants Lee's approval, which only System Settings' Login Items gives.
        case openSettings
    }

    public let isOn: Bool
    public let needsApproval: Bool
    public let choice: Choice

    public init(_ status: SMAppService.Status) {
        isOn = status == .enabled
        needsApproval = status == .requiresApproval
        choice = switch status {
        case .enabled: .unregister
        case .requiresApproval: .openSettings
        default: .register
        }
    }

    public var title: String {
        needsApproval ? "Start at login (approve in System Settings)" : "Start at login"
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
