import Testing

extension Tag {
    /// A test that runs a real program, or reads what this Mac holds: the kernel's processes, an app running, macOS's
    /// own sounds, its accent colour or its Keyboard navigation setting. It marks them; `swift test --filter` here
    /// selects by name alone, never by tag.
    @Tag public static var process: Self
}
