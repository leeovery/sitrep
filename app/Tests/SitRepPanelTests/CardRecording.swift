@testable import SitRepPanel

/// The card prototype at Lee's settings, recorded in the browser a frame at a time (its recorder, `harness/record.mjs`,
/// kept in Lee's clone at `.scratch/surfaces-tools/card/`): an open from rest with something needing Lee, then a
/// close, each frame's time since the call, the phase, the depth, the length, the light's dimming and the head's
/// opacity, a JSON file of each in `Recorded/Card`. The panel's content was 482 long.
struct Recorded {
    let t: Double
    let phase: Phase
    let w, h, vis, head: Double

    static let contentLength = 482.0

    static let opening: [Self] = Recordings.frames("opening", in: "Card")

    static let closing: [Self] = Recordings.frames("closing", in: "Card")
}

extension Recorded: Decodable {
    private enum Keys: String, CodingKey {
        case t, phase, w, h, vis, head
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let phase: Phase = switch try c.decode(String.self, forKey: .phase) {
        case "closed": .closed
        case "opening": .opening
        case "open": .open
        case "closing": .closing
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .phase, in: c, debugDescription: "No phase \(other)")
        }
        try self.init(
            t: c.decode(Double.self, forKey: .t), phase: phase, w: c.decode(Double.self, forKey: .w),
            h: c.decode(Double.self, forKey: .h), vis: c.decode(Double.self, forKey: .vis),
            head: c.decode(Double.self, forKey: .head)
        )
    }
}
