import Foundation

/// Output as it comes, in chunks, made lines: a line is whole once its
/// newline comes. Each chunk is scanned once, and a line is kept only up to
/// its longest, the rest of it dropped, so output with no newline costs no
/// more than that. Blank lines are dropped, as nothing is said in them.
struct LineBuffer {
    private static let newline = UInt8(ascii: "\n")

    let longest: Int
    /// The line under way, kept to its longest.
    private(set) var unended = Data()

    init(longest: Int) {
        self.longest = longest
    }

    /// The lines the chunk ends; what it leaves unended is kept for the next.
    mutating func lines(adding chunk: Data) -> [String] {
        var lines: [String] = []
        var start = chunk.startIndex

        while let end = chunk[start...].firstIndex(of: Self.newline) {
            keep(chunk[start..<end])

            if let line = rest() {
                lines.append(line)
            }

            start = chunk.index(after: end)
        }

        keep(chunk[start...])

        return lines
    }

    /// What is left unended, as the output closes.
    mutating func rest() -> String? {
        defer { unended = Data() }

        return unended.isEmpty ? nil : String(decoding: unended, as: UTF8.self)
    }

    private mutating func keep(_ part: Data) {
        unended.append(part.prefix(longest - unended.count))
    }
}
