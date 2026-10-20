import CoreGraphics
@testable import SitRepPanel

/// A frame of the strip as its prototype recorded it, in `Recorded/Strip`, loaded by `StripRecording.swift`. In the
/// JSON a frame and a tab are objects; a mark, the ends, a count, a tab's end, a word and the pointer are each a list
/// of their values in order.
struct StripRecorded {
    struct Tab {
        let key: String
        let phase: StripTab.Phase
        let w, h, y, press, alpha: Double
        /// Each of its words' opacity, by its key, in its order.
        let words: [Words]
        /// While it is out, where its top and its bottom meet the strip's ends.
        let top, bottom: End?
    }

    /// Where a tab's fillet leaves the strip's edge, on the screen, its radius, the edge's direction there in degrees,
    /// and whether that is on the S or the straight edge.
    struct End {
        enum On: String, Decodable { case s, edge }

        let x, y, rho, phi: Double
        let on: On
    }

    struct Words: Equatable {
        let key: String
        let alpha: Double
    }

    /// A spring's three: for a mark its centre, scale and opacity; for the hairline its y and opacity.
    struct Mark {
        let y, sc, op: Double
    }

    /// A count: how many it holds, and its mark's three.
    struct Count {
        let n: Int
        let mark: Mark
    }

    /// The strip's ends: where its top S and its bottom S leave the screen's edge, and how far it has drawn back into
    /// the notch at rest.
    struct Ends {
        let top, bottom, drawnIn: Double
    }

    let t: Double
    /// The pointer as the strip took it; nil off the page.
    let p: CGPoint?
    let hair: Mark
    let ends: Ends
    /// "mark s6" or "tab s7": a click jumping.
    let jumping: String?
    let tabs: [Tab]
    /// The scenario's marks, in its order; nil for one not on the strip.
    let marks: [Mark?]
    let more: Count?
    let moreNeeds: Count?
}

extension StripRecorded: Decodable {
    private enum Keys: String, CodingKey {
        case t, p, hair, ends, jumping, tabs, marks, more, moreNeeds
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        try self.init(
            t: c.decode(Double.self, forKey: .t), p: c.decode(Pointer?.self, forKey: .p)?.at,
            hair: c.decode(Mark.self, forKey: .hair), ends: c.decode(Ends.self, forKey: .ends),
            jumping: c.decodeIfPresent(String.self, forKey: .jumping),
            tabs: c.decodeIfPresent([Tab].self, forKey: .tabs) ?? [],
            marks: c.decodeIfPresent([Mark?].self, forKey: .marks) ?? [],
            more: c.decodeIfPresent(Count.self, forKey: .more),
            moreNeeds: c.decodeIfPresent(Count.self, forKey: .moreNeeds)
        )
    }
}

extension StripRecorded.Tab: Decodable {
    private enum Keys: String, CodingKey {
        case key, phase, w, h, y, press, alpha, words, top, bottom
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let phase: StripTab.Phase = switch try c.decode(String.self, forKey: .phase) {
        case "reach": .reach
        case "open": .open
        case "closing": .closing
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .phase, in: c, debugDescription: "No phase \(other)")
        }
        try self.init(
            key: c.decode(String.self, forKey: .key), phase: phase, w: c.decode(Double.self, forKey: .w),
            h: c.decode(Double.self, forKey: .h), y: c.decode(Double.self, forKey: .y),
            press: c.decode(Double.self, forKey: .press), alpha: c.decode(Double.self, forKey: .alpha),
            words: c.decode([StripRecorded.Words].self, forKey: .words),
            top: c.decodeIfPresent(StripRecorded.End.self, forKey: .top),
            bottom: c.decodeIfPresent(StripRecorded.End.self, forKey: .bottom)
        )
    }
}

extension StripRecorded.End: Decodable {
    init(from decoder: any Decoder) throws {
        self = try decoder.values { c in
            try Self(
                x: c.decode(Double.self), y: c.decode(Double.self), rho: c.decode(Double.self),
                phi: c.decode(Double.self), on: c.decode(On.self)
            )
        }
    }
}

extension StripRecorded.Words: Decodable {
    init(from decoder: any Decoder) throws {
        self = try decoder.values { c in try Self(key: c.decode(String.self), alpha: c.decode(Double.self)) }
    }
}

extension StripRecorded.Mark: Decodable {
    init(from decoder: any Decoder) throws {
        self = try decoder.values { c in try Self(&c) }
    }

    /// The three, next in a count's or a mark's values.
    fileprivate init(_ c: inout any UnkeyedDecodingContainer) throws {
        try self.init(y: c.decode(Double.self), sc: c.decode(Double.self), op: c.decode(Double.self))
    }
}

extension StripRecorded.Count: Decodable {
    init(from decoder: any Decoder) throws {
        self = try decoder.values { c in try Self(n: c.decode(Int.self), mark: StripRecorded.Mark(&c)) }
    }
}

extension StripRecorded.Ends: Decodable {
    init(from decoder: any Decoder) throws {
        self = try decoder.values { c in
            try Self(top: c.decode(Double.self), bottom: c.decode(Double.self), drawnIn: c.decode(Double.self))
        }
    }
}

/// The pointer, as its x and y; CGPoint's own decoding would pass over a third.
private struct Pointer: Decodable {
    let at: CGPoint

    init(from decoder: any Decoder) throws {
        at = try decoder.values { c in try CGPoint(x: c.decode(Double.self), y: c.decode(Double.self)) }
    }
}

extension Decoder {
    /// A list of values read in order, failing if any are left over once they are read.
    fileprivate func values<T>(_ read: (inout any UnkeyedDecodingContainer) throws -> T) throws -> T {
        var c = try unkeyedContainer()
        let value = try read(&c)
        guard c.isAtEnd else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: codingPath, debugDescription: "More than the \(c.currentIndex) values expected")
            )
        }
        return value
    }
}
