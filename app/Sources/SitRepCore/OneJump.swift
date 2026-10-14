/// Lets one jump run at a time: two knocking on one terminal at once can
/// leave it reporting `$HOME`, as the later takes the earlier's marker for
/// a directory it cannot know.
@MainActor
public final class OneJump {
    public private(set) var isRunning = false

    public init() {}

    /// Runs the jump unless one is running already; whether it ran.
    public func run(_ jump: () async -> Void) async -> Bool {
        guard !isRunning else {
            return false
        }

        isRunning = true
        defer { isRunning = false }
        await jump()

        return true
    }
}
