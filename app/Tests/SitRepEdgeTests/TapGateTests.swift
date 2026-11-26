import SitRepEdge
import SitRepTestSupport
import Testing

/// When the tap listens (DESIGN, "Keys"): while it is meant on, and after, until the last key it took or rewrote comes
/// up, so a key taken is taken whole though the panel closed under it; meant off, every new key goes through; and
/// macOS turning it off turns it on again only while it listens, so it is never left on at rest.
@Suite(.backstop)
struct TapGateTests {
    private static let holding = KeySnapshot.panel(hold: 1)
    private static let down = TapKey(code: KeyCode.down, typed: "\u{1F}")
    private static let k = TapKey(code: 40, typed: "k")

    private static func again(_ key: TapKey) -> TapKey {
        var key = key

        key.stroke = .again
        return key
    }

    private static func up(_ key: TapKey) -> TapKey {
        var key = key

        key.stroke = .up
        return key
    }

    @Test func turnedOnItIsEnabledDecidingByTheSnapshotAndOffItIsDisabled() {
        var gate = TapGate()

        #expect(!gate.listens && !gate.isEnabled)
        #expect(gate.turn(on: true, deciding: Self.holding) == true)
        #expect(gate.snapshot == Self.holding && gate.isEnabled)
        #expect(gate.turn(on: true, deciding: .none) == nil)
        #expect(gate.turn(on: false, deciding: .none) == false)
        #expect(!gate.isEnabled)
    }

    /// Off, it decides by nothing, whatever it was told it holds.
    @Test func meantOffEveryNewKeyGoesThrough() {
        var gate = TapGate()

        _ = gate.turn(on: false, deciding: Self.holding)
        #expect(gate.snapshot == .none)
        #expect(gate.read(Self.k).verdict == .pass)
    }

    /// Turned off with a taken key down, as the panel's grace closes it under a held `↓`: it stays enabled, a new key
    /// going through, the held key's repeats and key-up going nowhere, and is disabled as that key comes up.
    @Test func turnedOffWithATakenKeyDownItListensUntilThatKeyComesUp() {
        var gate = TapGate()

        _ = gate.turn(on: true, deciding: Self.holding)
        #expect(gate.read(Self.down) == (.take(.panel(.down)), nil))
        #expect(gate.turn(on: false, deciding: Self.holding) == nil)
        #expect(gate.listens && gate.isEnabled)

        #expect(gate.read(Self.k) == (.pass, nil))
        #expect(gate.read(Self.again(Self.down)) == (.take(nil), nil))
        #expect(gate.read(Self.up(Self.down)) == (.take(nil), false))
        #expect(!gate.listens && !gate.isEnabled)
    }

    /// A key rewritten in a snooze menu that closed while it was held comes up as the arrow it went down as.
    @Test func aRewrittenKeyHeldAsTheMenuClosesComesUpRewritten() {
        var gate = TapGate()

        _ = gate.turn(on: true, deciding: .menu(choices: 4))
        #expect(gate.read(Self.k) == (.rewrite(to: KeyCode.up), nil))
        #expect(gate.turn(on: false, deciding: .none) == nil)
        #expect(gate.read(Self.up(Self.k)) == (.rewrite(to: KeyCode.up), false))
    }

    /// Turned on again, a key taken before still comes up taken: the keys down are kept.
    @Test func turningOnAgainKeepsTheKeysDown() {
        var gate = TapGate()

        _ = gate.turn(on: true, deciding: Self.holding)
        _ = gate.read(Self.down)
        _ = gate.turn(on: false, deciding: .none)
        _ = gate.turn(on: true, deciding: .none)
        #expect(gate.read(Self.up(Self.down)).verdict == .take(nil))
    }

    /// macOS turning it off, slow to answer or as input it can't see starts: on again while it is meant on, or a key
    /// it took is down; at rest, left off.
    @Test func turnedOffByMacOSItIsOnAgainOnlyWhileItListens() {
        var rest = TapGate(), on = TapGate(), held = TapGate()

        #expect(rest.turnedOff() == nil && !rest.isEnabled)

        _ = on.turn(on: true, deciding: Self.holding)
        #expect(on.turnedOff() == true && on.isEnabled)

        _ = held.turn(on: true, deciding: Self.holding)
        _ = held.read(Self.down)
        _ = held.turn(on: false, deciding: .none)
        #expect(held.turnedOff() == true)
        _ = held.read(Self.up(Self.down))
        #expect(held.turnedOff() == nil && !held.isEnabled)
    }
}
