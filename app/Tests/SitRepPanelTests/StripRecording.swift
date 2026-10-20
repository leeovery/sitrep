import Foundation

extension StripRecorded {
    /// At length full. No marks move.
    static let hover = recorded("hover")

    /// At length full. No marks move.
    static let fit = recorded("fit")

    /// At length full. Its marks: s4, s5, s9.
    static let arrive = recorded("arrive")

    /// At length full. Its marks: s1, s2, s5, s8.
    static let settle = recorded("settle")

    /// At length full. Its marks: s6.
    static let jump = recorded("jump")

    /// At length full. No marks move.
    static let tabJump = recorded("tabJump")

    /// At length full. Its marks: s6, s8, s20.
    static let many = recorded("many")

    /// At length full. Its marks: s4, s8, s9, s16.
    static let last = recorded("last")

    /// At length full. Its marks: s6, s9.
    static let bottom = recorded("bottom")

    /// At Lee's settings. Its marks: s4, s5, s7, s8, s9.
    static let grows = recorded("grows")

    /// At max 6. Its marks: s3, s4, s5, s9, s10, s13.
    static let maxSix = recorded("maxSix")

    /// At max 6. Its marks: s4, s9, s13, s14.
    static let lands = recorded("lands")

    /// At max 6. Its marks: s4, s9.
    static let countTab = recorded("countTab")

    /// At max 6. Its marks: s4, s5, s9, s10.
    static let answerOut = recorded("answerOut")

    /// At Lee's settings. Its marks: s1, s8, s9.
    static let empty = recorded("empty")

    /// At Lee's settings. Its marks: s1, s5, s8.
    static let drag = recorded("drag")

    /// Too many, settled: the order the marks end in.
    static let manyOrder: [String] = ["s1", "s2", "s3", "s4", "s5", "s20", "s27", "s11", "s26", "s17", "s14", "s30", "s24", "s6", "s9", "s10", "s12", "s13", "s15", "s16", "s18", "s7", "s19", "s21", "s22", "s23", "s25", "s28", "s29", "s8"]

    /// When the new mark arrived, growing into its place, since the ask.
    static let arrived: Double = 80

    /// When the ask landed in needs you's count, which flashed, since the first five asks.
    static let landed: Double = 1008

    /// Max 6, the five asks in: the asks folded into needs you's count, newest first and the away one last, and the
    /// rest into the grey one.
    static let maxSixFolded: (asks: [String], rest: [String]) = (
        asks: ["s10", "s11", "s12", "s13", "s4"], rest: ["s5", "s6", "s7", "s8"]
    )

    /// Each tab's width as the browser measured its words, by their lines.
    static let widths: [String: Double] = [
        "The management window is sketched|Fumi · Management window discussion": 321,
        "Waiting for the next round of feedback|Goosemates · Settle the older open questions": 329,
        "Approve the round 2 drawings|SitRep · The Mac app": 269,
        "Running the exception reporting tests|DocMan · Fix inverted exception reporting": 321,
        "Writing the bootstrap's tests|Kit · The bootstrap\nReading the Atlas logs|Fabric · Atlas overload from llm-manager\nReshaping the review workflow|Agentic Workflows · Reshape the workflows\nRunning the usage ledger tests|Switchboard · Usage\nBuilding the app|SitRep · Jump to session\nProfiling the dispatcher|Turnstile · Dispatcher limiter\nRunning the exception reporting tests|DocMan · Fix inverted exception reporting\nDrafting the release notes|Goosemates · Release 2.4\nSketching the tool|Terrace · The first cut\nWiring the management window|Fumi · Management window\nCounting tokens per hunk|Mint · Hunk budgets\nMapping the units|Aircon · Discovery\nTracing the jump outside tmux|SitRep · Jump test outside tmux\nRebasing onto main|DocMan · Upload limits\nFixing the limiter's reset|Turnstile · Exception reporting": 276,
        "Fixing the limiter's reset|Turnstile · Exception reporting": 240,
        "Probing the unit's local API|Aircon · Aircon local control": 252,
        "Allow Bash aws sso login --profile dev|Fabric · Atlas overload from llm-manager\nGive the go for stage 3|Switchboard · Milestone 7 stages 4 to 14\nWhich unit is the bedroom?+2|Aircon · Aircon local control\nApprove the reshaped review workflow|Agentic Workflows · Reshape the workflows\nApprove the plan for the tool|No window holds it. Carry it on in Claude.": 326,
        "Allow Bash aws sso login --profile dev|Fabric · Atlas overload from llm-manager\nApprove the plan for the tool|No window holds it. Carry it on in Claude.": 326,
        "Signing in to the dev account|Fabric · Atlas overload from llm-manager\nApprove the plan for the tool|No window holds it. Carry it on in Claude.": 259,
        "Nothing running|SitRep · sessions show here as they start": 274,
    ]

    /// The strip prototype at Lee's settings, recorded in the browser a frame at a time by the strip's recorder, each
    /// scenario on a fresh page with the prototype's eight sessions on a screen 626 tall, at the settings it seeds the
    /// prototype with: each frame's time since the scenario began, the pointer as the strip took it, the hairline, the
    /// strip's ends and how far into the notch at rest, what is jumping, every tab (its depth, body, centre, press and
    /// fade, each of its words' opacity, to the browser's three decimals, and, while it is out, where its top and
    /// bottom fillets leave the strip's edge, how round and at what angle, on the S or the straight edge), the
    /// scenario's marks (centre, scale, opacity), and the counts (how many, centre, scale, opacity), a JSON file per
    /// scenario in `Recorded/Strip`. Generated, with the declarations above, by the strip prototype's recorder,
    /// `fixture.mjs` among the surfaces tools; not edited by hand.
    ///
    /// Data, not Swift: as array literals they cost the type checker 20 GB and more per compile.
    private static func recorded(_ scenario: String) -> [StripRecorded] {
        guard let url = Bundle.module.url(forResource: scenario, withExtension: "json", subdirectory: "Recorded/Strip")
        else { fatalError("The strip's recording \(scenario) is missing from Recorded/Strip") }
        do {
            return try JSONDecoder().decode([StripRecorded].self, from: Data(contentsOf: url))
        } catch {
            fatalError("The strip's recording \(scenario) doesn't decode: \(error)")
        }
    }
}
