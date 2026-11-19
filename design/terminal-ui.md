# The board in a terminal

SitRep shows the board at the edge of a Mac's screen, as the notch or the strip. Away from that screen there was nothing: on an iPad or a phone signed in to the Mac over SSH in rootshell, what needs you couldn't be seen until you went looking. The board in a terminal is the notch's panel as a terminal app, for those screens and for a Ghostty tab on the Mac. Its looks were drawn in four rounds in the Paper file "SitRep · terminal look", and on 19 November 2026 Lee picked round 4, now the page "FINAL · board in a terminal": **Two-line under grey capitals**, each session on two lines, its name and time, then its project and status line, under ruled section headings in grey capitals, every row flush at the margin and the chosen row marked by a band alone. This doc settles that look and how it's built.

**Settled with Lee on 18 November 2026:**
- **One panel,** drawn the same everywhere. It is a dashboard to leave open beside your work, and a launcher to pick from.
- **The command.** `sitrep` alone opens the panel in a terminal; `sitrep help` keeps the help.
- **Sessions by state,** as the notch orders them: Needs you (asks in orange, Stopped in blue), then Working, then Snoozed, folded at first. The project shows on each row.
- **It suits a terminal.** It's drawn for a narrow terminal first, such as a 25% split on an iPad or a phone held upright, and grows with the width. Lee: "We build it dynamically. It will fit regardless."
- **It doesn't answer asks,** because the notch doesn't.
- **Picking a row** attaches that session's tmux or zmx session in place, on the Mac as over SSH, so it behaves the same on every screen. Detaching comes back to the panel.
  - A session whose Claude has ended resumes in place, by the resume command.
  - A session running in a terminal with no tmux or zmx can't be reached from here, and the panel says so.
- **Notifications.** A new ask posts a terminal notification (OSC 9 or 777), which rootshell shows, even in the background and through tmux with passthrough. It's on by default, and a flag turns it off. Claude stopping doesn't notify, as in the app's defaults.
- **The screens** were measured by Lee in rootshell on the iPad: 39×27, the small floating window and the narrowest rootshell allows; 69×46, the slide-over; 114×45, the main window; and 73×36, a Ghostty pane on the Mac. 15 rows is the floor the design is drawn to.

A setting to run a command on a new ask, such as `rootshell-notify`, is parked. It would be a generic setting, like the terminal choice, not tied to rootshell.

**Settled with Lee on 19 November 2026, over the rounds:**
- **The marks are circles,** as on the notch card (round 2; round 1 drew asks as `◆` and `◇`). The orange is Claude Code's own, `#D77757`.
- **No `▸`:** the band alone marks the chosen row, so every row starts flush at the margin (round 3).
- **The headings are grey capitals,** `NEEDS YOU ●4 ●2 ───── ▿`: the words in `#7A82AB` at regular weight, the rule in `#565F89` (round 4).

## The looks

- **Round 1** drew four looks with diamonds: List, borderless sections and rows, the pane's idiom; Card, the notch's card in rounded box lines; Two-line, each session on two lines, roomy for a phone; Marks, the strip's two letters on pills, the densest.
- **Round 2** drew the same four with circles, from round 1's generator changed in place (`design/paper/round1/round1.py`, whose READ ME says round 2), so the repo holds no `round2/`.
- **Round 3** drew Two-line's rows under List's ruled headings, flush left, with no `▸` (`round3/round3.py`).
- **Round 4** is round 3 with the headings' words in grey capitals (`round4/round4.py`), the generator of record. It imports round 3, which imports round 1's worlds, scenes, colours and helpers, so all three are kept. `python3 -I design/paper/round4/round4.py` writes every frame to `round4/frames/`, reads each `.ansi` back cell for cell, and runs the width checks: 21 frames, none broken, the quiet board's short line listed on purpose.

## Scope

**What changes.** The `sitrep` CLI gains one interactive, full-screen view: bare `sitrep` on a terminal. It draws on the alternate screen, reads the board as `sitrep watch` does, in the same process, and redraws as the board changes.

**What stays byte for byte.** Every existing command: its words, its output, its JSON, its exit codes and the files it writes. `sitrep watch` prints the same lines, so SitRep reads it as before. Bare `sitrep` off a terminal, as a script or a pipe runs it, keeps today's answer: the help on standard error, exit 1. The help itself changes only if Lee agrees (Open for Lee, 14).

**What the switch carries.** Three pieces move to where both the watch and the panel can use them, with no change to what they give: the watch's look loop (`cli/watch.ts`) into `cli/looks.ts`; `ago` from the pane's `hooks/look.ts` into core; and the panel's grouping of Needs you, which only the app's Swift holds today, into core (see "What the code can't give yet").

## The frame

**The screen.** The panel owns the alternate screen while it runs. It hides the cursor and turns autowrap off (`CSI ?7l`), so a line written to the last column never scrolls the screen. Leaving restores all three. It paints no background: the terminal's own shows through every cell but the band and the wash.

**The margin.** Every line starts at column 1, counting from 0, so column 0 is the margin. The last column of the layout is a margin too: a row's time and a heading's chevron end at column W−2.

**The layout's width.** W is the terminal's width up to 120 columns. Past 120 the layout stays 120 wide and stands at the left, as round 4 drew it at 173. With no width to read, as a terminal that answers no size, it lays out at 80×24.

**Top to bottom:**
1. Row 0, the title: ` sitrep`, bold, in the terminal's own ink. Its right side is empty, unless the board went stale (Open for Lee, 7).
2. Row 1, blank.
3. The body, from row 2: the sections, a blank row between each two.
4. A pick's answer, when there is one: a blank row, then the answer's lines, just above the key line.
5. The last row, the key line.

**A short terminal.** The title and the key line always stay. Below 15 rows the blank row under the title goes first, then the blank rows between sections; then the body scrolls.

**Too small.** Below 24 columns or 8 rows the panel draws only `Too small` on row 0, at the margin, cut to the width. It keeps watching, so notifications still post, and it draws in full again once the terminal grows.

## The marks

Colour says what's needed; fill says where (DESIGN.md, "The notch and its panel"). Filled, a terminal on this Mac shows the session. Hollow, it's away: no window holds it, its Claude ended, or no terminal on this Mac shows it (Open for Lee, 8, says how the panel learns the last).

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
| the band | `#3E4A5B` ground | the chosen row, over both its lines |

**Without colour** (`NO_COLOR`), the shapes carry it. An ask and a turn share `●`, so an ask's name is bold and a turn's regular. The band is reverse video over both lines. A new ask keeps `◉` and loses its wash. Metadata is faint (SGR 2): times, projects, counts in grey, the rule, the chevron, `▲ N more`, an away row's words. A bold name is never faint too, since many terminals draw SGR 1 and 2 as one intensity.

## Rows and structure

**A section's heading** is one row:
- its words in capitals, `NEEDS YOU`, `WORKING`, `SNOOZED`, at column 1, grey `#7A82AB`, regular;
- a space, then its counts;
- a space, then a rule of `─` in faint `#565F89`, out to column W−5;
- a space, then the chevron at column W−2: `▿` open, `▹` folded, faint.

**The counts,** as the notch's eyebrow counts them (`Eyebrow`, `SitRepPanel/Sections.swift`):
- **Needs you:** `●` orange then its asks in bold orange, `●4`: the lines of its ask rows, each ask, permission prompt and question waiting. Then a space, `●` blue and its Stopped in bold blue, `●2`: the rows at your turn, one a session. Each shows only above zero.
- **Working:** its rows, grey.
- **Snoozed:** its lines, grey: the asks asleep, and the turns put off.

**A row** is a session, on two lines:
- **Line one.** The mark at column 1. From column 3, the session's name, then, where more than one line waits, a space and their count in grey: `Help desk redesign 2`. The name is cut before the count, never the count. Then the time, right-aligned to end at column W−2, in grey, with at least 2 spaces before it.
- **Line two,** from column 3: the project's name and ` · ` in grey, then the status line in soft `#A9B1D6`, cut with `…` at column W−2.

**The words.**
- **The name:** an ask's in the terminal's ink, bold; a turn's in that ink, regular; a working or own-work row's in soft. In Snoozed, grey, an ask's bold.
- **The status line** is the row's first line (`RowLine`): its lead, then its subject after a space (`Running npm test`). A permission prompt joins its subject with `: ` (`Allow Bash: psql -f import.sql`). A question adds its `+2` after a space, in grey. A wake reads `Wakes in 12m`.
- **The time:** in Needs you, how long its newest line has waited; in Working, how long the turn has run; on its own work, how long since its turn ended. Each reads as `ago` gives it: `now`, `12m`, `2h`, `3d`. In Snoozed, when it wakes, as core's `wakeWords` says it (`14:00`, `tomorrow 09:00`, `Sat 09:00`, `next week`), or `until it moves`.

**Dimming.**
- **An away row** dims its words as one, as the notch does: each ink 0.61 of the way from the background, its mark kept full and hollow (`DIMMED` in round 1).
- **A Snoozed row** dims its mark, and only its mark. Its name is grey, as "The words" says, and its project and status line are as any row's.
- **The band and the wash** sit over both lines of a row, from column 1 to W−2.
- **A new ask's wash** is orange mixed 22% into the background, `#534345` on Nordfox, for two seconds from the first frame that shows the line.

**The order** is the notch's (DESIGN.md, "The rows", 13 November 2026):
- **Needs you:** its asks, those this Mac shows first, then the away ones; then its Stopped, the same way. Each part keeps core's order, newest first.
- **Working:** working, the longest running first; then on its own work, those waiting on a wake first, the soonest due first.
- **Snoozed:** the soonest to wake first, those until it moves last, then the oldest (`inSnoozedOrder`).

**Folding.** Snoozed is folded at first, its heading alone. `s` opens it and scrolls its rows into view; `s` again folds it. The fold isn't saved: each run starts folded. Needs you and Working never fold.

**Scrolling.** The body shows the rows that fit, in whole rows.
- **Out of view:** above them, `▲ 11 more` in grey on a row of its own; below them, `▼ 6 more`. Each counts sessions, not lines.
- **The pinned heading:** scrolled into a section, its heading stays on the body's top row, above `▲`.
- **The band in view:** the view moves the least that keeps the band's row whole in sight. With no band, opening Snoozed scrolls its last row into view.

**A quiet board.** With no rows at all, the body reads `All clear`, bold, then a blank row, then `Nothing needs you, and nothing is running.` in grey, wrapped at 24 columns. Each line is centred, the three a little above the middle. The key line reads `q quit`.

## The live region

Doesn't apply: the panel draws on the alternate screen, never in the terminal's flow, and leaves nothing in the scrollback.

## Progress

Doesn't apply: the panel shows no step running. Its marks are still: `✻` doesn't spin, until Lee says otherwise (Open for Lee, 12). Only the clock moves anything: the times turn over each minute, a wake's countdown with them, and a wash ends after its two seconds.

## Keys

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j` | The first press puts the band on the top row in view; then each moves it a row, across sections, skipping headings |
| `PgUp` `PgDn` | Moves the band a body's height |
| `Home` `End` | Moves the band to the first or the last row |
| `⏎` | Opens the band's session (see "Picking a row") |
| `s` | Opens or folds Snoozed |
| `esc` | Drops the band and any pick's answer |
| `q`, `Ctrl-C` | Leaves |
| `Ctrl-Z` | Suspends the panel; `fg` brings it back, drawn afresh |

**The key line** names the keys that work now, most needed first: `↑↓ pick  s snoozed  q quit` with no band, `↑↓ move  ⏎ open  s snoozed  q quit` with one. Each key is bold in the terminal's ink, its word grey, two spaces between hints. `s snoozed` shows only while Snoozed holds rows; an empty board's line is `q quit`. Short of room, whole hints drop from the right. PgUp, Home, `j`, `k`, `esc` and `Ctrl-Z` work but aren't named.

**Decoding.** Keys come in raw mode as bytes. `CSI` and `SS3` arrows both read as arrows (`ESC [ A`, `ESC O A`), so application cursor mode doesn't matter. A lone `ESC` with nothing after it within 50 ms is `esc`. Any other byte does nothing.

**The band and a changing board.** Rows take their new places at every look. The band stays on its session wherever that row goes, and the view keeps it in sight (Open for Lee, 11). A session that leaves the board passes the band to the row now in its place, else the row above; with no rows left, there's no band.

## Picking a row

`⏎` on a row opens its session in the panel's own terminal. What opens depends on the session's windows, in core's jump order (`FeedWindow.jumpOrder`):

| The session | `⏎` |
|---|---|
| A live window in tmux | `tmux -S <socket> attach-session -t <pane>` |
| A live window in zmx | `zmx attach <session>`, once `zmx list --short` names it |
| Live windows, none in tmux or zmx | The answer: `Release notes can't be opened here: its terminal has no tmux or zmx.` |
| A live window that says nothing of where it is | The answer: `Release notes can't be opened here: its window didn't say where it is.` |
| No live window, with a last window | The resume command, in place |
| No live window, and none to resume | The answer: `Release notes can't be carried on from here: no window of it is left.` |

- **The first that can be opened.** The panel tries the session's live windows in that order, and opens the first in tmux or zmx. A Snoozed row picks the same way.
- **Two multiplexers.** A window that records both is in the innermost, as the jump decides it (DESIGN.md, "The jump", 9 November 2026). tmux is innermost where `tmux -S <socket> display-message -p -t <pane> '#{pane_tty}'` gives the window's device; else zmx is.
- **tmux's target.** A pane as the target attaches the session holding it, with the pane's window current and the pane active; slice 6 proves this live.
- **zmx's check.** `zmx attach` makes a session it doesn't find, so the panel attaches only one `zmx list --short` names. A session gone reads `Release notes's zmx session has ended.`

**The resume command,** for a session no live window holds, is filled from core's last window (`FeedSession.lastWindow`):
- `{claude}`: the last window's writer, the Claude Code session it ran;
- `{dir}`: its directory;
- `{tty}`: empty, unless the alive check finds that Claude still running there, as SitRep fills it; only a command you wrote is ever run with it, since the default is refused there.

Each value goes in single-quoted, as SitRep's `TypedCommand` quotes them, and the line runs in the login shell, `$SHELL -l -c <line>`. A window with no directory gets SitRep's words: `Release notes's last window did not say which folder it ran in, as a window on an older sitrep does not, so sitrep has nothing to put for {dir}.` Which command it is, SitRep's setting or the default `cd {dir} && claude --resume {claude}`, is Open for Lee, 9.

**Never beside a living Claude.** SitRep's jump never resumes beside a Claude that may still be alive (`Jump.carryOn`): the panel follows the same rule with the default command, if Lee allows it the process table (Open for Lee, 10).
- **Suspended:** a Claude stopped on the last window's device reads `Release notes's Claude is suspended in its terminal: type fg there to bring it back.`
- **Running:** one still running there reads `Release notes's Claude is still running in its terminal.`

**The hand-over.** Opening a session hands the terminal over, then takes it back:
1. Leave the alternate screen, show the cursor, turn autowrap on and raw mode off, and stop reading keys.
2. Run the program with the panel's standard input, output and error, and ignore SIGINT, SIGQUIT and SIGTSTP while it runs: they're the program's.
3. When the program ends, take the terminal back and redraw from the latest board, the band where it was.

- **Leaving the session.** Detaching ends the attach: `Ctrl-\` in zmx, the prefix then `d` in tmux (Open for Lee, 1). A resumed Claude ends when you quit it.
- **Watching meanwhile.** The panel keeps looking at the board while the program runs.
- **A program that fails.** One that exits non-zero leaves an answer: `tmux couldn't attach Release notes: it exited 1.` One not on the PATH leaves `tmux isn't on this shell's PATH.`
- **Inside a multiplexer.** A panel running inside zmx or tmux can't nest an attach as it can elsewhere; Open for Lee, 2, decides what it does.

**A pick's answer** sits above the key line: `!` bold, a space, then the words in the terminal's ink, wrapped at W−4 and hung under the first word. It stays until the next key.

## Notifications

- **What notifies.** Each ask new on the board, as core's `newRows` finds it and the app's `newAsks` keeps it to asks: never a permission prompt, a question, or Claude stopping.
- **What doesn't.** The panel's first board posts nothing, as the app's first board doesn't. Several new asks post oldest first.
- **The words** are the app's banner's (`Notices.newAsk`): the ask's words, then `Project · Session`.
- **The sequence** is one OSC, written whole between frames (Open for Lee, 5): OSC 777, `ESC ] 777 ; notify ; <ask> ; <Project · Session> BEL`, or OSC 9, `ESC ] 9 ; <ask> · <Project · Session> BEL`.
- **Inside tmux** (`$TMUX` set), it goes in tmux's passthrough, `ESC P tmux; … ESC \` with each `ESC` doubled. tmux shows it only with `allow-passthrough on`, your setting.
- **Clean text.** Control characters are dropped from the words, and a `;` in OSC 777's title becomes `,`, since `;` ends the field.
- **Turning it off.** One flag turns notifications off for the run (Open for Lee, 4).
- **While a session is attached,** whether the panel posts is Open for Lee, 6.

## Failure

- **A look that fails,** as an unreadable state folder: the watch passes over a file that doesn't read and ends on anything else. The panel never ends on a look; what it shows is Open for Lee, 7.
- **Before the first board,** the body reads `Looking for sessions…` in grey, but only once the first look has taken 300 ms.
- **A pick that can't open** says why in its answer (see "Picking a row") and changes nothing.
- **The panel itself failing:** it restores the terminal first, then prints `sitrep: <message>` to standard error and exits 1, as `main` does for any command.

## Next steps

Doesn't apply: the panel collects no remedies. A pick's answer says what to do in its own words.

## The close

`q` or `Ctrl-C` leaves the alternate screen, so the shell's screen comes back as it was. It prints nothing and exits 0.
- **SIGTERM** restores the terminal and exits 143.
- **SIGHUP,** as an SSH connection drops, tries to restore it and exits 129.
- **`Ctrl-Z`** restores the terminal and stops the panel; on SIGCONT it takes the terminal back and redraws.

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
| The band | `#3E4A5B` | 239 | reverse video |

- **The terminal's ink:** names, the title and the keys are in the terminal's own foreground, never a hex, so they read on any theme.
- **The level:**
  - `NO_COLOR` set: no colour at all.
  - `FORCE_COLOR` set: colour on, at the level its value gives.
  - `COLORTERM` of `truecolor` or `24bit`, or a `TERM` naming `ghostty` or ending `-direct`: 24-bit.
  - A `TERM` naming `256color`: 256 colours.
  - Otherwise: 16.

  Over SSH, `COLORTERM` usually stays behind, so rootshell likely draws in 256 colours: the nearest each, measured from the palette.

**Asking the terminal.** At start, in raw mode, the panel asks for the terminal's foreground and background (OSC 10, OSC 11), then device attributes (DA1), which every terminal answers. It waits for DA1's answer, up to a second. Answers that come after are read and dropped for a second more, never taken as keys. It asks only on a terminal, in the foreground.

**Mixes.** Three things are mixed toward the background, so they need its colour:
- an away row's dimmed words, 0.61 of each ink;
- a Snoozed row's dimmed mark;
- a new ask's wash, orange at 22%.

Dimming the terminal's own ink needs its foreground too. With both answers, at 256 colours or more, they're mixed. Without them, or at 16 colours, the dims are faint (SGR 2) and the wash is left out. The band is a fixed colour, so it needs no answer.

**Bold and faint.** Bold marks what needs you: an ask's name, the needs-you counts, the title, the keys, `!` and `◉`. Faint (SGR 2) is used only without colour or at 16, for metadata.

**Contrast,** measured on Nordfox's `#2E3440`, the background the frames are drawn on:
- **The palette:** soft 5.9 : 1, blue 5.0, orange 4.0, grey 3.3, the rule 2.0.
- **On the band:** soft 4.3 : 1, grey 2.4.
- **Lee's call.** These are the frames Lee picked; they clear the floor for marks (3 : 1), not every word the text floor (4.5 : 1).
- **A light background:** the palette is drawn for dark ones. What the panel does on a light one is Open for Lee, 13.

## Width

**Each part's least and natural width:**

| Part | Natural | Least, and below it |
|---|---|---|
| The name, with its count | its own width | 6 cells and `…`; the count is never cut |
| The time | its own width | a Snoozed wake drops its clock (`tomorrow`) where the name would get under 6, then goes |
| The status line | its own width | 6 cells and `…`; below that it goes, its ` · ` with it |
| The project, on line two | its own width | cut with `…` once the status line has gone |
| The heading's rule | out to W−5 | 3 cells; below that it goes, the counts and the chevron kept |
| The key line | every hint | whole hints drop from the right |
| A pick's answer | wraps at W−4 | always wraps, never cut |

**What gives way first,** as the width falls: the status line is cut, then dropped; then the project is cut; then the name is cut to its least; then a Snoozed wake loses its clock; then the time goes. At 39 columns, Lee's narrowest, only the status line is cut. Below 24 columns the panel draws `Too small`.

**Wide terminals.** Past 120 columns the layout stays 120 and stands at the left. The rows don't change form with width: line two holds the status line at every width, as round 4 drew at 114 and 173.

**Cutting.** A name is cut from its end with one `…`, only below its natural width. Nothing is cut that a wider terminal would show whole, and nothing cut can't be read by widening the terminal.

**Shown text made harmless.** Every word from the board is collapsed to one line, as core's `oneLine` does, before it's measured. C0 and C1 controls, `ESC` and `DEL` are dropped from it, so a session's name can't move the cursor or set a colour.

**Cell widths.** A cell's width is its grapheme's:
- East Asian Wide and Fullwidth characters, and emoji in emoji presentation, take two cells;
- a combining mark joins the cell before;
- a cut never splits a grapheme.

**Height.** It gives way in the order "The frame" gives. The least is 8 rows: the title, a heading, `▲`, one two-line row, `▼` and the key line, with one row to spare. A pick's answer takes its rows from the body.

## Per command

**`sitrep`, alone, on a terminal:** the panel.
- **When it opens:** standard input and output are both terminals, and `TERM` isn't `dumb`.
- **Its flags:** words that are all flags read as the panel's, so `sitrep --no-notify` opens it too (Open for Lee, 4). A word that isn't a flag is a command's name, as today.
- **Opening:** it asks the terminal's colours, enters the alternate screen, looks at the board and draws it.
- **Running:** it redraws as the board changes, as keys move the band, as the terminal resizes, and as the clock turns a minute or ends a wash.
- **Leaving:** see "The close".

**`sitrep` alone, off a terminal or on `TERM=dumb`:** the help on standard error, exit 1, as today.

**`sitrep help`, `--help`, `-h`:** the help, as today.

**Every other command,** `watch` among them: unchanged.

## Built on: the code as it is

- **Dispatch.** `cli/main.ts`'s `answer` takes the first word as a command's name. With none, it prints `HELP` to standard error and returns `EXIT.refused`, 1; `help`, `--help` and `-h` print the help. The panel goes in `answer`'s empty case, on a terminal.
- **The board.** `cli/watch.ts`'s `watchUntil` looks every second (`POLL_MS`).
  - It uses `boardReader` over `heldReads` (`cli/held.ts`) and `readBoard`/`readFolder` (`cli/files.ts`).
  - It keeps a `Clock` of the Mac's sleeps (`clockAt`), and looks again when core's `nextExpiry` says time alone changes the board.
  - It ends by `untilEnded` (`cli/ending.ts`).
  - Core's `feedOf` makes the `Feed`; `newRows` says what's new. Each look's `Feed` is all the panel draws from.
- **The rows.** `core/rows.ts`'s `rowOf` and `snoozedRowOf` make the rows.
  - A `Row` carries its session, name, project name, `isAway`, `section` (`needsYou`, `yourTurn`, `working`), its `lines` newest first, and `since`.
  - A `Line` carries its key, `is`, `first` (`RowLine`: `lead`, `mono`, `subject`, `more`, `until`) and `since`.
  - Core's `inPanelOrder` groups needs-you here, needs-you away, your turn, working, then on its own work. `inSnoozedOrder` orders Snoozed.
- **Where a window is.** Each live window comes as a `FeedWindow`: its writer, session, `where`, `directory`, `state` and `jumpOrder`.
  - `where` is `core/where.ts`'s `Where`: `device`, `terminal`, `tmux` with its `socket` and `pane`, and `zmx` with its `session`.
  - The mod records it once a process (`hooks/where.ts`'s `whereNow`): the socket is `$TMUX` up to its first comma, the pane `$TMUX_PANE`, the zmx session `$ZMX_SESSION` whole, and the device by `TTY_WALK`.
  - Core's `inJumpOrder` orders the windows for a jump.
- **Resuming.** A session no live window holds carries `lastWindow` (`core/windows.ts`'s `lastWindowOf`): its writer (`{claude}`), `where`, `directory` (`{dir}`) and `ownsDevice`.
  - The CLI can't resume a session today. SitRep does, in Swift (`SitRepScreen/Jump.swift`'s `carryOn` and `resume`).
  - SitRep fills the command by `ResumeCommand` and `TypedCommand`, its default in `OpenSettings.defaultResumeCommand`.
  - The command Lee sets is saved in SitRep's defaults, under `app`'s `resume` key (`SitRepMenu/AppSettings.swift`).
- **Words.** `core/snooze.ts`'s `wakeWords`, `core/text.ts`'s `oneLine`, and `hooks/look.ts`'s `ago`.
- **The world.** `cli/io.ts`'s `Io` gives the file system, the environment, the clocks, standard input, output and error, and the run's end. It has no terminal and no `run`: "It runs no program" (DESIGN.md, 10 November 2026, stage 7, step B). `cli/shell/index.ts` binds it to Bun, its runtime declared in `cli/shell/runtime.d.ts`.
- **Retired, in history.** The CLI's tmux, zmx and `ps` readings went in `09e943b` (#110), with the Bun binding's runner of programs: `cli/tmux.ts`, `cli/zmx.ts`, `cli/processes.ts`, `cli/multiplexer.ts`.

## What the code can't give yet

1. **A look loop apart from printing.** `boardReader`, `untilEnded` and `releaseOf` are private to `cli/watch.ts`.
2. **The panel's order and counts.** Needs you's asks before its Stopped, here before away, and the eyebrow's counts are the app's alone (`SitRepPanel/Sections.swift`'s `inPanelOrder` and `Eyebrow`, `SitRepEdge/PanelBoard.swift`). Core's `inPanelOrder` groups by section and away.
3. **Words for the times.** `ago` is the pane's, in `hooks/look.ts`. A wake's countdown, `Wakes in 12m`, is worded only by the app.
4. **A terminal.** `Io` has no raw mode, size, resize, alternate screen, colour query, or way to hand the terminal to a program and wait.
5. **Running a program.** Attaching needs tmux and zmx, and the alive check needs `ps`; `Io` has no `run`.
6. **Which sessions this Mac shows.** Only SitRep reads it (`SitRepScreen/HereWatch.swift`, `Here.swift`), and core knows nothing of it, so the panel can't yet tell a held session no Ghostty shows from one it does.
7. **The resume command.** It lives only in SitRep's saved settings, and only Swift fills and quotes it.
8. **Whether a Claude is alive or suspended** on a device: only SitRep's process table reads it (`Jump.claude(on:)`).
9. **`sitrep` on a shell's PATH.** Claude Code puts the plugin's `bin` on Claude's own PATH. A login shell, over SSH or in Ghostty, has no `sitrep`, and the cask has no `binary` stanza.
10. **Golden frames under the kit.** `claude plugin test` loads only code: a test can't import `node:fs` or a `.txt`, proven on 19 November 2026, as `RealNamesTests.swift` notes. The frames need a checker run by Bun (see "Testing").

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
  time: string
}
export type PanelView = {
  sections: { kind: PanelSection['kind']; counts: PanelSection['counts']; rows: PanelRow[]; isOpen: boolean }[]
  band?: string
  top: number
  answer?: string
  board: 'looking' | 'read' | 'stale'
}
export const viewOf: (feed: Feed, state: PanelState, now: number, notHere: ReadonlySet<string>) => PanelView

// cli/panel/state.ts: the keys and the board, with no terminal
export type PanelEvent =
  | { board: Feed; news: string[] }
  | { key: Key }
  | { size: Size }
  | { tick: number }
  | { opened: Answer | undefined }
export const step: (state: PanelState, event: PanelEvent) => { state: PanelState; open?: string }

// cli/panel/draw.ts: lines at a size; no clock, no terminal
export type Run = { text: string; pen: Pen }
export type Line = Run[]
export const draw: (view: PanelView, size: Size, paint: Paint) => Line[]
export const ansi: (lines: Line[], level: Level) => string
export const text: (lines: Line[]) => string

// cli/panel/reach.ts: what ⏎ opens, decided from the feed alone
export type Reach =
  | { tmux: { socket: string; pane: string; device?: string } }
  | { zmx: { session: string } }
  | { resume: { claude: string; dir?: string; device?: string } }
  | { answer: string }
export const reachOf: (session: string, feed: Feed) => Reach
```

**`Paint`** is what the terminal said: the colour level, and its foreground and background where it answered. **`Key`** is decoded from bytes by `cli/panel/keys.ts`'s `keysOf`. `step` returns `open` with a session's id when `⏎` asks for one, and the loop answers with `opened`.

**The shell's half.** `Io` gains `terminal`, absent off a terminal, bound to Bun in `cli/shell/terminal.ts`:

```ts
export type Terminal = {
  size: () => Size | undefined
  onResize: (heard: () => void) => () => void
  keys: (heard: (bytes: string) => void) => () => void
  write: (text: string) => void
  ask: (query: string) => Promise<string>
  hand: (argv: readonly string[]) => Promise<number>
  run: (argv: readonly string[], ms: number) => Promise<{ exit: number; out: string; err: string }>
  onSignal: (signal: 'SIGHUP' | 'SIGTERM' | 'SIGCONT', heard: () => void) => () => void
  suspend: () => void
}
```

- **`keys`** turns raw mode on while it listens.
- **`ask`** writes the OSC 10, OSC 11 and DA1 queries and gives what came back before DA1's answer.
- **`hand`** gives the terminal to a program until it ends, as "The hand-over" says.
- **`run`** runs a program within a limit, for tmux's and zmx's questions and `ps`.

The fakes in `tests/` stand in for all of it.

**The loop.** `cli/panel/run.ts`'s `panel(io, flags)`:
1. Asks the colours and enters the screen.
2. Starts `looking` (`cli/looks.ts`), the watch's loop, which hands it each look's `Feed`.
3. Steps the state on every event, draws, and writes only the rows that changed, inside synchronized output (`CSI ?2026h` … `CSI ?2026l`).
4. Opens what `step` asks for through `cli/panel/edge.ts`, which alone builds tmux's, zmx's and the shell's command lines.

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
  - `Too small` below 24×8.
- **`panel-keys.test.ts`:** byte sequences to keys, a lone `esc` by its 50 ms, `CSI` and `SS3` arrows.
- **`panel-state.test.ts`:** the band's first press, moves, pages and ends; the view's scroll; the band following its session and passing on; folding; answers dropped on a key.
- **`panel-reach.test.ts`:** every row of "Picking a row"'s table; the innermost of two; the jump order; the resume command's values quoted; the alive check's words.
- **`panel.test.ts`,** golden runs through the fake terminal:
  - the exact writes to enter, draw, hand over, take back and leave;
  - `q` exits 0, SIGTERM 143, SIGHUP 129;
  - SIGINT ignored while a program has the terminal;
  - notifications: one OSC each for new asks only, none on the first board, none with the flag, wrapped inside tmux.
- **`cli.test.ts`:** bare `sitrep` off a terminal keeps its help and exit 1; every command's tests pass unchanged.

**Golden frames,** by the Bun checker `cli/frames/check.ts`, which the kit can't run:
- **The files:** each frame is a `.txt` and an `.ansi` in `tests/frames/`, named `panel-<screen>-<W>x<H>`.
- **The check:** each fixture is drawn and held to its frame cell for cell: glyph, foreground, background, bold, faint and reverse. The SGR reader refuses any escape it doesn't model. A failure names the first 20 differences, then how many more.
- **Writing them again:** `--update` writes the frames again and deletes those nothing draws; a kept frame nothing draws fails.
- **The checker's own tests:** its reader and comparer are pure TypeScript in `cli/frames/cells.ts`, tested under the kit with inline strings.
- **The fixtures** (`cli/frames/fixtures.ts`) are moments: a world, a size, the terminal's answers (Nordfox's `#CDCECF` on `#2E3440`), a fixed clock, and the keys pressed to reach them.
- **The screens:** round 4's, `rest`, `picked`, `unfolded`, `busy`, `arriving`, `unreachable`, `quiet`, `wide` and `nocolor`, at round 4's sizes. Added to them: `narrow-30x27`, `small-23x10`, and `busy-24x8`.
- **The first goldens** are round 4's frames, with one change on purpose: the names and a pick's answer, which round 4 drew in Nordfox's `#CDCECF`, are in the terminal's own ink, as its title and keys already are.

**The sweep.** The checker draws every fixture at 39×27, 69×46, 73×36, 114×45, 173×53 and 73×15, and runs the four width checks from termgrid's `sweep`, ported:
- a name cut with room to spare;
- a fold with rows to spare;
- nothing drawn;
- a wasted third.

The quiet board is listed on purpose, as round 1 lists it: "All clear" and one short line, centred, have nothing to widen.

**Gates.** The slice that brings the checker adds `bun cli/frames/check.ts` and `bunx tsc -p cli/frames` to CLAUDE.md's gates. The root `tsconfig.json` excludes `cli/frames` as it does `cli/shell`.

**Live tests.** A live run points `XDG_STATE_HOME` at a folder of its own and seeds sessions there, as CLAUDE.md says. Picking a row attaches in the panel's own terminal and brings no window forward, so it is no jump.

## Pictures

- **The demo world** is round 1's: `REST`, `BUSY` and the arriving `Room bookings`, in `cli/frames/fixtures.ts`, all placeholder names.
- **No VHS tapes:** the golden frames and the live runs hold the panel.
- **The still** for the docs page is a golden frame, `panel-rest-73x36`, read by `termgrid.py read` and drawn as the rounds' previews are, into `art/`.
- **Later rounds** start from the build's frames read into termgrid, not from round 1's model of them.

## Out of scope

- Answering asks (settled with Lee), and snoozing or waking from the panel.
- Opening a session's own Ghostty window on the Mac, as the notch's jump does: the panel attaches in place everywhere.
- An ASCII fallback, colour settings, themes, and a `--no-color` flag: `NO_COLOR` covers it.
- Remembering the fold or the band between runs.
- `sitrep serve`, a phone app, or any reach beyond the Mac's own terminals.

## Known limits

- **zmx inside zmx.** An attach made inside another zmx session switches that terminal's client in place, and leaves no process of its own to end: DESIGN.md, "The jump", records the limit. So a pick from a panel inside zmx can't come back to it by detaching (Open for Lee, 2).
- **OSC 9 and 777 inside zmx** are not yet known to reach the terminal; slice 7 proves it live.
- **An update under a running panel.** The panel runs the code it started with until you quit it. The watch, by contrast, ends at a new version for SitRep to start again.
- **A resumed Claude lives in the panel's terminal.** A dropped SSH connection ends it, unless the resume command runs it in a multiplexer.
- **Ambiguous-width glyphs.** `●` `○` `◌` `◉` `✻` `─` `▿` `▹` `▲` `▼` are East Asian Ambiguous: a terminal set to draw them wide breaks the columns.
- **A board a second old.** The panel looks every second, as the watch does, so a new ask's mark and its notification come up to a second late.
- **tmux grouped sessions.** A pane in several sessions is attached in whichever of them tmux picks.

## Open for Lee

Asked one at a time, each with a recommendation; each answer is recorded here.

1. **Leaving an attached session.** The panel hands the terminal to tmux or zmx, so their own detach brings you back: `Ctrl-\` in zmx, the prefix then `d` in tmux. A resumed Claude has no detach: quitting it brings you back. *Recommended:* the multiplexers' own keys and nothing of sitrep's. A key of sitrep's own would mean relaying every byte through a pty the CLI holds.
2. **Picking from a panel that runs inside zmx or tmux.** zmx switches this terminal's client in place, and tmux would nest. *Options:*
   - **(a) Switch:** `zmx attach`, or tmux's `switch-client`. The panel stays running in its own session, which you come back to as to any session.
   - **(b) Nest the attach:** zmx's one detach key reaches the outer client first, so this fails in zmx.
   - **(c) Refuse:** "Run sitrep outside zmx to open sessions from it."

   *Recommended:* (a). Every Ghostty tab on your Mac runs in zmx, and switching is what both multiplexers do by design. Detaching then comes back to the panel only when the panel runs outside a multiplexer, as `ssh -t` to `sitrep` from rootshell does.
3. **Mouse and touch.** *Recommended:* a tap puts the band on a row and a tap on the band's row opens it; the wheel or a swipe scrolls; no hover. Hover needs every pointer move sent over SSH. With mouse reporting on, selecting text in the panel needs a modifier held.
4. **The flag's name.** *Recommended:* `--no-notify`, read as `sitrep --no-notify`: it says what it does.
5. **Which notification.** OSC 777 carries a title and a body, as the app's banner does; OSC 9 carries one line. *Recommended:* OSC 777, the ask's words as its title and `Project · Session` as its body, once you confirm rootshell shows it.
6. **Notifications while a session is attached.** *Recommended:* keep posting. An ask in another session is the one you'd want to hear about.
7. **What the panel shows if it can't read the board.** *Recommended:*
   - **After a board:** keep the last board, with `as of 12:04` in grey at the right of the title row, as the app's menu does.
   - **Before any board:** `Looking for sessions…`, then `Can't read the board` and the reason, as the app's words go.
8. **How the panel learns which sessions this Mac shows,** the fill of a held row. *Options:*
   - **(a) Core's away alone:** a session held in a zmx session no Ghostty shows draws filled.
   - **(b) SitRep's read:** SitRep writes the sessions this Mac doesn't show as it reads them, for the panel to read; with SitRep not running, as (a).
   - **(c) The CLI reads the screen itself:** the Mac's work in TypeScript again.

   *Recommended:* (b). It keeps that read in one place, in Swift, and the panel's fill then matches the notch's.
9. **The resume command.** *Options:* the default only; SitRep's setting; a flag or variable of the panel's. *Recommended:* SitRep's setting, read from its saved settings, the default where none is saved. A command you wrote to run Claude in zmx then carries on there, so a dropped connection doesn't end it.
10. **The CLI running programs again.** Attaching needs tmux and zmx; never resuming beside a living Claude needs the process table, `ps`. The CLI has run no program since 10 November 2026 (#110). *Recommended:* one edge module, `cli/panel/edge.ts`, for the pick alone: `tmux attach-session` and `display-message`, `zmx list` and `zmx attach`, `ps -t <device>`, and the login shell for the resume command. Nothing else in the CLI runs a program, and the app's jump keeps all of its own.
11. **Rows moving under the band.** The notch holds its rows in place while its panel is open, a glance. *Recommended:* the terminal's rows take their new places at each look, the band staying on its session and in sight. A dashboard left open for hours must stay current.
12. **The working mark.** Round 1 named `✻` as Claude Code's spinner, `·✢✳✶✻✽`. *Recommended:* a still `✻`. Turning means redrawing every working row several times a second over SSH, and the time already shows the session is live.
13. **A light terminal.** The palette is drawn for dark backgrounds. *Recommended:* where OSC 11 or `COLORFGBG` says the background is light, draw with the terminal's own 16 colours, until a light set is drawn in Paper and picked.
14. **The help.** *Recommended:* `sitrep help` gains one usage line, `sitrep [--no-notify]`, saying it opens the board in this terminal. Every other line stays as it is.
15. **`sitrep` on a shell's PATH.** Over SSH there's no `sitrep` to type. *Recommended:* the cask, in its Homebrew tap, gains a `binary` stanza linking SitRep's CLI, `Contents/Resources/Plugin/bin/sitrep`, into Homebrew's `bin`.

## Build

A PR a slice, in order. Slices 2 and 3 can run in parallel once 1 is in; 4 waits on both, and each slice after it on the one before. Each is reviewed before the next starts; 5 and 6 at the deepest review, for raw mode, the hand-over and signals.

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
   - **Delivers:** `reachOf`, the edge (tmux, zmx, the resume command and the alive check, as Lee decides 2, 9 and 10), the hand-over, and the answers.
   - **Checked by:** `panel-reach` and the hand-over's golden runs. Then a live run with a seeded session in a zmx session with a placeholder name, attached and detached, and one away session resumed.
7. **Notifications.**
   - **Delivers:** the OSC on new asks, tmux's passthrough, and the flag.
   - **Checked by:** `panel`'s notification runs. Then live in Ghostty and in rootshell, with the panel in front and behind, inside tmux with passthrough, and inside zmx.
8. **The fill from SitRep,** if Lee picks (b) in Open for Lee, 8.
   - **Delivers:** SitRep writes the sessions this Mac doesn't show; the panel reads them.
   - **Checked by:** a Swift test of the write, a panel test of the read, and a live check beside the notch. One Swift build at a time.
9. **Reaching it, and its page.**
   - **Delivers:** the cask's `binary` stanza, a PR in the cask's tap; a feature page in `docs/`, measured; the glossary's new terms; the README's line; the still in `art/`.
   - **Checked by:** the docs' measure script, and `sitrep` typed in a fresh login shell over SSH.
