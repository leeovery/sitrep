import AppKit

@main
enum SitRepApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()

        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
