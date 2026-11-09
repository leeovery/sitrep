/// A terminal app with a driver of its own, which finds the window on a device and brings it forward: Ghostty's the one.
public struct Driver: Sendable, Hashable {
    public let name: String
    /// `$TERM_PROGRAM` in its windows outside a multiplexer.
    public let program: String
    /// The last part of its program's path, which a multiplexer's client in one of its windows descends from.
    public let executable: String

    public static let ghostty = Driver(name: "Ghostty", program: "ghostty", executable: "ghostty")

    /// Every terminal app with a driver.
    public static let all: [Driver] = [.ghostty]
}

/// The terminal app a window is in: one with a driver, else one brought forward whole, which shows the session but
/// cannot pick out its window.
public enum TerminalApp: Sendable, Hashable {
    case driven(Driver)
    /// An app with no driver known by its bundle id, the first of those given that is running: Warp's stable release
    /// or its preview. One told by its `$TERM_PROGRAM`, which a program started from another terminal's shell
    /// inherits, or by a helper that outlives the app, so it must be found running before it is brought forward.
    case bundled(name: String, bundles: [String])
    /// An app with no driver by its bundle's path, its program running among a client's ancestors.
    case atPath(name: String, path: String)

    public var name: String {
        switch self {
        case let .driven(driver):
            driver.name
        case let .bundled(name, _), let .atPath(name, _):
            name
        }
    }

    public var isDriven: Bool {
        if case .driven = self {
            true
        } else {
            false
        }
    }

    /// Whether a window in it can be reached on the device: a driver needs one to find the window; an app with no
    /// driver is brought forward whole, so needs none.
    func reaches(_ device: String?) -> Bool {
        device != nil || !isDriven
    }

    /// The apps with no driver told by their `$TERM_PROGRAM`. kitty and Alacritty set none, so only their clients are
    /// told, by their app's path; VS Code's, which Cursor sets too, would name the wrong app for one of them.
    static let byProgram: [String: TerminalApp] = [
        "Apple_Terminal": .bundled(name: "Terminal", bundles: ["com.apple.Terminal"]),
        "iTerm.app": .bundled(name: "iTerm2", bundles: ["com.googlecode.iterm2"]),
        "WezTerm": .bundled(name: "WezTerm", bundles: ["com.github.wez.wezterm"]),
        "WarpTerminal": .bundled(name: "Warp", bundles: ["dev.warp.Warp-Stable", "dev.warp.Warp-Preview"]),
    ]

    /// The app a window outside a multiplexer is in, by its `$TERM_PROGRAM`: its driver, else one in the table.
    public init?(program: String?) {
        guard let program else {
            return nil
        }

        if let driver = Driver.all.first(where: { $0.program == program }) {
            self = .driven(driver)
        } else if let app = Self.byProgram[program] {
            self = app
        } else {
            return nil
        }
    }

    /// The app a process is, by its program's path, as the kernel gives it: a driver's, where the last part of its
    /// path is the driver's executable; a known app's helper outside its bundle; else the bundle it is inside, the
    /// outermost (`/Applications/Visual Studio Code.app` for its helpers too). None for a program in no app: a shell,
    /// `login`, mosh-server, sshd.
    public init?(path: String) {
        let last = path.split(separator: "/").last.map(String.init)

        if let driver = Driver.all.first(where: { $0.executable == last }) {
            self = .driven(driver)
        } else if let app = Self.helpersProgram(path).flatMap({ Self.byProgram[$0] }) {
            self = app
        } else if let bundle = Self.outermostBundle(path) {
            self = .atPath(name: bundle.name, path: bundle.path)
        } else {
            return nil
        }
    }

    /// The `$TERM_PROGRAM` of the app with no driver a program outside its bundle is: iTerm2's shells, since 3.4, run
    /// under `~/Library/Application Support/iTerm2/iTermServer-<version>` (unchecked on this Mac, which has no iTerm2),
    /// which outlives iTerm2 quitting.
    private static func helpersProgram(_ path: String) -> String? {
        path.contains(/\/Library\/Application Support\/iTerm2\/iTermServer-[^\/]+$/) ? "iTerm.app" : nil
    }

    /// The outermost app bundle a path is inside: its path and its name, the folder's less `.app`.
    private static func outermostBundle(_ path: String) -> (path: String, name: String)? {
        guard path.hasPrefix("/") else {
            return nil
        }

        var folders: [Substring] = []

        for part in path.split(separator: "/", omittingEmptySubsequences: false).dropFirst().dropLast() {
            folders.append(part)

            if part.hasSuffix(".app"), part.count > ".app".count {
                return ("/" + folders.joined(separator: "/"), String(part.dropLast(".app".count)))
            }
        }

        return nil
    }
}
