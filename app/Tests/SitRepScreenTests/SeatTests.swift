import Darwin
@testable import SitRepScreen
import Testing

struct SeatTests {
    private static let ghostty = TerminalApp.driven(.ghostty)

    @Test func aClientsAppIsTheNearestItDescendsFromAndNoneForThePhonesOrAGhosttysOverSsh() {
        var tree = Tree()
        let ghostty = tree.app(ghosttyProgram)
        let inGhostty = tree.tmux(under: tree.window(of: ghostty, on: "/dev/ttys000"), on: "/dev/ttys000")
        let inTerminal = tree.tmux(under: tree.window(of: tree.app(terminalProgram), on: "/dev/ttys030"), on: "/dev/ttys030")
        let code = tree.add(under: tree.app("/Applications/Visual Studio Code.app/Contents/MacOS/Electron"), codeHelper)
        let inCode = tree.tmux(under: tree.add(under: code, "/bin/zsh", on: "/dev/ttys090"), on: "/dev/ttys090")
        let phone = tree.tmux(under: tree.shell(under: ["/opt/homebrew/bin/mosh-server"], on: "/dev/ttys067"), on: "/dev/ttys067")
        let ssh = tree.tmux(
            under: tree.shell(under: ["/usr/sbin/sshd", "/usr/libexec/sshd-session"], on: "/dev/ttys080"), on: "/dev/ttys080"
        )
        let processes = Processes(tree.processes)
        let appOf = { (pid: pid_t) in processes.seat(of: pid, own: "/dev/ttys999")?.app.name }

        #expect(processes.seat(of: inGhostty, own: "/dev/ttys000")?.app == Self.ghostty)
        #expect(appOf(inTerminal) == "Terminal")
        #expect(appOf(inCode) == "Visual Studio Code")
        #expect(appOf(phone) == nil)
        #expect(appOf(ssh) == nil)
    }

    @Test func aClientsDeviceIsTheTtyOfItsAppsOwnChildThroughAnyRelayingPty() {
        var tree = Tree()
        let shell = tree.window(of: tree.app(ghosttyProgram), on: "/dev/ttys036")
        let direct = tree.tmux(under: shell, on: "/dev/ttys036")
        let relayed = tree.zmx("kit", under: tree.relay(under: shell, on: "/dev/ttys036"), on: "/dev/ttys032")
        let scripted = tree.tmux(under: tree.relay(under: shell, on: "/dev/ttys036", "/usr/bin/script"), on: "/dev/ttys050")
        let processes = Processes(tree.processes)

        #expect(processes.seat(of: direct, own: "/dev/ttys036") == Seat(app: Self.ghostty, device: "/dev/ttys036"))
        #expect(processes.seat(of: relayed, own: "/dev/ttys032") == Seat(app: Self.ghostty, device: "/dev/ttys036"))
        #expect(processes.seat(of: scripted, own: "/dev/ttys050") == Seat(app: Self.ghostty, device: "/dev/ttys036"))
    }

    @Test func withTheAppsChildOnNoTtyTheClientsOwnDeviceIsTaken() {
        var tree = Tree()
        let login = tree.add(under: tree.app(ghosttyProgram), "/usr/bin/login")
        let client = tree.tmux(under: tree.add(under: login, "/bin/zsh"), on: "/dev/ttys040")

        #expect(Processes(tree.processes).seat(of: client, own: "/dev/ttys040") == Seat(app: Self.ghostty, device: "/dev/ttys040"))
    }

    @Test(arguments: ["", nil] as [String?])
    func aClientOnNoTtyOfItsOwnIsOnNoDeviceSoNoPlaceForADriver(own: String?) {
        var tree = Tree()
        let ghosttys = tree.tmux(under: tree.window(of: tree.app(ghosttyProgram), on: "/dev/ttys036"), on: nil)
        let terminals = tree.tmux(under: tree.window(of: tree.app(terminalProgram), on: "/dev/ttys030"), on: nil)
        let processes = Processes(tree.processes)

        #expect(processes.seat(of: ghosttys, own: own) == nil)
        #expect(processes.seat(of: terminals, own: own)?.device == nil)
        #expect(processes.seat(of: terminals, own: own)?.app.name == "Terminal", "an app with no driver needs no device")
    }

    @Test func aClientTheTableLacksOrWhoseAncestryLoopsHasNoSeat() {
        let looping = Processes([
            10: Proc(parent: 11, program: "/opt/homebrew/bin/tmux"),
            11: Proc(parent: 12, program: "/bin/zsh"),
            12: Proc(parent: 11, program: "/usr/bin/login"),
        ])

        #expect(looping.seat(of: 10, own: "/dev/ttys000") == nil)
        #expect(looping.seat(of: 99, own: "/dev/ttys000") == nil)
    }

    @Test func anAncestorWhoseProgramCannotBeReadIsNoApp() {
        var tree = Tree()
        let unread = tree.add(under: 1, nil)
        let client = tree.tmux(under: tree.add(under: unread, "/bin/zsh", on: "/dev/ttys001"), on: "/dev/ttys001")

        #expect(Processes(tree.processes).seat(of: client, own: "/dev/ttys001") == nil)
    }
}
