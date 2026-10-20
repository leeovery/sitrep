import Foundation

/// What a folder marketplace's own `marketplace.json` says of its plugin `sitrep`: where it is within the folder, or
/// that Claude Code fetches it from elsewhere.
public enum MarketplaceEntry: Equatable, Sendable {
    /// Its source, a path within the marketplace's folder: `./` for sitrep's own.
    case within(String)
    /// A source Claude Code fetches, such as a repository, which it runs from its own copy.
    case fetched

    /// The entry for `sitrep` in the folder's `.claude-plugin/marketplace.json`; nil with none to read.
    public static func sitrep(in folder: String) -> MarketplaceEntry? {
        struct Listing: Decodable {
            struct Plugin: Decodable {
                let name: String
                /// Optional, so another plugin listed with none leaves sitrep's entry readable.
                let source: Source?
            }

            /// A path within the folder, or an object naming where Claude fetches it.
            enum Source: Decodable {
                case path(String)
                case fetched

                init(from decoder: Decoder) throws {
                    self = (try? decoder.singleValueContainer().decode(String.self)).map(Self.path) ?? .fetched
                }
            }

            let plugins: [Plugin]
        }

        let file = URL(fileURLWithPath: folder).appending(path: ".claude-plugin/marketplace.json")
        let listing = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Listing.self, from: $0) }

        return listing?.plugins.first { $0.name == "sitrep" }?.source.map { source in
            switch source {
            case let .path(path): .within(path)
            case .fetched: .fetched
            }
        }
    }
}
