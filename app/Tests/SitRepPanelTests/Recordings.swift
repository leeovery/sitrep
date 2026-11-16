import Foundation

/// A prototype's frames as the browser recorded them, a JSON file of them in `Recorded`.
///
/// Data, not Swift: as array literals they cost the type checker 20 GB and more per compile.
enum Recordings {
    /// The frames in `Recorded/<folder>/<name>.json`, in their order.
    static func frames<Frame: Decodable>(_ name: String, in folder: String) -> [Frame] {
        let subdirectory = "Recorded/\(folder)"
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: subdirectory) else {
            fatalError("The recording \(name) is missing from \(subdirectory)")
        }
        do {
            return try JSONDecoder().decode([Frame].self, from: Data(contentsOf: url))
        } catch {
            fatalError("The recording \(name) in \(subdirectory) doesn't decode: \(error)")
        }
    }
}
