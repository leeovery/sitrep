import Testing

extension Tag {
    /// A test that runs a real program, or reads what this Mac holds: the kernel's processes, macOS's own sounds, an
    /// app running. Slower than the rest, and at the mercy of the Mac it runs on, so they can be run or skipped as one.
    @Tag public static var process: Self
}
