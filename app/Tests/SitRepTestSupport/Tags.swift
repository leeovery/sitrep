import Testing

extension Tag {
    /// A test that leans on this Mac: it runs a real program, or reads what the Mac holds, the kernel's processes, an
    /// app running, macOS's own sounds, its accent colour or its Keyboard navigation setting. It only marks them, for
    /// a reader to see which they are: `swift test --filter` here selects by name alone, never by tag.
    @Tag public static var thisMac: Self
}
