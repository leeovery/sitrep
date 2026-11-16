import Foundation

/// The checkout these tests are in.
public enum Repository {
    /// Its root, three folders above this file's.
    public static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appending(path: "../../..").standardizedFileURL
}
