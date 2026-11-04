import AppKit

extension NSSegmentedControl {
    /// A pair of the system's steps for a toolbar, as back and forward are in Finder's and Safari's: a segmented
    /// control of two chevrons, each its own button, VoiceOver reading each by its name, which is its tooltip too.
    static func steps(_ segments: [(symbol: String, name: String)]) -> NSSegmentedControl {
        let images = segments.map { symbol, name in
            NSImage(systemSymbolName: symbol, accessibilityDescription: name) ?? NSImage()
        }
        let control = NSSegmentedControl(images: images, trackingMode: .momentary, target: nil, action: nil)

        control.segmentStyle = .separated
        for (segment, step) in segments.enumerated() {
            control.setToolTip(step.name, forSegment: segment)
        }
        return control
    }
}
