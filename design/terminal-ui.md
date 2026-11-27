# The board in a terminal

SitRep shows the board at the edge of a Mac's screen, in the notch (and, until 26 November 2026, the strip). Away from that screen there was nothing: on an iPad or a phone signed in to the Mac over SSH in rootshell, what needs you couldn't be seen until you went looking. The board in a terminal is the notch's panel as a terminal app, for those screens and for a Ghostty tab on the Mac. Its looks were drawn in four rounds in the Paper file "SitRep · terminal look", and on 19 November 2026 Lee picked round 4, the page "FINAL · board in a terminal" until 26 November 2026: **Two-line under grey capitals**, each session on two lines, its name and time, then its project and status line, under ruled section headings in grey capitals, every row flush at the margin and the chosen row marked by a band alone. On 26 November 2026 round 5 put each session on one line, as the notch draws it, and the view began answering a row's asks; Lee signed it off that day, now the page "FINAL · one line, asks under the row · signed off 26 Nov 2026", round 4's page renamed "superseded · round 4 · FINAL · board in a terminal". This doc settles that look and how it's built.

**Settled with Lee on 18 November 2026:**
- **One panel,** drawn the same everywhere. It is a dashboard to leave open beside your work, and a launcher to pick from.
- **The command.** `sitrep` alone opens the panel in a terminal; `sitrep help` keeps the help.
- **Sessions by state,** as the notch orders them: Needs you (asks in orange, Stopped in blue), then Working, then Snoozed, folded at first. The project shows on each row.
- **It suits a terminal.** It's drawn for a narrow terminal first, such as a 25% split on an iPad or a phone held upright, and grows with the width. Lee: "We build it dynamically. It will fit regardless."
- **It doesn't answer asks,** because the notch doesn't. (Until 26 November 2026: the notch has answered since 24 November, and so does the view; see below.)
- **Picking a row** opens that session in place (by `o` since 20 November 2026), on the Mac as over SSH, so it behaves the same on every screen. Detaching comes back to the panel.
  - A session whose Claude has ended resumes in place, by the resume command.
  - A session running in a terminal with no tmux or zmx can't be reached from here, and the panel says so.
  - **Corrected by Lee on 19 November 2026:** the panel never attaches a session itself. "It should never run zmx attach. We should be using the existing commands that are registered for this process." It runs SitRep's resume command, as the app's click does for a session this Mac doesn't show (see "Picking a row").
- **Notifications.** A new ask posts a terminal notification (OSC 9 or 777), which rootshell shows, even in the background and through tmux with passthrough. It's on by default, and a flag turns it off. Claude stopping doesn't notify, as in the app's defaults.
- **The screens** were measured by Lee in rootshell on the iPad: 39×27, the small floating window and the narrowest rootshell allows; 69×46, the slide-over; 114×45, the main window; and 73×36, a Ghostty pane on the Mac. 15 rows is the floor the design is drawn to.

A setting to run a command on a new ask, such as `rootshell-notify`, is parked. It would be a generic setting, like the terminal choice, not tied to rootshell.

**Settled with Lee on 19 November 2026, over the rounds:**
- **The marks are circles,** as on the notch card (round 2; round 1 drew asks as `◆` and `◇`). The orange is Claude Code's own, `#D77757`.
- **No `▸`:** the band alone marks the chosen row, so every row starts flush at the margin (round 3).
- **The headings are grey capitals,** `NEEDS YOU ●4 ●2 ───── ▿`: the words in `#7A82AB` at regular weight, the rule in `#565F89` (round 4).
- **Every recommendation in "Open for Lee" accepted,** with the correction above, and the question it raised answered: a pick always goes through the command, a session this Mac shows included. Nothing is left open.

**Decided by Lee on 20 November 2026,** after his test over SSH from his phone, where every asking session drew hollow though he had it open there, attached from the phone and detached on the Mac: **hollow means not open on the device you're looking from.** Over SSH, a session attached from that same device counts as here. On the Mac, nothing changes: hollow is what the notch dims (see "The marks").

**Decided by Lee on 20 November 2026,** for the narrow strip he keeps open on his iPad over SSH to see what needs him: he snoozes rows from there, reads rows the width cuts short, and must never open a session by accident. **`⏎`, or a tap on the chosen row, expands it; `o` opens it; `z` snoozes it, or wakes it in Snoozed.** Opening takes the deliberate `o`, and a tap or `⏎` never opens anything. There is no view-only flag. "Open" stays the docs' word, and nothing says "attach" (see "Keys", "Expanding a row" and "Snoozing a row").

**Decided by Lee on 26 November 2026,** once the notch's asks panel answered asks (24 November) and every surface took one set of keys (DESIGN.md, "Keys"): **the view answers a row's asks.** It hadn't only because the notch hadn't. Four choices settled how:
- **Each session on one line, as the notch draws it:** its mark, its words, its project at their right, its time. Lee chose it over keeping two lines, which kept 33 columns for a name at 39 where one line keeps 17 beside a project like Northwind, and showed what an ask asked without opening it (see "Rows and structure").
- **A row's asks open under it,** one at a time, as the snooze menu opens under its row: not in place of the list, nor beside it on wide terminals alone (see "Answering a row's asks").
- **`⏎` looks closer:** on a row with asks the view answers, it opens them; on any other row it expands it, as before. It stayed so when the notch gave `⏎` to the jump and its arrows to the asks panel on 27 November 2026 (DESIGN.md, "Keys"): the notch's asks panel comes out sideways, so its arrows step along that line, where the view opens a row's asks under it. Lee: "the notch lends itself to sideways arrows due to how it presents on the screen. sitrep tui isnt the same."
- **`u` takes back an answer sending,** in the notch's `⌘Z`'s place: the view reads keys as bytes, and none of the forms it reads carries ⌘.

## The looks

- **Round 1** drew four looks with diamonds: List, borderless sections and rows, the pane's idiom; Card, the notch's card in rounded box lines; Two-line, each session on two lines, roomy for a phone; Marks, the strip's two letters on pills, the densest.
- **Round 2** drew the same four with circles, from round 1's generator changed in place (`design/paper/round1/round1.py`, whose READ ME says round 2), so the repo holds no `round2/`.
- **Round 3** drew Two-line's rows under List's ruled headings, flush left, with no `▸` (`round3/round3.py`).
- **Round 5** (26 November 2026) is round 4 with each session on one line, as the notch draws it, and a row's asks opened under it (`round5/round5.py`). It draws the page as the build has since 20 November 2026, a blank top row and no title, from round 1's worlds with the asks the round adds. `python3 -I design/paper/round5/round5.py` writes 33 frames, reads each `.ansi` back cell for cell, and runs the width checks: none broken but the quiet board's, listed on purpose. Lee signed it off on 26 November 2026, and it is the generator of record.
- **Round 4** is round 3 with the headings' words in grey capitals (`round4/round4.py`), the generator of record until round 5. It imports round 3, which imports round 1's worlds, scenes, colours and helpers, so all three are kept. `python3 -I design/paper/round4/round4.py` writes every frame to `round4/frames/`, reads each `.ansi` back cell for cell, and runs the width checks: 21 frames, none broken, the quiet board's short line listed on purpose.

## Scope

**What changes.** The `sitrep` CLI gains one interactive, full-screen view: bare `sitrep` on a terminal. It draws on the alternate screen, reads the board as `sitrep watch` does, in the same process, and redraws as the board changes.

**What stays byte for byte.** Every existing command: its words, its output, its JSON, its exit codes and the files it writes. `sitrep watch` prints the same lines, so SitRep reads it as before. Bare `sitrep` off a terminal, as a script or a pipe runs it, keeps today's answer: the help on standard error, exit 1. The help gains one usage line, `sitrep [--no-notify]`, saying it opens the board in this terminal; every other line of it stays (Lee, 19 November 2026).

**Its name in the docs.** `docs/terminal.md` and the glossary call the panel the terminal view, since "the panel" there is what the notch opens (one term, one meaning); a new ask's OSC 777 is a terminal notification, beside the app's banner. The page's dots are the spec's marks, since "mark" there is a session on the strip, and its chosen row is the band, since "the band" there is the line above the Claude Code prompt.

**What the switch carries.** Three pieces move to where both the watch and the panel can use them, with no change to what they give: the watch's look loop (`cli/watch.ts`) into `cli/looks.ts`; `ago` from the pane's `hooks/look.ts` into core; and the panel's grouping of Needs you, which the app's Swift held alone, into core's `panelSections`.

## The frame

**The screen.** The panel owns the alternate screen while it runs. It hides the cursor and turns autowrap off (`CSI ?7l`), so a line written to the last column never scrolls the screen. Leaving restores all three. It paints no background: the terminal's own shows through every cell but the band and the wash.

**The margin.** Every line starts at column 1, counting from 0, so column 0 is the margin. The last column of the layout is a margin too: a row's time and a heading's chevron end at column W−2.

**The layout's width.** W is the terminal's width up to 120 columns. Past 120 the layout stays 120 wide and stands at the left, as round 4 drew it at 173. With no width to read, as a terminal that answers no size, it lays out at 80×24.

**Top to bottom:**
1. A blank row, row 0, while the whole body fits under it (see "A short terminal").
2. The body: the sections, a blank row between each two.
3. A pick's answer, when there is one: a blank row, then the answer's lines, just above the key line.
4. The last row, the key line. On a board gone stale, `as of 12:04` stands at its right end in grey, ending at column W−2 (see "Failure").

**No title** (Lee, 20 November 2026). The view had a title row, ` sitrep` in bold, and a blank row under it. Lee dropped both for the narrow strip he keeps open on his iPad, where every row counts: the body starts on row 0, and the stale notice, the title row's only other use, moved to the key line's right end, in the same words and style, so the keys keep their places. Every state that drew under the title drew from row 0 then: `Too small`, the failure words, the empty board and the short body's centred lead, until the blank top row came back the same day.

**A blank top row** (Lee, 20 November 2026). With the title gone, the body ran to the window's top edge: "would it be hard to re-insert the blank line at the top? but keep the title gone? its a little snug at the top". So row 0 is blank again, and nothing is drawn on it: no title, no version, no notice; the stale notice stays at the key line's right end. It gives way first, short of room, and never costs a row (see "A short terminal"). Every state takes it by the same rule, which the layout's `topRowOf` gives:
- **The board:** the body starts on row 1 while every block fits under it, its blank rows between sections and a pick's answer counted; else on row 0.
- **The empty board, `Looking for sessions…` and the failure words:** centred in the rows under row 0 while their lines fit there; else in the rows from row 0, as before.
- **`Too small`:** on row 1, at the margin, while the terminal has a second row; on row 0 in a terminal one row tall.

**A short terminal.** The key line always stays. Short of room, the blank top row gives way first: it stays only while every block fits under it, so the board never loses a row of content to it, at any height. Then, below 13 rows, the blank rows between sections give way; then the body scrolls. 13 rows give the body what 15 gave under the title, so a body keeps its blank rows at the same room as before. A fixed height for the top row, as the old title's 15, would cost a row at every height above it once the board runs longer than the window: at 39×27 the busy board would show a row fewer and the unreachable board would lose its folded Snoozed heading. So a board that grows past its rows, an expanded row or an opened snooze menu among it, moves up a row as the top row goes.

**Too small.** Below 24 columns or 8 rows the panel draws only `Too small` on row 1, under the blank top row, at the margin, cut to the width; on row 0 in a terminal one row tall. It keeps watching, so notifications still post, and it draws in full again once the terminal grows.

## The marks

Colour says what's needed; fill says where (DESIGN.md, "The notch and its panel"). Filled, the session is open on the device you're looking from. Hollow, it's away: no window holds it, its Claude ended, or it's open on no device you're looking from. On the Mac that device is the Mac's screen, so hollow is what the notch dims; over SSH it's the phone or iPad the panel runs on, so a session attached from that phone draws filled there, though no terminal on the Mac shows it (Lee, 20 November 2026). The panel learns the last from SitRep, which writes who views each held session to `here.json` as it reads them; with SitRep not running, a held session draws filled (Lee, 19 November 2026; "Built on: the code as it is", who views each session).

| Mark | Colour | Meaning |
|---|---|---|
| `●` | orange `#D77757` | an ask, a permission prompt or a question waits, here |
| `○` | orange `#D77757` | the same, away |
| `●` | blue `#7AA2F7` | Stopped: Claude finished its turn and waits on you, here |
| `○` | blue `#7AA2F7` | Stopped, away |
| `✻` | soft `#A9B1D6` | working |
| `◌` | grey `#7A82AB` | on its own work: agents, a workflow, a shell, a monitor, a wake |
| `◉` | orange `#D77757`, bold | a line new to Needs you, for two seconds, its row washed |
| `●` `○`, dimmed | the state's colour, dimmed | a row in Snoozed keeps its state's mark |
| `▿` / `▹` | faint `#565F89` | a section open / folded |
| `▲` / `▼` | grey `#7A82AB` | rows out of view above / below |
| `!` | bold | a pick's answer |
| `▹` / `▿` | the terminal's ink, bold | on the band's row, in the time's place: asks the view answers / their asks open under it |
| `━━ ━` | orange `#D77757` / faint `#565F89` | the ask shown, and the row's others, where it has more than one |
| `1` `2` `3` | grey `#7A82AB` | an answer's number: the digit sends it |
| `✓` | the background's colour, on the terminal's ink | an answer sending, for its two seconds |
| the band | the background, one step toward `#3E4A5B` | the chosen row, over its line, or every line of it expanded or opened |

**Without colour** (`NO_COLOR`), the shapes carry it. An ask and a turn share `●`, so an ask's name is bold and a turn's regular. The band is reverse video over both lines. A new ask keeps `◉` and loses its wash. In Needs you's heading, the asks' count is bold and the Stopped count regular, so `●4 ●2` don't rest on colour (19 November 2026). Metadata is faint (SGR 2): times, projects, counts in grey, the rule, the chevron, `▲ N more`, an away row's words. A bold name is never faint too, since many terminals draw SGR 1 and 2 as one intensity.

## Rows and structure

**A section's heading** is one row:
- its words in capitals, `NEEDS YOU`, `WORKING`, `SNOOZED`, at column 1, grey `#7A82AB`, regular;
- a space, then its counts;
- a space, then a rule of `─` in faint `#565F89`, out to column W−4;
- a space, then the chevron at column W−2: `▿` open, `▹` folded, faint.

**The counts,** as the notch's eyebrow counts them (`Eyebrow`, `SitRepPanel/Sections.swift`):
- **Needs you:** `●` orange then its asks in bold orange, `●4`: the lines of its ask rows, each ask, permission prompt and question waiting. Then a space, `●` blue and its Stopped in bold blue, `●2`: the rows at your turn, one a session. Each shows only above zero.
- **Working:** its rows, grey.
- **Snoozed:** its lines, grey: the asks asleep, and the turns put off.

**A row** is a session, on one line, as the notch draws it (Lee, 26 November 2026; until then on two, the project and status line under the name):

```text
 NEEDS YOU ●5 ●2 ─────────────────── ▿
 ● Data import            Litware   1m
 ● Help desk redesi… 2  Northwind   4m
 ● Drafted the 2.4 rel…  Tailspin  31m
```

- **The mark** at column 1.
- **Its words** from column 3, as the notch's row says them:
  - a row of asks, permission prompts or questions: the session's name, then, where more than one line waits, a space and their count in grey (`Help desk redesign 2`), the name cut before the count, never the count;
  - a Stopped row: what Claude left you, its status line;
  - a working row, or one on its own work: what it is doing, its status line;
  - a Snoozed row: the session's name and count, as a row of asks says them.
- **Its project** in grey at their right, ending 2 columns before the time's lane, so a section's projects stand right-aligned in a column, 2 columns after the words at the least.
- **The time** in its lane, right-aligned to end at column W−2, in grey. A section's lane is its widest time, 3 columns at the least: an age is `now`, `4m` or `26m`, and Snoozed's lane takes its wakes.
- **The arrow:** on the band's row, where the view answers one of its asks, `▹` stands in the time's place, in the terminal's ink, bold, as the notch's arrow stands over the time of the row under the pointer; `▿` while the row's asks are open (see "Answering a row's asks"). The band is the view's hover: the terminal sends no pointer moves.

**The words.**
- **The words:** an ask's name in the terminal's ink, bold; a Stopped row's status line in that ink, regular; a working or own-work row's in soft. In Snoozed, the name grey, an ask's bold.
- **The status line** is the row's first line (`RowLine`): its lead, then its subject after a space (`Running npm test`). A permission prompt joins its subject with `: ` (`Allow Bash: psql -f import.sql`). A question adds its `+2` after a space, in grey. A wake reads `Wakes in 12m`.
- **The time:** in Needs you, how long its newest line has waited; in Working, how long the turn has run; on its own work, how long since its turn ended. Each reads as the notch's `Age` words it, rounded down: `now`, `12m`, `1h` at 90 minutes, `3d`, core's `ago`, which the pane uses too since 22 November 2026, when it stopped rounding to the nearest. In Snoozed, when it wakes, as core's `wakeWords` says it (`14:00`, `tomorrow 09:00`, `Sat 09:00`, `next week`), or `until it moves`.

**Dimming.**
- **An away row** dims its words as one, as the notch does: each ink 0.61 of the way from the background, its mark kept full and hollow (`DIMMED` in round 1). A Snoozed row is never drawn away: its mark stays filled and its words undimmed, as the notch draws it (`SessionRow.swift`, 19 November 2026).
- **A Snoozed row** dims its mark, and only its mark. Its name is grey, as "The words" says, and its project is as any row's.
- **The band and the wash** sit over a row's line, or every line of a row expanded or opened, from column 1 to W−2.
- **A new ask's wash** is orange mixed 22% into the background, `#534345` on Nordfox, for two seconds from the first frame that shows the line.

**The order** is the notch's (DESIGN.md, "The rows", 13 November 2026):
- **Needs you:** its asks, those drawn filled first, then the away ones; then its Stopped, the same way. Each part keeps core's order, newest first.
- **Working:** working, the longest running first; then on its own work, those waiting on a wake first, the soonest due first.
- **Snoozed:** the soonest to wake first, those until it moves last, then the oldest (`inSnoozedOrder`).

**Folding.** Snoozed is folded at first, its heading alone. `s` opens it and scrolls its rows into view; `s` again folds it. The fold isn't saved: each run starts folded. Needs you and Working never fold.

**Scrolling.** The body shows the rows that fit, in whole rows.
- **Out of view:** above them, `▲ 11 more` in grey on a row of its own; below them, `▼ 6 more`. Each counts sessions, not lines.
- **The pinned heading:** scrolled into a section, its heading stays on the body's top row, above `▲`.
- **A short body,** as when an answer takes its rows: the pinned heading and `▲` stand above the first row only if a row and `▼` still fit under them; else `▲` alone if it fits; else the row alone.
- **Never a bare edge:** the body never starts or ends on a blank row, or on an open section's heading, while blocks follow: a heading stands only with a row under it. A folded Snoozed heading is drawn last.
- **The band in view:** the view moves the least that keeps the band's row whole in sight. With no band, opening Snoozed scrolls its last row into view.

**A quiet board.** With no rows at all, the body reads `All clear`, bold, then a blank row, then `Nothing needs you, and nothing is running.` in grey, wrapped at 24 columns. Each line is centred, the three a little above the middle. The key line reads `q quit`.

## The live region

Doesn't apply: the panel draws on the alternate screen, never in the terminal's flow, and leaves nothing in the scrollback.

## Progress

Doesn't apply: the panel shows no step running. Its marks are still: `✻` doesn't spin (Lee, 19 November 2026), since turning would redraw every working row several times a second over SSH. Only the clock moves anything: the times turn over each minute, a wake's countdown with them, and a wash ends after its two seconds.

## Keys

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j` | The first press puts the band on the top row in view; then each moves it a row, across sections, skipping headings |
| `PgUp` `PgDn` | Moves the band by the rows in view, so none is skipped unseen |
| `Home` `End` | Moves the band to the first or the last row |
| `⏎` | Looks closer: on a row with asks the view answers, opens them under it, and closes them again (see "Answering a row's asks"); on any other row, expands it, and folds it again (see "Expanding a row") |
| `o` | Opens the band's session, its asks open or not (see "Picking a row") |
| `z` | Snoozes the band's row by a menu of times, or wakes it in Snoozed (see "Snoozing a row"); with its asks open, snoozes the ask shown |
| `1`–`9` | In the snooze menu, snoozes to the choice of that number; with a row's asks open, sends the answer of that number; elsewhere does nothing |
| `x` | With a row's asks open, ignores the ask shown |
| `←` `→` | With a row's asks open, shows the ask before or after |
| `u` | Takes back the answer sending, within its two seconds |
| `s` | Opens or folds Snoozed |
| `esc` | Closes the snooze menu, else the row's asks, else drops the band and any pick's answer |
| `q`, `Ctrl-C` | Leaves |
| `Ctrl-Z` | Suspends the panel; `fg` brings it back, drawn afresh |

**The key line** names the keys that work now, most needed first: `↑↓ pick  s snoozed  q quit` with no band, and with one `↑↓ move  ⏎ expand  o open  z snooze  s snoozed  q quit`. While the band's row is expanded `⏎ fold` stands in place of `⏎ expand`; on a Snoozed row `z wake` in place of `z snooze`; and on a row that can't be snoozed, a window's prompt alone or a working row, `z` isn't named. On a row with asks the view answers, `⏎ asks` stands in place of `⏎ expand`. In the snooze menu the line is the menu's own, `↑↓ pick  ⏎ snooze  esc cancel`. With a row's asks open, the line is theirs: `1–3 answer  ←→ ask  esc close`, the digits' range the answers' (`1 answer` for a yes, none for a words ask), `←→ ask` only where the row has more than one; while an answer sends, `u undo  esc close`. Each key is bold in the terminal's ink, its word grey, two spaces between hints. `s snoozed` shows only while Snoozed holds rows; an empty board's line is `q quit`. Short of room, whole hints drop from the right, `q quit` last, since it always applies, or in the menu `esc cancel`, or with a row's asks open `esc close`: at 39 columns the band's line is `↑↓ move  ⏎ expand  o open  q quit`, or `↑↓ move  ⏎ asks  o open  q quit` on a row with asks, at 52 `↑↓ move  ⏎ expand  o open  z snooze  q quit`. `↑↓` is named only while a row is in view. PgUp, Home, `j`, `k`, `esc` and `Ctrl-Z` work but aren't named, nor are the digits in the snooze menu, whose choices show them, nor `x`, `z` and `o` with a row's asks open, whose foot shows them.

**Decoding.** Keys come in raw mode as bytes. `CSI` and `SS3` arrows both read as arrows (`ESC [ A`, `ESC O A`), so application cursor mode doesn't matter. A lone `ESC` with nothing after it within 50 ms is `esc`. Any other sequence cut short by that quiet gap is held: when the rest of it comes, however late, the sequence is read whole and its key thrown away, so the rest of a mouse report split over a slow link is never read as keys, `1`–`9` among them, to snooze a row unasked (26 November 2026). One that turns out a paste's start is held to the paste's end and dropped, as any paste is. What a stop from outside cuts short is let go, so the first key after `fg` is read. `1` to `9` each carry their number; `0`, and any other byte, does nothing.

**Mouse and touch** (Lee, 19 November 2026). The panel turns on button reporting in SGR's form (`CSI ?1000h`, `CSI ?1006h`), never motion, and turns it off on leaving and for a hand-over. A terminal that sends the older X10 form (`ESC [ M` and three bytes) is read the same way, so a click never reads as a key. Bracketed paste is on too (`CSI ?2004h`), and a paste is dropped whole, so pasted text never acts as keys.
- **A tap or a click** on any line of a row puts the band on it; one on the band's row looks closer, as `⏎` does, opening its asks or expanding it, and closing or folding it again, and never opens the session (Lee, 20 November 2026). With a row's asks open, a tap acts as the notch's click does (see "Answering a row's asks").
- **The wheel or a swipe** scrolls the view a row a notch; the band stays on its session, in view or not.
- **No hover:** hover needs every pointer move sent over SSH.
- **Selecting text** in the panel needs the terminal's modifier held while reporting is on.

**The band and a changing board.** Rows take their new places at every look. The band stays on its session wherever that row goes, and the view keeps it in sight (Lee, 19 November 2026): a dashboard left open for hours must stay current, where the notch holds its rows only while its panel is open, a glance. A session that leaves the board passes the band to the row now in its place, else the row above; with no rows left, there's no band.

## Expanding a row

A row on one line cuts its words short, and says either the session's name or what it is doing. `⏎`, or a tap on the chosen row, expands it, so nothing is cut and both show; again, it folds (Lee, 20 November 2026). A row with asks the view answers opens them instead (see "Answering a row's asks").

```text
 NEEDS YOU ●5 ●2 ─────────────────── ▿
 ● Data import                      1m
   Litware · Allow Bash: psql -f
   import.sql
 ● Help desk redesi… 2  Northwind   4m
```

- **Which rows:** every row but one with asks the view answers, whose `⏎` opens them. A prompt alone, a question, a Stopped row, a working one and a Snoozed one expand.
- **One expanded row at most:** the band's. Moving the band to another row folds it, by a key, a tap, or a changing board that passes the band on; coming back finds it folded. A row that only moves keeps it expanded.
- **What it shows,** what the two-line rows showed until 26 November 2026, whole, from what the feed gives the row (core's `Row` and `SnoozedRow`, each `RowLine`), nothing read beyond it:
  - **line one:** the mark, then the name and its count, wrapping under the names' column (column 3) as far as they need, the time kept at the first line's right, fitted as a folded row's is;
  - **a row of one line:** its project and ` · `, then its status line and a question's `+2`, wrapped as one, as line two reads them; ` ·` stays with the project's last word, so no line starts on it;
  - **a row of several lines,** as several asks: its project alone, then each line's words on a line of its own, each wrapped, in the row's order.
- **The words keep their looks:** the name as the row's name, the project, count and `+2` grey, the status lines soft. A word wider than a line goes in pieces, as a pick's answer does.
- **The band** lies over every line of the expanded row, and the view keeps the whole row in sight, as it does any band.
- **Taller than the body,** the row is cut to the body's rows, and its last line kept reads `…`; in a body of one row it draws as its folded line. Scrolling, the pinned heading, `▲` and `▼` follow the layout's rules for a row of that height. Below 24 columns or 8 rows the panel still draws `Too small`.
- **The fold isn't saved,** as Snoozed's isn't.

## Snoozing a row

`z` on the chosen row snoozes it from a menu of times drawn under it, as the notch's row menu does; on a row in Snoozed it wakes it (Lee, 20 November 2026).

```text
 NEEDS YOU ●3 ●1 ──────────────────────────────── ▿
 ● Help desk redesign 2                          4m
   Northwind · Thread replies, or keep them flat?
   1 In an hour                               15:00
   2 Later today                              17:00
   3 Tonight                                  18:00
   4 Tomorrow                                 09:00
   5 Next week                            Mon 09:00
   6 Until it moves
 ○ Data import                                   2h
```

- **Which rows,** as the notch offers Snooze (`RowMenu`): a row that needs you, of asks, or of your turn alone. On a row of a window's prompt alone, or a working row, `z` answers in the answer line, as a pick's refusals do: `Data import waits on a prompt in its window, and a prompt can't be snoozed.`, or `Mobile app needs nothing of you: there is nothing to snooze.` With no band, `z` does nothing.
- **The choices:** Snooze's times as Lee set them in SitRep, read from the app's `snooze.json` at every look, core's defaults where there is none (`snoozeSettingsOf`); those still to come, in their order (`snoozeChoicesAt`), each worked out as the menu opens (`snoozeAt`), from the time of the last look, a failed one too, so a stale board offers no time already past; then Until it moves. A choice snoozes to the time it showed, as the notch's does, though the clock moved on meanwhile.
- **The words** are the notch's: In an hour, Later today, Tonight, Tomorrow, This weekend, Next week, Until it moves (DESIGN.md, "Snooze"). Each time stands at the right in grey, saying only what its name doesn't, as the notch's menu says it (`WakeTime.besideChoice`, core's `timeBeside`): the time alone, `15:00`, and beside This weekend and Next week its weekday too, `Mon 09:00`. Until it moves has none. Unlike the notch, no separator stands before Until it moves, so the menu takes no row more than its choices.
- **Its looks:** a choice a line: its number in the names' column, in the key line's grey, then a space and its name, in the terminal's ink; the band moves onto the choice picked, its name bold, its number still grey, and leaves the row while the menu is open. Short of room, the time goes, then the name is cut; the number never is. Only the first nine choices have a number, and the words of any past them stand in line with those that have one; the menu holds seven at most today (26 November 2026, DESIGN.md, "Keys").
- **Its place:** under the chosen row, expanded or not, the two kept whole in sight as one. Short of room, the row's lines give way first, down to its first line, which an expanded row draws folded, so the menu always says whose it is; then the menu shows the choices it has room for, scrolled the least from where it stood that keeps the pick among them, so every choice stays reachable and the pick is always drawn. An answer that lands while it is open shrinks it the same way. The layout's other rules hold, and `Too small` too.
- **Its keys:** `↑↓` pick a choice, scrolling the menu where it is cut short; `⏎`, or a tap on a drawn choice, snoozes to it, never to one out of sight; `1` to `9` snooze to the choice of that number, as `⏎` on it would, and a digit past the choices does nothing; `esc`, `z`, or a tap anywhere else closes it, writing nothing. Any other key does nothing while it is open, but `q`, `Ctrl-C` and `Ctrl-Z`, which work as ever. With the menu drawn on no line, as when an answer fills the body, neither `⏎` nor a digit snoozes.
- **A digit chooses by its number, in sight or not** (decided 26 November 2026): the numbers are fixed to the choices, so `1` is always the first, In an hour under the defaults, even with the menu scrolled past it. A choice out of sight keeps its number, and the same key always makes the same choice.
- **The menu is the row's:** a board that passes the band to another row closes it, as does one on which the row can no longer be snoozed: its asks gone to a prompt alone, or the row now Working or Snoozed.
- **What it writes:** exactly what `sitrep snooze` writes, the CLI's own line in its own file (`<session>/cli.jsonl`), run in the panel's process as the command runs (`cli/acts.ts`) on the words the app's row menu gives it: `--until <ms>` but for Until it moves, `--session <id>`, then after `--` the asks the row showed as the menu opened, so none is snoozed unseen; a row of your turn alone names none. The line, for Help desk redesign's ask k1 snoozed for an hour from 14:00 on 18 November 2026:

  ```text
  {"v":1,"at":1795010400000,"seq":1,"type":"snoozeSession","until":1795014000000,"asks":["k1"]}
  ```

- **Waking:** `z` on a Snoozed row writes `sitrep wake`'s line, with no menu. A second `z` on it before a board shows the wake writes nothing, rather than a refusal that it is not snoozed.
- **Afterwards:** the next look finds the row in Snoozed, and the band passes on as "The band and a changing board" says: to the session's Snoozed row while Snoozed is open, else to the row now in its place.
- **A failed write,** refused by the command's checks or failing in the files, gives its words in the answer line and changes nothing: an ask that landed since the menu opened answers `An ask waits on you that the snooze did not name: look at it, then snooze again.` A choice whose time came while the menu stood open writes nothing, and says so as the notch says it (`WakeTime.comeAlready`, core's `wakeWords`): `18:00 has come already.`

## Answering a row's asks

`⏎` on a row with asks the view answers opens them under it, one at a time, and a digit sends an answer, as the notch's asks panel does (Lee, 26 November 2026; DESIGN.md, "Answering from the panel" and "Keys").

```text
 NEEDS YOU ●5 ●2 ─────────────────── ▿
 ● Data import            Litware   1m
 ● Help desk redesign 2              ▿
   Northwind
   Thread replies, or keep them flat?
   Asked 4m ago                   ━━ ━
   1 Threaded · Recommended
   2 Flat
   3 Flat, with a quote of the one it
     answers
   x Ignore  z Snooze  o Open
 ● Shift schedules        Contoso  26m

 1–3 answer  ←→ ask  esc close
```

- **Which rows,** as the notch's arrow takes them: a Needs you row with at least one board ask the view answers, a yes, a choice or a words ask. A row of Claude Code's own permission prompts or questions alone has none, nor has a Stopped, working or Snoozed row. A row of both opens only its board asks.
- **Opening:** `⏎`, or a tap on the band's row, its `▹` among it. The band stays on the row, over every line of it and its asks, as over an expanded row, so the asks read as one card, as the notch's asks panel stands on its own black.
- **The row's head:** its name and count wrapped whole under the names' column, `▿` in the time's place, then its project alone, in grey, as the asks panel's top line names the session and its project.
- **One ask at a time,** the session's asks in the row's order, newest first:
  - **the title,** bold, in the terminal's ink, wrapped whole;
  - **when it was asked,** `Asked 4m ago` in grey, its age counted as its line on the row counts it; at its right, ending at column W−2, the page dots, where the row has more than one ask: `━━` in orange for the ask shown, `━` in faint for each other, a space between;
  - **its answers,** a row each: its number in grey in the names' column, a space, its words from column 5, wrapped there to two lines at most, the second cut with `…`. A yes has one, its yes; a choice one for each option, Claude's pick first. Claude's pick is in Claude Code's suggestion lilac `#B1B9F9`, ` · Recommended` after its words in `#9AA2EE`, on a line of its own within the two where its words leave no room, the words cut before it past two lines, so it always shows. Any other answer's words are in the terminal's ink. No answer has a ground of its own: a ground in a terminal reads as the band;
  - **a words ask** has no answers, nor has a choice with no options: its title, its age, then the foot, whose `o Open` opens its session, as the notch's Open in Claude does;
  - **the foot:** `x Ignore  z Snooze  o Open`, each key bold in the terminal's ink, its word grey, as the key line's hints. `z Snooze` shows only while Snooze offers a time, as the notch's Snooze ▾ does.
- **Its keys,** the notch's asks panel's (DESIGN.md, "Keys"), but `⏎`, which on the notch's asks panel is Open in Claude and here closes, since `⏎` never opens a session in the view (Lee, 20 November 2026):
  - `1` to `9` send the answer of that number, `1` the first, Claude's pick where Claude has one; a digit past the answers does nothing;
  - `x` ignores the ask shown, with the same two seconds;
  - `z` opens a menu of Snooze's times in the foot's place, as the row's snooze menu, for the ask shown alone, and no Until it moves; `esc` or `z` closes it, back to the ask;
  - `o` opens the session, as `o` on the row does (see "Picking a row");
  - `←` `→` show the ask before or after, as the dots lie, one a press, at once; nothing wraps;
  - `⏎` and `esc` close the asks; `↑` `↓`, `k` `j` move the band and close them, as a menu's arrows close its submenu;
  - `s` does nothing while they are open; `q`, `Ctrl-C` and `Ctrl-Z` work as ever.
- **Its taps,** as the notch's clicks: a tap on an answer sends it, as its digit; on a dot, shows its ask; on `Ignore`, `Snooze` or `Open`, acts as its key; on `undo` while an answer sends, takes it back. A tap anywhere else, on the row's head or another row, closes the asks and does nothing more, as a click off a Mac submenu only closes it; the next tap acts.
- **A key lands only on what has stood 300ms,** as the notch's press does: a digit, `x` or a tap within 300ms of the board changing the ask under it, an ask leaving, an edit, a send stepping on, does nothing. The keys' own paging starts no beat.

**Answering, with two seconds to undo.** A digit, or a tap on an answer, holds it: its row turns ink on white, the background's colour on the terminal's foreground, reverse video without colour, a `✓` at column W−2, its words keeping their lines. The foot reads `Sending Threaded  ◔  u undo`, `Sending` in grey, the answer's words in the ink, cut to fit, and a ring in orange that fills a quarter each half second, `◔` `◑` `◕`. After 2 seconds the view sends it. `x` holds an ignore the same way, its line reading `Ignoring`.

```text
 ● Help desk redesign 2              ▿
   Northwind
   Thread replies, or keep them flat?
   Asked 4m ago                   ━━ ━
   1 Threaded · Recommended
   2 Flat                            ✓
   3 Flat, with a quote of the one it
     answers
   Sending Flat  ◑  u undo
```

- **`u`, or a tap on `undo`,** within the two seconds takes it back, and nothing is written.
- **While an answer is held,** digits and `x` do nothing, as the notch's answer rows take no click then. Every other key acts as ever, and the answer still goes: `esc` closes the asks, `↑` `↓` move the band.
- **Once it goes,** the asks step to the session's next ask; after its last, they close.
- **`q` or `Ctrl-C` while an answer is held** sends it at once, waits on the write, then leaves, as quitting SitRep does. A hangup or `SIGTERM` leaves at once: the answer is not sent.
- **What it writes:** exactly what `sitrep answer` writes, run in the view's process as the command runs (`cli/acts.ts`), as the snooze menu writes `sitrep snooze`'s line: `sitrep answer <ask> <answer> --wants <what it wanted> --session <id>`, or `--ignore` in the answer's place. `--wants` gives what the ask wanted as it was shown, so an ask Claude reshaped since is refused, as the notch's are. The reply goes into the session's inbox, and its window delivers it as "From the board:", as every answer from the board goes.
- **A refusal,** as an ask answered in its window meanwhile, gives the command's words in the answer line, as a pick's refusals do, and the ask stays.

**Snoozing the ask shown:** a choice writes exactly what `sitrep snooze --ask <id> --until <ms> --session <id>` writes, the ask alone, as the pane's one-ask snooze and the notch's Snooze ▾ do. A refusal gives its words in the answer line.

**A changing board.**
- **An ask that leaves the board,** answered in its window, ignored or resolved, leaves the asks with it; the next takes its place, else the one before; with none left, the asks close.
- **An ask edited** while shown is drawn as it now reads.
- **The row leaving Needs you,** its asks gone to a prompt alone, or the session Working, Snoozed or gone, closes the asks, as the snooze menu closes.
- **Moving the band** to another row, by a key, a tap or a board that passes it on, closes them. An answer held still goes.

**Short of room.** The asks are kept whole in sight with their row, as the snooze menu is with its. Short of rows, the head gives way first, to its first line; then the title to its first line, cut with `…`; then the `Asked` line, the dots with it; then the foot, its keys still working. The answers stay whole, and the view scrolls the least that keeps them in sight. A digit sends only an answer drawn: where even the answers don't fit, a digit past those drawn does nothing.

## Picking a row

`o` on a row runs SitRep's resume command for its session in the panel's own terminal, as the app's click does for a session this Mac doesn't show (DESIGN.md, stage 8, "One command, the resume command", 13 November 2026). The panel never attaches a session itself: it runs no `zmx attach` and no `tmux attach`, and knows no session tool. What the command does is yours, and whether it works is yours too (Lee, 19 November 2026: "It should never run zmx attach. We should be using the existing commands that are registered for this process.").

**One command, not two.** The only command SitRep registers for opening a session is the resume command. The open command of stage 7, step C, with its `{session}`, `{socket}` and `{pane}`, was folded into it on 13 November 2026. SitRep passes over an `openCommand` still saved, and Settings has no field for it. So a session a live window holds and one no window holds both run the resume command, filled from the window the session is carried on from.

| The session | `o` |
|---|---|
| A live window in tmux or zmx | The resume command, filled from that window |
| Live windows, none in tmux or zmx | The answer: `Release notes can't be opened here: its terminal has no tmux or zmx.` |
| A live window that says nothing of where it is | The answer: `Release notes can't be opened here: its window didn't say where it is.` |
| No live window, with a last window | The resume command, filled from the last window |
| No live window, and none to resume | The answer: `Release notes can't be carried on from here: no window of it is left.` |
| Gone from the board by the pick | The answer, as the app's jump says it: `There is no such session on the board, in any project.` |

- **Which live window.** The first in core's jump order (`FeedWindow.jumpOrder`) whose `where` names tmux or zmx. A Snoozed row picks the same way.
- **Why tmux or zmx is still read.** Only to refuse. A window in no multiplexer ends its Claude with its terminal, so a command run for it could only start a second Claude beside the first, as stage 1 settled and the app's step C refused. The panel reads the heartbeat's `where` and nothing more: it asks tmux nothing and runs zmx never.

**The placeholders,** filled as the app fills them (`ResumeFacts`, `SitRepScreen/ResumeCommand.swift`):
- `{claude}`: the window's writer, the Claude Code session id of the session's latest conversation: the live window's, or the last window's (`FeedSession.lastWindow`) for a session no window holds;
- `{dir}`: that window's `directory`;
- `{tty}`: that window's device, filled only while `ps` shows a Claude Code running on it, with no later conversation seen there (`ownsDevice`); otherwise `''`. A held session's live window owns its device. A Claude suspended there fills nothing, since the pick then refuses (see "Never beside a living Claude").

**The line,** read and refused as the app's `TypedCommand` reads it, in its words. It holds to plain shell syntax, and anything else is refused in words that point to a script (Lee, 20 November 2026). A reader that refused each place a shell reads a value again could never be finished: three reviews each found new ways for a folder's name to run as code across sh, bash 3.2 and 5.3, zsh, dash and ksh.
- **Plain shell syntax,** which those shells all read alike:
  - words of ASCII letters, digits and `_ . / : @ % + , = -`, and `\` with the character after it;
  - a `~` starting a word, or right after the word's first `=` or a `:` past that, as in `PATH=~/bin:~/go/bin` and `--flag=~/x`;
  - spaces between words, and `|`, `||`, `&&` and `;`; never a tab, which can't be typed, since a shell completes at one;
  - redirections: `<`, `>` and `>>` to a word, and `>&` or `<&` to a single digit, as `2>&1`, which nothing may join;
  - `[` and `]` as words of their own, as `[ -n "$s" ]`;
  - `'…'`, holding anything;
  - `"…"`, holding what prints but a backtick and `!`, and `\` only before `"` or `$`;
  - a parameter: `$name`, `${name}`, `$?`, `$$`, or `$1` to `$9`;
  - `$(…)` outside quotes, holding the same syntax, however deep.
- **Where a parameter ends.** Outside braces, a parameter must end where every shell ends it: at a blank, an operator, a redirection, a `)`, a double quote, one of `/ - = , + @ % \ $`, or the line's end. Inside double quotes, a `'` ends one too, as in `"$USER's"`. `${name}` ends at its brace, so any part of a word may follow it, as `${PATH}:/opt/bin`. The shells read on past other characters (found by the fuzz and the probes after it, 20 November 2026):
  - zsh reads `$x[…]` as a subscript, even in double quotes, and `$x:…` as modifiers, of which `$x:F:…:` evaluates the `…` as arithmetic, running a value's `$(…)`;
  - zsh reads `$12` as `${12}`, and `$$'…'` as `$$` and `$'…'`, in which `\'` ends nothing;
  - ksh reads `$x.y` as one name, and bash and ksh take a letter past ASCII into a name.

  All but `$'…'` hold inside double quotes too, so a `.`, `:` or `[` after a parameter is refused there as well.
- **No `~` before a placeholder.** zsh and ksh read a tilde through the quotes after it: `~'root'` is `/var/root` there, and the text as written in bash and dash (proven 20 November 2026). So `~{dir}` is refused wherever a `~` may stand.
- **`$!` and `$#` left out.** An interactive bash or zsh reads the `!` of `$!` as history, and with `&` alone refused, no job runs in the background for it to name. `$#` is always 0 here, and zsh reads its `#` as asking the length of what follows: in `$#$(…)` zsh reads the length of `$$` and a glob qualifier where the others read a `$(…)`.
- **The placeholders** stand outside every quote, at the top level or in a `$(…)`, joined to a word or not: `id={claude}` is `id='…'`, one word. Inside quotes, a name that is no placeholder's is text, as awk's `'{print $1}'`.
- **Quoted.** Each value goes in single quotes, never bare.
- **Refused before anything runs.** The command, read less the spaces around it, the first that applies:
  - empty (see "Which command");
  - a character that doesn't print: `The resume command in Settings has a tab, which can't be typed.`, a line break and an escape named so too, any other by its code point;
  - a placeholder SitRep doesn't know: `The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}.`;
  - one inside quotes: `The resume command in Settings puts {dir} in quotes. Remove them: SitRep quotes each value itself.`;
  - the first part past plain syntax, read from the left: any other part, named as found, ``The resume command in Settings uses `(`, which SitRep can't check. Put that part in a script and pass it {claude}, {dir} or {tty}, as in ~/bin/resume {claude} {dir}.``, a backtick named `a backtick`; or a quote or a `$(…)` left open, ``The resume command in Settings opens `"` but never closes it.``.

  Then the values, once the guard has passed (see "The order of checks"), the first that applies:
  - `{dir}`, where the window said no folder (see "No folder");
  - a value with a character that doesn't print: `For Release notes, the folder its Claude ran in has a tab, which can't be typed.`;
  - a value starting with a dash, which a program would read as an option, as `claude --resume {claude}` would read an id of `--settings=…`: `For Release notes, the Claude Code session's id starts with a dash, which a program would read as an option.`
- **What takes code from an argument is yours.** Two kinds take code, a name or a number from an argument and evaluate it, as a program running an argument as code does, `sh -c` among them. They pass as words: a command that passes a placeholder to one takes that risk.
  - a builtin: `eval`, `trap`, `let`, `read`, `declare`, `typeset`, `local`, `export`, `printf -v`, `test`'s numeric comparisons, `shift`, `exit`, `return`, `ulimit`, and others, such as zsh's `getln` and `repeat`;
  - an assignment to a variable the shell evaluates: `PS1`, `PS4`, `PROMPT_COMMAND`, `ENV`, `BASH_ENV`, and integer ones such as `RANDOM`, `SECONDS` and `OPTIND`.
- **Run** as `$SHELL -l -c <line>`: a login shell that isn't interactive. It reads your login files, such as `.zprofile` or `.bash_profile`, so it has the PATH and environment they set. It reads no `.zshrc` or `.bashrc`, which only an interactive shell reads. The app types its line at the prompt of an interactive login shell in a new window, which reads both. So an alias or a function defined in `.zshrc` works from the app's click but not from the panel; a script on the PATH works from both.
- **A POSIX login shell only.** Each value is quoted for a POSIX shell's single quotes, and in fish's a `\'` is an escape. So the line runs only where the last part of `$SHELL`'s path is `sh`, `bash`, `zsh`, `dash` or `ksh`. Any other refuses before `ps` is asked: `sitrep can run the resume command only in a POSIX shell; your login shell is fish.` With `$SHELL` unset or empty: `sitrep couldn't start your login shell: $SHELL is not set.`

**Which command.** SitRep's setting, read from SitRep's saved settings, and the default, `cd {dir} && claude --resume {claude}`, where none is saved (Lee, 19 November 2026). The settings are JSON under `app` in SitRep's defaults, `~/Library/Preferences/com.leeovery.sitrep.plist`, a binary property list the panel reads itself (`cli/panel/plist.ts`), as `SitRepMenu/AppSettings.swift` saves them:
- its `resume`, read as saved, an empty one included;
- else the `resumeCommand` saved before `resume` had a key of its own, only where it holds a command;
- else the default. Defaults that can't be read hold none. A command you wrote to run Claude in zmx then carries on there, so a dropped connection doesn't end it. A field saved empty refuses in SitRep's words: `The resume command in Settings is empty. To carry Release notes on, set one, or restore the default.`

**Never beside a living Claude,** after the app's click (`Jump.carryOn`), read from `/bin/ps -t <device> -o stat=,comm=` before anything runs:
- **What `ps` is asked.** Only a terminal's device, `/dev/tty…`, and within 2 seconds. A Claude Code is told by its program as `ps` gives it: `claude`, or a file in a `claude/versions` folder. One whose state starts `T` is suspended. A device no longer there runs nothing, and `ps` isn't asked. `ps` ending 1 with nothing to say means no process is on the device. Any other failure, a device that isn't a terminal's, or no answer in time, is no answer.
- **Suspended,** whatever the command: a Claude stopped on the window's device, whoever was seen there after, answers `Release notes is suspended in its window: type fg there to bring it back.`, starting nothing.
- **No answer from `ps`,** whatever the command: `Could not tell whether Release notes's Claude is still running: the process table gave no answer.`
- **The guard, the default's alone:**
  - a Claude seen running on the window's device, the device still its conversation's (`ownsDevice`): `Release notes's Claude is still running: set a resume command that can reach it, in SitRep's Settings.`;
  - a live window holding the session with no Claude seen on its device, as a tab just closed: `Release notes's window has just stopped answering: try again in a moment.`
- **A later conversation's Claude** running on the device isn't the session's: it refuses nothing, and fills no `{tty}`.
- **A command you wrote** runs past the guard: what it does is yours. The default is told by its text, less the spaces around it, so a command saved the same as it is the default.
- **No folder:** a window with no directory, for a command naming `{dir}`, answers `Release notes's last window did not say which folder it ran in, as a window on an older sitrep does not, so sitrep has nothing to put for {dir}.` For a held session, it says `Release notes's window`.

**Where the app's click differs,** on purpose:
- **A suspended Claude.** The app takes you to its window where a terminal on this Mac shows it, saying `… is suspended in this window: type fg to bring it back.` Where none shows it, the app carries the session on as any other: the default refused, a command you wrote run, `{tty}` filled where the device is its own. The panel never jumps, and reads no screen to tell whether a terminal here shows it. So it treats every suspended Claude as the app treats one it can take you to: yours to bring back, with nothing started, whatever the command.
- **The words.** The app's suspended refusal adds `which SitRep could not bring forward`; the panel tries no window, so it drops that. The app's running refusal says `still running where this Mac doesn't show it` and `in Settings`; the panel can't tell where it shows, and isn't SitRep, so it says `still running` and `in SitRep's Settings`.
- **Telling a Claude Code.** The app reads each process's program path; the panel reads `ps`'s argv[0] (see "Known limits").

**The order of checks,** the first that refuses answers, and nothing runs before the last:
1. The feed (`reachOf`): a session gone from the board, then the table's refusals.
2. The command, typed (`typedOf`): its own refusals, with no `ps` asked.
3. The login shell: unset, or not a POSIX shell.
4. `ps` on the window's device: no answer, then suspended.
5. The guard, the default's alone.
6. The values (`filledOf`): `{dir}` with no folder, a value that doesn't print, then one starting with a dash.

So with the default command, picking a session a live window holds always refuses: only a command that can reach a running Claude opens one. Lee's own command (DESIGN.md, stage 8's examples) attaches the session holding that Claude, or starts one resuming it.

**No special case, on the Mac or anywhere** (Lee, 19 November 2026). A pick always runs the command in the panel's terminal, a session already showing in a window on this Mac included. The panel never jumps, never asks SitRep to, and never moves the Mac's screen. Lee: "As long as we always go through the command … It's generic enough that it's up to the user to handle their own scenarios through the registered commands." What becomes of a session open elsewhere is the command's business, not SitRep's. Lee's own takes the session over from the other window, which then says it's open elsewhere, so the session never runs in two terminals at once.

**The hand-over.** Running the command hands the terminal over, then takes it back:
1. Leave the alternate screen, show the cursor, turn autowrap on, mouse reporting, bracketed paste and raw mode off, and stop reading keys.
2. Run the login shell with the panel's standard input, output and error, and ignore SIGINT and SIGQUIT while it runs: they're the command's. SIGTSTP keeps its default, so Ctrl-Z stops the whole job, the panel with the command, and `fg` carries on with both; the panel takes nothing back at that SIGCONT. A panel that heard SIGTSTP held the terminal from the shell, the command stopped, since Bun can't see a child stop (shown live, 19 November 2026). SIGTERM and SIGHUP still end the panel, which takes nothing back, but the process ends only once the command ends, then exits 143 or 129: Bun's child keeps it alive, and that is right, since ending sooner would hand the terminal to the shell under the command.
3. When the shell ends, unless a SIGTERM or SIGHUP sent with its end closed the panel first, take the terminal back: enter the screen, read the size afresh, and draw whole from the latest board, the band where it was, with the pick's answer, if it leaves one.

- **One pick at a time.** An `o` while a pick is under way does nothing. Nothing takes the terminal back while the command has it, a Ctrl-Z's take-back pressed while the pick was readied included.

- **Coming back is the command's.** The panel takes the terminal back only when the command ends. A command attaching a zmx session in a plain shell returns when you detach, with zmx's `Ctrl-\`. A resumed Claude with no multiplexer returns when you quit it. A command that switches this terminal's client and ends, or never ends, decides otherwise; the panel doesn't watch it.
- **Inside a multiplexer.** A panel running inside zmx or tmux runs the command there like anywhere else. Whether the command nests a client, switches this one or refuses is the command's, and no question of the panel's: it attaches nothing itself (Lee, 19 November 2026; this was Open for Lee, 2).
- **Watching meanwhile.** The panel keeps looking at the board, drawing nothing, and posts notifications, while the command runs (Lee, 19 November 2026).
- **A command that fails** says so in its own words, on the screen the panel gave it. One that ends non-zero within 2 seconds also leaves an answer when the panel comes back: `The resume command ended with 1 for Release notes.` One a signal ended, exiting 129 and up, leaves none, since that is mostly a Ctrl-C you pressed yourself.
- **A login shell that can't start** leaves its answer, naming `$SHELL`'s path: `sitrep couldn't start your login shell, /bin/zsh.`

**A pick's answer** sits above the key line: `!` bold, a space, then the words in the terminal's ink, wrapped at W−4 and hung under the first word. It stays until the next key.

## Notifications

- **What notifies.** Each ask new on the board, as core's `newRows` finds it and the app's `newAsks` keeps it to asks: never a permission prompt, a question, or Claude stopping.
- **What doesn't.** The panel's first board posts nothing, as the app's first board doesn't: core's `newRows` finds nothing new on it, a first board after looks that failed included. A failed look posts nothing either, as the app's stale board doesn't.
- **After a failed look,** the panel keeps what it had shown, so the next good look posts each ask that landed meanwhile, once. The app starts a new run instead, and posts none of them; the panel's way tells you what you missed.
- **After the panel closes,** a look whose reads were still under way posts nothing, so no notification reaches your shell once the terminal is given back. Several new asks post oldest first, by the time each was posted, a tie in board order.
- **The words** are the app's banner's (`Notices.newAsk`): the ask's words, then `Project · Session`.
- **The sequence** is OSC 777, written whole between frames: `ESC ] 777 ; notify ; <ask> ; <Project · Session> BEL`, the ask's words as its title (Lee, 19 November 2026). It carries a title and a body, as the app's banner does, where OSC 9 carries one line. Each is a write of its own, after the look's frame. That rootshell shows it is Lee's to confirm in a live run.
- **Inside tmux** (`$TMUX` set), it goes in tmux's passthrough, `ESC P tmux; … ESC \` with each `ESC` doubled. tmux shows it only with `allow-passthrough on`, your setting.
- **Clean text.** Both fields are cleaned as the board's words are (`cleaned`): control characters dropped, C1's among them, and a line break run into a space. A `;` in either becomes `,`: it ends the title's field, and a parser that splits on every `;` would cut the body.
- **A long ask** is cut as a subject is (core's `shownText`): its title keeps 200 code points at most, the `…` among them, never cut inside a character. A 10 KB ask would make a 10 KB OSC, which some terminals drop.
- **Turning it off.** `--no-notify` turns notifications off for the run: `sitrep --no-notify` (Lee, 19 November 2026). The board is drawn as ever, the new ask's mark and wash among it.
- **While a command has the terminal,** the panel keeps posting: an ask in another session is the one you'd want to hear about (Lee, 19 November 2026). It posts while it draws `Too small` too.
- **Proven live** on 20 November 2026, in a pty on a scratch board: one OSC 777 for an ask added while the panel ran, its `;` made `,`, none for the first board, none inside a frame, and none with `--no-notify`. tmux's passthrough is held by the tests alone: no tmux was on the Mac the build ran on.

## Failure

- **A look that fails,** as an unreadable state folder: the watch passes over a file that doesn't read and ends on anything else. The panel never ends on a look (Lee, 19 November 2026):
  - **after a board,** it keeps the last board, with `as of 12:04` in grey at the key line's right end, as the app's menu does, until a look reads again. The keys are cut, whole hints from the right as ever, to the room left of it, two spaces kept before it, so the notice is never cut while `q quit` fits: at 39 columns, with no band, the line is `↑↓ pick  q quit           as of 12:04` (Lee, 20 November 2026);
  - **before any board,** the body reads `Looking for sessions…` in grey, once the first look has taken 300 ms, then `Can't read the board` in bold, a blank row, and the reason in grey wrapped at W−4, as the app's words go. Both are centred as the quiet board is. The view has no clock: the loop holds the first draw for the 300 ms.
- **A pick that can't open** says why in its answer (see "Picking a row") and changes nothing.
- **The panel itself failing:** it restores the terminal first, then prints `sitrep: <message>` to standard error and exits 1, as `main` does for any command.

## Next steps

Doesn't apply: the panel collects no remedies. A pick's answer says what to do in its own words.

## The close

`q` or `Ctrl-C` leaves the alternate screen, so the shell's screen comes back as it was. It prints nothing and exits 0.
- **SIGTERM** restores the terminal and exits 143.
- **During a hand-over,** SIGTERM and SIGHUP end the panel once the command it handed the terminal to ends, then it exits 143 or 129 (see "The hand-over").
- **SIGHUP,** as an SSH connection drops, tries to restore it and exits 129. A terminal gone without one (its input ended, or output failing) counts as a hang-up.
- **SIGINT and SIGQUIT** from outside restore it and exit 130 and 131. Ctrl-C typed in the panel is a key, and exits 0.
- **`Ctrl-Z`** restores the terminal and stops the panel. It takes the terminal back as the stop returns, the size read afresh, so a stop the kernel discards, as in an orphaned process group under `ssh -t host sitrep`, never leaves it stranded; the SIGCONT of its own stop then does nothing more. A SIGCONT after a stop from outside takes it back too.

## Colour

**The model.** The notch's colours over the terminal's own background: no canvas and no themes. The panel paints a ground only under the band and a new ask's wash, so your theme stays the ground everywhere else. It is colour.md's one-accent model, with the notch's two state colours, orange and blue, in place of an accent.

**The palette,** the inks round 4 was drawn and picked in:

| Use | 24-bit | 256 | 16 |
|---|---|---|---|
| An ask's mark and count | `#D77757` | 173 | yellow |
| Stopped's mark and count | `#7AA2F7` | 111 | blue |
| A working name, the status line, `✻` | `#A9B1D6` | 146 | default |
| Times, projects, counts, headings, key words, `◌` | `#7A82AB` | 103 | bright black |
| The rule and the chevron | `#565F89` | 60 | bright black, faint |
| Claude's pick | `#B1B9F9` | 147 | bright blue |
| Its `· Recommended` | `#9AA2EE` | 111 | blue, faint |
| An answer sending | the background on the terminal's foreground | the same | reverse video |
| The band | the background, one step toward `#3E4A5B` (`#343D4B` on Nordfox, `#282B30` on `#212121`) | the nearest (237 on Nordfox, 236 on `#212121`) | reverse video |

- **The terminal's ink:** names and the keys are in the terminal's own foreground, never a hex, so they read on any theme.
- **The level:**
  - `NO_COLOR` set: no colour at all.
  - `FORCE_COLOR` set: colour on, at least the level its value gives (`1` 16 colours, `2` 256, `3` or more 24-bit; `0` or `false`, none); a higher level the terminal says it has still wins, as chalk reads it.
  - `COLORTERM` of `truecolor` or `24bit`, in any case, or a `TERM` naming `ghostty` or ending `-direct`: 24-bit.
  - A `TERM` naming `256color`: 256 colours.
  - Otherwise: 16.

  Over SSH, `COLORTERM` usually stays behind, so rootshell likely draws in 256 colours: the nearest each, measured from the palette.

**Asking the terminal.** At start, in raw mode, the panel asks for the terminal's foreground and background (OSC 10, OSC 11), then device attributes (DA1), which every terminal answers. It waits for DA1's answer, up to a second. Answers that come after are read and dropped for a second more, never taken as keys. It asks only on a terminal, in the foreground.

**Mixes.** Four things are mixed from the background, so they need its colour:
- an away row's dimmed words, 0.61 of each ink;
- a Snoozed row's dimmed mark;
- a new ask's wash, orange at 22%;
- the band, the background moved one step, a set contrast, toward `#3E4A5B` (see "The band's step").

Dimming the terminal's own ink needs its foreground too. With both answers, at 256 colours or more, they're mixed. Without them, or at 16 colours, the dims are faint (SGR 2). On the band, a dim mixes toward the band's ground instead of the background, so a hollow row's words keep there the step they have off it. The wash is drawn at 24-bit only: at 256 colours it lands beside the band (on Nordfox the wash `#534345` is grey 238 and the band 237; on `#212121` the wash is 237 and the band 236), so an arriving row would look chosen; `◉` carries an arrival there, as at 16. The band needs only the background's answer: without it, the band is the step over a near-black `#212121`, `#282B30`.

**The band, quieter (Lee, 20 November 2026).** On his phone over SSH, on a near-black background, the fixed `#3E4A5B` band was too strong to read a hollow row's grey project on: "the background highlight needs to be made a little more transparent. It is very difficult to see the project name [...] when it's dimmed. When the orange circle is empty, the text is slightly more dimmed, which I think is appropriate. But then when you hover it, that level is too much. It needs to be brought right back. Make it as dim as we can get it, because it's still going to be obvious. Maybe a touch higher." So the band moved most of the way back to the background: 20% toward `#3E4A5B` was the faintest step that still read as a chosen row on `#212121`, and 25% is the touch above it. The dims off the band stayed as they were.

**The band's step.** A fixed fraction reads differently on each ground: 25% is barely there on Nordfox and nothing on `#3B4252`. So the band holds a contrast step instead, the 1.13 : 1 that 25% toward `#3E4A5B` makes on `#212121`:
1. The background moves toward `#3E4A5B` by the least amount, in hundredths, that reaches the step, so the band keeps its cool tint.
2. If `#3E4A5B` can't reach it, because the ground is close to it or lighter, the background moves toward the terminal's foreground instead, or white without that answer.
3. No band stands off its ground by more than `#3E4A5B` does off `#212121`, 1.79 : 1, the band before.

| Ground | Moved toward | By | Band |
|---|---|---|---|
| `#212121` | `#3E4A5B` | 25% | `#282B30` |
| Nordfox `#2E3440` | `#3E4A5B` | 39% | `#343D4B` |
| `#3B4252` | its foreground `#D8DEE9` | 6% | `#444B5B` |
| `#4A4A4A` | its foreground `#E0E0E0` | 5% | `#525252` |

A light background draws in reverse video, as at 16.

**Bold and faint.** Bold marks what needs you: an ask's name, the needs-you counts, the keys, `!` and `◉`. Faint (SGR 2) is used only without colour or at 16, for metadata.

**Contrast,** measured on Nordfox's `#2E3440`, the background the frames are drawn on:
- **The palette:** soft 5.9 : 1, blue 5.0, orange 4.0, grey 3.3, the rule 2.0.
- **On the band:** soft 5.2 : 1, grey 2.9, a hollow row's dimmed grey 2.0 (2.1 off it); on `#212121`, soft 6.7, grey 3.8, dimmed grey 2.3 (2.5 off it).
- **Lee's call.** These are the frames Lee picked; they clear the floor for marks (3 : 1), not every word the text floor (4.5 : 1).
- **A light background:** the palette is drawn for dark ones. Where OSC 11 or `COLORFGBG` says the background is light, the panel draws with the terminal's own 16 colours, as the 16 column above, until a light set is drawn in Paper and picked (Lee, 19 November 2026).

## Width

**Each part's least and natural width:**

| Part | Natural | Least, and below it |
|---|---|---|
| A row's words: the name with its count, or the status line | its own width | 12 cells while the project gives way, then 6, the `…` among them; the count is never cut |
| The time | its own width | a Snoozed wake drops its clock (`tomorrow`) where the words would get under 12 and dropping it narrows the section's lane; then the times go |
| The project | its own width | cut with `…` once the words are down to 12 cells, to 4 cells; below that it goes |
| An ask's title, an answer | wraps at W−2 | an answer to two lines, the second cut with `…` |
| The heading's rule | out to W−4 | 3 cells; below that it goes, the counts and the chevron kept |
| The key line | every hint | whole hints drop from the right |
| A pick's answer | wraps at W−4 | wraps; cut with `…` only where it is taller than the rows above the key line |

**What gives way first,** as the width falls: the words are cut, down to 12 cells; then the project is cut, then goes; then a Snoozed wake loses its clock; then the words are cut to 6; then the time goes. At 39 columns, Lee's narrowest, the words of most rows are cut, the projects of Snoozed rows too (`Onboarding…   Cont…  tomorrow 09:00`). Below 24 columns the panel draws `Too small`.

**Wide terminals.** Past 120 columns the layout stays 120 and stands at the left. The rows don't change form with width: one line at every width, as round 5 drew at 114 and 173.

**Cutting.** A name is cut from its end with one `…`, only below its natural width, with no space left before the `…` (`Thread…`, never `Thread …`). Nothing is cut that a wider terminal would show whole, and nothing cut can't be read by widening the terminal.

**Shown text made harmless.** Every word from the board is collapsed to one line, as core's `oneLine` does, before it's measured: once, by the view's `cleaned`, so the renderer cleans nothing. C0 and C1 controls, `ESC` and `DEL` are dropped from it, so a session's name can't move the cursor or set a colour.

**Cell widths.** A cell's width is its grapheme's:
- East Asian Wide and Fullwidth characters, and emoji in emoji presentation, take two cells;
- a combining mark joins the cell before;
- a cut never splits a grapheme.

**Height.** It gives way in the order "The frame" gives. The least is 8 rows: a heading, `▲`, a row, `▼` and the key line, with rows to spare. A pick's answer takes its rows from the body.

## Per command

**`sitrep`, alone, on a terminal:** the panel.
- **When it opens:** standard input and output are both terminals, and `TERM` isn't `dumb`.
- **Its flags:** words that are all flags, each a dash and more, read as the panel's, so `sitrep --no-notify` opens it too. A word that isn't a flag is a command's name, as today, so `sitrep --no-notify watch` is no command `--no-notify`.
  - **A flag it doesn't take** answers as an unknown command does, before the terminal is touched: `sitrep --bogus` says `There is no command --bogus.`, exit 1, as it did before the panel took any.
  - **`--help` or `-h` among them** is the help, so `sitrep --no-notify --help` prints it. `sitrep --help park` is still `park`'s help.
  - **Off a terminal,** `sitrep --no-notify` answers as bare `sitrep` does off one: the help on standard error, exit 1.
- **Opening:** it asks the terminal's colours, enters the alternate screen, looks at the board and draws it.
- **Running:** it redraws as the board changes, as keys move the band, as the terminal resizes, and as the clock turns a minute or ends a wash.
- **Leaving:** see "The close".

**`sitrep` alone, off a terminal or on `TERM=dumb`:** the help on standard error, exit 1, as today.

**`sitrep help`, `--help`, `-h`:** the help, as today.

**Every other command,** `watch` among them: unchanged.

## Built on: the code as it is

- **Dispatch.** `cli/main.ts`'s `answer` takes the first word as a command's name. With none, on a terminal whose `TERM` isn't `dumb`, it opens the panel (`cli/panel/panel.ts`'s `panel`); off one, it prints `HELP` to standard error and returns `EXIT.refused`, 1. `help`, `--help` and `-h` print the help.
- **The looks.** `cli/looks.ts`'s `looking` looks at the board every second (`POLL_MS`) and hands each look to its caller, `cli/watch.ts`'s `watch` or the panel.
  - It reads by `boardReader` over `heldReads` (`cli/held.ts`) and `readBoard`/`readFolder` (`cli/files.ts`).
  - It keeps a `Clock` of the Mac's sleeps (`clockAt`), and looks again when core's `nextExpiry` says time alone changes the board.
  - It ends as its run does (`untilEnded`); the panel's run ends only as the panel closes.
  - Core's `feedOf` makes the `Feed`; `newRows` says what's new. Each look's `Feed` is all the panel draws from.
- **The rows.** `core/rows.ts`'s `rowOf` and `snoozedRowOf` make the rows, and core's `inPanelOrder` and `inSnoozedOrder` order them. `core/panel.ts`'s `panelSections` puts them in the panel's sections, with their counts.
- **The words.** `cli/panel/view.ts`'s `viewOf` words each row: its time and a wake's countdown through core's `ago` and `inUnits` (`core/ago.ts`), rounded down as the app's `Age` words it, the pane's too; core's `wakeWords` and `oneLine`.
- **Where a window is.** Each live window comes as a `FeedWindow`: its writer, session, `where`, `directory`, `state` and `jumpOrder`.
  - `where` is `core/where.ts`'s `Where`: `device`, `terminal`, `tmux` with its `socket` and `pane`, and `zmx` with its `session`.
  - The mod records it once a process (`hooks/where.ts`'s `whereNow`): the socket is `$TMUX` up to its first comma, the pane `$TMUX_PANE`, the zmx session `$ZMX_SESSION` whole, and the device by `TTY_WALK`.
  - Core's `inJumpOrder` gives each window its `jumpOrder`; a window with no `where` has none.
- **Resuming.** A session no live window holds carries `lastWindow` (`core/windows.ts`'s `lastWindowOf`): its writer (`{claude}`), `where`, `directory` (`{dir}`) and `ownsDevice`.
  - SitRep resumes a session in Swift (`SitRepScreen/Jump.swift`'s `carryOn` and `resume`). It fills the command by `ResumeCommand` and `ResumeFacts`, reads and quotes it by `TypedCommand`, and keeps its default in `OpenSettings.defaultResumeCommand`.
  - The panel resumes one in TypeScript, by the same rules: `cli/panel/reach.ts`'s `reachOf` and `carriedOn`, `cli/panel/command.ts`'s `typedOf` and `filledOf`, `TypedCommand`'s twin, and `cli/panel/edge.ts`, which reads the saved command (`cli/panel/plist.ts`), asks `ps` and hands the line over. The two readers are held to one file of cases (see "Testing").
  - The command is saved in SitRep's defaults, under `app`'s `resume` key (`SitRepMenu/AppSettings.swift`). It is the one command SitRep registers for opening a session: `AppSettings` passes over an `openCommand` still saved, and no `OpenCommand` is left in `app/Sources`.
- **Who views each session.** SitRep reads it (`SitRepScreen/HereWatch.swift`, `Here.swift`, `Viewer.swift`) and writes what it read to `here.json`, at the top of sitrep's folder beside `snooze.json` (core's `HERE_FILE`; `SitRepScreen/HereFile.swift`):
  - **A viewer:** every client showing a session, a multiplexer's client or the processes holding Claude's terminal in none, gives one. `mac`, where the client is seated in a terminal app on this Mac (`Processes.seat`), as the notch's here is told. `ssh:<address>`, where the nearest remote login above it is an SSH login: OpenSSH's `sshd` or `sshd-session`, or `tsshd`, trzsz-ssh's UDP server, which rootshell's tssh starts through an SSH login and which runs apart under launchd (live, 20 November 2026: Lee's phone reaches the Mac this way, through no `sshd`). The address is the first field of `SSH_CONNECTION` in the client's own environment, read through `KERN_PROCARGS2` (`parseSSHAddress`), so every tab one phone opens counts as that phone. macOS hides its own programs' environments from other processes, a login shell's among them, so a client whose own gives no address takes the first another process on its tty gives. Anything else, mosh among it, gives none. The nearest remote login above a client decides: mosh started from an SSH login's shell gives none, and an SSH login started from mosh's shell gives its own client's address.
  - **Privacy:** `SSH_CONNECTION` is the one variable read from another process's environment, matched by its bytes; nothing else of it is made text, kept, logged or written. Only the first field is kept, and only where its bytes are an IPv4 or IPv6 address, checked by `inet_pton` before any of it is made text, and no longer than an IPv6 address and a zone's name. Only these environments are read: those of the clients an SSH login reached; and, for such a client whose own gives none, those of the processes on its tty, one at a time in order of process id, stopping at the first that gives an address. A click's read of here reads none (see "A tty's viewers").
  - **A session's viewers** are those of every client showing any of its windows: in zmx, each `zmx attach <session>` client; in tmux, each client showing the pane's tmux window or attached to a tmux session holding it, where a select would show it; in no multiplexer, the processes on its device whose parent is on another. A read that can't answer keeps the last answer, as `.unknown` does; `mac` among a session's viewers wins over a window unknown, as here does.
  - **A tty's viewers,** for the panel to find its own: the tty of each process a zmx session's server started, the session's own, maps to the viewers of that session's clients, a session holding no Claude among them. The servers are told by their command lines, `zmx attach <session>` on no tty, which the read for `here.json` reads beside the clients' (`tellsTtysBy`). Neither the jump's read nor a click's read of here does: a click asks only whether this Mac's screen shows the session (`HereReader.read(_ windows:)`), so it reads the seats alone, no multiplexer tty and no environment. In tmux, each pane's tty maps to the viewers of the clients showing it, on the servers a window on the board runs under, which alone tmux is asked of. A tty with no viewer, detached or reached only through mosh, is left out.
  - **The file:** `{"at":1763650000123,"sessions":{"sr-ct0002":["ssh:192.0.2.7"],"sr-nw0001":["mac","ssh:192.0.2.7"]},"ttys":{"/dev/ttys004":["ssh:192.0.2.7"]},"v":2}`, compact, its keys sorted, its slashes as they are: `at`, when SitRep wrote it, in milliseconds since the epoch; `sessions`, each held session read, by its id, with its viewers in order, none for one open nowhere; `ttys`, each multiplexer tty with a viewer, by its device; `v`, the format's version, 2. A tty is named as the app names a process's from the kernel's `e_tdev`, `/dev/ttys004` for major 16 minor 4 (`device(of:)`), and the panel names its own from Bun's `fstatSync(0).rdev` by the same rule (core's `ttyOf`); `tests/here.ts` holds both to one table of numbers. Version 1, `notHere`, reads as each session it named seen by nobody.
  - **When SitRep writes it:** at once as what it says changes, and otherwise at most every 10 seconds (`HereFile.refresh`) while any held session is read, so `at` stays fresh: that is SitRep's heartbeat. `HereWatch.settled` tells each settling, changed or not: at each read, every 3 seconds (`HereWatch.every`), and at each board line, which can drop a session no window holds with no read. With no session read, as with nothing held, the file is removed, once. So a Mac with sessions held writes 8,640 times a day at most beside each change, against 28,800 had it written at every read. This replaces writing only while something is dimmed: the panel over SSH needs the file whenever sessions are held.
  - **How it writes:** each write is whole, the bytes beside the file then renamed over it, and every write and removal runs on a queue of its own, off the main thread, in turn. A write that fails is tried again at the next settling, changed or not; the first of a run of failures is logged, and no other until a write succeeds. It writes only into the folder as the board made it. SitRep removes the file as it quits, waiting a second at most, so a write hung on its volume never holds quitting up.
  - **The notch is unchanged:** its dimmed are the held sessions whose viewers hold no `mac` (`Sightings.notHere`), and a session never read is here.
  - **What the panel makes of it:** core's `sightingsOf` reads it, and says nothing for a file missing, unreadable, of another shape or a later version, or 30 seconds or more from the moment it is read, either way (`HERE_STALE_MS`). Its own viewers (core's `lookingFrom`) are its own tty's, where the file lists any, as inside zmx or tmux, whose `SSH_CONNECTION` is stale from wherever the session was made; else `ssh:` and the first field of its own `SSH_CONNECTION`; else `mac`. A held session is dimmed where its viewers share none with the panel's (core's `notHereOf`). So with SitRep quit or never started every held session draws filled at the next look, as does one the file doesn't name; with SitRep crashed, hung or napped, within 30 seconds. The limit is long for SitRep's 10 seconds because only those three cases reach it: SitRep runs in the background with no activity held against App Nap, so macOS may stretch its sleep well past 10 seconds, and a shorter limit would blink every dimmed row filled in every panel. A session it names that no live window holds is away by core's own rule already, and `panelSections` leaves such a row as it is, so nothing counts it twice.
  - **What a read costs:** the table's look reads the command line of each zmx server too, and the environment of each client an SSH login reached, all through one buffer for the read. Over this Mac's 1,317 processes and 25 zmx sessions, 6 of them attached from the phone, a debug build's read took 28ms against 23.5ms before, its table 11.8ms against 9.8ms, the command lines' parse stopping at the arguments (20 November 2026).
  - **Who else reads the folder:** nothing else lists its top but the mod's snooze read, which takes `snooze.json` by its name, as the panel's look does for its snooze menu. The board reads `projects/` alone. So `here.json`, and the temp file a write leaves beside it for a moment, are passed over.
- **Whether a Claude is alive or suspended** on a device: SitRep reads it from its process table (`Jump.claude(on:)`), the panel from `ps` (`cli/panel/edge.ts`'s `claudeOn`).
- **The world.** `cli/io.ts`'s `Io` gives the file system, the environment, the clocks, standard input, output and error, the run's end, and the terminal, absent off one. It appends only as the CLI's commands do, a snooze or a wake by the code `sitrep snooze` and `sitrep wake` run (`cli/acts.ts`). It runs a program only through the terminal, for a pick: `hand` gives the terminal to the login shell, and `run` asks `ps`. `cli/shell/index.ts` binds it to Bun, and `cli/shell/terminal.ts` the terminal, their runtime declared in `cli/shell/runtime.d.ts`.
- **The frames.** `cli/frames/check.ts`, run by Bun, holds each fixture to its golden frame in `tests/frames/` and runs the sweep (see "Testing").

## What the code can't give yet

Nothing in this repo. `sitrep` on a shell's PATH lands with the tap's PR (slice 9): Claude Code puts the plugin's `bin` on Claude's own PATH alone, so the cask in `leeovery/homebrew-tools` gains `binary "#{appdir}/SitRep.app/Contents/Resources/Plugin/bin/sitrep"`, linking the compiled CLI the bundle carries, which needs no Bun, into Homebrew's `bin`. The tap's `update-formula.yml` rewrites only the cask's `version` and `sha256` lines, so the stanza survives every release.

## The output seam

The panel is pure functions from the board to lines at a size, a pure state machine for the keys, and a thin shell that owns the terminal, as `cli/shell` owns Bun today.

```ts
// core/panel.ts: the board's rule, as the app's Sections.swift states it in Swift
export type PanelSection = {
  kind: 'needsYou' | 'working' | 'snoozed'
  rows: (Row | SnoozedRow)[]
  counts: { value: number; need?: 'ask' | 'turn' }[]
}
export const panelSections: (feed: Feed, notHere: ReadonlySet<string>) => PanelSection[]

// cli/panel/view.ts: the board in the panel's words, at `now`
export type PanelRow = {
  session: string
  mark: 'ask' | 'turn' | 'working' | 'onItsWork'
  isAway: boolean
  isSnoozed: boolean
  isNew: boolean
  name: string
  count?: number
  project: string
  status: StatusWords
  lines: StatusWords[] // each line's words, the status line first, for the row expanded
  time: string
}
export type PanelView = {
  sections: { kind: PanelSection['kind']; counts: PanelSection['counts']; rows: PanelRow[]; isOpen: boolean }[]
  band?: string // a row key, rowKey's: the session's id, or snoozed:<id> for its Snoozed row, as Swift's markID
  expanded?: string // the band's row key while it is expanded
  top: number // the first row in view, counted over the open sections' rows, one a row
  answer?: string
  board: 'looking' | 'read' | 'stale'
  asOf?: string // `12:04`, while the board is stale
  reason?: string // why the board can't be read, before any board
}
export type StatusWords = { text: string; more?: number } // the status line joined; a question's +2
export const rowKey: (row: PanelRow) => string
export const viewOf: (feed: Feed | undefined, state: ViewState, now: number, notHere: ReadonlySet<string>) => PanelView

// cli/panel/state.ts: the keys and the board, with no terminal.
// PanelState carries ViewState (the band, top, Snoozed's fold, the answer, the board's state,
// when it was read and why it can't be, and each new line's first-shown time), so it passes
// straight to viewOf. It stamps a line's time at every news, a woken ask included, and drops
// those older than two seconds.
export type PanelEvent =
  | { board: Feed; news: string[]; now: number } // now: the look's own time, which stamps the arrivals
  | { failed: string; now: number } // a look that failed, and when: the board kept, stale, the menu's clock moved on
  | { key: Key }
  | { size: Size }
  | { tick: number }
  | { opened: string | undefined } // a pick done: the answer it leaves, if any
  | { written: string | undefined } // a snooze or a wake written: why it failed, if it did
  | { notHere: ReadonlySet<string> } // the sessions dimmed by here.json, where they differ from the state's
  | { snoozeSettings: SnoozeSettings } // snooze.json as the look read it
export type Write =
  | { command: 'snooze'; session: string; asks: readonly string[]; until?: number } // the asks the row showed; no until, until it moves
  | { command: 'wake'; session: string }
export const step: (state: PanelState, event: PanelEvent) => { state: PanelState; open?: string; write?: Write }

// cli/panel/menu.ts: the snooze menu's choices as the notch's menu offers and words them
export type SnoozeOption = { title: string; time: string; until?: number } // no until, Until it moves
export type Menu = { row: string; session: string; asks: readonly string[]; options: readonly SnoozeOption[]; at: number; top: number } // at: the pick; top: the first drawn, as the layout last kept it
export const snoozeOptions: (now: number, settings: SnoozeSettings) => SnoozeOption[]

// cli/panel/writes.ts and cli/acts.ts: a write as `sitrep snooze` or `sitrep wake` makes it
export const wordsOf: (write: Write) => string[] // --until <ms>, --session <id>, -- and the asks; or --session <id>
export const actOnWords: (io: Io, command: SessionCommand, words: readonly string[]) => Promise<Acted>

// core/here.ts: here.json's text as the panel reads it
export type Viewers = ReadonlySet<string> // 'mac', 'ssh:<address>'
export type Sightings = { sessions: ReadonlyMap<string, Viewers>; ttys: ReadonlyMap<string, Viewers> }
export type Lookout = { tty?: string; sshConnection?: string } // the panel's own tty and SSH_CONNECTION
export const HERE_STALE_MS = 30_000 // three of SitRep's 10 seconds: it matters only for a SitRep crashed, hung or napped
export const sightingsOf: (text: string | undefined, now: number) => Sightings | undefined // nothing for a file missing, torn, misshapen or stale
export const lookingFrom: (sightings: Sightings | undefined, lookout: Lookout) => Viewers // its tty's, else its SSH_CONNECTION's, else 'mac'
export const notHereOf: (text: string | undefined, now: number, lookout: Lookout) => ReadonlySet<string> // the held sessions sharing no viewer with the panel
export const ttyOf: (rdev: number) => string | undefined // '/dev/ttys004' for major 16, minor 4, as the app's device(of:)

// cli/panel/layout.ts: the fit rules, once, for draw and for step
// (keeping the band whole, paging, a tap's row)
export const layoutOf: (view: PanelView, size: Size) => Layout // the body, the answer, top clamped, lastTop, each visible row's key, y and height
export const topFor: (view: PanelView, size: Size, key: string) => number | undefined // the top nearest view.top showing the row whole

// cli/panel/expand.ts: the chosen row expanded, its lines counted by the layout and drawn by draw.ts
export type Expanded = { time: string; lines: Tagged<Tag>[][] } // Tag: 'name' | 'meta' | 'status'
export const expandedOf: (row: PanelRow, width: number) => Expanded

// cli/panel/draw.ts: lines at a size; no clock, no terminal
export type Run = { text: string; pen: Pen }
export type Line = Run[]
export const draw: (view: PanelView, size: Size, paint: Paint) => Line[]
export const ansi: (lines: Line[], level: Level) => string
export const text: (lines: Line[]) => string

// cli/panel/reach.ts: what `o` opens, decided from the feed alone
export type Resume = { name: string; claude: string; dir?: string; device?: string; isHeld: boolean; ownsDevice: boolean }
export type Reach = { resume: Resume } | { answer: string }
export const reachOf: (session: string, feed: Feed) => Reach

// cli/panel/command.ts: TypedCommand's rules in TypeScript; no terminal, no shell
export const lineOf: (command: string, facts: ResumeFacts, name: string) => Checked<string>

// cli/panel/notices.ts: what a look's news posts, as Notices.swift's newAsks and newAsk keep it
export type Notice = { title: string; place: string } // the ask's words; Project · Session
export const newAsks: (feed: Feed, news: readonly string[]) => Notice[] // asks only, oldest first
export const osc777: (notice: Notice) => string // its fields cleaned, each ; made ,, the title cut to 200
export const passedThrough: (sequence: string) => string // in tmux's passthrough, each ESC doubled
export const noticesOf: (feed: Feed, news: readonly string[], env: { TMUX?: string }) => string[] // a write each
```

**`Paint`** is what the terminal said: the colour level, and its foreground and background where it answered. **`Key`** is decoded from bytes by `cli/panel/keys.ts`'s `keysOf`. `step` returns `open` with a session's id when `o` asks for one, and the loop answers with `opened`.

**The shell's half.** `Io` gains `terminal`, absent off a terminal, bound to Bun in `cli/shell/terminal.ts`:

```ts
export type Terminal = {
  size: () => Size | undefined
  device: () => string | undefined
  onResize: (heard: () => void) => () => void
  keys: (heard: (bytes: string) => void) => () => void
  write: (text: string) => void
  ask: (query: string) => Promise<string>
  hand: (argv: readonly string[]) => Promise<number>
  run: (argv: readonly string[], ms: number) => Promise<{ exit: number; out: string; err: string }>
  onSignal: (signal: 'SIGHUP' | 'SIGTERM' | 'SIGINT' | 'SIGQUIT' | 'SIGCONT', heard: () => void) => () => void
  suspend: () => void
}
```

- **`device`** is standard input's tty, `fstatSync(0).rdev` named by core's `ttyOf`, for the panel to find itself in `here.json`.
- **`keys`** turns raw mode on while it listens.
- **`ask`** writes the OSC 10, OSC 11 and DA1 queries and gives what came back before DA1's answer.
- **`hand`** gives the terminal to a program until it ends, as "The hand-over" says.
- **`run`** runs a program within a limit: `ps` alone.

The fakes in `tests/` stand in for all of it.

**The loop.** `cli/panel/panel.ts`'s `panel(io, terminal, { isNotifying })`, `isNotifying` false for `--no-notify`:
1. Asks the colours and enters the screen.
2. Starts `looking` (`cli/looks.ts`), the watch's loop, which hands it each look's `Feed`, the next look waiting on the panel's handling of it.
3. At every look, the board changed, unchanged or failed, reads `here.json` by `Io`'s file system and core's `notHereOf`, aged from the moment of the read, from where the panel is looked at: its `Lookout`, its terminal's `device` and its own `SSH_CONNECTION` (`Env` gains it), read once as it opens. It steps the state with `{ notHere }` first where the set differs, so an unchanged board, or one that can't be read, redraws with its new fill. `looking` waits on `seen` and on `isPastFailure` alike, so the reads stay in order. `panelSections` and `viewOf` stay pure: the read is the loop's.
4. Steps the state on every event, draws, and writes only the rows that changed, inside synchronized output (`CSI ?2026h` … `CSI ?2026l`).
5. Writes each of a look's `noticesOf`, a write each after its frame, where it notifies; `Env` gains `TMUX` for them.
6. Opens what `step` asks for through `cli/panel/edge.ts`, the CLI's one edge: it reads SitRep's saved resume command, asks `ps` about the window's device, and hands the filled line to your login shell. It runs nothing else.

**What goes.** Nothing: the watch prints as before, from `looking`.

## Testing

**Under `claude plugin test`,** in `tests/`, with the CLI's memory world (`tests/terminal.ts`) and a fake terminal:
- **`panel-sections.test.ts`:** Needs you's order, here and away, asks then Stopped; Working's and Snoozed's order; every count; a session in Snoozed beside its working row.
- **`panel-view.test.ts`:**
  - the words: the status joins, `+2`, `Wakes in 12m`, the times as `ago` and `wakeWords` give them;
  - the marks, here and away; `isNew` for two seconds;
  - control characters dropped.
- **`panel-draw.test.ts`:**
  - each element drawn at widths 24, 39, 69, 73, 114 and 173, colour off, its lines inline;
  - each pen's exact escape codes at 24-bit, 256 and 16 colours, and none at all with `NO_COLOR`;
  - the mixes with and without the terminal's answers;
  - the chosen row expanded: its name and line two wrapped, a row of several lines its project alone then each line's words, the band over every line, and one taller than the body cut, its last line `…`;
  - the snooze menu's choices after their numbers in grey, the first nine alone numbered, the words of any past them in line, a name cut and never its number;
  - a row on one line in each state, its words as the notch's, the projects right-aligned in a column, the time's lane a section's widest, and the cuts in their order down to 24 columns; the arrow on the band's row with asks, and on no other;
  - a row's asks: the head, the title wrapped, the age and its dots, the answers numbered, wrapped to two lines and cut, Claude's pick in lilac with its tag on its line or its own, a yes, a words ask, the foot with and without Snooze; an answer held, white with its check, and the sending line; each given way as "Short of room" says;
  - `Too small` below 24×8.
- **`panel-keys.test.ts`:** byte sequences to keys, a lone `esc` by its 50 ms, `CSI` and `SS3` arrows; `1` to `9` with their numbers, `0` nothing; a sequence cut short past the 50 ms read whole once its rest comes, its key thrown away, an X10 report, a paste's start and a colour answer cut twice among them.
- **`panel-state.test.ts`:** the band's first press, moves, pages and ends; the view's scroll; the band following its session and passing on; folding; expanding and folding a row, one at most, folded as the band moves, kept whole in sight, a tap on any of its lines landing on it; `o` alone asking to open, never `⏎` or a tap; answers dropped on a key; the sessions SitRep's file dims moving behind those drawn filled, the band on its session.
- **`panel-snooze.test.ts`,** in London at a fixed clock: the menu's choices and their words under the defaults, under a `snooze.json`, and after Tonight's time; `↑↓` within the first and the last, the menu scrolled at 39×8 with seven choices so the seventh is reached, drawn and made, and an answer landing while it is open keeping the pick drawn; ⏎ and a tap on a drawn choice asking for the snooze, naming the asks the row showed, with no time for Until it moves; a digit making the choice of its number as ⏎ on it would, scrolled out of sight or not, one past the choices and one with no menu doing nothing; neither ⏎ nor a digit choosing while the menu is drawn on no line; a turn alone naming none; `esc`, `z` and a tap elsewhere closing it, writing nothing; every other key doing nothing; `z` waking a Snoozed row, and refused in words on a prompt alone and a working row; the menu closed as a board passes the band on, or leaves the row nothing to snooze, its asks kept as it opened; the choices worked out from a failed look's time; a second `z` on a Snoozed row writing nothing until a board comes; a failed write's answer; the menu and its row kept in sight, the row giving way first.
- **`panel-asks.test.ts`:** `⏎` and a tap opening a row's asks only on a row with one the view answers, a prompt alone expanding; the asks in the row's order; digits sending their answer, one past them nothing; `x`, `z` for the ask shown and `o`; `←` `→` paging, nothing wrapping; `⏎`, `esc`, `↑` `↓` and a tap elsewhere closing; the 300ms beat after a change the board made, none after paging; an answer held for two seconds, `u` and a tap on `undo` taking it back, digits and `x` doing nothing meanwhile, its going stepping to the next ask and closing after the last; an ask leaving, edited, and the row leaving Needs you; a digit past the answers drawn doing nothing when short of room.
- **`snooze.test.ts`:** core's `timeBeside`, the time alone or the weekday and time, as the app's menu words them.
- **`here.test.ts`:**
  - `sightingsOf` on the file as the app writes it (`tests/here.ts`, the text the Swift tests hold the app's encoder to); fresh up to 30 seconds either side of `at`, nothing from then; nothing for a file missing, torn, of a later version or none, or of the wrong shape; a version 1 file dimming what it named wherever the panel is;
  - `lookingFrom` by each path: its tty's viewers, whatever its `SSH_CONNECTION` says; a tty listed with none, or unlisted, its `SSH_CONNECTION`'s first field, an IPv6 one among them; else `mac`;
  - `notHereOf` over SSH from the phone, the iPad and an IPv6 address; Lee's case, open on the phone and detached on the Mac filled on the phone, inside zmx there or in a plain login, and open only in the Mac's Ghostty hollow there; on the Mac, the sessions whose viewers hold no `mac`, as the notch's;
  - `ttyOf` held to `tests/here.ts`'s table of numbers, which the Swift tests hold `device(of:)` to.
- **`looks.test.ts` and `offered.test.tsx`:** `here.json`, and a write's temp file, at the folder's top change no look, and the pane's snooze read still takes `snooze.json`.
- **`panel-reach.test.ts`:**
  - `reachOf`: every row of "Picking a row"'s table, a session gone from the board among them; the jump order; a session in Snoozed alone; `{claude}`, `{dir}`, the device and `ownsDevice` from a live window and from a last window;
  - `carriedOn`: suspended and no answer from `ps` refusing whatever the command; the guard's words, the default saved with spaces round it among them, against a command you wrote, and `{tty}` filled only for a Claude running on its own device; a later conversation's Claude refusing nothing; no folder in the window's words.
- **`panel-edge.test.ts`:**
  - the property list reader: the data under a key, long and in UTF-16; a list cut short, claiming more than it holds, or with offsets of no bytes, holding nothing;
  - the saved command: `resume`, empty where cleared, else the older `resumeCommand`, else the default, from the home folder's defaults;
  - `ps`: the system's, asked of the device alone within its time; a Claude Code told by its program, stopped by its state; a device gone or none asking nothing; a failure as no answer;
  - the line handed to `$SHELL -l -c`; a command's refusals before `ps` is asked; a POSIX login shell only; the quick failure's answer; a login shell that can't start.
- **`panel-command.test.ts`:** `lineOf` held to the cases `TypedCommand`'s Swift tests hold: quoting, plain syntax filled, every refusal in its words, and each command of `tests/refused-commands.ts`, the reviews' holes, refused, a list the Swift tests read too. A seeded run of commands made from the grammar's parts (`tests/commands.ts`) holds plain ones filled and ones with a part refused never taken. `tests/reader-cases.ts` holds 2,000 of them, most mutated, each with the line or the refusal the panel gave, made by `bun tests/make-reader-cases.ts > tests/reader-cases.ts`; both suites read it, so the two readers give the same for every one. The kit can't start a process, so the same commands filled with hostile values ran in sh, bash 3.2 and 5.3, zsh, dash and ksh in a scratch run, outside the suite.
- **`panel.test.ts`,** golden runs through the fake terminal:
  - the exact writes to enter, draw, hand over, take back and leave;
  - `q` exits 0, SIGTERM 143, SIGHUP 129;
  - SIGINT ignored while a program has the terminal;
  - the fill: a fresh `here.json` naming a held session seen by nobody draws it hollow and dimmed at the next look on an unchanged board, and the first board with it; the file stale, or gone, fills it again, a failing look among them; a file naming no session on the board, or none, writes nothing more; over SSH, a session open on the phone filled and one open only on the Mac hollow, and on the Mac the other way round; inside a multiplexer session, the panel's own tty's viewers, and its stale `SSH_CONNECTION` once its tty is unlisted;
  - the keys over time: a mouse report cut by the 50 ms gap read whole once its rest comes, its digits choosing nothing in the snooze menu, the `1` after it choosing In an hour; a sequence a stop from outside cut short never read with the first key after the SIGCONT;
  - answering: a digit's answer, after its two seconds, writing the very text `sitrep answer` writes in a twin world, `--wants` with it, a yes, a choice and an ignore; `u` writing nothing; `q` while held writing it at once before leaving; a reshaped ask refused in the answer line; the one-ask snooze writing `sitrep snooze --ask`'s line;
  - the writes: `z` and ⏎ writing the very text `sitrep snooze` writes in a twin world, for a row of asks and for a turn alone, In an hour from the test's clock; `z` on a Snoozed row writing `sitrep wake`'s; a snooze refused, an ask landed since the menu opened, said above the key line, nothing written;
  - notifications: one OSC each for new asks only, oldest first, in one look and across two, none on the first board, none with the flag, wrapped inside tmux, posted during a hand-over and while `Too small`, never inside a frame's write, none after the panel closes, once after a failed look and none on a first board after one, the text cleaned.
- **`panel-notices.test.ts`:** `newAsks`' kinds, order and words, an away row's place; `osc777`'s bytes, cleaning and cut; tmux's wrapping.
- **`cli.test.ts`:** bare `sitrep` off a terminal keeps its help and exit 1; the help's new line, every other line as it was; the flags read as the panel's, an unknown one as an unknown command, and `--no-notify` off a terminal; every command's tests pass unchanged.

**In Swift,** `swift test`:
- `HereFileTests`: the file's place as `rootOf` gives it; its text byte for byte as `tests/here.ts` holds it; a tty named as `tests/here.ts`'s table of numbers says; a write whole, nothing left beside it; a failure making nothing, tried again at the next settling, and a run of failures logged once; posted reads written in turn, the queue drained before the file is read; a change written at once, the same again only 10 seconds on, either way of the clock; a settling with no session read removing the file once; the removal after every write posted before it, and the removal at quit returning at its limit behind a hung write.
- `HereWatchTests`: each settling told, at each read and at a line that drops a session; each session's viewers as last read, unknown keeping them, and each read's ttys, kept where its table gave none; the notch's dimmed, the sessions read whose viewers hold no `mac`; and `writes(to:)`, the seam `Works` calls, keeping the file in step: written at the first read, not again within 10 seconds, removed as a line drops the session, written while sessions are held though none is dimmed.
- `ViewerTests`, with `HereReader`'s fake process table: a client's viewer from a terminal app, from `sshd` and from `tsshd` with an address, and from neither, mosh among it; a client whose environment holds no `SSH_CONNECTION`; only the environments of clients an SSH login reached read; every tab of one device as one viewer; the nearest remote login deciding, mosh started from an SSH login's shell and an SSH login from mosh's; a window in no multiplexer, a login shell's hidden environment read through the first process on its tty that gives an address, in order of process id, none read after it, all through one reader; a tmux pane's clients; a session's viewers from its windows'; the notch's here as `mac` among them, Lee's case among it; each zmx session's tty, one holding no Claude among them, and each tmux pane's; no table, no ttys.
- `KernelProcessesTests`: `parseSSHAddress` giving the first field of `SSH_CONNECTION` alone, IPv4, IPv6 and a zone, and nothing for a variable unset, empty, not an address, a token in its place, longer than any address, a zone not of letters and digits, a name only starting the same, an argument, past the environment's end, or a value cut short; `parseProcArgs` keeping an empty argument, the first among them, the path's padding skipped by its length, and nothing for bytes cut inside it; and on this Mac, a process's address from its own environment, none for one holding none, nor for macOS's own program, whose environment it hides.
- `HereTests`: whether a session is here, as before, each answer now `Sighting.here`; and a click's read reading no environment and no zmx server's command line, where the read for `here.json` reads both.
- `DefaultsScanTests`: no test reaching the live `HereFile`.

`Works` and `AppDelegate` have no test: `Works` builds the live jump and the live read, with no seam for a fake. The wiring is one line in `Works`, `here.writes(to: hereFile)`, and `hereFile` is a required argument of its `init`.

**Golden frames,** by the Bun checker `cli/frames/check.ts`, which the kit can't run:
- **The files:** each frame is a `.txt` and an `.ansi` in `tests/frames/`, named `panel-<screen>-<W>x<H>`.
- **The check:** each fixture is drawn and held to its frame cell for cell: glyph, foreground, background, bold, faint and reverse. The SGR reader refuses any escape it doesn't model. A failure names the first 20 differences, then how many more.
- **Writing them again:** `--update` writes the frames again and deletes those nothing draws; a kept frame nothing draws fails.
- **The checker's own tests:** its reader and comparer are pure TypeScript in `cli/frames/cells.ts`, tested under the kit with inline strings.
- **The fixtures** (`cli/frames/fixtures.ts`) are moments: a world, a size, the terminal's answers (Nordfox's `#CDCECF` on `#2E3440`), a fixed clock, and the keys pressed to reach them.
- **The screens:** round 4's, `rest`, `picked`, `unfolded`, `busy`, `arriving`, `unreachable`, `quiet`, `wide` and `nocolor`, at round 4's sizes. Added to them: `narrow-30x27`, `small-23x10`, `busy-24x8`, `docs-73x18`, the docs page's still, `expanded`, at 52×27 and 114×45: a row of a long name and three asks, expanded; `snoozing`, at the same sizes, the snooze menu open; and `waking`, at 52×27, a Snoozed row chosen, its key line naming `z wake` (20 November 2026). Round 5's screens join them (26 November 2026): every screen drawn again on one line, and `asks`, `words`, `yes`, `sending`, `prompt` and `busyasks`, at round 5's sizes.
- **The first goldens** are round 4's frames, with one change on purpose: the names and a pick's answer, which round 4 drew in Nordfox's `#CDCECF`, are in the terminal's own ink, as its title and keys already are.

**The sweep.** The checker draws every fixture at 39×27, 69×46, 73×36, 114×45, 173×53 and 73×15, and runs the four width checks from termgrid's `sweep`, ported:
- a name cut with room to spare;
- a fold with rows to spare;
- nothing drawn;
- a wasted third.

The quiet board is listed on purpose, as round 1 lists it: "All clear" and one short line, centred, have nothing to widen.

**Gates.** The slice that brings the checker adds `bun cli/frames/check.ts` and `bunx tsc -p cli/frames` to CLAUDE.md's gates. The root `tsconfig.json` excludes `cli/frames` as it does `cli/shell`.

**Live tests.** A live run points `XDG_STATE_HOME` at a folder of its own and seeds sessions there, as CLAUDE.md says. A `here.json` written by hand there stands in for SitRep, which writes only the folder its own environment names. Picking a row runs the resume command in the panel's own terminal and brings no window forward, so it is no jump.

**The viewers, live** (20 November 2026, Lee connected from his phone): over the real table, a scratch read gave each zmx client Portal attached in Ghostty `mac`, and each attached through tssh `ssh:` and the one address of the device it was attached from; 12 zmx ttys mapped, 6 to each. In a pty, with a hand-written version 2 file, the panel drew the phone's session filled and the Mac's hollow with the phone's `SSH_CONNECTION`, the other way round with none, and the phone's way with its own tty listed and a stale `SSH_CONNECTION`; Bun's `ttyOf(fstatSync(0).rdev)` named the pty as `ttyname` did.

## Pictures

- **The demo world** is round 1's: `REST`, `BUSY` and the arriving `Room bookings`, in `cli/frames/fixtures.ts`, all placeholder names.
- **No VHS tapes:** the golden frames and the live runs hold the panel.
- **The still** for the docs page, `docs/terminal.md`, is the golden frame `panel-docs-73x18`, drawn from the fixtures' docs world: only the six sessions and six projects the docs may name (CLAUDE.md, "Writing the docs"), with asks, a Stopped row, a hollow one, `✻`, `◌` and Snoozed folded. It is read by `termgrid.py`'s `read_ansi` and drawn as the rounds' previews are (`preview_page`, its title bar `sitrep`, Nordfox), shot by headless Chrome at 2× and made lossless webp by `cwebp`: `art/screens/terminal.webp`. Remake it after a change to that frame.
- **Later rounds** start from the build's frames read into termgrid, not from round 1's model of them. Round 5 is the exception: its rows change form, so it draws from round 1's model, as the build drew then, a blank top row and no title.
- **Round 5** is on the page "FINAL · one line, asks under the row · signed off 26 Nov 2026" of "SitRep · terminal look", first in the file: its READ ME, then the 39×27 frames at rest, the band on a row with asks, its asks open, a words ask, a yes ask, an answer sending, a prompt expanded and `NO_COLOR`; then the asks open at 69×46 and 114×45.

## Out of scope

- Typing a words ask's words, a comment, and Claude Code's own permission prompts and questions: a words ask opens its session, as the notch's Open in Claude does. Answering asks was out of scope until 26 November 2026, and snoozing and waking until 20 November 2026.
- Opening a session's own Ghostty window on the Mac, as the notch's jump does: the panel attaches in place everywhere.
- An ASCII fallback, colour settings, themes, and a `--no-color` flag: `NO_COLOR` covers it.
- Remembering the fold or the band between runs.
- `sitrep serve`, a phone app, or any reach beyond the Mac's own terminals.

## Known limits

- **Coming back after a pick is the command's.** A command that switches this terminal's client and ends leaves the panel running in a session this terminal no longer shows. A `zmx attach` your command runs inside another zmx session does just that (DESIGN.md, "The jump", records the limit).
- **A notification during a hand-over can garble the program's screen.** The panel and the program share the terminal, and macOS copies a write to a tty in 100-byte chunks, sleeping between them where it must. So a notification can land inside one of the program's escape sequences, or the program's bytes inside the notification, leaving stray characters until it repaints. It is rare and cosmetic, and the title's cut narrows it; holding notifications until the take-back would break the rule that the panel keeps posting meanwhile.
- **OSC 777 inside zmx** is not yet known to reach the terminal, nor rootshell to show it; both are left to Lee's live test after slice 9. The panel wraps it for tmux alone.
- **An update under a running panel.** The panel runs the code it started with until you quit it. The watch, by contrast, ends at a new version for SitRep to start again.
- **A resumed Claude lives in the panel's terminal.** A dropped SSH connection ends it, unless the resume command runs it in a multiplexer.
- **Ambiguous-width glyphs.** `●` `○` `◌` `◉` `✻` `─` `▿` `▹` `▲` `▼` are East Asian Ambiguous: a terminal set to draw them wide breaks the columns.
- **A Claude Code told by its name.** The panel tells a Claude Code on a window's device by `ps -o comm`, the process's argv[0], not the path of its program, which the app reads (proc_pidpath) and no `ps` keyword gives. A Claude Code started through a link of another name is not seen there: the default can then resume beside it, and `{tty}` stays empty. A program started as `claude` (`exec -a claude`) is counted as one: the default then refuses it as still running.
- **The fill can blink filled for one read,** about 3 seconds: on waking the Mac, the file is stale until SitRep's first read; and of two SitReps, the one quitting removes the file until the other's next read.
- **A device is its SSH login's address.** The address is the one the login came from, kept for its life: tsshd keeps the address it started with as the phone roams, so a device whose address changes counts as another until its tabs reconnect. Over Tailscale each device keeps one address. Two devices behind one address, as on a network that shares one, count as one.
- **Mosh, and what no SSH login reached, has no viewer.** A session attached only through mosh is open on no device SitRep can name, so it draws hollow everywhere, as on the notch; and a panel inside a multiplexer session reached only that way goes by its own `SSH_CONNECTION`, stale from wherever the session was made, or by the Mac's screen.
- **A panel looked at from two devices** draws filled what either has open: inside a zmx session attached from the phone and in Ghostty, it can't tell which one you are reading.
- **A multiplexer inside another** gives its clients no viewer: a tmux client run inside a zmx session descends from zmx's server, under launchd, as it reaches no terminal app for the notch. A tmux server no window on the board runs under is never asked, so a panel in one goes by its own `SSH_CONNECTION`, which tmux refreshes only for shells started after an attach.
- **A board a second old.** The panel looks every second, as the watch does, so a new ask's mark and its notification come up to a second late.
- **zsh's GLOB_SUBST.** With it set, an unquoted parameter or `$(…)` holding a value can run code: `x={dir}; echo $x`, its value `*(e:touch PWNED:)`, runs `touch` under `zsh -o globsubst`. So a command for such a shell puts them in double quotes, as `echo "$x"`. Refusing every unquoted parameter would still miss an unquoted `$(…)`, and would refuse `s=$(…)` with it. The panel's `-l -c` reads no `.zshrc`, but the app's interactive shell does.

## Open for Lee

Nothing is open: Lee answered every question on 19 November 2026.

### Answered

Every recommendation was accepted by Lee on 19 November 2026, with one correction, his own: the panel runs SitRep's resume command and never attaches a session itself. Lee: "It should never run zmx attach. We should be using the existing commands that are registered for this process." The correction raised one more question, 16, which he answered the same day. The answers, as the spec now holds them:

1. **Leaving a session the panel opened** is the command's: the panel takes the terminal back when the command ends. With a command attaching a zmx session in a plain shell, zmx's `Ctrl-\` detaches and ends it; a resumed Claude with no multiplexer ends when you quit it. Nothing of sitrep's own: a key of its own would mean relaying every byte through a pty the CLI holds.
2. **Picking from a panel inside zmx or tmux** is no longer a question, and was removed. It asked whether the panel should switch, nest or refuse an attach it made itself. The panel makes none: what your command does inside a multiplexer is your command's.
3. **Mouse and touch:** a tap puts the band on a row and a tap on the band's row opened it (since 20 November 2026 it expands the row, and `o` opens it); the wheel or a swipe scrolls; no hover (see "Keys").
4. **The flag:** `--no-notify`, read as `sitrep --no-notify`.
5. **The notification:** OSC 777, the ask's words as its title and `Project · Session` as its body, once Lee confirms rootshell shows it.
6. **While a command has the terminal,** the panel keeps posting notifications.
7. **A board that can't be read:** the last board kept, with `as of 12:04` in grey at the key line's right end (at the title's right until 20 November 2026); before any board, `Looking for sessions…`, then `Can't read the board` and the reason.
8. **Which sessions this Mac shows:** SitRep writes the sessions this Mac doesn't show as it reads them, for the panel to read; with SitRep not running, a held session draws filled. Widened by Lee on 20 November 2026: SitRep writes who views each session, and the panel dims what is open on no device it is looked at from (see "The marks").
9. **The resume command:** SitRep's setting, read from its saved settings, the default where none is saved.
10. **What the CLI runs,** narrowed by the correction: one edge module, `cli/panel/edge.ts`, for the pick alone. It runs your resume command through your login shell, and `ps -t <device>` for the living-Claude check and `{tty}`. It never runs zmx or tmux, nor anything else, and the app's jump keeps all of its own.
11. **Rows moving under the band:** rows take their new places at each look, the band staying on its session and in sight.
12. **The working mark:** a still `✻`.
13. **A light terminal:** the terminal's own 16 colours where the background is light, until a light set is drawn in Paper and picked.
14. **The help:** one usage line, `sitrep [--no-notify]`, saying it opens the board in this terminal.
15. **`sitrep` on a shell's PATH:** the cask, in its Homebrew tap, gains a `binary` stanza linking SitRep's CLI, `Contents/Resources/Plugin/bin/sitrep`, into Homebrew's `bin`.
16. **A session this Mac shows, picked from a panel on this Mac,** asked after the correction: run the command in the panel's terminal, or ask SitRep to jump to the window showing it, as the notch does. Lee chose the command, always, so the panel never jumps and never moves the Mac's screen: "As long as we always go through the command … It's generic enough that it's up to the user to handle their own scenarios through the registered commands." What becomes of the session's other window is the command's (see "Picking a row").

## Build

A PR a slice, in order. Slices 2 and 3 can run in parallel once 1 is in; 4 waits on both, and each slice after it on the one before. Each is reviewed before the next starts; 5 and 6 at the deepest review, for raw mode, the hand-over, the signals and the quoting of a line run by the shell.

1. **The looks apart from the watch.**
   - **Delivers:** `cli/looks.ts` takes the watch's loop (`boardReader`, the clock, the expiry, whole looks, the run's end), and `watch` prints from it. `ago` moves into core, and the pane imports it from there.
   - **Checked by:** every watch, feed and pane test passing unchanged, and a test of the loop handing each look's `Feed`.
2. **The panel's board.**
   - **Delivers:** `core/panel.ts`'s `panelSections`, with its order and counts, and `cli/panel/view.ts`'s `viewOf`, with words, times, marks and arrivals.
   - **Checked by:** `panel-sections` and `panel-view`.
3. **The renderer,** not wired in.
   - **Delivers:** cells and widths, cutting and cleaning text (`cells.ts`); colour levels, the palette, pens and mixes (`paint.ts`); every element, the band, the wash, the dims and `Too small` (`draw.ts`).
   - **Checked by:** `panel-draw`.
4. **The frames.**
   - **Delivers:** `cli/frames/` (fixtures from round 1's worlds, the SGR reader and comparer, the sweep, `check.ts --update`), and the first goldens in `tests/frames/` from round 4. CLAUDE.md gains the checker's gates.
   - **Checked by:** every golden drawn, the sweep clean but for the quiet board's listed third, and Lee's eye on `panel-rest-39x27` and `panel-busy-73x15` beside Paper's page.
5. **The panel, watching.**
   - **Delivers:** `Terminal` in `Io` and its Bun binding, `keysOf`, `step`, and `panel`. Also bare `sitrep`'s dispatch, the colour query, scrolling, folding, resizing, suspending, the signals and the restore. `⏎` isn't in the key line yet.
   - **Checked by:** `panel-keys`, `panel-state`, `panel` and `cli`. Then a live run on a seeded state folder in Ghostty at 73×36, and over SSH in rootshell at 39×27 and 69×46.
6. **Picking a row.**
   - **Delivers:** `reachOf`; `lineOf`, `TypedCommand`'s rules in TypeScript; the edge, reading SitRep's saved resume command and asking `ps`; the hand-over; and the answers.
   - **Checked by:** `panel-reach`, `panel-command` and the hand-over's golden runs. Then a live run on a seeded state folder: a held session in a zmx session with a placeholder name, opened by Lee's resume command and detached back to the panel; an away session resumed; and the default refusing a held one.
7. **Notifications.**
   - **Delivers:** the OSC on new asks, tmux's passthrough, and the flag.
   - **Checked by:** `panel`'s notification runs. Then live in Ghostty and in rootshell, with the panel in front and behind, inside tmux with passthrough, and inside zmx.
8. **The fill from SitRep.**
   - **Delivers:** SitRep writes the sessions this Mac doesn't show; the panel reads them.
   - **Checked by:** a Swift test of the write, a panel test of the read, and a live check beside the notch. One Swift build at a time.
9. **Reaching it, and its page.**
   - **Delivers:** the cask's `binary` stanza, a PR in the cask's tap; a feature page in `docs/`, measured; the glossary's new terms; the README's line; the still in `art/`.
   - **Checked by:** the docs' measure script, and `sitrep` typed in a fresh login shell over SSH.
10. **Hollow from where you look** (Lee, 20 November 2026).
   - **Delivers:** each client's viewer and each multiplexer tty's in the read of here; `here.json` version 2, written at once on a change and every 10 seconds while sessions are held; the panel's own viewers, by its tty and its `SSH_CONNECTION`; the notch unchanged.
   - **Checked by:** `ViewerTests`, `HereFileTests`, `HereWatchTests` and `KernelProcessesTests`; `here.test.ts` and `panel.test.ts`; the viewers read live over this Mac's table, and the panel in a pty three ways (see "Testing").

**Answering a row's asks** (Lee, 26 November 2026), built once the keys across SitRep have landed (DESIGN.md, "Keys"), whose build edits the same keys and frames:

11. **Rows on one line.**
   - **Delivers:** the row's words by state, the project's lane, the time's lane by section, the cuts in their new order, and the expanded row showing what two lines showed; the arrow on the band's row with asks the view answers, and `⏎ asks` in the key line, `⏎` still expanding until slice 12.
   - **Checked by:** `panel-draw` and `panel-state`; every golden drawn again on one line beside round 5's frames, the sweep clean.
12. **A row's asks, open.**
   - **Delivers:** the feed's asks for the view (each ask's title, what it wants, its yes, options and pick, and its age); `⏎` and a tap opening them; the head, the ask, the dots, the answers and the foot; paging, closing, a changing board, the 300ms beat, and the rules short of room.
   - **Checked by:** `panel-view`, `panel-draw` and `panel-asks`; the goldens `asks`, `words`, `yes`, `prompt` and `busyasks`.
13. **Answering.**
   - **Delivers:** digits and taps holding an answer, the sending line, `u`, the write through `sitrep answer`'s code with `--wants`, `x`, the one-ask snooze, `o`, `q` while held, and the refusals.
   - **Checked by:** `panel-asks` and `panel`'s golden runs; the golden `sending`. Then a live run on a seeded state folder: an ask answered from the view over SSH from the phone and delivered in its window, one taken back by `u`, and a reshaped one refused.
14. **The docs.**
   - **Delivers:** `docs/terminal.md` on rows of one line and answering, the glossary's new terms, and the still `art/screens/terminal.webp` made again.
   - **Checked by:** the docs' measure script.
