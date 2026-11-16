@testable import SitRep
import SitRepEdge
@testable import SitRepPanel
import SitRepPanelTestSupport

extension StripScene {
    /// A full strip on a 1512 by 982 screen, no session on it and nothing under the pointer, at time 0.
    @MainActor
    static func resting() -> StripScene {
        let stage = StripStage(width: 1512, height: 982, menu: 37)
        let input = StripInput(time: 0, pointer: nil, stage: stage)
        let measure = StripMeasure.uniform(200)
        let strip = Strip(length: .full, maxLength: .full, along: 0.42, sessions: [], measure: measure, input)

        return StripScene(
            frame: strip.frame(input), hoverRow: nil, note: StripNote(), now: 0, mirror: .identity, menu: 37,
            reducesMotion: false
        )
    }
}
