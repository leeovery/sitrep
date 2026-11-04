import AppKit
@testable import SitRep
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// A session on its own work, marked as Paper's board D draws it: a still ring of round-capped dashes, on the black
/// card and in the window's sidebar, each read from its pixels at 2×.
@MainActor
struct DottedRingTests {
    private static let waiting = Session(
        id: "a", project: "SitRep", kind: .onItsWork, title: "Waiting on ", subject: "3 agents",
        sub: "SitRep · The Mac app", since: 0
    )

    /// A row on the card, on one line.
    private static let cardSize = CGSize(width: 344, height: Item.lineHeight)

    private static func card(_ session: Session) throws -> (row: SessionRow, drawn: Drawn) {
        let row = SessionRow(session, size: Self.cardSize)

        return (row, try Drawn(row.layer))
    }

    /// A card row's words' box, beside its project in the lane at its right.
    private static func title(of project: String) -> CGRect {
        SessionRowLayout(size: cardSize, project: TextLine.width(TextLine.text(project, EdgeStyle.sub, EdgeStyle.ink3))).title
    }

    /// Its 4.5 radius and 1.5 stroke 10.5 across, on the mark's centre at 16 by 15, in #8E8E95, open in the middle.
    @Test func theCardsRingIsCentredInItsLaneInGrey() throws {
        let drawn = try Self.card(Self.waiting).drawn
        let ring = try #require(drawn.drawnBox(in: CGRect(x: 4, y: 2, width: 24, height: 26), ground: Self.cardGround))

        #expect(abs(ring.midX - 16) <= 0.5 && abs(ring.midY - 15) <= 0.5)
        #expect(abs(ring.width - 10.5) <= 1 && abs(ring.height - 10.5) <= 1)
        #expect(Self.colour(drawn, in: ring).isClose(to: 0x8E8E95))
        #expect(drawn.drawnBox(in: CGRect(x: 15, y: 14, width: 2, height: 2), ground: Self.cardGround) == nil)
    }

    /// Dashes of 1.6 with gaps of 2.12 go round seven and a half times, the last gap closed by the caps where the ring
    /// meets its start: seven dashes. Your turn's ring, read the same way, is whole.
    @Test func theCardsRingIsDashed() throws {
        let waiting = try Self.card(Self.waiting).drawn
        let turn = try Self.card(Session(id: "a", project: "SitRep", kind: .turn, title: "Your turn", sub: "", since: 0))
        let lane = CGRect(x: 4, y: 2, width: 24, height: 26)

        #expect(try Self.dashes(waiting, in: lane, ground: Self.cardGround) == 7)
        #expect(try Self.dashes(turn.drawn, in: lane, ground: Self.cardGround) == 1)
    }

    @Test func theCardsRingNeverTurns() throws {
        let row = try Self.card(Self.waiting).row
        let ring = try #require(row.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first { $0.lineDashPattern != nil })

        #expect(ring.animationKeys() == nil)
    }

    /// Its verb in the title's medium at #B4B4BA, brighter than its subject after it at #8E8E95.
    @Test func theCardsTitleSetsItsVerbBrighterThanItsSubject() throws {
        let drawn = try Self.card(Self.waiting).drawn
        let verb = TextLine.width(LineTitle.text(Self.waiting, verb: EdgeStyle.waitingVerb, subject: nil, isFollowed: false))
        let title = Self.title(of: "SitRep")

        #expect(Self.colour(drawn, in: CGRect(x: title.minX, y: title.minY, width: verb, height: title.height))
            .isClose(to: 0xB4B4BA))
        #expect(Self.colour(drawn, in: CGRect(x: title.minX + verb, y: title.minY, width: 80, height: title.height))
            .isClose(to: 0x8E8E95))
    }

    /// The countdown is set again as it reads differently: "Wakes in 12m" narrows to "Wakes now" as the wake comes due.
    @Test func theCardsWakeCountsDownAsTheClockTicks() throws {
        let wake = Session(id: "a", project: "Kit", kind: .onItsWork, title: "Wakes ", until: 1_000_000, sub: "", since: 0)
        let row = SessionRow(wake, size: Self.cardSize)
        let title = Self.title(of: "SitRep")

        row.showAge(at: 1_000_000 - 690_000)
        let early = try #require(try Drawn(row.layer).drawnBox(in: title, ground: Self.cardGround))
        row.showAge(at: 1_000_000)
        let due = try #require(try Drawn(row.layer).drawnBox(in: title, ground: Self.cardGround))

        #expect(early.minX == due.minX)
        #expect(early.width - due.width > 10)
    }

    /// Its 4.25 radius and 1.5 stroke 10 across, on the mark's centre at 29 on the working row's first line, in white
    /// at 45% over what is under it, dashed: 1.5 with gaps of 2.0 go round seven and a half times. Read on the row the
    /// window opens picked, as only the selection's dark draws offscreen.
    @Test func theSidebarsRingIsCentredDashedAndFaint() throws {
        let run = HostedSidebar.opened(Lines.onItsWork)
        let side = try HostedSidebar(run, listAlone: true)
        let drawn = try side.drawn()
        let place = try #require(run.sidebar(at: HostedSidebar.printed).lines.firstIndex {
            if case let .session(row) = $0 { row.name == "The bootstrap" } else { false }
        })
        let row = side.rows[place].offsetBy(dx: 0, dy: -side.glassTop)
        let middle = row.minY + WindowStyle.twoLineTop + WindowStyle.titleLine / 2
        let ground = CGPoint(x: 13, y: middle)
        let lane = CGRect(x: 18, y: middle - 8, width: 22, height: 16)
        let ring = try #require(drawn.drawnBox(in: lane, ground: ground))
        let under = try #require(drawn.stored(at: ground))

        #expect(run.pick == .session("sr-k7bt2s"))
        #expect(abs(ring.midX - 29) <= 0.5 && abs(ring.midY - middle) <= 0.5)
        #expect(abs(ring.width - 10) <= 1 && abs(ring.height - 10) <= 1)
        #expect(abs(Self.colour(drawn, in: ring)[0] - (0.45 + 0.55 * under.redComponent)) <= 0.02)
        #expect(try Self.dashes(drawn, in: lane, ground: ground) == 7)
    }

    private static let cardGround = CGPoint(x: 2, y: 2)

    /// The red, green and blue drawn at the brightest pixel in `rect`, in sRGB, as stored.
    private static func colour(_ drawn: Drawn, in rect: CGRect) -> [CGFloat] {
        let step = 1 / drawn.scale
        let points = stride(from: rect.minY, to: rect.maxY, by: step).flatMap { y in
            stride(from: rect.minX, to: rect.maxX, by: step).map { CGPoint(x: $0, y: y) }
        }
        let brightest = points.compactMap(drawn.stored).max { $0.lightness < $1.lightness }

        return brightest.map { [$0.redComponent, $0.greenComponent, $0.blueComponent] } ?? []
    }

    /// The runs of a ring's stroke drawn near full over what is under it in `lane`, each pixel reaching the next beside
    /// it: its dashes; one for a whole ring. Counted so, not read round its centreline, where the round caps leave
    /// gaps of half a point, which a quarter point's shift hides.
    private static func dashes(_ drawn: Drawn, in lane: CGRect, ground: CGPoint) throws -> Int {
        let under = try #require(drawn.pixel(at: ground)).lightness
        let scale = drawn.scale
        let columns = Int((lane.minX * scale).rounded()) ..< Int((lane.maxX * scale).rounded())
        let rows = Int((lane.minY * scale).rounded()) ..< Int((lane.maxY * scale).rounded())
        var light: [SIMD2<Int>: CGFloat] = [:]

        for x in columns {
            for y in rows {
                let centre = CGPoint(x: (CGFloat(x) + 0.5) / scale, y: (CGFloat(y) + 0.5) / scale)

                light[SIMD2(x, y)] = drawn.pixel(at: centre)?.lightness ?? under
            }
        }

        let full = light.values.max() ?? under
        var stroke = Set(light.filter { $0.value > under + 0.75 * (full - under) }.keys), runs = 0
        let beside: [SIMD2<Int>] = [SIMD2(1, 0), SIMD2(-1, 0), SIMD2(0, 1), SIMD2(0, -1)]

        while let start = stroke.popFirst() {
            var reached = [start]

            runs += 1
            while let pixel = reached.popLast() {
                reached += beside.map { pixel &+ $0 }.filter { stroke.remove($0) != nil }
            }
        }
        return runs
    }
}

private extension [CGFloat] {
    /// Within a step of 8 bits of this colour's red, green and blue.
    func isClose(to hex: UInt32) -> Bool {
        let wanted = [hex >> 16, hex >> 8, hex].map { CGFloat($0 & 0xFF) / 255 }

        return count == 3 && zip(self, wanted).allSatisfy { abs($0 - $1) <= 1.5 / 255 }
    }
}
