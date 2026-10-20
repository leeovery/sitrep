import CoreGraphics

extension Strip {
    /// The prototype's `moveEdge`, which a drag let go across the screen's middle sets off: any tab draws back, the
    /// strip drains into this edge over 170ms, its marks out in 90; at 200 it swaps to the other edge
    /// (`StripFrame.swapsEdge`), its tabs gone, and grows out of it over 320, its marks back over 260; at 520 it takes
    /// the pointer again. Under reduced motion it swaps at once, its old black fading out, its marks fading in.
    func cross() {
        guard !crossing else {
            return
        }

        tabs.forEach { drawBack($0) }
        cancel(.dwell, .grace)
        crossing = true
        hot = nil
        guard !reducesMotion else {
            fade = (lastStrip ?? CGMutablePath(), t)
            swap()
            sw.snap(StripTuning.width)
            mvis.x = 0
            to(&mvis, 1, 160)
            return later(.crossDone, 160) { $0.crossing = false }
        }

        to(&sw, 0, 170)
        to(&mvis, 0, 90)
        later(.crossSwap, 200) { strip in
            strip.swap()
            strip.to(&strip.sw, StripTuning.width, 320)
            strip.to(&strip.mvis, 1, 260)
        }
        later(.crossDone, 520) { $0.crossing = false }
    }

    /// On the other edge from this frame, with no tab.
    private func swap() {
        tabs.forEach(removeTab)
        swapsEdge = true
    }
}
