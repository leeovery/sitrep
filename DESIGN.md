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
4. At the start of every Claude session, sitrep lists the project's open pieces
   of work, with their ids, in Claude's context, so "let's carry on with the
   dashboard work" finds its id even if nothing in memory says it.
5. A window that never starts or joins a piece of work shows nothing on the
   board. That is the best effort.

A piece of work is **open** while at least one window is attached to it.
Nothing goes in the repo: no dotfile. Worktrees of one repository are one
project (identity: the git common dir).

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

**proposed** wording rules, in the tool descriptions:

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
  In Paper: the dashboard file, page "round 1", frames 1–6
LOG ────────────────────────────────── what happened
12m  • Status: now also drawing Usage, round 2
```

- **On Lee's own path** (this session, its project, all projects) the board shows
  three tabs. **Anywhere else** (another session or project) the tabs give way
  to `← <one level up>` and `⌂ this session`, the familiar nested-page pattern.
- **This session** (home, the default): name and summary, Status, For you, Log.
- **Project**: its sessions, each with what it is doing and its waiting count;
  the project's log.
- **All projects**: this project first, then the busiest. Each project's open
  sessions hang off it as a tree. A project with nothing open, waiting or parked
  folds into one line at the bottom.
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
`to Request ledger`). Each reply hangs off its item with a `└`, has its own
`✕`, and the ask shows `↺ undo`. **send to Claude** sends them; **cancel all**
clears them.

### The band

One line above the prompt, right-aligned counts only, each one a way in:

```
                        ◆ 1 for you   2 in other sessions   ◇ 4 parked   ▸ show board
```

`for you` opens this session, `in other sessions` this project, `parked` the
parked view. Below 64 columns the words drop and the counts stay. The board's
show/hide button always matches whether it is drawn.

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
  turn to end`, `○ closed: goes in when it reopens`), each ask shows
  `delivered 2m ago` or `on its way`, a toast sums it up, and the receiving
  window's band flashes `✦ 2 replies from the board`.
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
  only write whole files, so each mod rewrites its own file; the CLI can append.
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
  `delivered` mark naming it. For this work, the mod writes the reply and the
  mark together, once Claude Code has taken the message. For another work, the
  sender writes the reply into that work's inbox, and the window that submits
  it there writes the mark to its own file. Only replies count from an inbox.
- **Presence:** a mod can't tell that its own window died, so each attached
  window rewrites its heartbeat (`attachedAt`, `seenAt`) every 30 seconds, and
  a work is open while a heartbeat is under 90 seconds old. A mod can't delete
  a file either, so a window that lets go adds `leftAt`. Of several windows on
  one work, the one attached longest submits its inbox, so two never both do.
- Readers list and `stat` the folder every second or two (a mod cannot watch
  files) and read only what changed.
- `$.store` holds only per-person conveniences (last view, band preferences).

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
    process (`--resume`) starts without it, and Claude joins again.
- **the CLI**, `sitrep`: runs on Bun, reads and writes through the file system.
  For scripts and other tools: a Paper generator posting "round 3 drawn", and
  later the tmux indicator. **proposed** commands: `sitrep ask`, `sitrep note`,
  `sitrep status`, `sitrep list --json`.

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
edit plus `/reload-plugins` is a change. The CLI lives in the same folder, its
`bin/` put on the PATH by kit. If sitrep becomes a product, it moves to its own
public repository with a marketplace file and a formula in `homebrew-tools`.

## Later

Parked: an **agents** view (subagents, observed from engine events, grouped by
what they're for); a **tmux indicator** reading the shared folder; **jumping**
to a work's Ghostty window (likely through Portal, which Lee wants to make
agent-aware); **Paper thumbnails** inline in Ghostty; a "re:" tag on Lee's
transcript rows that came from the board.

Dropped: a standalone toast plugin (Claude Code has one).

## Open questions

1. How the mod tells that Lee is looking at its window, for notifications.
2. Notification mechanism: `osascript`, `terminal-notifier`, or what Claude Code
   offers by then.
3. How long before an unanswered ask counts as "left open".
4. Whether the CLI should be able to answer asks, or only post.

## Build order

1. **core** and the storage format, with tests.
2. **The mod for one piece of work**: start/join, status, ask, note, park,
   the board's session view, Ready to send, delivery to this work, the band.
3. **Across pieces of work**: the project and all-projects views, delivery
   through inboxes, the start-of-session listing.
4. **The CLI.**
5. **Notifications**, left open, `/sitrep check`, the turn-end safety net.

## The spike

`~/.claude/dev-mods/fdd35b79-4db2-4bb8-83a4-0636944d64e4/board-spike/`: a
throwaway mod with fake data modelled on Switchboard, Goosemates and five other
projects. It settled every surface above. Its drawing code is the starting
point for the mod; its data and `/spike` commands are not.
