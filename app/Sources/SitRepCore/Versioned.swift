import Foundation

/// JSON the CLI prints with its version as `v`. It is stable: every field is
/// always there, null where there is none, and `v` moves only with a change
/// a reader would trip on. Its times are milliseconds since 1970.
protocol Versioned: Decodable {
    /// The output's version this app reads.
    static var version: Int { get }
}

/// Why output of the CLI went unread.
public enum Unread: Error, Equatable, Sendable, CustomStringConvertible {
    case version(given: Int, read: Int)
    case shape

    public var description: String {
        switch self {
        case let .version(given, read):
            "gave output version \(given), and this SitRep reads version \(read)"
        case .shape:
            "gave output this SitRep cannot read"
        }
    }
}

extension Versioned {
    /// The output in the JSON given; throws `Unread` when it is not one this app
    /// reads. Its version is read first, so output of another version is named
    /// as such, whatever its shape.
    static func read(_ json: String) throws(Unread) -> Self {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .millisecondsSince1970

        guard let given = try? decoder.decode(Version.self, from: data) else {
            throw .shape
        }

        guard given.v == version else {
            throw .version(given: given.v, read: version)
        }

        guard let output = try? decoder.decode(Self.self, from: data) else {
            throw .shape
        }

        return output
    }
}

private struct Version: Decodable {
    let v: Int
}
