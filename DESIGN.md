# sitrep

A small window, inside Claude Code, onto where a piece of work stands and what
it needs from Lee. Claude jots into it as it works; Lee glances at it, answers
what waits on them, and goes back to the chat.

Written 8 October 2026 from a day of design and a working UI spike. Everything
here was decided with Lee unless it says **proposed**.

## The one rule

**The chat is primary. sitrep is a best-effort window onto Claude's own tracking.**

- Claude talks to Lee in the chat exactly as it does today, and *also* pings
  sitrep. Nothing moves out of the chat into sitrep.
- Claude never tracks anything *through* sitrep. Its real record stays wherever
  that project keeps one: a design doc, a plan, memory, a log. sitrep shows a
  line from that record and points at it, never the payload.
- sitrep is for Lee. If an update is missed, nothing breaks; it should still be
  dependable enough to trust at a glance.
- The board never claims Claude knows something it was not told (see Delivery).

## Words

| Word | Means |
|---|---|
| **piece of work** | What Lee calls a "session": one line of work, whatever Claude windows it spans. The UI says *session*; underneath it is a work id. |
| **work id** | The board's internal id for a piece of work. Never shown in the UI. |
| **project** | What a piece of work is on, named by Claude as Lee would say it (`SitRep`, `Switchboard`), and where it lives once known. Never the folder a session started in. |
| **status** | Where a piece of work stands: its name, a one-line summary, what is under way now (one line each), and what comes next. |
| **ask** | Something only Lee can do or decide, posted by Claude. Counted on the band. |
| **note** | A line in the log: something that happened that Lee may want to know. Not counted. |
| **parked** | Something raised and put off, to circle back to. Not counted, not dismissable. |
| **reply** | Lee's answer to an ask, or a pick-up of a parked item, waiting in Ready to send. |
| **board** | The pane. **band** is the line above the prompt. |

## Pieces of work, not Claude sessions

A Claude session id changes on `/clear` and `/resume`, and one piece of work
can run across several windows. So sitrep keys everything on a work id.

1. Claude starts a piece of work on the board with a name, a summary and its
   project (below), and gets back a work id.
2. Claude records the id in its own tracking for that work (design doc, plan,
   memory: wherever that project keeps things).
3. Any later window joins the work by id: after `/clear`, `/resume`, a fresh
   window tomorrow, or a second window on the same work. Two windows on one
   work is how sessions combine.
4. At the start of every Claude session, sitrep lists every current piece of
   work, with its project and id, in Claude's context, so "let's carry on
   with the dashboard work" finds its id even if nothing in memory says it.
   It is a block of the conversation's first message (`prompt.context`,
   named `sitrep`), in every conversation: how to keep the board (below,
   "When to start a piece of work"), then the works when there are any, a
   line each, project by project:

   ```
   On the board:
   - SitRep: sr-wdsqvn "sitrep", 2 waiting on Lee
   - Switchboard: sr-v1pwm9 "Milestone 7 stage 1"
   ```

   The projects whose directory holds the session's folder come first, the
   nearest first, then the busiest, as All projects orders them. It is
   computed once per conversation, again after `/clear` or a compaction, and
   again for a session resumed in a new process or by `/resume` (live). It
   tells Claude to join the matching one by id, and says which one this
   window already holds.
5. A resumed conversation, holding nothing, takes up by itself the work it
   was last seen in, in whichever project: by its heartbeat, else the latest
   item or status it posted. Sending into a work's inbox, or having started
   it, is not being seen in it. A finished work is never taken up by itself,
   nor an older one in its place: the conversation had moved on from those.
   - Resumed in a new process (`--resume`, `-c`), it keeps its session id but
     not `$.state`. The process computes the listing before its session
     starts (live), so the rejoin runs there first, for the listing to name it.
   - Resumed by `/resume` in this process, the conversation that ended lets go
     of its work (`session.end`), and no `session.start` follows. The engine's
     `SessionStart` with source `resume` names the resumed conversation;
     `$.session.id()` still names the one that ended at that moment (live), so
     the window rejoins as the event's session id.
6. A window that never starts or joins a piece of work shows nothing on the
   board. That is the best effort.

A piece of work is **open** while at least one window is attached to it.
Nothing goes in the repo: no dotfile.

**Projects are named by Claude, never taken from a folder.** Lee may start
Claude in their home folder and talk about sitrep, and a brand new project
may have no folder or repository yet; what matters is the project being
discussed. So `start` names its project, as Lee would say it and cased
(`SitRep`, never `sitrep-1a2b`), and may say where it lives:

- A project on the board whose name matches takes the work, matched
  ignoring case, spaces and punctuation (`Sitrep` and `Sit Rep` are
  SitRep's); the project keeps its own name, and the answer says which
  project the work went into. A name alone is a project: there are no
  project codes.
- Else a new project is made of the name.
- A directory given is recorded for a project that has none. One that has
  its own keeps it, and the answer says so: the `project` tool changes it.
- The folder a session started in decides nothing: not the board's own
  project (the held work's), not what the first message lists (every
  current work), not where a join or a resumed conversation looks (every
  project). It only orders: projects whose directory holds it come first.
  A work still records it, as `root`: where the work was started.

A work is **current**, and shows in the project view, All projects and the
start-of-session listing, while it is open, has an ask waiting, has
something parked, or was updated in the last 7 days. An older idle work stays
on disk and out of the views; a project left with none drops out of All
projects altogether.

A work is **finished** once Claude or Lee marks it done, and is then never
current, whatever it holds: a session can end with things still open
because Lee closed the window. Its waiting asks count nowhere (tabs, band,
projects). A line posted to it later, by the CLI or anyone, leaves it
finished; only joining it again reopens it.

## Claude's side

Tools the mod registers, schemas loaded up front. **Only the main conversation
can call them**; a subagent is told to put it in its report, and the
orchestrator decides what reaches the board.

| Tool | Does |
|---|---|
| `start` / `join` | begin a piece of work (name, summary, its project's name, and its directory once known) and get its id; or join one by id, in whichever project it is filed |
| `status` | set the name, summary, the list of what is under way, and what is next |
| `ask` | post an ask: what it wants back (`wants`: a yes, a choice or words), its title, and where to look; a yes's button (`yes`: the verb Lee gives, `Go`, `Approve`, `It works`), a choice's `options`, or what a words ask's words are (`needs`: "the command's output"), each only on its own shape |
| `note` | add a log line, with optional detail lines and a pointer |
| `park` | park something to come back to |
| `resolve` / `reopen` / `edit` | close, reopen or correct an item, with a reason. An edit may change what an ask wants, its `yes`, `options` and `needs`, under the checks `ask` makes; an empty `needs` clears it |
| `finish` | mark the attached work done, with a reason, once it is complete and nothing is left on it; the window stays attached, and joining it again reopens it |
| `project` | rename the attached work's project, or say where it lives, or both; a name another project has is refused. It never moves a work to another project |
| `board` | read back the board's open items, what each ask wants back among them (`k1 wants a yes (Go)`), so Claude can check and repair it |

**When to start a piece of work**, in every conversation's first message
(added once a session started one with nothing to go on but the tools, and
named it in internal shorthand):

- Start one when the work will run across several turns or will need Lee: a
  feature, a design, an investigation. Not for a quick question.
- Name it in plain words, as Lee would say it, with no internal codes, and
  record its id wherever the project tracks the work.
- Touch the board only once it is clear which project the work is on: the
  project being discussed, whatever folder the session started in. When Lee
  carries on with a work on the board, join it; otherwise start one, naming
  its project as Lee would say it, by the name it has on the board when it
  is one there, with the project's directory once known.
- As it goes: the status when what's under way changes, an ask whenever Lee is
  needed (said in the chat as well), a note for what Lee would want later,
  never running commentary; resolve what's done; finish the work once it is
  complete, with nothing left on it.

Wording rules, in the tool descriptions:

- Ask only when Claude cannot go on without Lee, or Lee's judgement changes what
  happens next. Say it in the chat as well.
- Choose the shape by what Lee gives back: a yes for a go, an approval, "it
  works" or "done"; a choice for one of options; words when Lee must write
  something back. A yes's button is the verb Lee is giving, a word or two
  (`Go` for "Give the go for stage 3", never a stock `done`).
- One line, plain words, starting with the verb. No internal codes (no P-numbers,
  no D-numbers). "Where" says where to look in words: "In Paper: the dashboard
  file, page "round 1", frames 1–6".
- Notes are things Lee would want to know later, not running commentary.
- A changed status is logged by the board itself (it compares the new status
  with the last), so Claude does nothing extra for it.

When the board changes, its open items ride into Claude's next turn as unseen
context, so drift is noticed. A join answers with the whole board, and asks
Claude to correct anything on it that is stale against what it knows.
Dropped: a `/sitrep check` command, since the `board` tool already reads the
board back to repair it and Lee can ask for that in the chat; and a turn-end
check for an ask Claude forgot to post. The board is best effort, and in use
Claude has not drifted or forgotten.

## Lee's side

### The board: a tree, with this session as home

```
 ⌂ Dashboard redesign 3  ≡ All projects 8
━━━━━━━━━━━━━━━━━━━━━━━━──────────────────────────────────────────

Dashboard redesign · Switchboard
Redesign the dashboard, area by area in Paper

FOR YOU ──────────────────────────────────────────────── 3 waiting
◆ Review Sessions & Runway, round 1                             2h
└ In Paper: the dashboard file, page "round 1", frames 1–6
  [ ✓ Approve ] [ ✎ comment ] [ ✕ ignore ]
  Your reply waits in Ready to send. Ignore tells Claude you've
  seen it and won't act on it.

◆ Give the go for stage 3                                       3h
└ → Go · not sent yet ↺ undo ✎ comment
◆ Choose how long the ledger keeps requests                     3h

STATUS ─────────────────────────────────────────── updated 12m ago
• Waiting on your review of Sessions & Runway, round 1
• Drawing Usage, round 2
◦ next: Usage, round 3

LOG ──────────────────────────────────────────────── what happened
• Status: now also drawing Usage, round 2                      12m
• PR #82 merged                                                 1h
◇ Picked up from parked: A tmux indicator                       2h

PARKED ──────────────────────────────────────── 2 to come back to
◇ Paper thumbnails inline in Ghostty                            1d
◇ A Space-aware notes window                                    2d

DONE ──────────────────────────────────────────────────── 4 closed
✓ Review the dashboard's Overview, round 2                      1d
✓ Grant Ghostty notification permission                         1d
✓ Run the production apply                                      2d
show all 4
```

- **The header never changes its tabs.** Every place draws the same two:
  home, as `⌂`, this session's name and its waiting count, and
  `≡ All projects` with what waits across every project. Home is lit at
  home; anywhere else (All projects, a project's view, this project's
  included, any session's but this one) All projects is lit. Home's name is
  what it is pressed by, wide enough for a thumb, and is cut short to fit:
  All projects keeps its full width, and the name takes what is left. With
  no work held, the board says so, and there are no tabs.
- **Inline, the tab row ends with a wide close**, `[ ✕ close ]` at its
  right end, over plain rule: on the phone the band is not shown while the
  board is (they share the row above the prompt, and the board takes it),
  and the frame's ✕ is one cell. Its width comes out of the name's, so the
  row stays one line. Docked, there is none.
- **Browsing, the way back** sits in the row under the tab rule, at its
  left, one level up: `← All projects` over a project's view,
  `← <its project>` over a session's, a plain press drawn dim, cut short
  at the board's edge. Home and All projects have none, and the row is
  blank. It carries no `⌂`: the first tab is always home.
- The header is the tabs, their rule and the way back's row, the same
  height in every view. Docked or inline, there is no row above the tabs:
  they are the board's first line. There is no collapse: the phone's board
  and the docked one start alike. Docked, the header stays still at the
  top while the list scrolls under it, its way back too, as Ready to send
  stays still at the foot; inline, it is the board's first rows, and
  scrolls with it, its close too.
- A view's title line takes the whole width: its grey aside is cut first,
  then its title, with an ellipsis, so the line stays one row.
- **This session** (home, the default): name and summary, For you, Status, Log,
  Parked, Done. What waits on Lee comes first.
- **All projects**: this project first, then the busiest. Each project's open
  sessions hang off it as a tree. A project with nothing open, waiting or parked
  folds into one line at the bottom. A project opens its view.
- **A project**, reached from All projects, named as it is (`SitRep` stays
  `SitRep`): its sessions, this one first (`⌂`), each with what it is doing
  and its waiting count; For you, every current session's asks, the newest
  first, each naming its session (`Request ledger: Keep the ledger…`) and
  answered right there as in a session's view; the project's log; and
  Parked, every session's parked items, each naming its session. A project
  has no Done.

  ```
   ⌂ Dashboard redesign 3  ≡ All projects 8
  ────────────────────────━━━━━━━━━━━━━━━━━━────────────────────────
  ← All projects
  Switchboard · 2 waiting on you

  SESSIONS ─────────────────────────────────────────────── 2 of 3 open
  Dashboard redesign ⌂                                      1 waiting
  └ Drawing Usage, round 2
  Request ledger                                            1 waiting
  └ Drawing the ledger schema

  FOR YOU ──────────────────────────────────────────────── 2 waiting
  ◆ Dashboard redesign: Review Sessions & Runway, round 1        2h
  ◆ Request ledger: Keep the ledger 400 days, or forever?        3h

  LOG ──────────────────────────────────────────────── what happened
  • Request ledger: Wrote the schema                             1h

  PARKED ─────────────────────────────────────── 2 to come back to
  ◇ Request ledger: Export the ledger as CSV                     1d
  ◇ Dashboard redesign: A tmux indicator                         2d
  ```

- **Another session** is the same view as this one, in the same order: For
  you with buttons that answer it, its status, its log, its parked, its
  done. While no window has it, its foot (above Ready to send) has
  `✓ mark this work done`, for a session Lee left with things open by
  closing the window. It asks first, in place:
  `Mark <name> done? Its open asks stop counting.`, `[ yes, mark it done ]`
  `[ cancel ]`. Yes writes the finish into that work's folder, in this
  window's own file there (nothing goes to its inbox: it is Lee's act on the
  board, not a reply to Claude), and the board goes up a level, the work gone
  from it. A work with a window is still being worked: Lee finishes it there
  by telling Claude.
- **For you:** each ask is a list's row (see Look): its mark, its title in
  white clipped to one line, its age on the right, and no `where`, docked or
  inline. A reply waiting on it, or on its way, still hangs from it as its
  one branch, as a pick-up hangs from a parked row, so what waits to be sent
  shows at a glance. A new ask arrives opened. Opened, an ask shows its whole
  title and its tree from the mark: what a words ask's words are (`needs:`)
  first, then where to look, its `see`, Lee's comment once Claude has it and
  the ask stays open (`you commented: “…”. Claude has it.`), and the reply or
  `answering in the prompt…`; then its buttons and the hint, with a blank row
  after them, so the next ask does not run into them. There is no blank row
  between asks otherwise. An ask Lee's send just closed keeps the same row
  for a moment: a green `✓`, its title faint, `sent, and Claude has it`.
- **Done:** a section of its own at the foot of a session's view, under Parked,
  drawn once an ask has closed. Its heading counts the asks closed before
  now, ignored ones aside (`4 closed`), and it lists the latest 3, the newest
  closed first. With more, `show all 4`, dim, opens it to every one and
  then reads `show fewer`. That toggle alone opens and folds it: opening or
  closing an item, in DONE or anywhere on the board, never changes how many
  it shows; closing the board folds it. Each is a list's row: a green `✓`,
  its title, and how long ago it closed. Opened, as any item opens, it
  shows its whole title and hangs how it closed: the reply that closed it
  (`→ Approve`, `→ Forever`), or `resolved by Claude: <reason>`. Folding
  DONE closes an ask opened past the latest 3, no longer shown. For you
  holds only what is open, and the asks Lee's send just closed, for a
  moment.
- Each tab carries what waits there: home, this session's asks; All
  projects, every project's.
- Each view's first line sits under the way back's row.
- Every section heading has a few words on the right: `1 waiting`,
  `what happened`, `updated 12m ago`, `2 of 3 open`.
- **Log lines open** to the detail behind them, as a tree. A project's log
  names each line's session before its text (`Request ledger: Wrote the
  schema`). A status change's detail lines open with their labels (`Added:`,
  `No longer:`, `Still there:`, `Next:`, `Name:`, `Summary:`), and any
  item's pointer with `see`, each label in its item's colour, the text after
  it soft. A note's own detail lines, as Claude wrote them, carry no label.
- **Parked:** a section of every session's view, under Log, and of every
  project's, drawn only while something is parked there, its heading
  counting it (`2 to come back to`). A session's lists only its own items,
  a project's every session's, each naming its session; the oldest first.
  Each is a list's row: a purple `◇`, its title, and its age. Opened, its
  tree hangs from the mark: where to look, its `see`, and the pick-up once
  one waits or is on its way; `pick it up` and `✎ with a comment` sit under
  the tree until then. The pick-up queues in Ready to send like any reply;
  its comment is written in the prompt as an ask's is, and goes with it as
  its note (see "Answering an ask"). It is never counted: not on a tab, nor
  on the band.

### Answering an ask

An ask wants one of three things back, and that chooses its buttons. No
shape is ever shown as a word:

| Claude asks for | Buttons |
|---|---|
| **a yes**: a go, an approval, "it works", "done" | `✓ <its yes>` · `✎ comment` · `✕ ignore` |
| **a choice** | one button per option · `✎ comment` · `✕ ignore` |
| **words**: an answer, a command's output, feedback | `✎ Answer` · `✕ ignore` |

- **The yes is in Claude's words.** Claude gives the button's label as the
  verb Lee is giving: `✓ Go` on "Give the go for stage 3", `✓ Approve`,
  `✓ It works`, `✓ Ship it`. A word or two, 20 characters at most.
- **What the words are.** A words ask may say what its words must be, in a
  few words, as `needs`: "the command's output", "which frames you'd
  change". It hangs first from the ask's mark, in the ask's colour, as
  `needs: the command's output`, while the ask is opened. Only a words ask
  takes it.
- **Ignore** tells Claude Lee has seen it and won't act on it.
- **What a reply does once Claude has it:** a yes, a choice or an answer
  closes the ask; ignore drops it; a comment leaves it open, replied, for
  Claude to act on.

**Lee writes in Claude Code's own prompt box**, where a paste works, and the
words still wait in Ready to send with everything else, sent in one go.

1. `✎ Answer` (a words ask) or `✎ comment` (a yes or a choice) puts the
   window in **answering** mode for that ask; `✎ with a comment` puts it in
   the mode for a parked item's pick-up, all that follows holding for it as
   for an ask. It is held in `$.state` (`answering`: the item, whether it
   is an answer, a comment or a pick-up, its title, the surface it was
   begun on, and any words it put in the prompt). Only with the prompt
   empty: a draft there is refused with
   `The prompt has a draft in it: send or clear it first, then answer.`,
   since its Enter would answer with that draft. Words the mode itself put
   there are no draft: they give way to the new mode's.
   - The mode stands from the press, for an ask the board draws anywhere,
     and is checked against what the board draws: another session's ask in
     a project's For you is drawn from that work's brief, and the mode
     stands on the brief, while the press has the board read that work in
     full at once. A mode whose ask's work the board has not read is
     neither shown nor ended.
   - A plugin cannot give the keyboard to the prompt box: `$.ui.focus` moves
     only a site's own focus ring, while that site holds the keys. A press on
     the board leaves the keys with the board, so Lee presses Escape once to
     reach the prompt.
   - The item hangs `answering in the prompt…`, and its buttons give way.
2. **The band says only that**, in place of its counts, the whole time:

   ```
   ✎ Your next Enter answers "Run sitrep list…"  ↓                         cancel
   ```

   (`comments on` for a comment, `picks up` for a pick-up; a comment that
   closes its ask, as one on an old decide does, is an answer, and says
   `answers`). It shows on the band of the surface the mode was begun on,
   and only there. `cancel` ends it, in one press. Escape at
   an empty prompt cannot: it edits nothing, so `prompt.edit` never hears it
   (a probe, 2.1.295, heard typing, pastes and Backspace, never Escape).
3. **The next Enter is taken.** The `prompt.submit` hook takes Lee's own
   prompt from the surface the mode was begun on (origin `composer` at the
   terminal, the Remote Control `bridge` that Claude's app sends through),
   drops it so nothing reaches Claude, its reason the transcript's one line
   (`Your answer waits in Ready to send.`, or `Your comment waits…` for a
   comment that leaves the ask open, `Your pick-up waits…` for a pick-up),
   and empties the box once the drop settles, since the engine puts a
   dropped prompt back. A prompt from the
   other surface goes to Claude, the mode standing; so does one while a
   survey holds the band in its place, which hides the mode there: it is
   shown, and takes the next Enter, once the band is back. The text becomes:
   - on a words ask, its `answer`;
   - a comment, on an ask with a yes or a choice already queued, that
     reply's note (`→ Go, with a comment: “…”`); else a `comment` of its own;
   - on a parked item, its `pickup`'s note (`pick it up, with a comment: “…”`).

   A paste arrives in the submitted prompt wrapped
   `<pasted_content id="…">…</pasted_content id="…">` (live, 2.1.295;
   undocumented): it is unwrapped onto lines of its own, the words typed
   around it kept in place. An empty Enter, or one with something attached,
   is not taken: a toast says why, the prompt stays in the box, and the mode
   stands.
4. **Queued, the reply shows on one row**, under the ask and in Ready to
   send: its words clipped to a line, `+3 lines` when there are more, then,
   under the ask, `· not sent yet ↺ undo ✎ edit`. `✎ edit` enters the mode
   again for that reply, the prompt filled with its words (still only from
   an empty prompt), and the next Enter replaces them. A bare yes or choice
   offers `✎ comment` there instead, which adds its note; a bare pick-up,
   neither.
5. **One send carries everything**, as ever.

**The mode is safe to be in:**

- **One Enter only.** It ends with the prompt it takes, and never takes a
  second.
- **Always shown.** The band shows it the whole time it stands, on the
  surface it was begun on, and it stands exactly while the next Enter there
  would be taken. Once its ask can take the reply no longer (closed, or a
  parked item picked up, its work done, a reply already on its way, a send
  carrying the reply its comment would join) the band is back to its
  counts, the next Enter goes to Claude, and the next look ends the mode, so
  the ask, reopened, does not take it up again. Its work is read at every
  look, the board open or not, for that.
- **Easy out.** Cancel is one press.
- **Typed messages are safe.** A prompt Lee sends while not answering goes
  to Claude as ever, and so does one not of Lee's own (a background task's)
  while answering.
- **It ends** with its ask, as above, a send carrying its reply ending it
  as the send is claimed; when the window takes up another work or lets go
  of its own, the session's end among them. A reload keeps it, in
  `$.state`, and the band still shows it.
- **It leaves nothing behind.** Ended without taking an Enter (cancel, its
  ask closing, its work done, a send carrying its reply, another ✎, the
  window letting go), the mode takes back the words it put in the prompt
  for `✎ edit`: still just those, the box is emptied, so no Enter sends the
  board's words to Claude; changed since, they are left as Lee has them,
  and a toast says so.

**Surfaces.** The terminal's prompt is read, filled and heard, so it gets
all of this; the phone over mosh is the terminal. Claude's app (the
`mobile` surface) sends its prompt through the Remote Control bridge, which
the hook hears (so the engine's types say; not yet tried live), but the mod
cannot reach its box: `✎ Answer`, `✎ comment` and `✎ with a comment` work
there, and `✎ edit` is not offered. Desktop and VS Code send theirs some way
not yet seen, so they offer nothing to write: a words ask is only ignored
there, a parked item only picked up, and Lee says the rest in the chat.

**What Claude reads.** A reply's line gives an answer under what its words
are (`- Run the export → the command's output: “v1.2.3”`, `answer:` where the
ask said nothing), a yes in its own words (`→ Go`), a choice as its option,
and a note as `with a comment`. A note of one line is quoted on the reply's
line. Words of several lines (pasted output) go under it, fenced and
indented, each line as typed, the fence longer than any run of backticks
inside; so does any note of several lines, a comment's or a pick-up's alike.

````
- Run the export → the command's output:
  ```
  exported 42 rows
  done in 3s
  ```
````

**Asks written before they said what they want back** read as the shape
their kind maps to (see Storage): a review as a yes in `Approve`, a try in
`It works`, a do in `Done`, a decide as a choice, and any that needed
something back as words. The replies written to them keep the meaning they
had: a yes or a choice still closes one now read as words, and a decide's
comment is still its answer, closing it, so its button reads `✎ answer`,
the band `answers`, and the transcript `Your answer waits…`. An edit that
leaves such an ask's shape as it is keeps its kind (see Storage), so the
replies queued for it, or on their way, keep their meaning.

### Ready to send

Everything Lee does on the board queues here first; nothing goes one press at
a time. The box sits at the foot of **every** view of the board while anything
waits in it, grouped by where each reply goes (`to this session`,
`to Request ledger`, a session of another project with its project's name).
Each reply hangs off its item with a `└`, on one row: its words clipped to a
line, `+3 lines` where there are more, and `✎ edit` to write them again in
the prompt (`✎ comment` on a bare yes or choice). Each has its own `✕`, and
the ask shows `↺ undo`. **send to Claude** sends them; **cancel all** clears
them.

**Docked**, the box stays still at the foot of the board's window, under
the board's list, which scrolls between it and the header; the list's last
line scrolls clear of it. **Inline** (the phone) it sits at the end of the
content. Each of its lines keeps to one row, cut short, so its height
follows from what it holds. Docked it takes under half the window: a queue
too long for that lists what fits and ends `… 3 more`, still one box. Only
Lee moves the list: queuing a reply, sending, a new ask arriving and the
board drawing again leave it where Lee had it, and only a list that shrank
under it stops it short at its new end. Each place starts at its top,
every time the board goes there: by a tab, the way back, a session's or a
project's row, or a band count, even one landing on the place already
showing; and so does the board opened again. Opening or closing an item
leaves the list where it is. Tab and the arrows step between buttons, and
one below the fold brings its item into view; a click never moves the list
(see "One engine, two front ends").

On an inline board (the phone layout) a send closes the board as soon as it
is claimed: the message to this session claimed, or, with none, the replies
written into other works' inboxes. It never waits for Claude Code to take
the message, which can take minutes while Claude is mid-turn. A send that
Claude Code refuses still toasts and leaves its replies queued, and the
board, opened again, shows them; a send that sent nothing leaves the board
open. A docked board stays open.

A group sent into another work's inbox stays in the box, its replies out of
the queue, until Claude has them all, and 10 minutes after, so
`delivered 2m ago` can be read. A closed work's group stays until it reopens.
A reply whose item changed before it went in (see Delivery) shows as
`not delivered: it changed since`, and lingers out the same way.

### The band

One line above the prompt, right-aligned counts only, each one a way in:

```
                                         ◆ 1 for you   2 elsewhere   ▸ show board
```

`for you` opens this session; `elsewhere`, what waits on Lee in every other
current work, in every project, opens All projects. Below 64 columns the
words drop and the counts stay (`+2`), and the answering line says `Enter`
for `Your next Enter`, to leave the title room. The board's show/hide button
always matches whether it is drawn. Where the board sits inline and its
frame's ✕ is one cell, the open board's button is a wide `[ ✕ close ]`
instead, its words kept at any width; on the phone, where the band is not
shown while the board is, the board's tabs end with the same close. Where the board sits is
where Claude Code seated it, which only the board's drawing knows: never
guessed from widths, since beside a docked board the band's columns are the
transcript's. A `Client` in the board's header (`hooks/draw/placement.tsx`)
posts the placement it was drawn with on its surface as it changes, and the
window keeps the last one each surface said, across closes, so a board
opened again gets the right button from its first frame. Docked, not yet
said, or on a surface whose board draws no `Client`, it is `hide board`.
While Lee answers an ask in the prompt, the band says that instead, and only
that, with `cancel` (see "Answering an ask").

The band shares the area above the prompt. What another plugin draws there,
such as the workflow-gates mod's gate rows, stays, stacked above the band,
so the band keeps the row on the prompt, which the answering line's `↓` points
at. The plugins beneath are given `maxRows` less the band's one row, so a
gate sized to what it is given still fits whole beside it. A plugin
loaded outside sitrep that stacks itself above what is beneath it lands in
the same order. With nothing else drawn there, the band is the whole tree,
as before (11 October 2026: until then the band dropped everything beneath
it once it had a work to show).

When a new ask lands: the ◆ pulses, a toast names it, and a soft chime plays.
Dropped for now (11 October 2026): a macOS notification for asks. Back on
13 October 2026, from the menu bar app (see "The menu bar").

## Delivery

**The board never claims Claude knows something it was not told.**

- Replies for **this** piece of work are sent as Lee's own message
  (`$.prompt.submit`, `asUser`), marked "From the board:". The board changes
  only once Claude Code takes it; a refused send leaves every reply in place.
  If Claude is mid-turn the message waits for that turn to end.
- Replies for **another** piece of work go into that work's inbox in the shared
  folder. The sitrep mod in that work's window picks them up and submits them as
  Lee's message (not as a message between agents, which Claude would give less
  weight). It writes back a delivered mark.
  - open and idle: in within a second or two;
  - mid-turn: waits for the turn to end;
  - no window open: waits in the inbox, goes in when the work is joined again.
- The send box shows each destination's state (`✓ delivered`, `⧗ waiting for its
  turn to end`, `○ closed: goes in when it reopens`, `✕ not delivered` once
  every reply went void), each ask shows
  `delivered 2m ago` or `on its way`, a toast sums it up, and the receiving
  window's band flashes `✦ 2 replies from the board` for 5 seconds. In the
  destination's own view, an ask whose reply is on its way says so and offers
  no second answer.
- The receiving window delivers only while it is the work's deliverer.
- **One message in flight per window**, whatever its source: this work's
  send, or the inbox. It is claimed in `$.state` before it is submitted, and
  holds its source, the work it goes to (project and work), the writer that
  claimed it, the text exactly as submitted, the replies it carries, when it
  was claimed, and whether Claude Code has taken it. The replies' ids are
  fixed at the claim: a send's are made then; the inbox's are the replies
  whose lines the message holds, no others. While it is in flight a look
  submits nothing, and a send says it waits for the inbox's replies.
- **Taken** is heard from the submit resolving with no drop, or from a turn
  starting whose text is the message's; whichever comes first marks it taken
  and writes it down. A load that starts with a message taken but not written
  down writes it down.
- **Written down** in the work it went to, whatever the window holds by then:
  through the hold when the window still holds that work as that writer, so
  the hold's own text stays in step; else into that writer's file there, read
  back and written whole. A send writes each reply and one delivered mark; the
  inbox, one mark naming its replies. Writing first reads the work: lines
  already there, or replies already marked, are not written again, so writing
  down twice writes once. A write that fails is tried again at the next look.
- **Refused** (a drop, or a throw): let go at once, its replies left as they
  were; the next look, or Lee's next send, tries again.
- **Never taken** (Lee deleted the queued prompt, or the submit was lost): let
  go once the session has gone quiet without it, 30 seconds after a turn of
  the main conversation (or the conversation) ended with no turn starting
  since. A queued prompt goes in as the turn before it ends, its own turn
  starting about 40 ms after (live), once the prompt's hooks have run; so a
  message still unheard by then was never going in, and letting it go never
  sends it twice. A send's replies are back in Ready to send, and a toast
  says so; the inbox's wait for the next look.
- A reply on its way whose item an edit changes so it no longer fits (an ask
  wanting a yes made to want a choice under Lee's yes) is **void**: no message carries it, a mark
  naming it changes nothing, and the item can be answered again.
- The inbox message is the board's own, as this work's is: it takes no
  board-change context, and written through the hold its lines are lines
  Claude knows of (`postKnown`). The rest rides in with Lee's next prompt.
- An ask's life: **open → replied → closed**. The board never closes an ask on
  a press, only once Claude has been told: a delivered reply closes it, or
  Claude resolves it. An ask open past a day shows its age. Nothing ages an
  ask out: Claude keeps the board clean, and Lee may be
  away for days and come back to the work.

## Storage

```
$XDG_STATE_HOME/sitrep/, else ~/.local/state/sitrep/
  projects/<project key>/
    project.json              name, directory, created and by whom: the project's own
    works/<work id>/
      work.json               name, summary, project, root, created and by whom: written once, by whoever starts the work
      <writer>.jsonl          one file per writer: each window as its session id, the CLI as `cli`
      inbox/<sender>.jsonl    replies from other works, one file per sending writer
      presence/<writer>.json  each attached window's heartbeat
```

- **Project key:** a new project's name as a slug, accents dropped
  (`sitrep`), numbered on (`sitrep-2`) where a folder already has it. The
  key is only where its files are; the name in `project.json` is what
  matches and shows.
- **`project.json`:** `{ v, name, directory?, created, by }`. A start writes
  it as it makes the project, and the `project` tool as it renames it or
  gives it a directory; a start giving a directory to a project with none
  writes it too. It breaks the one-file-per-writer rule below: whichever
  writer makes the change rewrites it whole, and the last write wins. That
  is fine for a file rewritten only that rarely, by Claude, at Lee's word.
- **Folders from before projects were named** keep their keys
  (`code-84dbac88`, `switchboard-7a75d7ba`, from the folder a session
  started in): nothing moves. Without a `project.json`, such a project is
  named as its works' `work.json` recorded it, its first letter a capital
  (`Code`). Matching and showing read `project.json` first, so writing one
  there (the `project` tool does, from a window holding one of its works)
  relabels the project in place.
- **Work id:** `sr-` and six characters (`sr-k3f9qa`): short enough for Claude
  to record, and easy to grep. Items and replies get four characters, unique
  within their work.
- One file per writer, so there are no locks and no daemon. A mod's `$.fs` can
  only write whole files, so each mod rewrites its own file; the CLI appends.
  Runs of the CLI at once share its file: each run's line lands whole (tried
  with 20 runs at once, and lines up to 200 KB), and two runs that read the
  file together write the same count, which reading never minds: it orders by
  time, then writer, then count, and keeps both.
- Each line is one JSON object: the format's version, the time, the writer's
  own count, the kind, then its fields.

  ```
  {"v":1,"at":1760000000000,"seq":4,"type":"ask","id":"k3f9","wants":"yes","yes":"Go","title":"Give the go for stage 3"}
  ```

  An ask's line holds what it `wants` back (`yes`, `choice` or `words`) and
  its `title`; a yes ask its button's words, as `yes`; a choice its
  `options`; a words ask, where it says, what its words are, as `needs`; and
  `where` and `ref` where it has them. An edit's changes name the fields
  they set; an empty `needs` clears it, where any other empty field is
  refused. An edit leaves an ask holding only what its shape takes: one
  made to want a choice drops its `yes`, one made to want a yes its
  `options` and `needs`. A reply's verdict is `yes`, `choose` (with its
  `option`), `answer` (a words ask's words, as its `note`), `comment`,
  `ignore` or `pickup`; a yes or a choice may carry a comment as its note.
  The format's version stays 1: a new reader reads every old line, and an
  old reader skips an ask line it cannot read, as it skips any.

  **Asks written before they said what they want back** have a `kind` in
  place of `wants` (`review`, `decide`, `try` or `do`), and some a `needs`.
  They still read, by the shape their kind maps to: one with `needs` wants
  words; else a decide wants a choice, and a review, a try or a do a yes in
  `Approve`, `It works` or `Done`. The ask keeps its kind as read, so the
  replies written to it then keep their meaning: it still takes the verdicts
  its kind took (a yes or a choice on one now read as words), and a decide's
  comment, its answer then, still closes it. An old edit naming a `kind`, or
  changing `needs`, reshapes such an ask by the same map. An edit written now
  that changes one of them's shape (its `yes`, `options` or `needs`) names
  what it `wants`, which it then wants from that edit on, its kind gone; one
  changing only its title, `where` or `ref` keeps its kind, so the replies
  queued for it or in an inbox keep the meaning they had.

  The kinds: `status`, `ask`, `note` and `park`; `resolve`, `reopen` and
  `edit`, each naming an item; `reply`, Lee's answer to one; `delivered`,
  naming the replies Claude has been given; `finish`, the work marked done,
  saying who (`lee` or `claude`) and with an optional reason; and
  `unfinish`, a window joining it again. The work holds the latest finish,
  when, by which writer and why, until an unfinish clears it. Who is a field
  of its own because Lee's board and Claude's tool write as the same
  window.
- Reading merges every writer's lines into one order: time, then writer, then
  count. A reader can catch a file mid-write, so a torn last line, a bad line
  or one of a kind or version it does not know is skipped, never fatal.
- The status shown is the latest across writers. A status change is logged by
  the board as it reads, comparing each status with the one before; it is
  never written down.
- A reply counts as delivered once a writer **in its work** has written a
  `delivered` mark naming it, while it still fits its item: an edit before
  the mark voids it. For this work, the mod writes the reply and the mark
  together, once Claude Code has taken the message. For another work, the
  sender writes the reply into that work's inbox, and the window that submits
  it there writes the mark to its own file. Only replies count from an inbox.
- **Presence:** a mod can't tell that its own window died, so each attached
  window rewrites its heartbeat (`attachedAt`, `seenAt`) every 30 seconds, and
  a work is open while a heartbeat is under 90 seconds old. A mod can't delete
  a file either, so a window that lets go adds `leftAt`. Of several windows on
  one work, the one attached longest submits its inbox, so two never both do.
  A heartbeat also says `where` its window is, as far as that is known (see
  "The menu bar"): `device`, `terminal`, and `tmux` with its `socket` and
  `pane`. It is read field by field, a bad one dropped, and a heartbeat is
  never lost over it; one written before it reads as ever.
- Readers list and `stat` the folder every second or two (a mod cannot watch
  files) and read only what changed; each work's read lists its project's
  folder too, so a rename shows on every board within a look. The works
  around the held one are read every 5 seconds, each through its reader:
  they are glanced at, not watched. Every project is read, the board open
  or closed, for the band's `elsewhere` and the All projects tab: each look
  lists every work's folders and reads again only a file that changed. With
  the board open, the session it looks at and those replies wait for or
  went to are read in full too, and so is the work of the item Lee is
  answering in the prompt, open or not, read at once as the press begins
  answering it.
- The board's last view lives in the session's `$.state` only: where it
  looks, the item opened there, and, apart from that, the work whose DONE
  shows every closed ask, and where Claude Code last seated the board on
  each surface, kept when it closes (see "The band"); a pane an older load
  saved, without either, reads as none. `$.store` is unused so far.

## One engine, two front ends

- **core**: a plain TypeScript module, no file system, no Node: the folder's
  format, the event shapes, the rules (what a reply does to an ask, what counts
  as waiting, what folds away). Tested on its own.
- **the mod**: Claude Code's hooks module. Draws the board and the band;
  registers Claude's tools; reads and writes through `$.fs`.
  - The engine reads a hooks module's calls on `$` off its source, and will
    not load one that hands `$` to an import, or whose `$.state` values are
    not consts of the file that reads them. So `hooks/register.tsx` spells
    every call on `$`, and hands the other modules a host bound to it.
  - `$.state` holds JSON data, which keeps no Map or Set, so the folded work
    sits there as plain data, its items and ids as lists. It outlives a
    reload of the mod's code, and the window takes its work up again; a new
    process (`--resume`) starts without it, and the window takes up by itself
    the work its conversation was last seen in (item 5 under "Pieces of
    work").
  - Drawing lives in modules of its own (`hooks/draw`): pure functions from
    a surface's element table and plain data to a tree, what a button does
    handed in as actions bound to the host. JSX's `h` is global in every
    module of the plugin. What a surface can do beyond drawing (whether Lee
    can write back from it in a prompt the mod hears, and whether the mod
    can fill that prompt) is read off `e.surface`. An item's address is its
    work's id then its own (`sr-k3f9qa:k3f9`): what opens it, and every
    button of its, keyed by it (`pick:sr-k3f9qa:k3f9`), since a project's
    view and Ready to send list several works' items, and two works' items
    may share an id.
  - Docked, the board scrolls its own list, clipped above Ready to send
    (settled by a probe and a live run, 2.1.295). A box floated over the
    foot of a tree the engine scrolls, placed again on every drawing,
    flickers by design: the engine paints the scrolled frame before the
    drawing that puts the box back (26 of 195 frames, live). So the engine
    is given nothing to scroll.
    - **The engine.** The tree is a row shorter than the window, so the
      engine's window never moves, and that row tells a page key (the
      window's rows) from Home and End (the tree's). The scroll hook holds
      the engine at the top (`offset: 0`).
    - **The board.** The header (the tabs, their rule, and the way back's
      row) sits at the tree's top, still. The list sits in a box of the
      rows between it and Ready to send, clipped (`overflow: "hidden"`),
      and shifted up by how far down it stands (`marginTop`); Ready to
      send sits under it, still, its last row past the tree's end,
      which paints. The list's rows are the window's, less the header's, and
      less Ready to send's or, with nothing in it, the tree's spare row; the
      header's rows are the same everywhere, and Ready to send's follow
      from what it holds. How far down the list stands is kept in
      `$.state` with the place it was moved at; every way to a place
      forgets it, so the place starts at its top though Lee had been down
      it before, and closing the board forgets it. The scroll hook moves it: the
      wheel as it turns, a page key by the rows showing, Home and End to the
      ends, stopped at either. Nothing else does: the drawing only stops it
      short at the end of a list that shrank, or of a window that grew. It
      clips always, docked, not only while Ready to send holds something:
      switching between the engine's window and the board's own as the
      queue filled would move what Lee is looking at.
    - **Measuring.** The view is drawn as a list of blocks: the line under
      the header, each section's heading, each entry of a list (an
      ask, a log line, a parked item, a closed ask, a session, a project),
      Status whole, the foot, and a blank row closing the list; the blank
      row between sections is the next block's own. Docked, a `Client`
      spans each block down the column the board keeps free beside its
      lines (`hooks/draw/measure.tsx`), drawing nothing, and posts the rows
      the block takes whenever they change. It is keyed by its block, a
      work's item by its address. The list is as tall as its blocks, and a block sits as far
      down as those above it; one not measured yet counts a row. Each
      measures once as it is laid out, and again as it grows or the width
      changes (about 140 posts over a long live run). The rows and the list
      as last drawn are kept in a module, since a render hook cannot write
      `$.state`; a reload disposes the `Client`s, and new ones post again
      (live). The test kit lays a `Client` out with no rows, so a measuring
      `Client`, which waits for rows, never posts there: its tests post each
      block's rows as its `Client` would. A `Client` that posts as it draws
      (the board's placement) does reach the plugin under the kit.
    - **The focus.** Tab, Shift-Tab and the arrows all step between buttons:
      with nothing for the engine to scroll, an arrow has no rows to move.
      The focus hook brings the block holding the button Lee's focus lands
      on (origin `person`) into view, moving the least, from its top where
      it is taller than the rows showing; the header's own and Ready to
      send's always show, and never move the list. A plugin's focus move
      never moves it. A click on a button is a press, the focus left where
      it was (live, 2.1.295), so it never moves the list either; the
      engine's types count a click among the person's focus moves, which
      `ui.focus` cannot tell from Tab, so an engine that raised one would
      reveal the clicked button's item. Text with no button in it is
      reached by the wheel and the page keys.
    - **Dock only.** Inline, the board flows as it always has, the header
      first and Ready to send after the view, and the engine scrolls it; so
      does a dock on a surface that draws no `Client`. There, every way to
      a place puts the engine's window at its top (`$.ui.scroll`, to its
      `start`; live, 2.1.295). The test kit has no implementation of a
      mod's `$.ui.scroll`, so that is checked live only.
  - `$.prompt.submit` while Claude is mid-turn (settled in a live run): the
    call waits, the prompt never folded into the running turn; once that
    turn completes, the prompt starts a turn of its own and the call
    resolves as it starts. A hook holding the turn (`tool.call`,
    `command.run`, or a timer one of them started, while that hook runs) is
    refused the call, so the board submits from its send button's own
    handler.
  - The mod's own `prompt.submit` hook does not see a prompt the mod
    submitted from a button's handler or a timer (live, and in the test
    kit); from its `ui.press` hook it does. Either way the board's own
    message takes no board-change context: its replies are the change, and
    the rest rides in with the next prompt.
  - The same hook takes Lee's next Enter while Lee answers an ask in the
    prompt (see "Answering an ask"), before anything rides in with it, so a
    prompt it takes reaches nothing. A prompt it drops comes back to the box
    over a clear made while the hook runs (live), so the box is cleared
    100 ms after. The keyboard is the person's: a plugin moves only its own
    site's focus ring (`$.ui.focus`), so it cannot hand the keys to the
    prompt; and `prompt.edit` hears only what edits the box, never Escape at
    an empty one (a probe, 2.1.295).
  - `turn.start` carries a plugin prompt's text exactly as submitted. It and
    the submit's resolving come within a few milliseconds of each other,
    either first (live probes). Inbox delivery runs on a timer the session's
    start begins, never one a tool call began, so the engine never refuses it
    as holding the turn.
  - A reload mid-delivery, settled by live probes: a probe mod submitted a
    prompt while Claude was mid-turn, then was reloaded mid-turn.
    - `/reload-plugins` typed mid-turn queues and runs once the turn ends,
      before the plugin's waiting prompt goes in. The old load's submit never
      resolves; the prompt still goes in as its own turn, and the new load's
      `turn.start` hears its text.
    - A file-watch reload (`CLAUDE_CODE_PLUGIN_DIR_WATCH=1`, an edit
      mid-turn) is held until the turn ends too. The old load's submit
      resolves first, then the new load starts, and the reload can cut short
      what the old load does next: a write it began after the resolve was
      lost.

    So whichever load hears the message go in writes it down, and writing it
    down twice writes once (see Delivery). A live run with two windows
    checked it end to end: a reply sent into another window's inbox went in
    and was marked once; a send of this window's own reply, made while
    Claude ran a 40-second command, with `/reload-plugins` typed during it,
    went in after the reload and was written exactly once, closing its ask.
  - The test kit cannot load a fresh copy of the mod: a test's reload runs
    `session.start` again in the same module, its variables kept. Everything
    a reload must carry over lives in `$.state`, so the tests model each
    settled behaviour by what the old load's submit does: never resolving,
    the new load hearing the turn start; or resolving with its writing cut
    short, left as a message taken but not written down, which the next load
    writes once (tests/flight.test.tsx).
- **the CLI**, `sitrep`: runs on Bun, reads and writes through the file system.
  For scripts and other tools: a Paper generator posting "round 3 drawn", and
  later the tmux indicator.

  ```
  sitrep note <text> [--detail <line>]... [--ref <ref>]
  sitrep ask <title> --wants yes|choice|words [--yes <label>] [--option <choice>]... [--needs <words>] [--where <words>] [--ref <ref>]
  sitrep park <title> [--where <words>] [--ref <ref>]
  sitrep status [--name <words>] [--summary <line>] [--now <line>]... [--next <line>]
  sitrep board [--json]
  sitrep list [--project <name>] [--json]
  sitrep jump
  ```

  - It writes as the writer `cli`, appending to `<work>/cli.jsonl`. It never
    writes a delivered mark or a heartbeat: it is never a window on the work.
  - What it posts is checked by core as Claude's tools' posts are, and a
    refusal prints the check's words. A post prints its item's id and nothing
    else, so a script can keep it. An ask says what it wants back with
    `--wants`, as the ask tool does, and its `--yes`, `--option`s or
    `--needs` with it. A status gives only what changed, as the
    status tool does; `--now ""` and `--next ""` clear. The last argument takes
    every word left, so a title needs no quotes.
  - The work is `--work sr-xxxxxx`, else `$SITREP_WORK`, looked up in every
    project. `list` takes none: every project's current works, grouped, in
    the order the first message lists them (those whose directory holds the
    folder the CLI runs in first); a finished work is never among them.
    `--project <name>` gives only that project's, matched as `start` matches
    it, and a name no project has is refused. `--all` is gone: every
    project is listed already. The CLI does not finish works.
  - Exit codes: 0 done; 1 a usage error, a refused input or a failure; 2 no
    such piece of work.
  - `list --json` is for tools, and stable: every field is always there (a
    list empty, any other value null where there is none), and `v` moves only
    with a change a reader would trip on. `here` is the key of the project
    the CLI runs in: the nearest whose directory holds its folder, else null.
    It is listed even with no current works, the first of `projects` unless
    `--project` leaves it out.

    ```
    { "v": 1, "here": "switchboard",
      "projects": [ { "key": "switchboard", "name": "Switchboard",
                      "open": 1, "waiting": 2, "parked": 1, "updatedAt": 1760000000000,
                      "works": [ { "id": "sr-k3f9qa", "name": "Dashboard redesign",
                                   "summary": "...", "now": ["..."], "next": null,
                                   "isOpen": true, "waiting": 1, "parked": 1,
                                   "updatedAt": 1760000000000, "onScreen": true } ] } ] }
    ```

    `onScreen` says whether a Ghostty window shows the work (see "The
    menu bar"). Only `--json` works it out, from tmux, asked twice per
    socket however many works there are; it knocks on nothing. Plain `list`
    runs no program.

    `board --json` is `{ v, project: { key, name }, work, asks, parked, log }`:
    the work as `list` gives it, its open asks, what it parked, and its latest
    log lines. Its `v` is 2 since its asks say what they want back (`wants`,
    `yes`, `needs`) in place of their kind; `list`'s stays 1.
  - `jump` brings the Ghostty window showing the work to the front, on
    whatever Space it is (see "The menu bar"), and prints nothing. A work no
    Ghostty window shows is refused (`Dashboard redesign is not on screen: no
    Ghostty window shows it.`), as is one whose devices no Ghostty terminal
    answered.
  - Answering an ask waits on open question 4. It would be one more command,
    a reply into the work's inbox, which the work's window already delivers.
  - Its logic is `cli/`, plain TypeScript beside core and tested in the test
    kit on a file system in memory; `cli/shell` binds it to Bun, and
    `bin/sitrep` runs that.

## Look

- Palette (Tokyo Night): ask `#e0af68`, new-ask pulse `#ff9e64`, log `#7aa2f7`,
  parked `#bb9af7`, ok `#9ece6a`, now `#73daca`, soft `#a9b1d6`,
  grey `#7a82ab`, faint `#565f89`, rules `#3b4261`, tab `#292e42`.
- **White:** anything clickable, and the main content.
- **Soft:** lines describing the item above them (a summary, what a session is
  doing, a reply, a log detail), and the line a section with nothing in it
  shows (`Nothing yet.`).
- **Grey:** ages, counts, heading notes. DONE's toggle is a quieter press, drawn dim (a
  Button's own `dimColor`: Claude Code 2.1.294 refuses a Button with a
  label and a coloured child, and blanks the board). **Faint:** closed things (a closed
  session, an ask Lee's send just closed), but not DONE's asks: each is a
  row to open, its `✓` green and its title white; and every tree's `│ ├ └`.
  Section headings' rules and the tabs' rule are the rule colour.
- **Colour:** glyphs, headings and amber waiting counts only; in the ask's
  amber, the `needs:` line of a words ask, since it is a request of Lee's,
  not a description; and a tree line's label (`Added:`,
  `see`), in its item's colour.
- Glyphs: `◆` ask, `◇` parked, `•` under way, `◦` next, `└ ├` trees, `⌂` home.
  No glyph that reads as "expand" unless it expands.
- **One row for every list.** A log line, a parked item, an ask in For you
  and a closed ask are drawn alike: the mark, the title (white, and the
  press that opens it) on one line, clipped, and the age on the right, in
  grey. Opened, the title shows in full, a `│` beside its further lines, and
  the detail hangs from the mark as a tree; an opened ask's buttons and hint
  come after its tree, at its title's column. A wrapped title is a press per
  line (a Button's label never wraps), all of them one hover group, a
  `hover` scope made from its press key, so the whole title lights
  whichever line the pointer is on.
- Breathing room: a column each side, a blank row under the tab rule
  where there is no way back, after an opened ask's buttons, between
  projects in All projects, and between sections; none between the
  entries of a list (log, For you, done, parked), nor between the tabs and
  their rule.
- No indents left floating: anything hanging off an item hangs from a `└`.

## Where it lives

Its own repository, `leeovery/sitrep`: private until sitrep is stable, then
public, which is half the point of its own repository. It began in kit, Lee's Mac
setup, at `shared/plugins/sitrep/` in kit's own marketplace, and moved out on
13 October 2026, its history split out with every commit kept, once this
design and stages 1 and 2 had merged there (kit-config #1 and #2). With the
CLI, the mod and soon an app, sitrep is a product, and kit's job is setting
up Lee's Macs. The board's folder (`~/.local/state/sitrep`) stayed where it
was: only where the code lives changed.

The repository holds the plugin, a one-plugin marketplace of its own
(`.claude-plugin/marketplace.json` at its root, its source `./`, as revdiff
is; the plugin is `sitrep@sitrep`), and from stage 3 the app, whose source
is `app/` (14 October 2026). One version and one release cover them all.
The whole repository is the plugin, so a plugin installed from GitHub
carries `app/` too; it is small, and accepted.

**Installing and updating**, decided with Lee on 14 October 2026: app first.

- **On a Mac, sitrep is the app**, from a Homebrew cask in `homebrew-tools`,
  and from nowhere else (no download of its own), so every install updates
  the same way: `brew upgrade`.
- **The app installs the Claude plugin.** On its first start, once it has
  asked for what macOS must grant it (banners, leave to control Ghostty,
  starting at login), it copies the plugin it carries to
  `~/Library/Application Support/sitrep/`, outside its own bundle, since
  anything written into a signed app breaks its signature; then registers
  that folder as the `sitrep` marketplace and installs `sitrep@sitrep`,
  through `claude plugin`. It finds `claude` where its installers put it,
  or by asking Lee's login shell: an app sees almost no PATH.
- **After `brew upgrade`** the app finds its newer self on disk, relaunches,
  and refreshes that copy of the plugin. One command updates both, and
  their versions never part.
- **Everyone else** (Linux, Windows, no menu bar wanted) installs the plugin
  alone from the GitHub marketplace: `claude plugin marketplace add
  leeovery/sitrep`, then `claude plugin install sitrep@sitrep`.
- **Ruled out:** the plugin first, its mod building the app whenever the
  plugin's version moved on (a Claude mod compiling a Mac app, and Xcode's
  tools wanted on every Mac); Sparkle, since `brew upgrade` already updates
  a cask; the Mac App Store, whose sandbox forbids running another program
  (even tmux's queries), controlling Ghostty, and writing Claude's settings.

**Until the first release** (stage 4): this Mac reads the plugin from the
clone, `~/Code/sitrep`, as a folder marketplace, so an edit plus
`/reload-plugins` is a change, and the clone's checkout is the code every
window runs: work happens in a worktree. The app is built locally, by
`app/build` (stage 3). kit's `[manual]` step installs the plugin from the
GitHub marketplace on any other Mac until the cask exists.

**Versions side by side.** Neither the app nor a mod can reload a Claude
window (the engine's types offer no way): each window takes a new plugin up
at its next `/reload-plugins` or restart, and runs the code it loaded until
then. So every release keeps the board's folder readable and writable by
the release before it: a new field is optional, and nothing is renamed or
given a new meaning. Stage 1 was the first such: windows not yet reloaded
wrote no `where`, and read as off screen. Each window's heartbeat says which
version it runs, so the app can show which windows to reload.

The CLI is `bin/sitrep`, an executable Bun script, the only file in `bin/`.
Claude Code puts an enabled plugin's `bin/` on its Bash tool's PATH, and the
app calls the copy of the plugin it installed, so nothing puts the CLI on
Lee's shell's PATH: no project's folder goes on kit's `[paths]` (Lee, 14
October 2026). The copy the app carries has it compiled
(`bun build --compile`), so a Mac with the app needs no Bun; the plugin alone
from GitHub runs it on Bun.

The engine's types sit in `.claude-plugin/types/`, kept out of git by their
own `.gitignore`; `.worktreeinclude` copies them into a worktree. The mod's
type-check leaves `cli/shell` out; it is checked on its own
(`tsc -p cli/shell`), against what it calls of Bun, declared there, since the
plugin keeps no packages.

## The menu bar

Decided with Lee on 13 October 2026, on the board as `sr-aw3bgs`. One place
on the Mac, on every Space, for what waits on Lee across every project, and
a click that takes Lee to the window a session is in.

- **A native menu bar app** (SwiftUI). Its icon carries what waits on Lee. A
  new ask posts a macOS banner, silent: the window's own chime already plays,
  so Lee hears it once.
- **The panel:** projects, their sessions, and what waits on Lee in each; a
  project opens to more of its view. Answering stays in the session: the
  panel shows, and takes Lee there.
- **Clicking** a session, an ask or a banner takes Lee to the Ghostty window
  showing that session, on whatever Space it is. A session no window shows
  offers no jump: the app never opens a window (until stage 6).
- **The app holds no sitrep logic.** It watches the state folder, and asks
  the CLI for the board and for the jump.
- **tmux and Ghostty stay at the edge.** Only the jump knows them; core, the
  board and the app never do. Portal is not involved.

### The jump

1. Each Claude window records, in its heartbeat, the terminal device it is
   on, the terminal program (`$TERM_PROGRAM`), and its tmux socket and pane
   when it runs in tmux, worked out once as it attaches. A process Claude
   Code starts has no terminal of its own (`ps` gives `??`, live), so the
   mod runs a small shell walk up the processes from there to the first
   with one, which is Claude Code's. A walk that finds none leaves the
   device out and says so in the debug log; the window attaches all the
   same.
2. A click finds the devices showing the work, its windows the one attached
   longest first. Without tmux it is Claude's own, when its terminal is
   Ghostty. With tmux it is each client tmux lists whose current window is
   the pane's window (`list-panes` and `list-clients`, reads; nothing in
   tmux changes; grouped and linked sessions need nothing more, since a
   window keeps its id in each) and whose process descends from this Mac's
   Ghostty, each device once. One `ps` snapshot settles it: a Ghostty
   window's client runs `tmux < zsh < login < ghostty`, a phone's or iPad's
   `tmux < zsh < mosh-server`, one over ssh from another Mac `sshd` (all
   checked live, 13 October; the terminal's name, `xterm-ghostty`, would
   count the ssh one too). tmux and `ps` each get 2 seconds; one that
   cannot start, fails or does not answer shows nothing, so `list --json`
   never fails or hangs over them. On screen means the client's current
   window is Claude's (tmux's window ids, read from both lists): a session
   of several windows, or a grouped one, whose client shows another window
   does not count, and nothing in tmux is changed to make it. Lee's
   sessions are one window each, so for him every attached Ghostty window
   counts. A jump that could not tell, tmux or `ps` giving no answer in
   time, says so rather than calling the work off screen.
3. sitrep finds the Ghostty window on a device by a knock. Ghostty's
   AppleScript gives each terminal a UUID, a title and a working directory,
   but no device or pid, and Lee's `title = " "` blanks every title. So
   sitrep reads every terminal's working directory, writes a working
   directory report (OSC 7) naming a fresh marker to the device, and asks
   which terminal now reports the marker. Nothing is drawn; the titles stay
   blank and the window buttons stay. The one exception: the knock shares
   the device with tmux, so one landing between two writes of a tmux redraw
   that split an escape sequence would leave a stray fragment on screen
   until tmux next redraws. It needs both at once, and is accepted. Settled
   live:
   - The report's host is `localhost`: Ghostty ignores one with none.
   - Ghostty percent-decodes the path, so every path written is encoded.
   - The old directory is written back however the find ends, `$HOME` for a
     terminal that reported none, or another jump's marker. A terminal that
     took the marker after the find gave up is put back too, as far as
     listing again can tell.
   - The listing reads ids, directories, then ids again, and is read again
     (three tries at most) while terminals open or close under it, so no
     directory is paired with the wrong terminal.
   - A device is opened for writing without being made, so a device that is
     gone fails; it answers nothing, and the next device is knocked on.
   - Each program first checks Ghostty is running: telling it anything
     would launch it.
   - Each question to Ghostty waits at most 5 seconds. With the screen
     locked, Ghostty still answers a trivial question at once but nothing
     about its terminals, and AppleScript's own limit is two minutes
     (found live, 13 October). The jump then refuses in plain words; the
     listing comes before any knock, so a locked screen leaves nothing on a
     marker.
   - Each device is knocked on in turn until one answers.
   - No UUID is kept: a jump knocks every time, which costs well under a
     second, and being on screen needs no knock (tmux and `where` say it).
4. sitrep focuses that terminal (Ghostty's `focus`). With macOS's "switch to
   a Space with open windows" on, macOS goes to its Space. Tried live: from
   Space 9 to the Fumi window on Space 12, then back to Space 1. It needs no
   Accessibility permission and no window manager.

Why tmux comes in at all: walking up the processes never reaches the window.
Claude's chain is `launchd → tmux server → zsh → claude`, the window's is
`Ghostty → login → zsh → tmux attach`, and the two meet only inside tmux,
which is what lets a session outlive a crash and be picked up from the phone.
Ruled out: an environment variable (Ghostty gives a shell no window id),
AppleScript (no device or pid on a terminal), the window server and
Accessibility (nothing ties a window to its device), recording the front
window as each shell starts (a race, and blind to windows already open), and
tmux passing the knock through from Claude's own pane (a tmux setting, and it
reaches a window only while that pane is on show).

### Stages

1. **Each window records where it is**: its device, and its tmux socket and
   pane. Built 13 October 2026.
2. **`sitrep jump --work <id>`** in the CLI, the whole jump, runnable from a
   shell; and `list --json` says whether each work is on screen, so the
   panel knows what to offer. Built 13 October 2026, reviewed at xhigh,
   and run live twice with Lee watching: Finder in front, to the Fumi
   window on its Space and back, about half a second a jump, every
   directory as it was. Stages 1 and 2 landed together (kit-config #2);
   after a `/reload-plugins`, a jump on real works went from Finder to the
   Fumi window's Space and back, half a second each way, every directory
   as it was (13 October 2026).
3. **The app**: the icon, the banner, the panel, the jump, and installing
   the plugin. It is a `.app` of its own (SwiftUI, no Dock icon): a menu
   bar item lives only as long as the process that owns it, and macOS
   sends banners only from an app. Its source sits in the repository
   beside the plugin. In order: a bare app, built locally, to prove a
   banner, the leave to control Ghostty, and starting at login; then its
   first start installing the plugin, and its relaunch refreshing it
   (Installing and updating, under "Where it lives"); then the panel,
   designed in Paper. A jump outside tmux is tested but not yet run live:
   one live run, on a Ghostty window with no tmux. Two
   things to carry over from stage 2: an app started from the Finder has
   only `/usr/bin:/bin:/usr/sbin:/sbin` on its `PATH`, with no tmux, so it
   runs the CLI with Lee's; and its first jump asks macOS for leave to
   control Ghostty. It runs one jump at a time: two knocking on one
   terminal at once can leave it reporting `$HOME`, as the later one takes
   the earlier one's marker for a directory it cannot know.

   The bare app was built on 14 October 2026. Its five live proofs are
   still to run with Lee, and none is proven yet: a silent banner, whose
   click jumps to the work it names; the first jump bringing macOS's prompt
   to control Ghostty, naming SitRep, though it is the CLI, run as the
   app's child, that asks; a rebuild keeping that leave; starting at login;
   and a jump to a Ghostty window without tmux. What building it settled:
   - **A Swift package in `app/`**, no Xcode project: the executable
     `SitRep`, and a library beside it holding what can be tested without a
     screen. macOS 14 and later, Swift 6.
   - **`app/build`** builds it, makes `SitRep.app`, signs it, installs it to
     `~/Applications/SitRep.app`, replacing what is there, and starts it.
     Always that place: the login item and macOS's permissions remember an
     app by where it is. It stops a running SitRep with a signal, since
     asking it to quit by an Apple Event would itself want leave to control
     it.
   - **Signed with "SitRep Local"**, a certificate `app/make-certificate`
     makes once per Mac and trusts for code signing. macOS ties the leave to
     control Ghostty to the app's signature, and an ad hoc signature changes
     with every build, so each rebuild would ask again; this one stays put,
     its designated requirement the bundle id and the certificate. A
     Developer ID replaces it at stage 4, which asks once more.
   - **`com.leeovery.sitrep`**, named SitRep, with no Dock icon.
   - **Its version is the plugin's**, read from `plugin.json` as it builds:
     one version covers both.
   - **Hardened runtime, with the apple-events entitlement**, already:
     notarising at stage 4 needs it, so the leave to control Ghostty is
     proven as a release will ask for it.
   - **Lee's login shell's PATH.** As it starts, the app asks the shell in
     Lee's user record, as a login and interactive shell, for its PATH
     printed between markers, since Oh My Zsh prints around it; about 0.3s.
     Interactive, as step 2 needs `claude`, which only an interactive
     shell's PATH has. With no answer it falls back to Homebrew's folders
     and the system's, and logs it. Every child gets that PATH and
     otherwise the app's own environment, and a time limit: 10 seconds for
     `list --json`, 30 for a jump, whose questions to Ghostty wait up to 5
     seconds each.
   - **The main checkout's path stamped in.** `app/build` writes the folder
     of the repository's main checkout, the live plugin, into the app's
     Info.plist (`SitRepPlugin`), even when it builds in a worktree; the
     app runs that folder's `bin/sitrep`. Step 2 replaces it with the copy
     the app installs.
   - **A plain menu**, until the panel is designed: the works on screen, a
     jump each; a test banner; starting at login; quitting. The works are
     listed by `list --json` as the app starts and again each time the menu
     opens, which shows the last listing at once and redraws only when the
     fresh one differs, so nothing flashes; a work just gone from the
     screen may show for the tenth of a second the listing takes, and
     choosing it gets the CLI's refusal. A failed jump shows the CLI's words
     as a banner. The menu bar item is AppKit's `NSStatusItem`,
     not SwiftUI's `MenuBarExtra`, whose menu style says nothing as the
     menu opens; the panel can still be SwiftUI inside it.
4. **Releases**, once sitrep is stable: a release is its version, in
   `plugin.json`, the marketplace entry and the app, and a tag
   (`claude plugin tag`); a GitHub Action on a macOS runner builds the app
   with the plugin inside it, its CLI compiled, and updates the cask in
   `homebrew-tools`. Lee's Macs then install the cask like anyone, kit's
   `[manual]` step gives way to the cask, and the clone stops being live:
   a script in the repository points the `sitrep` marketplace at the clone
   for a live test, and back. Going public needs the app signed with a
   Developer ID and notarised, since Homebrew quarantines what a cask
   downloads, as macOS does any download. To settle then: whether
   `claude plugin update` follows `main` or the tags, for the plugin alone
   from GitHub.
5. **Attention beyond asks.** The mod hears a permission prompt
   (`classic.Notification`) and a turn ending (`turn.complete`), and the
   heartbeat carries it. A session blocked on a permission prompt gets a
   banner; "your turn" shows quietly, with none.
6. **Opening what isn't on screen**: a new Ghostty window attached to a
   session running with no window, as `code-OQWkFt · sitrep` and
   `portal-rex` were on 13 October.

## Later

Parked: an **agents** view (subagents, observed from engine events, grouped by
what they're for); a **tmux indicator** reading the shared folder; **Paper
thumbnails** inline in Ghostty; a "re:" tag on Lee's transcript rows that
came from the board. Jumping to a work's window is now "The menu bar".

Dropped: a standalone toast plugin (Claude Code has one), and a line in the
new-ask toast saying the band opens it: Lee knows it does, and on the phone
the toast is better short.

## Open questions

Answered with Lee on 8 October 2026, for build step 5, which Lee then dropped
on 11 October 2026 (see "Build order"):

1. **Whether Lee is looking at the window: no check.** It was only there to
   spare a banner for the window that has already pulsed, toasted and chimed;
   asks are rare, so a notification for every new ask.
2. **Notifications:** `terminal-notifier` when it is already on the PATH;
   sitrep never installs anything on someone's machine. Without it,
   `osascript`'s notification, which ships with macOS (clicking it opens
   Script Editor rather than Ghostty).
3. **Left open: dropped.** Lee may be away for days, so no time is right; a
   window joining a work reconciles its open items instead.
4. **The CLI answering asks:** later. It only posts for now; answering would
   be one more command, a reply into the work's inbox.

## Build order

1. **core** and the storage format, with tests.
2. **The mod for one piece of work**: start/join, status, ask, note, park,
   the board's session view, Ready to send, delivery to this work, the band.
3. **Across pieces of work**: the project and all-projects views, delivery
   through inboxes, the start-of-session listing.
4. **The CLI.**
5. **Dropped** (11 October 2026): notifications, `/sitrep check`, and a
   reconcile when a window joins a work. Notifications aren't wanted for now;
   `/sitrep check` adds nothing over the `board` tool; a join already answers
   with the whole board, and asks Claude to correct what is stale. The build
   is finished.
6. **The menu bar** (13 October 2026), in stages of its own: see "The menu
   bar".

## The spike

A throwaway mod with fake data modelled on Switchboard, Goosemates and five
other projects, run only in the session that designed sitrep. It settled every
surface above, and its drawing code became `hooks/draw`. Retired on 8 October
2026, once it was found drawing its fake data over the real board: both named
their pane `board`, and a pane's id is not scoped to the plugin that opens it.
