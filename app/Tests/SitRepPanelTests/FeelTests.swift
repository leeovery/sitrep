import Foundation
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// A spring as the design's tables print it: response·dampingFraction, to two decimals.
private func shown(_ p: SpringParams) -> String {
    String(format: "%.2f·%.2f", p.response, p.damping)
}

// How each form moves ships fixed at Lee's settings, and its springs after them are the design's tables.

@Suite(.backstop)
struct MeniscusFeelTests {
    @Test func itIsLeesRoundElevenWithTheSwellFromTheApp() {
        let feel = MeniscusFeel.lees

        #expect([feel.bounce, feel.pull, feel.hold, feel.reach, feel.push, feel.land, feel.close, feel.swell] == [
            0.90, 0.35, 35, 10, 20, 1.11, 1.81, 25,
        ])
        #expect(feel.swells == 2)
    }

    @Test func itsSpringsAfterBounceAreTheDesignsTable() {
        let feel = MeniscusFeel.lees
        let table: [(MeniscusSpring, String)] = [
            (.attract, "0.20·0.57"), (.relax, "0.45·0.42"), (.home, "0.60·0.61"), (.pourH, "0.40·0.57"),
            (.pourW, "0.34·0.55"), (.cling, "0.24·0.55"), (.clingY, "0.16·0.65"), (.tongue, "0.08·0.61"),
            (.ret, "0.30·0.29"), (.ring, "0.17·0.29"), (.letGo, "0.30·0.38"), (.drain, "0.60·0.95"),
            (.land, "0.19·0.24"), (.rebound, "0.20·0.42"), (.ask, "0.42·0.38"),
        ]

        #expect(table.map { shown(feel.sp($0.0)) } == table.map(\.1))
        #expect(table.count == MeniscusSpring.allCases.count)
    }

    @Test func pullMakesAFieldOf49ATongueOf7Point7AndAClingOf2Point1() {
        let feel = MeniscusFeel.lees

        #expect(feel.field.rounded() == 49)
        #expect(String(format: "%.1f %.1f", Tuning.attractCap * feel.pull, Tuning.clingA * feel.pull) == "7.7 2.1")
    }

    @Test(arguments: [(0.0, 1.4), (0.5, 1.0), (1.0, 0.7)])
    func bounceScalesEveryDampingFraction(bounce: Double, scale: Double) {
        var feel = MeniscusFeel.lees
        feel.bounce = bounce

        #expect(abs(feel.bounceScale - scale) < 1e-12)
        for kind in MeniscusSpring.allCases {
            #expect(feel.sp(kind).response == kind.listed.response)
            #expect(abs(feel.sp(kind).damping - min(1, kind.listed.damping * scale)) < 1e-12)
        }
    }

    @Test func noBounceCapsTheDampingFractionAtOne() {
        var feel = MeniscusFeel.lees
        feel.bounce = 0

        #expect(feel.sp(.attract).damping == 1)
        #expect(feel.sp(.drain).damping == 1)
        #expect(abs(feel.sp(.ring).damping - 0.532) < 1e-12)
    }
}

@Suite(.backstop)
struct CardFeelTests {
    @Test func itIsLeesRoundTwo() {
        let feel = CardFeel.lees

        #expect([feel.bounce, feel.nudge, feel.slide, feel.lag, feel.close, feel.swell] == [0.70, 8, 0.93, 30, 0.88, 25])
        #expect(feel.swells == 2)
    }

    @Test func itsSpringsAfterBounceSlideAndCloseAreTheDesignsTable() {
        let feel = CardFeel.lees

        #expect(CardSpring.allCases.map { shown(feel.sp($0)) } == [
            "0.19·0.70", "0.17·0.75", "0.24·0.79", "0.14·1.00", "0.16·1.00", "0.25·0.79", "0.32·0.53",
        ])
    }

    @Test func slideSpeedsTheOpeningSpringsAndCloseTheClosingOnesAndNothingElse() {
        var feel = CardFeel.lees
        feel.bounce = 0.5
        feel.slide = 2
        feel.close = 0.5

        let responses = CardSpring.allCases.map { feel.sp($0).response / $0.listed.response }

        #expect(responses == [0.5, 0.5, 1, 2, 2, 1, 1])
        expectEvery(CardSpring.allCases) { feel.sp($0).damping == min(1, $0.listed.damping) }
    }
}

@Suite(.backstop)
struct StripFeelTests {
    @Test func itIsThePrototypesDefaultsAsLeeKeptThem() {
        let feel = StripFeel.lees

        #expect([
            feel.bounce, feel.dwell, feel.reach, feel.pour, feel.glide, feel.fade, feel.close, feel.room, feel.grace,
            feel.settle, feel.slide, feel.lead,
        ] == [0.50, 120, 3, 1, 1, 160, 1, 12, 300, 1000, 1, 1.25])
        #expect(feel.swells == 2)
    }

    @Test func itsSpringsAfterBounceAreTheDesignsTable() {
        let feel = StripFeel.lees

        #expect(StripSpring.allCases.map { shown(feel.sp($0)) } == [
            "0.20·0.70", "0.26·0.72", "0.22·0.80", "0.24·0.82", "0.24·0.86", "0.22·0.80", "0.36·0.80", "0.30·0.55",
            "0.10·0.70", "0.42·0.86",
        ])
        #expect([shown(feel.ends(growing: true)), shown(feel.ends(growing: false))] == ["0.29·0.80", "0.45·0.80"])
    }

    @Test func eachSpeedSpeedsItsOwnSpringsAndNothingElse() {
        var feel = StripFeel.lees
        feel.pour = 2
        feel.glide = 0.5
        feel.close = 1.25
        feel.slide = 1.6

        let responses = StripSpring.allCases.map { feel.sp($0).response / $0.listed.response }

        #expect(responses.map { ($0 * 1e9).rounded() / 1e9 } == [0.5, 0.5, 0.5, 2, 2, 0.8, 0.625, 0.625, 1, 1])
    }

    /// Lead: the ends' spring, from the marks' slide, quicker growing and slower shrinking.
    @Test func leadQuickensTheEndsGrowingAndSlowsThemShrinking() {
        var feel = StripFeel.lees
        feel.lead = 2

        #expect(feel.ends(growing: true) == SpringParams(response: 0.18, damping: 0.80))
        #expect(feel.ends(growing: false) == SpringParams(response: 0.72, damping: 0.80))
    }
}
