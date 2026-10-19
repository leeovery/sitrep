import Foundation
@testable import SitRepPanel
import Testing

struct StripSettingsTests {
    /// The prototype's Copy settings at its defaults, version 27.
    private static let lees = #"{"bounce":0.50,"dwell":120,"reach":3,"pour":1.00,"glide":1.00,"fade":160,"close":1.00,"room":12,"grace":300,"settle":1000,"slide":1.00,"lead":1.25,"max":"full","swells":2,"length":"grows","edge":"left"}"#

    @Test func theDefaultsAreLeesPrintedAsTheDesignAndTheCopySettingsJSONHaveThem() {
        #expect(StripSettings().json == Self.lees)
    }

    @Test func leesJSONReadsBackAsTheDefaults() throws {
        #expect(try StripSettings(json: Self.lees) == StripSettings())
    }

    /// The switches the prototype has dropped, Lee's choices now built in, are passed over.
    @Test func onlyTheLengthAndTheEdgeAreSwitchesStill() throws {
        let read = try StripSettings(json: #"{"between":"each","during":"stay","top":"hang","length":"full","edge":"right"}"#)

        var expected = StripSettings()
        expected.length = .full
        expected.edge = .right
        #expect(read == expected)
        #expect(read.json.hasSuffix(#""swells":2,"length":"full","edge":"right"}"#))
    }

    @Test func otherSettingsPrintAsThePrototypePrintsThem() {
        var settings = StripSettings()
        settings.bounce = 0.42
        settings.reach = 2.5
        settings.pour = 2
        settings.settle = 50
        settings.lead = 1.5
        settings.maxMarks = 6

        #expect(settings.json == #"{"bounce":0.42,"dwell":120,"reach":2.5,"pour":2.00,"glide":1.00,"fade":160,"close":1.00,"room":12,"grace":300,"settle":50,"slide":1.00,"lead":1.50,"max":6,"swells":2,"length":"grows","edge":"left"}"#)
    }

    @Test func eachDialGoesOntoItsSlidersRangeAndStep() throws {
        let read = try StripSettings(json: #"{"bounce":2,"dwell":124,"reach":2.7,"pour":0.1,"fade":10,"room":25,"grace":999,"settle":1020,"lead":1.27,"max":3,"swells":5}"#)

        #expect(read.bounce == 1)
        #expect(read.dwell == 120)
        #expect(read.reach == 2.5)
        #expect(read.pour == 0.5)
        #expect(read.fade == 40)
        #expect(read.room == 20)
        #expect(read.grace == 800)
        #expect(read.settle == 1000)
        #expect(read.lead == 1.25)
        #expect(read.maxMarks == 5)
        #expect(read.swells == 3)
    }

    /// Max reads "full" as Full, and keeps any number of marks a screen might hold.
    @Test(arguments: [(#""full""#, 0.0), ("0", 0), ("6", 6), ("6.4", 6), ("40", 40)])
    func maxIsFullOrAtLeastFiveMarks(_ json: String, _ marks: Double) throws {
        #expect(try StripSettings(json: #"{"max":\#(json)}"#).maxMarks == marks)
    }

    @Test func theDialsHaveThePrototypesNamesRangesAndSteps() {
        let dials = StripDial.allCases.map { "\($0.name) \($0.range.lowerBound)...\($0.range.upperBound) by \($0.step)" }

        #expect(dials == [
            "Bounce 0.0...1.0 by 0.01",
            "Dwell 0.0...400.0 by 10.0",
            "Reach 0.0...8.0 by 0.5",
            "Pour 0.5...2.0 by 0.01",
            "Glide 0.5...2.0 by 0.01",
            "Fade 40.0...400.0 by 10.0",
            "Close 0.5...2.0 by 0.01",
            "Room 0.0...20.0 by 1.0",
            "Grace 0.0...800.0 by 10.0",
            "Settle 0.0...3000.0 by 50.0",
            "Slide 0.5...2.0 by 0.01",
            "Lead 1.0...2.0 by 0.05",
            "Max 5.0...inf by 1.0",
            "Swells 1.0...3.0 by 1.0",
        ])
        #expect(StripDial.sliders == StripDial.allCases.filter { $0 != .max })
    }

    @Test func eachDialShowsAsItsSlidersLabelDoes() {
        let settings = StripSettings()

        #expect(StripDial.allCases.map { $0.show(settings[$0]) } == [
            "0.50", "120ms", "3px", "1.00×", "1.00×", "160ms", "1.00×", "12px", "300ms", "1000ms", "1.00×", "1.25×",
            "Full", "2×",
        ])
        #expect(StripDial.reach.show(2.5) == "2.5px")
        #expect(StripDial.max.show(6) == "6 marks")
    }

    /// On the recording's screen, 626 tall, Max's slider runs to 16, Full; a Room of 0 holds more.
    @Test func maxsSliderRunsToAsManyMarksAsTheScreenHolds() {
        var settings = StripSettings()
        #expect(settings.longest(on: StripLab.stage) == 16)

        settings.room = 0
        #expect(settings.longest(on: StripLab.stage) == 17)
        #expect(settings.longest(on: StripStage(width: 1512, height: 982, menu: 37)) == 28)
    }

    @Test func atLeesSettingsTheDerivedSpringsAreThePrototypes() {
        #expect(StripSettings().derived == "springs, response·damping after Bounce ×1.00, Pour 1.00×, Glide 1.00×, "
            + "Close 1.00×, Slide 1.00×: reach 0.20·0.70, pour 0.26·0.72, grow 0.22·0.80, glide 0.24·0.82, "
            + "width 0.24·0.86, draw 0.22·0.80, slide 0.36·0.80, arrive 0.30·0.55, press 0.10·0.70, morph 0.42·0.86, "
            + "ends 0.29·0.80 growing, 0.45·0.80 shrinking")
    }

    @Test func eachSpeedDialSpeedsItsOwnSpringsAndNothingElse() {
        var settings = StripSettings()
        settings.pour = 2
        settings.glide = 0.5
        settings.close = 1.25
        settings.slide = 1.6

        let responses = StripSpring.allCases.map { settings.sp($0).response / $0.listed.response }

        #expect(responses.map { ($0 * 1e9).rounded() / 1e9 } == [0.5, 0.5, 0.5, 2, 2, 0.8, 0.625, 0.625, 1, 1])
    }

    /// Lead: the ends' spring, from the marks' slide, quicker growing and slower shrinking.
    @Test func leadQuickensTheEndsGrowingAndSlowsThemShrinking() {
        var settings = StripSettings()
        settings.lead = 2

        #expect(settings.ends(growing: true) == SpringParams(response: 0.18, damping: 0.80))
        #expect(settings.ends(growing: false) == SpringParams(response: 0.72, damping: 0.80))
    }

    @Test func copySettingsCopiesAHeaderTheJSONAndWhatItMakes() {
        let settings = StripSettings()

        #expect(settings.copied == "SitRep · Strip settings\n\(settings.json)\n\(settings.derived)")
    }
}
