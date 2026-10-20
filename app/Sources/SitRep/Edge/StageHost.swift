import AppKit

/// A view hosting a layer tree drawn top-down, y down from the view's top, as the stage is: every drawing of an edge
/// hosts its layers in one. AppKit sets a hosted layer's flip from its view's, whatever the layer says, so a layer
/// hosted in an unflipped view draws upside down in its window.
@MainActor
class StageHost: NSView {
    init(hosting root: CALayer) {
        super.init(frame: .zero)
        layer = root
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }
}
