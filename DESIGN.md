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
| **status** | Where a piece of work stands: its name, a one-line summary, what is under way now (one line each), and what comes next. |
| **ask** | Something only Lee can do or decide, posted by Claude. Counted on the band. |
| **note** | A line in the log: something that happened that Lee may want to know. Not counted. |
| **parked** | Something raised and put off, to circle back to. Not counted, not dismissable. |
| **reply** | Lee's answer to an ask, or a pick-up of a parked item, waiting in Ready to send. |
| **board** | The pane. **band** is the line above the prompt. **glance** is the board collapsed to a narrow column. |

## Pieces of work, not Claude sessions

A Claude session id changes on `/clear` and `/resume`, and one piece of work
can run across several windows. So sitrep keys everything on a work id.

1. Claude starts a piece of work on the board with a name and a summary, and
   gets back a work id.
2. Claude records the id in its own tracking for that work (design doc, plan,
   memory: wherever that project keeps things).
3. Any later window joins the work by id: after `/clear`, `/resume`, a fresh
   window tomorrow, or a second window on the same work. Two windows on one
   work is how sessions combine.
4. At the start of every Claude session, sitrep lists the project's current
   pieces of work, with their ids, in Claude's context, so "let's carry on
   with the dashboard work" finds its id even if nothing in memory says it.
   It is a block of the conversation's first message (`prompt.context`,
   named `sitrep`), in every conversation: how to keep the board (below,
   "When to start a piece of work"), then the project's works when it has
   any. It is computed once per conversation, again after `/clear` or a compaction, and again for a
   session resumed in a new process or by `/resume` (live). It tells Claude
   to join the matching one by id, and says which one this window already
   holds.
5. A resumed conversation, holding nothing, takes up by itself the work of
   this project it was last seen in: by its heartbeat, else the latest item
   or status it posted. Sending into a work's inbox, or having started it, is
   not being seen in it.
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
Nothing goes in the repo: no dotfile. Worktrees of one repository are one
project (identity: the git common dir).

A work is **current**, and shows in the project view, All projects and the
start-of-session listing, while it is open, has an ask waiting, has
something parked, or was updated in the last 7 days. An older idle work stays
on disk and out of the views; a project left with none drops out of All
projects altogether.

## Claude's side

Tools the mod registers, schemas loaded up front. **Only the main conversation
can call them**; a subagent is told to put it in its report, and the
orchestrator decides what reaches the board.

| Tool | Does |
|---|---|
| `start` / `join` | begin a piece of work (name, summary) and get its id; or join one by id |
| `status` | set the name, summary, the list of what is under way, and what is next |
| `ask` | post an ask: kind (review, decide, try, do), title, where to look, options for a decision |
| `note` | add a log line, with optional detail lines and a pointer |
| `park` | park something to come back to |
| `resolve` / `reopen` / `edit` | close, reopen or correct an item, with a reason |
| `board` | read back the board's open items, so Claude can check and repair it |

**When to start a piece of work**, in every conversation's first message
(added once a session started one with nothing to go on but the tools, and
named it in internal shorthand):

- Start one when the work will run across several turns or will need Lee: a
  feature, a design, an investigation. Not for a quick question.
- Name it in plain words, as Lee would say it, with no internal codes, and
  record its id wherever the project tracks the work.
- As it goes: the status when what's under way changes, an ask whenever Lee is
  needed (said in the chat as well), a note for what Lee would want later,
  never running commentary; resolve what's done.

Wording rules, in the tool descriptions:

- Ask only when Claude cannot go on without Lee, or Lee's judgement changes what
  happens next. Say it in the chat as well.
- One line, plain words, starting with the verb. No internal codes (no P-numbers,
  no D-numbers). "Where" says where to look in words: "In Paper: the dashboard
  file, page "round 1", frames 1–6".
- Notes are things Lee would want to know later, not running commentary.
- A changed status is logged by the board itself (it compares the new status
  with the last), so Claude does nothing extra for it.

When the board changes, its open items ride into Claude's next turn as unseen
context, so drift is noticed. **proposed:** a `/sitrep check` command asks
Claude to compare the board with what it knows and repair it, logging what it
changed. **Nice to have:** when a turn ends with Claude asking Lee something
that no ask records, send it back once to record it.

## Lee's side

### The board: a tree, with this session as home

```
 ⌂ This session 1  ▤ Switchboard 3  ≡ All projects 7
━━━━━━━━━━━━━━━━━━──────────────────────────────────────
Dashboard redesign · Switchboard
Redesign the dashboard, area by area in Paper
STATUS ────────────────────────────── updated 12m ago
• Waiting on your review of Sessions & Runway, round 1
• Drawing Usage, round 2
◦ next: Usage, round 3
FOR YOU ─────────────────────────────────── 1 waiting
◆ Review Sessions & Runway, round 1                 2h
└ In Paper: the dashboard file, page "round 1", frames 1–6
LOG ────────────────────────────────── what happened
12m  • Status: now also drawing Usage, round 2
```

- **On Lee's own path** (this session, its project, all projects) the board shows
  three tabs. **Anywhere else** (another session or project) the tabs give way
  to `← <one level up>` and `⌂ this session`, the familiar nested-page pattern.
- **This session** (home, the default): name and summary, Status, For you, Log.
- **Project**: its sessions, this one first (`⌂`), each with what it is doing
  and its waiting count; the project's log, each line naming its session.
- **All projects**: this project first, then the busiest. Each project's open
  sessions hang off it as a tree. A project with nothing open, waiting or parked
  folds into one line at the bottom.
- **Another session** is the same view as this one: its status, For you with
  buttons that answer it, its log.
- Each tab carries what waits there. All projects is read only while the board
  looks at it, so its tab has a count only then.
- Each view's first line sits directly under the tab rule, with no blank row.
- Every section heading has a few words on the right: `1 waiting`,
  `what happened`, `updated 12m ago`, `2 of 3 open`.
- **Log lines open** to the detail behind them, as a tree.
- **Parked** is a view of the board, scoped to where the board is looking.
- **Collapse** turns the board into the glance: counts on one row, what is under
  way, what waits, the last few log lines, the project's sessions; every line
  opens the full board on what was clicked. `⇥ collapse` and `⇤ expand` sit in
  the same top-right spot.

### Answering an ask

A kind is never shown as a word. It only chooses the first button:

| Kind | Buttons |
|---|---|
| review | ✓ approve · ✎ comment · ✕ ignore |
| decide | one button per option · ✎ answer · ✕ ignore |
| try | ✓ it works · ✎ comment · ✕ ignore |
| do | ✓ done · ✎ comment · ✕ ignore |

- Comment opens a multi-row field that grows as you type (drawn by the mod;
  Claude Code's own field is one line). Enter saves, shift+Enter is a new line.
  A review also gets **✓ approve + comment**.
- **Ignore** tells Claude Lee has seen it and won't act on it.
- What a reply does once Claude has it: a yes or a choice or an answer closes
  the ask; ignore drops it; a comment on a review, try or do leaves it open
  for Claude to act on.

### Ready to send

Everything Lee does on the board queues here first; nothing goes one press at
a time. The box sits at the foot of **every** view of the board while anything
waits in it, grouped by where each reply goes (`to this session`,
`to Request ledger`, a session of another project with its project's name).
Each reply hangs off its item with a `└`, has its own `✕`, and the ask shows
`↺ undo`. **send to Claude** sends them; **cancel all** clears them.

A group sent into another work's inbox stays in the box, its replies out of
the queue, until Claude has them all, and 10 minutes after, so
`delivered 2m ago` can be read. A closed work's group stays until it reopens.
A reply whose item changed before it went in (see Delivery) shows as
`not delivered: it changed since`, and lingers out the same way.

### The band

One line above the prompt, right-aligned counts only, each one a way in:

```
                        ◆ 1 for you   2 in other sessions   ◇ 4 parked   ▸ show board
```

`for you` opens this session, `in other sessions` (what waits in this
project's other works) this project, `parked` the parked view. Below 64
columns the words drop and the counts stay. The board's show/hide button
always matches whether it is drawn.

When a new ask lands: the ◆ pulses, a toast names it, and a soft chime plays.
**To try:** a macOS notification for asks, only when Lee isn't looking at that
window.

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
- A reply on its way whose item an edit changes so it no longer fits (a review
  made a decision under Lee's yes) is **void**: no message carries it, a mark
  naming it changes nothing, and the item can be answered again.
- The inbox message is the board's own, as this work's is: it takes no
  board-change context, and written through the hold its lines are lines
  Claude knows of (`postKnown`). The rest rides in with Lee's next prompt.
- An ask's life: **open → replied → closed**. The board never closes an ask on
  a press, only once Claude has been told: a delivered reply closes it, or
  Claude resolves it. An ask open past a day shows its age; one left open when
  its work has no window moves to a **left open** list in that project rather
  than piling up.

## Storage

```
$XDG_STATE_HOME/sitrep/, else ~/.local/state/sitrep/
  projects/<project key>/works/<work id>/
    work.json               name, summary, project, root, created and by whom: written once, by whoever starts the work
    <writer>.jsonl          one file per writer: each window as its session id, the CLI as `cli`
    inbox/<sender>.jsonl    replies from other works, one file per sending writer
    presence/<writer>.json  each attached window's heartbeat
```

- **Project key:** the repository's folder name as a slug, then a hash of its
  git common dir (outside git, of the folder): `switchboard-1a2b3c4d`.
  Worktrees share a common dir, so they share a project.
  The mod asks git for it in the session's working directory
  (`git rev-parse --path-format=absolute --git-common-dir`), which spells it
  the same however the folder was reached; outside git it takes the
  directory itself.
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
  {"v":1,"at":1760000000000,"seq":4,"type":"ask","id":"k3f9","kind":"review","title":"Review Sessions & Runway, round 1"}
  ```

  The kinds: `status`, `ask`, `note` and `park`; `resolve`, `reopen` and
  `edit`, each naming an item; `reply`, Lee's answer to one; `delivered`,
  naming the replies Claude has been given.
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
- Readers list and `stat` the folder every second or two (a mod cannot watch
  files) and read only what changed. The works around the held one are read
  every 5 seconds, each through its reader: they are glanced at, not watched.
  With the board closed only the held work's project is read, for the band;
  open, the project it looks at too, every project while it looks at all of
  them, and in full the session it looks at and those replies wait for or
  went to.
- The board's last view lives in the session's `$.state` only. `$.store` is
  unused so far.

## One engine, two front ends

- **core**: a plain TypeScript module, no file system, no Node: the folder's
  format, the event shapes, the rules (what a reply does to an ask, what counts
  as waiting, what folds away). Tested on its own.
- **the mod**: Claude Code's hooks module. Draws the board, band and glance;
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
    module of the plugin, and a `Client`'s `module` is read off whichever
    file draws it, relative to that file. A surface's table names every
    element, one the surface lacks drawing nothing, so what a surface can
    draw (a text area, a one-line field) is read off `e.surface`.
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
  sitrep ask <kind> <title> [--where <words>] [--option <choice>]... [--ref <ref>]
  sitrep park <title> [--where <words>] [--ref <ref>]
  sitrep status [--name <words>] [--summary <line>] [--now <line>]... [--next <line>]
  sitrep board [--json]
  sitrep list [--all] [--json]
  ```

  - It writes as the writer `cli`, appending to `<work>/cli.jsonl`. It never
    writes a delivered mark or a heartbeat: it is never a window on the work.
  - What it posts is checked by core as Claude's tools' posts are, and a
    refusal prints the check's words. A post prints its item's id and nothing
    else, so a script can keep it. A status gives only what changed, as the
    status tool does; `--now ""` and `--next ""` clear. The last argument takes
    every word left, so a title needs no quotes.
  - The work is `--work sr-xxxxxx`, else `$SITREP_WORK`, looked up in the
    project of the folder the CLI runs in (known as the mod knows it), then in
    every other. `list` takes none: this project's current works, or with
    `--all` every project's, ordered as All projects orders them.
  - Exit codes: 0 done; 1 a usage error, a refused input or a failure; 2 no
    such piece of work.
  - `list --json` is for tools, and stable: every field is always there (a
    list empty, any other value null where there is none), and `v` moves only
    with a change a reader would trip on. `here` is the key of the project the
    CLI runs in, always the first of `projects`.

    ```
    { "v": 1, "here": "switchboard-1a2b3c4d",
      "projects": [ { "key": "switchboard-1a2b3c4d", "name": "switchboard",
                      "open": 1, "waiting": 2, "parked": 1, "updatedAt": 1760000000000,
                      "works": [ { "id": "sr-k3f9qa", "name": "Dashboard redesign",
                                   "summary": "...", "now": ["..."], "next": null,
                                   "isOpen": true, "waiting": 1, "parked": 1,
                                   "updatedAt": 1760000000000 } ] } ] }
    ```

    `board --json` is `{ v, project: { key, name }, work, asks, parked, log }`:
    the work as `list` gives it, its open asks, what it parked, and its latest
    log lines.
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
  doing, a reply, a log detail).
- **Grey:** ages, counts, heading notes. **Faint:** closed things.
- **Colour:** glyphs, headings and amber waiting counts only.
- Glyphs: `◆` ask, `◇` parked, `•` under way, `◦` next, `└ ├` trees, `⌂` home.
  No glyph that reads as "expand" unless it expands.
- Breathing room: a column each side, a blank row between asks and between
  sections, none between the tabs and the first line under them.
- No indents left floating: anything hanging off an item hangs from a `└`.

## Where it lives

`~/.config/kit/shared/plugins/sitrep/`, in Lee's private `kit` marketplace,
the same as `handoff`. The marketplace is read straight from the folder, so an
edit plus `/reload-plugins` is a change. The CLI lives in the same folder:
`bin/sitrep`, an executable Bun script, the only file in `bin/`. Claude Code
puts an enabled plugin's `bin/` on its Bash tool's PATH. **proposed:** for
Lee's own shell, scripts and tmux, kit's `[paths]` takes the folder too
(`kit path add --shared ~/.config/kit/shared/plugins/sitrep/bin`). The mod's
type-check leaves `cli/shell` out; it is checked on its own
(`tsc -p cli/shell`), against what it calls of Bun, declared there, since the
plugin keeps no packages. If sitrep becomes a product, it moves to its own
public repository with a marketplace file and a formula in `homebrew-tools`.

## Later

Parked: an **agents** view (subagents, observed from engine events, grouped by
what they're for); a **tmux indicator** reading the shared folder; **jumping**
to a work's Ghostty window (likely through Portal, which Lee wants to make
agent-aware); **Paper thumbnails** inline in Ghostty; a "re:" tag on Lee's
transcript rows that came from the board.

Dropped: a standalone toast plugin (Claude Code has one).

## Open questions

Answered with Lee on 8 October 2026, for build step 5:

1. **Whether Lee is looking at the window: no check.** It was only there to
   spare a banner for the window that has already pulsed, toasted and chimed;
   asks are rare, so a notification for every new ask.
2. **Notifications:** `terminal-notifier` when it is already on the PATH;
   sitrep never installs anything on someone's machine. Without it,
   `osascript`'s notification, which ships with macOS (clicking it opens
   Script Editor rather than Ghostty).
3. **Left open:** an unanswered ask whose work has had no window for 24 hours.
4. **The CLI answering asks:** later. It only posts for now; answering would
   be one more command, a reply into the work's inbox.

## Build order

1. **core** and the storage format, with tests.
2. **The mod for one piece of work**: start/join, status, ask, note, park,
   the board's session view, Ready to send, delivery to this work, the band.
3. **Across pieces of work**: the project and all-projects views, delivery
   through inboxes, the start-of-session listing.
4. **The CLI.**
5. **Notifications**, left open, `/sitrep check`, the turn-end safety net.

## The spike

A throwaway mod with fake data modelled on Switchboard, Goosemates and five
other projects, run only in the session that designed sitrep. It settled every
surface above, and its drawing code became `hooks/draw`. Retired on 8 October
2026, once it was found drawing its fake data over the real board: both named
their pane `board`, and a pane's id is not scoped to the plugin that opens it.
