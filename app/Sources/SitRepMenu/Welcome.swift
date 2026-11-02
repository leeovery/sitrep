import SitRepCore
import SitRepEdge
import SitRepPanel

/// A step of the welcome window (DESIGN, "The welcome window"): its headline, the grey paragraph under it, and what
/// its stage plays.
public enum WelcomeStep: String, Sendable {
    case hello, edge, sound, ready

    /// Two lines at most, in the column's 330.
    public var headline: String {
        switch self {
        case .hello: "Every session, at the edge of your screen."
        case .edge: "Choose what sits at your edge."
        case .sound: "Hear it when Claude needs you."
        case .ready: "You're set. One thing in Claude Code."
        }
    }

    public var paragraph: String {
        switch self {
        case .hello:
            "Claude keeps a board as it works. SitRep keeps it beside you, lights up when a session needs you, and "
                + "takes you to the window it's in."
        case .edge: "Watch it change as you choose. It's all in Settings later."
        case .sound: "Once per new ask, whichever session it lands in. Pick one to hear it."
        case .ready: "Windows already open join the board at their next reload. New ones join by themselves."
        }
    }

    /// What the stage plays while the step shows.
    public var stage: WelcomeStage {
        switch self {
        case .hello: .loop
        case .edge: .lit
        case .sound: .chime
        case .ready: .callout
        }
    }
}

/// What the stage plays for a step: the notch's whole story on a loop; the notch lit, as for needs you; lit, swelling
/// with each sound chosen; or at rest, with the callout beside it.
public enum WelcomeStage: Equatable, Sendable {
    case loop, lit, chime, callout
}

/// The welcome's steps, in their order, and the one Lee is on. The list is data: a step comes or goes in `all` alone.
public struct WelcomeSteps: Equatable, Sendable {
    /// Every step, first to last.
    public static let all: [WelcomeStep] = [.hello, .edge, .sound, .ready]

    public let steps: [WelcomeStep]
    public private(set) var index = 0

    public init(_ steps: [WelcomeStep] = all) {
        precondition(!steps.isEmpty, "a welcome has a step")
        self.steps = steps
    }

    public var current: WelcomeStep { steps[index] }
    public var isFirst: Bool { index == 0 }
    public var isLast: Bool { index == steps.count - 1 }

    /// On to the next step; at the last, nowhere.
    public mutating func next() {
        index = min(index + 1, steps.count - 1)
    }

    /// Back to the step before; at the first, nowhere.
    public mutating func back() {
        index = max(index - 1, 0)
    }

    /// Back to the first step, as the menu's Welcome… opens it.
    public mutating func restart() {
        index = 0
    }

    /// The footer as it stands at this step.
    public var footer: WelcomeFooter {
        WelcomeFooter(
            canGoBack: !isFirst,
            dashes: steps.indices.map { $0 < index ? .done : $0 == index ? .current : .ahead },
            continueTitle: isLast ? "Done" : isFirst ? "Show me" : "Continue",
            showsSkip: !isLast
        )
    }
}

/// The footer, which never moves: the back chevron, dimmed at the first step; a dash for each step, the one Lee is on
/// long and blue, those behind lit; Skip setup, gone at the last step with nothing left to skip; and Continue ↵, which
/// reads Show me at the first and Done at the last.
public struct WelcomeFooter: Equatable, Sendable {
    public enum Dash: Equatable, Sendable {
        case done, current, ahead
    }

    public let canGoBack: Bool
    public let dashes: [Dash]
    public let continueTitle: String
    public let showsSkip: Bool

    public init(canGoBack: Bool, dashes: [Dash], continueTitle: String, showsSkip: Bool) {
        self.canGoBack = canGoBack
        self.dashes = dashes
        self.continueTitle = continueTitle
        self.showsSkip = showsSkip
    }
}

/// Whether a welcome has closed on this Mac, kept apart from what Lee sets, as the Settings window's pane is: a welcome
/// opened again after one has closed changes nothing Lee chose elsewhere, the login item above all.
public struct WelcomeSettings: SavedValue {
    public static let key = "welcome"

    public var welcomed = false

    public init() {}

    public init(welcomed: Bool) {
        self.welcomed = welcomed
    }

    public init(from decoder: any Decoder) {
        let defaults = WelcomeSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        welcomed = given.value(.welcomed, or: defaults.welcomed)
    }
}

/// What the welcome does to the login item, which is SitRep's real one, as General's switch is. In the first welcome,
/// none having closed before it, Open SitRep at login is on by default: SitRep is registered as Lee arrives at its
/// step, so macOS's notice comes as the stage shows it, or as the window closes if he never got there. Once he presses
/// the switch, or the welcome has registered it, it is his. A welcome opened again changes nothing until pressed.
public struct WelcomeLogin: Equatable, Sendable {
    public let isFirst: Bool
    public private(set) var isSettled = false

    public init(isFirst: Bool) {
        self.isFirst = isFirst
    }

    /// Arrived at the switch's step, the item as it stands: whether to register SitRep now.
    public mutating func arrive(_ item: LoginItem) -> Bool {
        registers(item)
    }

    /// Lee pressed the switch: the item is left as he set it.
    public mutating func press() {
        isSettled = true
    }

    /// The window closing, however it closes, the item as it stands: whether to register SitRep now.
    public mutating func close(_ item: LoginItem) -> Bool {
        registers(item)
    }

    /// Registered only once, in the first welcome, where nothing settled it and it is not registered already; never
    /// while macOS waits on Lee's approval.
    private mutating func registers(_ item: LoginItem) -> Bool {
        defer { isSettled = true }
        return isFirst && !isSettled && item.choice == .register
    }
}

/// The sounds as the welcome lists them: the four most distinct first, Glass leading, then the rest in Finder's order.
/// Four rows show and the rest are a scroll away, the fourth saying how many more there are; No sound follows them,
/// after a hairline.
public struct WelcomeSounds: Equatable, Sendable {
    /// Those listed first, where macOS has them (Paper's board D).
    public static let leading = ["Glass", "Ping", "Pop", "Tink"]
    /// The rows that show before the list scrolls.
    public static let shown = 4

    public let names: [String]

    /// macOS's alert sounds, in Finder's order (`AlertSounds`).
    public init(_ names: [String]) {
        let leading = Self.leading.filter(names.contains)

        self.names = leading + names.filter { !leading.contains($0) }
    }

    /// How many are a scroll away.
    public var more: Int { max(0, names.count - Self.shown) }

    /// The sound to scroll to as the list appears: the one chosen, where it sits a scroll away; else none.
    public func scrolledTo(_ chosen: String) -> String? {
        names.firstIndex(of: chosen).map { $0 >= Self.shown } == true ? chosen : nil
    }

    /// What a row says at its right: "and 10 more" on the last that shows, while any are a scroll away.
    public func aside(at index: Int) -> String? {
        index == Self.shown - 1 && more > 0 ? "and \(more) more" : nil
    }
}

/// Step 3's grouped form under the two pictures: Style for the notch, or Length for the strip in its place, so the
/// form keeps its height; then Material, from macOS 26 only; then Edge. Nothing, neither shape, stays in Settings.
public enum WelcomeEdgeForm {
    public enum Row: Hashable, Sendable {
        case style, length, material, edge
    }

    public static func rows(_ settings: EdgeSettings, hasGlass: Bool) -> [Row] {
        [settings.show == .strip ? .length : .style] + (hasGlass ? [.material] : []) + [.edge]
    }
}

/// The last step's playback: Lee's choices in four rows, in what-happens words, read from the real settings, each with
/// its fix in place where something was left off.
public enum WelcomePlayback {
    /// A row: what it is about, what happens, and the button that fixes what was left off, if anything was.
    public struct Row: Equatable, Sendable {
        public let label: String
        public let words: String
        public let fix: Fix?

        public init(label: String, words: String, fix: Fix?) {
            self.label = label
            self.words = words
            self.fix = fix
        }
    }

    /// What a row's button does.
    public enum Fix: Equatable, Sendable {
        /// Registers SitRep to open at login.
        case turnOnLogin
        /// System Settings' Login Items, where macOS waits on Lee's approval.
        case loginItems

        public var title: String {
            switch self {
            case .turnOnLogin: "Turn On"
            case .loginItems: "Login Items Settings…"
            }
        }
    }

    /// At the edge, A new ask, At login and A click, with `sound` the one a new ask plays, as `AlertSounds` reads it.
    public static func rows(edge: EdgeSettings, app: AppSettings, sound: String, login: LoginItem) -> [Row] {
        [
            Row(label: "At the edge", words: atTheEdge(edge), fix: nil),
            Row(label: "A new ask", words: newAsk(app, sound: sound), fix: nil),
            atLogin(login),
            Row(label: "A click", words: "Opens Ghostty", fix: nil),
        ]
    }

    /// "Meniscus notch, left", "Strip, right"; with Nothing, set in Settings, the menu bar's light.
    public static func atTheEdge(_ settings: EdgeSettings) -> String {
        let edge = settings.edge.title.lowercased()

        return switch settings.show {
        case .notch: "\(settings.style.title) notch, \(edge)"
        case .strip: "Strip, \(edge)"
        case .nothing: "The menu bar's light alone"
        }
    }

    /// "Glass, and a notification", "Glass", "A notification", or for neither, "Silent".
    public static func newAsk(_ app: AppSettings, sound: String) -> String {
        switch (app.playsSound, app.notifiesNewAsks) {
        case (true, true): "\(sound), and a notification"
        case (true, false): sound
        case (false, true): "A notification"
        case (false, false): "Silent"
        }
    }

    /// "Opens SitRep"; off, with Turn On; waiting on Lee's approval, with Login Items Settings…, as General has it.
    public static func atLogin(_ item: LoginItem) -> Row {
        switch item.choice {
        case .unregister: Row(label: "At login", words: "Opens SitRep", fix: nil)
        case .register: Row(label: "At login", words: "Doesn't open SitRep", fix: .turnOnLogin)
        case .openSettings: Row(label: "At login", words: "Waits for your approval", fix: .loginItems)
        }
    }
}

/// What the last step asks of Claude Code: `/reload-plugins` in each window already open; or, where the plugin's first
/// install failed, what failed, in the words of Settings' row for the plugin.
public enum WelcomeReload: Equatable, Sendable {
    case command(String)
    case trouble(SettingsRow)

    /// The plugin as SitRep found it, nil while it looks.
    public init(_ plugin: PluginStanding?) {
        if let plugin, plugin.trouble != nil {
            self = .trouble(.plugin(LastBoard(), plugin: plugin))
        } else {
            self = .command(ClaudeCodePane.command)
        }
    }
}
