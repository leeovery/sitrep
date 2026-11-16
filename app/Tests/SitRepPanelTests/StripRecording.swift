extension StripRecorded {
    /// At length full. No marks move.
    static let hover = recorded("hover")

    /// At length full. No marks move.
    static let fit = recorded("fit")

    /// At length full. Its marks: s4, s5, s9.
    static let arrive = recorded("arrive")

    /// At length full. Its marks: s1, s2, s5, s8.
    static let answer = recorded("answer")

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

    /// At Lee's settings. Its marks: s5, s6, s7, s8.
    static let stops = recorded("stops")

    /// At max 6. Its marks: s4, s7, s8, s9.
    static let stopsLand = recorded("stopsLand")

    /// At max 7. Its marks: s4, s5, s9, s10.
    static let displace = recorded("displace")

    /// At Lee's settings. Its marks: s1, s5, s8.
    static let drag = recorded("drag")

    /// At Lee's settings. Its marks: s1, s6, s7, s8.
    static let fold = recorded("fold")

    /// At Lee's settings. Its marks: s7, s8.
    static let unfold = recorded("unfold")

    /// At Lee's settings. Its marks: s8, s9, s10, s11.
    static let snoozed = recorded("snoozed")

    /// At Lee's settings. Its marks: s9, s11.
    static let snoozedTab = recorded("snoozedTab")

    /// At max 10. Its marks: s6, s8, s9, s10, s11, s12.
    static let manyAll = recorded("manyAll")

    /// At Lee's settings. Its marks: s4, s9.
    static let foldedArrive = recorded("foldedArrive")

    /// Too many, settled: the order the marks end in.
    static let manyOrder: [String] = ["s1", "s2", "s3", "s4", "s5", "s20", "s27", "s11", "s26", "s17", "s14", "s30", "s24", "s6", "s9", "s10", "s12", "s13", "s15", "s16", "s18", "s7", "s19", "s21", "s22", "s23", "s25", "s28", "s29", "s8"]

    /// When the new mark arrived, growing into its place, since the ask.
    static let arrived: Double = 80

    /// When the ask landed in needs you's count, which flashed, since the first five asks.
    static let landed: Double = 1008

    /// When the ask landed in needs you's count, folded, which flashed, since needs you folded.
    static let foldedLanded: Double = 912

    /// Max 10, all three sections, working folded at the end: what each count holds.
    static let manyAllFolded: (working: [String], snoozed: [String]) = (
        working: ["s7", "s8"], snoozed: ["s10", "s11"]
    )

    /// Max 6, the five asks in and a settle after: those folded into needs you's count, the asks in the panel's
    /// order, the away one last, and the stopped after them, and the rest into the grey one.
    static let maxSixFolded: (asks: [String], rest: [String]) = (
        asks: ["s10", "s11", "s12", "s13", "s4", "s5", "s6"], rest: ["s7", "s8"]
    )

    /// Each tab's width as the browser measured its words, by their lines.
    static let widths: [String: Double] = [
        "The billing panel redesign is sketched|Wingtip · Billing panel discussion": 321,
        "Waiting for the next round of comments|Lucerne · Close the remaining open questions": 329,
        "Approve the second floor plan|Trey Research · Lab fit-out": 269,
        "Running the invoice totals query tests|BlueYonder · Fix the reversed invoice totals": 321,
        "Writing the installer's tests|Litware · The installer\nReading the indexer logs|Southridge · Search load from the indexer\nReshaping the customs workflow|Wide World Importers · Customs workflows\nRunning the statement tests|Woodgrove · Statements\nBuilding the lab|Trey Research · Lab bookings\nProfiling the stock sync|Proseware · Stock sync\nRunning the invoice totals query tests|BlueYonder · Fix the reversed invoice totals\nDrafting the course notes|Lucerne · Term 2\nSketching the launch|Humongous · The first cut\nWiring the billing panel|Wingtip · Billing panel\nCounting files per batch|Relecloud · Batch budgets\nMapping the slopes|Alpine · Discovery\nTracing the booking outside hours|Trey Research · Bookings outside hours\nRebasing onto main|BlueYonder · Import limits\nFixing the stock count|Proseware · Stock reporting": 276,
        "Fixing the stock count|Proseware · Stock reporting": 240,
        "Probing the lift's motor API|Alpine · Lift schedule": 252,
        "Choose the batch size|Relecloud · Smaller diff batches\nAllow Bash aws sso login --profile uat|Southridge · Search load from the indexer\nApprove the next print run|Woodgrove · Statement print runs 4 to 9\nWhich slope opens first?+2|Alpine · Lift schedule\nApprove the reshaped customs workflow|Wide World Importers · Customs workflows\nThe billing panel redesign is sketched|Wingtip · Billing panel discussion\nWaiting for the next round of comments|Lucerne · Close the remaining open questions": 326,
        "Choose the batch size|Relecloud · Smaller diff batches\nAllow Bash aws sso login --profile uat|Southridge · Search load from the indexer\nThe billing panel redesign is sketched|Wingtip · Billing panel discussion\nWaiting for the next round of comments|Lucerne · Close the remaining open questions": 326,
        "Allow Bash aws sso login --profile uat|Southridge · Search load from the indexer\nThe billing panel redesign is sketched|Wingtip · Billing panel discussion\nWaiting for the next round of comments|Lucerne · Close the remaining open questions": 326,
        "Nothing running|SitRep · sessions show here as they start": 274,
        "Allow Bash aws sso login --profile uat|Southridge · Search load from the indexer\nThe invoice totals tests pass|BlueYonder · Fix the reversed invoice totals\nThe billing panel redesign is sketched|Wingtip · Billing panel discussion\nWaiting for the next round of comments|Lucerne · Close the remaining open questions": 326,
        "Running the invoice totals query tests|BlueYonder · Fix the reversed invoice totals\nFixing the stock count|Proseware · Stock reporting": 276,
        "Pick the onboarding copy|Contoso · Onboarding flow": 242,
        "Pick the onboarding copy|Contoso · Onboarding flow\nThe ledger export is reviewed|Northwind · Ledger export\nWhich region goes first?|Fabrikam · Region rollout": 240,
    ]

    /// The strip prototype at Lee's settings, recorded in the browser a frame at a time by the strip's recorder, each
    /// scenario on a fresh page with the prototype's eight sessions on a screen 626 tall, at the settings it seeds the
    /// prototype with: each frame's time since the scenario began, the pointer as the strip took it, the hairline over
    /// Working, and over Snoozed once it is first placed (14 November 2026), the strip's ends and how far into the
    /// notch at rest, what is jumping, every tab (its depth, body, centre, press and fade, each of its words' opacity,
    /// to the browser's three decimals, and, while it is out, where its top and bottom fillets leave the strip's edge,
    /// how round and at what angle, on the S or the straight edge), the scenario's marks (centre, scale, opacity), and
    /// the counts (how many, centre, scale, opacity), a JSON file per scenario in `Recorded/Strip`. Generated, with the
    /// declarations above, by the strip prototype's recorder in `prototypes/strip` (its README says how); not edited
    /// by hand.
    private static func recorded(_ scenario: String) -> [StripRecorded] {
        Recordings.frames(scenario, in: "Strip")
    }
}
