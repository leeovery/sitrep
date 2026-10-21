import Foundation
@testable import SitRep
import SitRepPanel
import SwiftUI
import Testing

/// What a pointer over a picture does, whatever moves it: DESIGN's "What stays on screen".
struct PictureHoverTests {
    @Test func theNotchAndTheStripMoveUnderThePointerAndNothingHasNothingToMove() {
        #expect(PictureHover.moves(.notch, reducesMotion: false))
        #expect(PictureHover.moves(.strip, reducesMotion: false))
        #expect(!PictureHover.moves(.nothing, reducesMotion: false))
    }

    @Test(arguments: EdgeSettings.Show.allCases)
    func underReducedMotionNoPictureMoves(show: EdgeSettings.Show) {
        #expect(!PictureHover.moves(show, reducesMotion: true))
    }

    /// `#FFFFFF26` lifted to `#FFFFFF4D`, motion reduced or not.
    @Test func aTileNotChosenLiftsItsHairlineUnderThePointer() {
        #expect(abs(PictureHover.hairline(isOver: false) - 0x26 / 255) < 0.002)
        #expect(abs(PictureHover.hairline(isOver: true) - 0x4D / 255) < 0.002)
    }
}

/// The notch's tongue reaching for the pointer, as A2's first filmstrip draws it.
struct NotchReachTests {
    /// The filmstrip's paths between the crest's ends, its controls and ends in order.
    private static let partWay = points([9.8, 40.3, 11.4, 42, 12, 42.9, 12.4, 43.5, 12.4, 44.1, 12, 44.7, 11.4, 45.6, 9.8, 47.1])
    private static let full = points([10.2, 40.5, 13.9, 42.4, 15, 43.2, 15.7, 43.7, 15.7, 44.5, 15, 45, 13.9, 45.8, 10.2, 47.2])

    private static func points(_ values: [CGFloat]) -> [CGPoint] {
        stride(from: 0, to: values.count, by: 2).map { CGPoint(x: values[$0], y: values[$0 + 1]) }
    }

    private static func near(_ a: [CGPoint], _ b: [CGPoint], within tolerance: CGFloat = 0.01) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0.x - $1.x) <= tolerance && abs($0.y - $1.y) <= tolerance }
    }

    private static func capMiddle(_ tongue: [CGPoint]) -> CGFloat {
        (tongue[2].y + tongue[5].y) / 2
    }

    /// Which way a curve turns from its start to its end, by its control polygon.
    private static func turn(_ start: CGPoint, _ control1: CGPoint, _ control2: CGPoint, _ end: CGPoint) -> CGFloat {
        let (a, b) = (CGPoint(x: control1.x - start.x, y: control1.y - start.y), CGPoint(x: end.x - control2.x, y: end.y - control2.y))

        return a.x * b.y - a.y * b.x
    }

    private static func flanks(_ tongue: [CGPoint]) -> (upper: CGFloat, lower: CGFloat) {
        (
            turn(CGPoint(x: 9, y: 37.9), tongue[0], tongue[1], tongue[2]),
            turn(tongue[5], tongue[6], tongue[7], CGPoint(x: 9, y: 49.1))
        )
    }

    @Test func atRestTheNotchsCrestIsAStraightRun() {
        #expect(abs(NotchPicture.outline(reach: 0).boundingRect.maxX - 9) < 0.001)
        #expect(abs(NotchPicture.outline(reach: 0, tip: 39).boundingRect.maxX - 9) < 0.001)
        #expect(PicturePose.rest.reach == 0)
    }

    /// Its tip about 6.5 units past the crest, a little more than the lip's own 6-unit depth.
    @Test func atFullReachTheTongueIsTheFilmstripsHeldFrameItsTipAboutSixAndAHalfPastTheCrest() {
        let tip = NotchPicture.outline(reach: 1).boundingRect.maxX

        #expect(Self.near(NotchPicture.tongue(reach: 1), Self.full))
        #expect(tip > 15.3 && tip < 15.7)
    }

    /// The filmstrip's 0.1 s frame, the tip at about x 12.3: the tongue half out.
    @Test func halfOutTheTongueIsTheFilmstripsPartWayFrame() {
        let tip = NotchPicture.outline(reach: 0.5).boundingRect.maxX

        #expect(Self.near(NotchPicture.tongue(reach: 0.5), Self.partWay))
        #expect(abs(tip - 12.3) < 0.05)
    }

    @Test func betweenStagesTheTongueRunsFromOneToTheNext() {
        let tongue = NotchPicture.tongue(reach: 0.75)
        let between = zip(Self.partWay, Self.full).map { CGPoint(x: ($0.x + $1.x) / 2, y: ($0.y + $1.y) / 2) }

        #expect(Self.near(tongue, between))
    }

    /// Out in about 0.3 s, as the filmstrip holds it there.
    @Test func theAttractSpringHasItOutInAboutAThirdOfASecond() {
        #expect(abs(NotchPicture.out.value(target: 1.0, time: 0.3) - 1) < 0.01)
        #expect(Self.near(NotchPicture.tongue(reach: NotchPicture.out.value(target: 1.0, time: 0.3)), Self.full, within: 0.05))
    }

    /// Home in about 0.6 s, past home first: the crest dips in a little before it settles.
    @Test func theRelaxSpringHasItHomeInAboutSixTenthsOfASecondWithItsOwnOvershoot() {
        let reach = { (time: TimeInterval) in 1 - NotchPicture.home.value(target: 1.0, time: time) }
        let deepest = stride(from: 0.0, through: 0.6, by: 0.01).map(reach).min() ?? 0

        #expect(deepest < -0.05 && deepest > -0.2)
        #expect(NotchPicture.tongue(reach: deepest).allSatisfy { $0.x < NotchPicture.crestX })
        #expect(abs(reach(0.6)) < 0.03)
    }

    @Test(arguments: [40.9, 42.5, 44.1, 46])
    func itsTipSitsAtThePointersHeight(pointer: CGFloat) {
        #expect(abs(Self.capMiddle(NotchPicture.tongue(reach: 1, tip: pointer)) - pointer) < 0.001)
        #expect(abs(Self.capMiddle(NotchPicture.tongue(reach: 0.5, tip: pointer)) - pointer) < 0.001)
    }

    /// Inside the crest's span, y 37.9 to 49.1, each flank keeping 2 units of it.
    @Test func itsTipIsHeldInsideTheCrestsSpan() {
        let above = NotchPicture.tongue(reach: 1, tip: 20)
        let below = NotchPicture.tongue(reach: 1, tip: 70)

        #expect(abs(above[2].y - 39.9) < 0.001)
        #expect(abs(below[5].y - 47.1) < 0.001)
        #expect(above.allSatisfy { NotchPicture.crest.contains($0.y) })
        #expect(below.allSatisfy { NotchPicture.crest.contains($0.y) })
    }

    @Test func movingTheTipLeavesTheReachAsItIs() {
        let drawn = NotchPicture.tongue(reach: 1)
        let moved = NotchPicture.tongue(reach: 1, tip: 41)

        #expect(drawn.map(\.x) == moved.map(\.x))
    }

    /// A liquid pulled thin, as the real meniscus's are, wherever the tip goes.
    @Test(arguments: [20, 41, 44.1, 46, 70])
    func itsFlanksStayAsConcaveAsDrawn(pointer: CGFloat) {
        let drawn = Self.flanks(Self.full)
        let moved = Self.flanks(NotchPicture.tongue(reach: 1, tip: pointer))

        #expect(drawn.upper.sign == moved.upper.sign && drawn.lower.sign == moved.lower.sign)
    }
}

/// The strip's rings turning under the pointer, as A2's second filmstrip draws them.
struct StripTurnTests {
    private static let entered = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let turn = StripTurn(since: entered)

    private static func at(_ seconds: TimeInterval) -> Date {
        entered.addingTimeInterval(seconds)
    }

    private static func near(_ a: [Double], _ b: [Double]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) < 0.001 }
    }

    @Test func atRestTheStripsWorkingRingsStandAtTwelveAndFortyFiveAndTheRestAreWhole() {
        #expect(StripPicture.restingArcs == [nil, nil, 0, 45])
        #expect(StripPicture.rings.map(\.ring) == [.needs, .turn, .working, .working])
        #expect(PicturePose.rest.turning == 0)
    }

    /// Needs you 90°–180°, your turn 60°–150°, then the working rings 30°–120° and 0°–90°.
    @Test func atAThirdOfASecondEachRingIsThirtyDegreesBehindTheOneAbove() {
        let pose = Self.turn.pose(at: Self.at(0.3))

        #expect(Self.near(pose.arcs, [90, 60, 30, 0]))
        #expect(pose.turning == 1)
    }

    @Test func atSixTenthsOfASecondTheyHaveTurnedAQuarterMore() {
        #expect(Self.near(Self.turn.arcs(at: Self.at(0.6)), [180, 150, 120, 90]))
    }

    @Test func eachRingWaitsAtTwelveUntilItsTurnStarts() {
        #expect(Self.near(Self.turn.arcs(at: Self.at(0.05)), [15, 0, 0, 0]))
        #expect(Self.near(Self.turn.arcs(at: Self.at(0.15)), [45, 15, 0, 0]))
    }

    @Test func aTurnTakesOnePointTwoSecondsAndRepeats() {
        #expect(Self.near(Self.turn.arcs(at: Self.at(1.8)), Self.turn.arcs(at: Self.at(0.6))))
        #expect(Self.near(Self.turn.arcs(at: Self.at(12.7)), Self.turn.arcs(at: Self.at(0.7))))
    }

    @Test func theTurningLookFadesInOverTheStripsOwnQuarterSecond() {
        #expect(Self.turn.turning(at: Self.at(0)) == 0)
        #expect(abs(Self.turn.turning(at: Self.at(0.12)) - 0.5) < 0.001)
        #expect(abs(Self.turn.turning(at: Self.at(0.24)) - 1) < 0.001)
        #expect(Self.turn.faded == nil)
    }

    @Test func onLeavingTheArcsFadeOutOverAQuarterSecondStillTurningAndThenTheyRest() {
        let left = Self.turn.left(at: Self.at(1))

        #expect(abs(left.turning(at: Self.at(1.12)) - 0.5) < 0.001)
        #expect(left.turning(at: Self.at(1.24)) < 0.001)
        #expect(Self.near(left.arcs(at: Self.at(1.12)), Self.turn.arcs(at: Self.at(1.12))))
        #expect(left.faded.map { abs($0.timeIntervalSince(Self.at(1.24))) < 0.001 } == true)
    }

    @Test func leftAsTheyFadeInTheyFadeOutFromWhereTheyAre() {
        let left = Self.turn.left(at: Self.at(0.12))

        #expect(left.faded.map { abs($0.timeIntervalSince(Self.at(0.24))) < 0.001 } == true)
    }

    @Test func comingBackBeforeTheyHaveFadedTheyFadeInAgainAndCarryOnTurning() {
        let back = Self.turn.left(at: Self.at(1)).entered(at: Self.at(1.12))

        #expect(abs(back.turning(at: Self.at(1.12)) - 0.5) < 0.001)
        #expect(abs(back.turning(at: Self.at(1.24)) - 1) < 0.001)
        #expect(Self.near(back.arcs(at: Self.at(1.3)), Self.turn.arcs(at: Self.at(1.3))))
        #expect(back.faded == nil)
    }
}
