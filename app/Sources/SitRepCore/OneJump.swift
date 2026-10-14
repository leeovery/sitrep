/// Lets one jump run at a time: two knocking on one terminal at once can
/// leave it reporting `$HOME`, as the later takes the earlier's marker for
/// a directory it cannot know.
@MainActor
public final class OneJump {
    public private(set) var isRunning = false

    public init() {}

    /// Runs the jump unless one is running already: what it came to, or nil when refused.
    public func run<Jumped>(_ jump: () async -> Jumped) async -> Jumped? {
        guard !isRunning else {
            return nil
        }

        isRunning = true
        defer { isRunning = false }

        return await jump()
    }
}
