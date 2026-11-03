import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepRelay

/// A step of the welcome window (DESIGN, "The welcome window"): its headline, the grey paragraph under it, and what
/// its stage plays.
public enum WelcomeStep: String, Sendable {
    case hello, ask, edge, sound, permissions, ready

    /// Two lines at most, in the column's 330.
    public var headline: String {
        switch self {
        case .hello: "Every session, at the edge of your screen."
        case .ask: "Claude asks. You answer."
        case .edge: "Choose what sits at your edge."
        case .sound: "Hear it when Claude needs you."
        case .permissions: "Two things to allow, both optional."
        case .ready: "You're set. One thing in Claude Code."
        }
    }

    public var paragraph: String {
        switch self {
        case .hello:
            "Claude keeps a board as it works. SitRep keeps it beside you, lights up when a session needs you, and "
                + "takes you to the window it's in."
        case .ask:
            "When a session needs you, the notch lights. Open it, pick the ask, and you're in the session's window "
                + "to answer."
        case .edge: "Watch it change as you choose. It's all in Settings later."
        case .sound: "Once per new ask, whichever session it lands in. Pick one to hear it."
        case .permissions: "SitRep works without either. Each one turns on one thing."
        case .ready: "Windows already open join the board at their next reload. New ones join by themselves."
        }
    }

    /// What the stage plays while the step shows.
    public var stage: WelcomeStage {
        switch self {
        case .hello: .loop
        case .ask: .answer
        case .edge, .permissions: .lit
        case .sound: .chime
        case .ready: .callout
        }
    }
}

/// What the stage plays for a step: the notch's whole story on a loop; an ask landing and answered in its session, on
/// a loop; the notch lit, as for needs you; lit, swelling with each sound chosen; or at rest, with the callout beside
/// it.
public enum WelcomeStage: Equatable, Sendable {
    case loop, answer, lit, chime, callout

    /// The loop it plays, if it plays one.
    public var loop: WelcomeLoop? {
        switch self {
        case .loop: .hello
        case .answer: .ask
        case .lit, .chime, .callout: nil
        }
    }
}

/// The welcome's steps, in their order, and the one Lee is on. The list is data: a step comes or goes in `all` alone.
public struct WelcomeSteps: Equatable, Sendable {
    /// Every step, first to last.
    public static let all: [WelcomeStep] = [.hello, .ask, .edge, .sound, .permissions, .ready]

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
            continueTitle: isLast ? "Done" : "Continue",
            showsSkip: !isLast
        )
    }
}

/// The footer, which never moves: the back chevron, dimmed at the first step; a dash for each step, the one Lee is on
/// long and blue, those behind lit; Skip setup, gone at the last step with nothing left to skip; and Continue ↵, which
/// reads Done at the last.
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
/// the switch, the welcome has registered it, or it is found on, or changed since it was last read, as Lee may change
/// it in Settings › General, it is his. A welcome opened again changes nothing until pressed.
public struct WelcomeLogin: Equatable, Sendable {
    public let isFirst: Bool
    public private(set) var isSettled = false
    private var last: LoginItem?

    public init(isFirst: Bool) {
        self.isFirst = isFirst
    }

    /// The item as macOS says it now: found on, or changed from the last read, it is Lee's.
    public mutating func read(_ item: LoginItem) {
        if item.isOn || last.map({ $0 != item }) == true {
            isSettled = true
        }
        last = item
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
        read(item)
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
/// form keeps its height; then Material, from macOS 26 only; then Edge; and under it, Show nothing at the edge. At
/// Nothing neither picture is chosen, and the rows stay in their place, taking no presses.
public enum WelcomeEdgeForm {
    public enum Row: Hashable, Sendable {
        case style, length, material, edge
    }

    /// Under the form: Show nothing at the edge, a link that sets Nothing; at Nothing, a line in its place, saying what
    /// is left and how to bring the edge back.
    public enum Under: Equatable, Sendable {
        case showNothing, nothingShown

        public var words: String {
            switch self {
            case .showNothing: "Show nothing at the edge"
            case .nothingShown: "Only the menu bar's light. Choose Notch or Strip to bring it back."
            }
        }
    }

    public static func rows(_ settings: EdgeSettings, hasGlass: Bool) -> [Row] {
        [settings.show == .strip ? .length : .style] + (hasGlass ? [.material] : []) + [.edge]
    }

    /// The picture ringed: the shape Lee chose, none at Nothing.
    public static func chosen(_ settings: EdgeSettings) -> EdgeSettings.Show? {
        settings.show == .nothing ? nil : settings.show
    }

    public static func takesPresses(_ settings: EdgeSettings) -> Bool {
        settings.show != .nothing
    }

    public static func under(_ settings: EdgeSettings) -> Under {
        settings.show == .nothing ? .nothingShown : .showNothing
    }
}

/// The last step's playback: Lee's choices in four rows, in what-happens words, read from the real settings, each with
/// its fix in place where something was left off.
public enum WelcomePlayback {
    /// A row: what it is about, what happens, and the button that fixes what was left off, if anything was; while the
    /// fix's ask is under way, a spinner in its place; and a line under it, saying where macOS asked or what went
    /// wrong.
    public struct Row: Equatable, Sendable {
        public let label: String
        public let words: String
        public let fix: Fix?
        public let isAsking: Bool
        public let line: String?

        public init(label: String, words: String, fix: Fix?, isAsking: Bool = false, line: String? = nil) {
            self.label = label
            self.words = words
            self.fix = fix
            self.isAsking = isAsking
            self.line = line
        }
    }

    /// What a row's button does.
    public enum Fix: Equatable, Sendable {
        /// Registers SitRep to open at login.
        case turnOnLogin
        /// System Settings' Login Items, where macOS waits on Lee's approval.
        case loginItems
        /// Step 5's Allow… for Ghostty, which opens it first where it isn't running.
        case allowGhostty
        /// System Settings' Automation, where Lee turns back on the leave he refused.
        case automation
        /// System Settings' Notifications, where Lee allows the notifications macOS shows none of.
        case notifications

        public var title: String {
            switch self {
            case .turnOnLogin: "Turn On"
            case .loginItems: "Login Items Settings…"
            case .allowGhostty: "Allow…"
            case .automation, .notifications: "Open System Settings…"
            }
        }
    }

    /// At the edge, A new ask, At login and A click, with `sound` the one a new ask plays, as `AlertSounds` reads it,
    /// and `notices` and `ghostty` where the two leaves stand, as step 5's rows show them, with what went wrong with
    /// Ghostty's last ask.
    public static func rows(
        edge: EdgeSettings, app: AppSettings, sound: String, notices: WelcomeLeave, login: LoginItem,
        ghostty: WelcomeLeave, hitch: WelcomeHitch? = nil
    ) -> [Row] {
        [
            Row(label: "At the edge", words: atTheEdge(edge), fix: nil),
            newAsk(app, sound: sound, notices: notices),
            atLogin(login),
            aClick(ghostty, hitch: hitch),
        ]
    }

    /// "Opens the session's window" with the leave; else "Opens Ghostty", as a click without it brings Ghostty forward
    /// but to none of its windows, with step 5's row in place: Allow…, and what went wrong with its last ask; its
    /// spinner while macOS asks, and where it asked once Lee has waited on it; once refused, the way to Automation;
    /// and with no Ghostty to open, "Needs Ghostty", with nothing to press.
    public static func aClick(_ ghostty: WelcomeLeave, hitch: WelcomeHitch? = nil) -> Row {
        let label = "A click", opens = "Opens Ghostty", line = WelcomePermission.ghostty.line(ghostty, hitch: hitch)

        return switch ghostty {
        case .on: Row(label: label, words: "Opens the session's window", fix: nil)
        case .refused: Row(label: label, words: opens, fix: .automation)
        case .toAsk: Row(label: label, words: opens, fix: .allowGhostty, line: line)
        case .asking: Row(label: label, words: opens, fix: nil, isAsking: true, line: line)
        case .unavailable: Row(label: label, words: "Needs Ghostty", fix: nil)
        }
    }

    /// "Meniscus notch, left", "Strip, right"; with Nothing, the menu bar's light.
    public static func atTheEdge(_ settings: EdgeSettings) -> String {
        let edge = settings.edge.title.lowercased()

        return switch settings.show {
        case .notch: "\(settings.style.title) notch, \(edge)"
        case .strip: "Strip, \(edge)"
        case .nothing: "The menu bar's light alone"
        }
    }

    /// "Glass, and a notification", "Glass", "A notification", or for neither, "Silent", with `notices` where step 5's
    /// row stands: while macOS shows none of SitRep's notifications, one Notify me promises is dropped, and the row
    /// has that row's Open System Settings… in place.
    public static func newAsk(_ app: AppSettings, sound: String, notices: WelcomeLeave = .toAsk) -> Row {
        let isRefused = app.notifiesNewAsks && notices == .refused
        let words = switch (app.playsSound, app.notifiesNewAsks && !isRefused) {
        case (true, true): "\(sound), and a notification"
        case (true, false): sound
        case (false, true): "A notification"
        case (false, false): "Silent"
        }

        return Row(label: "A new ask", words: words, fix: isRefused ? .notifications : nil)
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

/// Step 5's two rows: what each asks macOS for, its reason in one clause about something Lee watched, the button that
/// asks, and where macOS puts its prompt, said once Lee has waited on it.
public enum WelcomePermission: CaseIterable, Sendable {
    case notifications, ghostty

    /// How long a prompt goes unanswered before the row says where macOS put it.
    public static let patience: Duration = .seconds(10)
    /// How long Turn On… waits on the notices helper for macOS's answer before reading what macOS says instead, so a
    /// helper that never answers keeps the row spinning only while macOS's prompt is up.
    public static let limit: Duration = .seconds(60)

    public var title: String {
        switch self {
        case .notifications: "Notifications"
        case .ghostty: "Control Ghostty"
        }
    }

    public var reason: String {
        switch self {
        case .notifications: "So an ask reaches you when the edge is out of sight"
        case .ghostty: "So a click takes you to the session's window"
        }
    }

    /// Named for what it does, never dressed as macOS's own dialog.
    public var ask: String {
        switch self {
        case .notifications: "Turn On…"
        case .ghostty: "Allow…"
        }
    }

    /// Where macOS put its prompt: a notification of its own for SitRep's, a dialog for the Automation leave.
    public var whereAsked: String {
        switch self {
        case .notifications: "macOS asks in a notification, at the top right of your screen"
        case .ghostty: "macOS asks in a dialog, which may be behind Ghostty's window"
        }
    }

    /// The line under the row's reason, as the row stands: once Lee has waited on macOS's prompt, where it is; to ask,
    /// what went wrong with the last ask; with no Ghostty to open, why.
    public func line(_ leave: WelcomeLeave, hitch: WelcomeHitch?) -> String? {
        switch leave {
        case .asking(waitedLong: true): whereAsked
        case .toAsk: hitch?.words
        case .unavailable: WelcomeHitch.notInstalled.words
        case .asking, .on, .refused: nil
        }
    }
}

/// Where one of step 5's rows stands: to ask, a button; asking, a spinner, and once Lee has waited on it, where macOS
/// put its prompt; on, a green check; refused, the way to System Settings; or, with no Ghostty to open, nothing to ask.
public enum WelcomeLeave: Equatable, Sendable {
    case toAsk
    case asking(waitedLong: Bool)
    case on
    case refused
    case unavailable

    /// Notifications: on only with Notify me of a new ask on and macOS showing them; refused while macOS shows none,
    /// whatever the switch, as no press here would bring its prompt back; else, not yet read included, to ask.
    public static func notifications(_ leave: NoticeLeave?, isOn: Bool) -> WelcomeLeave {
        switch leave {
        case .denied?, .allowed(.none)?: .refused
        case .allowed?, .provisional?: isOn ? .on : .toAsk
        case .unasked?, nil: .toAsk
        }
    }

    /// Control Ghostty: macOS says only while Ghostty runs, so one it can't say of is to ask, as Allow… opens it.
    public static func ghostty(_ leave: GhosttyLeave?) -> WelcomeLeave {
        switch leave {
        case .allowed?: .on
        case .denied?: .refused
        case .unasked?, .unknown?, nil: .toAsk
        }
    }
}

/// What went wrong with a row's last ask, said under it: Ghostty not installed, so the row offers nothing until it is;
/// Ghostty not opening, so macOS couldn't ask; or no answer from macOS, through the notices helper or for Ghostty.
/// Either of the last two leaves the row's button to try again.
public enum WelcomeHitch: Equatable, Sendable {
    case notInstalled, didNotOpen, noAnswer

    public var words: String {
        switch self {
        case .notInstalled: "Ghostty isn't installed"
        case .didNotOpen: "Ghostty didn't open, so macOS couldn't ask"
        case .noAnswer: "SitRep couldn't get macOS's answer"
        }
    }
}

/// What opening Ghostty for Allow… came to: it runs, it isn't installed, or it didn't finish opening.
public enum GhosttyOpening: Equatable, Sendable {
    case runs, notInstalled, didNotOpen
}

/// The callout Done leaves beside the real notch, or the strip, at rest: due once Done closes a welcome, never by any
/// other close, and gone for good once Lee first points at the edge. Saved apart from what Lee sets, as whether a
/// welcome has closed is.
public struct CalloutSettings: SavedValue {
    public static let key = "notchCallout"

    public enum Standing: String, Codable, Sendable {
        case unshown, due, gone
    }

    public private(set) var standing = Standing.unshown

    public init() {}

    public init(_ standing: Standing) {
        self.standing = standing
    }

    public init(from decoder: any Decoder) {
        let defaults = CalloutSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        standing = given.value(.standing, or: defaults.standing)
    }

    /// Whether it shows beside the edge.
    public var shows: Bool { standing == .due }

    /// Done, with this shape at the edge: due, unless it has shown and gone, as it shows once. Done at Nothing leaves
    /// it as it stood, so one who chose to show nothing never meets it the day he picks a shape; one already due still
    /// waits for a shape.
    public mutating func done(_ show: EdgeSettings.Show) {
        if standing == .unshown, show != .nothing {
            standing = .due
        }
    }

    /// The first hover over the edge while it shows: gone for good.
    public mutating func pointedAt() {
        if standing == .due {
            standing = .gone
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
