# sitrep

A small pane, inside Claude Code, onto where a session stands and what it
needs from Lee. Claude jots into it as it works; Lee glances at it, answers
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

Settled with Lee on 16 October 2026.

| Word | Means | On screen |
|---|---|---|
| **project** | The top level: what a session is on, named by Claude as Lee would say it (`SitRep`, `Switchboard`), and where it lives once known. Roughly a repository. Never the folder a window started in. | |
| **session** | One line of discussion, with its status, asks, notes and parked items. It outlives its window: after a `/clear`, or in a new Claude told to carry on, it is the same session. | |
| **window** | One running Claude Code, wherever it shows: a Ghostty window, a tab, a tmux pane. Where working, your turn and a permission prompt come from, and what the jump brings forward. A word for the code and for the design. | Rarely shown. |
| **session id** | The board's internal id for a session (`sr-k3f9qa`). Not Claude Code's session id, which names a conversation and changes on `/clear`. | Never shown. |
| **the board** | The content: projects, sessions and their items, the state any surface shows. Putting something on the board is like putting it in a database. | |
| **status** | Where a session stands: its name, a one-line summary, what is under way now (one line each), and what comes next. | |
| **ask** | Something only Lee can do or decide, posted by Claude. Counted on the band. | |
| **note** | A line under Notes: something that happened that Lee may want to know. Not counted. | |
| **parked** | Something raised and put off, to circle back to. Not counted, not dismissable. | |
| **reply** | Lee's answer to an ask, or a pick-up of a parked item, waiting in Ready to send. | |
| **resolved** | An item done with: an ask a reply closed, or any item Claude resolved. Resolved lists a session's resolved asks. | |
| **finished** | A session Claude or Lee finished, once it was complete with nothing left on it. | |
| **notch** | The SitRep notch, where it needs telling from the camera's: the black shape at the edge of the screen that opens into the panel. | |
| **panel** | What the notch opens, the notch panel or the SitRep panel: a glance at the board, and a jump. | |
| **strip** | The alternative to the notch and its panel: a narrow strip the height of the screen. | |
| **SitRep window** | The bigger window, showing the whole board. | |
| **menu bar item** | SitRep's icon in the menu bar, and its menu. | |
| **Settings** | Where Lee sets SitRep up. | |
| **pane** | The view of the board inside Claude Code. | board: `show board`, `hide board` |
| **band** | The line above Claude Code's prompt. | |
| **macOS notification** | What macOS shows from an app, as SitRep's for a new ask. | |

The code uses these words (19 October 2026): sessions, not pieces of work,
in the mod, core, the CLI (`--session`, `$SITREP_SESSION`) and Claude's
tools; on the pane, ASKS, NOTES, RESOLVED and "finish this session"; on
disk, `sessions/` and `session.json`, the old `works/` and `work.json` read
beside them until the CLI moves them (see "Storage"). Claude Code's own
session is a conversation or a window there, so "session" means only the
board's. The old words are left in two places until what holds them is
rebuilt: the spike's `lip`, in its views only, since the model the build
took from it says the notch (19 October 2026); and the app's Swift
identifiers, until the edge and the menu rebuild the app, later in stage 3.
The CLI's JSON keeps its names (`works`, `work`), as "Versions side by
side" has it.

## Sessions outlive their windows

Claude Code's session id changes on `/clear` and `/resume`, and one session
can run across several windows. So sitrep keys everything on a session id
of its own.

1. Claude starts a session on the board with a name, a summary and its
   project (below), and gets back a session id.
2. Claude records the id in its own tracking for that session (design doc,
   plan, memory: wherever that project keeps things).
3. Any later conversation joins the session by id: after `/clear`,
   `/resume`, or in a fresh window tomorrow. A second window at once is a
   second session (below, "Two windows").
4. At the start of every conversation, sitrep lists every current session,
   with its project and id, in Claude's context, so "let's carry on
   with the dashboard work" finds its id even if nothing in memory says it.
   It is a block of the conversation's first message (`prompt.context`,
   named `sitrep`), in every conversation: how to keep the board (below,
   "When to start a session"), then the sessions when there are any, a
   line each, project by project:

   ```
   On the board:
   - SitRep: sr-wdsqvn "sitrep", 2 waiting on Lee
   - Switchboard: sr-v1pwm9 "Milestone 7 stage 1"
   ```

   The projects whose directory holds the window's folder come first, the
   nearest first, then the busiest, as All projects orders them. It is
   computed once per conversation, again after `/clear` or a compaction, and
   again for a conversation resumed in a new process or by `/resume` (live). It
   tells Claude to join the matching one by id, and says which one this
   window already holds.
5. A resumed conversation, holding nothing, takes up by itself the session
   it was last seen in, in whichever project: by its heartbeat, else the
   latest item or status it posted. Sending into a session's inbox, or having
   started it, is not being seen in it. A finished session is never taken up
   by itself, nor an older one in its place: the conversation had moved on
   from those.
   - Resumed in a new process (`--resume`, `-c`), it keeps Claude Code's
     session id but not `$.state`. The process computes the listing before
     the conversation starts (live), so the rejoin runs there first, for the
     listing to name it.
   - Resumed by `/resume` in this process, the conversation that ended lets go
     of its session (`session.end`), and no `session.start` follows. The
     engine's `SessionStart` with source `resume` names the resumed
     conversation; `$.session.id()` still names the one that ended at that
     moment (live), so the window rejoins under the event's Claude Code
     session id.
6. A window that never starts or joins a session shows nothing on the
   board. That is the best effort.

A session is **open** while at least one window is attached to it.
Nothing goes in the repo: no dotfile.

**Projects are named by Claude, never taken from a folder.** Lee may start
Claude in their home folder and talk about sitrep, and a brand new project
may have no folder or repository yet; what matters is the project being
discussed. So `start` names its project, as Lee would say it and cased
(`SitRep`, never `sitrep-1a2b`), and may say where it lives:

- A project on the board whose name matches takes the session, matched
  ignoring case, spaces and punctuation (`Sitrep` and `Sit Rep` are
  SitRep's); the project keeps its own name, and the answer says which
  project the session went into. A name alone is a project: there are no
  project codes.
- Else a new project is made of the name.
- A directory given is recorded for a project that has none. One that has
  its own keeps it, and the answer says so: the `project` tool changes it.
- The folder a window started in decides nothing: not the board's own
  project (the held session's), not what the first message lists (every
  current session), not where a join or a resumed conversation looks (every
  project). It only orders: projects whose directory holds it come first.
  A session still records it, as `root`: where the session was started.

A session is **current**, and shows in the project view, All projects and
the first message's listing, while it is open, has an ask waiting (on Lee,
or on a window to deliver Lee's answer), has something parked, or was
updated in the last 7 days. An older idle session
stays on disk and out of the views; a project left with none drops out of
All projects altogether.

A session is **finished** once Claude or Lee finishes it, and is then never
current, whatever it holds: a window can close with things still open on
its session. Its waiting asks count nowhere (tabs, band, projects). A line
posted to it later, by the CLI or anyone, leaves it finished; only joining
it again reopens it.

**Two windows are two sessions** (16 October 2026). Two terminals on one
tmux session show one window twice, and the jump picks either. If two
windows ever join one session, it shows once, with the more urgent state,
and a click goes to the window that needs Lee, else the one active last.
There is no chooser.

### A session's state

Decided with Lee on 16 October 2026; the panel's rows show it (see "The
notch and its panel").

- **needs you**: an ask waits, or its window has stopped on a permission
  prompt or a question. Orange. It wins over the others: a session can need
  Lee and be working at once, as when Claude posts an ask and carries on.
  An ask counts even while the session is away.

  An ask waits on Lee until Lee replies to it (20 October 2026): once a
  reply of Lee's to it is on its way, an answer or a comment, in its
  session's inbox from the pane or the SitRep window, Lee has responded: it
  waits on a window to deliver the reply, and then on Claude, not on Lee,
  and counts nowhere on Lee's surfaces as needing Lee: not in a session's or
  a project's waiting, on the tabs or the band, in `list` or `board --json`,
  nor in `watch`'s head and rows, so the notch does not swell for it. Its
  session's state is then what its windows make it: an away one with nothing
  else waiting leaves the panel and the strip, and shows in the SitRep
  window. The ask itself still shows among its session's asks, saying its
  reply is on its way, until the delivered mark settles it; an ask whose
  reply went void waits on Lee again, as does one whose reply reached Claude
  after an edit it no longer fits (see "Which replies go in", under
  Delivery). A comment on its way bars no answer: the ask still offers its
  buttons. Core's `waitsOnLee` decides it. It still keeps its session
  current, as an ask waiting on Lee does, however long the answer waits for
  a window.

  What Claude is told follows what Claude has been given, so everything
  Claude reads (the board text, the first message's listing and its counts,
  core's `toldSummary`) has such an ask still waiting on Lee until the
  reply is delivered: Lee's surfaces show where Lee's own work stands, and
  Lee has replied; Claude's show what Claude knows, and a reply not yet
  delivered is not Claude's to know.
- **working**: its window is running a turn.
- **on its own work** (22 October 2026): its window's turn has ended, but
  Claude left something running that will wake it, so it waits on that and
  not on Lee: background agents, a workflow, a background shell, a monitor,
  anything else Claude Code runs in the background for it, or a one-off wake
  it scheduled. When the work ends or the wake fires, Claude Code wakes the
  window with a turn of its own, and it is working again. Board A, which Lee
  took as the base of the card's sections ("A is kind of the base"), puts
  Working above Your turn and on its own work in Working. What leaves a
  session your turn all the same:
  - a persistent monitor and a recurring wake: neither ever ends, so a
    session holding one would never be Lee's turn again;
  - a monitor the mod never heard start, which may be one of Claude Code's
    own that never ends, as its watch on a published artifact is;
  - a turn stopped with Esc, or ended by an API error: Claude Code sends no
    Stop for the first, and for the second a StopFailure, which lists
    nothing, so nothing pending is heard.

  Known limit: a background shell that never ends, as `tail -f`, cannot be
  told from one that will. It counts while it runs.
- **your turn**: its window finished its turn, or Lee stopped it, with
  nothing of its own left running, and waits for Lee's message. Not orange:
  they are in a conversation, and Lee comes back when ready.
- **away**: no window holds it, and it is still current. Dimmed.
- **finished**: off the panel.

Working, on its own work, your turn and the stops on a permission prompt or
a question come from the window's events. The mod records them as each
window's state, in its heartbeat, with what the row shows of it (19 October
2026; the shape is under "Storage"). The session's state across its windows
is core's (`core/rows.ts`, 19 October 2026), which `sitrep watch` prints:
needing Lee wins, then working, then on its own work, then your turn, and a
live window on a release from before heartbeats said a state reads as your
turn since it attached. Only a stop the events show needs Lee: a turn that
ends on a question in plain text is your turn. The colours stay few; the
look is played with later, in Paper.

How the mod hears its window's state, every hook only observing: it passes
the event on as it came, and a failure recording what it heard is logged
and swallowed, never breaking a turn, a tool or a permission prompt.
- **A turn starts** (`turn.start`): working, since the turn began. What an
  earlier turn left running is forgotten: a wake-up is such a turn, a
  task's end or a monitor's event coming as `prompt.submit` then
  `turn.start`, and the turn's own Stop says again what still runs.
- **A tool runs** (`tool.call`, until its `next` settles): working carries
  the tool and its subject, the latest started where several run at once,
  then the one still running. The hook is over every call, sitrep's own
  among them, which still answer as before.
- **A permission dialog shows** (19 October 2026): permission, with the
  tool and its subject, since then. Only a dialog shown to Lee is a stop,
  not a check's verdict: "ask" puts a call to the mode's decider, which is
  the dialog by default but in auto mode, which Lee runs, a classifier that
  settles most calls without Lee, so a stop taken from the verdict would
  have read nearly every Bash as waiting on Lee for its whole run.
  - `tool.check` settling "ask" on a real call (one with a `tool_use_id`; a
    query of the check has none) makes the call a candidate, and nothing
    more.
  - `classic.PermissionRequest` is Claude Code about to show the dialog: in
    auto mode only for a call the classifier hands to Lee, never for one it
    settles. Where a settings hook beneath answers it, with a decision or a
    block, no dialog shows, and nothing stops. A plugin above sitrep that
    answers it itself, after sitrep has passed it on, is not seen: that
    reads as a stop though no dialog shows. The observer hands the event's
    answer on as it came.
  - The event says the tool, its input and, for a subagent, its
    `agent_id`, never the call, so it goes to the oldest candidate it is
    for: the same tool; the same loop, strictly, a request with no
    `agent_id` being the main loop's (the engine's types say it is absent
    there) and taking only the main loop's calls; and the arguments equal
    on every one both carry, at least one, or both carrying none. Not
    equal as wholes: the check reads a call's arguments as the permission
    decision does, and either side may carry one the other lacks (Bash's
    `description`, `timeout`). Each argument is compared as a digest of
    its JSON, its objects' keys in order (core's `jsonOf` and `digestOf`,
    53 bits), so a candidate stays small, a Write's whole file a few
    characters. A request no candidate fits is logged and ignored.
  - Within one loop, two calls alike in tool and the arguments both carry,
    which the classifier judged apart, can still cross: the dialog shown
    for the later one stops the older, which the classifier settled. The
    cost: that stop ends when the older call settles, perhaps with the
    dialog still open, and the window reads working while it waits on Lee.
  - A plan's approval (ExitPlanMode) takes the same rule, and shows as its
    tool's permission prompt until the rows design it.
- **Claude asks a question** (a call of AskUserQuestion, from its start,
  whatever its check says): question, with the first question's text and
  how many there are, since then. It always puts its own dialog to Lee, so
  a permission request for it changes nothing.
- **The call settles** (its `tool.call`'s `next` resolves), answered and
  run, refused, or stopped: back to what the window was doing. Nothing the
  mod hears marks the moment a call answered at its dialog starts to run,
  so a command Lee allowed reads as its permission prompt until it ends.
  Of several calls waiting on Lee, the oldest shows.
- **The turn ends** (`turn.complete` of the window's own loop, whatever its
  reason: an answer, Lee's stop, an error): your turn, since then, or on its
  own work where the turn's Stop left something running. Before any turn,
  your turn since the window attached.
- **The turn stops** (`classic.Stop`, 22 October 2026): Claude Code's hook
  at the end of the main loop's turn, which lists what still runs in the
  background (`background_tasks`) and what is scheduled (`session_crons`).
  The mod passes it on, then reads the answer it settles to: a `block`
  from a hook beneath, without `preventContinuation`, carries the turn on,
  so nothing is heard, and the debug log says so. Otherwise the mod keeps a
  summary of what runs, never the lists: how many of each kind (agents,
  workflows, shells, monitors, the rest), the first's words (a shell's
  command, a workflow's name, else its description), and the one-off wakes,
  with the soonest's time. The latest Stop replaces what an earlier one
  left, and one with nothing running clears it. A Stop carrying an
  `agent_id` is not the window's and changes nothing; Claude Code 2.1.308
  sends a subagent's end as SubagentStop, never Stop, so none is expected.
  Left out of the summary:
  - a task Claude Code runs for itself and not for the turn (its dream,
    its auto mode's scan, a memory import), which never wakes the window;
  - a persistent monitor. The list does not say whether a monitor is
    persistent, so the mod reads it from the Monitor call that started it:
    its result gives its `taskId`, the list's id for the task, and says it
    is persistent by `persistent`, or by a `timeoutMs` of 0, as the engine's
    tool types have it. A Monitor running a command is listed as a shell;
    known by its id, it counts as the monitor it is. A call's task is kept
    until a Stop no longer lists it;
  - a monitor the mod never heard start. Claude Code runs some of its own
    (its watch on a published artifact, re-armed on session resume), which
    never end, and without hearing a monitor's call the mod cannot tell
    whether it is persistent. So one listed as a monitor counts only where
    its call was heard and it is not persistent; one started before the
    mod was loaded, or by an MCP server's tool rather than the Monitor
    tool, is left out too, erring toward your turn. (A Monitor
    running a command is listed as a shell, so one never heard is counted
    as the background shell it cannot be told from);
  - a recurring wake. A one-off wake's time is the minute its schedule names
    nearest now, in local time, as a cron reads it, within four years either
    side: its next, unless the last before it is nearer. A one-off still
    listed has not fired, so one whose minute has just passed is due now,
    not a day or a year away. One that cannot be read counts without a
    time: its minute or its hour not a number, or its day, month or weekday
    a range, a list, a step, a name, or out of its range.
- **Either order.** Whether Stop comes before `turn.complete` or after it
  is unverified, so neither waits on the other: what Stop heard outlasts the
  turn's end, and the state is worked out from both, whichever came last.
  With no turn running and nothing stopped, something running makes it on
  its own work, since the turn's end; else your turn. A Stop that changes
  the state rewrites the heartbeat as any change does.
- **Each loop's turn bounds what it left.** The window's turn starting or
  ending clears its own loop's tools, candidates and stops; a subagent's
  own `turn.complete`, which carries its `agentId`, clears that
  subagent's. So a background agent's prompt stays a stop across the
  window's turns (another agent finishing starts one), until it is
  answered or that agent's turn ends; and a call whose end the window
  never heard, as one under way across a reload, holds its tool or its
  stop only until its loop's turn ends.
- **A new conversation starts afresh** (`session.end`, as at a `/clear`):
  nothing heard, your turn since it attaches, not since the last
  conversation's turn ended.
- **Nothing in a call's way.** A change lands in the mod's memory at once;
  its write to `$.state` and the heartbeat's rewrite follow in order, and
  nothing waits on them. A call waits on the host only for the one
  `$.state` read that loads what an earlier load heard, before the first
  change of a load, and on the clock only at a question's start, whose stop
  it stamps; its end needs no time. A turn's start and end and a dialog
  wait on the clock for their times. A clock that fails leaves the last
  time it gave, and anything heard before it ever answered reads as since
  the attach. A rewrite waits its turn on the window's queue, so it may
  follow a sitrep tool's own work there.
- **Subagents.** A subagent's events carry its `agentId`, the main loop's
  none. Its run raises no `turn.start`, and its `turn.complete` is not the
  window's, so its turns neither start nor end the window's; and its tools do
  not show, the row showing the Agent call that runs it, by its
  description: several at once would only flicker. Its permission prompt
  or its question stops the window on Lee all the same: it shows in the
  window, and only Lee can answer it. Its own `turn.complete` ends only
  what it left (above).
- **For the live try**, each stop begun and ended goes to the debug log
  (`claude --debug`, or `--debug-file`; a mod's log reaches no other, the
  unified log among them), with its call, its tool and subject, and how it
  was matched: `sitrep: stop begun, call toolu_…: a permission prompt for
  Bash: gh pr create; its dialog shown, matched by tool, loop and input to
  the oldest call put to Lee`, and `stop ended, …; its call settled` (or
  the turn started or ended, its subagent's turn ended, or the
  conversation ended). A request no candidate matched, or one a settings
  hook answered, says so, as does a clock that failed.

## Claude's side

Tools the mod registers, schemas loaded up front. **Only the main conversation
can call them**; a subagent is told to put it in its report, and the
orchestrator decides what reaches the board.

| Tool | Does |
|---|---|
| `start` / `join` | begin a session (name, summary, its project's name, and its directory once known) and get its id; or join one by id, in whichever project it is filed |
| `status` | set the name, summary, the list of what is under way, and what is next |
| `ask` | post an ask: what it wants back (`wants`: a yes, a choice or words), its title, and where to look; a yes's button (`yes`: the verb Lee gives, `Go`, `Approve`, `It works`), a choice's `options`, or what a words ask's words are (`needs`: "the command's output"), each only on its own shape |
| `note` | add a note, with optional detail lines and a pointer |
| `park` | park something to come back to |
| `resolve` / `reopen` / `edit` | close, reopen or correct an item, with a reason. An edit may change what an ask wants, its `yes`, `options` and `needs`, under the checks `ask` makes; an empty `needs` clears it |
| `finish` | finish the attached session, with a reason, once it is complete and nothing is left on it; the window stays attached, and joining it again reopens it |
| `project` | rename the attached session's project, or say where it lives, or both; a name another project has is refused. It never moves a session to another project |
| `board` | read back the board's open items, what each ask wants back among them (`k1 wants a yes (Go)`), so Claude can check and repair it |

**When to start a session**, in every conversation's first message
(added once a conversation started one with nothing to go on but the tools,
and named it in internal shorthand):

- Start one when the work will run across several turns or will need Lee: a
  feature, a design, an investigation. Not for a quick question.
- Name it in plain words, as Lee would say it, with no internal codes, and
  record its id wherever the project tracks the work.
- Touch the board only once it is clear which project the work is on: the
  project being discussed, whatever folder the window started in. When Lee
  carries on with a session on the board, join it; otherwise start one, naming
  its project as Lee would say it, by the name it has on the board when it
  is one there, with the project's directory once known.
- As it goes: the status when what's under way changes, an ask whenever Lee is
  needed (said in the chat as well), a note for what Lee would want later,
  never running commentary; resolve what's done; finish the session once it
  is complete, with nothing left on it.

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

### The pane: a tree, with this session as home

```
 ⌂ Dashboard redesign 3  ≡ All projects 8
━━━━━━━━━━━━━━━━━━━━━━━━──────────────────────────────────────────

Dashboard redesign · Switchboard
Redesign the dashboard, area by area in Paper

ASKS ─────────────────────────────────────────────────── 3 waiting
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

NOTES ────────────────────────────────────────────── what happened
• Status: now also drawing Usage, round 2                      12m
• PR #82 merged                                                 1h
◇ Picked up from parked: A tmux indicator                       2h

PARKED ──────────────────────────────────────── 2 to come back to
◇ Paper thumbnails inline in Ghostty                            1d
◇ A Space-aware notes window                                    2d

RESOLVED ────────────────────────────────────────────── 4 resolved
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
  no session held, the pane says so, and there are no tabs.
- **Inline, the tab row ends with a wide close**, `[ ✕ close ]` at its
  right end, over plain rule: on the phone the band is not shown while the
  pane is (they share the row above the prompt, and the pane takes it),
  and the frame's ✕ is one cell. Its width comes out of the name's, so the
  row stays one line. Docked, there is none.
- **Browsing, the way back** sits in the row under the tab rule, at its
  left, one level up: `← All projects` over a project's view,
  `← <its project>` over a session's, a plain press drawn dim, cut short
  at the pane's edge. Home and All projects have none, and the row is
  blank. It carries no `⌂`: the first tab is always home.
- The header is the tabs, their rule and the way back's row, the same
  height in every view. Docked or inline, there is no row above the tabs:
  they are the pane's first line. There is no collapse: the phone's pane
  and the docked one start alike. Docked, the header stays still at the
  top while the list scrolls under it, its way back too, as Ready to send
  stays still at the foot; inline, it is the pane's first rows, and
  scrolls with it, its close too.
- A view's title line takes the whole width: its grey aside is cut first,
  then its title, with an ellipsis, so the line stays one row.
- **This session** (home, the default): name and summary, Asks, Status,
  Notes, Parked, Resolved. What waits on Lee comes first.
- **All projects**: this project first, then the busiest. Each project's open
  sessions hang off it as a tree. A project with nothing open, waiting or parked
  folds into one line at the bottom. A project opens its view.
- **A project**, reached from All projects, named as it is (`SitRep` stays
  `SitRep`): its sessions, this one first (`⌂`), each with what it is doing
  and its waiting count; Asks, every current session's asks, the newest
  first, each naming its session (`Request ledger: Keep the ledger…`) and
  answered right there as in a session's view; the project's Notes; and
  Parked, every session's parked items, each naming its session. A project
  has no Resolved.

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

  ASKS ─────────────────────────────────────────────────── 2 waiting
  ◆ Dashboard redesign: Review Sessions & Runway, round 1        2h
  ◆ Request ledger: Keep the ledger 400 days, or forever?        3h

  NOTES ────────────────────────────────────────────── what happened
  • Request ledger: Wrote the schema                             1h

  PARKED ─────────────────────────────────────── 2 to come back to
  ◇ Request ledger: Export the ledger as CSV                     1d
  ◇ Dashboard redesign: A tmux indicator                         2d
  ```

- **Another session** is the same view as this one, in the same order: its
  asks with buttons that answer them, its status, its notes, its parked, its
  resolved. While no window has it, its foot (above Ready to send) has
  `✓ finish this session`, for a session Lee left with things open by
  closing the window. It asks first, in place:
  `Finish <name>? Its open asks stop counting.`, `[ yes, finish it ]`
  `[ cancel ]`. Yes writes the finish into that session's folder, in this
  window's own file there (nothing goes to its inbox: it is Lee's act on the
  pane, not a reply to Claude), and the pane goes up a level, the session
  gone from it. A session with a window is still being worked: Lee finishes
  it there by telling Claude.
- **Asks:** each ask is a list's row (see Look): its mark, its title in
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
- **Resolved:** a section of its own at the foot of a session's view, under
  Parked, drawn once an ask has closed. Its heading counts the asks closed
  before now, ignored ones aside (`4 resolved`), and it lists the latest 3,
  the newest closed first. With more, `show all 4`, dim, opens it to every one
  and then reads `show fewer`. That toggle alone opens and folds it: opening
  or closing an item, in RESOLVED or anywhere on the pane, never changes how
  many it shows; closing the pane folds it. Each is a list's row: a green `✓`,
  its title, and how long ago it closed. Opened, as any item opens, it shows
  its whole title and hangs how it closed: the reply that closed it
  (`→ Approve`, `→ Forever`), or `resolved by Claude: <reason>`. Folding
  RESOLVED closes an ask opened past the latest 3, no longer shown. Asks
  holds only what is open, and the asks Lee's send just closed, for a moment.
- Each tab carries what waits there: home, this session's asks; All
  projects, every project's.
- Each view's first line sits under the way back's row.
- Every section heading has a few words on the right: `1 waiting`,
  `what happened`, `updated 12m ago`, `2 of 3 open`.
- **A line in Notes opens** to the detail behind it, as a tree. A project's
  Notes names each line's session before its text (`Request ledger: Wrote the
  schema`). A status change's detail lines open with their labels (`Added:`,
  `No longer:`, `Still there:`, `Next:`, `Name:`, `Summary:`), and any
  item's pointer with `see`, each label in its item's colour, the text after
  it soft. A note's own detail lines, as Claude wrote them, carry no label.
- **Parked:** a section of every session's view, under Notes, and of every
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
   - The mode stands from the press, for an ask the pane draws anywhere,
     and is checked against what the pane draws: another session's ask in
     a project's Asks is drawn from that session's brief, and the mode
     stands on the brief, while the press has the pane read that session in
     full at once. A mode whose ask's session the pane has not read is
     neither shown nor ended.
   - A plugin cannot give the keyboard to the prompt box: `$.ui.focus` moves
     only a site's own focus ring, while that site holds the keys. A press on
     the pane leaves the keys with the pane, so Lee presses Escape once to
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
- **Always shown.** The band shows it the whole time it stands, on the surface
  it was begun on, and it stands exactly while the next Enter there would be
  taken. Once its ask can take the reply no longer (closed, or a parked item
  picked up, its session finished, for an answer another already on its way,
  a send carrying the reply its comment would join) the band is back to its
  counts, the next Enter goes to Claude, and the next look ends the mode, so
  the ask, reopened, does not take it up again. Its session is read at every
  look, the pane open or not, for that.
- **Easy out.** Cancel is one press.
- **Typed messages are safe.** A prompt Lee sends while not answering goes
  to Claude as ever, and so does one not of Lee's own (a background task's)
  while answering.
- **It ends** with its ask, as above, a send carrying its reply ending it
  as the send is claimed; when the window takes up another session or lets
  go of its own, the conversation's end among them. A reload keeps it, in
  `$.state`, and the band still shows it.
- **It leaves nothing behind.** Ended without taking an Enter (cancel, its ask
  closing, its session finished, a send carrying its reply, another ✎, the
  window letting go), the mode takes back the words it put in the prompt for
  `✎ edit`: still just those, the box is emptied, so no Enter sends the pane's
  words to Claude; changed since, they are left as Lee has them, and a toast
  says so.

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

Everything Lee does on the pane queues here first; nothing goes one press at
a time. The box sits at the foot of **every** view of the pane while anything
waits in it, grouped by where each reply goes (`to this session`,
`to Request ledger`, a session of another project with its project's name).
Each reply hangs off its item with a `└`, on one row: its words clipped to a
line, `+3 lines` where there are more, and `✎ edit` to write them again in
the prompt (`✎ comment` on a bare yes or choice). Each has its own `✕`, and
the ask shows `↺ undo`. **send to Claude** sends them; **cancel all** clears
them.

**Docked**, the box stays still at the foot of the pane, under the pane's
list, which scrolls between it and the header; the list's last
line scrolls clear of it. **Inline** (the phone) it sits at the end of the
content. Each of its lines keeps to one row, cut short, so its height
follows from what it holds. Docked it takes under half the window: a queue
too long for that lists what fits and ends `… 3 more`, still one box. Only
Lee moves the list: queuing a reply, sending, a new ask arriving and the
pane drawing again leave it where Lee had it, and only a list that shrank
under it stops it short at its new end. Each place starts at its top,
every time the pane goes there: by a tab, the way back, a session's or a
project's row, or a band count, even one landing on the place already
showing; and so does the pane opened again. Opening or closing an item
leaves the list where it is. Tab and the arrows step between buttons, and
one below the fold brings its item into view; a click never moves the list
(see "One engine, two front ends").

On an inline pane (the phone layout) a send closes the pane as soon as it
is claimed: the message to this session claimed, or, with none, the replies
written into other sessions' inboxes. It never waits for Claude Code to take
the message, which can take minutes while Claude is mid-turn. A send that
Claude Code refuses still toasts and leaves its replies queued, and the
pane, opened again, shows them; a send that sent nothing leaves the pane
open. A docked pane stays open.

A group sent into another session's inbox stays in the box, its replies out
of the queue, until Claude has them all, and 10 minutes after, so
`delivered 2m ago` can be read. A group for a session no window holds stays
until one does.
A reply that never went in (see Delivery) says why, and lingers out the same
way: `not delivered: it changed since`, its item edited under it;
`not delivered: already answered`, another answer of Lee's to its item there
first; `not delivered: Claude closed it`, the item closed by Claude before
it went in; `not delivered: the session was finished`, before it went in.
One Claude was given though it settled nothing says both and why: its item
edited under it first, `delivered 2m ago, but it changed since`; or void as
its item closed, and marked only once Claude had reopened it,
`delivered 2m ago, but it was reopened since`.

**One answer to an item** (20 October 2026). A send carries a reply only
while its item takes it, as the fold would (see "Which replies go in",
under Delivery): an item open, and, for an answer, no other answer of
Lee's on its way to it. A comment on its way bars nothing: an ask holding
only another window's comment still offers its buttons, and Lee's answer
to it is carried. A reply to an item Lee answered first from elsewhere
(the SitRep window, another window's pane), the answer on its way or
delivered, or to one Claude closed, is not carried. It stays in Ready to
send, which says why where its `✎ edit` was, `not sent: already answered`
or `not sent: Claude closed it`, and so does its item's row, where it said
`not sent yet`; until Lee clears it with its `✕`, or the item, reopened,
takes it again. A send that carries nothing at all, to this session or any
other, toasts why: `Nothing to send: the items replied to are answered or
closed already.`, `…have changed since.` where none fits its item any more,
or `…have changed since, or are answered or closed already.` for some of
each.

### The band

One line above the prompt, right-aligned counts only, each one a way in:

```
                                             ◆ 1 ask   2 elsewhere   ▸ show board
```

`asks` opens this session; `elsewhere`, what waits on Lee in every other
current session, in every project, opens All projects. Below 64 columns the
words drop and the counts stay (`+2`), and the answering line says `Enter`
for `Your next Enter`, to leave the title room. The pane's show/hide button
always matches whether it is drawn. Where the pane sits inline and its
frame's ✕ is one cell, the open pane's button is a wide `[ ✕ close ]`
instead, its words kept at any width; on the phone, where the band is not
shown while the pane is, the pane's tabs end with the same close. Where the pane sits is
where Claude Code seated it, which only the pane's drawing knows: never
guessed from widths, since beside a docked pane the band's columns are the
transcript's. A `Client` in the pane's header (`hooks/draw/placement.tsx`)
posts the placement it was drawn with on its surface as it changes, and the
window keeps the last one each surface said, across closes, so a pane
opened again gets the right button from its first frame. Docked, not yet
said, or on a surface whose pane draws no `Client`, it is `hide board`.
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
it once it had a session to show).

When a new ask lands: the ◆ pulses, a toast names it, and a soft chime plays.
Dropped for now (11 October 2026): a macOS notification for asks. Back on
13 October 2026, from the menu bar app (see "The menu bar").

## Delivery

**The board never claims Claude knows something it was not told.**

- Replies for **this** session are sent as Lee's own message
  (`$.prompt.submit`, `asUser`), marked "From the board:". The board changes
  only once Claude Code takes it; a refused send leaves every reply in place.
  If Claude is mid-turn the message waits for that turn to end.
- Replies for **another** session go into that session's inbox in the shared
  folder, and so do the SitRep window's answers, through `sitrep answer` (see
  "One engine, two front ends"). The sitrep mod in that session's window
  picks them up and submits them as Lee's message (not as a message between
  agents, which Claude would give less weight). It writes back a delivered
  mark.
  - open and idle: in within a second or two;
  - mid-turn: waits for the turn to end;
  - no window open: waits in the inbox, goes in when the session is joined
    again.
- The send box shows each destination's state (`✓ delivered`, `⧗ waiting for its
  turn to end`, `○ closed: goes in when it reopens`, `✕ not delivered` once
  every reply went void), each ask shows
  `delivered 2m ago` or `on its way`, a toast sums it up, and the receiving
  window's band flashes `✦ 2 replies from the board` for 5 seconds. In the
  destination's own view, an ask whose reply is on its way says so; one
  whose answer is on its way offers no second, while one holding only a
  comment on its way still offers its buttons.
- The receiving window delivers only while it is the session's deliverer.
- **One message in flight per window**, whatever its source: this session's
  send, or the inbox. It is claimed in `$.state` before it is submitted, and
  holds its source, the session it goes to (project and session), the writer
  that claimed it, the text exactly as submitted, the replies it carries, when
  it was claimed, and whether Claude Code has taken it. The replies' ids are
  fixed at the claim: a send's are made then; the inbox's are the replies
  whose lines the message holds, no others. While it is in flight a look
  submits nothing, and a send says it waits for the inbox's replies.
- **Taken** is heard from the submit resolving with no drop, or from a turn
  starting whose text is the message's; whichever comes first marks it taken
  and writes it down. A load that starts with a message taken but not written
  down writes it down.
- **Written down** in the session it went to, whatever the window holds by
  then: through the hold when the window still holds that session as that
  writer, so the hold's own text stays in step; else into that writer's file
  there, read back and written whole. A send writes each reply and one
  delivered mark; the inbox, one mark naming its replies. Writing first reads
  the session: lines already there, or replies already marked, are not written
  again, so writing down twice writes once. A write that fails is tried again
  at the next look.
- **Refused** (a drop, or a throw): let go at once, its replies left as they
  were; the next look, or Lee's next send, tries again.
- **Never taken** (Lee deleted the queued prompt, or the submit was lost): let
  go once the window has gone quiet without it, 30 seconds after a turn of
  the main conversation (or the conversation) ended with no turn starting
  since. A queued prompt goes in as the turn before it ends, its own turn
  starting about 40 ms after (live), once the prompt's hooks have run; so a
  message still unheard by then was never going in, and letting it go never
  sends it twice. A send's replies are back in Ready to send, and a toast
  says so; the inbox's wait for the next look.
- **Which replies go in** (20 October 2026) is the fold's to say, every
  reader alike, each reply dated as it is written down and read in the order
  every reader reads in. A reply that closes its item, a yes, a choice, an
  answer, an ignore or a pick-up (a decide's comment too), is Lee's
  **answer**; a comment is not, and leaves its ask open for Claude to act
  on. A reply **on its way** is one neither delivered nor void, an answer or
  a comment; **Lee's answer on its way** is the answer alone, which bars
  another, where a comment on its way bars nothing. The rules read three
  facts the fold keeps, each recorded once, by the line that makes it true:
  - **Lee's answer on its way** to an item, at most one: recorded as the
    answer reaches the item open with none on its way, and ended as it is
    delivered or goes void.
  - **Who closed the item, and how**: Lee's answer, Lee's ignore, or Claude.
    Recorded by the line that closes it, a delivered answer or a resolve,
    and cleared by a reopen. The first close stands: Claude resolving an
    item Lee's answer closed adds Claude's reason and leaves it Lee's, so an
    ask Lee ignored stays ignored, out of Resolved.
  - **Why a reply is void**, when it goes nowhere: `changed`, `answered`,
    `resolved` or `finished`.

  Delivered and void are two facts, not one: a delivered mark is Claude's
  record that it has a reply, and makes delivered any reply it names,
  whatever else is true of it.
  - **One answer per item.** A reply reaching an item closed is void,
    `answered` where Lee closed it, `resolved` where Claude did. An answer
    reaching an item with Lee's answer on its way is void, `answered`. A
    comment bars no answer, and nothing bars a comment but its item closed.
    An answer barred so, by Lee's answer on its way, is read again should
    that answer go void, or stop being an answer, and so never go in as
    one: it reaches the item as the item stands then, on its way where the
    item takes it, as Lee's answer on its way now, else void for the reason
    that holds then. On an open item the replies void `answered` and not
    history are just those that answer barred, since a delivered answer
    closes its item and a reopen makes history of what it voided; the fold
    reads them off the replies, with no record of its own, and only those:
    one an edit made void `changed` stays so. So a second answer an edit
    left fitting, an ignore, goes in in place of the first the edit voided,
    and one whose first answer Claude's close voided says `resolved`; none
    says `answered` when no answer went in.
  - **Claude closing first.** A reply on its way when Claude closes its item
    is void, `resolved`. One on its way when the session is finished is
    void, `finished`, and so is one reaching a finished session: none goes
    in stale when a window takes the session up again. A resolve after Lee's
    close closes nothing, the first close standing, and the comments still
    on their way go void by that close, `answered`.
  - **Edits.** A reply that fits its item no more is void, `changed`: one
    not yet delivered, void or not, when an edit reshapes its item (an ask
    wanting a yes made to want a choice under Lee's yes), and one reaching
    an item an edit already reshaped. The item can be answered again. An
    edit to an open item also reads the replies still on their way again, in
    order, against the item as it now stands, so Lee's answer on its way is
    always an answer: an ask written by its kind, a decide, whose comment on
    its way was its answer, edited to want a yes or a choice, has that
    comment on its way as a comment, barring nothing, and what it barred
    reaches the ask again. An edit to a closed item reads nothing again: a
    comment Lee's close left on its way stays on its way, to go in.
  - **Marks.** A reply void `answered`, `resolved` or `finished` that a mark
    names goes in, its message having crossed what voided it. One void
    `changed` stays void: Claude has it, and it settles nothing, its item
    open to its new shape and waiting on Lee. So a send whose ask Claude
    makes a choice while the send waits out Claude's turn reaches Claude as
    Lee's yes, `→ Approve`, and the ask waits on Lee with its choice's
    buttons; Ready to send says the reply was delivered, but it changed
    since, and `board --json`'s `reply` reads it as delivered.
  - **Reopening.** A reply on its way across a reopen stays live: Lee's
    answer among them is still Lee's answer on its way, and once delivered
    it settles the reopened item as it would have before, so Lee's answer
    is never thrown away and the board's history is what Claude was told
    (Claude reopening a `replied` ask in the turn Lee gives the yes gets
    the yes, and the ask closes on it). A reopen of a closed item has no
    answer on its way, since a close voids it, though a comment Lee's close
    left on its way may still go in, leaving the reopened ask `replied`.
    What a reopen of a closed item does make history is every reply that
    stood settled, void or delivered, while the item stood closed: a fact
    the fold records as the reopen comes, in the order every reader reads
    in, never from comparing times, so a reply settled at the reopen's own
    moment is history where it settled first and live where it came after.
    History settles nothing and never comes back: a mark that names it
    later, its message having crossed the close, makes it delivered, keeps
    its void, and the item stands reopened, waiting on Lee; and no answer
    going void brings it back as one barred. A reopen of an open item, a
    `replied` ask, makes nothing history: an answer barred there by Lee's
    answer on its way is read again should that answer go void, and its
    mark settles the ask. `reply` reads the replies that are not history.
  - **Delivery.** A delivered answer closes its item, as Lee's, and voids
    the other answers on their way to it, `answered`, leaving a comment on
    its way to go in; a delivered comment voids nothing.

  So one window gives Claude one answer to an item. While its send waits
  out Claude's turn it delivers nothing else; an answer that came into the
  inbox meanwhile makes the send's answer void as it is written down, the
  send's mark makes it delivered, as Claude has it, and the inbox's goes
  void, never carried. Two windows on one session can each give their
  Claude an answer, one delivering the inbox's while the other's send waits
  out its own turn; the board keeps both delivered, as the two Claudes had
  them. A known limit of two windows on one session. `tests/replies.test.ts`
  holds a case for each rule. Ready to send says why a reply never went in
  (`not delivered: already answered`, and so on), and a send carries no
  reply its item takes no more (see "Ready to send").
- The inbox message is the board's own, as this session's is: it takes no
  board-change context, and written through the hold its lines are lines
  Claude knows of (`postKnown`). The rest rides in with Lee's next prompt.
- An ask's life: **open → replied → closed**. The board never closes an ask on
  a press, only once Claude has been told: a delivered reply closes it, or
  Claude resolves it. An ask open past a day shows its age. Nothing ages an
  ask out: Claude keeps the board clean, and Lee may be
  away for days and come back to the session.

## Storage

```
$XDG_STATE_HOME/sitrep/, else ~/.local/state/sitrep/
  projects/<project key>/
    project.json              name, directory, created and by whom: the project's own
    sessions/<session id>/
      session.json            name, summary, project, root, created and by whom: written once, by whoever starts the session
      <writer>.jsonl          one file per writer: each window as Claude Code's session id, the CLI as `cli`
      inbox/<sender>.jsonl    replies from other sessions, one file per sending writer; the CLI's answers as `cli`
      presence/<writer>.json  each attached window's heartbeat
    works/<session id>/       the old layout, its meta as work.json: read beside sessions/, never written, moved by the CLI
  ghostty-terminals.jsonl     each device's Ghostty terminal, as the jump last found it (see "The jump")
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
  (`code-84dbac88`, `switchboard-7a75d7ba`, from the folder a window
  started in): no key is renamed. Without a `project.json`, such a project is
  named as its sessions' `session.json` recorded it, its first letter a capital
  (`Code`). Matching and showing read `project.json` first, so writing one
  there (the `project` tool does, from a window holding one of its sessions)
  relabels the project in place.
- **Session id:** `sr-` and six characters (`sr-k3f9qa`): short enough for
  Claude to record, and easy to grep. Items and replies get four characters,
  unique within their session. A new session's id is unlike every one filed,
  under either layout (below).
- **Two layouts, side by side** (19 October 2026): `works/` became
  `sessions/` and `work.json` `session.json` with the words, as "Versions
  side by side" has it. Windows not yet reloaded still write the old, so
  every reader, the mod's and the CLI's, reads both as one (core's
  `layouts.ts`): a project's sessions are both folders' sessions; a
  session's meta is its `session.json` where that reads, else its
  `work.json`; a writer's file, or a sender's, under both names is every
  line of both, a line in both, byte for byte, once; of a window's two
  heartbeats, the one seen later. Never today's file alone: a window not
  reloaded that sleeps through the move wakes still writing its whole file
  under the old name. Every read of the two goes through one place, which
  reads the old layout first, then today's, never both at once: each step of
  the move puts a file under its new name before the old name loses it, so a
  file the move takes between the two reads is found under the new, where
  reads at once could miss it under both; and a project's folder is listed
  anew for today's layout, which the move makes as it goes. A file listed,
  or found there, and gone by its read is not there. Writers write
  `sessions/` alone. A window's own file and its letters are built from what
  it had under both, so its first write carries every line; the CLI appends
  under `sessions/`, its count going on from its file under both and a torn
  last line of the file it appends to ended first, and carries nothing
  across, since reading reads both and the move merges what is left.
- **The move** is the CLI's, as each command starts: a mod's `$.fs` can
  neither delete nor rename. There is something to move while an old session
  folder holds a file the move acts on, a meta, lines or a heartbeat;
  anything else left under `works/`, as a Finder file or a folder that is no
  session, is not, and costs only its listing. It waits while any window on
  the board, by its latest heartbeat under either layout, says no `version`
  (below), has not let go, and was seen within a week (`OLD_WINDOW_MS`):
  such a window still writes the old layout, and a Mac may sleep for days
  with one open, which wakes writing it still. A window's later heartbeat
  saying its version, as after its reload, stands for its earlier ones. A
  heartbeat file there that does not read, torn mid-rewrite or not to be
  read at all, keeps it waiting a week from when it was written. Then each
  old session's files go into `sessions/`: one `sessions/` lacks is linked
  in and its old name unlinked, so it never lands over a file a writer makes
  there that moment; a writer's or sender's file under both is merged, the
  lines today's lacks appended, never rewritten whole, so a run appending
  then keeps its line; a heartbeat seen later than today's replaces it in
  one step, a rename, so two runs replacing it at once never lose it, and
  one seen as late is dropped; a `work.json` beside a `session.json` that
  reads is dropped, and replaces one that does not, as readers read it then.
  A file it does not know, under both, stays where it is. Emptied folders
  go, `works/` last. As readers read both, every state partway through reads
  the same board, and two runs moving at once are harmless: a file another
  moved first is left so, and a line both append reads once. A move that
  fails is told on stderr and the command runs on; the next run moves what
  is left. With nothing to move it costs a listing of `projects/`, of each
  project's `works/`, and of each session folder left there. Tried live over
  a state folder of its own (19 October 2026): an old session read and
  posted to while a versionless window was live, its CLI line under
  `sessions/` counting on from the one under `works/`; moved by the next run
  once that window said its version, `cli.jsonl` merged, `work.json` now
  `session.json`; run again, nothing changed; and three runs at once over
  six old sessions left nothing under `works/`, a line two runs both
  appended read once.
- **What the changeover still costs.** A window not yet reloaded reads only
  `works/`, and sees nothing written under `sessions/` until it reloads, as
  with newer lines. While one is live on a session it delivers that
  session's inbox, by its own count, since it sees no heartbeat under
  `sessions/`, and the windows on today's version wait, so two never both
  submit: letters under `sessions/inbox`, which it cannot see, wait until it
  reloads or leaves. One that comes live on a session after a window on
  today's version delivered the letters in its inbox under `works/` submits
  them again: it cannot see the marks that window wrote under `sessions/`.
  One holding no session writes no heartbeat, so the move cannot wait for
  it; should it later join a session already moved, it finds nothing of it,
  and cannot hold it until it reloads. One that wakes after the week, its
  `work.json` moved, reads its session as gone, and holds delivery there,
  its heartbeat live again, until it reloads or leaves. And the old layout
  stays up to a week after the last such window was seen, unless it let go.
- One file per writer, so there are no locks and no daemon. A mod's `$.fs` can
  only write whole files, so each mod rewrites its own file; the CLI appends.
  Runs of the CLI at once share its file: each run's line lands whole (tried
  with 20 runs at once, and lines up to 200 KB), and two runs that read the
  file together write the same count, which reading never minds: it orders by
  time, then writer, then count, and keeps both (see "Reading merges", below).
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
  naming the replies Claude has been given; `finish`, the session finished,
  saying who (`lee` or `claude`) and with an optional reason; and
  `unfinish`, a window joining it again. The session holds the latest finish,
  when, by which writer and why, until an unfinish clears it. Who is a field
  of its own because Lee's pane and Claude's tool write as the same
  window.
- Reading merges every writer's lines into one order: time, then writer,
  then count. A writer's own file and its letters in an inbox count apart,
  so of two lines of theirs at one moment the file's goes first, whatever
  their counts (20 October 2026): the CLI's finish in `cli.jsonl` before its
  answer in `inbox/cli.jsonl`, the same in every reader. A reader can catch
  a file mid-write, so a torn last line, a bad line or one of a kind or
  version it does not know is skipped, never fatal. A line of an older
  version is upgraded to today's shape as it is read, by core's upgrader for
  that version, so nothing past the reader knows an old shape (16 October
  2026; see "Versions side by side", under "Where it lives"). Built 19
  October 2026 (`core/versions.ts`): each format, a line's, `session.json`'s
  and `project.json`'s, has a table of upgrades, one per past version, each
  taking an object of its version to the next, chained from the object's
  own; a format's version is one past its table, so each moves only as its
  own shape does, and an old reader still reads the files whose shape has
  not. Every table is empty so far, every format at 1. The file keeps the
  version its line was written in: nothing rewrites an old line. A line a
  file holds twice, byte for byte, reads once.
- The status shown is the latest across writers. A status change is logged by
  the board as it reads, comparing each status with the one before; it is
  never written down.
- A reply counts as delivered once a writer **in its session** has written a
  `delivered` mark naming it: Claude has it. For this session, the mod
  writes the reply and the mark together, once Claude Code has taken the
  message. For another session, the sender writes the reply into that
  session's inbox, and the window that submits it there writes the mark to
  its own file. The CLI's answers go in as another session's replies do, as
  its letters, `inbox/cli.jsonl`, appended to; the window's mark is the
  trace the CLI reads them delivered by (20 October 2026). A reply is void
  where "Which replies go in" (under Delivery) says so, its reason kept with
  it in the fold, none on disk: a second answer to an item, one reaching an
  item closed or a session finished, one on its way as Claude closes its
  item or the session finishes, one an edit leaves fitting its item no more;
  and a mark makes any of those go in but the last, which it makes delivered
  and leaves void, settling nothing. Only replies count from an inbox.
- **Presence:** a mod can't tell that its own window died, so each attached
  window rewrites its heartbeat (`attachedAt`, `seenAt`) every 30 seconds,
  and a session is open while a heartbeat is under 90 seconds old. A mod
  can't delete a file either, so a window that lets go adds `leftAt`. Of
  several windows on one session, the one attached longest submits its
  inbox, so two never both do; while a live window on a release that says no
  `version` is on it, the longest attached of those, and the rest wait (see
  "Storage"). A heartbeat also says `where` its window is, as far as that is
  known (see "The menu bar"): `device`, `terminal`, and `tmux` with its
  `socket` and `pane`. It is read field by field, a bad one dropped, and a
  heartbeat is never lost over it; one written before it reads as ever. It
  also says the sitrep `version` its window runs (19 October 2026): the
  `version` in the plugin's manifest, `.claude-plugin/plugin.json` under the
  plugin's folder, read once as the mod loads and kept for the load, a
  failure too, since the clone is the live plugin and the manifest on disk
  may by then be a newer checkout's than the code the window runs. A
  manifest that cannot be read leaves it out, says so once in the debug log,
  and the heartbeat beats on; that window then reads as one on an old
  release, holding the move and delivering first, which is safe, and rare.
  It is read as `where` is, field by field; a heartbeat with none, not let
  go, is a window on a release from before heartbeats said it, which still
  writes the old layout: it keeps the move waiting, and while live delivers
  its session's inbox (see "Storage"). `sitrep watch` says which windows
  need a reload, for the menu to list. It also says the window's `state`
  (19 October 2026), with what the row shows of it, rewritten at once as it
  changes (how the mod hears it is under "A session's state"):

  ```
  "state": { "is": "permission", "since": 1760000005000,
             "tool": { "name": "Bash", "subject": "gh pr create" } }
  ```

  - `is` is `working`, `permission`, `question`, `onItsWork` or `yourTurn`,
    and `since` when it began: the turn's start while working, the prompt's
    or the question's showing, the turn's end, or before any turn the
    attach. So the row's time is how long the turn has run, or how long it
    has waited.
  - `work`, on its own work alone (22 October 2026), is what it waits on, as
    the turn's Stop listed it: each kind running, of `agents`, `workflows`,
    `shells`, `monitors` and `others`, as its `count` and its `first`'s
    words, cut as a subject is; and `wakes`, their `count` and `at`, when
    the soonest is due of those whose schedule reads. A kind with nothing
    is left out:

    ```
    "state": { "is": "onItsWork", "since": 1760000005000,
               "work": { "agents": { "count": 3, "first": "Review the diff" },
                         "wakes": { "count": 1, "at": 1760000725000 } } }
    ```
  - `tool` is the tool working runs, or the one a permission prompt asks for:
    its `name` as the model calls it, and its `subject` where it has one, from
    one argument (core's `subject.ts`): Read's, Edit's, MultiEdit's and Write's
    `file_path`, NotebookEdit's `notebook_path`, LSP's `filePath`, Bash's
    `command`, Monitor's `description`, Grep's and Glob's `pattern`, WebFetch's
    `url`, WebSearch's `query`, Agent's and Task's `description`, and Skill's
    `skill`; any other tool, an MCP tool among them, shows by its name alone.
    `question` is a question's first `text` and the `count` asked. Each text is
    one line, cut to 200 characters with an ellipsis, so a heartbeat stays small
    whatever the command.
  - It is read field by field, as `where` is: a state of a kind the reader
    does not know, or without its time, is dropped, as is a bad `tool` or
    `question` of it, and the heartbeat is kept; one written before reads
    as ever, with no state. A later kind or field is added beside these, so
    an older reader passes over what it does not know.
  - A change is written at once, through the window's serialised writes, not on
    the beat, which goes on as before and says the state as it stands, so a
    state write that failed is put right within a beat. A burst of quick calls
    is not written call by call: within a second of a rewrite, a change waits
    for the second to pass, then the state as it stands by then is written once
    (a rewrite still waiting a second past its time is taken never to have
    fired, its timer refused or dropped, and waited on no more); a change back
    to what the heartbeat says writes nothing, and holds nothing back. So a
    change is at most a second late, inside a reader's poll of a second or two.
  - A window holding no session writes no heartbeat but goes on hearing,
    so attaching mid-turn writes the state as it stands. A window that lets
    go says no state.
  - The mod's own boards leave it out: the board in `$.state` and the
    boards around it keep each presence without its `state`, which nothing
    the mod draws reads, so a neighbour working rewrites no board, redraws
    no pane and announces nothing (the board Claude is told it has seen
    holds no presence at all). Core's parse still reads it, for `sitrep
    watch`.
  - Each load of the mod stamps its heartbeat with `loadedAt`, when it
    loaded (session.start, its first hook, reads the clock once), and reads
    the heartbeat file before rewriting it: once the file carries a later
    load's stamp, it writes neither the heartbeat nor `$.state` again, and
    says so once in the debug log. A call in flight across
    `/reload-plugins` may settle in the load it began in, whose memory is
    stale by then; the engine's types say a reload cancels the old load's
    pending waits, not that its other continuations never resume, so the
    fence stays. The file is read live, as `$.state` inside a long dispatch
    is not. A stale load's read and a newer load's write may still cross
    once, and the newer load's next rewrite, at its next change or beat,
    puts it right.
  - What the window has heard (its turn, the tools it runs, the calls put to Lee
    with their tool, loop and arguments' digests, the stops, each with its
    loop, the summary of what its last Stop listed running, and the tasks its
    Monitor calls started, each with whether it is persistent) is kept in
    `$.state` (`activity`), so a `/reload-plugins` keeps it,
    and in the mod, which reads it from there once a load and writes it back at
    each change. It is never read back: every `get` of one dispatch reads one
    moment, and a call's hook, whose dispatch lasts as long as its tool runs,
    would read what stood as the call began and miss a prompt raised meanwhile
    (found in the test kit). A new process starts with nothing heard: your turn
    since the attach, until its next event.
  - It is read field by field, as a heartbeat is, since an earlier load may
    have kept another shape: a time or a list that does not read is as
    nothing heard has it, and an entry that does not read is dropped.
  - Each write carries the load's `loadedAt` and is made only on the version
    the load last saw (`ifVersion`). A miss is another load's write: an
    earlier load's is read and written over; a later load's means this one
    is stale, and it writes neither `$.state` nor the heartbeat again.
- Readers list and `stat` the folder every second or two (a mod cannot watch
  files) and read only what changed; each session's read lists its project's
  folder too, so a rename shows on every pane within a look. The sessions
  around the held one are read every 5 seconds, each through its reader:
  they are glanced at, not watched. Every project is read, the pane open
  or closed, for the band's `elsewhere` and the All projects tab: each look
  lists every session's folders and reads again only a file that changed. With
  the pane open, the session it looks at and those replies wait for or
  went to are read in full too, and so is the session of the item Lee is
  answering in the prompt, open or not, read at once as the press begins
  answering it.
- The pane's last view lives in the window's `$.state` only: where it looks,
  the item opened there, and, apart from that, the session whose RESOLVED
  shows every closed ask, and where Claude Code last seated the pane on each
  surface, kept when it closes (see "The band"); a pane an older load saved,
  without either, reads as none. `$.store` is unused so far.

## One engine, two front ends

The shape stays, decided again with Lee on 16 October 2026, when Lee
stepped back to design SitRep properly before the app is built for real.
Core holds the logic, and the mod and the CLI are its front ends. The folder
is the state, with no database, no server and no background service. The
SitRep app reads the board through the CLI.

Every later front end sits on the same core:
- `sitrep mcp`, for other agents to post to the board;
- `sitrep serve`, for a phone or a website.

Once a remote surface exists, the SitRep app hosts serving: it runs
`sitrep serve` itself, once Lee turns it on, and the folder stays the
truth. There is still no background service. None of it is built now. Lee:
"we might do a phone app, we might not"; the architecture allows it.

- **core**: a plain TypeScript module, no file system, no Node: the folder's
  format, the event shapes, the rules (what a reply does to an ask, what counts
  as waiting, what folds away). Tested on its own.
- **the mod**: Claude Code's hooks module. Draws the pane and the band;
  registers Claude's tools; reads and writes through `$.fs`.
  - The engine reads a hooks module's calls on `$` off its source, and will
    not load one that hands `$` to an import, or whose `$.state` values are
    not consts of the file that reads them. So `hooks/register.tsx` spells
    every call on `$`, and hands the other modules a host bound to it.
  - `$.state` holds JSON data, which keeps no Map or Set, so the folded
    session sits there as plain data, its items and ids as lists. It outlives
    a reload of the mod's code, and the window takes its session up again; a
    new process (`--resume`) starts without it, and the window takes up by
    itself the session its conversation was last seen in (item 5 under
    "Sessions outlive their windows"). What a load from before the words
    changed left there (a session as its `work`, RESOLVED in full as
    `doneInFull`) is read in today's names, so a window reloaded mid-session
    keeps its session, its place on the pane and Ready to send
    (`hooks/older.ts`).
  - Drawing lives in modules of its own (`hooks/draw`): pure functions from
    a surface's element table and plain data to a tree, what a button does
    handed in as actions bound to the host. JSX's `h` is global in every
    module of the plugin. What a surface can do beyond drawing (whether Lee
    can write back from it in a prompt the mod hears, and whether the mod
    can fill that prompt) is read off `e.surface`. An item's address is its
    session's id then its own (`sr-k3f9qa:k3f9`): what opens it, and every
    button of its, keyed by it (`pick:sr-k3f9qa:k3f9`), since a project's
    view and Ready to send list several sessions' items, and two sessions'
    items may share an id.
  - Docked, the pane scrolls its own list, clipped above Ready to send
    (settled by a probe and a live run, 2.1.295). A box floated over the
    foot of a tree the engine scrolls, placed again on every drawing,
    flickers by design: the engine paints the scrolled frame before the
    drawing that puts the box back (26 of 195 frames, live). So the engine
    is given nothing to scroll.
    - **The engine.** The tree is a row shorter than the window, so the
      engine's window never moves, and that row tells a page key (the
      window's rows) from Home and End (the tree's). The scroll hook holds
      the engine at the top (`offset: 0`).
    - **The pane.** The header (the tabs, their rule, and the way back's
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
      it before, and closing the pane forgets it. The scroll hook moves it: the
      wheel as it turns, a page key by the rows showing, Home and End to the
      ends, stopped at either. Nothing else does: the drawing only stops it
      short at the end of a list that shrank, or of a window that grew. It
      clips always, docked, not only while Ready to send holds something:
      switching between the engine's window and the pane's own as the
      queue filled would move what Lee is looking at.
    - **Measuring.** The view is drawn as a list of blocks: the line under
      the header, each section's heading, each entry of a list (an
      ask, a line in Notes, a parked item, a closed ask, a session, a project),
      Status whole, the foot, and a blank row closing the list; the blank
      row between sections is the next block's own. Docked, a `Client`
      spans each block down the column the pane keeps free beside its
      lines (`hooks/draw/measure.tsx`), drawing nothing, and posts the rows
      the block takes whenever they change. It is keyed by its block, a
      session's item by its address. The list is as tall as its blocks, and a block sits as far
      down as those above it; one not measured yet counts a row. Each
      measures once as it is laid out, and again as it grows or the width
      changes (about 140 posts over a long live run). The rows and the list
      as last drawn are kept in a module, since a render hook cannot write
      `$.state`; a reload disposes the `Client`s, and new ones post again
      (live). The test kit lays a `Client` out with no rows, so a measuring
      `Client`, which waits for rows, never posts there: its tests post each
      block's rows as its `Client` would. A `Client` that posts as it draws
      (the pane's placement) does reach the plugin under the kit.
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
    - **Dock only.** Inline, the pane flows as it always has, the header
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
    refused the call, so the pane submits from its send button's own
    handler.
  - The mod's own `prompt.submit` hook does not see a prompt the mod
    submitted from a button's handler or a timer (live, and in the test
    kit); from its `ui.press` hook it does. Either way the pane's own
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
    either first (live probes). Inbox delivery runs on a timer
    `session.start` begins, never one a tool call began, so the engine never refuses it
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
  later the tmux indicator; and for the SitRep app, which answers and
  finishes through it.

  ```
  sitrep note <text> [--detail <line>]... [--ref <ref>]
  sitrep ask <title> --wants yes|choice|words [--yes <label>] [--option <choice>]... [--needs <words>] [--where <words>] [--ref <ref>]
  sitrep park <title> [--where <words>] [--ref <ref>]
  sitrep status [--name <words>] [--summary <line>] [--now <line>]... [--next <line>]
  sitrep answer <ask> (<answer> | --ignore)
  sitrep finish
  sitrep board [--json]
  sitrep list [--project <name>] [--json]
  sitrep jump
  sitrep watch
  ```

  - It writes as the writer `cli`, appending to `<session>/cli.jsonl`, and an
    answer to its letters in the session's inbox, `<session>/inbox/cli.jsonl`,
    the same way: each file's count goes on from that file under both
    layouts, a torn last line ended first, and nothing is rewritten. It never
    writes a delivered mark or a heartbeat: it is never a window on the
    session. Before a command reads the board, it moves the old layout into
    today's, once no window still writes it (see "Storage").
  - What it posts is checked by core as Claude's tools' posts are, and a
    refusal prints the check's words. A post prints its item's id and nothing
    else, so a script can keep it. An ask says what it wants back with
    `--wants`, as the ask tool does, and its `--yes`, `--option`s or
    `--needs` with it. A status gives only what changed, as the
    status tool does; `--now ""` and `--next ""` clear. The last argument takes
    every word left, so a title needs no quotes.
  - The session is `--session sr-xxxxxx`, else `$SITREP_SESSION`, looked up
    in every project. `list` takes none: every project's current sessions,
    grouped, in the order the first message lists them (those whose
    directory holds the folder the CLI runs in first); a finished session is
    never among them.
    `--project <name>` gives only that project's, matched as `start` matches
    it, and a name no project has is refused. `--all` is gone: every
    project is listed already.
  - Exit codes: 0 done; 1 a usage error, a refused input or a failure; 2 no
    such session.
  - `list --json` is for tools, and stable: every field is always there (a
    list empty, any other value null where there is none), and `v` moves only
    with a change a reader would trip on. `here` is the key of the project
    the CLI runs in: the nearest whose directory holds its folder, else null.
    It is listed even with no current sessions, the first of `projects` unless
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

    `onScreen` says whether a jump can reach the session (see "The jump",
    step 2). Only `--json` works it out, from tmux, asked twice per socket
    however many sessions there are; it selects and knocks on nothing. Plain
    `list` runs no program.

    `board --json` is
    `{ v, project: { key, name }, work, asks, parked, log, resolved }`: the
    session as `list` gives it, its open asks, what it parked, its latest log
    lines, and its resolved asks (20 October 2026), closed, the ignored aside,
    the newest closed first, as a session's Resolved lists them. Its `v` is 2
    since its asks say what they want back (`wants`, `yes`, `needs`) in place
    of their kind; `list`'s stays 1. Each ask, open or resolved, carries
    `reply`, where Lee's reply to it stands (below, under `answer`), and a
    resolved one when it closed, by Lee's answer or Claude's resolve, and
    Claude's reason where Claude resolved it with one, Lee's answer having
    closed it first or not:

    ```
    { "id": "k1", "wants": "yes", "yes": "Go", "title": "Give the go for stage 3",
      "where": null, "options": [], "needs": null, "ref": null,
      "state": "closed", "at": 1760000000000,
      "reply": { "is": "delivered", "isAnswer": true, "words": "→ Go",
                 "since": 1760000090000 },
      "closedAt": 1760000090000, "reason": null }
    ```

    No `v` moved for 20 October 2026's changes. `reply` and `resolved` are
    fields added, which a reader that does not know them passes over. One
    meaning changed too: `waiting`, in `list --json`, `board --json` and
    `watch`, leaves out an ask Lee's reply is on its way to, an answer or a
    comment (see "A session's state"), and `watch`'s session `state`, its
    rows and its head follow it, while its session's `asks` keep such an
    ask, its `reply` saying it is on its way. `watch` and `board --json`
    list a session's asks alike, by core's `openAsks`: those open, waiting
    or replied. No reader reads those yet (the SitRep window is their
    first), and a reader of the old meaning would only count fewer asks
    waiting on Lee, never trip on a shape.
  - `answer` (20 October 2026) answers a yes or a choice ask, or ignores
    any ask, as Lee does on the board, for the SitRep window to answer
    through (see "The SitRep window"): the ask by its id, then the answer in
    the words of the button Lee pressed, a yes ask's yes (`sitrep answer k1
    Go`) or one of a choice ask's options (`sitrep answer k2 Keep it`),
    matched exactly, as the board shows them; or `--ignore` in their place,
    the pane's `✕ ignore`, which every ask offers, a words ask among them.
    It prints nothing.
    - It writes a reply, `yes`, `choose` with its option, or `ignore`, into
      the session's inbox as the CLI's letters, as the pane's replies to
      another session go in (see "Delivery"): the session's window delivers
      it to Claude as Lee's own message, as it delivers any reply, and marks
      it delivered. A session no window holds is answered the same way: the
      answer waits in its inbox, and goes in once a window takes the session
      up. The reply is dated as it is written, once its checks are done, as
      every reply is (see "Which replies go in").
    - It never closes the ask: the delivered mark does, as for any reply, or
      Claude's resolve. Until then the ask stays open, its answer on its
      way, and waits on Lee no more (see "A session's state"). An ignore,
      once delivered, drops the ask, as the pane's does: it leaves the asks,
      with no moment of "sent, and Claude has it", and Resolved lists none,
      though Claude resolves it after.
    - Refused, exit 1 and nothing written: words, a comment and a
      permission prompt, which need Claude Code's prompt (`k3 wants words,
      which need Claude Code's prompt: answer it there.`; a comment is no
      word it takes, `There is no --comment.`; a permission prompt is no ask
      on the board, and is answered in its window); a decide written before
      asks had options, which offers none to choose (`k5 gives no options to
      choose from: answer it in Claude Code's prompt.`); an ask closed (`k1 is
      already closed.`) or ignored (`k4 is already ignored.`); one with
      another answer of Lee's on its way already, from the pane or the CLI,
      since an ask takes no second answer, as the pane offers none (`An
      answer to k1 is on its way already.`), though a comment on its way bars
      none, as on the pane; an answer the ask does not take (`k2 wants a
      choice: answer it with “Keep it” or “Drop it”.`); an item that is no
      ask, or no item; and an ask of a finished session, whose asks wait on
      Lee no more, as an answering mode ends with its session finished; an
      answer given with `--ignore` (`Give an answer or --ignore, not
      both.`); and any answer while the window that delivers the session runs
      a sitrep behind the CLI's own, by the comparison `watch`'s
      `needsReload` makes (`A window holding this session runs an older
      sitrep: run /reload-plugins in it first.`): one from before today's
      layout reads only `works/`, and would never see the answer written
      under `sessions/`; one from before this release voids no second answer
      (see "Versions side by side"). The CLI's own version is its plugin's
      manifest's. An unknown session is exit 2. Where several refusals
      apply, the first of these says why: the session finished; no such
      item, or one that is no ask; the window behind; the ask ignored,
      closed, or with an answer on its way; then the answer given.
    - Two runs answering one ask at once can both find it with nothing on
      its way, and both land. Only the first goes in, the second a second
      answer, void (see "Which replies go in", under Delivery), so the window
      gives Claude one answer. Both may write the same `seq` in
      `inbox/cli.jsonl`, each counting on from the file as it read it; that
      is harmless, as two lines of one writer at one moment and one `seq`
      fall to their order in the file, the same in every reader.
    - Where Lee's reply stands is core's, from the files (`replyState`), and
      `board --json` and `watch` give it on each ask, as `reply`, from its
      replies but those a reopen of the closed ask made history (see
      "Reopening", under Delivery), by who closed it. `isAnswer` says
      whether that reply is Lee's answer, which bars another, or a comment,
      which bars nothing; on its way, it is whether the reply is the ask's
      answer on its way, the very fact the bar reads, so an open ask whose
      `reply` is `onItsWay` with `isAnswer` true takes no answer, as
      `sitrep answer` refuses one and the pane offers none, while one with
      only a comment on its way still takes one, its buttons standing. An
      ask Lee's answer closed reads that answer, `delivered`, since the
      window's mark, whatever comment is still on its way. One Claude closed
      reads `delivered` where Lee's answer reached Claude all the same, the
      message crossing the resolve; else `notDelivered`, since Claude closed
      it, where Lee's reply was still on its way then, or reached it after:
      it never goes in, as a pane's send to a closed ask does not, and the
      card can say so. An open ask reads `onItsWay` once a reply is in the
      inbox, not yet delivered, since it was written, Lee's answer before a
      comment where both are; else `delivered` where Claude has an answer
      the ask, edited under it, no longer takes (it waits on Lee again);
      else `null`, with none sent, one gone void as its ask was edited under
      it before Claude had it (the ask can be answered again), or only a
      comment Claude has. `words` is the reply as the board shows it on one
      row (`→ Go`, `ignored`, `comment: “Tighten the copy”`). Those are the
      SitRep window's card: "on its way" on an open ask, "sent, and Claude
      has it" on the ask the answer just closed, as the pane's Asks keep one
      for a moment, and then Resolved, where `board --json` lists it.
  - `finish` (20 October 2026) finishes a session no window holds, as the
    pane's `✓ finish this session` does, for the SitRep window's `✓ Finish
    this session`: Lee's finish, `{ "type": "finish", "who": "lee" }`, in the
    CLI's own file, nothing in the inbox. It prints nothing. Asking first is
    the window's. A session a live window holds is refused (`Dashboard
    redesign is open in a window: tell Claude there to finish it.`), as is
    one already finished (`This session is already finished.`); an unknown
    one is exit 2.
  - `jump` brings the terminal window showing the session to the front, on
    whatever Space it is (see "The jump"), and prints nothing. A session no
    jump can reach is refused (`Dashboard redesign is not on screen: no
    terminal window on this Mac shows it.`), as is one whose devices no
    terminal answered, or whose pane's window tmux would not select.
  - `watch`, designed 16 October 2026 and built 19 October 2026, is how the
    SitRep app hears the board: one per Mac, which the app starts as its
    child, so it stops with the app, and the app starts it again if it
    exits: no daemon. It takes no words but `--help`. It reads the one
    folder that holds every project and session (see Storage), under both
    layouts as every reader does, and what it prints is core's: a session's
    state and its rows (`core/rows.ts`); the board as every surface shows
    it, what is new, and when the board next changes by time alone
    (`core/feed.ts`).
    - **A line per change.** A line of JSON at its start, then one only when
      what it would print differs from the last, its own time aside, each
      written whole and at once. A finished session is in no row and no
      project, though a window still live on it is among the windows; an
      away session is in both, its asks still counting. It carries no
      project without a current session, nor does `list --json`, so the
      SitRep window's Projects is every project it carries, those with
      nothing open among them (see "The SitRep window"). A state folder not there yet, as
      before any Claude window has written, is an empty board, and what
      comes into it shows.

      ```
      { "v": 2, "at": 1760000060000, "version": "0.2.0",
        "head": { "needYou": 2, "sessions": 1 },
        "rows": [
          { "session": "sr-k3f9qa", "section": "needsYou",
            "isAway": false, "project": "switchboard", "letters": "Sw",
            "lines": [
              { "key": "ask:sr-k3f9qa:k1", "is": "ask", "ask": "k1",
                "writer": null,
                "first": { "lead": "Review round 1", "mono": null,
                           "subject": null, "more": null,
                           "until": null },
                "since": 1760000000000 },
              { "key": "stop:sr-k3f9qa:b1c2d3e4-...:1760000030000",
                "is": "permission", "ask": null,
                "writer": "b1c2d3e4-...",
                "first": { "lead": "Allow Bash",
                           "mono": "gh pr create --draft",
                           "subject": null, "more": null,
                           "until": null },
                "since": 1760000030000 } ],
            "second": "Switchboard · Dashboard redesign",
            "since": 1760000000000 } ],
        "projects": [
          { "key": "switchboard", "name": "Switchboard",
            "directory": "/Users/lee/Code/switchboard", "open": 1,
            "waiting": 1, "parked": 0, "updatedAt": 1760000000000,
            "sessions": [
              { "id": "sr-k3f9qa", "name": "Dashboard redesign",
                "summary": "...", "now": ["..."], "next": null,
                "isOpen": true, "waiting": 1, "parked": 0,
                "updatedAt": 1760000000000, "state": "needsYou",
                "since": 1760000000000,
                "doing": { "is": "working",
                           "line": { "lead": "Reading", "mono": "...",
                                     "subject": null, "more": null,
                                     "until": null },
                           "since": 1760000000000 },
                "asks": [ ... ] } ] } ],
        "windows": [
          { "writer": "b1c2d3e4-...", "session": "sr-k3f9qa",
            "name": "Dashboard redesign", "project": "Switchboard",
            "version": "0.2.0", "needsReload": false,
            "where": { "device": "/dev/ttys001", "terminal": "ghostty",
                       "tmux": null },
            "state": { "is": "working", "since": 1760000000000,
                       "tool": { "name": "Read", "subject": "..." },
                       "question": null },
            "attachedAt": 1760000000000 } ],
        "new": [], "changed": [] }
      ```

    - `rows` are the panel's, the strip's and the menu's, in their order
      (see "The rows"), a row a session (`v` 2, 22 October 2026). A row is
      its `session`, which names it for as long as it stands, so the app
      keeps a row's place by it; its `section` (`needsYou`, `working` or
      `yourTurn`; on its own work is in `working`, at its end), and
      `isAway`, a Needs you row of a session no window holds; its project's
      key, the strip's two `letters` (the project's capitals where it has
      two, else its first two), its `lines`, its `second` line, and `since`,
      the instant its time counts from: its oldest line's on Needs you, else
      its one line's. `second` is the project and the session, or, for an
      away row, "No window holds it. Carry it on in Claude.", which the app
      shows as it comes.
    - A row's `lines`, never empty, are what it says: on Needs you one per
      ask waiting, permission prompt and question, the oldest first; on any
      other row one, its state's. A line's `key` names it for as long as it
      stands (`ask:<session>:<ask>`, `stop:<session>:<window>:<since>`,
      `turn:<session>`). `is` is what the line is (`ask`, `permission`,
      `question`, `working`, `onItsWork` or `yourTurn`); then its `ask` or
      its window (`writer`), its words (`first`), and its `since`, which the
      app ticks: an ask's posting or reopening, a stop's showing, the turn's
      end or, working, its start. `first` is in parts: `lead`, which a
      working row shimmers; `mono`, the subject set in mono; `subject`, one
      set plain, as on its own work's "3 agents"; `more`, a question's `+2`;
      `until`, when the wake a row on its own work waits on is due, which
      the app words as its countdown after the lead. `subject` and `until`
      came in with on its own work (22 October 2026), null on every other
      line.
    - `head`: how many lines need Lee, away ones among them, and how many
      sessions the rows hold; none needing Lee is "All clear".
    - `projects`: those with a current session, in the SitRep window's
      order: a session where its row sits, those with none after, the
      latest updated first; a project where its first session sits. Each
      session is as `list --json` gives it but `onScreen`, which only `list
      --json` works out, asking tmux, with its `state` (`needsYou`,
      `working`, `onItsWork`, `yourTurn` or `away`), `since`, its row's
      time, else
      its latest line's, `doing`, and its open asks, as `board --json` lists
      them (core's `openAsks`): waiting, on Lee or on a window to deliver Lee's
      reply, or replied, Claude's to act on, each with its `reply`, which
      tells them apart. So a reply going into a session's inbox is a line,
      the session among `changed`, and its mark is another. `doing` (20
      October 2026) is what the session is doing, as the SitRep window's
      line under its name says it, there for every session (core's
      `doingOf`): a window's permission prompt or question, the one shown
      first; else the window its turn row comes from; each as that row's
      `is`, its `first` as `line`, and its `since`. With no window holding
      it, `away`, "No window holds it. Carry it on in Claude.", since its
      latest line. So a session needing Lee for its asks alone, which has
      no row of its windows', still says what they do. A field added: `v`
      did not move.
    - `windows`: every live window, the longest attached first, a finished
      session's among them, with its session's name and project, its
      `version`, and `needsReload` where it says none, or one behind the
      CLI's own `version`, dotted part by part. Not `seenAt`: every beat
      would be a line. Nor `loadedAt`, which only the mod's fence reads.
    - `new`: the keys of the lines needing Lee this watch has not shown, a
      new ask by its id or a window's new stop by when it showed. A row
      holding one **arrives**: a session new to the board, one coming to
      need Lee from working or your turn, or one in Needs you gaining a
      line. Since rows went by session a row keeps its key through all
      three, so an arrival is this, not a key new to the app, as it was
      while each ask and stop was a row of its own (22 October 2026). An
      arrival swells the notch, washes its row on the card and in the
      sidebar, the new line's time orange there, and on the strip moves its
      mark into Needs you at once, flashing, or flashes it where it is
      already in Needs you. A row **changes section** when its session
      comes into Needs you or leaves it: on the card, while it is out, it
      leaves its held place for its place in its new section (see "The
      rows"). The first line has none, so the app does not swell at its
      start, and what it shows counts as shown. A line gone and back, as a window's heartbeat late or an ask's folder away
      for a look, is not new again until it has been gone more than a day
      of the watch's own time (core's `FORGET_MS`), counted from its going;
      by then it is let go. So a finished session joined again brings back
      as new only the asks this watch has not shown.
    - `changed`: the sessions on the line whose `board --json` changed since
      the last, one new to the line among them, for the SitRep window to
      read again; none on the first.
    - It is stable as `list --json` is: every field is always there (a list
      empty, any other value null where there is none), and `v` moves only
      with a change a reader would trip on. A new value in a field that
      names one of a set (a row's `is`, a session's `state` and its
      `doing`'s `is`, an ask's `wants`, a window's state's `is`, and the
      like) is such a change: the app reads them strictly and refuses a
      line holding a value it does not know. New words in a line, as an away ask's `second`, are not.
      On its own work breaks this once, by plan (22 October 2026):
      `onItsWork` came into the rows', the sessions', the doings' and the
      windows' kinds without `v` moving, the app taking it in the same
      change, so an app built before it refuses a line holding it until it
      is built again. The rows grouped by session moved `v` to 2 (22
      October 2026): a row became a session holding its lines, keyed by the
      session, with its section; what was a row's (its key, `is`, `ask`,
      `writer`, `first` and its own `since`) became a line's; and `head`'s
      `needYou` counts lines. The app reads 2 alone, so one built before
      it says it can't read the board until it is built again.
    - **The loop.** It looks every second, as the mod's readers do: a file
      is read again only once its size or time moved, a folder listed again
      only once its time moved, as an entry made, removed or renamed there
      moves it, and a session folded again only once its files changed
      (`cli/held.ts`). A session off the board, finished or idle past the
      views, is read every 10 seconds: it changes rarely, and only a join or
      a post brings it back. A finished one a live window still holds is
      read at every look, so the window's state is heard at once. The shell
      lists, stats and reads at once, not through a promise's round trip to
      a thread, at about a tenth of the cost (measured on Bun 1.4). At rest
      it costs about half a percent of a core over a copy of Lee's board (50
      sessions, 13 of them current, 11 windows beating), 0.15% over a board
      of three. Polling, not the
      platform's file events: Bun's recursive `fs.watch` does hear every
      change on macOS (probed), but events can be coalesced or dropped, so a
      slower poll would still run beside them, and polling is what every
      reader does and what the tests run on. Events are the lever should the
      cost come to matter.
    - **Expiry.** A heartbeat going stale changes no file, so core says when
      the board next changes by time alone: the first live heartbeat going
      stale, or an idle session dropping out of the views. It looks again at
      that instant, folding every session afresh.
    - **Pauses.** Time the Mac slept ages no heartbeat (core's
      `pauses.ts`). A window live as the Mac slept has the rest of its 90
      seconds after the wake to beat again, and one stale before stays
      stale, so a Mac waking shows no stop gone for the moment before the
      windows beat. A sleep is told from a stall by two clocks: the wall
      clock, which runs on while the Mac sleeps, and the uptime, which does
      not. How far the wall clock moved beyond the uptime between two looks,
      past 5 seconds of it, is the sleep, a pause. A look held back, by App
      Nap, timers coalesced or a slow look, moves both alike and pauses
      nothing: first written (19 October 2026) as any gap between looks past
      5 seconds, all of it, which held back over and over kept a window
      gone for good live. The uptime is Bun's `performance.now()`, read from
      Bun 1.4.2's source on 20 October 2026: Rust's `Instant`, which on
      macOS is `CLOCK_UPTIME_RAW`, `mach_absolute_time`, stopped while the
      Mac sleeps. Should a later Bun's count the sleep, a sleep pauses
      nothing: on a wake the board may drop a stop and bring it back as the
      window beats, but never swell for it again, as `new` is what the
      watch has not shown. Clocks that disagree otherwise, the uptime going
      back or outrunning the wall clock, pause nothing either. The expiry
      follows: folded again at the instant it was to go stale, the window
      is found live still, and its next instant comes the sleep later. A
      pause is let go once the Mac has been awake 90 seconds since it, when
      every heartbeat seen before it is stale with it or without it, and
      however the clocks run no more than 10 are kept, the oldest let go
      first, so a look's cost stays a few sums.
    - **Torn files.** A file caught torn keeps the last text read of it whole
      until it changes again: a JSON file that does not parse, or a writer's
      lines holding only the start of what was last read whole, as a mod
      rewriting its whole file may leave them. So nothing drops off for a
      look and comes back as new. A file that will not read keeps it too,
      tried at each look; one never read whole is not there. What a folder's
      listing no longer shows is let go, and all under it, as every file of
      the old layout once the move has run.
    - **The move.** It moves the old layout as it starts, as every run does,
      and every 10 minutes after: it runs as long as the app does, and the
      move waits on windows reloading.
    - **Ending.** It ends, exit 0, once what reads its standard output has
      gone, or on SIGTERM (`cli/ending.ts`), which the app sends it as it
      quits, from the quit itself, before the app can be gone. A pipe
      closed is found only at the next write, or once the parent goes. An app that quits, however it
      quits, leaves its child to launchd, and while the board is still no
      write finds the pipe closed, so it looks each second whether its
      parent has gone: the one it found as it loaded, launchd's pid 1
      counting as gone, so an app dying as it starts the watch is caught at
      once. A write that fails ends it too. It also ends, exit 0 and
      printing nothing more, once the plugin's manifest says a version other
      than the one it started on: each look stats the manifest, so after a
      plugin update the app, hearing an exit it did not ask for, starts the
      new one at once, with the new version and `needsReload` to match. The
      version it runs is the first it reads whole, so a manifest caught torn
      as it starts is no move. A folder it cannot look in ends it with a
      `sitrep:` line on stderr and exit 1, for the app to start it again.
      However it ends, a failure among them, it stops listening for its end
      and lets go of the wait under way, either of which would otherwise
      hold the process open.
    - Tried live (19 October 2026) over a state folder of its own: an ask
      and a note posted with the CLI, and heartbeats written by hand with a
      working tool, a permission prompt and a question, each became a line
      at the next look, the ask and the stops new on it, the working row's
      path shown from the project's directory; each heartbeat went stale to
      the millisecond, a line with no file changed; SIGTERM, the parent
      quitting and the pipe closing each ended it, exit 0. Again later that
      day, each way out: a state folder it could not read ended it at once,
      exit 1, where before it ran on; one not there yet gave the empty
      board; the manifest saying another version ended it, exit 0, no line
      after; and one left to launchd as it started ended at once. On 20
      October 2026, timed from what ended it, three runs each, the wait
      under way let go: SIGTERM in 10 to 20 milliseconds, where before it
      took up to a second; the parent quitting, the manifest moving and a
      write finding the pipe closed in about 0.7 seconds each, the time to
      the next look or the next look for the parent, gone at once after.
    - Claude windows don't watch: each mod writes its own files there and
      polls for its pane, as under Storage.
    - `sitrep serve`, later, builds on the same loop.
  - Its logic is `cli/`, plain TypeScript beside core and tested in the test
    kit on a file system in memory; `cli/shell` binds it to Bun, and
    `bin/sitrep` runs that.

## Look

- Palette (Tokyo Night): ask `#e0af68`, new-ask pulse `#ff9e64`, log `#7aa2f7`,
  parked `#bb9af7`, ok `#9ece6a`, now `#73daca`, soft `#a9b1d6`,
  grey `#7a82ab`, faint `#565f89`, rules `#3b4261`, tab `#292e42`.
- **White:** anything clickable, and the main content.
- **Soft:** lines describing the item above them (a summary, what a session is
  doing, a reply, a note's detail), and the line a section with nothing in it
  shows (`Nothing yet.`).
- **Grey:** ages, counts, heading notes. RESOLVED's toggle is a quieter press, drawn dim (a
  Button's own `dimColor`: Claude Code 2.1.294 refuses a Button with a
  label and a coloured child, and blanks the pane). **Faint:** closed things (an away
  session, an ask Lee's send just closed), but not RESOLVED's asks: each is a
  row to open, its `✓` green and its title white; and every tree's `│ ├ └`.
  Section headings' rules and the tabs' rule are the rule colour.
- **Colour:** glyphs, headings and amber waiting counts only; in the ask's
  amber, the `needs:` line of a words ask, since it is a request of Lee's,
  not a description; and a tree line's label (`Added:`,
  `see`), in its item's colour.
- Glyphs: `◆` ask, `◇` parked, `•` under way, `◦` next, `└ ├` trees, `⌂` home.
  No glyph that reads as "expand" unless it expands.
- **One row for every list.** A line in Notes, a parked item, an ask in
  Asks and a resolved ask are drawn alike: the mark, the title (white, and the
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
  entries of a list (notes, asks, resolved, parked), nor between the tabs and
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
How the app updates changed on 16 October 2026 (Sparkle, below).

- **On a Mac, sitrep is the app**, from a Homebrew cask in `homebrew-tools`,
  and from nowhere else (no download of its own), so every install updates
  the same way. That way was `brew upgrade` until 16 October 2026; now the
  app updates itself.
- **The app installs the Claude plugin**, at each start that finds nothing
  of sitrep in either of Claude's lists. It copies the plugin it carries to
  `~/Library/Application Support/sitrep/`, outside its own bundle, since
  anything written into a signed app breaks its signature; then registers
  that folder as the `sitrep` marketplace and installs `sitrep@sitrep`,
  through `claude plugin`. So removing SitRep's marketplace, or
  uninstalling `sitrep@sitrep` from it, is undone at the next launch, while
  disabling the plugin sticks. It finds `claude` where its installers put
  it, or by asking Lee's login shell: an app sees almost no PATH. The
  install waits on nothing macOS grants: notifications are off until Lee
  turns them on in Settings, the leave to control Ghostty is asked at the
  first jump or from General, and starting at login is General's (all
  moved there since 14 October 2026, which had the install wait on them).
  Built 20 October 2026 (stage 3, step 9).
- **Anything of sitrep SitRep did not install is left exactly as it is.**
  SitRep reads `claude plugin marketplace list --json` and `claude plugin
  list --json` as it starts, and decides from both. It adds and installs
  only when neither shows anything of sitrep: no `sitrep` marketplace, and
  no installed plugin named `sitrep` from any marketplace. It refreshes
  only its own copy, the `sitrep` marketplace being a folder marketplace of
  that very folder. A `sitrep` marketplace anywhere else (Lee's clone, the
  GitHub one), or any installed `sitrep` not from its own copy
  (`sitrep@kit`, since sitrep began in kit's marketplace), is foreign: it
  is never removed, replaced or re-pointed, no second sitrep is installed
  beside it, which would leave each window running two mods, and SitRep
  runs that plugin's CLI from where Claude loads it:
  - from a folder marketplace, its folder and the plugin's place in it, as
    the folder's own `marketplace.json` says (`./` for sitrep's), never
    Claude's cached copy, which is as stale as the install (Claude drops
    `readFromFolder` once the folder or its `marketplace.json` is gone);
  - with that marketplace no longer listed, the folder Claude says it
    reads the plugin from;
  - from GitHub, or any source Claude fetches, Claude's copy
    (`installPath`), which is what it runs;
  - with none of these to read, the trouble, in plain words: "SitRep can't
    find the sitrep plugin. Claude Code has it from ~/Code/sitrep, where
    SitRep can't read it."

  `claude plugin marketplace add` over an existing `sitrep` registration
  re-points it without complaint, which is why an empty marketplace list
  alone is not enough to add one: with Claude's record of its marketplaces
  gone, the list says `[]` while the plugin still loads from the clone. On
  this Mac, until the first release, the app changes nothing and runs the
  clone's CLI.
- **Trouble does not leave SitRep without a board.** SitRep remembers the
  plugin folder of the last look that went well. A look that meets trouble
  (no `claude`, a list that fails, times out or does not read, a step that
  fails) runs that folder's CLI while the folder is there, else its own
  copy's, and says the trouble in the card and the menu. It looks again a
  second later, the wait doubling to half a minute, as `watch`'s back-off
  does, until a look goes well; `watch` starts again only when the folder
  it settles on is another.
- **The app updates itself, with Sparkle** (16 October 2026). Its feed is
  published with each GitHub release. The cask stays the way to install,
  marked `auto_updates true`, so brew leaves updates to the app: one
  updater. Sparkle was ruled out on 14 October, since `brew upgrade` already
  updates a cask. That was reversed because `brew upgrade` reaches only
  those who run it, where an app that updates itself reaches everyone, and
  knows when the plugin changed.
- **After an update** the app refreshes its copy of the plugin, so one
  update moves both, and their versions never part. Windows on the old mod
  show as needing `/reload-plugins` (see "Versions side by side"). First
  planned for `brew upgrade`, the app finding its newer self on disk and
  relaunching. Built as every start's look: when the bundle carries
  another build than its copy (its version, or the digest of its files
  `app/bundle` stamps it with, so a rebuild at the same version counts),
  the app replaces the copy whole, copied beside it under a name of that
  start's own, then swapped in. While Claude's record of the plugin is at
  another version than the copy, it runs `claude plugin marketplace update
  sitrep` and `claude plugin update sitrep@sitrep`, so a refresh cut short
  after its copy is finished at the next start. A plugin from a folder
  marketplace loads in place, so the copy is what each window takes up at
  its next `/reload-plugins`; the two updates keep Claude's record of it
  current. With all the same, it does nothing.
- **Built at the first public release**, which waits for a Developer ID
  (stage 4); Lee will get one before going public. It must be testable
  locally first: a feed served from this Mac, and two builds signed with
  the "SitRep Local" certificate. Until then, this Mac builds the app from
  the clone (below).
- **Everyone else** (Linux, Windows, no menu bar wanted) installs the plugin
  alone from the GitHub marketplace: `claude plugin marketplace add
  leeovery/sitrep`, then `claude plugin install sitrep@sitrep`.
- **Ruled out:** the plugin first, its mod building the app whenever the
  plugin's version moved on (a Claude mod compiling a Mac app, and Xcode's
  tools wanted on every Mac); the Mac App Store, whose sandbox forbids
  running another program (even tmux's queries), controlling Ghostty, and
  writing Claude's settings. Sparkle was ruled out here too, and taken back
  on 16 October 2026 (above).

**Until the first release** (stage 4): this Mac reads the plugin from the
clone, `~/Code/sitrep`, as a folder marketplace, so an edit plus
`/reload-plugins` is a change, and the clone's checkout is the code every
window runs: work happens in a worktree. The app is built locally, by
`app/build` (stage 3). kit's `[manual]` step installs the plugin from the
GitHub marketplace on any other Mac until the cask exists.

**Versions side by side.** Neither the app nor a mod can reload a Claude
window (the engine's types offer no way): each window takes a new plugin up
at its next `/reload-plugins` or restart, and runs the code it loaded until
then. So two releases often share the board's folder, each window writing
as its own does. Stage 1 was the first such: windows not yet reloaded wrote
no `where`, and read as off screen.

How, decided with Lee on 16 October 2026: lines are upgraded as they are
read.
- Each line keeps its `v`. Core holds one upgrader per past version, and
  every reader upgrades an old line to today's shape as it reads it, so the
  rest of the code knows only the current shape.
- Writers write the current version.
- A window not yet reloaded skips lines newer than it knows. Its
  heartbeat's version lets the app show which windows to reload.
- The build's renames on disk (`works/`, `work.json`) are the first use:
  readers read the old names and the new, writers write only the new, and
  the old files move once no window runs an old version. A window not yet
  reloaded reads only the old names, so it sees nothing written under the
  new ones until it reloads, as with newer lines. Built 19 October 2026,
  `works/` to `sessions/` and `work.json` to `session.json` (see "Storage").
- A window on a release from before 20 October 2026 voids no second answer:
  two answers to one ask that land at once (two runs of `sitrep answer`, or
  the CLI and a pane's letter) both go in from it, until it reloads, and the
  board records both delivered, as Claude had them. One from before today's
  layout (no `version` in its heartbeat) reads only `works/`, so it would
  never see the CLI's answers, written under `sessions/`. So `sitrep answer`
  refuses while the window delivering the session runs a sitrep behind the
  CLI's, by `needsReload` (see "One engine, two front ends"), saying to
  `/reload-plugins` it; the version moves at each release, this one among
  them, 0.1.0 to 0.2.0. Known limits, all of a window not yet reloaded: one
  that only takes a session up later, after the answer was written, is not
  refused, so an old one attaching to a session still under `works/` never
  sees the answer waiting under `sessions/`; a session's second answer still
  reaches Claude from a window before this release that delivers it; and one
  before this release, as a sender, letters a second answer into a session
  whose window runs this release, which rightly voids it, `answered`, while
  the old window's own Ready to send, reading by the old rules, keeps
  showing it on its way until that window reloads.
- The CLI's JSON stays as it is, its `v` and its stable fields (see "One
  engine, two front ends"): the app carries its own CLI, so the two never
  drift. Pinned versions, a client saying the version it speaks and being
  answered in it, belong to `sitrep serve` when it is built.

This replaces the rule written on 14 October 2026: a new field is optional,
and nothing is renamed or given a new meaning. That rule froze the folder's
names for good, where the build renames them (see "Words"), and Lee wants
anything built so far free to change for something better.

The CLI is `bin/sitrep`, an executable Bun script, the only file in `bin/`.
Claude Code puts an enabled plugin's `bin/` on its Bash tool's PATH, and the
app calls the copy of the plugin it installed, so nothing puts the CLI on
Lee's shell's PATH: no project's folder goes on kit's `[paths]` (Lee, 14
October 2026). The copy the app carries has it compiled
(`bun build --compile`), so a Mac with the app needs no Bun; the plugin alone
from GitHub runs it on Bun. Bun reads a file by its extension, so what it
compiles is `cli/shell/run.ts`, which `bin/sitrep` imports; compiled, the
CLI finds its manifest from its binary's folder, since its own source's
folder is then one inside the binary.

The engine's types sit in `.claude-plugin/types/`, kept out of git by their
own `.gitignore`; `.worktreeinclude` copies them into a worktree. The mod's
type-check leaves `cli/shell` out; it is checked on its own
(`tsc -p cli/shell`), against what it calls of Bun, declared there, since the
plugin keeps no packages.

## The menu bar

Decided with Lee on 13 October 2026, on the board as `sr-aw3bgs`, its surface
redrawn as the notch and its panel on 14 and 15 October 2026. One place on the
Mac, on every Space, for what waits on Lee across every project, and a click
that takes Lee to the window a session is in.

- **A native Mac app**, with no Dock icon. Its surface is **the notch**: a
  black shape at the edge of the screen that opens into a panel of Lee's
  sessions, or **the strip** in its place (below). It replaces the menu
  bar's list, first planned as projects opening to their sessions.
- **The menu bar item stays**, as a native menu: the panel's sessions with a
  click to each, what shows at the screen's edge, the SitRep window,
  Settings and quitting (17 October 2026; see "The menu bar item").
- **macOS notifications for a new ask**, silent, since the window's own
  chime already plays and Lee hears it once. They are off by default once
  the notch exists, since the notch swells and lights for a new ask, and a
  setting turns them on.
- **Answering stays in Claude Code:** the panel shows, and takes Lee there.
  Only the SitRep window answers, and only an ask that wants a yes or a
  choice (17 October 2026).
- **Clicking** a session, an ask or a macOS notification takes Lee to the
  Ghostty window showing that session, on whatever Space it is. A session no
  window shows offers no jump: the app never opens a window (until stage 6).
- **The app holds no sitrep logic.** It runs one `sitrep watch` as its
  child, which tells it the board as it changes, and each jump is a one-off
  call to the CLI (see "One engine, two front ends"). First written (13
  October 2026) as the app watching the state folder and asking the CLI
  for the board; changed on 16 October 2026 so that presence expiry and
  what is new, which decides the notch's swell, are worked out in core, not
  in the app. Once a remote surface exists, the app also hosts serving.
- **tmux and Ghostty stay at the edge.** Only the jump knows them; core, the
  pane and the app never do. Portal is not involved.

### The notch and its panel

Lee's idea, 14 October 2026: a floating island at the side of the screen,
opening like a liquid, as iOS 27's Siri does. It was designed with Lee over
14 and 15 October:
- the form in Paper (the file "SitRep · side panel", rounds 1 and 2);
- the feel in an animated prototype in the browser, tuned over eleven
  rounds;
- published at https://claude.ai/artifact/NVh9MJwABf5Kmqtzvy5Uoh, whose
  Meniscus tab is the design, and whose Card tab is the alternative (see
  "The alternative: Card").

**The notch.** At rest, a black notch flared into the display's black bezel,
7 points deep and 76 long, its ends S-curves. While something needs Lee,
it is 15 × 124, with the light inside. It opens into a black panel:
- 372 deep;
- front corners of radius 24, and flares of 18 into the bezel;
- kept 40 from the top and bottom of the screen's visible frame.

In Glass (Settings' Material; Black by default), Meniscus and the card are
thick Liquid Glass from rest, the light drawn over the glass and the rows in
the system's label colours. Clear glass that narrow hardly reads (Lee, 20
October 2026: "the hovering box maybe is a little too subtle"), so the
notch is marked as the black is by its dark: the glass tinted black at 0.5,
with a white rim 1 point wide at 0.22 inside its edge. It is in full at
the notch at rest, and near it while something needs Lee or the notch
reaches for the pointer (the tint 0.44 to 0.49), as it eases off with how
far out the outline is past the notch at rest, to the plain glass of the
panel open, which Lee liked as it was. Under reduced motion each outline
of the cross-fade keeps its own.

It sits on the left edge by default, at Lee's asking, 0.42 of the way down
the screen, a little above the middle, as the prototypes have it and where
the strip centres at Grows. On this Mac the left edge of the main display is
a hard edge: the built-in display sits to its right. A drag moves it along
the edge, and past the middle to the other
edge; never to the bottom. The form is Paper's round 1 "Bezel". The light's
place, a bar in the notch, is round 2's "Strip".

The drag, as built (20 October 2026), is the prototype's: a press on the
black off a row, moved more than 4 points, closes the panel and lifts the
notch over 140ms, 2 further out with a shadow, and it follows the pointer
along the edge on a 50ms spring. Let go, it sets down over 220ms; let go
past the screen's middle, it drains into this edge in 150ms, swaps to the
other at 160 and grows out of it over 300, its ghost fading over 420; no
press takes it again until it is home there.
Where it is let go is saved in what Lee sets, as
its edge and how far down the screen it sits (0.42 until then), so the
strip, centring where the notch sits, takes it too. A chosen display is
named by its UUID, which outlives a restart and a replug; one not connected
gives way to the main display.

**The light: Live**, in Claude Code's orange, #E9643D. It is a crisp bar
2.5 × 36 in the notch:
- a tight halo, clipped to the notch;
- two warmer spots swaying slowly along it, on about 8 and 11 seconds;
- a breath on 2.4 seconds, carried in colour with opacity 0.86–1, so it
  stays orange at the trough.

A new ask brightens it briefly. It shows only whether anything needs Lee,
never how many asks, and dims out while the panel is out. Every needs-you
mark is that orange: the light, the rows' dots, a new ask's wash.

Six steps were tried, from a bloom to a glow inside the material. A bloom
looked blurred from across the room. Lee wanted "the crisp edges on the
black background", with a little happening inside: subtle, and narrower.

**The rows** (16 October 2026). The panel shows every session that needs
Lee, away ones included, and every session a window holds, working, on its
own work or your turn (see "A session's state"). An away session with
nothing waiting stays off it, for the SitRep window to show. In this order:
1. needs you, oldest first, with away ones last, oldest first among them;
2. working, longest running first;
3. on its own work: those waiting on a wake first, the soonest due first,
   then the rest, the longest waiting first;
4. your turn, newest first.

Working and on its own work came above your turn with on its own work (22
October 2026): board A, the base of the card's sections, puts Working above
Your turn, and on its own work at Working's end. Your turn was second until
then.

**The sections** (22 October 2026, Paper's board D, "One list, two sizes",
from boards A, B and C). Lee, of the three boards: "A is kind of the base,
but using B's flattened, one-line turn, and then using C's collapsing turns
that move outside of the period." So the card lists its rows in three
sections, each under an eyebrow: Needs you, Working (on its own work at its
end) and Your turn, in that order. A section with no rows is left out, its
eyebrow with it.
- **The head goes.** "4 need you · 6 sessions" told what the eyebrows now
  carry. It stays only where there is nothing to list, as the empty card's
  "All clear", "Looking for sessions…" or why SitRep can't read the board,
  and while the board is stale, to say when it was last known current, "as
  of 12:04", over the sections. With no head, the first eyebrow sits 4
  under the card's top padding of 12, so the first row stands at 44, where
  it stood under the head.
- **An eyebrow** is 28 tall: the section's name 10 in, 11 semibold in white
  at 55%; its count 6 after it, 11 semibold in tabular figures, in orange
  for Needs you and white at 30% for the others; and at its right a
  chevron, 10 by 6 and stroked 1.5 in white at 25% with round caps, in a box
  15 by 24 that stands 7.5 in, so the chevron ends where a row's time does.
  Needs you counts its waiting lines, the asks and stops (Kit's one and
  Harness's three are 4); Working and Your turn count their rows, Your
  turn's folded ones among them. The eyebrow after the hairline follows it
  straight on, Working's, or Your turn's where there is no Working; Your
  turn's under Working sits 10 under it, Working folded or not.
- **The hairline** sits after Needs you only, as it did, whenever another
  section follows, Needs you folded or not.
- **Folding.** A click on an eyebrow folds its section to the eyebrow
  alone, its chevron pointing right (6 by 10); a click again unfolds it.
  Either changes at once, with no motion, as the Settings card does (Lee,
  22 October 2026, of the motion there: "a bit jarring"). The folds are kept
  across opens and launches, a value of their own in the app's defaults
  under "card". An arrival unfolds Needs you, at once: a row holding a line
  new to the board, as swells the notch, whether the session is new, comes
  to need Lee or gains a line. The unfold is kept, as a click's is: Needs
  you stays open until Lee folds it again. At once is for what the fold
  changes only, the section's rows coming or going; every other row keeps
  its own motion, one folding away finishing and one arriving, the new
  ask's own row among them, folding in.
- **Your turn's rows are one line**, 30 tall, with no gap between them (see
  "How each row reads").
- **"N earlier."** Your-turn sessions whose turn ended longer ago than the
  fold period (Settings' "Your turn folds after", an hour unless Lee sets
  four hours, today or never) fold into one line at Your turn's end, shown
  only while at least one has: 34 tall, 2 under the row above, its ring at
  white 35%, "8 earlier" in 13 regular in the soft grey, then 7 after it
  their projects, 12 in the faint grey, comma-separated, each once in the
  rows' order, cut short with an ellipsis, and a right chevron. A click
  opens it in place: the earlier sessions show under it as ordinary
  your-turn rows, the line staying as their eyebrow with its chevron
  pointing down; a click again folds them, each at once. Whether it is open
  is never kept: it is folded each time the card comes out, since what it
  holds is stale, and as the line goes, its last row starting a turn, so it
  never comes back already open. The period is measured from each row's time, its turn's
  end, against the wall clock: "today" folds what ended before local
  midnight, and "never" shows no "N earlier". As time passes a row folds in
  where it passes the period, at once, the rest keeping their motion, and
  under the line where it is open, the card drawn again at that moment
  as it is drawn again as a row's time changes, and nothing polls; the
  period changing refolds the card at once.

**A row is a session**, on every surface (22 October 2026, Paper's board D,
"One list, two sizes"). Lee, of a first draw that set a session's asks
under a line of its own: "It shouldn't look different if a session has
multiple asks." So a row has lines, and one shape serves every section: a
Needs you row has a line for each ask waiting and each permission prompt or
question its windows are stopped on, the oldest first; any other row has
one, its state's. One ask is that shape with one line, as before. It is one
row: one lift, one press, one pick, and a click anywhere on it jumps to the
session. Needs you sorts by each row's oldest line, and its count, on its
eyebrow, is of lines: the asks and stops waiting, not the sessions.

Core decides the rows (`core/rows.ts`, 19 October 2026), and `sitrep
watch` prints them in this order, for the app to draw as they come: a row
per session that needs Lee, its lines its asks waiting and its live
windows' stops, showing only those; else a row per session a window holds,
of one line: working where any of its windows is, the one whose turn began
last, else on its own work where any is, else your turn, each the one whose
turn ended last. Each line says what it is, its words as below, and the
instant its time counts from: an ask's posting, or its reopening; a stop's
showing; the turn's end on your turn and on its own work; the turn's start
while working. A row's time is its oldest line's. While a tool runs, a working row
leads with its verb (Read Reading; Edit, MultiEdit and NotebookEdit Editing;
Write Writing; Bash Running; Grep and WebSearch Searching; Glob Finding;
WebFetch Fetching; Skill Using; LSP Checking), its subject after it, a
file's path from the project's directory where it lies under it; Agent,
Task and Monitor lead with their description, and any other tool with its
name. With no tool, working and your turn read the board's "now", else the
summary, else the name.

A row on its own work says what it waits on, in the working row's form, the
first of these that it has (22 October 2026):
1. agents: "Waiting on" and "3 agents", or the one agent's description;
2. a workflow: "Running" and its name, else its description;
3. a shell: "Running" and its command, in mono, as a working row sets one;
4. a monitor: "Watching" and its description;
5. anything else: "Waiting on" and its description;
6. only a wake: "Wakes" and "in 12m".

The countdown is the app's: core writes nothing that hangs on the clock, so
the wake's line carries when it is due (`until`), and each surface words it
after "Wakes" as its clock ticks: under an hour, the whole minutes left,
rounded up ("in 12m" from twelve minutes down to eleven); past that, hours
and then days, as an age is worded ("in 1h" up to two hours); then "now"
once due, as a wake past its minute is. Its figures are tabular, and a tab
on the strip leaves room for the widest it will read, so it never widens
past its tab: "in 1h" becomes "in 59m". The row's time still counts from
the turn's end, as every row's does, so the countdown never shows twice.

Rows keep their places while the panel is open: a changed row moves only
once it closes. Each section, Needs you, Working or Your turn, is held on
its own and the sections follow in their order, so each stays together
under its eyebrow however core reorders it meanwhile (22 October 2026, rows
by session, then the card's sections). A row is kept by its session, so one
gaining or losing a line in Needs you, as a second ask comes, is the same
row, changed where it stands at its new height, at once, and the rows under
it move with it, as is one going from working to on its own work, both
Working. A row changing section, its session coming to need Lee, its asks
answered, or its turn ending, leaves its held place and takes its place in
its new section: it folds away where it was and unfolds in the other, as
two rows, as when each ask was a row of its own, washed where it arrives
and never as it folds away. "N earlier" and the rows folded under it are
Your turn's.
Meanwhile a row gone folds away where it was, and a new one unfolds,
washed if it needs Lee (20 October 2026). A row new to a section, new to
the board or come from another, goes under the row core has above it in
that section, or at the section's top where core has none there. A click
on an away row does nothing; it is there, but there
is no window to jump to. What a click on it opens is decided later: for
Lee, a new Ghostty window attached to the session's tmux session, where
there is one (Lee, 16 October 2026, in place of "until the SitRep window
exists; then it opens the session there"). This replaces the first list,
needs you, your turn, working, quiet and not on screen: quiet was your
turn, and not on screen is a fact about where a window is, for the jump.

**How each row reads**, drawn in Paper's "Panel rows" (surfaces round 1,
16 October 2026; Lee: "everything looks great"). A mark, two lines, and a
time on the right; one line each, cut short with an ellipsis:
- **an ask**: an orange dot; its title, then its project and session; how
  long it has waited. Its window may still be working: needs you wins, so
  nothing else shows;
- **a permission prompt**: "Allow Bash", then the command in SF Mono;
- **a question**: the question itself, and "+2" when there are several;
- **several waiting** (board D, 22 October 2026): each line as its own row
  of one would read, each with its dot in the mark lane and its age in the
  time lane, 22 under the last (its 18 and 4 between), the project and
  session once under the last, as under a row's one. So a row of one line
  is 55 as built, and each line more makes it 22 taller; the card's height
  and its scrolling take it. Every waiting line's words are medium, a row
  of one's too, not semibold as they were, as the card's other titles are;
- **away, with an ask**: the dot stays orange and the words dim. Under the
  pointer it doesn't lift, and its second line says "No window holds it.
  Carry it on in Claude.";
- **your turn**, on one line (board B's, in board D, 22 October 2026; Lee:
  "B's flattened, one-line turn"): 30 tall, inset 10, an open white ring 9
  across with a stroke of 1.5 in the 12 mark lane, so its shape differs
  from the dot, not only its colour; then what Claude left Lee, the board's
  "now", 13 regular in white, cut short with an ellipsis; its session's
  project in a lane at the right of it, 12 in the faint grey, on its
  baseline, its own width and never cut, 12 after the words at the least;
  how long it has waited, in the 36 time lane. It lifts, presses, jumps and
  washes as any row does, its lift radius 10. The two-line your-turn row is
  gone from the card;
- **working**: a turning arc, and a slow grey-to-white shimmer along the
  line, as Claude Code's own; while a tool runs, the line is the tool (the
  verb shimmers, a path stays still in mono), else the board's "now"; how
  long the turn has run. It is greyer than the rest: it needs nothing.
- **on its own work** (Paper's board D, "One list, two sizes", 22 October
  2026): the working row's layout, all of it still. Its mark is a ring of
  round-capped dashes that never turns, #8E8E95, centred in the working
  mark's 11-wide lane (r 4.5, its stroke 1.5, dashes 1.6 with gaps of
  2.12); its verb 14 medium in #B4B4BA, what it waits on 14 regular in
  #8E8E95 after it, or a command in mono as working sets one; how long
  since its turn ended. Nothing of it runs: no shimmer, no turning, and only
  a wake's countdown is drawn again, as it reads differently.

The shimmer stays neutral. Orange is for needs you only: the dot, the wash
and a new row's "now". Lee had suggested working titles shimmer white or
grey to orange, then left it to Claude; it can change after a test. One hairline
sits after Needs you; the sections under it are told apart by their
eyebrows, and their rows by their marks. A row, or "N earlier", under the
pointer lifts to #141416, with no ⏎ hint, since the panel never takes the
keyboard; an eyebrow never lifts. With nothing waiting, the hairline goes,
and the notch rests with no light; with nothing at all, the head reads "All
clear".

Each row drawn whole says what it is, with its project and session beneath;
a your-turn row, its project at its right. A click jumps: the
row presses in and spins for up to 450ms in its first line's time lane, the
other lines' times hidden meanwhile, the panel drains, and a caption
says where it jumped. A new ask
makes the notch over-swell twice, to 25 deep, about 450ms apart, as each
comes back through its 15. The light flashes with each, and its row, new or
gaining the line, gets an orange wash for 2 seconds. Lee set the swell on the display
(15 October 2026). The prototype swells once, to 19, which Lee found a
little too quiet, and Lee thought it might look nice twice.

**The feel: Meniscus.** The edge is the surface of a liquid.
- **Approach.** The field reaches 49 from the edge (140 × Pull) and 220
  along it either side of the notch's centre. Within it, the notch draws a
  tongue toward the cursor:
  - pulled as 1/(distance + 10);
  - its tip follows the cursor along the edge, up to 40 from home;
  - its base never slides.

  It snaps open when the gap closes to Reach, once the tongue has caught
  up and the cursor isn't sliding past along the edge. Touching the notch
  opens it after 150ms, or at once when fast. The panel pours out from the
  point of contact, and the rows land 25ms apart.
- **Open.** The edge bows toward a cursor near it from inside, anywhere on
  the outline.
- **Leave.** The edge holds the cursor: a tongue with its tip just past the
  pointer, narrowing as it stretches. It holds round the corners and along
  the top and bottom too. It breaks after hanging 60ms at Hold, or when the
  pointer gets 6 ahead of it. A fast leave flings the edge out after the
  cursor, up to about 14, before it lets go.
- **Release.**
  - The bulge springs back to its line, then through it into a dent: about
    8 deep when slow and 3.6 on a flick, its inward travel fitted to 85ms
    and 50ms.
  - It comes out to a slight convex and rings on.
  - The panel starts to collapse Push of the way, in time, from the line to
    the deepest dent, kicked by the bulge's speed.
  - The collapse eases in, so the ring shows on the panel, and the ring
    carries on into the notch.
- **Home.**
  - The notch's two ends are springs of their own: the end nearer the exit
    leads, and the far end follows 36ms later.
  - The notch arrives past home, away from the exit (up to 12), swings back
    and settles.
  - The landing dips about 3 under the notch's depth, lengthens about 6.7,
    swings and settles (Land).
- **Leaving back over the notch** has a grace of 300ms, down to 60ms when
  fast. A click elsewhere closes it at once. The notch takes no click: it
  opens on hover alone.
- **It never takes the keyboard.** A click on it leaves Lee's typing where
  it was, in Ghostty, so there is no Esc and no ⏎: moving away closes it.
  There is no pin either. Lee, 15 October 2026, on the display:
  - hovering opens the panel before the notch can be clicked, so a pin on
    the notch was out of reach;
  - a click on the panel took Lee's typing from Ghostty;
  - the panel "protrudes into the screen too much to be pinned".
- **Reduced motion:** no pull toward the cursor; the shape cross-fades.

**Lee's settings**, from round 11 ("I think this is working"), with the
swell from the app:
`{"bounce":0.90,"pull":0.35,"hold":35,"reach":10,"push":20,"land":1.11,"close":1.81,"swell":25,"swells":2,"edge":"left","light":"live"}`.

What each sets; the first seven are the prototype's dials, the last two the spike's:

| Dial | What it sets |
|---|---|
| Bounce | Scales every spring's damping: at 0 ×1.4, at 0.5 as listed, at 1 ×0.7, capped at 1 |
| Pull | The field, the tongue's reach and the cling |
| Hold | How far the edge stretches before it breaks |
| Reach | The gap at which the notch snaps open |
| Push | When the collapse starts |
| Land | The landing's dip |
| Close | The collapse's speed |
| Swell | How deep a new ask swells the notch, from 15 to 30 |
| Swells | How many times, from 1 to 3 |

**The app ships these values fixed**, with no dials and no Settings for how
it moves (Lee, 17 October 2026: "we have locked them in now and ship by my
taste"). The dials are for tuning, in the prototype and the spike. A change
after a release is a change to the values in the code, tuned in the
prototype first. This replaces the plan of 15 October, the app carrying the
dials and Copy settings so Lee could tune it on the display. The card's
values ship fixed the same way.

The springs, after Bounce, as SwiftUI's
`.spring(response:dampingFraction:)`:

| Spring | Value |
|---|---|
| attract | 0.20·0.57 |
| relax | 0.45·0.42 |
| home | 0.60·0.61 |
| pour h | 0.40·0.57 |
| pour w | 0.34·0.55 |
| cling | 0.24·0.55 |
| cling y | 0.16·0.65 |
| tongue | 0.08·0.61 |
| return | 0.30·0.29 |
| ring | 0.17·0.29 |
| release | 0.30·0.38 |
| drain | 0.60·0.95 (its speed ×1.81 from Close) |
| land | 0.19·0.24 |
| rebound | 0.20·0.42 |
| ask | 0.42·0.38 |

From Pull: a field of 49, a tongue of 7.7, a cling of 2.1. The feel changes
only from Lee's notes.

**The alternative: Card** (17 October 2026). Lee wanted a second notch, an
alternative to Meniscus and never its replacement. It ships beside it,
Settings' Style choosing between them, Meniscus the default (Lee, 18 October
2026, having felt both in the spike on the display: "They both look good. I
would use Meniscus, but I think we should ship both"). It is drawn in
Paper's "The card notch", and its feel is the prototype's Card tab, tuned in
two rounds.
- **The shape.** The mound's sizes and light: 7 × 76 at rest, 15 × 124
  while something needs Lee, 372 deep open. It meets the edge square, with
  no flares or S-curves, and rounds only its two outer corners: 6 at rest,
  10 at 15 deep, growing to the panel's 24 by 60 deep.
- **Approach.** No tongue. Within the same field, 49 from the edge and 220
  along it, the notch eases straight out toward the pointer by up to Nudge,
  the full amount within 90 of its centre and at the moment of touch.
  Touching it opens it after 150ms, or at once when fast.
- **Open.** It slides straight out at the notch's length, like a card from
  an ATM. Lag into the slide, it starts growing along the edge, up and down
  alike from its centre, to the panel's length. Lee: "it slides out and
  then just after a moment starts to increase in height and width as well".
  The rows land 25ms apart once the depth is within 12 of its stop and the
  length within 4.
- **Its length** is its rows', up to the screen's visible frame less 40 at
  each end. Past that the rows scroll inside it. As rows come and go while
  it is open, the length follows them.
- **Close.** No cling. After the grace, 300ms or 60 when fast, the rows
  fade over 60ms. The length starts back 50ms in, and the depth Lag after
  it. Both are critically damped, so the card eases into the slot without
  a bounce. The light comes back over the depth's last 30.
- **A new ask** pushes the closed notch out to Swell, Swells times, 450ms
  apart; it never grows longer. The light flashes with each push.
- **Reduced motion:** no nudge; the shape cross-fades.

The first round offered two lengths. In one, the card rested as long as the
panel, growing and shrinking with its rows, and slid straight out. In the
other, it rested at the notch's length, slid out, and only then grew along
the edge. Lee turned down the growing notch and chose the notch's length,
with the two moves overlapping.

**Lee's settings** for it, from round 2:
`{"bounce":0.70,"nudge":8,"slide":0.93,"lag":30,"close":0.88,"swell":25,"swells":2,"edge":"left","light":"live"}`.
At these it reaches 372 at about 110ms, 12 past, and is still by about
240ms, the rows starting at 125ms. Closing, it is seated by about 350ms.

| Dial | What it sets |
|---|---|
| Bounce | As Meniscus's |
| Nudge | How far the notch eases out toward the pointer, up to 10 |
| Slide | The opening springs' speed, and Lag with them |
| Lag | How far into the slide the length starts, and into the shrink the depth starts home |
| Close | The closing springs' speed, and the 50ms and Lag with them |
| Swell | How far a new ask pushes the notch, from 15 to 30 |
| Swells | How many times, from 1 to 3 |

Its springs, after Bounce, Slide and Close:

| Spring | Value |
|---|---|
| slide (the depth out) | 0.19·0.70 |
| length (along the edge) | 0.17·0.75 |
| follow (the length after its rows, and back to rest) | 0.24·0.79 |
| shrink (the length back) | 0.14·1.00 |
| home (the depth back) | 0.16·1.00 |
| nudge | 0.25·0.79 |
| ask | 0.32·0.53 |

**Ruled out.** Five feels were built:
- **Pour:** precise springs that never overshoot; too basic.
- **Gel:** Liquid Glass's gel. Too subtle at speed, and the background
  seemed to arrive after the text.
- **Jelly:** a membrane that ripples. Too subtle at speed.
- **Drop:** a drop that leaves the bezel and floats as an island. Lee:
  "It feels weird something creating a drop horizontally." It is parked for
  a panel at the top of the screen.

Of the lights, Neon and Ember were not quite right, and the bloom was too
blurred.

**The window**, from the research into edge and camera-notch apps:
- an `NSPanel` subclass, borderless and non-activating;
- at level `.mainMenu + 3`, on every Space (`.canJoinAllSpaces`,
  `.stationary`, `.ignoresCycle`), and off the screen while a full-screen
  app has its display (under "The strip", "Windows and full screen");
- clicks pass through it except over the shape;
- a global mouse monitor hears the approach, and while the panel is out,
  every move (see Stages, step 6);
- every layer drawn in the stage's coordinates, y down from the top, is
  hosted in a flipped view, the edge's, the ghost's and the caption's
  alike: AppKit sets a hosted layer's flip from its view's, whatever the
  layer says, and an unflipped one drew the glass's light upside down in
  its window, far below its notch (20 October 2026).

The shape is one path rebuilt every frame from the springs. As in the
prototype, they are integrated semi-implicitly in substeps of at most 4ms,
with their velocity kept when a target changes.

**Later: answering from the panel.** A yes or a choice would go through
the session's inbox. A permission prompt would need a hook that holds
Claude Code's prompt open.

### The strip

Lee's idea, 15 October 2026, first as the panel's pinned form: a subtle pin
control on the panel, perhaps in a corner, turns it into a narrow strip:
- full height, below the menu bar (or behind it) down to the screen's
  corner;
- holding the sessions as small icons;
- staying there.

It is an alternative to the notch and its panel, and the floating panel
itself is never pinned (above, "It never takes the keyboard"). It is not
for later (16 October 2026): it is designed in Paper and built, spiked like
the panel was, in the browser first, then in Swift.

**The design**, drawn in Paper's "The strip" (surfaces round 2, 16 October
2026; Lee: "I really like it"). The movement, the hover and the animation
were settled in the browser spike (below, "How the strip moves").
- **The form.** The bezel, grown: 36pt of the same black along the screen's
  edge, both its ends curving back into the bezel as the notch's ends do.
  It reads as a very tall notch with content rather than a strip fitted to
  the bottom (Lee, 18 October 2026). It sits on the notch's edge, left by
  default, and stays. Settings chooses it in place of the notch.
- **Length.** **Grows**, the default, makes the strip as long as its marks
  need, centred where the notch sits, 0.42 of the way down the screen, and
  held between the menu bar and 26pt above the screen's bottom (Lee, 19
  October 2026: "It should just sort of grow as needed"; then "I like that
  it seems to skew slightly above centre"). At its longest it is the full
  strip. **Full** runs it the screen's whole height, the top under the menu
  bar, the bottom 26pt above the screen's bottom. With nothing running,
  Grows draws the strip back into the notch at rest, unlit, and a hover
  there says "Nothing running".
- **Max**, for Grows: the strip's longest length, a slider in Settings
  from five marks' length to Full, the default. It never speaks in marks
  (Lee: "We definitely wouldn't want to record the Max as 'Marks.' That's
  silly."). Past it, the counts take the rest (below, "Too many"). Lee:
  "I like being able to control the maximum height, it's quite cool."
- **A mark per session**, in the panel's order and for the same sessions. A
  mark is the project's two letters in a 24pt ring, and the ring carries the
  state, so the strip reads without a hover:
  - **needs you**: orange, with the panel dot's glow, the letters white; the
    strip doesn't say which kind;
  - **just arrived**: washed orange inside the ring, its glow brighter, for
    two seconds, and the ring flashes twice, as the notch swells twice;
  - **away, with an ask**: orange, the letters dim;
  - **your turn**: white;
  - **working**: a grey track with a pale arc turning round it, the letters
    grey;
  - **on its own work** (22 October 2026): working's mark held still, its
    arc never turning and nothing of it running, until a click's jump turns
    it as it turns any mark's.

  One hairline sits under needs you, as in the panel. The letters are the
  project's capitals where it has two (SitRep SR, DocMan DM), else its first
  two (Switchboard Sw, agntc ag); two sessions of one project share them.
  A session with several lines waiting is still one mark.
- **Under the pointer** a mark pours its panel row out of the strip as a
  tab, the material flaring at both ends. A click jumps, as in the panel,
  on the tab or on the mark itself (Lee, 18 October 2026: "I can hover to
  see the card but shouldn't have to click the expanded card"); with no tab
  out yet, the ring presses in and its own arc turns. An away mark's tab
  says "No window holds it. Carry it on in Claude." and neither it nor the
  mark takes a click. A click on the count opens its tab. A tab, or a
  count's row, has room for one line: a session with several waiting shows
  its oldest, its time, and "+N" for the rest, set as a question's "+2"
  is, in its place where the oldest is a question (the proposal Lee
  agreed, 22 October 2026: "a row is a session on every surface"). Every waiting
  line's words are medium there too.
- **Moving.** The strip never shuts, so the panel's "a changed row moves only
  once it closes" becomes: a needs you arriving moves in at once, the marks
  below sliding down to make room; any other change shows in place, and the
  marks re-sort a second after the pointer leaves the strip. A mark arrives
  when `new` names any of its lines (see "One engine, two front ends"): new
  to the strip, or already on it, from working or your turn, it moves into
  Needs you at once and its ring flashes twice, as a new one's does; one
  already on the Needs you side, a second ask come, flashes where it is.
  One whose asks are answered changes in place and moves at the re-sort,
  as the prototype's answer does (below, "Too many").
- **Too many.** The strip has as many places as Max gives it, or as the
  full height holds: about 30 (32 on a 1117pt screen, 27 on a 982pt one).
  Needs you takes them first, keeping one for your turn and working
  whenever there are any. Past its room, the newest sessions needing Lee
  fold into a count of their own: an orange "+N" ring, the needs-you group's last place, over
  the hairline; away asks fold first (Lee, 19 October 2026: "new asks
  should collapse into a number of collapsed icons... in the bottom of
  their own panel"). Your turn and working take the places left, and past
  them the last place is the grey count ("+3"). Under the pointer each
  count pours out what it holds as one tab of rows, which scroll on a short
  strip. A new ask landing in the orange count flashes its ring twice and
  washes it, as a new mark's, and the marks showing never move. An ask
  answered out of the count changes its row in place; at the re-sort the
  count shrinks, or goes and the last folded mark takes its place. Lee: "It
  works."
- **Windows and full screen:** macOS lets no app reserve screen space as the
  Dock does, so a window filling the screen goes under the strip's 36pt; Lee
  hasn't said how that reads. Nothing of SitRep's goes over a full-screen
  window, the notch as well as the strip (Lee, 19 October 2026: "It should
  be hidden. Nothing should go over the top of a full screen window"): while
  a full-screen app has the panel's display, the panel is off the screen,
  and it comes back as the display leaves it. A maximised window doesn't
  count, and each display is judged on its own. How SitRep tells, as the
  spike found:
  - **Leaving the window off full-screen Spaces wasn't enough.** A
    non-activating panel on every Space still showed over Plex full screen.
  - **Bounds alone can't tell the two apart.** Under the built-in display's
    notch, a maximised window has a full-screen one's bounds.
  - **The system's presentation options**, read for the app in front,
    didn't catch Paper full screen.
  - **What works, from the window list:** a display is full screen while
    the Dock's full-screen backdrop covers it. The backdrop is a window
    owned by the Dock, at layer −2147483622 on macOS 26, read by owner,
    layer and bounds, so it needs no Screen Recording. A probe once a
    second while Lee put Paper full screen showed it there for exactly that
    long; meanwhile the display's menu bar and wallpaper windows were gone.
    If a later macOS changes it, the panel only shows over full screen
    again.
  - **When SitRep looks:** on each change of Space, of the app in front and
    of the screens, and once more a second later, as the backdrop slides
    in. Nothing polls.

  The private SkyLight call yabai uses would read each display's Space type
  directly. It was left out, as nothing guarantees it across macOS
  releases. In the Swift spike; Lee, putting Paper full screen and back:
  "It works".
- **Material:** Black, the bezel's, or Glass, macOS 26's Liquid Glass, for
  the strip and its tabs alike, as one shape (Lee, 18 October 2026: "I like
  the glass and the black, actually"). See Settings.

**How the strip moves**, felt in the browser spike (18 October 2026, the
prototype's Strip tab; Lee kept its defaults):
- **The first tab** pours once the pointer has rested 120ms on a mark, the
  strip's edge bowing 3pt toward it meanwhile, so a pointer crossing the
  strip opens nothing. Once a tab is out, the other marks take no wait.
- **Pouring,** the tab's depth springs out to its row's width as its body
  grows from the ring's 24 to 52; the words fade in from 55% to 95% of the
  depth. The tab is 52 deep, flared 10 into the strip at both ends, its
  front corners 16, as wide as its row needs, from 240 to 360.
- **Along the strip** the one tab glides to the next mark, its place and
  width springing, its words crossing in 160ms the way the pointer went.
  Lee chose this over each mark pouring its own tab.
- **Leaving:** a grace of 300ms, a fifth of that when fast. The words go in
  60ms and the black 30ms later, drawing back into the strip through a dent
  of at most 3pt. A click elsewhere draws it back at once.
- **The strip's ends never change; a tab fits into them** ("Fit"). The S at
  the top, its tight curve under the menu bar and its bump, is the same in
  every frame, whatever a tab does, and so is the bottom's. The marks start
  12pt lower than the board has them, to make room, and the first mark's tab
  meets the S's lower curve in a fillet: a circle touching both, 10pt where
  it fits, never leaving the S above where it has turned 70° (6.5pt at the
  first mark), so the S reads whole above it. A tab lower than the S's end
  flares into the straight edge as usual. The last marks keep the same room
  clear of the bottom's S, and their tabs and the count's fit into it the
  same way. Lee: "fit is the one! the others are no good", over:
  - the curve drawing up into a fillet under the menu bar ("Give way"),
    which on the display read as a sharp corner against the see-through
    menu bar;
  - the corner rising to meet the tab ("Rise"), which lost the S's bump;
  - a fixed rounded corner, and the first tab hanging below its ring;
  - every mark 26pt lower ("looks worse for it"), and the tab running into
    the curve as one shape.
- **Marks moving** slide to their places. A new needs you grows into its
  place once the mark below has slid 45% of its step, its ring flashing
  twice, 450ms apart. A tab out while marks slide stays with its mark, then
  glides to whatever is under the pointer. The re-sort waits a second after
  the pointer leaves.
- **Growing and shrinking**, at Grows: the strip's ends spring on their own,
  leading the marks out as it grows (the marks' slide 1.25× quicker) and
  following them in as it shrinks (1.25× slower). With nothing running for
  120ms, its outline morphs into the notch's at rest point for point, each
  end's S into the notch's at rest. A press dragged along the edge carries
  it.
- **Reduced motion:** no springs and no reach; a tab's shape fades in and
  out, and marks snap to their places and fade in.
- **In glass**, Liquid Glass has two thicknesses and picks one from a
  shape's size: the strip alone would be thin, the strip with a tab out
  thick, and a shape rebuilt every frame switches at once (Lee: "it needs
  to be a little more graded rather than instant"). A thin glass fading out
  over the thick one still read on the display as two steps, so the strip
  is thick glass from rest, one look in every frame (Lee, 19 October 2026:
  "the glass panel looks good as it is"). A mark's ring lifts once under
  the pointer, over 110ms, and settles back once. The working arcs and the
  shimmer turn in Core Animation, in the render server, so the strip at
  rest does no work in the app.

They ship fixed, as the notch's do (above, "The app ships these values
fixed"). Lee's settings:
`{"bounce":0.50,"dwell":120,"reach":3,"pour":1.00,"glide":1.00,"fade":160,"close":1.00,"room":12,"grace":300,"settle":1000,"slide":1.00,"lead":1.25,"swells":2,"edge":"left"}`.
The springs, after Bounce, as SwiftUI's `.spring(response:dampingFraction:)`:

| Spring | Value |
|---|---|
| reach | 0.20·0.70 |
| pour | 0.26·0.72 |
| grow | 0.22·0.80 |
| glide | 0.24·0.82 |
| width | 0.24·0.86 |
| draw | 0.22·0.80 |
| slide | 0.36·0.80 |
| ends | 0.29·0.80 growing, 0.45·0.80 shrinking |
| arrive | 0.30·0.55 |
| press | 0.10·0.70 |
| morph | 0.42·0.86 |

### The SitRep window

The bigger window, showing the whole board and updating as it changes (Lee,
16 October 2026). An away session with nothing waiting, which the panel and
the strip leave off, shows here, on its project's page. Drawn in Paper's "The SitRep window"
(surfaces round 3, 17 October 2026; Lee: "I like it", taking it as it
stands).
- **Two columns**, in a window of about 1100 × 720, the page the panel's
  black:
  - **the board** down the left, in the system's sidebar (see "The frame
    is macOS's own"): the card's list at the window's size, as Paper's board
    D, "One list, two sizes", draws it (22 October 2026). Lee, of the card
    listing a session's three asks as three rows while the sidebar showed
    the session once and its asks only on its page: "We should be
    consistent in that view", the sidebar feeling "very messy"; and of a
    session's asks drawn apart under it, "It shouldn't look different if a
    session has multiple asks". It replaces round 8's board C, "Option B,
    one list" (Lee, 21 October 2026: "let's go option B, so we get rid of
    the project and Needs You button"), which listed Needs you, then every
    project under its heading with its sessions, so every ask showed twice,
    then the quiet projects. Under the titlebar's band sits the Filter field
    alone, the system's search field at its large size, 28 tall, 9 under the
    band and 10 over the list. Then **one list**, the card's sections in the
    card's order, each session once, in its section, a row only where core
    has one (see "The rows"), so an away session with nothing waiting is
    reached by its project; then Projects:
    - **Needs you** heads it: every session with an ask or a window
      stopped on a permission prompt or a question, the oldest first, by its
      oldest line, an away session's after the live ones, as core's rows
      have them. A row is a session, one shape however many lines it has:
      each ask or stop waiting a line of its own, 16 tall, 3 apart, its dot
      (7) in the 26 slot, its words 13 medium in white at 85%, and its age
      12 in tabular figures; then "project · session" at 11 in white at 55%,
      1 under the last, aligned with the words. The row is inset 4 at its
      top, so one line is the system's two-line row, 39 tall, as built; each
      line more makes it 19 taller. As the row washes, a new ask's coming,
      only the new line's age goes orange, which tells it among the rest;
    - **the rule** after it sets it off from what follows, the foot's own:
      0.5 tall in the separator colour, inside the sidebar's 10 either side,
      11.5 under Needs you's last row, or its heading where it is folded, so
      it ends on a whole point and every row after it starts on one, the
      next heading 10 under it as every heading sits. It shows only while
      Needs you shows and a heading follows it, filtered or not. It is drawn
      behind the heading after it, on that heading's row, so the list holds
      no line of its own for it, whose insets a live window could move as it
      moved the foot's: nothing picks it, the pointer lights nothing on it,
      the arrow keys pass over it with the heading, and VoiceOver reads
      nothing there. Lee, 22 October 2026: "we should separate the 'Needs
      you' from the rest of the project list … we already said we would
      have a rule, but it also needs just a little bit of space";
    - **Working** follows: the sessions whose turn runs, the longest running
      first, then those on their own work. Its rows are Needs you's one-line
      shape, two lines, 39 tall: the working mark, its still arc on a faint
      track (r 4.25, white at 55% on white at 15%), or on its own work's
      ring of round-capped dashes in white at 45% (r 4.25, its stroke 1.5,
      dashes 1.5 with gaps of 2.0); the verb 13 medium in white at 55%, and
      5 after it what it acts on in white at 35%, a command in mono at 11,
      anything else at 13, a wake's countdown among them; how long its turn
      has run, or since it ended, 12 in white at 55%; then "project ·
      session" under them. It needs nothing of Lee, so it is greyer than the
      rest. Nothing in the sidebar turns;
    - **Your turn**: the sessions waiting on Lee with nothing posted, the
      newest first, each on one line, 28 tall, inset 6, its parts 4 apart:
      the open ring, 10 across, r 3.75, its stroke 1.5, in white at 55%;
      what Claude left Lee, 13 regular in white at 85%, cut short; its
      project at its right, 11 in white at 35%, its own width, never cut, 10
      after the words at the least (board D's 6 of padding after the row's 4);
      its time 12 in white at 55%, tabular, in a 30 lane. Those whose turn
      ended longer ago than the fold period (Settings' "Your turn folds
      after", an hour unless Lee sets four hours, today or never) fold into
      **"N earlier"** at its end, as on the card, shown only while at least
      one has: 28 tall, its ring in white at 25%, "8 earlier" 13 regular in
      white at 55%, its sessions' projects 9 after it, 11 in white at 25%,
      each once in the rows' order, comma-separated and cut short, and a
      chevron where a heading's stands, right while folded. A click
      anywhere on it opens them in place as ordinary your-turn rows under
      it, its chevron down, and a click again folds them, each at once; the
      list never selects it, and under the pointer it shows a row's quiet
      fill. Whether it is open is never kept: it is folded each time the
      window opens, and as the line goes, its last row starting a turn, so
      it never comes back already open. The period is measured from each
      row's turn's end against the wall clock: as time passes a row folds in
      the moment it passes the period, the window drawn again then as for
      any change by time alone, nothing polling; the period changing refolds
      the list at once;
    - **Projects** ends it: every project on the board, quiet ones too, a
      row each in `watch`'s order, its name 13 regular in white at 85% after
      an empty slot, 28 tall, each opening its project as a project's name
      does: its sessions, those no window holds among them, and their notes
      (Lee, 20 October 2026, of the projects with nothing open: "at least
      interact with them, view them, see them"). It is folded at first. A
      project's page is reached from it and from the session page's project
      name;
    - **A heading is a row of the list**, not the system's section header,
      whose chevron hides at rest and alone folds: 24 tall, 10 under what is
      before it, the first of them too, which sits 10 under the list's top,
      20 under the Filter field (Lee, 22 October 2026, of the first heading
      2 under it: "where it says 'Needs you,' that's a little bit close …
      the 'Needs you' eyebrow for that top section needs a little bit of
      spacing", System Settings' sidebar his reference, its first item
      about 20 under its Search field). Its name is 11 semibold in white at
      55%, and 6 after it its count, 11 semibold in tabular figures, orange
      for Needs you and white at 30% for the others: Needs you counts its
      lines waiting, the asks and stops; Working and Your turn their rows,
      "N earlier"'s among them; Projects its projects; each of what it
      lists, filtered or not. Every heading folds, Needs you's too: a click
      anywhere on it folds what is under it to the heading alone, or
      unfolds it, at once, with no motion, as the card's eyebrows do, and
      never moves the pick; the list never selects it. Its chevron, in a 15
      by 24 slot whose end is a row's time's, always shows which way it is,
      down open (10 by 6) and right folded (6 by 10), stroked 1.5 in the
      tertiary label colour, a step brighter under the pointer. The folds
      are kept across launches, the sections folded and whether Projects
      is, in the window's saved value of its own, "window"; a round 8
      value, its projects folded by their keys, reads as the defaults,
      Projects folded and nothing else. A picked row that moves into a
      folded section, its turn ending under a folded Your turn, stays hidden
      there, and the arrow keys step from that section's heading, as from any
      pick a fold hides. While the filter holds text every section with a
      match shows open, "N earlier" too, and the folds come back as they were
      when it clears, but for a pick made meanwhile (see the selection); a
      heading clicked meanwhile folds only until then;
    - **the type is the card's**, not System Settings' regular, in its
      whites (Lee, 22 October 2026, approving board D: ask lines medium,
      working verbs medium, your-turn lines regular). Paper draws in Inter
      and the app in SF, so the built metrics stand, the headings, the
      two-line rows, the rule and the foot, and board D's are taken relative
      to them;
    - **the filter** narrows the list in place, every section by one rule.
      A session stays while every word typed appears, anywhere, in its
      name, its project's or any of its lines' words, whatever their case
      and accents: typing a project's name lists its sessions, "gh pr" finds
      the session a permission prompt for `gh pr create` waits on, "3
      agents" the one on its own work waiting on them; a project stays in
      Projects while its name holds every word. A section with no match
      goes, its heading with it. The words are lit wherever they appear, a
      step brighter than the rest: in the label colour on words the rest of
      which goes soft, and soft on fainter ones, so an away row still reads
      as away. It never moves the pick: the page stays on what was open,
      even with its row filtered out. ⌘F focuses the field, Return in it
      opens the first match, the list's first row that picks, as it shows,
      never a heading nor "N earlier", nor a row a fold made while
      filtering hides. × or Escape clears it and gives the whole board back;
      Escape in it empty does nothing, and with an answer waiting, Escape
      takes the answer back first, as anywhere in the window. The window
      opens with focus on what holds the pick, the board's list or Settings
      at the foot, not the field, and focus moves there too whenever opening
      it turns it to a pick, as ⌘, and the menu's Settings… do. What it
      holds is not kept: closing the window clears it;
    - **decided for round 7** (21 October 2026, as the design pointed):
      a filter that keeps nothing anywhere says so in one centred line, "No
      sessions match “ledg”", the field's text in the quotes, and an empty
      board says how the board stands in the same place, as the panel's head
      words it; and the field carries no "⌘F" hint, which the system's
      field does not draw.
    - **its foot is Settings**, a row with the system's gear in the accent,
      fixed under a rule at the list's foot (see "Settings"): the rule 0.5
      tall in the separator colour, inside the sidebar's 10 either side, 8
      under it the row, 32 tall, then 10 to the glass's foot. The list ends
      at the rule, its last row 12 over it, and its rows fade out at its own
      bottom edge, just over the rule, by the system's soft scroll edge, on
      macOS 26 only, never a drawn gradient over the glass; no row ever
      passes behind the Settings row. Settled after three live failures, 21
      October 2026: a window on screen gives the sidebar a bottom safe area
      that one offscreen does not, and while the foot was a list of its one
      row in the system's bar over the board's list, which ran on under it,
      it rose by it live in three builds running, every offscreen test
      passing: round 7's 24.5 under its hairline and 20 over the glass's
      foot; with the safe area ignored, its row still 20 over the glass's
      foot, no rule to be seen and the list's rows showing under it
      (fd54b60). So the foot is SitRep's own, the column's last part under
      the list, laid out by SitRep alone, with no inset, safe area or bar for
      the live window to move. Picked, Settings shows on the right, where a
      session would, and the board's list holds no selection while it shows;
      SitRep draws the foot's selection itself, in the system's selection
      colours, shaped as the list's: 276 wide, 10 in, its corners 9, the
      accent while it has the key window's focus, its gear and word white,
      else the system's grey. Under the pointer, and not
      picked, it shows a row's quiet fill, gone as the pointer leaves or the
      window goes out of sight. A click anywhere across it opens Settings, in
      a window not key too, and takes focus there, as a click on a list's row
      does; a Control-click, the Mac's right-click, opens nothing. A click on
      a session or a project leaves Settings for it, and a board changing
      under it leaves it showing.
  - **the session** Lee picks, on the right: the pane's session view at
    window size. Its project's name is an eyebrow over its name, about 15
    points semibold in the secondary colour, smaller than a title and more
    than a caption, and a press opens the project. It starts at the top a
    project's title starts at, so going from a project into one of its
    sessions keeps the project's name in place (Lee, 20 October 2026, of
    the name as a small button up by the toolbar: it "suddenly gets really
    small and tucked up right close to the top… It almost sits inside the
    header of the page"). Its name sits close under the eyebrow, then its
    summary; what its window is doing now, the panel row's second line;
    then Asks, Status, Notes, Parked and Resolved, in the pane's order, the
    last four in two columns so a session fits without scrolling.
  - **the band under the toolbar**, beside the traffic lights, stays
    empty on every page, a session's, a project's and Settings': nothing
    of the page sits in it.
- **A session's row is the card's row at the window's size:** the same
  marks in the same lanes, the same words, and the panel row's time.
- **A project**, opened from its name or its row in Projects, is the pane's project view: its open
  sessions, each with what it is doing and what waits there; every session's
  asks, the newest first; their notes; and their parked items, the oldest
  first. Each line names its session, unless the project has only the one,
  which it could only name. There is no Resolved. An ask there is one line,
  and opens in place into its card.
- **It opens on** the oldest session that needs Lee; with none, on the one
  picked last. There is one window: opening it again brings it forward,
  on the Space Lee is on: it moves to the active Space and comes forward
  there before SitRep activates, so the activation takes him to no other
  Space. The menu opens it (see "The menu bar item"). ⌘, and the menu's
  Settings… open it on Settings, or turn it there where it shows already;
  ⌘, is a key of the app's main menu, which an accessory app never shows,
  so it works while a SitRep window is key.
- **The frame is macOS's own** (Lee, 20 October 2026, of a sidebar of
  hand-made glass, its corners unlike the window's and the traffic lights
  on its corner: "It looks a mess"). Whatever macOS draws, SitRep does not
  make again:
  - the window is AppKit's split, its board the split's sidebar item, which
    macOS 26 draws as Liquid Glass floating inside the window, its corners
    concentric with the window's, and earlier macOS in its sidebar
    material; the page sits beside it. Each side is SwiftUI;
  - the sidebar is pinned at the drawing's 296 points and never collapses,
    by a drag or by the window narrowing, as there is no toggle to bring it
    back. That is why the window is not SwiftUI's `NavigationSplitView`:
    it pins neither;
  - the window carries an empty toolbar, unified. Its taller titlebar is
    what sets the traffic lights inside the glass, 11 points in from its
    corner as Finder's; without one macOS puts them on the corner, a point
    in. Their middle is 26 points down, in the middle of the empty band the
    page starts under;
  - macOS draws an app in the design of the SDK its binary records, so the
    glass shows only in a build that records macOS 26's, as `app/bundle`
    sets it. Offscreen, the window's parts can be read, the sidebar item
    and the toolbar, but not what macOS draws of them;
  - the stills draw the sidebar as a stand-in, laid out as the system's
    list lays out its rows and on the panel's black, the row picked on a
    stand-in for the selection: nothing offscreen draws a list or a
    sidebar's glass, which come out blank.
- **The board is a list with a selection**, in the sidebar's style: the
  session or project picked is the list's selection, drawn by the system,
  and nothing clears it, neither a click in the list's blank space nor on
  the row picked. Each session shows once, so its row is the pick: the
  pick is a session or a project and nothing more, the round 8 `Spot`,
  which said which of a doubled session's two rows showed it, gone with
  the doubled rows. A session keeps its selection as its row moves between
  sections, its asks coming or answered, its turn ending, its row the same
  session's. The pick fills the whole row, whatever its kind, the
  system's accent at radius 9, under which its words go white and the rest,
  its second line, its project, what it acts on and its ages, white at 80%;
  the orange stays orange. A project's page shows picked on its row in
  Projects, as a session's does on its own. A session with no row of its
  own, an away one with nothing waiting, picked from its project's page,
  stands at its project's row in Projects, which shows picked; with its
  project listed nowhere either, as one filtered out, nothing shows picked.
  That row stands in for it and is not the list's selection, which holds
  none, as for a pick a fold hides: SitRep draws the selection on it as the
  system would, its grey, or the accent while the list has the key window's
  focus, its words white on it, so a click on it selects it and opens the
  project's page.
  A pick made outside the list, a restore at launch, the menu opening a
  session, a jump, a project's name pressed on a session's page, unfolds
  the section holding its row, Projects for a project or a session with no
  row, and opens "N earlier" where its row is under it, so the pick shows;
  the unfold is kept, as a click's is. While the filter holds text a pick
  unfolds only what shows until it clears; as it clears, a pick made
  meanwhile, by a click, the keys or Return, shows: whatever of Lee's folds
  would hide it unfolds as for a pick made outside the list, kept, and "N
  earlier" open for the run only, and everything else the filter opened
  folds back; a pick made before the filter changes nothing as it clears.
  A heading folded over the pick hides its row and keeps its page, the list
  then showing nothing picked, Projects folded over a project's page as
  any. The arrow keys move
  the selection through the list's rows in order, past the headings and
  "N earlier", which the list never selects, and past what a fold hides,
  each step a pick; from a pick the list holds no selection on, ↓ goes to
  the first row after the line it stands at, and ↑ to the last before it:
  for a pick a fold hides, the line it is folded under, its section's
  heading or "N earlier"; for a session with no row, its project's row, or
  Projects' heading folded over it; past either end the
  keys go nowhere, and with a modifier held they are the list's own; picks that
  follow sooner than 150ms read only the last one's boards once they stop.
  With the Mac's key repeat faster than that, holding ↓ reads the first
  row, the second, as the Mac waits longer before a key repeats, and the
  one it stops on; at a slower repeat each row reads. Only a read that
  runs takes its place as a session's latest, so one let go never throws
  away a read under way, and none waiting runs once the window closes or
  is minimised. Each pick in the list holds the list's order for a second
  after it, as the pointer over the list does, so no row moves between two
  presses of a key; closing or minimising the window lets the hold go. Each
  section is held on its own, as on the card, and Projects too, so a row
  changing section leaves its held place and takes its place in its new
  one, where `watch` has it. A resort slides the rows; a fold, or a row
  folding into "N earlier" as time passes, changes the list at once. The
  row picked scrolls into view, only as far as it needs, whenever the pick
  or the order changes: a pick made elsewhere, by a jump, a notification
  or the menu, or before the window shows, and a resort or a fold. The
  Filter field stays put above the rows as they scroll.
- **Under the pointer** (Lee, 20 October 2026: "When I hover down the
  left-hand side, nothing highlights"; then, of glass highlights over the
  rows, "a very deeply translucent, blurred bar"):
  - a row of the sidebar not picked shows a quiet plain fill behind it,
    white at 6%, never over its words, anywhere the pointer is on the row;
    the one picked keeps the system's selection. "N earlier" shows it too.
    A heading shows no fill, only its chevron a step brighter. While the
    selection is the accent, the window key and the list holding its focus,
    the row's words go white and the rest white at 80%, as above, and its
    grey marks brighter, as the system does on its own rows (Lee, 21
    October 2026);
    its orange stays orange. A session new to needing
    Lee washes the whole row orange, in the selection's shape. There is no
    glass highlight anywhere;
  - on the page, a line that opens, a project's session or ask, and a
    card's head show the panel's fills behind them;
  - every button shows a hover: the pills, the jump, the project's name
    above a session, "show all".
- **Keyboard focus is the system's.** In the sidebar the selection is the
  focus. The page's buttons take focus, each showing
  the system's own ring, shaped to it, a pill's ring a pill, only while the
  Mac's Keyboard navigation setting is on, as in any Mac app. Lee, 20
  October 2026, of a white outline of SitRep's own, which showed round a
  row untabbed and, tabbed, as "a strange kind of border or ring around
  the option, which is not very Mac-like at all"; before it, the system's
  blue square ring, where SitRep had made every button take focus. The
  order is the Mac's own: the Filter field first, then the board's list,
  the arrows inside it, then its foot, Settings,
  then the page's buttons. With Keyboard navigation off, Tab stops at the
  field, the board's list and the foot alone. The foot is one stop, which
  shows focus as a list's row does: picked, by its selection in the accent,
  with no ring; not picked, as Tab reaches it, by the system's focus ring
  in the selection's shape. The arrows go
  nowhere from it, as from either end of the board's list, and Space or
  Return on it opens Settings, focus staying there, and with a modifier held
  does nothing. Two keys move between the
  sides, through AppKit's key views: Return in the sidebar, anywhere but
  the Filter field, whose Return is its own, and the foot while Settings is
  not open, moves focus into the page, to
  its first button, as Tab from the foot would; with Keyboard navigation
  off nothing there takes it, so Return leaves focus where it was, never
  passing through the field, and does nothing more. Escape in the page, with no answer waiting to take back, moves it
  to what holds the pick, the board's list or the foot, and to the
  board's list when neither does.
- **VoiceOver reads words, never symbols.**
  - a sidebar row is one element. A Needs you row reads what waits first:
    how many where there are several, "2 asks", then each line's words; then
    its project and session, "away" where no window holds it, and the
    oldest's age, as "2 asks, Paste the load test's output, Allow Bash gh
    pr create, Switchboard, Dashboard redesign, 3 hours" (22 October 2026).
    A row of Working or Your turn reads its line's words, its project, its
    session, its state (working, on its own work, your turn) and its age, as
    "Drawing the ledger schema, Switchboard, Request ledger, your turn, 12
    minutes". A heading reads its name and its count, as "Needs you, 4
    waiting", "Your turn, 3 sessions" or "Projects, 6 projects", and folded
    says so, "Working, 2 sessions, folded"; "N earlier" reads how many and
    their projects, as "8 earlier, Switchboard, Fumi", and folded says so;
    a project's row reads "Kit, project". The Filter field reads as
    "Filter sessions", and the foot as one of the sidebar's choices, a radio
    button, "Settings", selected while Settings shows, as a list's row reads
    selected, and announced as that changes;
  - the page's title, the eyebrow and the section headings carry the
    header trait, each heading read with the words on its right, as
    "Asks, 3 waiting";
  - a card is a container labelled by its ask's title, after its
    session's name on a project's page, its buttons inside it. The title
    is said once, by the container; on a project's page its head, which
    closes it, reads "Close";
  - a mark reads its meaning, a closed ask's tick "closed"; a section's
    bullets, which say what its heading says, are not read, nor the ↗ of
    "Open in Ghostty".
- **Items that open.** A note, a parked item and a resolved ask open in
  place on a press, and close on a second, as an ask does in a project's
  view: the line whole, wrapping, and under it a note's detail, where a
  parked item was parked from, or how an ask closed: Lee's answer as the
  board words it, or Claude's resolve and its reason. A status line opens
  only while it is cut short. A line with nothing more to show is not a
  button, and takes no keyboard stop. Lee, 20 October 2026, of an opened
  item with a box behind it, its title in a narrow column hanging from its
  session's name and its detail under the bullet: "a bit shit". So every
  line of Status, Notes, Parked and Resolved, opened or closed, keeps one
  grid:
  - the marker in its lane, then the words, then the time on the first line;
  - a session's name is a quieter lead-in in the words' own flow, wrapping
    to their left edge, never a column of its own;
  - opened, the words wrap whole in their column, and the detail sits close
    under them from the same left edge, a size smaller, in the secondary
    colour. Nothing behind it, no fill and no ring; the hover fill shows
    only on a line that opens;
  - it opens and closes at once, with no motion of its words or of the
    lines below. Lee, 20 October 2026, of its spring, where a word cut in
    half by the truncation became whole and then dropped to the new line:
    "I don't see really why we need it… Let's just sort of make them
    appear. Less is more."
- **Answering.** A session's asks show opened, as cards with their buttons:
  - **a yes** is a white pill in Claude's words, the brightest thing in the
    window; **a choice** is one outlined pill per option. Both are answered
    here;
  - **the buttons sit on one line** as pills while they fit at their
    one-line widths, measured. Past that, as Claude's long options are, the
    answers lay out as a column of rows as wide as the card, left-aligned,
    their words wrapping, with Comment in Claude and Ignore on a line after
    them, or every button a row where that line would not fit either;
  - **the answer waits 2 seconds**, a line draining under it, with Escape to
    undo (borrowed from One, in Lee's dex). Then it goes into the session's
    inbox, as the pane's replies to another session do (see "Delivery"), by
    `sitrep answer`. The card says "on its way", then "sent, and Claude has
    it", then moves to Resolved, as each ask's `reply` in `board --json`
    says (see "One engine, two front ends"). The board never closes an ask
    on the press alone;
  - **a jump shows on the button pressed** alone, faint while it runs; the
    other cards stay as they look, and take no second jump while one runs;
  - **a comment, a words ask and a permission prompt** need Claude Code's
    prompt, so their buttons read "Comment in Claude ↗" or "Answer in Claude
    ↗" and jump to the session's window. Proposed, and new: that jump also
    puts the window in answering mode for the ask, its band saying "Your
    next Enter answers…". The mod cannot hear that from the app today;
  - **ignore** is quiet grey text.
- **A permission prompt or a question** is the window's state, not an ask.
  It takes the state line's place, washed orange as the panel row that
  brought it, and says the tool and what it would run.
- **The jump** is "Open in Ghostty ↗", shown only while a window holds the
  session, and only on a session's page. ↗ marks anything that leaves
  SitRep. It sits on the row of the session's name, trailing, centred on
  its first line, while the name wraps to no more lines beside it than
  across the whole width, as measured; on a window too narrow for that, it
  goes under the name, leading. Lee, 20 October 2026, of it above the
  name, by the toolbar: "Hierarchy-wise, that shouldn't be there… it's
  opening the session in Ghostty. Doesn't make sense to have it above,
  this is like basic UI principles."
- **Away**, a session no window holds:
  - there is no jump, and the state line says "No window holds it. Carry it
    on in Claude.";
  - its yes and choice asks can still be answered: the answer waits in its
    inbox and goes in when a window takes the session up again. A comment or
    words wait for that window;
  - its foot has "✓ Finish this session", which asks first, in place, as the
    pane's does, then runs `sitrep finish`.
- **One colour.** Orange is for needs you only: the dots, the counts,
  "2 waiting". Parked and resolved stay grey, not the pane's purple and
  green.
- **Live.**
  - A new needs you moves in at once, the rows below sliding down, and is
    washed orange for two seconds.
  - Any other change shows in place, and the list re-sorts a second after
    the pointer leaves it, as on the strip.
  - The session open on the right never shifts while Lee reads it: an ask
    closed meanwhile keeps its place, faint and without buttons, saying how
    it closed, until another session is picked.
  - The window never comes forward or takes focus by itself; the notch or
    the strip tells Lee.

### The menu bar item

The item in the menu bar and its native menu, drawn in Paper's "The menu
bar item" (surfaces round 4, 17 October 2026). A first drawing kept the
menu to the SitRep window, Settings and Quit. Lee, with Spaceman's menu
beside it (a header, its spaces with a click to each, quick settings),
asked for the sessions back, and approved the redraw as it stands.
- **The menu, top to bottom:**
  - **a header**: SitRep's icon, its name and its version. The icon is the
    one macOS renders for the bundle, at the header's 30. A click on it
    opens About SitRep (see "About SitRep"): under the pointer or the keys
    it takes the menu's own highlight, the accent behind it and its words
    in white, as any item does. It is set at the menu's 340, so the
    highlight runs across the menu, and never stretches with it, as one
    stretched to the menu kept the widest the menu had ever been;
  - **the panel's sessions**, in its order and with its marks (see "The
    rows"), under a heading in the panel head's words, "4 need you" or "All
    clear". Each is a native item with a subtitle (macOS 14.4): what it is,
    then its project and session, and its time on the right as the item's
    badge. An item is a session, as a row is, with room for one line: one
    with several waiting shows its oldest, its time, and "+N" for the rest,
    as the strip's tab does. A row on its own work is faint, as a working row is, its mark
    the dotted ring, and a wake's countdown is set again as it ticks, with
    the badges. A separator sits where the panel's hairline is. A click
    jumps;
  - **Open SitRep Window**, after the list, for what the list leaves out:
    away sessions with nothing waiting, notes, parked and resolved;
  - **Show**: Notch, Strip or Nothing, inline, the one in use ticked, so
    pinning the strip takes one click. With Nothing, the menu and the
    SitRep window carry the board, and the glyph still lights for needs
    you;
  - **Settings… ⌘,**, the SitRep window on Settings (see "Settings");
    **Check for Updates…**, with Sparkle, from the first public release;
    **Quit SitRep ⌘Q**.
- **About Spaceman's width, a little wider** (Lee, 20 October 2026): the
  whole menu is 340 points, the one number to tune. A native menu is as
  wide as its widest item, so each row's title is cut at its tail with an
  ellipsis to what AppKit leaves of the 340 round the mark's lane, the
  badge and the insets, measured on an offscreen menu laid out as this one,
  each run in the font it is drawn in, the subject in SF Mono. The line
  under it is cut the same way, and to no more than AppKit sets on one line
  before it wraps, so no row grows taller. macOS draws that line at the
  small size, 11 points. The shares are measured once, as the menu first
  draws, so a change to the menu bar's size in System Settings holds
  until SitRep starts again. A row cut short has its whole words as its
  tooltip.
- **An away session** is disabled, with no window to jump to: its words
  dim, and its dot with them, as macOS dims a disabled item's image and
  AppKit has no switch for it, where the panel keeps the dot orange
  (accepted, 20 October 2026). **Past twelve rows** the list
  ends with "4 more…", which opens the SitRep window.
- **One lane on the left** holds the marks, the tick and an SF Symbol for
  each command, as macOS 26's own menus carry icons. The tick is drawn as
  the item's image, so the menu has no state column.
- **It speaks up first** when something is wrong, under the header:
  - windows on an old sitrep, which haven't run `/reload-plugins` (their
    heartbeat's version says so), listed under "Needs /reload-plugins", a
    click jumping to each. The heading goes once every window is current;
  - "SitRep can't read the board", with the reason in plain words, when
    `sitrep watch` stops or the CLI fails, as today's menu says. The
    sessions stay as the board last read them, their heading saying when
    ("4 need you · as of 12:04"). The notch, the strip and the window keep
    the last board too, marked as stale.
- **How the app keeps `watch` running** (built 19 October 2026, in
  `app/Sources/SitRepCore`; the CLI's side is under "One engine, two front
  ends"):
  - **The back-off.** A `watch` that ends is started again after a second,
    the wait doubling at each end in a row to 30 seconds, and starting over
    once a run lived a minute, or after a renewal.
  - **The renewal.** `watch` exits 0, unasked, when its plugin's version
    moves under it, so the app runs the new code. That is started again at
    once, the board not marked stale, as the new run's first line follows
    within a second or so. An exit 0 within a second of the run starting,
    or within a minute of the last renewal, is a failure, so a `watch` that
    keeps exiting cannot spin. A run's life counts from its child starting,
    not from asking Lee's shell for the PATH before it.
  - **The reason.** The last 20 lines of `watch`'s stderr are kept, each to
    1KB. The reason is the last that says anything: the CLI's own `sitrep:`
    line when it ended on its own error, else the error's own line when Bun
    crashed, never Bun's version trailer, a stack frame or the source Bun
    quotes. With none, it says how `watch` ended: "ended", "ended with
    status 1" or "was stopped (signal 9)". Output is read for half a
    second after `watch` exits, as for any run of the CLI, so a child left
    holding it open does not hold up the exit.
  - **Stale since.** The board is stale from the instant the app heard the
    exit, the failed start, or a line that does not read (one longer than
    1MB among them); the "as of" is that instant, not the board's own time,
    since `watch` prints only on a change. A line that reads ends it.
  - **The first board of a run after another** is marked as resumed: its
    `new` and `changed` are empty, as on any run's first line, though the
    board may have moved while `watch` was down, so the SitRep window reads
    what it shows again in full. The app decides no rows of its own, so a
    row that needed Lee and came while `watch` was down gets no swell or
    flash: accepted.
- **The icon** in the menu bar is the light's glyph (see "The icon"): white
  on a dark menu bar and black on a light one, its bar lit orange while
  anything needs Lee, since the notch is on one display and the menu bar on
  every one. The header carries SitRep's app icon, which never changes.
  Round 4 drew a placeholder, a screen with a bar at its edge and a dot for
  needs you; round 6 replaced it.

This replaces the 13 October plan, a menu slimmed to Settings and quitting
with the plain list of sessions kept as a fallback, and round 4's first
drawing, which left the sessions to the SitRep window.

### Settings

Settings is a page of the SitRep window, drawn in Paper's "Settings in the
window" (surfaces round 7, 21 October 2026; Lee: "Yes, I really like what
you've done there. Let's go ahead and build it"). It replaces round 5's
separate Settings window and its three panes (Paper's "Settings", 17
October 2026; Lee: "nice", once the dials for how the notch moves were
taken out), so there is one SitRep window. Lee asked for macOS 26's Liquid
Glass, modern and led by content, with Spaceman's preferences as a
reference only.
- **Where it opens:** the sidebar's foot, a row of its own, or ⌘, and the
  menu's Settings…, which bring the window forward on it (see "The SitRep
  window"). It shows on the right, where a session or a project would;
  nothing on the board is picked while it shows, and a click on a session
  or a project leaves it for that. A board changing under it leaves it
  showing.
- **One page, set as System Settings sets its grouped form** (Paper's
  "Round 8 · sidebar and Settings", boards E and F, 21 October 2026; Lee:
  "all the settings look good", after he found round 7's "don't look very
  Mac… the text is too big"): the title in a project's page's place and
  size, with nothing under it, then What stays on screen, Notifications and
  General, each headed in sentence case, 13 semibold in the label colour,
  10 in from its card's edge and 10 over it, the sections 30 apart. They
  sit in a column that fills the page less 44 on each side, as a session's
  and a project's pages do, at the title's edge, so the title stays where a
  project's is. It has no cap: round 8 drew it at most 704, the width System
  Settings caps its own form at, until Lee, seeing it live on 21 October:
  "why isnt the settings content dynamically sizing to the width? its weird
  to have a large wide margin on the rigth when the window is widened". At
  any width the controls keep their own widths against the card's right and
  the labels take what's left, wrapping before a control moves. At the
  narrowest window, a column of 476, every General row that needs
  something wraps its line beside its button, the plugin's beside Show
  Windows included. The page scrolls as one, as the window's other pages scroll, its toolbar's
  scroll edge hidden as theirs is. Rows sit on the ask cards' raise, radius
  14, split by the system's separator, half a point, 10 in from both ends,
  one box deep: rows of SitRep's own at the form's metrics, not SwiftUI's
  grouped Form, whose sections draw their own fill and insets, scroll on
  their own and draw nothing as a still. A row's label is 13, its line
  under it 11 in the secondary colour; a row is at least 52 tall with a
  line, 38 without, its words and its control 10 in from the card's edges,
  and a line wraps, growing the row, before its control gives up any width.
  The controls are the system's, never redrawn, each at the regular size
  and its own width against the card's right: segmented controls, their
  segments equal, as SwiftUI's picker sets them (Meniscus · Card is 155,
  where Paper drew 160: its widths were Inter's, and the control's are SF's);
  a pop-up as wide as its widest choice, as every Mac pop-up is; bordered
  push buttons and a pull-down; and the mini switch, 36 by 16, as the HIG
  gives a grouped form. Orange stays for needs you, so it appears only inside the pictures
  and the glyph.
- **What stays on screen**, named for the choice it makes, true for all
  three, Nothing included (Lee's alternative, if he prefers it later: "Show
  on screen"). One card, opening on the **Show row**, set as System
  Settings sets its Appearance row on macOS 26, measured from a capture of
  it (round 9, 21 October 2026). Round 8 put three large pictures over the
  card, filling the column; once the column filled the page they grew with
  the window, 385 by 248 each in a window 1591 wide, and Lee pointed at
  Appearance instead: "I think maybe we should change what that looks
  like … and that would help solve this problem". Show is the row's label,
  at a label's place at its top, as Appearance's is; at its right, against
  the card's, three pictures, 67 by 44 at radius 5, 15 apart, the last
  13.5 in from the card's edge, at any width: the notch and its light,
  the strip as it stands at Length Grows, its column curving back into the
  edge in the strip's own S and its rings in the panel's order, or only the
  menu bar's glyph, lit. Each is named under it, 11, 4.5 below it. The one
  chosen is ringed in the accent, 3 wide past a gap of the card's raise,
  0.5, with no shadow, its name semibold in the label colour. A picture
  not chosen stands on the soft shadow Appearance's unchosen thumbnails
  stand on, measured from the same capture: black, darkest at the edge,
  where it takes 14% off the card, gone 4 out, alike on every side, so
  with no offset; drawn as black at 30% blurred 2. Its name is regular in
  the secondary colour. Round 9 drew a hairline of white at 15% there
  instead, which Lee saw live as "a very thin white border or ring".
  The row is 86 tall, its pictures' ring 10 from its top. A click chooses
  one; it is the menu's Show. At their size, the pictures keep to what
  reads: the strip's rings drawn no finer than half a point, and Nothing's
  menu bar seen closer, from its right end, until the glyph's housing
  stands 5 tall, where its line is still a pixel. The
  pictures are a fixed sample, one needs you and the notch lit, and
  nothing in them moves, under the pointer or not (Lee, 21 October 2026,
  of the notch's tongue reaching for the pointer and the strip's rings
  turning under it: "This looks stupid… Remove the animation from these
  highlights"). Nor does the row answer the pointer at all: a picture
  changes only as it is chosen. Round 9 lifted a picture's edge and its
  name under the pointer, which Appearance does not (Lee, 22 October 2026:
  "in Mac settings, hovering an item doesn't actually hover in the boxes
  for appearance. Auto light and dark doesn't change the appearance at
  all, actually").
- **The rows under Show**, in the same card, are the ones that apply to the
  choice, in this order. They change at once, always, with no motion: as
  the choice changes, or Length with Max, the rows arrive and leave and the
  card takes its new height in the frame the tiles change in (Lee, 22
  October 2026, of the system's transition there: "the animation on the
  panel when switching the notch mode is a bit jarring"):
  - **Notch:** Edge, Left or Right ("or drag it across the middle");
    Display, the main one unless another is chosen; Style, Meniscus or Card;
    Material; Reduce motion.
  - **Strip:** Edge; Display; Length, Grows or Full ("grows with what's on
    it, or runs the screen's height"); Max, only at Grows, a slider 160
    wide whose right end is Full ("how long it grows"); Material; Reduce
    motion.
  - **Nothing:** none; the card is the Show row alone, and Show has a line
    under it, as a row's line is set, saying the menu and the SitRep window
    carry the board. Under the notch or the strip, Show has no line.

  Material is Black or Glass, for the notch and the strip alike, Black by
  default, from macOS 26 (before it, Black and no row). Reduce motion is
  off, its line saying SitRep follows the Mac's own setting either way
  (Lee, 18 October 2026: "One thing we might want to ship... is the ability
  to reduce motion").
- **Notifications** opens on a corner of the desktop, drawn by SitRep: the
  wallpaper, the see-through menu bar with the glyph lit and a clock that
  tells the time now in the menu bar's own form, a minute at a time, a
  Claude window behind, and the banner a new ask sends where macOS puts it,
  with SitRep's own icon. Its words are a sample, as drawn. It fills the
  column at 150 tall, nothing in it stretched or scaled. Wider than its
  drawing's 704, the wallpaper and the menu bar run on, the menu bar's
  items and the banner keeping to its right and the window behind to its
  left, 28 in. Narrower, it crops at its left, keeping its right, where the
  clock and the banner are, which the picture is there to show (spec round
  8 had it cropping at its right; at the narrowest column that dropped the
  clock and most of the banner). Under
  it, its caption and Send Test, a push button, which sends what the test
  always has: a real notification, its click jumping as any would. Then Notify me of a new ask, off by
  default, its line "Silent; a click on it jumps to the session"; and
  macOS's own answer, "Allowed by macOS, as banners", with Notification
  Settings… for SitRep's page in System Settings.
- **General:** first, "Your turn folds after", "Older ones fold into one
  line, which opens in place", a pop-up at its own width of An hour, the
  default, Four hours, Today or Never: how long a your-turn row stays on the
  card, and in the SitRep window's sidebar, before it folds into "N earlier"
  (see "The sections", under "The notch and its panel", and "The SitRep
  window"), measured from its turn's end, "Today" folding what
  ended before local midnight and "Never" folding nothing. It is in General,
  not under What stays on screen, as that card is the Show row alone at
  Nothing and the period governs the SitRep window's sidebar too (22
  October 2026). It is saved with the rest of what Lee sets beyond the edge, under
  "app", and the card and the sidebar refold as it changes. Then the Claude Code plugin,
  "Puts each Claude Code session on the board", up to date; Open at login;
  and the leave to control Ghostty,
  worded as macOS words a permission, by what SitRep can do with it: "Bring
  a session's Ghostty window to the front", "So a click on a session jumps
  to it". No row carries an icon. The plugin's folder, its version and its
  windows are gone from it: the version is About SitRep's, and the windows come back only when
  some need reloading. Update automatically and Check Now come with the
  first public release.
- **A dot when it's fine, a button when it's yours.** Each row says its state
  where its control goes. All well, that is a green dot, 7, and a word, Up
  to date or Allowed, in the secondary colour, with nothing to press. When
  something wants Lee, the words move into the row's 11-point line and say
  what is wrong, and a push button at its own width takes him to the fix,
  its ellipsis saying it opens somewhere else. No blue
  words and no ↗: blue is left to the switches, the menu's highlight and
  the chosen picture.
  - **Windows on an older plugin:** "Updated to 0.2.0. 3 windows run 0.1.0
    until /reload-plugins", and Show Windows, a pull-down listing each by
    the menu's words for it, its project and session, a click jumping to
    it. Once every window runs the new one, the row is up to date again.
  - **A plugin that failed or can't be found:** the line says what failed,
    in the menu's words, with no dot. A button comes only where SitRep has
    something to do about it; it has none today, as it looks again after
    trouble by itself.
  - **Ghostty not allowed:** "Not allowed, so a click on a session can't
    reach its window", with Open System Settings… for Privacy & Security ›
    Automation. Before macOS has asked, SitRep is not listed there, so where
    it can tell, the button is Allow…, which brings up macOS's own prompt.
  - **Banners off in macOS:** Notify me of a new ask keeps the state Lee
    left it in but greys, "Can't while macOS stops it; the notch swells and
    lights instead", and macOS's row reads "Not allowed by macOS", "Turn
    SitRep on in System Settings › Notifications", with Notification
    Settings….
  - **Waiting on Lee's approval to open at login:** the switch gives way to
    Login Items Settings….

  What macOS says is read as the page comes into sight, showing in the
  SitRep window while the window is key: each time that window comes
  forward on it, as Lee may have changed it in System Settings, and once
  as the window opens on it. About SitRep, or any other window, coming
  forward reads nothing.
- **How the notch moves is not a setting.** It ships fixed (see "The app
  ships these values fixed", under "The notch and its panel"). A first
  drawing had a Feel pane with the prototype's dials; Lee took it out.
- **Borrowed**, from Lee's saved references: Dockset's native controls in a
  styled frame, a live picture leading each step, and leaves named by what
  they give.

### About SitRep

Who and what version, where a Mac keeps it: a small window of SitRep's own,
drawn in Paper's "Settings in the window" (round 7, 21 October 2026), laid
out as every app's About is. It is set in SitRep's own window, not AppKit's
standard About panel, which draws its icon smaller.
- **Down its middle:** the app icon at 112, as macOS renders it; SitRep in
  the system's bold; "Version 0.2.0", the bundle's short version, which the
  plugin shares, as the app and its plugin are one release and never part;
  then "The board for your Claude Code sessions", and "Made by Lee Overy",
  where a Mac app's copyright line goes.
- **Nothing to change, and nothing more in it:** no title, no links, no
  licences, no update button; Check for Updates… stays in the menu. Only its
  close button is live, and it or ⌘W shuts it. It opens centred, in the
  upper part of the screen, on the Space Lee is on.
- **It opens from the menu's header**, which takes the menu's own highlight
  under the pointer, as any item does, and a click on it opens the window
  from anywhere. To VoiceOver the header is one button, "About SitRep". It is not in the app menu: an accessory app never shows
  its main menu.

### The icon

SitRep's app icon and its menu bar glyph, drawn in Paper's "Icon and logo"
(surfaces round 6, 17 October 2026). Three marks were drawn: the edge, the
notch's light alone, and the band's ◆. Lee picked the edge for the icon and
the light's glyph for the menu bar.
- **The app icon is the edge:** the icon's own left edge is the screen's,
  a black bezel down it, and the notch pours from it with its light on, as
  the notch looks when something waits. The rest is a dark desktop. It is
  the one mark no other app could have, and it shows Lee the thing on the
  screen's edge.
  - **Drawn as macOS 26 draws icons**: a continuous-corner body, built in
    Icon Composer from three layers, the desktop, the bezel and notch, and
    the light, in Liquid Glass. macOS makes the dark, clear and tinted icons
    from them; in clear and tinted the light turns white or takes the tint,
    the only places it gives up its orange.
  - **The light is a picture, not a state.** It is always on in the icon,
    and the icon never changes; the menu bar glyph says needs you.
  - **Where it is seen**, with no Dock icon: the notification a new ask
    sends, the menu's header at 30, About SitRep at 112, Finder, Login Items
    and Spotlight. It holds down to 38; by 16 the light is a pixel.
- **The menu bar glyph is the light**, in its housing: a rounded outline 13
  points tall in an 18-point box, a 1.3-point line, as SF Symbols' regular.
  - **At rest** it is a template image, its thin bar unlit, so macOS draws
    it in the menu bar's ink on any wallpaper.
  - **While anything needs Lee**, SitRep swaps in a second image whose bar
    is lit orange. The glyph itself is the state, with no dot beside it.
- **The name is set, not drawn:** SitRep in the system's semibold, as the
  menu's header sets it, and in its bold in About SitRep. There is no wordmark; the README pairs the icon
  and the name.

The boards for rounds 4 and 5 still show round 4's placeholder.

### The jump

**Terminal drivers**, decided with Lee on 16 October 2026 and built on 19
October 2026 (stage 3, step 5). The jump stays in the CLI, in TypeScript,
in two layers:
- **a driver per terminal app**, Ghostty's the one built (`cli/ghostty.ts`:
  steps 3 and 4, every behaviour as it was): it recognises its windows, by
  the `$TERM_PROGRAM` in the heartbeat's `where` outside tmux and by its
  program among the tmux client's ancestors under it, finds the window on a
  device, and brings it forward;
- **one tmux layer**, shared by every driver (`cli/tmux.ts`): which clients
  show a pane, and selecting the pane's tmux window where none does (step
  2). So tmux or not works for any terminal.

A driver declares what it can do beyond bringing a window forward, which
every driver must: select a tab or a split, and show a session's state, in a
tab's title or by OSC 7501. They are declared in the driver's shape and
built for none: Ghostty's declares none yet. A terminal with no driver still
has its sessions shown, and a click on one brings that terminal app forward
(step 2). Other drivers, and Ghostty's tabs and splits, stay parked, and the
shape allows them. A jump made in Swift, in the app, stays parked too.

1. Each Claude window records, in its heartbeat, the terminal device it is
   on, the terminal program (`$TERM_PROGRAM`), and its tmux socket and pane
   when it runs in tmux, worked out once as it attaches. A process Claude
   Code starts has no terminal of its own (`ps` gives `??`, live), so the
   mod runs a small shell walk up the processes from there to the first
   with one, which is Claude Code's. A walk that finds none leaves the
   device out and says so in the debug log; the window attaches all the
   same.
2. A click finds the places that can show the session, each a terminal app of
   this Mac and the device of its window, the session's windows in turn: the
   one that needs Lee first, else the one active last (below). Without tmux it
   is Claude's own device, when its `$TERM_PROGRAM` names an app sitrep knows;
   an app with no driver is brought forward whole, so a window in one counts
   without knowing its device. With tmux it is each client tmux lists whose
   current window is the pane's window and which descends from a terminal app
   of this Mac, each device once; where no such client shows it, each such
   client attached to a tmux session holding the pane's window, which a select
   will make show it (below). `list-panes -a` gives each pane's window and
   tmux session, a pane once for each session its window is in, and
   `list-clients` each client's current window and session, all by tmux's ids;
   a window keeps its id in every session. One `ps` snapshot settles each
   client's app, the nearest app among its ancestors: a Ghostty window's
   client runs `tmux < zsh < login < ghostty`, a phone's or iPad's `tmux < zsh
   < mosh-server`, one over ssh from another Mac `sshd` (all checked live, 13
   October; the terminal's name, `xterm-ghostty`, would count the ssh one
   too), and neither of the last two descends from an app. tmux and `ps` each
   get 2 seconds; one that cannot start, fails or does not answer shows
   nothing, so `list --json` never fails or hangs over them. Lee's tmux
   sessions are one window each, so for Lee every attached Ghostty window
   shows its pane already. A jump that could not tell, tmux or `ps` giving no
   answer in time, says so rather than calling the session off screen.

   `list --json`'s `onScreen` says whether a jump can reach the session: a
   place shows it, or a select would make one show it. Its name and `v` stay
   as they were before the select (19 October 2026), so a reader that took
   `true` to mean a jump can reach it reads it as before. `list` selects
   nothing, and knocks on nothing.

   **Selecting the pane's window** (19 October 2026). Where no client a jump
   can reach has the pane's tmux window current, the tmux layer makes it
   current in the tmux session that client is attached to, so it shows the
   pane, and the client's app brings its window forward:
   `tmux -S <socket> select-window -t <session>:<window>`, by tmux's ids
   (`$3:@45`). Ids, as tmux matches a name by its start or as a pattern, and
   an id never changes; the session named, as a window alone goes to
   whichever of its sessions tmux picks. So grouped and linked sessions need
   nothing more: the select is made in the client's own session, and the
   others of its group, or the other sessions the window is linked into,
   keep their current window. Checked on a private tmux 3.7c server the same
   day: a select in one session of a group left the other's current window
   as it was, a linked window was made current in the session it was linked
   into, and a session not holding the window answered `can't find window:
   @1`, exiting 1. The phone showing the pane does not stop a select: it is
   no client a jump can reach. A pane whose window no reachable client's
   session holds has nothing selected, and is off screen: opening a window
   for it is stage 6.

   The select runs only in a jump, after tmux, `ps` and the front are read
   and before the place's app is asked anything, within the 2 seconds
   tmux's reads have, and once a jump however many places need it, so one
   that hangs costs its 2 seconds once. Nothing selected is put back: a
   select made for a device whose terminal then does not answer, or in a
   jump that is refused in the end, leaves that tmux session on the pane's
   window, which is where Lee was going.

   **A place that fails gives way to the next** (19 October 2026, from
   review): a select tmux does not make, a window that does not answer, an
   app with no window open, or one that cannot be asked (Ghostty not
   answering in time, or macOS refusing sitrep control of it), and the next
   place is tried, another client, the next window, another app. An app
   with no window open, or that cannot be asked, is passed over at its
   places after, so a Ghostty not answering costs its 5 seconds once. Only
   once no place is left is the jump refused, in the words of what stopped
   the first place, the one most wanted: `Dashboard redesign is in a tmux
   window no terminal shows, and tmux would not select it: can't find
   window: @45`, or `… and tmux gave no answer when asked to select it.`;
   Ghostty's own words for a Ghostty that cannot be asked; off screen for
   an app with no window open; and, for a window that did not answer, every
   device whose window did not. So a session in one Ghostty window is
   refused exactly as before.

   **A terminal with no driver** (19 October 2026) is brought forward as an
   app, by `open` within 2 seconds, and nothing more: no knock, no watch of
   the front, no select beyond the tmux layer's. It is never launched:
   `open` launches an app that is not running, so it runs only for one
   running. Outside tmux the app is told by its `$TERM_PROGRAM`, from a
   table, which a program started from another terminal's shell inherits
   (an IDE started from Terminal), so it is opened by its bundle id (`open
   -b`) only once `lsappinfo find bundleid=<id>` names it running, within
   the same 2 seconds; it prints the app's ASN, or an empty line for none
   (live, 19 October 2026). Not running, its place does not answer.

   | `$TERM_PROGRAM` | App | Bundle id |
   |---|---|---|
   | `Apple_Terminal` | Terminal | `com.apple.Terminal` |
   | `iTerm.app` | iTerm2 | `com.googlecode.iterm2` |
   | `WezTerm` | WezTerm | `com.github.wez.wezterm` |
   | `WarpTerminal` | Warp | `dev.warp.Warp-Stable`, else `dev.warp.Warp-Preview`, whichever runs |

   Only Terminal's is checked on this Mac, which has no other. kitty and
   Alacritty set no `$TERM_PROGRAM` of their own, so outside tmux they are
   not told; VS Code's, `vscode`, is Cursor's too, and would bring forward
   the wrong app. A window in one needs no device: the app comes forward
   whole. Under tmux, which sets its own, the app is the bundle the
   client's nearest app ancestor runs inside, the outermost
   (`/Applications/Visual Studio Code.app` for its helper's shells), opened
   by its path (`open -a`) with no question to lsappinfo, as its program
   is running, among the client's ancestors in `ps`; a driver's program
   among the ancestors, the nearer, is that driver's. One helper outside
   its bundle is known: iTerm2's shells, since 3.4, run under
   `~/Library/Application Support/iTerm2/iTermServer-<version>`, which is
   iTerm2's, and, as it outlives iTerm2 quitting, is opened by iTerm2's
   bundle id once found running (unchecked on this Mac, which has no
   iTerm2). `open` sends a running app the reopen event, which makes one
   with no window open one; that does not happen here, as a live window of
   the session is in the app. An app that does not come forward is passed
   over for the next place, as a Ghostty device that does not answer is,
   and the refusal names the apps tried (`… but no Terminal or Ghostty
   window there answered.`, or, with no device, `… shows in iTerm2, which
   did not come forward.`).

   **Of two windows on one session** the jump goes to the one that needs
   Lee, its heartbeat's state a permission prompt or a question, else the
   one active last (19 October 2026; see "Two windows are two sessions"). A
   working window is active now, however long ago its turn began, since
   `state.since` is its turn's start: one working since 9:00 is more active
   than one whose turn ended at 10:00. So the order is: needs Lee; then
   working; then on its own work, as the session's row prefers it, so the
   jump goes to the window the row describes, though another's turn ended
   later (22 October 2026); then the rest, on their turn or saying no state;
   within each, the latest `state.since` (the later stop, the turn Lee
   started last, the later end of a turn), then the latest `attachedAt`. A
   window saying no
   state, as one on a release from before heartbeats said it, goes with
   those on their turn, by its attach, which is what a state's start is
   before any turn. Each window's places are tried before the next window's,
   so one that needs Lee where no terminal shows it gives way to the other.
   The jump no longer goes by the window that delivers the session's inbox,
   which keeps its own rule, the one attached longest.
3. Ghostty's driver finds the Ghostty window on a device by a knock. Ghostty's
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
   - Each question to Ghostty, each Apple Event a program sends, waits at
     most 5 seconds: AppleScript's `with timeout` holds for each event, not
     for the program around them. With the screen locked, Ghostty still answers a trivial question at once but nothing
     about its terminals, and AppleScript's own limit is two minutes
     (found live, 13 October). The jump then refuses in plain words; the
     listing, or the focus of a remembered terminal, comes before any
     knock, so a locked screen leaves nothing on a marker.
   - Each device is tried in turn until one answers: first the terminal
     remembered for it, then a knock.

   **Each device's terminal is remembered** (14 October 2026), so a jump
   after the first neither lists nor knocks. A knock that answers adds a
   line naming the device and the terminal's UUID to
   `ghostty-terminals.jsonl` in sitrep's folder, beside `projects/`, which
   is all the mod and the CLI ever list there, so nothing reading the board
   meets it. The CLI's files are only appended to, so the last line for a
   device wins, and a torn or broken line is skipped. A later jump focuses
   that terminal by its UUID, within the same 5 seconds, looking it up
   first (`terminals whose id is`, about 15ms more), so a terminal gone is
   never taken for one focused, whatever Ghostty's `focus` makes of a UUID
   it does not know. Why it is safe: a Ghostty terminal keeps its device
   for its life, so a UUID that still names a terminal names the one on
   that device; a device taken by a new terminal means the old one is
   gone, so its UUID finds nothing, and the knock runs and remembers the
   new one. Any failure but a timeout falls back to the knock in the same
   way; a timeout refuses, as for any question to Ghostty. The one gap,
   accepted: a surface Ghostty keeps open after its shell exits ("wait
   after command") while its device goes to a new terminal. It is rare,
   and Lee's Ghostty closes a surface as its shell exits. `ps` stays all
   the same: a device must still be a Ghostty window's.

   The listing a knock needs runs only once a device needs a knock, after
   tmux and `ps` have answered, and once for every device knocked on. A
   jump that focuses a remembered terminal, finds the session off screen, or
   cannot tell, asks Ghostty for no listing. First built to start the
   listing beside `ps` when no device that might show the session had a
   terminal remembered, it was dropped in review the same day: a jump
   ending off screen or unknown left that osascript running, keeping the
   CLI up for as long as 5 seconds, and it could raise macOS's prompt for
   leave to control Ghostty on a jump that needed nothing from it. It
   saved about 65ms, only on a first jump, which a remembered terminal
   makes rare.
4. sitrep focuses that terminal (Ghostty's `focus`). With macOS's "switch to
   a Space with open windows" on, macOS goes to its Space. Tried live: from
   Space 9 to the Fumi window on Space 12, then back to Space 1. It needs no
   Accessibility permission and no window manager.

   **The front kept** (14 October 2026). With another app in front as the
   jump begins (Lee clicked the desktop, so Finder), and the target's
   Space last showing that app in front, macOS hands the front back to it
   once its slide ends. Logged live, from the jump's end: at about 0.2s
   Ghostty is in front, its front window's focused terminal still the old
   one, the Space sliding; at about 0.5s Finder is in front again, Ghostty's
   focused terminal now the target. With Ghostty already in front as the
   jump began, it never happened (two tries, the focus held for 3
   seconds). So the jump reads which app is in front as it begins, beside
   tmux and `ps`, which outlast it, and before any focus, so it never reads
   Ghostty brought forward by the jump itself: `lsappinfo front`, then the
   bundle id of the app it names, each within 2 seconds. An ASN names one
   app for its whole life, so each one's bundle id is kept for the jump,
   and a look after the first runs only `lsappinfo front` unless a new app
   has come to the front (review, 14 October 2026). With Ghostty there,
   nothing more. Otherwise, once the
   terminal is focused, it looks every 50ms for up to a second, twice the
   half second at which the hand-back came in all three logged: at the
   first look finding another app in front after Ghostty, it brings
   Ghostty forward, once, and stops. Ghostty never in front by the end is
   no hand-back, and nothing is brought forward: the focus may have shown
   nothing, Ghostty hidden or its window minimised, and bringing it forward
   then could make it open a new window (below). A second, and no longer:
   a jump that sees no hand-back keeps the app waiting that long, and a
   switch Lee makes within it would be undone. It was 1.5 seconds,
   and brought Ghostty forward when it never came forward too, until the
   review the same day. Bringing Ghostty forward is enough, since its
   focused terminal is the target by then; focusing again after the
   hand-back held, live. Nothing in the watch fails the jump, and
   lsappinfo giving no answer as the jump begins means no watch.

   It brings Ghostty forward with `open -b com.mitchellh.ghostty`, within
   2 seconds. First built with osascript telling Ghostty to `activate`, it
   was run live the same day: a jump to Space 6 with Finder in front still
   landed unfocused, the window taking focus about half a second later.
   The watch saw the hand-back within about 75ms; the `activate` took
   202–354ms, where `open` takes 68–98ms, going through LaunchServices with
   no Apple Event, so it needs no leave to control Ghostty either. `open`
   is safe here because it runs only on a hand-back, Ghostty seen in front
   after the focus and then another app: Ghostty is running, so `open`
   never launches it, and its window was just in front, so the reopen
   event `open` sends never makes a new one. With no window showing, that
   event can make Ghostty open one, which is why Ghostty never coming
   forward brings nothing. `lsappinfo info -only bundleid front` prints
   nothing, so a new app's bundle id takes a second run. Run live with
   `open`: the window sat unfocused for 100–200ms at most, as Lee saw it, and the CLI ended at 0.83 seconds,
   the watch stopping at the hand-back. The hand-back itself is macOS's,
   and nothing a jump can call stops it.

   **What a jump costs**, measured live on 14 October 2026 with 24 Ghostty
   terminals open. Before: about 0.6s. tmux's two lists took 10ms, beside
   `ps` at 75ms; then the listing 230–640ms, the knock's write 1ms, the
   find and focus 210–315ms, and the put-back 1ms. osascript's own start
   is about 70ms (`get frontmost` takes 69ms), and Ghostty is slow to
   answer (counting its terminals takes 154ms, a focus 200–350ms), so the
   time is Ghostty's, not the programs' starts; `lsappinfo front` takes
   11ms. After, run live the same day: a jump to a remembered terminal
   takes 265–360ms, tmux and `ps` then one focus. A first jump costs what
   every jump did before, tmux and `ps`, then the listing, then the find
   and focus, about 0.6s, now that the listing waits for `ps`; one run
   live, from Finder, with the first `activate` and the 1.5-second watch,
   ended at 1.8 seconds, the window forward long before. With another app
   in front, the CLI stays up to a second more, watching, the window
   already forward.

Why tmux comes in at all: walking up the processes never reaches the window.
Claude's chain is `launchd → tmux server → zsh → claude`, the window's is
`Ghostty → login → zsh → tmux attach`, and the two meet only inside tmux,
which is what lets a tmux session outlive a crash and be picked up from the phone.
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
   shell; and `list --json` says whether each session is on screen, so the
   panel knows what to offer. Built 13 October 2026, reviewed at xhigh,
   and run live twice with Lee watching: Finder in front, to the Fumi
   window on its Space and back, about half a second a jump, every
   directory as it was. Stages 1 and 2 landed together (kit-config #2);
   after a `/reload-plugins`, a jump on real sessions went from Finder to the
   Fumi window's Space and back, half a second each way, every directory
   as it was (13 October 2026).
3. **The app**, and what the plugin gives it: the words and the versions,
   the live feed, the jump's drivers, the notch and its panel, the strip,
   the menu bar item, the macOS notification, Settings, the SitRep window,
   and installing the plugin. It is a `.app` of its own (no
   Dock icon): a menu bar item lives only as long as the process that owns it,
   and macOS sends notifications only from an app. Its source sits in the
   repository beside the plugin. In order, rewritten on 19 October 2026 once
   every surface was designed and the spikes felt (Lee: "get this thing
   built now"):
   1. **A bare app**, built locally, proving a macOS notification, the leave
      to control Ghostty, and starting at login. Built 14 October 2026
      (below).
   2. **The spikes**, felt on the display over sample data (PR #5): the
      notch, Meniscus and the card; the strip; Material, Reduce motion, and
      nothing over full screen. The SitRep window has none: it is an
      ordinary window, its design taken as it stands, and its hard part,
      answering, is plumbing a spike over sample data would not test. PR #5
      closes unmerged once the build has taken its model.
   3. **The words and the versions**, in the plugin (see "Words" and
      "Versions side by side"):
      - core's upgraders, one per past version, every line keeping its `v`;
      - the heartbeat saying its window's version, so the menu can list the
        windows to reload;
      - the renames: on disk, `works/` to `sessions/` and `work.json` to
        `session.json`, read under both names and written under the new,
        the old files moved once no window runs an old version; in the mod
        and Claude's tools, work to session, the pane's ASKS, NOTES and
        RESOLVED, and "finish this session"; in the CLI, `--work` to
        `--session`.

      Built 19 October 2026 (PR #7), each part reviewed twice and the
      folder's rules once more after their fixes; the move, the reads in
      their order and the changeover's costs are under "Storage".
   4. **The live feed**, in the plugin, two PRs:
      - **each window's state in its heartbeat**, written at once: stage 5
        below, brought forward, since the rows and the rings need it. With
        the state, what the row shows of it: the tool running and its path;
        the permission prompt's tool and command; the question, and how
        many there are; when the turn began or ended. Built 19 October
        2026: how the mod hears it is under "A session's state", and the
        heartbeat's `state` under "Storage";
      - **`sitrep watch`** (under "One engine, two front ends"), with what
        is new and presence expiry worked out in core. Built 19 October
        2026: the board as every surface shows it, a line each time it
        changes, each session's state and its rows in their order decided
        in core, what is new by row, the windows with their versions, and
        a look again the moment a heartbeat goes stale.

      The clone is the live plugin: each is proven by the CLI run live over
      a state folder of its own, and reaches Lee's windows as it merges, at
      their next `/reload-plugins`.
   5. **The jump's two layers**, in the CLI (see "The jump"):
      - a driver per terminal, Ghostty's from today's jump;
      - one tmux layer under every driver, which also selects the pane's
        tmux window, so a pane no client shows still has a jump;
      - a terminal with no driver brought forward as an app;
      - of two windows on one session, the jump goes to the one that needs
        Lee, else the one active last.

      Built 19 October 2026, in the test world, never with a real jump, and
      revised after two reviews the same day (a failing place gives way to the
      next, an app is never launched, a working window counts as active now,
      iTerm2's server is iTerm2's): Ghostty's driver is the jump as it was,
      moved whole, its tests unchanged but for those the new rules change (a
      tmux session showing another of its windows is now selected, not off
      screen; a window in iTerm2 is brought forward, not off screen; the
      deliverer is no longer tried first). The select's form was checked on a
      private tmux server; the rest waits on Lee's live try.
   6. **The edge, for real**, in the app, two PRs. Each takes the spike's
      model with its recorded tests, the code brought to the build's bar,
      the spike's scaffolding left behind (the Simulate items, the sample
      rows, the Max menu).
      - **The notch and its panel** over `sitrep watch`:
        - Meniscus and the card, and the rows, scrolling past the panel's
          length;
        - a click jumping, and the swell for what `watch` says is new;
        - the left or right edge on the chosen display, and the drag along
          it and across;
        - Material, Reduce motion, and nothing over full screen;
        - the last board kept, marked stale, when `watch` stops.

        The panel closing as the pointer leaves gets a test of its own: on
        the spike it once stayed open.
      - **The strip** over the same feed: Grows and Full, Max, the two
        counts and their tabs' scrolling rows, a click jumping, the drag,
        either edge.

      The model came over first, on its own (19 October 2026): every
      recorded test passing frame for frame, no number of the feel
      changed. With the dials gone, what the spike worked out from their
      furthest settings is worked out from Lee's, on purpose:
      - the window's depth from the screen's edge: 422 for the notch, from
        Hold's 35 at Bounce 0.90, where the spike's 434 came from Hold's 44
        at Bounce 1; and 414 for the strip, where the spike's was 458;
      - the notch's home along the edge, kept where its deepest swell fits
        inside the band: Swell's 25, 92 either side, where the spike kept
        the Swell dial's 30, 107 either side.

      What Lee sets is one value the app saves, read leniently; Max is kept
      as how far along its slider it is, never in marks, and its top is
      Full, with or without the hairline. One fix came with it: a shape
      springing a little past the band's length stays on the band's middle,
      where the spike jumped to the screen's.

      The notch and its panel were built on 20 October 2026, never run on
      the display, every recorded test passing frame for frame. What the
      build settled:
      - **Core's rows, as given.** The panel lists `watch`'s rows in their
        order, the hairline under the needs you that lead, and its head is
        core's counts; the spike's sort went with the strip's PR. The
        app maps a line to the panel's rows in one place (`PanelBoard`),
        tested on the first line the real `watch` printed over a board
        seeded in a scratch folder of its own.
      - **Its swell is `new`'s alone.** Something needing Lee with nothing
        new, as on every run's first line, takes the notch to 15 × 124 and
        lights it with no swell and no flash.
      - **Stale**, its head keeps its count of what needs Lee and says in
        the count's place when the board was last known current, "as of
        12:04", and nothing on it is new again: no swell, no wash. Before
        the first line it says "Looking for sessions…", with `watch` down
        before any, "SitRep can't read the board", and in a SitRep with no
        plugin to run, the trouble that left it none (step 9).
      - **Frames run only while something moves**: the notch, a row
        folding, the ghost, a new row's wash in glass. A pointer resting
        anywhere, by the notch or on the still panel, costs nothing; the
        open panel's times are drawn again as they change, each minute.
      - **The spike's panel that stayed open**, found in the tests: frames
        stop while nothing moves, and a move of the pointer woke them only
        near the notch or over the panel as drawn. Under reduced motion,
        rows going from under a still pointer leave the panel out with
        nothing moving, so no move away reached the model. Every move wakes
        them while the panel is out.
      - **Hidden**, over a full-screen app or with Nothing chosen, nothing
        of SitRep's shows, the caption and the ghost included, and a drag
        under way ends where it began. The notch's time runs on meanwhile:
        shown again, it is where it would have come to rest, with nothing
        left to play late.
      - **The click.** A row that jumps presses in (to 0.985, #1C1C20) and
        an arc spins in its time's place until the jump answers, 450ms at
        most, and then the panel drains: this design's "up to 450ms", where
        the prototypes always wait the whole 450. While it is pressed in a
        leave doesn't close the panel: it rings, and the panel stays out
        for the jump. A click elsewhere still closes it at once, as it
        always does. Only an open or opening panel takes a click, as in the
        prototypes, and none while a jump runs, from the panel, the menu or
        a banner, as the menu's works are disabled then; a row folding away
        takes none either. Once the jump has jumped, "Jumped to SitRep's
        window" shows 90ms into the drain, or as the jump answers if that is
        later, and never once its moment has passed. The CLI's answer names
        no place, so the caption names the row's project. It sits at the
        top of the notch's screen, centred, 22 under the menu bar, where the
        prototypes put it 22 under their stage's top, with no blur behind
        it. A jump refused leaves no caption, and its banner says why.
      - **Rows fold**, as the prototypes': while the panel is out, a new
        row unfolds over 260ms and fades in over 220, and a row gone folds
        away where it was, fading with its fold; under reduced motion a fold
        takes 120 and nothing fades in. The panel's length follows.
      - **The ghost.** Dragged past the screen's middle, the notch at rest
        shows on the other edge where it would land, in the panel's black
        at 0.3: in over 140ms, out over 140 as the drag comes back; let go,
        out over 420 as the notch grows into it, or over 200 on its own
        side. A press takes no hold of the notch from a drop across until
        it is home on the other edge, as the prototypes take none while it
        moves.
      - **The light's own refresh.** While anything needs Lee and the panel
        is in, the light breathes on a link of its own at 30Hz, with the
        notch's frames asleep. Under reduced motion the light holds still,
        mid-breath with its spots at home, as lights.js's `drawLive` holds
        it, a new ask a 540ms brighten in place of the 700ms one, and the
        link runs only while that brighten plays.
      - **Between frames.** A board, a press, a drag, a scroll or a click
        elsewhere first brings the notch up to now, so what it starts, a
        wash, a swell, a press, a flash, runs from the clock and never from
        the last frame's moment, minutes old once frames have slept; and
        frames woken after a sleep take no speed from the pointer's unseen
        move. A move wakes them from near the notch as well as to it, so a
        notch leaning toward the pointer sees it go. Every input steps the
        model, so the press, the drag and the rest act on one list in one
        place (`NotchRun`), and the model's clock never goes back. While
        frames run, the next one draws what the inputs between did. The
        pointer's speed is measured in its own time, each reading stamped
        as it was read, and one within 1ms of the last taking its place, as
        `trackPointer` does, so a frame between ticks reads the speed the
        ticks read. The light keeps a clock of its own, so it never steps
        back and never moves the notch's.
      - **A row's project** is named as the board names it, with core's
        letters for it, ready for the strip; and an away ask's second line
        is core's.

      The strip was built on 20 October 2026, over the same feed, never run
      on the display, every recorded test passing frame for frame. What the
      build settled:
      - **Core's rows, in core's order.** A mark is one of `watch`'s rows,
        its letters core's, and the spike's own sort is gone: the re-sort a
        second after the pointer leaves takes core's latest order. A new
        needs you moves in under the needs you core has above it, or first
        where core has none, and past its room into its count. The prototype
        put it after every needs you a window holds; the two differ only for
        a row whose time is older than one already there. Any other row new
        to the strip comes in as the marks re-sort
        at once, as the prototype's Too many brings them; a row that changed
        shows in place; a row gone fades where it is. Core never turns an
        ask into a turn in place: an ask answered goes, and its session's
        turn comes in.
      - **Its flash is `new`'s alone.** A needs you new to the strip but not
        on the line's `new`, as on a first or a resumed line, comes in with
        the rest, unflashed.
      - **The click**, on a mark or its tab, spins until the jump answers,
        450ms at most, as a panel row does, where the prototype always spins
        the whole 450; then the tab draws back, or the ring springs back
        out. Its arc fades in over 60ms as the spin starts, as the
        prototype's `.mk.jumping .arc` does, so a quick answer still shows
        it, and out over the mark's 240, as it fades in over 240 for a mark
        turning working. The ring, its glow and the letters' colour ease over
        240 and the pressed fill over 110, each on its own, in black and in
        glass. The caption is the panel's, over the strip's screen, once the
        spin is over. As the panel's, none is
        taken while a jump runs, from
        anywhere; an answer to an earlier click changes nothing; and the
        session jumped to is the one the strip pressed in. A click is a
        press and its mouse-up, as the prototype's is: a press on the strip,
        which may drag, or on an open tab, which only clicks. A mouse-up
        with no press the strip took behind it, refused or given up, is no
        click.
      - **The drag** is the notch's, at either length: a press on the strip
        moved more than 4 points. At Grows it carries the strip along the
        edge; at Full, which runs the screen's height, along nothing. Let go
        past the screen's middle, the strip goes to the other edge, its
        black showing there faintly meanwhile, as the notch's ghost does.
        What it leaves is saved as the notch's drag saves it: the edge, and
        at Grows the strip's centre as how far down the screen it sits,
        which the notch then takes. Only that is saved, for the strip and the
        notch alike, and onto the settings as they stand when it lands, at
        the swap for a drop across: what Lee changed in between, Show among
        it, stands. This replaces the spike's "at Full there is nothing to
        drag". The strip's prototype drags only along, with no
        lift, so the strip has none; nor has it a drag across, so the drop
        across plays its `moveEdge`, the edge control's: the strip drains
        into its edge over 170ms, its marks out in 90; at 200 it swaps
        edges, the tabs gone, and grows out of the other over 320, its marks
        back over 260; at 520 it takes the pointer again, and until then no
        press, click or hover, so a re-grab can't flip it under a live
        drag. Under reduced motion its old black fades as it swaps at once,
        the marks in over 160. Drained all the way, there is no black.
      - **Stale**, with no head to say it: before the first line the notch
        at rest's tab says "Looking for sessions…", and with `watch` down
        before any, "SitRep can't read the board". While the board is stale,
        each tab says when it was last known current, "as of 12:04", in its
        time's place, and the notch at rest's tab in its second line.
        Nothing on it is new again: no flash. A tab out as what it says
        changes, a row's words, its time going stale or the notch at rest's
        title, takes its new words and eases to their measure as a glide
        does, where the prototype keeps the old width and squeezes them;
        under reduced motion its outline cross-fades to the new size, as a
        glide's does. It takes them once, though one board changes both its
        row and what the board says of it. A count's tab keeps its size as
        its rows change, as the prototype's recording has it, and its rows
        say no time, so it keeps them as the board goes stale.
      - **Frames run only while something moves**, as the notch's: a tab
        pouring, a ring flashing, the strip crossing, the ghost. A pointer
        resting anywhere, on the strip or a still tab, costs nothing. A
        move wakes them while a press is held, a tab is out, the strip had
        the pointer, the last frame's pointer or this one is on the strip,
        or the window takes the mouse; so a flick off a parked pointer,
        frames already stopped, still reaches the model and the strip
        settles. An open tab's time is drawn again as it changes, on a timer
        at the next whole minute, in the run loop's common modes, so it
        ticks while a menu is open; while the board is stale, never.
      - **Between frames**, as the notch's. The strip has a run of its own
        (`StripRun`), beside the notch's. What the two keep alike, each
        holds once, in a part of its own (`RunBook`, in `EdgeRun.swift`):
        the clock that never goes back, the clicks and which is the latest,
        and what a frame showed for the drawing to show once. A board, Lee's
        settings, a press, a drag, a let-go, a scroll or a click elsewhere
        each steps the model first, its time run on while hidden, so what
        it dates, a flash or a press, runs from the clock, and a click lands
        on the strip as drawn: on a count whose rows the board changed since
        the last frame, the row under the pointer is the row the strip
        presses in. A board after a long idle flashes in full; frames woken
        after a sleep take no speed from the move they slept through; the
        pointer's speed is its own, each reading stamped as it was read.
        While frames run, the next one draws what the inputs between did,
        with what the frames showed latched for it: the edge swapped, from
        every frame, the ones run on while hidden too, so a drop across
        hidden before its swap still lands; and the drain a click's jump
        waits for, the panel going in or the strip's spin over, which the
        caption waits for in turn. That is latched only while a click waits
        on it, so a panel closing with no click, as the pointer leaves, is
        none.
      - **Hidden**, over a full-screen app or with Nothing chosen, the
        caption and the ghost go with it, and a drag under way ends where it
        began, nothing saved, the window letting clicks through; hidden as
        it crosses, it is on the other edge at once. Its time runs on, as
        the notch's. The ghost's timings are the notch's.
      - **Reduced motion** stills a working tab's title, in ink, as the
        prototype's CSS does, and caps every ease at 140ms; the rings still
        flash, the wash still fades and the arcs still turn, as there.
      - **Either edge.** The blacks go through the edge's mirror as the
        notch's do; the marks and the tabs' words are placed through it but
        never mirrored, a tab's words set against the strip.
      - **A tab's second line is core's**, an away ask's saying no window
        holds it, as the panel's row's is; and the wheel scrolls a count's
        rows 16 points a notch, as the panel's, where the spike's strip
        scrolled 10.
   7. **The menu bar item and Settings**, one PR: the native menu (see "The
      menu bar item"), the Settings window's three panes with Max as a
      slider, macOS notifications off by default with the switch to turn
      them on, and the icon.

      Built on 20 October 2026, never run on the display: the menu's and
      Settings' decisions in a part of their own with no AppKit or SwiftUI
      (`SitRepMenu`), tested, and the views over it thin. Settings' panes were
      drawn offscreen and read beside Paper's drawings; the menu cannot be,
      so only its images were. Round 7 replaced this Settings window and
      its panes with a page of the SitRep window (see "Settings"). What the
      build settled:
      - **One feed.** The menu's sessions are the panel's, from the board
        the edge reads (`PanelBoard`), in core's order with the panel's
        marks and its hairline, the first twelve of them; its heading the
        panel head's words, "4 need you · as of 12:04" while the board is
        stale. `sitrep list` is no longer read by the menu, nor the listing
        it kept.
      - **The rows**, each a native item: its title the row's first line,
        set as attributed text, its words in the menu's font and its subject
        in the system's mono, a question's "+2" after (since rows by session,
        a row's oldest line, and "+N" for its other lines in its place); core's second line as
        its subtitle; its time as its badge. A working row's words are in
        the secondary label colour, its arc fainter than the other marks;
        under the pointer the colour is taken off, through the menu
        delegate's `willHighlight`, so the highlight's own ink shows. An away
        row has no action, so macOS draws it disabled, dimming its dot with
        its words, its title in the disabled ink. An item with an attributed
        title shows no subtitle before macOS 15, so before it a row's title
        is plain, and before 14.4, which has no subtitles, the second line
        is its tooltip. The marks, the tick and the commands' symbols are
        each the item's 16-point image, the state column turned off.
      - **The header** is a view, not an item, so it never highlights: the
        app icon at 30, the name in semibold, the version, made once.
        Round 7 changed this: the header is now an item's view that takes
        the menu's own highlight under the pointer, and a click on it opens
        About SitRep (see "The menu bar item").
        "SitRep can't read the board" is an item with no action, its title
        set in the label colour so macOS does not dim it, the reason its
        subtitle, under the same rule for macOS before 15.
      - **Needs /reload-plugins** lists each window `watch` marks
        `needsReload`, the longest attached first, as "Project · Session",
        a click jumping to its session; two windows on one session are two
        items, though the jump reaches the session's.
      - **The menu is patched in place** as each board comes and as it
        opens, for Show changed in Settings: the menu as data, an entry to
        an item, each keyed by what it is (a row by its key, its session since
        rows by session), and between
        the menu as it shows and as it should, the items gone are taken
        out, those come put in, and those kept set again only where they
        changed (`MenuChanges`). So an open menu keeps the item under the
        pointer, highlighted, however often the board moves. While it is
        open the rows' times tick, each change setting the timer for the
        rows then showing.
      - **Open SitRep Window** and "N more…" open the SitRep window.
      - **The glyph** is drawn from the icon drawing's SVG: at rest a
        template; lit, its housing drawn in the ink of the bar it is drawn
        on, light or dark, its bar orange. It lights from the board's
        "needs you", kept while the board is stale.
      - **What Lee sets** is kept in one place (`Preferences`): the edge's
        settings, saved as one value as before, and beside them, under a
        key of their own and as leniently read, whether a new ask notifies
        (off) and the pane ⌘, opens. The menu's Show and every control in
        Settings save and the edge takes the change at once; a drag's move
        is saved there too, for Settings to show. Max's slider moves the
        strip as it is dragged and is saved once, as the drag ends. Settings
        closes on ⌘W and minimises on ⌘M, and its controls take Edit's
        keys, through the app's main menu.
      - **At the edge** takes Show's pictures as drawn, on the pane's own
        ground: the chosen one ringed in the accent, its light breathing on
        2.4 seconds, held still under reduced motion. Display lists the main
        display first, then the others by name, then the one chosen where
        it is neither (one not connected, or the one since made main), so
        the choice always shows. Max's slider runs from "Short" to "Full".
      - **Notifications.** A new ask is one of a line's `new` whose row is
        an ask, so a window's new stop sends none. None is sent while the
        switch is off, for a run's first line (the first run's among them,
        `LastBoard.isRunsFirst`), nor for a board gone stale, whose `new` was
        told as it came. A run's first line is its first whether or not it
        reads, so after one that does not, the next that reads notifies as
        usual, though it is still the run's first board, resumed, for the
        window to read again in full. Several are sent in core's order.
        Each names the ask's project and session from the
        board's projects, so an away ask's says them too, where its second
        line does not; its click jumps nowhere. Turning the switch on asks
        macOS for leave, unless Lee answered before. The switch's line says
        what tells Lee instead: the notch's swell, the strip's flash, or the
        menu bar's light with Nothing. Send sends the board's first row a
        window holds, which a click jumps to.
      - **General.** The plugin's version is the CLI's, from the board; its
        line says where it runs from (step 9 made it each case's: "Installed
        by SitRep", "From ~/Code/sitrep", "From GitHub, leeovery/sitrep"),
        how many windows run it, and how many need
        `/reload-plugins`, Show listing those; while the board is stale,
        only that SitRep can't read it, and since when, with no tick and no
        counts. Open at login is
        `SMAppService`, moved from the menu, as is the test banner, now
        Send. The leave to control Ghostty is read with
        `AEDeterminePermissionToAutomateTarget`, never asking Lee; macOS
        answers only while Ghostty runs. What macOS says is read again each
        time the window comes forward.
      - **The icon** is Icon Composer's format, `app/Icon/SitRep.icon`, its
        three layers the desktop, the bezel and notch, and the light (its
        halo clipped to the notch), from the drawing's SVG. `app/build`
        compiles it with `xcrun actool` into the bundle's `Assets.car`,
        which holds the icon's layers for the default, dark and tinted
        appearances, so macOS makes the dark, clear and tinted icons from
        them, and the `.icns` `actool` makes beside it for older lookups,
        every size to 1024 by `--standalone-icon-behavior all` (by default
        it stops at 256);
        the Info.plist takes `actool`'s keys, `CFBundleIconName` and
        `CFBundleIconFile`. `actool` exits 0 having compiled nothing, as for
        an icon it cannot find, so `app/build` stops when there is no
        `Assets.car`. It needs Xcode's first launch run once on the Mac
        (`xcodebuild -runFirstLaunch`); until Lee ran it, on 20 October
        2026, the app was to ship an `.icns` of the default look alone.
   8. **The SitRep window**, two PRs:
      - in the CLI, answering a yes or a choice, or ignoring any ask, into
        the session's inbox, which its window delivers, and finishing an
        away session, each with what the window shows of it ("on its way",
        "sent, and Claude has it"). This settles open question 4. Built 20
        October 2026, and run live over a state folder of its own, the
        window's mark written by hand, and two answers to one ask run at
        once, both landing and the second read void: `sitrep answer` and
        `sitrep finish`, each ask's `reply` in `board --json` and `watch`,
        `board --json`'s resolved asks, an ask Lee replied to waiting on Lee
        no more (on Lee's surfaces; on Claude's it waits until delivered),
        and one answer per item, which a pane's send keeps too (see "One
        engine, two front ends", "A session's state", "Ready to send" and
        "Delivery"). Nothing new on disk: the answer is a reply as the
        pane's letters are, which every window on today's layout delivers as
        it is, and the window's delivered mark is how the CLI hears it went
        in;
      - the window (see "The SitRep window"). Its "Answer in Claude ↗" jumps
        without answering mode, which waits on the mod hearing the app.

        Built 20 October 2026, never opened on the display: its key states
        drawn offscreen and read beside Paper's drawing, its decisions in a
        unit of their own (`WindowRun`, in `app/Sources/SitRepWindow`),
        tested on the lines the real CLI printed over a board seeded in a
        scratch folder. What the build settled:
        - **One `watch`.** The app's one `watch` feeds the edge and the
          window alike. The window lists `projects` in `watch`'s order and
          counts `head` as the panel does; a session's detail, its asks
          among it, is its `board --json`, read as it is picked, for each
          session of a project opened, again whenever `changed` names one
          shown, and every one shown on a resumed board, only while the
          window shows; of two reads of a session crossing, the one asked
          for last is taken. Until a read lands, a session picked again, or
          the window reopened on it, shows its board as last read, its asks
          among it; that first read lays the asks out afresh, washing
          nothing and keeping nothing closed, as Lee saw neither come nor
          go. A read that fails says why over what was read before, and
          keeps it. Minimised, it reads nothing; brought back, its page
          reads what it shows again.
        - **Its counts.** A project's orange count, and a project's
          session's "2 waiting", are its rows needing Lee, stops among them;
          Asks' "3 waiting" is the asks waiting on Lee, as `waiting` counts
          them.
        - **Quiet projects** are those `watch` carries with nothing open: no
          window, no ask waiting and nothing parked, as core folds a project
          into All projects' line. `list --json` carries no others either.
        - **It opens on** the first row needing Lee, `watch`'s oldest; with
          none, on the session picked last, kept across launches; with none
          of those on the board, the first listed. A pick gone from the
          board gives way to that. Opening it again while it shows only
          brings it forward.
        - **The state line** is the session's `doing`, as `watch` gives it
          for every session: core words it, the window draws it, a stop in
          its washed card. A session needing Lee for its asks alone has no
          row of its windows', so the rows could not say it. Its time reads
          "6m into this turn", or "its turn ended 12m ago", as on its own
          work too, whose line says what it waits on, a wake's countdown
          worded at the window's tick. Its `away` is the
          one fact of away: the jump, finishing, the faint name and a card's
          buttons all follow it.
        - **A card.** Its buttons come from `wants`: a yes's white pill, an
          option's outlined pill each, "Comment in Claude ↗" beside them,
          "Answer in Claude ↗" for words, white, and ignore; on an away
          session nothing that needs Claude Code's prompt, and "Your answer
          waits in its inbox…" under a yes or a choice. A press, ignore
          among them, waits 2 seconds, its line draining, Escape taking back
          the one pressed last on the page showing while it waits (one on a
          page left goes as it would); then it is "sending" until `reply`
          says on its way, as an answer, or, once `sitrep answer` has
          written it, until the first read asked for after, whatever it
          says (should every one fail, the card says on its way, as the
          write proved); then the card takes `reply`'s word: "on its way: waits for
          the turn to end" mid-turn, "waits in its inbox for a window" away.
          A comment on its way keeps the buttons. `sitrep answer`'s refusal
          shows on the card in its words, its buttons back, until another
          session is picked, or a read has the ask closed or Lee's answer to
          it on its way, which bars them. After a written answer the session
          is read again at once.
        - **Kept in place.** The asks of the page showing, a session's or
          each of a project's sessions', show the newest first, as the
          pane's; one that leaves meanwhile keeps its place, faint, saying
          how: "sent, and Claude has it" where Lee's answer closed it,
          "resolved by Claude: …" with Claude's reason, "ignored" for one
          gone without a place in Resolved; Resolved leaves it out until
          another page is picked. A new ask lands at the top, washed. Where
          the pane keeps an ask its send closed for a moment, the window
          keeps every closed ask until the pick changes, as its own rule
          says, the stricter of the two. Each page opens at its top.
        - **The list.** Held while the pointer is over it and for a second
          after, a change showing in place; a session new to needing Lee
          (`new`) moves in at once to `watch`'s place, after the nearest of
          those `watch` has before it, its project with it, washed for the
          panel's 2 seconds, within its fill. Stale, nothing is new. A close
          lets the hold go. Under Reduce motion, SitRep's or the Mac's,
          followed as either changes, nothing slides or washes, and the arc
          and the shimmer hold still. Opened again while minimised, it comes
          back as it was.
        - **Finishing** asks in place, "Finish …? Its open asks stop
          counting.", Yes, finish it and Cancel, which a pick, a close or
          the session coming back open lets lapse; Yes pressed, it shows
          finishing, Cancel with it, until `watch` takes the session off;
          refused, it says why there.
        - **Jumps** go through the app's `Works`: none while one runs, from
          the window, the notch or the menu, and the window's jumps wait
          while one does.
        - **For now** it opens from "Open SitRep Window" in today's menu,
          which the menu bar item's phase rebuilds; the quiet projects' line
          is a line, opening nothing; Resolved's rows do not open to how
          they closed, which a pointer resting on one tells. Both open since
          Lee's first try, 20 October 2026 (see "The SitRep window").
   9. **Installing the plugin**: the app's first start installs it, and its
      relaunch refreshes it (Installing and updating, under "Where it
      lives"). Built 20 October 2026, and reviewed twice the same day:
      - **The bundle carries the plugin**, in `Contents/Resources/Plugin`:
        `app/bundle` copies what Claude Code loads (`.claude-plugin`,
        `hooks`, `core`, `types`, `sounds`) as the checkout stands, files
        not yet committed among them but not the ignored ones, compiles the
        CLI into `bin/sitrep` with `bun build --compile`, and stamps it
        with a digest of its files (`.sitrep-build`); the app's source, the
        tests, the CLI's source and this design stay behind. The bundle's
        signature verifies with it inside (`codesign --verify --deep
        --strict`). `app/bundle` refuses a folder that already holds a
        bundle. The Info.plist's `SitRepPlugin` is gone.
      - **The binary records the SDK it was built with**: `app/bundle`
        gives the release link the SDK as `-isysroot`. SwiftPM hands clang's
        link the SDK only as `--sysroot`, with no `SDKROOT`, and clang then
        records the deployment target, 14.0, as the SDK, though the objects
        record the SDK itself (27.0 on 20 October 2026). macOS draws an app
        in the design of the SDK it records, so SitRep was drawn as on
        macOS 14, its Settings and its window with none of the system's
        Liquid Glass (Lee, 20 October: "We should be using Liquid Glass for
        the settings"). The flag can go once SwiftPM passes `-isysroot` or
        `SDKROOT` itself. Only the bundle's build has it: `swift build` and
        `swift test` still link as macOS 14, so the tests run in the older
        design's behaviour, and the notch and strip, tuned frame by frame
        under it, want a look in the bundle.
      - **Each start looks first**, before `watch` starts: `claude` found
        where its installers put it (`~/.local/bin`, Homebrew's, npm's on
        an Intel Mac, the old `~/.claude/local`), else on Lee's login
        shell's PATH; then the two lists, read as JSON, decide, in a unit
        of their own (`PluginPlan`) apart from the running of `claude`:
        - nothing of sitrep in either: copy, `claude plugin marketplace
          add` the copy's folder, `claude plugin install sitrep@sitrep`;
        - the marketplace SitRep's own copy: at another build than the
          bundle carries, copy; with Claude's record at another version
          than the copy, `claude plugin marketplace update sitrep` and
          `claude plugin update sitrep@sitrep`; with the plugin not
          installed, as after a first start cut short, install it; with
          all the same, nothing;
        - anything else of sitrep: nothing, and the CLI run is the
          plugin's from where Claude loads it, never a folder plugin's
          cached copy. A test reads the lists this Mac printed, the clone's
          folder marketplace among them, and pins that nothing is run but
          the two lists and nothing copied.
      - **The trouble, in plain words.** With no `claude`, the card and
        the menu's speak-up say "SitRep can't find Claude Code" and
        "Install Claude Code, and SitRep will find it."; a step that fails
        says so in `claude`'s own words (the `message` of its `--json`
        line). Meanwhile SitRep runs the plugin of the last look that went
        well, else its own copy, and looks again on `watch`'s back-off;
        with none to run, the notch, the strip, the window and the menu say
        why.
      - **The card** says where the plugin comes from: "Installed by
        SitRep", "From ~/Code/sitrep", "From GitHub, leeovery/sitrep";
        before the first look ends, "Looking for Claude Code's sitrep
        plugin…". In trouble, or while looking, it lists no windows to
        reload, as its line counts none.
      - **Proven** against the real `claude` with `CLAUDE_CONFIG_DIR` and
        Application Support in a scratch folder (`LivePluginSetupTests`,
        only when `SITREP_LIVE_CLAUDE` names that folder): a first start
        ran the two lists, the add and the install; a relaunch at the same
        build ran the two lists alone; one at a newer build replaced the
        copy and ran the two updates, Claude then listing the new version;
        and the copied, compiled CLI answered `list --json`. The reviews'
        two states run there too: with Claude's record of its marketplaces
        gone and the clone still installed, SitRep ran the two lists alone,
        left `settings.json` as it was and ran the clone; with the clone's
        `marketplace.json` gone, it ran the two lists alone and named the
        trouble, never running Claude's cache.

   The build runs through to the end without stopping (Lee, 19 October
   2026): a PR per phase, or a stack where a phase needs several, each
   reviewed and merged to main as it passes, with no live try between them.
   Lee tries the whole once it is done. That try confirms, beside the rest,
   with the debug log on (see "A session's state"):
   - a permission prompt in the default mode: the dialog shows, the row
     says needs you, and the log says the stop began as its dialog showed
     and ended as its call settled;
   - the same in auto mode, for a call the classifier hands to Lee;
   - a call the classifier approves showing working throughout, with no
     stop in the log;
   - a `/reload-plugins` while a call runs: the heartbeat's `loadedAt`
     moves on, and if the old load's call settles after it, the log says
     once that a later load wrote over it, and the state stays the new
     load's;
   - a jump to a session whose pane's tmux window no terminal shows, its
     tmux session's Ghostty window on another of its windows: tmux selects
     the pane's window, and that Ghostty window comes forward showing it;
   - a jump to a session two windows hold, one stopped on a permission
     prompt: the jump goes to that one; and with neither stopped, to the one
     working, else the one whose turn ended last;
   - the Mac put to sleep for a few minutes with a permission prompt
     showing, and woken: the row stands throughout, with no flicker, and
     the notch does not swell again for it.

   A jump outside tmux, tested since stage 2, was first
   run live from the bare app (below). Two things to carry over from stage 2: an app started from the Finder has
   only `/usr/bin:/bin:/usr/sbin:/sbin` on its `PATH`, with no tmux, so it
   runs the CLI with Lee's; and its first jump asks macOS for leave to
   control Ghostty. It runs one jump at a time: two knocking on one
   terminal at once can leave it reporting `$HOME`, as the later one takes
   the earlier one's marker for a directory it cannot know.

   The bare app was built on 14 October 2026, and proved live with Lee the
   same day:
   - **A silent macOS notification**, once Lee allowed SitRep's
     notifications (macOS asks in a notification of its own, easily missed
     in Notification Center), and clicking it jumped to the session it
     named.
   - **The leave to control Ghostty is SitRep's**, though it is the CLI, run
     as the app's child, that asks: macOS's record names
     `com.leeovery.sitrep` controlling `com.mitchellh.ghostty`, granted at
     the first jump.
   - **A rebuild kept that leave:** no prompt after one.
   - **Starting at login:** macOS said the login item was added, and Login
     Items lists SitRep.
   - **A jump to a Ghostty window without tmux**, on another Space, reached
     it.

   A jump from the menu takes about 0.45 seconds, the CLI's own time, before
   macOS's slide to another Space. Found on the way, for both kinds of
   window: when the last thing Lee clicked on the target Space was the
   desktop, the jump can land on that Space with Finder still in front, as
   macOS seems to hand focus back once its slide ends; it is a race, taken
   up the same day with making the jump faster ("The jump", steps 3 and 4). What building it settled:
   - **A Swift package in `app/`**, no Xcode project: the executable
     `SitRep`, and a library beside it holding what can be tested without a
     screen. macOS 14 and later, Swift 6.
   - **`app/build`** builds it, makes `SitRep.app`, signs it, installs it to
     `~/Applications/SitRep.app`, replacing what is there, and starts it.
     Since step 9 `app/bundle` makes the signed bundle, into a folder given,
     and `app/build` installs what it made.
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
     shell's PATH has. The shell's answer is kept. With none it falls back
     to Homebrew's folders, `~/.bun/bin` and the system's, logs it, and
     asks the shell again at the next run, so a shell slow as Lee logs in
     costs one run, not every run until a restart. Every child gets that
     PATH and otherwise the app's own environment, and a time limit, only
     a backstop for a CLI that hangs: 10 seconds for `list --json`, and 180
     for a jump, well above any realistic one. A jump takes under a second
     as Ghostty answers, and one Ghostty does not answer at all, as with
     the screen locked, is refused at its first question, after 5 seconds.
     It is no true ceiling: the 5 seconds hold for each question to Ghostty,
     each Apple Event, and a program sends several (a listing three a try,
     a focus two, a find some 40), so a Ghostty answering every question
     only just inside its 5 seconds could keep a jump going past 180, and
     the app would then report that the jump did not answer. Raised from
     120 when the jump began remembering terminals and watching the front,
     14 October 2026.
   - **The main checkout's path stamped in.** `app/build` writes the folder
     of the repository's main checkout, the live plugin, into the app's
     Info.plist (`SitRepPlugin`), even when it builds in a worktree; the
     app runs that folder's `bin/sitrep`. Step 9 took it out (20 October
     2026): the app runs the CLI of the plugin the `sitrep` marketplace
     names, which on this Mac is still the main checkout, from any build.
   - **A plain menu**, until the notch and its panel are built (replaced by
     "The menu bar item", 17 October 2026, rather than slimmed as first
     planned): the sessions on screen, a jump each; a test
     notification; starting at login; quitting. The sessions are
     listed by `list --json` as the app starts and again each time the menu
     opens, which shows the last listing at once and redraws only when the
     fresh one differs, so nothing flashes; a session just gone from the
     screen may show for the tenth of a second the listing takes, and
     choosing it gets the CLI's refusal. A failed jump shows the CLI's words
     as a macOS notification. The menu bar item is AppKit's `NSStatusItem`,
     not SwiftUI's `MenuBarExtra`, whose menu style says nothing as the
     menu opens.
4. **Releases**, once sitrep is stable: a release is its version, in
   `plugin.json`, the marketplace entry and the app, and a tag
   (`claude plugin tag`); a GitHub Action on a macOS runner builds the app
   with the plugin inside it, its CLI compiled, publishes the app's update
   feed, and updates the cask in `homebrew-tools` (Sparkle, under
   "Installing and updating"). Lee's Macs then install the cask like
   anyone, kit's `[manual]` step gives way to the cask, and the clone stops
   being live: a script in the repository points the `sitrep` marketplace
   at the clone for a live test, and back. Going public needs the app
   signed with a Developer ID and notarised, since Homebrew quarantines
   what a cask downloads, as macOS does any download. The compiled CLI the
   bundle carries keeps Bun's ad hoc signature and is arm64 only (step 9):
   notarising needs it signed with the Developer ID, the hardened runtime
   and a timestamp, likely with Bun's `allow-jit` and
   `allow-unsigned-executable-memory` entitlements, and an Intel Mac needs
   an x64 build beside it. To settle then: whether
   `claude plugin update` follows `main` or the tags, for the plugin alone
   from GitHub.
5. **Attention beyond asks**, in this build (decided with Lee on 16 October
   2026), built as stage 3's fourth step, the live feed, since the rows
   and the strip's rings need it. The mod hears what its window is doing,
   and the heartbeat carries it, with what the row shows of it (the tool
   running and its path; the permission prompt's tool and command; the
   question, and how many there are; when the turn began or ended). These
   give a session's working, your turn and its stops on a permission prompt
   or a question (see "A session's state"):
   - a turn starts: working;
   - Claude Code is about to show a permission dialog
     (`classic.PermissionRequest`, matched to the call `tool.check` put to
     Lee with that tool and input): needs you, the row saying what it asks
     (`Allow Bash: gh pr create`). A check's "ask" verdict alone is no
     stop: in auto mode the classifier settles most such calls (corrected
     19 October 2026; see "A session's state");
   - Claude asks a question (AskUserQuestion): needs you;
   - the prompt or the question answered and the tool run (`tool.call`'s
     `next` resolving): working;
   - the turn ends, or Lee stops it: your turn.

   The mod writes each change into the window's heartbeat at once, not on
   the 30-second beat, so readers hear it within their poll of a second or
   two. A permission prompt or a question arrives like a new ask: the notch
   swells twice, the light flashes, and the row gets its orange wash. Only
   deterministic stops need Lee: a turn ending with a question in plain
   text is your turn, and shows quietly.

   The heartbeat's side was built on 19 October 2026, as stage 3's fourth
   step: each window's state, written at once, a burst of calls at most
   once a second, a subagent's prompt or question counting as the window's
   own while its turns and tools do not, and a permission prompt only once
   its dialog shows (see "A session's state" and "Storage"). `sitrep watch`
   gives the rows and what is new (19 October 2026); the swell and the light
   wait on the app.

   A macOS notification comes only if Lee turns them on. First written (13
   October 2026) as a macOS notification for every session blocked on a
   permission prompt, heard from `classic.Notification`, with the turn's
   end from `turn.complete`. Corrected on 16 October 2026, since macOS
   notifications are off by default once the notch exists, and the notch
   swells and lights for a stop as for a new ask.
6. **Opening what isn't on screen**: a new Ghostty window attached to a
   tmux session running with no window, as `code-OQWkFt · sitrep` and
   `portal-rex` were on 13 October.

## Later

Parked: an **agents** view (subagents, observed from engine events, grouped by
what they're for); a **tmux indicator** reading the shared folder; **Paper
thumbnails** inline in Ghostty; a **shy notch**, pulling away as the
cursor nears before giving up and pouring open (Lee, 16 October 2026); a
"re:" tag on Lee's transcript rows that
came from the board. Jumping to a session's window is now "The menu bar".

Dropped: a standalone toast plugin (Claude Code has one), and a line in the
new-ask toast saying the band opens it: Lee knows it does, and on the phone
the toast is better short.

## Open questions

Answered with Lee on 8 October 2026, for build step 5, which Lee then dropped
on 11 October 2026 (see "Build order"):

1. **Whether Lee is looking at the window: no check.** It was only there to
   spare a macOS notification for the window that has already pulsed, toasted
   and chimed; asks are rare, so a notification for every new ask.
2. **Notifications:** `terminal-notifier` when it is already on the PATH;
   sitrep never installs anything on someone's machine. Without it,
   `osascript`'s notification, which ships with macOS (clicking it opens
   Script Editor rather than Ghostty).
3. **Left open: dropped.** Lee may be away for days, so no time is right; a
   window joining a session reconciles its open items instead.
4. **The CLI answering asks:** settled on 20 October 2026, with stage 3's
   step 8: `sitrep answer`, a yes or a choice, or `--ignore` for any ask, a
   reply into the session's inbox, which its window delivers as it delivers
   any reply. A words ask, a comment and a permission prompt stay with
   Claude Code's prompt (see "One engine, two front ends").

## Build order

1. **core** and the storage format, with tests.
2. **The mod for one session**: start/join, status, ask, note, park,
   the pane's session view, Ready to send, delivery to this session, the band.
3. **Across sessions**: the project and all-projects views, delivery
   through inboxes, the first message's listing.
4. **The CLI.**
5. **Dropped** (11 October 2026): notifications, `/sitrep check`, and a
   reconcile when a window joins a session. Notifications aren't wanted for
   now; `/sitrep check` adds nothing over the `board` tool; a join already
   answers with the whole board, and asks Claude to correct what is stale. The
   build is finished.
6. **The menu bar** (13 October 2026), in stages of its own: see "The menu
   bar".

## The spike

A throwaway mod with fake data modelled on Switchboard, Goosemates and five
other projects, run only in the window that designed sitrep. It settled every
surface above, and its drawing code became `hooks/draw`. Retired on 8 October
2026, once it was found drawing its fake data over the real pane: both named
their pane `board`, and a pane's id is not scoped to the plugin that opens it.
