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
| **session** | One line of discussion, with its status and asks, and the items it parked, which are its project's. It outlives its window: after a `/clear`, or in a new Claude told to carry on, it is the same session. | |
| **window** | One running Claude Code, wherever it shows: a Ghostty window, a tab, a tmux pane. Where working, your turn and a permission prompt come from, and what the jump brings forward. A word for the code and for the design. | Rarely shown. |
| **session id** | The board's internal id for a session (`sr-k3f9qa`). Not Claude Code's session id, which names a conversation and changes on `/clear`. | Never shown. |
| **the board** | The content: projects, sessions and their items, the state any surface shows. Putting something on the board is like putting it in a database. | |
| **status** | Where a session stands: its name, a one-line summary, what is under way now (one line each), and what comes next. | |
| **ask** | Something only Lee can do or decide, posted by Claude. Counted on the band, unless snoozed. | |
| **parked** | Something raised and put off, to circle back to. Its project's, naming the session that parked it (11 November 2026; see "Parked items are the project's"). Not counted; Lee drops one from the pane (18 November 2026; see "Dropping a parked item"). | |
| **reply** | Lee's answer to an ask, or a pick-up of a parked item, waiting in Ready to send. | |
| **resolved** | An item done with: an ask a reply closed, or any item Claude resolved. Resolved lists a session's resolved asks. | |
| **snoozed** | A session Lee put off until a time, its asks and its turn together (13 November 2026; an ask alone from 23 October; see "Snooze"): nothing of it counts as waiting on Lee until then, and it is back as it wakes, as Lee wakes it, as a new ask lands there, or as Lee writes to it; snoozed until it moves, as its turn next ends too. | Snoozed |
| **finished** | A session Claude or Lee finished, once it was complete with nothing left on it; what it parked is its project's, and stays. | |
| **notch** | The SitRep notch, where it needs telling from the camera's: the black shape at the edge of the screen that opens into the panel. | |
| **panel** | What the notch opens, the notch panel or the SitRep panel: a glance at the board, and a jump. | |
| **row's arrow** | A Needs you row's button at its right end, shown in its time's place while the pointer is on the row, that opens the asks panel (24 November 2026). | |
| **asks panel** | The panel beside the list that shows one session's asks, one at a time, to answer from; a Needs you row's arrow opens it (24 November 2026; see "Answering from the panel"). | |
| **strip** | The alternative to the notch and its panel: a narrow strip the height of the screen. | |
| **menu bar item** | SitRep's icon in the menu bar, and its menu. | |
| **Settings** | Where Lee sets SitRep up. | |
| **pane** | The view of the board inside Claude Code. | board: `show board`, `hide board` |
| **band** | The line above Claude Code's prompt. | |
| **macOS notification** | What macOS shows from an app, as SitRep's for a new ask. | |

The code uses these words (19 October 2026): sessions, not pieces of work,
in the mod, core, the CLI (`--session`, `$SITREP_SESSION`) and Claude's
tools; on the pane, ASKS, RESOLVED and "finish this session"; on
disk, `sessions/` and `session.json`. The old `works/` and `work.json` were
read beside them until the CLI moved them, and on 27 October 2026, with
nothing of the old layout left on any Mac, the reads and the move went (see
"Storage"). Claude Code's own
session is a conversation or a window there, so "session" means only the
board's. The old words are left in two places until what holds them is
rebuilt: the spike's `lip`, in its views only, since the model the build
took from it says the notch (19 October 2026); and the app's Swift
identifiers, until the edge and the menu rebuild the app, later in stage 3.
The CLI's JSON kept its old names (`works`, `work`) until 27 October 2026,
when `list --json`'s projects came to hold `sessions` and `board --json` to
give its session as `session`, their `v`s moving, as `watch` was made to
carry boards (see "One engine, two front ends").

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
   - SitRep: sr-w8d4tn "sitrep", 2 waiting on Lee, 1 snoozed by Lee
   - Switchboard: sr-p7x2wd "Milestone 7 stage 1"
   ```

   An ask Lee snoozed counts apart, as snoozed by Lee (see "Snooze"). The
   projects whose directory holds the window's folder come first, the
   nearest first, then the busiest, as All projects orders them. It is
   computed once per conversation, again after `/clear` or a compaction, and
   again for a conversation resumed in a new process or by `/resume` (live). It
   tells Claude to join the matching one by id, and says which one this
   window already holds.
5. A resumed conversation, holding nothing, takes up by itself the session
   it was last seen in, in whichever project: by its heartbeat, else the
   latest item or status it posted. Sending into a session's inbox, having
   started it, or a note posted before notes went, is not being seen in it. A finished session is never taken up
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
snoozed or not, or on a window to deliver Lee's answer), or was updated in
the last 7 days. An older idle session stays on disk, out of the views but
its project's old sessions, folded at the foot of its Sessions (17 November
2026; see "Old sessions", under "The pane"); a project left with none
current drops out of All projects altogether, unless something is parked in
it (below). Something parked kept its session current until 11 November
2026, whatever its age.

A session is **finished** once Claude or Lee finishes it, and is then never
current, whatever it holds: a window can close with things still open on
its session. Its waiting asks count nowhere (tabs, band, projects) but in
the window that still holds it, which still answers them, and no reply from
another window reaches them (see "A finished session's view", under "The
pane"). It leaves
the session lists, and shows among its project's old sessions, whose row
opens its view, which says it is finished (see "A finished session's
view"). A line posted to it later, by the CLI or anyone, leaves it
finished; only a window joining it again reopens it, its asks waiting on
Lee again.

**Parked items are the project's.** A parked item is parked from a session,
on that session's project, and names the session that parked it. Any
session of the project sees it and acts on it: Claude's board text lists
it, Claude's tools resolve, edit or reopen it, and Lee picks it up from the
pane in any window of the project, the pick-up going to the Claude in that
window (see Delivery). Every view of the project lists every one: a
project's view the oldest first, each naming its session by name, and a
session's view the items it parked first, then the rest, each of those
naming its session, each part the oldest first, as Claude's board text
lists them. Finishing a session hides none of them, and
a session going idle takes none with it. Asks stay their session's.
Decided with Lee, 11 November 2026;
until then a parked item was its session's, and a finished session's
vanished from every view, though still stored.

- **A session's view lists the project's too** (17 November 2026, Lee).
  Until then a session's view listed only the items it parked. Lee expected
  parked items to be the project's everywhere, and his session's Parked
  said `nothing to come back to` while its project held 8. So the rule
  above holds in a session's view too, its heading counting them all, its
  picked up the project's, and any item picks up from there as from the
  project's view. It is what Claude's board text already gave Claude.

  A faint `from other sessions` heads the items other sessions parked, in
  a session's view, with no blank row (17 November 2026, made in review).
  Named alone, those rows read like titles with colons
  in them, and their ages jump at the seam. It shows even where the session
  parked nothing itself, so it is always plain that none of them is its
  own. A project's view names every row, and has none.

- **Nothing is rewritten.** Each item stays in its session's files, where it
  was parked, and the views read a project's parked items from every
  session filed under it, finished and idle ones included (see Storage). So
  every item parked before is its project's as if it always was. At the
  release, 31 items in 6 finished sessions come back: Switchboard 18, mint
  11, and 1 each in Kit and one other project.
- **Parked items keep no session current.** An idle session leaves the
  session lists after its 7 days, and its items stay in the project's
  Parked; a project with something parked stays listed, though none of its
  sessions is current. On Lee's board that day, 11 sessions holding 25
  items stood on the board for those items alone.
- **No line about a parked item moves its session's time**, its park aside:
  a pick-up, its delivered mark, and a resolve, an edit, a reopen or Lee's
  drop of a parked item leave the session as recent as it was (`updatedAt`), whoever
  writes them. So an act on a parked item from another session never brings
  the session that parked it back onto the board. A mark counts as about
  parked items where every reply it names is a pick-up. The fold judges each
  line by the item it names once every line is read, so a mark read before
  its reply is judged too; a line naming an item or a reply the session does
  not have moves the time as any line does. It is the simplest rule a build
  meets with no change of format, as every such line names its item already.
  It holds for the session's own window: while the window is live the
  session is open, and current whatever its time; once the window goes, its
  7 days count from its last line about anything else, its status or an ask.
- **Proven live on 11 November 2026**, on Lee's own board: All projects
  listed six projects for their parked items alone, `no sessions open · ◇
  11 parked` for Mint among them, and Mint's Parked named each item's
  session (`Build Mint's Rail look: …`), never an id. A new Mint session's
  window picked up an item the finished "Build Mint's Rail look" had
  parked: its Claude was given `Pick up from parked, Build Mint's Rail
  look's: …`, Parked went from 11 to 10, and no old session came back.

**A session moves to another project at Lee's word** (17 November 2026).
A move is a line in the session's own files; its folder never moves. Every
reader files the session under the project its latest move names.

A session started under Fabrikam, a client's general project, and Lee
asked it to move everything into Fabrikam Mobile, the project for one of
that client's apps. It could not: no tool moved a session, and the `project`
tool renames a project, never moves a session out of one. So it started a
new session there, and left the old one and its items behind. Agreed with
Lee that day:

- **Claude moves the session it holds, at Lee's word**, with the `move`
  tool, to a project named as Lee says it: one on the board, matched as
  `start` matches one, by its name, case, spaces and punctuation aside;
  else a new one, made of the name, with its directory once known, as
  `start` makes one. A directory given is recorded for a project that has
  none. The project it is in already is refused (`Help desk redesign is in
  Northwind already.`), as is a call with no session held. Renaming stays
  the `project` tool's and moving the `move` tool's: one changes what a
  project is called, the other which project a session is on. The tool's
  description and the board's guide tell Claude to move a session only
  when Lee asks, and never to start a new one there instead. The CLI moves
  one too, into a project on the board (`sitrep move`, under "One engine,
  two front ends").
- **The session goes whole**: its asks, what it parked, its status, its
  history and what was resolved. It is the same session, by the same id, in
  its new project's views, the first message's listing, the CLI's `list`
  and `board`, and SitRep's rows; what it parked is its new project's, and
  its own view and Claude's board text list the new project's parked items.
  The old project keeps nothing of it: no view of it lists the session or
  what it parked, and one left with no current session and nothing parked
  drops out of the lists, as any such project does. A board standing on
  the view of a project a move emptied goes up to All projects at its
  next look, at its top, as a finish goes up from the session it leaves
  (18 November 2026: the view stayed, headed by the project's key, of a
  project All projects no longer listed). The look goes up only for a move
  it saw: a session the last look filed under the project, read under
  another now, and none filed under it; so a listing that failed, or a
  torn `session.json`, moves no one, and nor does a look whose held
  board is another session's, which files the held one nowhere sure. A
  press of Lee's landing as the look reads stays where he went. One whose
  sessions are only finished or old is still the board's, and stays.
- **Every window holding it follows**, Claude carrying on with no rejoin,
  and says so: each toasts `Moved to Contoso.`, the mover's among them.

Built so (17 November 2026):

- **Nothing moves on disk.** A session's folder is the one it was started
  in, `projects/<key>/sessions/<id>/`, for good. A move is a line, `{
  "type": "move", "project": "trey-research" }`, which the mover appends to
  its own file there, naming the project by its key (see Storage). A
  session is filed under the project its latest move names, in the order
  every reader reads lines, where that project is on the board, and named
  as the board names it; else under its folder's. One rule in core,
  `fileSession`, given the name the board gives the project the latest
  move names, files it for the mod, the CLI and `watch` alike.
  - Why not move the folder: a mod's `$.fs` can neither rename nor delete,
    so a move could only copy the files, and every window holding the
    session would write its lines into the old folder until it heard of the
    move; every reader would then read two folders as one session, as the
    two layouts were read from 19 to 27 October 2026. A line moves nothing,
    so no line lands in the wrong place.
  - A reader mid-move has nothing to recover from: it files the session
    under its old project until it reads the line, and under the new one
    from then, one decision from one fold, never in both and never in
    neither. Two moves at once both land, and the later in that order wins,
    in every reader.
- **Kept refs name the folder, drawn refs the project, and the compiler
  holds the two apart.** Every ref to a session in `$.state` (the hold,
  Ready to send's replies, where they were sent, the board's place on a
  session, the item Lee is answering, a message in flight) names the folder
  its files are in, which no move changes, so a move rewrites none, and
  every read and write goes straight there. A ref a view draws names the
  project it shows the session in; a press keeps it, or writes by it, only
  through actions.ts's `kept`, which finds the folder by the session's id,
  the one named first, and keeps nothing where none holds it, a toast
  saying why (`Not queued: its session is no longer on the board.`).
  `finish` on another session's view writes by the ref kept so, then goes
  up to the project that view showed. A bare id is found the same way:
  `join`'s, and a pick-up's session as a taken message is written down.
  The project a session is filed under is never kept, but read from its
  fold, the held one's from the hold's latest (its board's `filedUnder`).
  Both keys are strings as stored, so `$.state` is as it was, but two
  types, `FolderKey` and `ProjectKey` (types/index.d.ts, core's
  filing.ts): assigning or passing one where the other goes is a type
  error; `===` between them is not, and no comparison mixes them. Only
  filing makes a project of a folder (`fileSession`, `projectOfFolder`),
  and only a key read off the disk is made a folder (`folderKey`, which
  refuses a `ProjectKey`). It stands for a bug found in review that day:
  Lee's snooze of the held session's ask after a move named the project
  the view showed, and was written beside the hold, then lost.
- **Following is reading.** Each window folds its session at its watch's
  look, every 1.5 seconds, the name of a project a move took it to read
  again only once that project's file's text changed, and a fold that
  files it as the last did giving the board nothing to put; its tools fold
  it again before they act, so `move` and `project` act on the project the
  session is in now, never the one another window just moved it out of,
  and every tool on the held session, acting on another session's parked
  item among them, is denied while its `session.json` is missing or torn,
  which leaves where it is filed unknown. Once the fold files it under
  another project, the window toasts and reads the sessions around again;
  a pick-up in Ready to send of what the old project's other sessions
  parked is held back there, as when a window takes up a session of
  another project (see "A window that changes project", under Delivery).
  Its hold, its own file, its heartbeat and the inbox stay as they were, so
  it posts, beats and delivers on. A window that joins the
  session later, or takes it up as its conversation resumes, files it
  under its new project from its first fold.
- **The mover answers from the fold after its post**: `Moved Help desk
  redesign to the existing project Contoso.`, `… to a new project, Trey
  Research.`; where another window moved it at the same moment and won,
  `Help desk redesign is in Woodgrove: a move another window made at the
  same moment took it there.` The call's row, in the pane's `verb: name`
  form, names the project the board named as the call was answered,
  `moved to: Contoso`, however Claude spelled it; a row from before the
  names were kept names the call's own words, never the project the
  session is in now, which a later move may have made another.
- **What is in flight goes on.** A reply in the session's inbox waits there,
  in its folder, and is delivered as any; a send to the session from its own
  window is written down through the hold. A pick-up of one of its parked
  items sent from another window goes on to that window's Claude, and is
  written down in the session that parked it, found by its id. One still in
  Ready to send there goes only while the session is filed under that
  window's project as the send reads it (see "A window that changes
  project", under Delivery).
- **SitRep follows at its next line.** `watch` files the session as every
  reader does, so the line after its look has it under the new project: its
  row's project and letters, its windows' project, and its board's
  `project`. A project renamed is a new line too, though no session of its
  folder changed, since a session moved to it goes by its name. No field
  changes and `v` does not move; the jump goes by the session and its
  windows, which move nowhere. Nothing in the app changes.
- **Older builds.** A build from before skips the `move` line, as it skips
  any kind it does not know, and files the session under its folder: a
  window not yet reloaded shows it in its old project until it reloads, and
  posts on into its folder, where every reader reads it. A build switched
  back to after a move (`app/plugin app` after a live test) finds its hold
  naming that folder, and holds the session and posts to it as before,
  filed under its folder's project until it reloads this build again.

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
  An ask counts even while the session is away, and not while Lee has it
  snoozed (23 October 2026; the session whole since 13 November 2026, see
  "Snooze"): a snoozed session's stops still need Lee, and otherwise it
  stands as its windows leave it, out of Your turn too.

  An ask waits on Lee until Lee replies to it (20 October 2026): once a
  reply of Lee's to it is on its way, an answer or a comment, in its
  session's inbox from the pane or `sitrep answer`, or, sent from the
  pane to its own session, in that window's message from the moment it is
  claimed (22 October 2026), Lee has responded: it waits on a window to
  deliver the reply, and then on Claude, not on Lee, and counts nowhere on
  Lee's surfaces as needing Lee: not in a session's or a project's waiting,
  on the tabs or the band, in `list` or `board --json`, nor in `watch`'s
  head and rows, so the notch does not swell for it. Its session's state is
  then what its windows make it: an away one with nothing else waiting
  leaves the panel and the strip. The ask
  itself still shows among its session's asks, saying its reply is on its
  way, until the delivered mark settles it; an ask whose reply went void
  waits on Lee again, as does one whose reply reached Claude after an edit
  it no longer fits (see "Which replies go in", under Delivery), and one
  whose own session's message was let go, taken back by Lee, refused or
  never taken, or whose window is gone before it was written down (see
  Delivery). A comment on its way bars no answer: the ask still offers its
  buttons. Core's `waitsOnLee` decides it. It still keeps its session
  current, as an ask waiting on Lee does, however long the answer waits for
  a window.

  Lee saw why on 22 October 2026: answering an ask while Claude was
  mid-turn, the reply sat in Claude Code's queue for minutes, and the card
  kept the ask in Needs you until the turn ended and the message was taken.
  A message to its own session is claimed in the window's `$.state`, which
  no other reader sees, so the window's heartbeat says the replies it
  carries, from the claim until the claim ends (`sending`, under "Storage"),
  and every reader folds them in as replies on their way. The window now
  holds such a message itself while Claude is mid-turn, where Lee can take
  it back, and submits it as the turn ends (see Delivery); it is on its way
  from the claim all the same.

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
  nothing of its own left running, and waits for Lee's message. Blue, and
  in Needs you under its asks, on SitRep's surfaces (13 November 2026,
  Lee): an ask and a finished turn both mean "go back to this session",
  Claude needing Lee explicitly or implicitly, and the white ring a
  your-turn row had said nothing. So the Mac app's "need you" counts asks
  and turns alike (see "The rows"). Core's state is unchanged, and so is
  the plugin's band inside Claude Code, whose "● N asks" counts asks
  alone. Until then it was not orange and had a section of its own: they
  are in a conversation, and Lee comes back when ready.
- **away**: no window holds it, and it is still current. Dimmed. SitRep
  dims a session a window holds but no terminal on this Mac shows too,
  keeping its state, which stays core's (stage 8's rethink, 13 November
  2026; see "The rows").
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
  none. Each run of its loop raises a `turn.start` and a `turn.complete` of
  its own, each carrying its `agentId` (Claude Code 2.1.318: the engine's
  types, written by 2.1.295, say its run raises no `turn.start`; see "Held
  behind a subagent's run", under Delivery). Neither is the window's, so its
  turns neither start nor end the window's; and its tools do not show, the
  row showing the Agent call that runs it, by its description: several at
  once would only flicker. Its permission prompt or its question stops the
  window on Lee all the same: it shows in the window, and only Lee can
  answer it. Its own `turn.complete` ends only what it left (above).
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
| `ask` | post an ask: what it wants back (`wants`: a yes, a choice or words), its title, and where to look; a yes's button (`yes`: the verb Lee gives, `Go`, `Approve`, `It works`), a choice's `options` and the one Claude leans toward (`recommended`), or what a words ask's words are (`needs`: "the command's output"), each only on its own shape |
| `park` | park something to come back to, on the attached session's project |
| `resolve` / `reopen` / `edit` | close, reopen or correct an item, with a reason. Resolving what Lee closed, an ask he answered or ignored or a parked item he picked up or dropped, passes quietly, changing nothing (below). An edit takes an item's one line as `text` or `title` alike, whatever the item, and may change what an ask wants, its `yes`, `options`, `recommended` and `needs`, under the checks `ask` makes for what it changes (see Storage); an empty `needs` or `recommended` clears it. An item of the attached session, or a parked item another session of its project parked, named with that session's id (`session`) and written into that session, in this window's own file there; another session's ask, or a session of another project, is refused |
| `finish` | finish the attached session, with a reason, once it is complete and nothing is left on it; what it parked stays its project's and holds no finish back. The window stays attached, and joining it again reopens it |
| `project` | rename the attached session's project, or say where it lives, or both; a name another project has is refused, saying a move there is the user's call, so to ask first. It never moves a session to another project: `move` does |
| `move` | move the attached session, whole, to another project, at Lee's word: one on the board whose name matches, as `start` matches one, else a new one, with its directory once known; the project it is in already is refused. Every window holding it follows (17 November 2026; see "A session moves to another project at Lee's word") |
| `board` | read back the board's open items, what each ask wants back among them (`k1 wants a yes (Go)`), and the project's parked items, so Claude can check and repair it |

**The mod hears its tools by their prefix** (17 November 2026): its
`tool.call` hook, and the renders of their rows, match every call whose
name starts `mcp__sitrep__` (`OWN_TOOLS`). Matched by the names
themselves, the matcher was typed against the tools the engine laid out
at the last load, so `move` failed the type-check until a load laid it
out; the type-check must not hang on names only a load writes. A call
matching the prefix that is none of the tools is denied (`sitrep has no
tool …`).

**A call is answered within its hook's budget** (24 November 2026). The
engine gives a hook 10 seconds of its own time (`HookBudget.ms`): the
clock stops only while a `next(e)` or one of the hook's own `$` calls is
in flight, so a wait on the window's queue (`serially`), behind work a
timer queued, is the hook's own time. Past it, Claude Code 2.1.331 skips
the hook without asking its `.catch` (proven with a probe mod: a `.catch`
that always refused was never taken), and the call goes on to the
engine's own tool, the loopback MCP server, which answers `sitrep
registered the tool status but no hook answered this call`. Meanwhile
the skipped hook's work runs on in the queue and writes its line.

- **What it did:** 15 calls failed so from 22 to 24 November, `status`
  and `ask` in four projects' windows, each 10.5 to 12.6 seconds after
  its hook began, while the Mac's processor stood at 100% for hours
  (test suites and builds of other projects). Every one of the Fabric
  session's failed statuses was on its board 2.5 to 7 seconds after the
  error, and an ask Claude sent again was on its board twice.
- **The deadline:** sitrep's hook gives a call until its budget's
  remaining time less 3 seconds (`next.budget.remainingMs` as the hook
  begins), waited with `$.clock.sleep`. A call whose work is done by then
  is answered as ever. The wait is real time, and the budget runs at real
  time only while no `$` call of the hook's is in flight: so through a
  wait in the queue, but not through the call's own reads and writes once
  its turn has come. So the deadline judges a call still queued by the
  real time, and a call begun by the budget it has left, read live.
- **At the deadline,** a call is answered by how far its work has come:

  | Its work | The answer |
  |---|---|
  | still waiting its turn in the queue | refused: the board was busy and nothing was written, so send it again; its turn, when it comes, does nothing |
  | a post's (`status`, `ask`, `park`, `finish`, and `resolve`, `reopen` and `edit` on the attached session), its check not yet passed | the same refusal once its budget is within 3 seconds of spent, read live; until then it waits on, looking again as that much more of the budget could have gone; refused, once its check runs it writes nothing |
  | a post's, its check passed, or its check refused it, or it had nothing to change | its answer, as it would have been (`Status set.`, `Posted ask k1mz. …`, the check's refusal); a line is written after, in the queue, a failure to write it logged |
  | any other tool's, begun | none yet: the hook waits on, as before |

  The answer of a post is known once its check settles, so the post
  answers then and the line follows; a call refused at the deadline has
  written nothing, so sending it again never doubles it. Lee stopping
  the turn ends the wait as the deadline does, the call answered by how
  far its work has come, a post before its check refused whatever its
  budget.
- **The timers queue no backlog:** each of the window's timers (the
  watch's refresh every 1.5 seconds, the heartbeat every 30, the
  inbox's look every 1.5, the look around every 5) skips a tick while its
  last is still queued or running, so a busy Mac slows them rather than
  stacking them up. Of them only the watch and the heartbeat run in the
  window's queue, so a call waits behind one run of each at most, besides
  whatever Lee's presses and the deliveries put there. A beat held past a
  minute leaves the window's heartbeat stale for a while, as the window
  is then.

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
- Keep the board current, since it tells Lee, away from the window, that
  something waits on him, but talk to Lee as if it weren't there.
- As it goes: the status when what's under way changes, an ask whenever Lee is
  needed (resolved by Claude when Lee answers it in the chat); resolve
  what's done; finish the session once it is complete, with nothing left on
  it. What it parked stays its project's and holds no finish back (11
  November 2026).
- A turn that ends on a decision or a question for Lee posts it as an ask,
  so it shows Lee it waits on him (in Needs you), never only in the status;
  plain conversation needs none (4 November 2026: two sessions ended turns
  with "Put to Lee: …" in their status line instead of posting an ask, so
  Lee's card showed them under Your turn, not Needs you).
- So does a turn that leaves Lee something to do, such as a release, a
  merge or a command to run, even said as a statement (17 November 2026: a session
  ended "It's ready for you to release", its status emptied and no ask
  posted, though its guide was in front of it; it read the ask rule as one
  for questions alone). The guide gives both as one rule, a bullet of its
  own, not a clause deep in "As it goes" (18 November 2026), and says what
  the ask does in words a Claude that never saw the app reads: the board
  shows it waiting on the user.
- When Lee asks to move the session to another project, move it with
  `move`: the whole session goes, so no new one is started there instead;
  and move one only at Lee's word (17 November 2026: asked to move
  everything into another project, a session started a new one there, its
  old one and its items left behind).
- Item and session ids are Claude's alone: Lee sees none anywhere in
  SitRep, so Claude never names one to him, and names an ask, a parked item
  or a session by its words (6 November 2026; Lee: "I have no visibility on
  those codes, they're entirely private, and that needs to state clearly in
  the plug-in instructions to you").
- The chat stands alone: it says all Lee needs, an ask's question and steps
  whole, and never points him to the board ("it's on the board", "check the
  board"). Saying what Claude parked is fine, as is naming the asks still
  open now and then, when several wait, though not at every turn's end. An
  ask Lee hasn't answered that Claude still needs is raised again in the
  chat (6 November 2026; Lee: "the Claude conversation to just be natural,
  almost as if the board doesn't exist… If I ignore an ask and it's
  required, Claude brings it back into focus as if the board isn't there").
- The turn's order: every board call of a turn comes before Claude's
  closing message to Lee, never after it; before any tool call Claude writes
  Lee a line at most, as longer words before a tool call can reach him as a
  short summary, or not at all; what Lee must read goes after the turn's
  last tool call (below).

Wording rules, in the tool descriptions:

- Ask when Claude cannot go on without Lee, when Lee's judgement changes what
  happens next, or when Claude leaves Lee something to do, a release, a merge
  or a command to run, as the guide's ask rule says (18 November 2026: the
  narrower rule, read as Claude decides, forbade the ask the guide demands
  of a session handing Lee a release). Say it in full in the chat as well,
  after the last tool call: the board never stands in for the chat. The
  ask's answer says the same:
  `Posted ask k3f9. Put it to Lee in full after your last tool call.`
- Choose the shape by what Lee gives back: a yes for a go, an approval, "it
  works" or "done"; a choice for one of options; words when Lee must write
  something back. A yes's button is the verb Lee is giving, a word or two
  (`Go` for "Give the go for stage 3", never a stock `done`).
- A choice Claude leans toward one option of gives that option as
  `recommended`, whenever it leans, never the word in the option's text
  (below, under "Answering an ask").
- One line, plain words, starting with the verb. No internal codes (no P-numbers,
  no D-numbers). "Where" says where to look in words: "In Paper: the dashboard
  file, page "round 1", frames 1–6".
- A changed status is noticed by the board itself (it compares the new
  status with the last), so Claude does nothing extra for it.

**The user** (18 November 2026). Every text Claude reads names the person
the board is for "the user", as Claude Code's own prompt does: the guide,
the tool descriptions and their answers, the refusals, the board text
(`waiting on the user`, `the user replied, yours to act on`, `snoozed by
the user`), a board message's lines, the narration line, and the CLI's
help and messages. Until then they said Lee, so a plugin installed on
anyone else's Mac told its Claude the board was Lee's; it ships in the
release after 0.7.0, so a 0.7.0 install still says Lee. Claude learns a
person's name from their own CLAUDE.md or setup, where they gave it; the
first plan, SitRep reading the Mac account's name into a file the mod and
the CLI read, felt invasive, and was dropped before it was built. The name
is one constant, core's `USER`, with its possessive, and no text guesses
at a pronoun: each is worded to need none ("so the board shows it waiting
on the user", "the rest never showed"), and what Claude reads, the guide,
the tools' descriptions and answers, the board text, a board message's
lines, the narration line, the refusals and the CLI's help, is tested to
hold no gendered one. The refusals only the person's own presses meet,
of a snooze, a wake or an answer, from the pane, the app or the CLI, speak
to them as "you", as the pane's toasts do (`This session is finished: its
asks wait on you no more.`); the CLI's help stays in the third person, for
scripts. A join's reopening says "It had been finished by the user" or
"by Claude". The plugin's own descriptions, in `plugin.json` and
`marketplace.json`, say "you". This document goes on in Lee's voice;
where it quotes a text that was reworded it gives the new words, and where
only the name was swapped, its quotes from before this date say Lee where
the code now says the user.

**No refusal for a call that does no harm** (13 November 2026). Live, Claude
was refused for calls that did no harm, and each refusal cost a turn and
confused Lee: it resolved asks Lee's answer had closed already, and was told
`k3f9 is already closed.`; and it edited a parked item's `text`, which only
a note had. So:

- **A board answer says whether it closed the ask** (see "What Claude
  reads"): under each ask's last reply in Lee's message, a line says where
  the message leaves it, `This closes the ask: nothing more to do with it.`
  or `This leaves the ask open: act on it, then resolve it.`, or, under a
  comment while an answer of Lee's is on its way apart, that the answer
  closes it. Before, the
  line gave the reply alone, and a choice sent with a comment read as if
  the ask were open.
- **Resolving what Lee closed passes quietly**: an ask whose yes, choice,
  words or ignore Claude has, or a parked item Lee picked up, the call
  answers `k3f9 was closed already by Lee: nothing to resolve.` and writes
  nothing (a parked item Lee dropped, `k3f9 was dropped already by the
  user: …`, from 18 November 2026; see "Dropping a parked item"), so Claude's reason never lands on Lee's reply. A parked item
  another session of the project parked passes the same way. Every refusal
  resolve and reopen made before stands for the rest: resolving an ask or a
  parked item Claude resolved; reopening what is open. Before, an
  ask Lee closed was refused as any closed item is, and a parked item he
  picked up took the resolve, Claude's reason written over his pick-up.
  An ask whose answer is on its way, not yet delivered, resolves as ever.
- **Accepted, not built**: an edit re-sending an option of an ask posted
  before markers were read, its marker now stripped, changes the option's
  stored words; a pick of it on its way is not voided, since a pick is
  never checked against the options' words, and reaches Claude in the
  words Lee picked (`→ Ship it (recommended)`) (13 November 2026).
- **Accepted, not built**: where Claude edits an ask in the very turn Lee's
  answer to it is on its way, the edit voids that answer as changed (see
  "Which replies go in", under Delivery), and the ask stays open, though
  the message that carried the answer said it closes. It takes an edit in
  the same turn as Lee's send, so it is left as it is. So too a held send
  Lee takes back: a comment's line, sent meanwhile, said the answer that
  send carried closes the ask, and the ask stays open.
- **An edit takes an item's one line as `text` or `title` alike**: an ask's
  or a parked item's, both given and saying different things refused (`An
  edit gives an item's one line as text or as title, not both with
  different words.`). A refusal names the field as Claude gave it, and
  lists the one line as `title or text` for every item (`An edit to a
  parked item changes title or text, where, ref; not yes.`). Before, a note
  took only `text`, and an ask or a parked item only `title`. The CLI has
  no edit.

When the board changes, its open items ride into Claude's next turn as unseen
context, so drift is noticed. A join answers with the whole board, and asks
Claude to correct anything on it that is stale against what it knows.

**The board text's Parked** is the project's (11 November 2026): what the
session parked first, then what the project's other sessions parked,
finished and idle ones included, the oldest first, each naming its session
by name, its id given only as the `session` the tools take to resolve, edit
or reopen the item. So another session of the project parking or resolving
something changes the board, which rides into the next turn as any change
does. A start counts as seen only what Claude gave the session, so a session
started in a project with something parked is told it with its first prompt.
What Claude changes itself is never told back to it: a pick-up written down
in the session that parked the item, or a resolve, an edit or a reopen there,
counts as seen, the rest of the board as Claude last saw it. A new park, by
the tool or the CLI, draws an id apart from every item open in the
project's Parked as last read, so two items seldom share one there; where
they do, the `session` tells them apart.
Dropped: a `/sitrep check` command, since the `board` tool already reads the
board back to repair it and Lee can ask for that in the chat; and a turn-end
check for an ask Claude forgot to post. The board is best effort, and in use
Claude has not drifted or forgotten, but for the turns that put a question
to Lee in the status (above), met with a line of guidance, not a check.

**Words Lee saw only as a summary** (6 November 2026). On Opus 5.5, prose
written before a tool call in the same turn, often when it runs past about
230 characters, though not always, comes back inside the model's thinking,
and no text block is sent. Claude Code asks the API for its thinking shown
as "updates", so a thinking block whose signature marks it narration comes
in the prose's place, holding a one-line summary, all Lee sees of it, or
nothing at all: Claude Code 2.1.285 gave only empty ones (187 of 187), and
on 6 November a Portal session on 2.1.318 had an empty one before an ask,
Lee seeing only "I've posted the same question to the board as well."
Prose after a turn's last tool call always arrives as text. That day it
lost a live test's numbered steps, the summary claiming Claude ran the test
itself, and a note Lee was to send on. Lee reported it to Claude Code:
https://github.com/anthropics/claude-code/issues/96288.

sitrep's own guide made the pattern: it asked Claude to say an ask in the
chat as well and then post it, set the status and so on at the turn's end,
a long message followed by tool calls. A clause added earlier that day
asked for the words after the last tool call; the guide now carries the
turn's order and the chat standing alone (above) in its place. Lee: "It's not
SitRep's responsibility to fix Claude Code, but we can at least make it not
happen as much as a result of SitRep."

What still slips through is caught on the next tool call, at no cost of a
turn (hooks/summarised.ts):

- **Untold.** A response row of the main conversation's (`session.append`,
  door `response`) holding a thinking block whose signature names it
  narration, words or none, waits untold. The main conversation's next
  turn (`turn.start` with no `agentId`) lets go of what is still untold,
  which belongs to a turn gone by.
- **The signature.** Base64 for a protobuf envelope: the block is field 2,
  its header field 1, and the header's field 8 the block's kind,
  `narration` or `thinking`. Only the signature's head is decoded, its first
  256 characters, as every thinking block's is read: the header ends some
  twenty bytes in on Opus 5.5's envelope (`CAQS…`), and some 175 on Fable
  5's (`CAIS…`), within the head's 192 bytes; every Fable signature in 627
  transcripts of three days read within it. As Claude Code reads
  it, anything that does not parse that far, the header whole, is no
  narration. Every one of 5,444 signatures in a live transcript of that day
  read as one or the other. Words do not tell them apart: narrations with
  none come, as above, and ordinary thinking with words comes in some
  sessions (2.1.309 and 2.1.317).
- **The line.** The first call the engine makes on the main loop (its
  `next.origin` the engine) that settles without a refusal, any tool's,
  sitrep's among them, carries one line in its result's `context`, which
  Claude reads after the result and Lee never sees, and everything untold
  is then told. With words: "Your words before this tool call reached the
  user only as this summary: “…”. The rest never showed." With none: "Your
  words before this tool call never reached the user: none of them
  showed." Either ends "Say again, after your last tool call, whatever of
  them the user still needs: a question, steps, a finding, a decision.",
  since most narrations
  are mid-turn progress no longer worth restating (over three days, turns
  with narration had a median of one narrated message, and as many as 32).
- **What carries it.** An errored result (a failed command, a permission
  refused, Esc) carries it as an answered one does, so where the turn ends
  there, the line is lost. A refused call carries nothing and leaves it for
  the next call, in the same request or the next. A subagent's rows and
  calls are left alone, as Lee reads only the main chat, and so is another
  plugin's own `$.tool.call`, whose added context the engine drops.
- **Never in the way.** The hook adds to the result `next` gave, its `ref`,
  `text` and `isReadOnly` kept, and changes nothing else; should it fail,
  the result passes as it came.
- **Seen.** A headless run of Claude Code 2.1.319 that day, through a
  probe plugin, showed each block of a response stored as a row of its own
  as it ends, its thinking signed, a tool use's row before its call starts;
  a subagent's requests, rows and calls each carrying its id; and the model
  reading a line so added and quoting it. A result carrying the line was
  stored as one without it: a 223.5KB command output saved to its file
  with the same preview, an image read the same, their records alike. No
  narration came in that run, as none comes on demand, so a narration's row
  is known only from transcripts, the same thinking block signed otherwise.
- **Left.** A retry inside one request can leave a dead attempt's
  narration untold, at worst one line too many.
- **Not a Stop hook.** A Stop hook blocking the turn's end to ask for the
  words again would cost a model turn each time; the line rides a result
  Claude reads anyway, for only the words it restates.

## Lee's side

### The pane: a tree, with this session as home

```
 ⌂ Dashboard redesign 3  ≡ All projects 8
━━━━━━━━━━━━━━━━━━━━━━━━──────────────────────────────────────────

Dashboard redesign · Switchboard
Redesign the dashboard, area by area in Paper

ASKS ─────────────────────────────────────────────────── 3 waiting
● Review Sessions & Runway, round 1                             2h
└ In Paper: the dashboard file, page "round 1", frames 1–6
  [ ✓ Approve ] [ ✎ comment ] [ ✕ ignore ]
  Your reply waits in Ready to send. Ignore tells Claude you've
  seen it and won't act on it.

● Give the go for stage 3                                       3h
└ → Go · not sent yet ↺ undo ✎ comment
● Choose how long the ledger keeps requests                     3h

STATUS ─────────────────────────────────────────── updated 12m ago
● Waiting on your review of Sessions & Runway, round 1
● Drawing Usage, round 2
● next: Usage, round 3
hide history
● now also drawing Usage, round 2                              12m
● no longer waiting on your review of Overview, round 2         1h
● now waiting on your review of Sessions & Runway, round 1      1h
show all 14

PARKED ──────────────────────────────────────── 3 to come back to
● Paper thumbnails inline in Ghostty                            1d
● A Space-aware sessions window                                 2d
● Request ledger: Export the ledger as CSV                      1d
show picked up 3

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
- **A session's project is a press** (17 November 2026, Lee). In the line
  under the tabs, `Dashboard redesign · Switchboard`, the project's name
  opens its view, as pressing the project in All projects does, home
  included, where there is no way back to reach it by. It is drawn dim, as
  the way back is, keeping the aside's quiet, and cut short with it. Every
  session's view has it, under a way back to the same place everywhere but
  home; at a width that drops the aside, it goes with it, and the way back
  is left to reach the project.
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
  Parked, Resolved. What waits on Lee comes first.
- **All projects**: this project first, then the busiest. Each project's open
  sessions hang off it as a tree. A project with nothing open, waiting or parked
  folds into one line at the bottom. A project opens its view. What a project
  has parked counts for it from every session filed under it, finished and
  idle ones included, so a project with something parked stays listed, and
  unfolded, though none of its sessions is current (11 November 2026).
- **A project**, reached from All projects, named as it is (`SitRep` stays
  `SitRep`): its sessions, this one first (`⌂`), each with what it is doing
  and its waiting count; Asks, every current session's asks, the newest
  first, each naming its session (`Request ledger: Keep the ledger…`) and
  answered right there as in a session's view, its old sessions at the foot
  of Sessions (see "Old sessions"); and Parked, every item parked in the
  project, finished and idle sessions' included, each naming its session by
  name, and what was taken off it. A project has no Resolved, and no
  history of its sessions' status: each session's is under its own Status.

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

  hide old sessions
  Export to CSV                                          finished 2d
  └ Shipping the export
  Settings tab                                               idle 9d
  └ next: Tidy the copy
  Ledger schema, first pass                              finished 12d
  └ Drawing the schema
  show all 7

  ASKS ─────────────────────────────────────────────────── 2 waiting
  ● Dashboard redesign: Review Sessions & Runway, round 1        2h
  ● Request ledger: Keep the ledger 400 days, or forever?        3h

  PARKED ─────────────────────────────────────── 2 to come back to
  ● Request ledger: Export the ledger as CSV                     1d
  ● Dashboard redesign: A tmux indicator                         2d
  hide picked up
  ● Request ledger: Rename the export · picked up by Request…    1h
  ● Dashboard redesign: Drop the old importer · closed by Cla…   4d
  ```

- **Another session** is the same view as this one, in the same order: its
  asks with buttons that answer them, its status, its project's Parked, its
  resolved. While no window has it, its foot (above Ready to send) has
  `✓ finish this session`, for a session Lee left with things open by
  closing the window. It asks first, in place:
  `Finish <name>? Its open asks stop counting.`, `[ yes, finish it ]`
  `[ cancel ]`. Yes writes the finish into that session's folder, in this
  window's own file there (nothing goes to its inbox: it is Lee's act on the
  pane, not a reply to Claude), and the pane goes up a level, the session
  gone from it. A session with a window is still being worked: Lee finishes
  it there by telling Claude.
- **A finished session's view** (17 November 2026, made in review),
  reached from its project's old sessions, says it is finished, and when,
  as STATUS says when it was updated, where another says it is closed:
  `Export to CSV · Northwind · finished 1d ago`. STATUS draws what was
  under way and what was next faint, so neither reads as going on, and
  where its finish gave a reason ends with it, `● finished: Shipped`. What
  it left open waits on no one: its asks, each with a faint `●` and a dim
  title, count nowhere, offer no reply and no snooze, and under ASKS'
  heading, which counts them apart (`nothing waiting · 2 left open`), a
  faint line says why: `Finished: its asks can't be answered.` An ask
  still opens, to its tree alone. A reply could only have gone into its
  inbox, and come back `not delivered: the session was finished`. One Lee
  queued there before the finish stays in Ready to send, and on its ask,
  saying `· not sent: session finished`, with its `↺ undo` and `✕` and no
  `✎`; a send leaves it out, writing nothing into the inbox, and `send`
  shows only while some other reply would go (see "One answer to an
  item").

  The session this window holds is the one exception: finished by Claude
  while the window still holds it, its view says finished, but its asks
  keep their answers (no snooze), `✎ Answer`, `✎ comment` and `✎ edit`
  among them, as a reply there goes in this window's own message, to the
  Claude right here, and settles its ask as any of this session's replies
  does. So this window counts its open asks as waiting wherever it counts,
  as its buttons say: the band, both tabs, ASKS' heading, its project's
  and All projects', though core, which no window holds, counts nothing of
  a finished session. A reply on its way to one takes it off those counts
  as any reply on its way does. In its project's Sessions it is drawn dim,
  `finished` on its right where `closed` goes, `finished · 1 waiting`
  while its asks wait, and it counts as open nowhere, in the project's
  view or All projects.

  One rule, core's `reaches`, decides all of it: whether a reply can reach
  an item from the window holding a given session, a parked item always,
  an ask where its session is not finished or is the one held. The board
  binds it to what it reads, as `canReach`; every reply's press, `✎ edit`,
  Ready to send, a send, the answering mode, the faint line and the mark
  go by that. The fold judges by it too: a reply a window's heartbeat
  carries, read from that window's heartbeat in the session's own folder,
  is the held session's own, so a finish voids none, and its ask waits on
  no one while Claude's turn runs; a line read from the files, which no
  window holds, a finish voids, and its mark, once delivered, settles it.
  Claude's board text goes by it as well (18 November 2026): a finished
  session's open ask waits on Lee where a window holds the session, as
  that window's buttons say, read by that window or by the CLI, which
  takes a live heartbeat for one; where none does, it `can't be answered
  (the session is finished)`, where it read `waiting on Lee` against the
  pane. It says nothing of joining it: only Lee's word joins one.

  What still works on a finished session's view stays: its project's
  Parked picks up as anywhere, to the Claude in this window, a finished
  session's items among them (see Delivery); its lists of the past open
  and fold; its project's name and the way back move the board. It has no
  `finish`, being finished. A window joining it again, as Claude's join
  does, reopens it, and its asks wait on Lee once more. Until that day no
  press reached a finished session's view.
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
  An ask whose session Lee snoozed comes after those waiting, the soonest to
  wake first, quieted (its `●` grey, its title dim), and hangs `snoozed until
  tomorrow 09:00` with `wake now`, which wakes its session; opened, it answers as
  any ask does (see "Snooze").
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
  projects, every project's. A snoozed ask counts on neither.
- Each view's first line sits under the way back's row.
- Every section heading has a few words on the right: `1 waiting`,
  `updated 12m ago`, `2 of 3 open`. Asks says what is
  snoozed too, where any is: `1 waiting · 2 snoozed`, or
  `nothing waiting · 1 snoozed`.
- **Status's history.** Closed, Status shows what is under way and what is
  next, and at its foot, while the status has ever changed,
  `show history 14`, counting the changes. Opened, it reads `hide history`,
  and the changes hang under it, the newest first, each a list's row: a
  faint `●`, the change's headline, and its age. The headline is what
  changed most: what is under way (`now wire up the export`, `now also
  …`, `no longer fix the login race`, ` (and 2 more)` after it), else what
  is next (`next is …`, `nothing next`), the name (`renamed to …`), the
  summary (`summary changed`). Opened, a change hangs its detail, each line opening
  with its label (`Added:`, `No longer:`, `Still there:`, `Next:`, `Name:`,
  `Summary:`) in the now colour, the text after it soft. It shows the latest
  3; with more, `show all 14`, then `show fewer`, as Resolved's does. It is
  a session's alone: a project's view has none (17 November 2026; see "Old
  sessions"). The changes are the board's
  own reading, each status compared with the one before (see Storage), so
  every session has its whole history from the lines it already holds. Each
  change is keyed by its session, its time and its writer, and where one
  writer changed the status twice in a millisecond, by its place among
  those, the older first: two blocks of one key leave the whole board
  undrawn (see "Measuring").
- **Old sessions** (17 November 2026, Lee). A project's view folds, at the
  foot of Sessions, every session filed under it that is not current:
  finished, or idle past its 7 days. Closed, it is `show old sessions 12`,
  counting them; opened, it reads `hide old sessions`, and they hang under
  it, the latest ended first, each drawn as a closed session is, even a
  finished one a window still holds: its name, dim, and on the right when
  it ended, `finished 1d` where it was finished, else `idle 8d`, since
  it last changed, so the two can be told apart; and under it,
  faint, what it was last doing, as Sessions says it. Its name opens its
  view, as a session's above does. It shows the latest 3; with more, `show
  all 12`, then `show fewer`, as the other lists do. Until then a
  project's view had the history of its current sessions' status there,
  each change cut to a word or two after its session's name, which each
  session already shows whole under its own Status; Lee, pressing `show
  history 266` in a project's view, expected the project's old sessions,
  which until then showed nowhere on the pane.
- **The toggles at a list's foot** are one press, shared: Status's history,
  Parked's picked up, a project's old sessions and Resolved's `show all`.
  Each is a plain press, drawn dim, at the list's foot, and only it opens
  and folds its list: opening or closing an item never changes how much a
  list shows. Folding a list closes an item opened in what it no longer
  shows. What each shows is kept with the rest of the pane's place: Status's
  history and Resolved per session, old sessions per project, and Parked's
  picked up per project too, the one list every view of the project draws
  (17 November 2026); closing the pane folds them all. A view draws its
  picked up, and a project's its old sessions, only once the look carries
  them (see "What a look carries").
- **Notes went** (17 November 2026, Lee). Notes mixed three things: notes
  Claude wrote, which Lee never looked at, and the status changes and
  pick-ups the board noticed itself. Lee wanted the notes gone, and the
  history kept where it belongs, under its own section, closed until asked
  for. So Claude has no note tool, the CLI no `note`, the board text no
  latest notes, and the pane no NOTES; Status keeps its history, and Parked
  what was taken off it. A note line already on disk is read for its id
  and its time alone: the id stays taken, so no new item is given it while
  Claude may still hold it in context; its time still dates its session and
  its count still counts, so the writer's next line counts on past it; and
  it posts nothing, no item and no change. A resolve or an edit naming it
  is refused as naming no item (`There is no item k3f9 on this board.`); an
  edit line already on disk changing only a note's `text` or `detail` is
  read the same, those fields ignored, so it too dates its session and
  counts. A note was never its writer being seen in its session: a resumed
  conversation takes up a session by its heartbeat, its items and its
  status alone, and a note's time is not among them. A
  board an older load saved in `$.state` may still hold a note among its
  items until the session folds again; drawing drops any item of a type it
  does not know, and keeps its id. The other way, the board this build
  keeps holds an empty `log`, which a build from before reads unguarded:
  back on a release (`app/plugin app`, a cask reinstall), its pane draws the
  board this one wrote rather than throw until it writes its own. A
  project's view there may still throw until its first look, 5 seconds at
  most, rewrites the projects.
- **Parked:** a section of every session's view, under Status, and of every
  project's, drawn while something is parked there or was taken off it, its
  heading counting what is parked (`2 to come back to`, or `nothing to come
  back to`). Each lists every item parked in the project, finished and idle
  sessions' included, and counts them all, in the order "Parked items are
  the project's" gives, a session named by its name, never by its id (11
  November 2026). A finished session's item
  shows as any other, with no mark of its own. Each is a list's row: a
  purple `●`, its title, and its age. Opened, its tree hangs from the mark:
  where to look, its `see`, and the pick-up once one waits or is on its way;
  `pick it up` sits under the tree until then, in a window holding a
  session of the item's project: another project's parked items show there
  without it. `✕ drop` sits after it, dim, in any window, and alone, drawn
  as any press, where it is not (18 November 2026; see "Dropping a parked
  item"). The pick-up queues in Ready to send
  like any reply, to this session whichever session of the project parked
  the item (see Delivery); once queued, `✎ comment` under it writes its
  comment in the prompt as an ask's is, which goes with it as its note (see
  "Answering an ask"). It is never
  counted: not on a tab, nor on the band.
- **Parked's picked up.** Closed, Parked lists only what is parked, and at
  its foot, while anything was taken off it, `show picked up 3`, counting
  the items Lee picked up or dropped, or Claude closed. Opened, it reads
  `hide picked up`, and those items hang under it, the newest taken off
  first, each a list's row: a green `✓`, its title and how it went, and how
  long ago: `Rename the settings tab · picked up by Export`, `Drop the old
  importer · closed by Claude`, or `Export the ledger as CSV · dropped by
  you`. Opened, an item hangs Lee's note on the
  pick-up, or Claude's reason for the close, and its `see`; or `nothing more
  was recorded`. It shows the latest 3; with more, `show all 5`, then `show
  fewer`. Every view of a project lists what any session of it parked,
  finished and idle ones included, naming the session that parked it as its
  Parked does: a project's each, a session's those another parked (17
  November 2026). A session's picked up is not split as its Parked is: its
  own items, unnamed, and those of the project's other sessions, named, are
  one list, the newest taken off first.

  Who picked it up is the session the pick-up went to, named as the pane
  names it everywhere, by its name as it stands. A pick-up's reply line
  says so itself: `to`, the id of the session its message went to, written
  as the reply is made (see Delivery). Nothing else on disk says it: a
  window's heartbeat in a session is rewritten as it joins it again or a
  resumed conversation takes it up, so which session a window held at a
  pick-up's time can't be read back, and a wrong name is worse than none.
  A pick-up written before its line said (17 November 2026) reads `picked
  up` alone.

- **Dropping a parked item** (18 November 2026). Lee: "allow us to drop
  parked items with an option… Ideally, it would just drop it, maybe with
  confirmation." Until then a parked item left Parked only by Lee picking
  it up or Claude closing it, so one Lee had no use for waited on Claude.
  The press drops it: Lee's own write, as a snooze or a finish from the
  pane is, with no round trip through Claude and nothing in Ready to send.
  - **Where it is offered.** An opened parked item has `✕ drop`, dim,
    after `pick it up`, as `✕ ignore` sits after an
    ask's answers: the session's own items, and every other session's of
    the project, live, idle, finished or moved there, in every view that
    lists them. It goes to no Claude, so another project's items have it
    too, where the pick-up is not drawn; there it is the only press, and
    drawn as any press, not dim, which would read as one that does
    nothing. It is not drawn while a pick-up
    waits on the item or is on its way to it, nor while Lee writes its
    note in the prompt, as the pick-up is not.
  - **It asks first, in place**, as Snooze's question and a session's
    finish do: the question and its answers in place of the buttons, the
    item opened still (`drop:<session>:<item>` as the pane's `selected`).
    `cancel` goes back to the buttons; the item's title closes it, question
    and all; opening anything else, going elsewhere on the board or closing
    the board ends it, as each changes what is opened. A drop has no undo
    on the pane, so no one press drops anything. Escape is not heard: it
    hands the keys back to the prompt, which the pane learns of only as it
    is drawn again without them, so the question stands until one of
    those, as Snooze's does. The three questions are drawn by one helper
    (kit.tsx's `drawQuestion`): the words, the answers, a dim `cancel`.
    Drawn docked, the session's own item opened, then asking:

    ```
    ● A priority badge across all tabs                          now
      [ pick it up ] [ ✕ drop ]
    ```

    ```
    ● A priority badge across all tabs                          now
      Drop it? It leaves Parked, and Claude no longer sees it.
      [ yes, drop it ] [ cancel ]
    ```

  - **Yes writes it at once**: a line, `{ "type": "drop", "item": "p1" }`,
    in the session that parked the item, in this window's own file there,
    as Lee's finish of another session is written. The session is found by
    its id, as every press's ref is (actions.ts's `kept`), so one moved to
    another project since is written in the folder it was started in. In
    the held session it goes through the hold, a change Claude did not
    make. Nothing goes into an inbox, and nothing to Claude. It is checked
    against the session as it stands (core's `checkDrop`): an item no
    longer parked writes nothing, a toast saying how it left (`Not
    dropped: it was picked up already.`, `… Claude closed it already.`, `…
    you dropped it already.`), and nor does one Lee's pick-up is on its
    way to (`Not dropped: your pick-up of it is on its way to Claude.`),
    since Claude would be told to pick up what the board no longer holds.
    Another session than the held one is read afresh after any press that
    writes into it or queues a reply to it, a finish among them, off the
    board or not, so a finished or idle session's item leaves the view at
    once, not at the next whole look; a session idle past the views,
    finished from its view, shows finished in its project's old sessions
    the same way.
  - **What it does to the item.** The fold closes it as of the line,
    `dropped`, Lee's (`closedBy` `drop`). The first close stands: a drop of
    an item picked up or closed changes nothing, nor does one naming an
    ask. A reply on its way to it goes void, `dropped`, so a pick-up in
    Ready to send meanwhile reads `· not sent: you dropped it`, and no send
    carries it. The line moves no session's time, as no line about a
    parked item but its park does; nor does one naming an ask or no item,
    which changes nothing. The item leaves Parked for its project's
    picked up, `dropped by you`, which opens to its `see`, or `nothing more
    was recorded`.
  - **What Claude reads.** The board text lists only what is parked, so it
    lists the item no more, and the board having changed rides into
    Claude's next turn as any change does, where Claude had been told of
    the item. A resolve of it passes quietly, as of anything Lee closed:
    `k3f9 was dropped already by the user: nothing to resolve.` The
    tool's description tells Claude so beforehand: a parked item may be
    dropped by the user, so one gone that Claude didn't close was dropped,
    to leave, parked again or reopened only at the user's word; else it
    reads the same as a write that was lost.
  - **A pick-up held in another window.** No heartbeat says a pick-up of
    another session's item (under Delivery), so another window's, claimed
    before the drop and held for its Claude's turn, would otherwise go in
    after it, minutes later. A held send is read again as it goes
    (deliver.ts's `goingNow`): each pick-up whose item has left Parked
    since the claim, dropped, picked up from another window or closed by
    Claude, is left out, and the message written again from the lines
    left, each reply's line kept on the claim (`lines`) as the send makes
    it. The held session's own items are judged as any other session's,
    so Claude's own close of one mid-hold leaves its pick-up out too. Each
    session the pick-ups name is read once a pass, the folders listed once
    for them all, so the read adds little between the turn's end and the
    submit. Ready to send, the send carrying it no more, says why at the
    next look (`· not sent: you dropped it`, `· not sent: Claude closed
    it`); a send left with nothing is let go, as a take-back lets it go,
    and the next held goes in its place, in the same pass. A session that
    does not read at all is no word that its item left, so its pick-ups go
    as claimed; one read in part, a log's read failing, can show an item
    gone that is not, and its pick-up is held back, safely, in Ready to
    send again for Lee's next send. What is left is a drop landing between
    that read and Claude Code taking the message, milliseconds; there
    Claude has the pick-up, and it is written down as given, as the board
    never denies Claude what it was told: the item stays dropped, the first
    close standing, as of two windows' pick-ups of one item. A claim an
    older load made carries no lines, and goes as claimed. Where the
    session that parked the item moves to another project mid-hold, the
    message goes as sent, as "A window that changes project" under
    Delivery has it.
  - **Claude's `reopen` brings it back**, as it brings back any parked
    item picked up or closed: into Parked and Claude's board text again.
    A drop has no undo on the pane, so a word to Claude in the chat is
    Lee's way back, which refusing the reopen would take away. Claude
    reopens only on purpose, by the item's id, and the board text no
    longer lists a dropped item, so nothing leads it to reopen one unasked.
  - **The CLI has no drop**: it acts for Lee on asks (`answer`), snoozes
    and finishes, never on a parked item. Its `board` and `list`, and
    `watch`, read the line as the mod does, the item gone from Parked and
    from what counts it, in the shapes they had: `board --json` lists only
    what is parked and `watch` counts it, so neither's version moves.
    SitRep changes nothing.
  - **Older readers** skip the line, as they skip any kind they do not
    know: a mod or a CLI of 0.7.1 or before reads the item still parked,
    and lists it in Parked, Claude's board text and SitRep's counts, until
    it runs a release that reads it. Back on such a release, a load reading
    the board this build saved in `$.state` draws a dropped item as picked
    up until its next look. Nothing is rewritten, and the line format stays
    1.

### Answering an ask

An ask wants one of three things back, and that chooses its buttons. No
shape is ever shown as a word:

| Claude asks for | Buttons |
|---|---|
| **a yes**: a go, an approval, "it works", "done" | `✓ <its yes>` · `✎ comment` · `✕ ignore` |
| **a choice** | one button per option, the one Claude recommends ending `· recommended`, in a darker lilac, inside it · `✎ comment` · `✕ ignore` |
| **words**: an answer, a command's output, feedback | `✎ Answer` · `✕ ignore` |

- **The yes is in Claude's words.** Claude gives the button's label as the
  verb Lee is giving: `✓ Go` on "Give the go for stage 3", `✓ Approve`,
  `✓ It works`, `✓ Ship it`. A word or two, 20 characters at most.
- **What the words are.** A words ask may say what its words must be, in a
  few words, as `needs`: "the command's output", "which frames you'd
  change". It hangs first from the ask's mark, in the ask's colour, as
  `needs: the command's output`, while the ask is opened. Only a words ask
  takes it.
- **The option Claude recommends** (13 November 2026). Claude often leans
  toward one option of a choice, and wrote "(recommended)" into the
  option's text, so the word showed inside the option, and at times twice.
  A choice ask takes `recommended` instead, on the ask tool and the CLI's
  `ask` (`--recommended <choice>`), and the tool asks Claude to give it
  whenever it leans:
  - **What it is.** Optional, and a choice ask's alone: the text of one of
    its options, as stored. Given on a yes or a words ask it is refused
    (`Only a choice ask takes recommended: one of its options.`), and so
    is one naming none of the options (`recommended names one of the
    options, in its words: “Ship it” or “Redraw”.`), and one that is not
    text (`recommended is text: one of the options, in its words.`).
  - **A marker Claude still types** is read as the field and stripped from
    the option's text, any case, one marker after another until none is
    left ("Ship it (recommended) (recommended)" is "Ship it"):
    - the word in parentheses or brackets ending the option, "strongly"
      or "highly" before it there, a full stop or a bang after ("Ship it
      (Recommended)", "Ship it [recommended]", "Ship it (strongly
      recommended).");
    - the word after a dash ending the option, a full stop or a bang
      after: a hyphen with a space before it, an en or em dash with or
      without ("Ship it - Recommended", "Ship it—recommended");
    - the word in parentheses or brackets with more words after, the
      spaces tidied ("Ship it (recommended) — ships today" is "Ship it —
      ships today");
    - brackets that start with the word and go on after a comma, a
      semicolon, a colon or a dash, keeping what follows ("(recommended,
      fastest)" is "(fastest)");
    - "Recommended:" before the option ("Recommended: Ship it").

    Each wants something left beside it. Nothing else is read: the word
    negated or qualified ("(not recommended)", "– not recommended",
    "(recommended by Apple)"), a hyphen with no space ("self-recommended",
    "non-recommended"), and an option about recommendations ("Use the
    recommended defaults") are left alone. Two options marked, or one
    marked and `recommended` naming another or clearing it, is refused
    (`Recommend one option: …`); the same option marked and named is fine.
    Two options that become one once stripped, leaving fewer than two, are
    refused naming it (`A choice ask needs at least 2 options: “Ship it”
    is given twice, once marked recommended.`). Options given in an edit
    are read the same way. (Until the review of 13 November 2026 only the
    word ending the option was read, in brackets or after a dash a space
    set off, so the rest showed it twice.)
  - **Asks posted before markers were read** may keep one in an option's
    stored text. An option is named by its exact words first, then by its
    words without their markers, either way round: an edit's `recommended`
    ("Ship it" for "Ship it (recommended)"), which takes the option in its
    own stored words, so Claude is never refused in a loop; the fold's
    reading of `recommended` against the options, so an edit re-sending
    the option stripped keeps it recommended; and the CLI's `answer`, which
    writes the option in its stored words.
  - **Claude's order of options is kept**; nothing is reordered.
  - **Drawn once, inside its option's button.** The pane ends the
    recommended option's label with the word, after a middle dot, in a
    darker lilac than the button's own (`[ Redraw · recommended ]` in the
    terminal): the Button's children, the option and a Text in the
    board's `recommended` colour, `#7178c7`, its `label` still the option,
    naming the control. The button is the primary already, whose lilac
    marks it; the word is quieter than the option's words, and plainly
    lilac. `#7178c7` is Claude Code's dark-theme `suggestion`, the lilac a
    primary button paints, `#b1b9f9`, at 75% of its OKLCH lightness, its
    hue kept, and its chroma raised from 0.09 to 0.12: that lilac darkened
    alone (`#7f85b3`, or its OKLCH darkening `#757bb7`) all but matches the
    board's grey `#7a82ab`, which is a lilac grey. Not `dimColor`: Claude
    Code draws a `dimColor` run in the theme's dim colour, a grey, whatever
    the colour around it. The same elements on every surface, each drawing
    them in its own way. The option recommended is the primary button;
    with none, the first, as before. The board text Claude reads names it once after the options
    (`options: Ship it | Redraw; recommended: Redraw`), `board` prints that
    text, `board --json` and `watch` carry it (`recommended`, null where
    none), and the CLI's `answer`, refusing an answer, names it once among
    the options (`answer it with “Ship it” (recommended) or “Redraw”.`).
    No band or row shows an ask's options, so none shows it; since 24
    November 2026 the asks panel ends the recommended option's row with
    the word, and a banner's buttons, which list the options, leave it out
    (see "Answering from the panel"). Lee's
    reply when he picks the option is the option alone, as ever
    (`→ Redraw`), never the word. Being the button's own, the word wraps
    with its label: on a narrow pane or a phone a long option wraps inside
    its brackets (`[ Redraw every frame, then ship ·` over `recommended ]`),
    so the word can never seem to mark the option below. The tests prove
    that wrap through their own reading of the drawing as rows
    (`tests/drawn.ts`, which wraps a Button's words in its room as the
    terminal does), since the kit paints nothing. (Lee, 17 November 2026:
    until then the word was dim grey, hard to see, and came after the
    button, so a long label left it on a line of its own over the next
    option, reading as that one's. #150 then drew it in the ask's amber,
    before the button, wrapping as a pair with it, so a long option took
    the line under the word. Lee, the same day, live: too much gold, with
    the `◆` and the `see` line amber already, and outside the button; the
    button's lilac, the primary's, marks it already. So the word went
    inside the button, in a darker lilac, and the amber went.)
  - **An edit** sets it, or clears it with an empty one. One changing the
    options keeps it while its option is among them; where its option is
    gone, or the ask wants a choice no more, it goes with it, and the
    edit's answer says so (`Edited k3. Its recommended option “Ship it” is
    gone, so it recommends none now.`), refusing nothing. Gone, it does not
    come back with its option.
- **Ignore** tells Claude Lee has seen it and won't act on it.
- **Snooze** follows the buttons, dim, on an ask waiting on Lee: none while
  it waits on Claude (Lee's comment) or on a reply of Lee's on its way, once
  it is snoozed, nor in a finished session, where nothing waits on Lee; nor
  while no choice is offered, every one off or the clock past those on
  (17 November 2026). It asks in place, the buttons giving way to `Snooze
  this session? Its asks, and your turn there, stop counting until it
  wakes.` (13 November 2026; `Snooze it? It stops counting until it wakes.`
  until then) over the choices offered (see "Snooze"), then `[ cancel ]`;
  a choice writes the session's snooze and closes the ask, cancel goes back
  to the buttons, and the ask's title closes it (see "Snooze"). Should the
  clock pass every choice while the question stands, the ask's buttons
  come back in its place, with no snooze.
- **What a reply does once Claude has it:** a yes, a choice or an answer
  closes the ask; ignore drops it; a comment leaves it open, replied, for
  Claude to act on.

**Lee writes in Claude Code's own prompt box**, where a paste works, and the
words still wait in Ready to send with everything else, sent in one go. An
answer with an image attached waits there too, the image saved as a file
its words name (see "An answer with an image", below).

1. `✎ Answer` (a words ask) or `✎ comment` (a yes or a choice) puts the
   window in **answering** mode for that ask; `✎ comment` under a queued
   pick-up (step 4) puts it in the mode for a parked item's pick-up, all
   that follows holding for it as for an ask. It is held in `$.state` (`answering`: the item, whether it
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

   (`comments on` for a comment, and for a pick-up's note once the
   pick-up is queued, as after a Go; `picks up` for a pick-up only where
   none is queued, as after `↺ undo` while the mode stands; a comment that
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
   around it kept in place. An empty Enter is not taken: a toast says why,
   the prompt stays in the box, and the mode stands. One with something
   attached is queued too, each attachment saved as a file (below).
4. **Queued, the reply shows on one row**, under the ask and in Ready to
   send: its words clipped to a line, `+3 lines` when there are more, then,
   under the ask, `· not sent yet ↺ undo ✎ edit`. `✎ edit` enters the mode
   again for that reply, the prompt filled with its words (still only from
   an empty prompt), and the next Enter replaces them. A bare yes, choice
   or pick-up offers `✎ comment` there instead, which adds its note. So a
   parked item offers only `pick it up`, beside its drop, and a comment
   follows the pick-up as one follows a Go (Lee, 23 November 2026; until
   then the item offered `✎ with a comment` beside `pick it up`, and a bare
   pick-up offered no comment).
5. **One send carries everything**, as ever.

**An answer with an image** (23 November 2026). An Enter the mode takes
with something attached waits in Ready to send, as any reply does. Lee
decided it the same day: an image comment is queued as a typed one is, and,
being queued, one works for a session in another window too. Until then it
rode in at once (the ride, below), because `prompt.submit` gave a plugin an
attachment's kind alone. The engine now reads the bytes: `$.prompt.media({
id })`, inside a `prompt.submit` hook, `e.attachments[].id` the handle,
base64 in slices of up to 4 MiB, `next` going on.

- **Saved.** While the hook is in flight, each attachment is read whole and
  written to a file of its own, `<root>/media/<name>.<ext>` (see Storage):
  16 random characters, then the extension its type names (`png`, `jpg`,
  `gif`, `webp`, `pdf`, else its subtype, else `bin`). `$.fs` writes only
  text and removes nothing, so a process writes the bytes and removes them
  (hooks/media.ts): `/bin/sh -c 'umask 077 && mkdir -p "$1" && chmod 700
  "$1" && /usr/bin/base64 --decode > "$2"'`, the base64 on its standard
  input and each path an argument, never in the script, the folder 0700 and
  the file 0600; `/usr/bin/touch -c --` and the paths to mark them sent;
  and `/bin/rm -f --` and the paths. Each runs from `/`, so a worktree
  removed under the window breaks none. A read is whole only once its
  slices end, each `next` past the one before, and its bytes come to the
  `size` the engine gives; else it can't be saved.
- **The words.** Each image takes its placeholder's place, `[Image #1]`
  becoming `[image: /…/sitrep/media/k3x9….png]`: the placeholders, lowest
  number first, take the images in the order attached. An attachment no
  placeholder places, a document among them, goes at the end, after a
  space, or on a line of its own after words of several lines. Nothing
  in the types ties an attachment to its number, so Claude Code's own order
  is trusted: a placeholder Lee deleted while its image stayed attached
  would shift the images after it (a live check). The board shows each
  saved file short (below), and `✎ edit` puts the words back in the prompt
  with the path, since words that no longer name a file remove it. A
  message any of whose lines names one ends with
  one line more, `Each [image: …] or [document: …] above is a file the user
  attached: open it with your Read tool.` It is decided from the replies'
  notes, and only by a path a save gives, `<…>/sitrep/media/<name>.<ext>`,
  never by other words in the same brackets (core's `messageText`, so a
  send, an inbox's delivery and a held send written again all carry it):

  ```
  From the board:
  - Ship round 2, or redraw? → comment: “Frame 2 [image: /Users/me/.local/state/sitrep/media/k3x9m2qa7d0f8hzc.png]”
    This leaves the ask open: act on it, then resolve it.
  Each [image: …] or [document: …] above is a file the user attached: open it with your Read tool.
  ```

- **Shown short** (Lee, 23 November 2026). Every surface that shows Lee a
  reply's words shows a saved file as Claude Code's prompt shows an image:
  `[Image #1]`, or `[Document #1]` for a document, each kind counted on its
  own. The number in Claude Code's placeholder is only its paste counter
  for the session, so here `n` counts the saved files within that one
  reply's words, in order: 1, 2 and so on. A file is told by the hint's
  rule, a path a save gives; other words in the same brackets stay as typed
  and count for nothing (core's `shownWords`). So the row under the ask,
  Ready to send's row, `you commented: “…”`, a picked-up item's note in
  Parked and a resolved ask's answer read `comment: “Frame 2 [Image #1]”`
  (core's `shownAnswerOf` on one row). A row clips after the change, so
  `[Image #1]` shows whole where it fits. The path stays in what is stored,
  in the words sent to Claude (the send, an inbox's delivery and a held
  send), in Claude's own reading of the board (`replied (…)`, which
  `sitrep board` prints too), and in `--json`'s `words`, which a script may
  need. The Mac app and the terminal view show no reply's words at all.
  Until then the board showed the words as they were: live, a queued row
  read `“[image: /Users/…/.local/state/sitrep/me…`, Lee's own words pushed
  out of view.
- **Queued** then as words alone are (step 3), the prompt dropped with
  `Your comment waits in Ready to send.` or its like: to any session's
  item, not only the held one's, the words going wherever the reply goes.
- **The ride where any can't be saved**: audio, an attachment with no `id`,
  a read answering `{ unreadable }` or `{ deny }` or failing or falling
  short, a write that fails. What was saved of it is removed, a file begun
  by a failed write among them, and the prompt rides in as it did before
  (below): nothing worse than before. For another session's item the ride
  is refused as before, its toast saying first that `The attachment
  couldn't be saved, so it can go only to this window's session: …`.
- **A submission given up** while its attachments were saved (the hook's
  `next.signal` aborted) queues nothing, and its files are removed; the
  mode stands.
- **Claude's Read of a saved file runs with no prompt.** The media folder
  lies outside every working directory, so the engine's check would ask at
  every send, and an inbox's reply in a window nobody watches would wait on
  it. The `tool.check` hook turns that ask into an allow for a Read whose
  `file_path` lands, every link and `..` followed (`$.fs.stat`'s
  `realPath`), directly in the media folder, itself resolved, named as a
  save names a file. A deny stands, and every other call's verdict is as it
  came.
- **A reply owns the files its words name**: a path directly in the media
  folder, named as a save names one, so no words name anything else for
  removing. A file goes once no reply names it without having gone anywhere:
  `↺ undo`, `✕` in Ready to send, `cancel all`, `✎ edit` taking words that
  no longer name it, or a button's reply in place of it (`changeQueue`, run
  by those presses and the mode's Enter). Two ways a reply leaves Ready to
  send remove nothing, and the sweep takes what they leave: an inbox write
  that fails, whose replies are put back, and the ride's displaced reply,
  put back as it was (the ride's words never name a saved file).
- **A sent reply's files stay** for the Claude it went to. Claude opens one
  in the turn the send starts, after the send is written down, and a reply
  sent into another session's inbox is read only at that window's next
  delivery, however much later. So a send, written down or written into an
  inbox, marks the files its replies name changed now, one `touch` for all,
  and the window sweeps the media folder at every session start: a file
  named as a save names one, changed over 14 days ago, that no reply in its
  own Ready to send names is removed. A reply that waited long in Ready to
  send is so counted from its send, never its save. The sweep sees this window's Ready to send
  alone, `$.state` being each window's: a file only another window's Ready
  to send names, waiting there over 14 days, is swept from under it.
- **What the test kit can't do.** It answers no `$.prompt.media` (`no
  implementation for prompt.media`, and no event a test answers it on). So
  the save, and the mode's Enter with one saved, are tested on a host with
  no engine beneath (tests/media.test.ts, tests/answering-media.test.tsx);
  the engine's tests take the ride, the send's words, the removals and the
  sweep. Not yet tried live.

**The ride** (5 November 2026; the answer with an image until 23 November
2026, its fallback since). Lee answered an ask in the
prompt with a screenshot attached, and the board refused it as words alone;
Lee: "they're just paths that pass through. We need to make that work." An
image couldn't wait in Ready to send then: `prompt.submit` gave a plugin each
attachment's kind, type and file name, never its bytes or a path; a
plugin's own `$.prompt.submit` expands no pasted image; and Claude Code
caches only pasted text. So an Enter the mode takes with an attachment it
can't save is not dropped: Lee's own prompt goes in now, its text rewritten as the
board's words for that one reply (`From the board:` and the reply's line,
as a send words it), its attachments passing through untouched. Claude Code
keeps the image's blocks and puts the new text in place of the typed text
(read from 2.1.318's code).

- **The words.** The submitted text keeps `[Image #1]` where each image sits
  (2.1.318 expands pasted text in place, an image's placeholder as typed),
  so the reply's note keeps it too, and Claude reads where each image
  belongs. An image alone answers as its placeholder: `answer: “[Image #1]”`.
  One with no text at all, as nothing marks where it sits, is an empty
  Enter, not taken.
- **The reply** is built as a queued one is: an answer, a comment, a
  pick-up's note, or a comment going as the note of a yes or a choice
  queued on the ask, which goes with it. It goes only while a send would
  carry it, the session read afresh first, as a send reads it, and again
  once it is claimed (below): it fits the ask, the ask is open, and no
  answer is on its way to it. Else the prompt is kept, a toast saying why,
  in Ready to send's words (`Not sent: already answered.`, `Not sent: it
  has changed since.`, `Not sent: Claude closed it.`). Where a send carries
  the ask's reply already, the mode is over, and the prompt goes on as any
  prompt of Lee's does, the board's context with it.
- **Only to this window's session.** The prompt goes into this window's
  Claude, so an ask of another session can't take it: the prompt is kept,
  with `The attachment couldn't be saved, so it can go only to this
  window's session: take it out to answer in words, or answer from that
  session's window.` (`An attachment goes only to this window's session: …`
  until 23 November 2026, when the ride became the fallback.) A pick-up takes
  one whichever session of the project parked its item, since every pick-up
  goes to this window's Claude (11 November 2026; see Delivery).
- **On its way from the start.** Before the prompt goes on, the reply is
  claimed as a message in flight, as a send is (see Delivery): its id fixed,
  its text the rewritten prompt, and the reply frozen in Ready to send in
  place of whatever was queued on its item, so no send carries that as well.
  What was queued there is kept on the claim, in `$.state`, to be put back
  should it not go in (builds before read the claim as a send). It is
  submitted already, by Lee's Enter: never held, so never taken back, and
  never submitted by the window. Ready to send draws it whole, `⧗ Sending.`
  under its reply, never as one of the held sends' rows: short of room it
  keeps its rows as the first send does. While the window is stopped, the
  sends behind it offer no `↑ send now`, which could submit nothing ahead of
  it: they say `⧗ Goes after your next message.`. It goes ahead of the
  sends the window holds, which wait for it to end and for its turn to
  start, as behind any message submitted first; that wait counts its 30
  seconds only from a moment between turns, as Claude's turn ending, since a
  prompt typed while a turn runs waits in Claude Code's queue until it ends,
  or is folded into that turn and starts none of its own. The heartbeat says
  it, so its ask is on its way to every reader at once, and the mode ends.
- **Read again once claimed** (17 November 2026). The claim takes nothing
  while a send in flight carries a reply to the ask. Once it lands, before
  the reply is frozen, the session is read afresh again and the reply
  judged as before, its own answer on its way, which this window's
  heartbeat says from the claim, barring nothing: an answer is its own by
  its id and its writer both, since two windows can draw one id. A send of
  this window's taken and written down since the first read has left no
  claim for the claim to meet, but its lines are down, since a window
  writes a message down before its claim ends; so the ask reads answered.
  Another window's answer is read there once that window's heartbeat says
  it, or its lines are down: one claimed ahead of this but not yet said
  there goes unseen, a gap two windows on one session had already. The
  read draws nothing, so a board that fails to be kept fails no read; a
  session that no longer reads by then has changed (`Not sent: it has
  changed since.`). Left out there, the claim is let go, with nothing
  frozen to put back, and the prompt is kept, a toast saying why as above.
  The mode stands again only where its ask still takes its reply, as a
  comment's does with another answer on its way, and Lee began no other
  meanwhile: on an ask answered or closed, the prompt kept in the box would
  otherwise answer it at Lee's next Enter. Until then the claim met only
  the messages still in flight: a test holding it back while a send was
  taken and written down had Lee's answer go in after the send's, a second
  answer to the ask.
- **Taken**, the prompt's `next` resolving with no drop, or a turn starting
  with its text, it is written down as any taken message is, the lines a
  send writes, through the hold; a write that fails, or a load cutting it
  short, is written at the next look or load. No quiet lets it go while the
  hook that let it in still waits on Claude Code, which delivers it, not the
  window; one a load or the conversation's end leaves behind is let go as
  never taken once the window has gone quiet without its turn, as a
  message submitted and not yet heard is. So let go, what was queued on its
  item is put back, and a toast says `Your answer with the image didn't go
  in: write it again.`: its image went with the prompt, and nothing on the
  board holds it.
- **Dropped beneath**, by another plugin's hook or Claude Code, it is let go
  silently: what was queued on its item is put back as it was, and the mode
  stands again, unless Lee began another meanwhile. Claude Code puts the
  prompt back in the box. A failure beneath, a hook throwing or timing
  out, lets it go too, the mode not standing again, the prompt having gone
  on in some form. Failing to read the session again once it is claimed,
  or to freeze the reply in Ready to send, before the prompt goes on lets
  it go as well, and Lee's words and image go in as a plain prompt, nothing
  on the board recording them; failing to put back
  what was queued, once it is let go, can leave its reply in Ready to send,
  no longer frozen. A drop by a plugin whose hook runs above
  sitrep's is never seen, `next` hearing only what is beneath: the reply is
  written down delivered all the same, a gap the mod cannot close.
- **Typed while Claude's turn runs**, `prompt.submit` fires at Enter, with
  that turn's id (2.1.318 queues the prompt with its screening begun, and
  the engine's types say so): `next` resolves then, and the reply is
  written down while the prompt waits in Claude Code's queue for the turn to
  end. A prompt Lee pulls back out of that queue never goes in, though the
  board has it delivered; nor does one whose hooks an interrupt cancels
  (`wasCancelled`), which still resolves `next` with no drop. Sends share
  the second gap.
- Like the board's own message it takes no board-change context, which
  rides in with the next prompt. It is still Lee's input: a prompt that goes
  on leaves the window stopped until its turn starts, and one dropped lifts
  the mark (see "Held for Lee's input", under Delivery).

**The mode is safe to be in:**

- **One Enter only.** It ends with the prompt it takes, and never takes a
  second.
- **Always shown.** The band shows it the whole time it stands, on the surface
  it was begun on, and it stands exactly while the next Enter there would be
  taken. Once its ask can take the reply no longer (closed, or a parked item
  picked up, closed or dropped, an ask's session finished but for the one this
  window holds (`reaches`; a parked item's session finished ends
  nothing), for an answer another already on its way, a send
  carrying the reply its comment would join) the band is back to its
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
  closing, an ask's session finished, a send carrying its reply, another ✎, the
  window letting go), the mode takes back the words it put in the prompt for
  `✎ edit`: still just those, the box is emptied, so no Enter sends the pane's
  words to Claude; changed since, they are left as Lee has them, and a toast
  says so.

**Surfaces.** The terminal's prompt is read, filled and heard, so it gets
all of this; the phone over mosh is the terminal. Claude's app (the
`mobile` surface) sends its prompt through the Remote Control bridge, which
the hook hears (so the engine's types say; not yet tried live), but the mod
cannot reach its box: `✎ Answer` and `✎ comment` work there, a pick-up's
among them, and `✎ edit` is not offered. Desktop and VS Code send theirs some way
not yet seen, so they offer nothing to write: a words ask is only ignored
there, a parked item only picked up, and Lee says the rest in the chat.

**What Claude reads.** A reply's line gives an answer under what its words
are (`- Run the export → the command's output: “v1.2.3”`, `answer:` where the
ask said nothing), a yes in its own words (`→ Go`), a choice as its option,
and a note as `with a comment`. A note of one line is quoted on the reply's
line. Words of several lines (pasted output) go under it, fenced and
indented, each line as typed, the fence longer than any run of backticks
inside; so does any note of several lines, a comment's or a pick-up's alike.
Under each ask's last reply in the message, one line says where the
message leaves the ask (13 November 2026), from every reply it carries to
it: a yes, a choice, words or an ignore closes it, and so does a yes or a
choice with a comment riding along from Ready to send, `This closes the
ask: nothing more to do with it.`, whatever else the message carries to it;
a comment alone leaves it open, `This leaves the ask open: act on it, then
resolve it.`, unless an answer of Lee's to it is on its way apart from the
message, when the line says that answer closes it, `An answer from the
user to this ask, sent apart from this message, closes it.`, saying nothing of
where or when it arrives. That answer may be in another board's send to
the inbox, or the CLI's; in a send already in flight from this window,
ahead of this one in its queue, which Claude may have already; or in
another live window's send, which reaches that window's Claude. Its own
message says it closes. A pick-up has no such line. Until then the line gave the reply alone, and Claude, reading a choice
with a comment as an ask still open, resolved it and was refused.

````
- Run the export → the command's output:
  ```
  exported 42 rows
  done in 3s
  ```
  This closes the ask: nothing more to do with it.
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
`to Request ledger`, a session of another project with its project's name);
a pick-up is always `to this session`, whichever session of the project
parked its item (11 November 2026; see Delivery). Each reply hangs off its
item with a `└`, on one row: its words clipped to a line, `+3 lines` where
there are more, and `✎ edit` to write them again in the prompt (`✎ comment`
on a bare yes or choice). Each has its own `✕`, and
the ask shows `↺ undo`. **send to Claude** sends them; **cancel all** clears
them. Each send of Lee's the window holds for Claude's turn, or that is on
its way to Claude Code, leads the box as a group of its own, sealed (see
"A send is sealed", below); send and cancel all reach only the replies
under them, still to send.

**Docked**, the box stays still at the foot of the pane, under the pane's
list, which scrolls between it and the header; the list's last
line scrolls clear of it. **Inline** (the phone) it sits at the end of the
content. Each of its lines keeps to one row, cut short, so its height
follows from what it holds. Docked it takes under half the window: a queue
too long for that lists what fits and ends `… 3 more`, still one box. The
first send on its way keeps its heading, its line and its take-back however
little room is left; each send after it, short of room, is one row under
it, `⧗ Then: Review round 4 +2` with its own `↺ take back`
(`⧗ Then, to Request ledger: …` for one not to the session held), the
replies it names counted as shown (5 November 2026). Those rows come
before any reply, the first send's own among them. With no room for a row
each, the last row stands for the sends left over, one at a time,
`⧗ Then: Review round 4 · 1 of 3`, with `› next` stepping to the next of
them and the take-back of the one it shows, so every held send's
take-back is in reach; that row shows however little room is left, and
the pane keeps which send it shows until it closes. A send to a session
the board has not read still shows, headed `on its way to` that session
as its project's briefs name it (`to another session` where they do not),
its line and take-back under it. Only
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
written into other sessions' inboxes. It never waits for Claude's turn to
end, which can take minutes, nor for Claude Code to take the message. A
send that Claude Code refuses still toasts and leaves its replies queued,
and the pane, opened again, shows them, save one refused as Lee had
stopped Claude's turn, which waits for his next message (see Delivery); a
send that sent nothing leaves the pane open. A docked pane stays open.

**Taking a send back** (22 October 2026). While the window holds Lee's send
for its turn (see Delivery), Ready to send says so under the replies it
carries, `⧗ Waiting for Claude's turn to end.`, with `↺ take back` beside
it; the replies stay above it, frozen, and their asks say `on its way`.
Taking it back lets go of its claim: its replies are in the queue as they
were before the send, each with its `✕`, `↺ undo` and `✎ edit` again, its
asks wait on Lee again at once, and send sends them again. (From 4 to 5
November 2026 a second line said when Claude's turn seemed only to wait on
its background work; see "Held behind a subagent's run", under Delivery.)
Once the window has submitted it, it is Claude Code's, and nothing takes it
back out of Claude Code's queue: the line says `⧗ Sending.` and the
take-back is gone. While Lee has stopped Claude's turn and Claude Code
refuses the window's prompts (see "Held for Lee's input", under Delivery),
the first send held says `⧗ Interrupted: goes after your next message.`
across the box, with `↑ send now` and its take-back on a row of their own
under it, at the right where every take-back is, and each send behind it
says `⧗ Goes after your next message.`, no turn of Claude's holding them.
(Until 6 November 2026 the line wrapped beside the two buttons, over three
rows on a docked board; Lee chose the row of their own.) The
inbox's message offers none: Lee sent its replies from elsewhere. Until 5
November 2026 the line stood where send and cancel all were, for the
whole box.

**A send is sealed** (5 November 2026). Lee, that day: "If the queue is
ready to send, but it's waiting for Claude to be ready to accept it, then
if I add new items (whether they're asks or picking up from the parked
queue), they should not be put into that ready-to-go list. They should
create another queue, which I can then separately send to Claude, and it
will go separately." A send the window holds is a group of its own,
headed `on its way to this session`, its replies frozen under the heading
and its line under them, however they were written, on the board or in
the prompt, and with nothing else queued as with more. A reply Lee queues
after it, an answer, a comment or a pick-up, on the board or in the
prompt, joins none of it: it starts the queue still to send, under
the held send, headed `to this session` as ever, each reply with its `✕`,
`↺ undo` and `✎ edit`, and send and cancel all under it all. Send makes
that queue a second send, sealed and held as the first, with its own
take-back; each goes in as its own prompt, in the order sent, the second
once Claude's turn on the first has ended (see Delivery). Taking back
either puts its replies back among those still to send, in the order Lee
replied, the queue there already or not; a send behind it stays held, and
goes in its place. Refused or never taken, a send lets go of every send
behind it too, all their replies back among those still to send, one toast
saying so (see Delivery). A send that goes in at once leaves nothing
behind, and replies after it start the queue afresh.

```
╭───────────────────────────────────────────────────────╮
│ READY TO SEND                               2 replies │
│                                                       │
│ on its way to this session                            │
│ Review round 1                                        │
│ └ → Approve                                           │
│ ⧗ Waiting for Claude's turn to end.       ↺ take back │
│                                                       │
│ to this session                                       │
│ Review round 2                                      ✕ │
│ └ → Approve ✎ comment                                 │
│                                                       │
│ [ send to Claude ] [ cancel all ]                     │
╰───────────────────────────────────────────────────────╯
```

Until then a reply queued while a send waited joined its group, under the
one line saying the send waited, which stood in place of send and cancel
all, so nothing sent it: the send carried only what it was claimed with,
and when it went in the reply stayed behind in Ready to send for another
press ("the first one goes and the second one stays behind"). A press of
send meanwhile, had there been a button, claimed nothing, the window
holding one message at a time.

A group sent into another session's inbox stays in the box, its replies out
of the queue, until Claude has them all, and 10 minutes after, so
`delivered 2m ago` can be read. A group for a session no window holds stays
until one does. Such a group was sealed already: its replies left the queue
as the send wrote them into the inbox, beyond `✕` or take-back, and what Lee
queues for that session after them goes with his next send, as letters of
their own; the group lists those beside the sent ones, each with its `✕`.
Lee's rule of 5 November 2026 leaves it so: nothing of it waits on this
window's Claude. The window delivering there may carry both in one message,
as it carries whatever its inbox holds.
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
while its item takes it, as the fold would (see "Which replies go in", under
Delivery): an item open, and, for an answer, no other answer of Lee's on its
way to it. Across sealed sends and the queue still to send an item holds one
reply in Ready to send (5 November 2026): its buttons give way while one is
queued, carried or not, a send carries none a send in flight carries
already, and a second press of send racing the first claims nothing of what
the first claimed. A comment on its way bars nothing: an ask holding only
another window's comment still offers its buttons, and Lee's answer to it is
carried. A reply to an item Lee answered first from elsewhere (`sitrep
answer`, another window's pane), the answer on its way or delivered, or to
one Claude closed, is not carried. It stays in Ready to send, which says why
where its `✎ edit` was, `not sent: already answered` or `not sent: Claude
closed it`, and so does its item's row, where it said `not sent yet`; until
Lee clears it with its `✕`, or the item, reopened, takes it again. A send
that carries nothing at all, to this session or any other, toasts why:
`Nothing to send: the items replied to are answered or closed already.`,
`…have changed since.` where none fits its item any more, or `…have changed
since, or are answered or closed already.` for some of each; `…are in
finished sessions` joins them for a reply to another session's ask finished
since it was queued (see "A finished session's view"), `…are in another
project now` for a pick-up of what a session of another project than the
held one's parked, and `…are in sessions that can't be read` for one where
either session's filing could not be read (see "A window that changes
project"). Ready to send's
`send` shows only while some reply would go, whatever holds the others
back, answered, closed by Claude or finished (17 November 2026, made in
review), so only a send pressed before the board read what holds them back
meets these.

### The band

One line above the prompt, right-aligned counts only, each one a way in:

```
                                             ● 1 ask   2 elsewhere   ▸ show board
```

`asks` opens this session; `elsewhere`, what waits on Lee in every other
current session, in every project, opens All projects; a snoozed ask counts
in neither (see "Snooze"). Below 64 columns the words drop and the counts
stay (`+2`), and the answering line says `Enter` for `Your next Enter`, to
leave the title room. The pane's show/hide button always matches whether it
is drawn. Where the pane sits inline and its frame's ✕ is one cell, the open
pane's button is a wide `[ ✕ close ]` instead, its words kept at any width;
on the phone, where the band is not shown while the pane is, the pane's tabs
end with the same close. Where the pane sits is where Claude Code seated it, which only the pane's drawing knows: never
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
gate sized to what it is given still fits whole beside it. With nothing else
drawn there, the band is the whole tree, as before (11 October 2026: until
then the band dropped everything beneath it once it had a session to show).

Claude Code 2.1.323 asks each plugin for a row of its own there and stacks
the rows itself, in its chain's order, which put the gate rows under the
band, each given every row (13 November 2026). The band's own drawing finds
nothing of another plugin beneath it now, so it does both halves elsewhere:
it moves its row to the foot of the stack (`AbovePromptList`), whatever
order the rows came in, the others keeping theirs, and gives the row of each
plugin whose hooks sit beneath sitrep's `maxRows` less one, while the band
shows. A plugin whose hooks sit above sitrep's keeps every row, as it did
when it wrapped the band. Each plugin beneath is given `maxRows` less one on
its own, so they cannot share what the band leaves: two of them that each
fill what they are given, or one above sitrep that fills every row, as on
the older engine, make the stack taller than the band's window, and the
band's row, at its foot, scrolls out of it. Every other plugin's row now
draws again at each change to sitrep's board, since reading whether the
band shows subscribes it, which is what keeps its `maxRows` current.

A window on an older Claude Code (Lee's long-lived ones may be) has one
drawing there and no list, and the band stacks what it finds beneath it, as
before. The hooks on 2.1.323's rows and list match nothing an older one
sends, so never run there, and a row named for no plugin is left its rows
besides, should one ever reach them (the band's tests pass under 2.1.321
and 2.1.322 as under 2.1.323, all but the two that only 2.1.323 can run: a
drawing in the band's own row by naming it, and the list itself).

When a new ask lands: the ● pulses and a toast names it, and SitRep, the Mac
app, plays its sound (see "Settings", under "The menu bar"). Until 27
October 2026 the window played a soft chime, macOS's Glass, and only the
window holding the ask's session did, so an ask from a session whose window
was elsewhere (another Mac over SSH, or none) played nothing where Lee was.
Lee, that day: "I do think we should move the sound into the app." A window
still on the older mod plays nothing either: it played `sounds/ask.aiff` from
the plugin's folder, and once an update, or a checkout under `app/plugin here`
moving on, has taken `sounds/` out of that folder, its play fails, logging
"sitrep: the chime failed" to the debug log, so no window doubles SitRep's
sound. So it is when an ask's snooze runs out in this session, the toast
saying `● Back from snooze: Review the plan`, and the pane opens it; not when
Lee wakes it, from the pane or the app. Asks landing and waking together make
one toast, the new asks' (see "Snooze"). Dropped for now (11 October 2026):
a macOS notification for asks. Back on 13 October 2026, from the menu bar
app (see "The menu bar").

## Delivery

**The board never claims Claude knows something it was not told.**

- Replies for **this** session are sent as Lee's own message
  (`$.prompt.submit`, `asUser`), marked "From the board:". Its lines are
  written only once Claude Code takes it; a refused send leaves every reply in
  place. If Claude is mid-turn the window holds the message until that turn
  ends, and Lee can take it back until then (below). From its claim, though,
  its replies are **on their way** to every reader (22 October 2026), as an
  inbox reply is: the window's heartbeat says them (`sending`, under
  "Storage") until the claim ends.
- Replies for **another** session go into that session's inbox in the shared
  folder, a pick-up aside (below), and so do `sitrep answer`'s (see
  "One engine, two front ends"). The sitrep mod in that session's window
  picks them up and submits them as Lee's message (not as a message between
  agents, which Claude would give less weight). It writes back a delivered
  mark.
  - open and idle: in within a second or two;
  - mid-turn: the window holds it until the turn ends;
  - no window open: waits in the inbox, goes in when the session is joined
    again.
- **A pick-up goes to the window it was pressed in**: to the Claude there,
  whichever session of the project parked the item, live, idle or finished
  (see "Parked items are the project's"). It goes in that window's own
  message with this session's replies, held for Claude's turn, taken back
  and sealed as they are. Once Claude Code has taken the message, the window
  writes the pick-up down in the session that parked the item, the reply and
  its delivered mark together, in its own file there, as the pane writes
  Lee's finish; the reply's id is unlike any that session uses, and the
  reply names the session its message went to (`to`), as every pick-up's
  does from 17 November 2026. The item leaves Parked. Claude's line names the session that parked it where that
  is another (`- Pick up from parked, Request ledger's: Export the ledger as
  CSV`). The item shows in its project's picked up, in every view of the
  project, `picked up by` the session it went to, a finished session's too (17
  November 2026; see "Parked's picked up"). Decided with Lee, 11 November
  2026. Until then a pick-up of another session's item went into that
  session's inbox, for its own Claude, and a finished session's could not be
  picked up at all; that route went. A window on an older build still sends
  one that way until it is reloaded, and the parking session's window
  delivers it as any inbox reply.
  - **No heartbeat says it.** Two sessions' items can share an id, so a
    pick-up of another session's item said in the window's `sending` would
    have every reader carry it onto the held session's item of that id. It
    is left out: from its claim until it is written down only its own window
    shows it, frozen in Ready to send, and no other reader sees it on its
    way. So its reply's id is drawn as the message is claimed, apart from
    every id the session that parked the item holds and every id the
    window's messages carry, and never drawn again. A pick-up is written
    down once: written means a reply by this window, by that id, to that
    item, judged in the same turn of the window's queue that writes it, so
    a write cut short and taken up again, or two write-downs of one
    message, write nothing twice. Another writer of that session drawing
    the same id before the pick-up is written down is left, as rare as any
    two ids meeting (one in about a million): drawing again at the write
    was tried, and every way of keeping it safe cost more than the clash it
    met (found in review, 11 November 2026).
  - **An older build mid-send.** In the window's `$.state`, the pick-up names
    its item by its address (`sr-q7rx01:k3f9`), the line written down by the
    item's own id. Should an older build take the message over before it is
    written down (`app/plugin app` after a live test), it writes it down in
    the held session, as it writes every reply it sends, naming an item no
    session has, and every reader passes over it: Claude had the pick-up,
    and the item stays parked, for Claude or Lee to close. Its heartbeat
    saying it names no item either.
  - **A window that changes project.** A pick-up goes to the window's
    Claude only while the session that parked its item is filed under the
    held session's project, as the send reads each, afresh (17 November
    2026): no Claude of another project is given one. Else it is held back,
    as a reply to a closed item is (queue.ts's `pickedElsewhere`), whatever
    parted the two: the window taking up a session of another project, by a
    join or a resume, its session moving away, or the item's session
    moving. It stays in Ready to send, drawn under this session, and on its
    item, `· not sent: its session is in Contoso`, with its `↺ undo` and `✕`
    and no `send` for it alone; a send pressed regardless leaves it,
    toasting `Nothing to send: the items replied to are in another project
    now.`; and it goes once the two are filed under one project again, the
    item parked meanwhile, to be picked up from a window of its project
    too. One whose session, or the held one, the send could not file is
    held back alike, `· not sent: its session can't be read`, never said to
    be in another project. A message already sent, held for the turn's
    end, goes in as sent, to the conversation Lee pressed send in; taken
    back, its pick-up is in Ready to send again, held back there. Nothing
    but Lee or a send carrying it takes a pick-up out of Ready to send: one
    of another project left it, a toast saying so, as the window took up a
    session, as its session moved, and as a claim ended unwritten, until
    the review of 17 November 2026 found that a reload or a taken-back send
    so dropped one held back as its item's session moved away. So one left
    behind, as a reload found the held `session.json` torn and read the
    move only after, or one whose item's session moved away after the
    press, never reaches a Claude of another project, and never waits
    unseen.
  - **Two windows, one item.** Each pick-up goes in to its own window's
    Claude: a mark lets in a reply its item's close voided `answered` (see
    "Which replies go in"), so both Claudes are told.
- The send box shows each destination's state (`✓ delivered`, `⧗ waiting for its
  turn to end`, `○ closed: goes in when it reopens`, `✕ not delivered` once
  every reply went void), each ask shows
  `delivered 2m ago` or `on its way`, a toast sums it up, and the receiving
  window's band flashes `✦ 2 replies from the board` for 5 seconds. In the
  destination's own view, an ask whose reply is on its way says so; one
  whose answer is on its way offers no second, while one holding only a
  comment on its way still offers its buttons.
- The receiving window delivers only while it is the session's deliverer.
- **One message submitted at a time per window**, whatever its source: this
  session's sends, or the inbox. Each is claimed in `$.state` before it is
  submitted, the window's messages in flight kept in the order claimed, and
  holds its source, the session it goes to (project and session), the writer
  that claimed it, the text exactly as submitted, the replies it carries, when
  it was claimed, whether the window still holds it, and whether Claude Code
  has taken it. The replies' ids are fixed at the claim: a send's are made
  then; the inbox's are the replies whose lines the message holds, no
  others. A send is claimed behind the window's sends ahead of it (5
  November 2026; see "A send is sealed", under "Ready to send"), and never
  behind the inbox's message: while that is in flight a send claims nothing
  and says it waits for the inbox's replies, Lee's replies left in Ready to
  send. The inbox's is claimed only with nothing in flight: while anything
  is, a look takes in nothing more. An answer that went in with Lee's
  prompt (see "The ride", under "Answering an ask") is the
  one exception to both: it is claimed as his Enter goes on, after any
  message submitted already, the inbox's among them, and ahead of every one
  held, the inbox's too. That is safe: Lee's prompt is Claude Code's to
  deliver, the window submits nothing for it, and what it holds behind it
  waits for it as behind any message submitted first. A claim an older
  load left, which submitted as it claimed, reads as held no more; one not
  shaped as a claim, as the object an older build makes of a list (see
  Storage), is none.
  Until 5 November 2026 the
  window held one message in flight, and a send claimed while one was took
  nothing.
- **Held while Claude is mid-turn** (22 October 2026, Lee's choice: "Hold
  the reply in SitRep and send it as the turn ends."). Every message the
  window claims, a send or the inbox's, it holds while the main
  conversation is mid-turn, and submits once it is between turns: at once
  when it is at the claim, else as the turn ends, however it ends
  (`turn.complete` without an `agentId`: answered, stopped by Lee, failed on
  an API error, or refused). A turn stopped on a permission prompt or a
  question still runs, and a subagent's turn is not the main
  conversation's, so neither lets it go, nor does a subagent's run
  starting hold one; a turn that starts before it goes, as the last one
  ends, keeps it held to that turn's end. Whether a turn
  runs is what the window has heard (its `activity`, under "Storage"), read
  at the moment the claim is updated. A load that finds a message held
  keeps holding it while a turn runs, and submits it at once between turns.
  So does each look (the inbox's, every 1.5 seconds), should the message
  still be held between turns: the update as the turn ended failed, or no
  load ran it then. A look finding it held while a turn runs, or finding
  nothing held, writes nothing. A turn's end that no load heard leaves the
  turn running as the window has heard it, and the message held, until the
  next turn ends; the window's state says the same of it.
  - **Behind another** (5 November 2026). Only the first message in flight
    is ever submitted. One behind it stays held, whatever the turn, until
    the one ahead has ended, written down or let go; then it goes as the
    first did, at the next moment between turns: as Claude's turn on the one
    ahead ends, at a load, or at a look. So each goes in as its own prompt,
    in the order claimed, and the window holds each one still to go, where
    Lee can take it back, rather than leave it in Claude Code's queue
    behind the first, where nothing could. Submitting it as the first went
    would have queued it there, its own turn still (a plugin's submit runs
    once the session is idle, never inside a running turn), but past taking
    back. A submit's resolving and its turn's start come within a few
    milliseconds of each other, either first (live probes), so the first can
    be written down and ended while the window still seems between turns:
    after a submit, nothing more is submitted until the start of that
    message's own turn is heard, its text the message's, the message is let
    go, or 30 seconds pass from the submit, should that start never be
    heard; for an answer that went in with Lee's prompt, 30 seconds from
    the first moment between turns after its claim. A turn another prompt starts meanwhile, as one Lee typed that
    went in first, counts for nothing: its end submits nothing. A press of
    send or a look in that gap submits nothing; the next goes as the first's
    turn ends. A load knows nothing of a submit an earlier load made, and
    goes by the turn the window's state says: a reload landing in those
    milliseconds can still submit the next early, into Claude Code's queue,
    its own prompt after the first's still, only past taking back. For an
    answer that rode in with Lee's prompt while Claude's turn ran, that window is
    the rest of the turn: a reload then forgets the wait on its turn, and a
    send behind it may go as that turn ends, past taking back. A load
    finding several held carries the first on, and the rest in turn.
  - The conversation's end ends any turn of it, but only a `/clear` goes on in
    this process with a next conversation, so only a `/clear` submits held
    messages, into that conversation, the first at once and the rest in turn,
    as a prompt queued across a `/clear` goes in after; a `/clear` Lee types
    ends the conversation while its command runs, so the first goes at the
    first look once the command has ended, within 1.5 seconds (see "Held
    for Lee's input"). Any other end lets
    each go, as a take-back does, submitting nothing, its replies left as they
    were (a send's in Ready to send, the inbox's in the inbox): a resume puts
    another conversation in this one's place, which those replies are not for,
    and an exit, a logout, or a `-p` run's end or a signal ends the process.
    One submitted already is Claude Code's: it waits to be heard as at a
    turn's end, let go as never taken should no turn start.
  - Why: a send submitted mid-turn waited in Claude Code's own queue, and
    no API takes a prompt back out of it. Dropping one at its
    `prompt.submit` as the turn ended showed a notice, and left any prompt
    queued behind it in the transcript, unanswered (a probe, Claude Code
    2.1.308). Holding it in the window takes nothing from Claude Code's
    queue, shows no notice, and strands nothing.
  - The probe: a `$.prompt.submit` made from a `turn.complete` hook, not
    awaited there, started its own turn about 13 ms later; a hook awaiting
    its own submit never ends. So the window submits a held message from the
    hook and waits on none of it there.
  - **Held behind a subagent's run** (found 5 November 2026). On 4 November
    2026 Lee's answers waited under `⧗ Waiting for Claude's turn to end.`
    long after Claude had finished, Claude Code's own line reading
    `✳ Waiting for 2 background agents to finish`: one sent after 15:35 went
    in only as Claude's next turn ended, at 15:40, and another at 17:40. In
    each, a background subagent had ended its run waiting on work of its
    own, and that work, ending, had started another run of its loop once
    Claude's turn had ended: at 15:29:59, and at 17:35:05. Claude Code
    (2.1.318) raises a `turn.start` for each run of a subagent's loop,
    carrying its `agentId`, which the engine's types leave out, and the
    window took it for the main conversation's turn starting. That run's
    `turn.complete` carries the `agentId`, so nothing ended the turn the
    window heard until Claude's next turn ended. A Portal session on 5
    November 2026 shows the rest: Claude's turn ended at 12:22:58 with two
    background agents at work, no subagent's run started after it, and Lee's
    answer at 12:27:55 went in at once. So, as seen there once live and as
    the engine's code reads, Claude Code does not hold a turn open while
    background agents run: its turn ends as ever, and a held message goes
    in then.
    - First suspected: each such run ends on a second notice that the agent
      waits on its own background work, which Claude Code takes into the
      transcript alone, with no model request and no `turn.complete`, and
      that notice started the window's turn. It does not: 2.1.318 raises the
      main conversation's `turn.start` only for a prompt it sends the model.
      Nor is Claude Code's `✳ Waiting for N background agents to finish` a
      turn running: it is a note at the idle prompt, shown once Claude's
      turn has ended while background agents still work.
    - So a `turn.start` carrying an `agentId` is a subagent's, and the
      window hears no turn of its own in it: it holds no message, clears
      none of the main loop's tools, candidates or stops, leaves what the
      last Stop left pending (the heartbeat stays on its own work), and
      leaves a message's quiet counting (see "Never taken", below).
    - A window that kept such a turn when it reloaded into this fix keeps
      it until Claude's next turn ends: its message held, and its heartbeat
      and the board saying working. Nothing on loading tells that turn from
      a real one, so it is left to heal there, once.
    - From 4 to 5 November 2026, Ready to send said `⧗ Claude is waiting on
      its background work: this goes in when that ends.` while the turn the
      window heard seemed only to wait on that work: its main loop done, by
      the model's requests (`turn.step`), and a subagent's loop running, by
      the engine's list of agents. It rested on the turn being held open;
      a subagent's start replaced the turn it watched, so it showed at most
      for a moment, as a turn ended. It went with this fix, as did hearing
      the model's requests.
  - **Taken back.** While the window holds a send of Lee's, Ready to send
    offers to take it back (see "Ready to send"): its claim is let go, its
    replies stay in the queue as they were, among those still to send, the
    heartbeat says them no more, and the held session is folded again at once,
    so their asks wait on Lee again at once. A send behind it stays held, and
    is the next to go. One update of the claim in `$.state` decides between
    taken back and submitting, so a take-back and the turn's end racing never
    both win: the take-back lands first and nothing is submitted, or the
    turn's end does and the take-back finds the send submitted, and lets it
    be. Submitted, it is Claude Code's, and cannot be taken back. The inbox's
    message offers no take-back: Lee sent those replies from elsewhere.
- **Its replies on their way from the claim** (22 October 2026). A send's
  replies are in no file until they are written down, and its claim is in the
  window's `$.state`, which no other reader sees, so every change to a claim
  rewrites the window's heartbeat, which says the replies each send to the
  session it holds carries (`sending`) from its claim until that claim ends,
  written down or let go, the sends in the order claimed. A load's first
  heartbeat says the sends `$.state` holds, so a reload mid-send never drops
  one for a moment. Every reader folds them in among the session's lines.
  Their place among the answers is their claim's: each is read as a line of
  its window's dated at its own send's claim (after the window's own file and
  letters at that moment; 5 November 2026, as a window came to hold several),
  so the first answer on its way bars any later, whatever its source: an inbox
  answer written after the claim is barred by it and one written before bars
  it, of two windows' sends the earlier claim wins, and one is held back only
  by an answer that still stands once every line is read, on its way or
  settling the item as it now stands: one barred by an answer that went void
  since, or that was delivered and its item reopened since, comes back on its
  way; a comment bars nothing. Whether its item takes it at all is judged as
  the item stands once every line is read, since its line, once written, is
  read after all of them: nothing the lines say while the send waits voids it,
  so a close, a finish or an edit undone since (a reopen, an unfinish, an edit
  back) leaves it on its way, and the ask takes no second answer, while one
  that still stands (the item closed, the session finished, the reply fitting
  the item no more) leaves it out, what it barred reaching the item again as
  of what left it out. While on its way, an answer or a comment, the ask waits
  on Lee no more. One whose line is written by then is that line, so between
  the lines going down and the claim ending nothing reads twice and nothing
  drops out, every reader, the mod's and the CLI's, reading a session's
  heartbeats before its lines, and listing its folder again after them: a
  window writes the lines down before its heartbeat stops saying the send, so
  lines read after the heartbeat miss nothing it no longer says. They are no
  reply of the session's own: no inbox delivers them, and Claude's reads (the
  board text, `toldSummary`) still have the ask waiting on Lee until it is
  delivered. The inbox's message says nothing there, its replies on their way
  in the inbox already; nor does a send to a session the window no longer
  holds, whose heartbeat there let go. Taken back, refused or never taken, the
  claim ends and the ask waits on Lee again, the window folding its session
  again at once rather than at the watch's next look, after its heartbeat
  stops saying the send; the window gone, its heartbeat goes stale and the
  same follows, within 90 seconds. The window itself keeps the claims it last
  set for its heartbeat, reading `$.state` the first time a load needs them
  and again at each beat, and taking what it reads only where the load has
  not changed them since the read's dispatch began: a hook's dispatch, a tool
  call's or the load's first, reads `$.state` as it stood when the dispatch
  began, which may predate a send claimed since; and another load, one a
  reload left running, may end or let go of a claim, which the next beat
  then drops.
- **Taken** is heard, once it is submitted, from the submit resolving with
  no drop, or from a turn starting whose text is the message's; whichever
  comes first marks it taken and writes it down. A message the window still
  holds is never taken: a turn starting with its text is some other prompt.
  A load that starts with a message taken but not written down writes it
  down.
- **Written down** in the session it went to, whatever the window holds by
  then: through the hold when the window still holds that session as that
  writer, so the hold's own text stays in step; else into that writer's file
  there, read back and written whole. A send writes each reply and one
  delivered mark; the inbox, one mark naming its replies. Writing first reads
  the session: lines already there, or replies already marked, are not written
  again, so writing down twice writes once. A write that fails is tried again
  at the next look.
- **Refused** (a drop, or a throw): let go at once, its replies left as they
  were, and its asks wait on Lee again; the next look, or Lee's next send,
  tries again. One refused because Lee stopped Claude's turn is held
  instead (below).
- **Held for Lee's input** (5 November 2026). Once Lee stops Claude's turn,
  Claude Code (2.1.318) refuses every plugin's prompt until he next sends
  input in that window: `the session was stopped and nobody has sent input
  since`, given as text alone. That day Lee sent while Claude's turn ran,
  then stopped it; the stopped turn's end submitted the send, Claude Code
  refused it, and it was let go with a toast, as was each press of send
  after, until he typed in Claude. A message refused for that reason is not
  let go: the window holds it again and marks itself stopped (`stopped` in
  `$.state`, beside the claims, kept across a reload), with no toast, its
  quiet and the wait on its turn undone, so nothing lets it go as never
  taken and nothing behind it goes early. Stopped is the window's, not a
  claim's: while it is, nothing is submitted, no look and no turn's end,
  so a send claimed meanwhile, the inbox's message taken in meanwhile, or
  the send behind one taken back spends no submit on a refusal sure to
  come.
  - **What lifts it.** Claude Code lifts its refusal for any input Lee
    types or sends from the Remote Control bridge that was not queued
    before the stop, a slash command among them, as the input arrives,
    before any hook hears it (its human origin, which reaches a plugin as
    `composer` or `bridge`; another plugin's prompt, the SDK's or a task's
    notification lifts nothing); and for a plugin's call made from within a
    press of Lee's after the stop. So the window lifts its mark at a slash
    command of his, at its `command.run` hook, before it runs; at a prompt
    of his that goes no further, taken by the answering mode or dropped
    beneath; as a turn of the window's own starts, never a subagent's run;
    and as the conversation ends. A prompt of his that goes on stays marked
    until its turn starts, so no look puts the board's message in ahead of
    it. A turn's end carries on the first as ever, the rest in turn; where
    no turn follows, the next look does: `command.run` holds the turn, so a
    submit from it is refused, and one from `prompt.submit` hangs there on
    the prompt the hook hears (in the test kit). A turn that leaves the
    refusal standing, as a task's notification's, costs one submit refused
    again, which marks it again. Input heard between a submit and its
    refusal coming back, or while the mark is written, leaves the window
    unmarked, the refusal predating it. Gaps: input Claude Code counts that
    the window never hears, as a bash-mode `!` command or a prompt of Lee's
    another plugin's hook drops before sitrep's, leaves the mark until a
    turn starts or Lee presses send; and every window turn's start lifts it,
    whatever its prompt, a turn that leaves the refusal standing costing one
    refused submit.
  - **While a slash command runs** nothing is submitted, stopped or not,
    until its `command.run` hook's `next` resolves: a prompt would wait on a
    `/compact`, its quiet passing and its claim let go as never taken before
    it went in, then written down by no one. A command that opens a panel,
    as `/resume`'s picker, may resolve as the panel opens, so the panel's own
    lifetime is not covered. The next look carries on once it ends.
    `sendHeld` reads whether the window is stopped before its update, so a
    refusal landing in between can still let one submit through, refused in
    turn.
  - **Send and send now.** Ready to send's send is answered by the mod's
    `ui.press` hook, inside Lee's press, as the band's buttons are, so its
    submit carries the press, which vouches for it: the hook's own `$`
    carries the press, where the pane's buttons, bound to the `$` the board
    was drawn with, carry none (read from 2.1.318's code, and seen live on
    6 November 2026: Lee pressed Esc mid-turn, the held send showed
    "Interrupted: goes after your next message.", and `↑ send now` put it
    in at once with nothing typed). Pressed while the window is stopped, it
    takes the first message in flight as going, then lifts the mark, then submits, before the hook
    returns, so no look submits it unvouched meanwhile; whatever is first
    goes, the inbox's message included, whether the press claimed a send,
    wrote only letters to other sessions, or found nothing to send, and the
    send pressed follows in turn. While stopped, the first send held offers
    `↑ send now` beside its take-back, which does the same with nothing new
    to send. Refused all the same, the window is marked stopped again,
    silently. The press's hook waits on the window's queue (`serially`)
    within its budget, as the band's does.
  - Still claimed, a message held is on its way, its asks needing Lee
    nowhere, and Lee can take it back as any held send. A `/reload-plugins`
    he types lifts the mark, so the load after it sends at once; a
    file-watch reload, typed by no one, leaves it, the refusal standing. A
    `/clear` lifts it, Claude Code refusing only in the conversation
    stopped, before the window lets go of its session, and the first goes
    into the next conversation at the first look once the command has
    ended.
  - A wait can be long, so a look lets the inbox's message go, silently,
    once the window is stopped and no longer delivers for its session, its
    replies left in the inbox for the window that does.
- **Those behind it, let go with it** (5 November 2026). A message refused
  or never taken lets go of every send held behind it in the same update of
  the claims, one toast saying so: their replies are all back among those
  still to send, in the order Lee replied, and Lee's next send carries them
  as one. None goes in ahead of the replies it would have followed, and
  none is spent on a refusal sure to come again, as a session closing
  refuses every prompt.
- **Never taken** (Lee deleted the queued prompt, or the submit was lost): let
  go once the window has gone quiet without it, 30 seconds after its submit,
  or after a later end of a turn of the main conversation (or of the
  conversation) or a load's start, with no turn starting since; never while
  the window still holds it, however long the turn it waits out. A prompt
  submitted between turns starts its own turn about 13 ms after (a probe),
  and one queued goes in as the turn before it ends, its own turn starting
  about 40 ms after (live), once the prompt's hooks have run; so a message
  still unheard by then was never going in, and letting it go never sends
  it twice. A send's replies are back in Ready to send, their asks waiting
  on Lee again, and a toast says so; the inbox's wait for the next look.
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
  - **Who closed the item, and how**: Lee's answer, Lee's ignore, Lee's
    drop of a parked item (18 November 2026), or Claude.
    Recorded by the line that closes it, a delivered answer, a resolve or a
    drop, and cleared by a reopen. The first close stands: Claude resolving an
    item Lee's answer closed adds Claude's reason and leaves it Lee's, so an
    ask Lee ignored stays ignored, out of Resolved.
  - **Why a reply is void**, when it goes nowhere: `changed`, `answered`,
    `resolved`, `dropped` or `finished`.

  Delivered and void are two facts, not one: a delivered mark is Claude's
  record that it has a reply, and makes delivered any reply it names,
  whatever else is true of it.
  - **One answer per item.** A reply reaching an item closed is void,
    `answered` where Lee's answer or ignore closed it, `resolved` where
    Claude did, `dropped` where Lee dropped it. An answer
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
    on their way go void by that close, `answered`. A pick-up pressed in
    another session's window is never on its way in the session that parked
    its item: its line is written only once Claude has it, with the mark
    that lets it in (below), so a finished session's item is picked up all
    the same, its reply void `finished` and delivered (11 November 2026).
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

## Snooze

Decided with Lee on 22 October 2026 (`.scratch/snooze/decisions.md`), of the
three Tailspin asks he wasn't ready for: "Maybe being able to snooze them to
tomorrow … They'll pop back into the 'Needs You' section." The verb is
"snooze", since "park" already means something on the board. How it is
stored and how it flows was designed on 23 October 2026; **proposed** marks
a call made then that Lee has not made himself. Until 13 November 2026 an
ask snoozed, and from 4 November a turn on its own (see "A turn snoozes
too"); since then the session does, its asks and its turn together (see
"The row snoozes"), and this section says how it stands now.

- **A session snoozes.** In the data the session carries Lee's snooze, and
  when it wakes; while it holds, every ask of the session waiting on Lee,
  and its turn, are put off together. A permission prompt or a question is
  its window's, and is never snoozed: it stays in Needs you. On the card,
  snoozing a row snoozes its session; in the pane, snoozing any ask of a
  session does. Only Lee snoozes: Claude has no tool for it.
- **The times**, Snooze's six choices, in this order on every surface: In
  an hour, Later today, Tonight, Tomorrow, This weekend and Next week, each
  Lee's to switch on or off and to time in SitRep's Settings, by default as
  the table under "Lee sets the times", below, gives. Then Until it moves,
  on the card, with no time, and no setting: see "The row snoozes".

  **In an hour** (Lee, 17 November 2026): the shortest, first, and offered
  at any hour while on. As Later today's, its time is real time, so across
  a change of the clocks it wakes an hour on, whatever the wall clock reads.

  **Tonight** (Lee, 17 November 2026): he wanted an evening choice. It is
  offered only while its time is to come, so from 18:00, or the time Lee
  set, until midnight no surface offers it, as Apple Mail leaves out its
  own once it has passed; between 15:00 and 18:00 both it and Later today
  are offered, Later today waking after it. Its time may be any of the
  day's, a morning's too, on purpose: Lee sets when it wakes, and the clock
  leaves it out once that has passed, so no hour is barred that he might
  mean. A choice is offered while Lee has it on and the time it comes to
  is still to come, the one rule every surface asks of core's
  `snoozeChoicesAt` or the app's `SnoozeChoice.offered`, so only Tonight
  and This weekend are ever left out by the clock. Tonight pressed once its
  time has passed, on a question
  or a menu drawn before, snoozes nothing, the rule stated once on the time
  it comes to, come already: the pane toasts `Not snoozed: 18:00 has come
  already.` and keeps its question open, drawn with what is offered now,
  or gives way to the ask's buttons where nothing is; the app posts the
  same words in its Not snoozed banner. The app's menu works out each
  item's time as it opens, and a choice snoozes to the time its item
  showed, so a clock or a zone moving while the menu stands open never
  changes what Lee picked. The pane's question shows no times: a choice
  pressed there is worked out at the press, from the settings as the pane
  last read them, so one Lee switched off since it was drawn still
  snoozes, as he pressed it.

  **This weekend** (Lee, 17 November 2026): it wakes at its time on the
  weekend's day Lee chose, Saturday or Sunday, of this week, the week
  running Monday to Sunday as Next week's does. So it is offered from
  Monday until that day's time, and left out after it until Monday, by the
  rule every choice is offered by, its time to come: on a Sunday afternoon
  it is never offered for the weekend six days on, which it would not
  name. Set to Sunday, it is offered on Saturday too, waking the next
  morning. Off by default, as Lee set it.

  **Next week** wakes at its time on the day Lee chose of the week after
  this one, the week running Monday to Sunday: by default the Monday after
  today, a week on from a Monday; set to Friday, pressed on a Wednesday, the
  Friday nine days on, and on a Sunday, the Friday five days on. It is
  never in the past, so always offered while on.

  **Lee sets the times** (17 November 2026). Lee asked for snooze set as
  Spark sets its own: a fixed set of choices, each switched on or off with
  its own time; not Spark's length of a snooze, and no choices of his own.
  So each choice comes when he means it to, and one he has no use for
  leaves every menu. The app owns the settings, in its own defaults and its
  Settings window's Snooze pane (see "Settings"), and writes them to a
  small file the mod reads, so the pane in Claude Code offers the same
  choices (see `snooze.json`, under "Storage"):

  | Choice | Lee sets | Default |
  |---|---|---|
  | In an hour | on or off, always an hour of real time | on |
  | Later today | on or off, and 1, 2, 3 or 4 hours on | on, 3 hours |
  | Tonight | on or off, and the time | on, 18:00 |
  | Tomorrow | on or off, and the time | on, 09:00 |
  | This weekend | on or off, Saturday or Sunday, and the time | off, Saturday 09:00 |
  | Next week | on or off, the day, and the time | on, Monday 09:00 |

  A time is set to the minute, in the system's time field with its
  stepper, as System Settings sets Night Shift's schedule. With every
  choice off, a row's Snooze holds Until it moves alone, with no
  separator, and the pane offers no snooze. The defaults are one constant
  in each copy, core's `SNOOZE_DEFAULTS` and the app's
  `SnoozeSettings()`, and every surface works out a choice from the
  settings it is given: `snoozeAt(choice, now, settings)` and
  `snoozeChoicesAt(now, settings)`, `SnoozeChoice.wakes(after:in:settings:)`
  and `SnoozeChoice.offered(at:in:settings:)`. A time on a day the clocks
  skip it is read past the change, 01:30 as 02:30 where 01:00 goes to
  02:00, and one they pass twice as the first. Until then each choice's
  length or hour was a named constant of each copy (`LATER_MS`,
  `TONIGHT_HOUR`, `TOMORROW_HOUR`, `NEXT_WEEK_HOUR`; `laterTodayInterval`,
  `tonightHour`, `tomorrowHour`, `nextWeekHour`), for this to take; In an
  hour's length stays one (`IN_AN_HOUR_MS`, `inAnHourInterval`). The CLI's
  `snooze` takes a time alone (`--until`), and works out none, so it reads
  no setting. The terminal view's snooze menu (20 November 2026) works its
  times out as the pane does, by core's, from `snooze.json`, and writes the
  line `sitrep snooze` writes.

  Lee: "We can always improve and add new options there." Each is worked out
  where it is pressed, on the Gregorian calendar in that Mac's time zone,
  whatever calendar the Mac is set to, so 09:00 is 09:00 across a change of
  the clocks and Monday is core's Monday: the app's in Swift, the pane's by
  core's `snoozeAt`, both to this rule (**proposed**: the day after today is
  the next calendar day, so Tomorrow pressed at 01:00 wakes 32 hours on).
  What is pressed is stored as the instant it comes to, in milliseconds since
  the epoch, as every time on the board is; nothing reads it as a local time
  again but to word it.

  The time is worked out in two places, core's `snoozeAt` and the app's
  `SnoozeChoice`, since SitRep's Snooze menus show each choice's wake time
  before the press, with nothing run. Both copies are checked against one
  table of wake times, `tests/wakes.ts`, which core's tests and the app's
  both read (Lee's choice, 27 October 2026): each choice in London, New York,
  Santiago, whose clocks change at midnight, Auckland and Kolkata, either
  side of a Monday, after midnight, and across each zone's changes of the
  clocks in 2026, In an hour's among them; and for Tonight, at 17:59, at
  18:00 and after, a row giving `-` for no time where the choice is not
  offered. Rows under settings other than the defaults carry their setting
  with their choice (17 November 2026): Later today at 1 hour on
  (`later:+1`), Tonight at 20:00 (`tonight:20:00`), This weekend on
  Saturday or Sunday (`weekend:sun:09:00`; `weekend` alone is the default,
  off), Next week on Friday (`week:fri:09:00`), a choice switched off
  (`tomorrow:off`), and times the clocks skip or pass twice; each side
  reads a row's setting over the defaults. The kit runs core's tests in the
  Mac's own zone and can set no other, so they run each row with a `Date`
  of its zone in the global's
  place (`tests/zoned.ts`), checked against the real one in the Mac's own
  zone wherever that zone changes its clocks.

**Where a snooze lives.** Two kinds of line, the format's version staying 1:

```
{"v":1,"at":1760000000000,"seq":9,"type":"snoozeSession","until":1760346000000,"asks":["k1","k3"]}
{"v":1,"at":1760005000000,"seq":10,"type":"snoozeSession","asks":["k1","k3"]}
{"v":1,"at":1760010000000,"seq":11,"type":"wakeSession"}
```

- `snoozeSession` says when the session wakes (`until`), none for Until it
  moves, and the asks it holds (`asks`): those waiting on Lee as it is
  written, snoozed already or not, by their ids, which the check puts there
  from the session as it stands, not from what the row named. `wakeSession`
  says Lee woke it now. A snooze is one line, whatever the row showed.
- Each goes in the writer's own file in the session, as Lee's finish does:
  the CLI's appended to `cli.jsonl`; the pane's in its window's own file
  there, through the hold for the session the window holds (`post`, so it
  rides to Claude as a change to the board), and for any other read back
  and written whole, as `✓ finish this session` writes it.
- Never the inbox: an inbox holds replies, which a window submits to Claude
  and marks delivered, and only replies count from it; a snooze is no
  message, and nothing for a window to deliver. Not an edit either, which is
  Claude's correction of an item and reads the replies on their way again.
  Nor a file of Lee's own: several writers would rewrite it whole and the
  last write would win, and every reader already reads a session's writers'
  files and nothing else, so the snooze folds with its session, the same in
  every reader, and Claude's view has it without a read more.
- Being a line on disk, it outlives a reload of the mod, a new process and
  the app's `watch` starting again: every reader reads it at every look,
  and folds it again as the session's files change or as its time comes.
- An old reader skips both kinds, as it skips any it does not know: a window
  not reloaded counts the session's asks on its band, and its Claude reads
  them waiting, until it reloads (`watch`'s `needsReload` lists it).
- The lines before 13 November 2026, `snooze` and `wake` of an ask, and
  `snoozeTurn` and `wakeTurn` of a turn, are still read: see "The row
  snoozes" for how.

**What a snooze is, as the fold reads it** (`core/asleep.ts`). Every reader
reads the lines in one order (see "Reading merges", under "Storage"), so of
two lines racing, two windows', a window's and the CLI's, a snooze and a
wake, the later wins, the same in every reader. The session keeps Lee's
latest snooze, `snooze`, its `until`, when it was written, and the asks it
holds:

- A `snoozeSession` sets when it wakes, in place of any before: snoozing
  again moves the time.
- A `wakeSession` ends it, whether its time has come or not; one with none
  standing does nothing.
- **It holds only the asks that waited on Lee as it was written.** An ask
  Lee's answer was on its way to then, from the pane, `sitrep answer` or a
  window's message he sent while Claude worked, is not his to put off, and
  is not on the line.
- **Something new that needs Lee, or is his, wakes it early** (13 November
  2026): an `ask` posted; a `reopen` of an ask, Claude raising it again;
  Lee's reply to one of the asks it holds, as a reply line, in an inbox
  from the pane or `sitrep answer`, or in a window's file once it delivers
  one it carried, since Lee writing there has dealt with it; and Lee's own
  prompt in a window holding the session (see "The row snoozes"). Each ends
  the snooze only while it still holds at the line's time: one that ran out
  before stays as it ran out, its asks carrying when they woke, so a new
  ask after it never takes their waking away. A reply to an ask it does not
  hold, an answer on its way as Lee snoozed and written down after, is no
  writing to the session since the snooze, and leaves it; so is a pick-up
  of a parked item.
- **An ask it does not hold, waiting on Lee again, wakes it while it
  waits**: one whose answer on its way at the snooze went void since, as
  Claude's edit voids a yes once the ask wants words, or was taken back
  from a window's message, which leaves no line at all. The fold sees it
  once every line is read, and the session reads as not snoozed, its asks
  all back in Needs you; answered again, that ask waits on Lee no more, and
  the snooze holds the rest until its time. Its time coming while it is
  set aside, it stands again, run out, its asks carrying when they woke: a
  change by time alone that core's `nextFoldChange` counts too (the
  session's `asideUntil`, 16 November 2026).
- **Nothing else wakes it**: its turn ending, whether its window began it
  for Lee or on its own work, as background agents finishing do, unless he
  snoozed it until it moves (see "The row snoozes"); a window joining,
  attaching or beating; Claude's status, edit, resolve or park. A
  reply of Lee's in a window's message in flight to an ask it holds takes
  that ask out of Snoozed as out of Needs you from its claim, since it waits
  on Lee no more, and wakes the session once it is written; taken back,
  refused or void, the ask is snoozed again while the time is to come.
- A finish leaves it: nothing of a finished session counts or shows, its
  snooze among them, and a join before the time finds it still snoozed.
- **Its time.** The fold reads a session at a moment, `now`, as it reads a
  heartbeat's liveness: a snooze holds while `now` is before its `until`.
  Every ask it holds still waiting as posted carries it as `snoozedUntil`
  while it holds; at `until` it has run out, and each carries when it woke,
  `wokeAt`, until a later line ends it. An ask posted after it never
  carries it, having woken it. A Mac asleep pauses nothing here: it is the
  wall clock's instant, not a heartbeat's age. Until it moves, the fold
  reads its time as `UNTIL_IT_MOVES`, past any time a `Date` holds, so it
  sorts after every time, never runs out, and keeps in the JSON `$.state`
  holds, as Infinity would not; it is never among the instants the board
  next changes by.

An ask is **snoozed**, on Lee's side, while it waits on Lee (`waitsOnLee`)
and a snooze holds on it (core's `isSnoozed`; a session's are
`snoozedAsks`, none once it is finished). `waitingOnLee` leaves them out,
and with it a session's `waiting` and everything counted from that. Its
turn is snoozed while the session stands at Lee's turn and the snooze
holds (core's `snoozedTurnOf`, `core/rows.ts`); the session's state stays
`yourTurn` wherever a state is read, its windows' still.

No file changes as a snooze runs out, so a reader learns it by folding again
at a later `now`. The mod looks at the held session every 1.5 seconds and at
the sessions around it every 5, folding one again once the `until` of a
snooze standing on it has come (core's `nextFoldChange`), so a pane, a band
and Claude's board text have it within a look; a CLI command folds as it
runs; `watch` counts each snooze's `until` among the instants the board next
changes by time alone (see "Expiry"), and folds every session afresh then.

**Where it counts.** A snoozed ask counts nowhere on Lee's surfaces: not in
a session's or a project's waiting, on the pane's tabs or the band, in `list`
or `board --json`'s `waiting`, nor in `watch`'s head and rows; so not in
Needs you, on the strip, in the menu or on its icon, in the notch's light or
swell, nor in a macOS notification. A snoozed turn leaves Your turn and its
count the same way. A snoozed session with no stop stands as its windows
leave it, out of Needs you; it still waits as posted (`asked`), so it keeps
its session current as any ask waiting does. A window's stop in a snoozed
session shows in Needs you as any does, the session's row in Snoozed beside
it: Snoozed is an exception to "each session appears once", as Projects is.

**The Snoozed section.**
- Its rows are core's (`snoozedRowOf`, `core/rows.ts`), in `watch`'s
  `snoozed`, beside `rows` and apart from them: a separate list, not a
  fourth `section`, since the app reads `section` strictly and one built
  before it would refuse every line. A row is a session, one each: its
  `session`, `isAway`, project key, `name`, `projectName`, `letters` and
  `second` as a Needs you row's; its `lines`, one per ask snoozed, each its
  `key` (`ask:<session>:<ask>`, the key it has in Needs you), `is` `ask`, its
  `ask`, its title as `first`, `since` its posting or reopening, and
  `wakesAt`, and at its turn one more, the turn's (see "The row snoozes");
  and its own `wakesAt`, the soonest of its lines'. Rows go soonest to wake
  first, and so do a row's lines, then the oldest first.
- It is the card's last section, under Your turn. It is folded at first, to
  its eyebrow and its count, the lines it holds (**proposed**), and a fold of
  it is kept as any is; unfolded, each row says when it wakes. The menu
  shows none; the strip shows them, as marks under a hairline of their own
  (14 November 2026; see "The strip"), and until then showed none either.
  How it looks is drawn in Paper.
- **Snooze, from a row:** a right-click on a card's Needs you row whose
  lines hold asks, or on a your-turn row, offers Snooze, then the choices
  offered, as Lee set them (In an hour, Later today, Tonight, Tomorrow,
  This weekend, Next week), and after a separator Until it moves, the same
  on every row: `sitrep snooze` of its
  session, naming the asks the row shows, by their ids, so an ask that
  landed after it was drawn is never snoozed unseen. A row of stops alone
  offers none.
- **Wake now:** a Snoozed row's right-click wakes its session, `sitrep
  wake`.

**Waking at its time is an arrival.** `watch`'s `new` names a line needing
Lee the watch has not shown, or not within a day of its going (`FORGET_MS`),
so an ask's line back from a snooze of three hours would come back
unremarked. So a line in Snoozed is kept among those shown however long it
sleeps, and its absence alone never makes it new; once its time runs out,
each ask's line in Needs you carries the snooze's `wokeAt`, and the watch
takes it as new. Its row arrives as a new ask's does: the notch swells, the
strip flashes, its row washes on the card, Needs you unfolds on the card
while Lee has the notch show the board, and a macOS notification goes where
they are on; with the strip chosen, Needs you folded stays folded and its
count on the strip flashes (see "Folding"). Its time still counts from its
posting. A turn's line is never new, as on Your turn. Woken by Lee, or
early, the asks come back as shown, unflashed, as Lee pressed it, and `new`
means not yet shown to Lee; their row moves at once wherever the wake
changes its group, as any row does (Lee, 14 November 2026; see "Moving"
under the strip). An ask new enough to wake it is new as any is. One woken
while no `watch` ran, the app quit, brings no swell, as any line then.

**In the pane.**
- It reads each ask's `snoozedUntil`, in the held session's fold and in the
  briefs of the sessions around it, and words it at the scene's `now`.
- A snoozed ask stays in ASKS, after those waiting, quieted, and hangs
  `snoozed until tomorrow 09:00` with `wake now`, its time worded as the
  app's snoozed rows word theirs (see "How each row reads" under "The
  notch and its panel"): `snoozed until 15:42`, `snoozed until next week`,
  `snoozed until 3 Dec 09:00`, `snoozed until it moves`. Until 18 November
  2026 it said a weekday for days two to six on
  and a date past them, never `next week`. Opened, it answers as any
  ask does, and answering it answers it, waking its session. The heading says both: `1 waiting · 2
  snoozed`.
- A waiting ask, opened, offers `snooze` among its buttons while any choice
  is offered, which asks in place, as the pane's finish does: the choices
  offered, as the app's
  `snooze.json` sets them (`in an hour`, `later today`, `tonight`,
  `tomorrow`, `this weekend`, `next week`), then `cancel`. A choice writes one
  `snoozeSession` line in the ask's session, naming as the CLI's check
  takes them the asks of that session the pane drew waiting, its time
  worked out at the press; `wake now` writes one
  `wakeSession`. Each is checked as the CLI checks it, and goes in the
  window's own file in the session (above), wherever the pane draws an
  ask's buttons (**proposed**). The pane offers no snooze of a turn alone:
  it draws no turn as a row of its own; the card does.
- How it is drawn, with no Paper for the pane (**proposed**): the snoozed
  asks the soonest to wake first, each `●` grey and its title dim,
  `wake now` a dim press after its time; `snooze` a dim button after an
  ask's answers, on an ask waiting on Lee in a session not finished, its
  question `Snooze this session? Its asks, and your turn there, stop
  counting until it wakes.` in their place, a choice closing the ask, and
  the title closing it from the question in one press. One refused, a line
  landing after the pane last drew, writes nothing, and a toast gives the
  CLI's words after `Not snoozed:` or `Not woken:`; one whose session is
  gone says so.
- An ask its time wakes in the held session is announced as a new one is:
  the `●` pulses, a toast, `● Back from snooze: Review the plan`, and it
  opens; SitRep plays its sound for it, as for a new ask (the window's chime
  until 27 October 2026, see "Settings"). One Lee wakes is not
  (**proposed**): it carries no `wokeAt`.
  The window keeps the asks it saw snoozed at its last look, and a load's
  first look announces nothing, so a reload over an ask asleep, or one woken
  as it reloaded, says nothing of it; one asleep through the reload is
  announced as its time wakes it.

**Claude's view.** Claude is told of a snooze as of any change to the board
it did not make: the board's text changes, and rides into its next turn as
context (see "Claude's side"). Never a message, never a turn. A snooze
running out changes the text again, and that rides in the same way. The
lines themselves leave the session's `updatedAt` as it was (`UNTOLD`,
`core/fold.ts`), so the first message's listing and the sessions around a
window order it as before; a snooze of a session at its turn alone, with no
ask, changes nothing Claude reads.

- The board text (the `board` tool, a join's answer, the context, `sitrep
  board`) lists a snoozed ask among the open asks, in place of `waiting on
  Lee`:

  ```
  - k1 wants a yes (Go), snoozed by Lee until Mon 26 Oct 09:00 (leave it until then): Give the go for stage 3
  ```

  The time is whole and local, never relative, so the text does not change
  at midnight and ride in again for nothing. One snoozed until it moves
  reads `snoozed by Lee until the session's next turn ends (leave it until
  then)`.
- What Claude reads follows what it has been given: an ask Lee's reply is on
  its way to still reads snoozed, as it still reads waiting.
- The first message's listing counts them apart: `- Tailspin: sr-7t2k9d
  "Finish the Tailspin modernisation", 1 waiting on Lee, 3 snoozed by Lee`.

**The CLI.**

```
sitrep snooze <ask>... [--until <ms>] [--session <id>]
sitrep wake [--session <id>]
```

- `snooze` snoozes the session until the instant `--until` gives, in
  milliseconds since the epoch as the JSON's times are, or with none until
  it moves, naming the asks its row showed, none for a turn's row; `wake`
  wakes it now. Each writes one
  line in the CLI's own file, nothing in the inbox, and prints nothing, as
  `answer` and `finish` do: what it did shows on `watch`'s next line and in
  `board --json`. There is no `--json`.
- Nothing is written, exit 1, the first of these saying why: the session
  finished (`This session is finished: its asks wait on you no more.`); an
  id that is no item, or no ask, in `answer`'s words; an ask waiting on Lee,
  not snoozed, that the asks named leave out (`An ask waits on you that the
  snooze did not name: look at it, then snooze again.`), so one that landed
  since the row was drawn is never snoozed unseen, where asks waiting on
  him no more, closed, ignored, commented on or answered on the way, may be
  named or not; the session needing nothing of Lee, no ask waiting on him,
  snoozed or not, and not at his turn (`<name> needs nothing of you: there
  is nothing to snooze.`), a window's stop being its own; then `--until`
  no time, whole milliseconds a date holds (`A snooze wakes at a time in
  milliseconds since the epoch, or with none until it moves.`), or come
  already (`That time has come already: give one still to come.`). For `wake`, the session
  finished, or no snooze of Lee's standing (`<name> is not snoozed.`); one
  whose time has come is woken with no refusal, so a Wake now pressed as
  its time comes is never refused. A session snoozed already is snoozed
  again, to the new time. An unknown session is exit 2. A snooze line whose
  `until` no date holds is skipped as a bad line, as is any line or
  heartbeat whose time no date holds (core's `isTime`).
- The app calls `snooze` with a card row's session and the asks it shows
  from its right-click, the ids after `--`, as `answer`'s, with no
  `--until` for Until it moves, and `wake` with a Snoozed row's session.
- What the JSON gains, every field always there and no `v` moving (fields
  added; `waiting` narrows, as on 20 October 2026, so a reader of the old
  meaning only counts fewer):
  - each ask, in `board --json` and `watch`: `snoozedUntil`, while it is
    snoozed, else null, and `untilItMoves`, true while it is snoozed until
    it moves, its `snoozedUntil` null then (13 November 2026);
  - each session and project, in `list --json`, `board --json`'s session and
    `watch`'s `projects`: `snoozed`, its asks snoozed;
  - `watch`: `snoozed`, the Snoozed rows.

  ```
  "snoozed": [
    { "session": "sr-7t2k9d", "isAway": false, "project": "tailspin",
      "name": "Finish the Tailspin modernisation", "projectName": "Tailspin",
      "letters": "Ta",
      "lines": [ { "key": "ask:sr-7t2k9d:k1", "is": "ask", "ask": "k1",
                   "first": { "lead": "Review the plan", "mono": null,
                              "subject": null, "more": null, "until": null },
                   "since": 1760000000000, "wakesAt": 1760346000000 },
                 { "key": "turn:sr-7t2k9d", "is": "yourTurn", "ask": null,
                   "first": { "lead": "Stage 2 is in", "mono": null,
                              "subject": null, "more": null, "until": null },
                   "since": 1760001000000, "wakesAt": 1760346000000 } ],
      "second": "Tailspin · Finish the Tailspin modernisation",
      "wakesAt": 1760346000000 } ]
  ```
- Plain `list` says it among a session's facts: `(open, 1 waiting, 2
  snoozed)`, counting asks alone.

**Built in three PRs:** core and the CLI; the mod (the pane, the band, the
announcement); the app, once its surfaces are drawn in Paper. The row's
snooze of 13 November 2026 changed all three in one.

### A turn snoozes too

Decided with Lee on 4 November 2026, over Paper's board I, which put Snooze
on a your-turn row's menu, Until it moves after its three times: "Yea, this
looks great." Until then only an ask snoozed, and a your-turn row's menu
offered Jump alone. Superseded on 13 November 2026 by "The row snoozes",
which snoozes a turn with its session's asks; what follows is how a turn's
own snooze worked, and how its lines are still read.

- **What it held:** that turn alone, named by its end, the time a your-turn
  row counts from. It ended at its time, or for Until it moves never by the
  clock, and as soon as the session took another turn: the next turn's end
  came back to Your turn unsnoozed. It ended for good, too, once anything in
  the session needed Lee after it, or Lee replied there.
- **Its lines,** in the CLI's own file in the session, the app writing them
  through the plugin's CLI. From the run that made `Lines.snoozedTurn`:

  ```
  {"v":1,"at":1793819990622,"seq":1,"type":"snoozeTurn","turn":1793818490000}
  {"v":1,"at":1793819990663,"seq":1,"type":"snoozeTurn","turn":1793819270000,"until":1793869200000}
  {"v":1,"at":1793819993740,"seq":2,"type":"wakeTurn","turn":1793819270000}
  ```

  `snoozeTurn` names the turn by its end, `turn`, and when it wakes,
  `until`, none for Until it moves; `wakeTurn` names the turn Lee woke now.
  Nothing writes them since 13 November 2026; how they are read now is in
  "The row snoozes".
- **Never told to Claude:** they leave the session's `updatedAt` as it was
  (`UNTOLD`, `core/fold.ts`), as the session's own lines do now.
- **How it showed:** `watch`'s `snoozed` carried it as a row of its own,
  beside any row of the session's asks asleep, its one line keyed
  `turn:<session>`, its `is` `yourTurn`, its `ask` null, `first` the turn's
  line as Your turn shows it, `since` the turn's end, and `wakesAt` when it
  wakes, null until it moves; the row's `wakesAt` the same, those until it
  moves after every one with a time. On the card it is a Snoozed row whose
  mark is, since 13 November 2026, a snoozed ask's dot in blue, dimmed the
  same (see "How each row reads"); until then a ring 9 across, its stroke
  1.5, in the faint grey, #5C5C63 (on glass the tertiary). In its time's
  place, in the soft grey, it says when it wakes, or "until it moves". A
  row of a session's turn alone still reads so.
- **The CLI** named the turn by `--turn <ms>`, its end as `watch` gives its
  row's `since`, in place of asks, `--until` optional with it:
  `sitrep snooze (<ask>... | --turn <ms>) [--until <ms>]`, `sitrep wake
  (<ask>... | --turn <ms>)`. `--turn` went on 13 November 2026.
- **The JSON:** each line of `watch`'s `snoozed` gained `is`, `ask` for an
  ask, `yourTurn` for a turn; a turn's line holds `ask` null, and `wakesAt`
  null until it moves, and so may a row's `wakesAt`. This broke a reader
  once, by plan, with no `v` moving (see `watch`, under "One engine, two
  front ends"): the app took it in the same change, reading a line with no
  `is`, from a CLI before it, as an ask's.

### The row snoozes

Decided with Lee on 13 November 2026: snooze acts on a session's row,
putting off its asks and its turn together, until the time he picks. A row
of the session's asks asleep beside one of its turn, each woken by its own
rules, had Lee waking and snoozing twice for one thing he meant to put off.

- **What it puts off:** everything the session needs of Lee: every ask
  waiting on him as the snooze is written, and his turn there, whenever it
  ends while the snooze holds. A row with only its turn snoozes from the
  same control, and its stops stay his window's.
- **What wakes it early:** a new ask posted to the session after the
  snooze; Lee's own prompt submitted in its window; and, Lee writing to it,
  his reply to one of the asks it holds (see the fold, above). Claude
  reopening an ask is a new ask in all but its id, and wakes it too; so,
  while it waits, does an ask the snooze does not hold waiting on Lee
  again, its answer voided or taken back.
- **What does not:** its turn ending on its own, as background agents
  finishing do, the window's next turn after one the snooze put off going
  straight back to Snoozed; a window merely joining; anything else Claude
  writes; Lee's answer to an ask that was on its way as he snoozed, written
  down after.
- **Once woken** it shows as any other session: its asks back in Needs you,
  its turn on Your turn, and a turn ending after Lee wrote is a new need.
- **Drawn** as snoozed rows are since #124 (see "How each row reads"): one
  row in Snoozed, its mark its Needs you row's colour dimmed, an ask's
  orange where any ask sleeps in it, as a row of asks at Lee's turn is an
  ask's in Needs you, and Lee's turn's blue for a turn alone.
- **Lee's prompt:** the mod's `prompt.submit` hook, where the prompt is
  Lee's own, typed in the composer or sent through Remote Control's bridge
  (`isLeesInput`), writes a `wakeSession` in the held session's window file
  through the hold before the board's change is read, so the waking rides
  in with the prompt. Anything Lee types in the window counts, a slash
  command among them, by design: he is there. It writes only while
  something he snoozed of the session still holds (core's `isAsleepAt`), so
  never for a snooze run out; nor for a turn that starts without him: a
  task's notification, a scheduled wake, a loop, or a board message. A
  window not yet reloaded runs the mod from before this, so Lee's prompt
  there wakes nothing until it reloads.

**Until it moves** (Lee, 13 November 2026, keeping it from board I, and the
same on every row): Snooze's fourth choice, after a separator, with no time
beside it. Its row comes back when the session's turn next ends, when it
posts a new ask, or when Lee writes to it: the wakes every snooze has, and
the turn's end, which wakes no snooze with a time. On a row of asks whose
Claude is still working, that brings the row back once Claude stops. A
session with asks that has also stopped stays one orange row, the ask
winning, as in Needs you.

- Its line is a `snoozeSession` with no `until`; the CLI's `snooze` with no
  `--until`. The row in Snoozed has no `wakesAt`, reads "until it moves"
  in its time's place, and sorts after every row with a time.
- The window ending the turn writes the wake: as its main conversation's
  turn ends, by its Stop, unless a settings hook blocked it, or by its
  `turn.complete`, whichever comes first, the mod writes a `wakeSession`
  through the hold where a snooze of Lee's until it moves holds on the
  session it holds (core's `isUntilItMoves`), before the turn's end is
  heard, so `watch` sees the session woken as it reaches Lee's turn and
  tells it as any turn ending (see "What fires for Lee's turn"). A
  subagent's turn ending writes nothing. A window joining is no turn
  ending, and wakes nothing: the fold never reads a turn's end as a wake.
- A window not yet reloaded writes no such wake: there the snooze holds
  until Lee wakes it, an ask lands, or he writes to the session.

**Reading the old lines.** Every board on disk stays readable, and old
writers and readers stay safe:

- An old `snooze` of an ask keeps its old meaning, per ask: its own time,
  for the ask it names waiting as posted, open and not replied, ended as
  that ask closes, reopens, or is woken by an old `wake`; one naming
  anything else is passed over, as before. Besides, while old lines'
  snoozes hold every ask waiting on Lee in the session, its turn sleeps
  with them, until the first of them wakes or closes, or a new ask lands.
  That joins Tailspin's turn to its three snoozed asks, the case Lee raised,
  in one row, waking as the first ask does, and leaves a session whose
  asks Lee left showing as it was, its turn on its Needs you row.
- An old `snoozeTurn` holds as it always did: until its time, or with none
  until the session takes another turn, and ended by a `wakeTurn`, by
  something after it needing Lee or his reply, and by Lee's snooze or wake
  of the session. Of a session snooze and an old turn snooze both holding,
  the turn wakes as the later does.
- Lee's snooze of the session stands in place of whatever old lines
  snoozed of it, and his wake of it, from the app, the CLI, the pane or
  his prompt, ends them all.
- Old readers, a window not reloaded or an app before this change, skip
  `snoozeSession` and `wakeSession` as any line they do not know, so they
  show the session's asks waiting until they reload. The app ships its own
  CLI, so its row menu and its CLI always agree.

## Storage

```
$XDG_STATE_HOME/sitrep/, else ~/.local/state/sitrep/
  snooze.json                 Snooze's choices as Lee set them in SitRep: the app's alone, for the pane and the terminal view
  here.json                   who SitRep last read viewing each held session and each multiplexer tty: the app's alone, for the panel in a terminal
  media/<name>.<ext>          an image or document Lee attached to a reply he wrote in the prompt, for Claude to open: 0600, in a 0700 folder
  projects/<project key>/
    project.json              name, directory, created and by whom: the project's own
    sessions/<session id>/
      session.json            name, summary, project, root, created and by whom: written once, by whoever starts the session
      <writer>.jsonl          one file per writer: each window as Claude Code's session id, the CLI as `cli`
      inbox/<sender>.jsonl    replies from other sessions, one file per sending writer; the CLI's answers as `cli`
      presence/<writer>.json  each attached window's heartbeat
```

- **Project key:** a new project's name as a slug, accents dropped
  (`sitrep`), numbered on (`sitrep-2`) where a folder already has it. The
  key is only where its files are; the name in `project.json` is what
  matches and shows.
- **`media/`** (23 November 2026; see "An answer with an image"): one file
  for each attachment the answering mode saved, named by 16 random
  characters and the extension its type names. A window writes them, and
  removes them as their reply leaves Ready to send without going, or at a
  session start once 14 days past its send and named by nothing in its
  Ready to send. Claude reads them there with no prompt.
- **`project.json`:** `{ v, name, directory?, created, by }`. A start or
  Claude's `move` writes it as it makes the project, and the `project`
  tool as it renames it or gives it a directory; a start or Claude's
  `move` giving a directory to a project with none writes it too. It
  breaks the one-file-per-writer rule below: whichever writer makes the
  change rewrites it whole, and the last write wins. That is fine for a
  file rewritten only that rarely, by Claude, at Lee's word.
- **`snooze.json`** (17 November 2026; see "Lee sets the times", under
  "Snooze"): Snooze's choices as Lee set them in SitRep's Settings, for the
  pane in Claude Code to offer the same. It sits at the folder's top, beside
  `projects/`, where every reader of the board already looks; of the CLI,
  only the terminal view reads it, for its snooze menu. The defaults, as the app's encoder writes them, indented,
  their keys in order (`tests/choices.ts` holds the encoder to its text):

  ```
  {
    "hour" : {
      "on" : true
    },
    "later" : {
      "hours" : 3,
      "on" : true
    },
    "tomorrow" : {
      "at" : "09:00",
      "on" : true
    },
    "tonight" : {
      "at" : "18:00",
      "on" : true
    },
    "v" : 1,
    "week" : {
      "at" : "09:00",
      "day" : "monday",
      "on" : true
    },
    "weekend" : {
      "at" : "09:00",
      "day" : "saturday",
      "on" : false
    }
  }
  ```

  Each choice by core's name for it; `on` whether it is offered; Later
  today's `hours`, 1 to 4; a time as `at`, `HH:MM` on the 24-hour clock; This
  weekend's `day`, `saturday` or `sunday`, and Next week's any weekday, by
  its English name in lower case.
  - **The app alone writes it,** from what it keeps in its own defaults
    (`snooze`), whenever a snooze setting changes and as SitRep starts, so
    it always says what the app has, a file another build wrote put right
    at the next start. It writes the whole file beside it, then renames it
    over the old (`Data.write`'s `.atomic`), so a reader never sees half a
    file. It finds the folder as core's `rootOf` does, from its own
    environment, which its CLI's `watch` runs with, so the file sits by the
    board SitRep shows.
  - **The mod reads it** at each look around the held session, every 5
    seconds: the look lists sitrep's folder, reads the file again only once
    its size or time moved, and puts what it says in `$.state` (`snooze`)
    only when that changed, so the pane draws from it and never reads the
    file as it draws, and a change shows within a look. A read that failed
    is not kept, so the next look reads the file again; nor is one taken
    within 2 seconds of the file's time, as git distrusts a file changed as
    its index was written: a rewrite of the same size within the time's
    resolution, a second on HFS+ and two on exFAT, leaves the time as it
    was. A press works out its time from what `$.state` holds then.
  - **Read leniently,** never an error the pane shows, nor one that stops a
    look: a file missing, unreadable, not a JSON object, or whose `v` is
    not a whole number from 1, or is later than the reader's, reads as the
    defaults; within one, each choice and each field of it is read on its
    own, by its type, one missing, of another type or out of range taking
    its default, so a file partly filled keeps what it says. A field a
    later version adds is passed over. Its format is 1, its table of
    upgrades empty (core's `snooze.ts`, by `versions.ts`).
  - **What `$.state` holds is read whole** where the pane draws and a press
    works out its time (core's `heldSnooze`): a choice it lacks, or a field
    of one, takes its default, so a build that adds a choice draws, and
    snoozes, before its first look rewrites what an older build stored.
  - SitRep is its one writer, as the one-file-per-writer rule below has
    every file, so it needs no lock.
- **`here.json`** (20 November 2026; see "The board in a terminal"): who
  SitRep's last read of here saw viewing each held session, and each tty
  inside a multiplexer session (stage 8, "How it is read"), for the board
  in a terminal to draw hollow and dimmed what is open on no device it is
  looked at from. Compact, its keys sorted, its slashes as they are
  (`tests/here.ts` holds the app's encoder to its text):

  ```
  {"at":1763650000123,"sessions":{"sr-ct0002":["ssh:192.0.2.7"],"sr-nw0001":["mac"]},"ttys":{"/dev/ttys004":["ssh:192.0.2.7"]},"v":2}
  ```

  - **A viewer** is `mac`, this Mac's screen, or `ssh:` and the address
    of a device reached over SSH, from the first field of
    `SSH_CONNECTION` in the client's environment, so every tab one phone
    opens counts as that phone. `sessions` gives each held session read
    its viewers, none for one open nowhere; `ttys` gives each multiplexer
    tty with a viewer its session's, by its device, `/dev/ttys004`, named
    from the kernel's numbers as the panel names its own. Version 1, which
    named only the sessions no terminal on this Mac showed as `notHere`,
    reads as each of them seen by nobody.
  - **The app alone writes it:** at once as what it says changes, and
    otherwise at most every 10 seconds while any held session is read, so
    `at`, the write's time in milliseconds since the epoch, stays fresh.
    With no session read, as with nothing held, it removes the file, once.
    It writes the whole file beside it and renames it over the old, off
    the main thread, a write at a time; a write that fails makes no folder
    and is tried again at the next settling, and the first of a run of
    failures is logged. It finds the folder as for `snooze.json`, and
    removes the file as SitRep quits, waiting a second at most. Until 20
    November 2026 it wrote only while a held session was dimmed; the panel
    over SSH needs the file whenever sessions are held.
  - **The CLI's panel reads it** at every look, the board read or not
    (core's `notHereOf`), and dims each held session whose viewers share
    none with its own: its own tty's, where the file lists any; else the
    device its own `SSH_CONNECTION` names; else `mac`. A file missing,
    unreadable, misshapen, of a later version, or 30 seconds or more from
    the moment it is read, either way (`HERE_STALE_MS`), says nothing, so
    a held session draws filled while SitRep isn't reading, as does one
    the file doesn't name. The limit matters only for a SitRep crashed,
    hung or napped: SitRep runs in the background with no activity held
    against App Nap, so its sleep may stretch well past 10 seconds. The
    mod never reads it, and the board reads `projects/` alone.
- **Folders from before projects were named** keep their keys
  (`code-3f9a1c2e`, `switchboard-5b0e7d41`, from the folder a window
  started in): no key is renamed. Without a `project.json`, such a project is
  named as its sessions' `session.json` recorded it, its first letter a capital
  (`Code`). Matching and showing read `project.json` first, so writing one
  there (the `project` tool does, from a window holding one of its sessions)
  relabels the project in place.
- **Session id:** `sr-` and six characters (`sr-k3f9qa`): short enough for
  Claude to record, and easy to grep. Items and replies get four characters,
  unique within their session. A new session's id is unlike every one filed.
- **A session's folder** is under the project it was started in, for good
  (17 November 2026; see "A session moves to another project at Lee's
  word"). It is filed under the project its latest `move` line names, where
  that project is on the board, and named as the board names that one;
  else under its folder's. Every ref the window keeps names the folder,
  and reads and writes go there by it. Only a ref a view drew, naming the
  project it showed the session in, or a bare id finds the folder, by the
  session's id: the project named first, then every project's folder, the
  one whose `session.json` of the id reads; none, and nothing is written.
- **Two layouts, side by side, 19 to 27 October 2026.** `works/` became
  `sessions/` and `work.json` `session.json` with the words, as "Versions
  side by side" has it. While windows not yet reloaded still wrote the old,
  every reader, the mod's and the CLI's, read both as one (core's
  `layouts.ts`): a project's sessions were both folders' sessions, a
  session's meta its `session.json` where that read, else its `work.json`,
  a writer's file under both names every line of both, a line in both, byte
  for byte, once, and of a window's two heartbeats the one seen later. The
  old layout was read first, then today's, never both at once, so a file
  the move took between the two reads was found under the new. Writers
  wrote `sessions/` alone. The CLI moved the old into today's as each
  command started, and `watch` every 10 minutes (a mod's `$.fs` can neither
  delete nor rename), once no window on the board saying no `version` (a
  release from before heartbeats said it, which still wrote the old) had
  been seen within a week (`OLD_WINDOW_MS`), unless it let go; meanwhile
  such a window, live on a session, delivered its inbox first, since it saw
  no heartbeat under `sessions/`. Each step put a file under its new name
  before the old lost it: a link in, then the old name unlinked; lines
  today's file lacked appended; a later heartbeat renamed over today's.
  Tried live over a state folder of its own (19 October 2026): an old
  session read and posted to while a versionless window was live, then
  moved by the next run once that window said its version; run again,
  nothing changed; and three runs at once over six old sessions left
  nothing under `works/`.

  Gone on 27 October 2026, with nothing of the old layout left on any Mac:
  this Mac's state folder held no `works/` and no `work.json`, the Mac mini
  no sitrep state at all, and no window says no `version` but those long
  let go or stale. No Claude process is older than this Mac's boot on 22
  October 2026, so no load and no `$.state` is left from before the words.
  The dual reads, the move, `OLD_WINDOW_MS` and the old windows' first
  claim on delivery went with it, and the files the CLI could move and
  remove with them: every reader reads `sessions/` alone, and the CLI's
  file system only reads, lists and appends. A window whose manifest does
  not read, and so says no `version`, delivers as any window does, by when
  it attached. A window still on the release before gives such a window,
  live, the first claim to deliver, and this release does not: while the
  two run side by side, its session's inbox can be delivered by two Claudes
  or by none, until the older window reloads. That needs a manifest read to
  fail, so it is rare, and a reload clears it; the next release's version
  has `watch` list the windows to reload.
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
  `options`, and the one Claude recommends, where it gives one, as
  `recommended` (13 November 2026); a words ask, where it says, what its
  words are, as `needs`; and `where` and `ref` where it has them. An
  edit's changes name the fields they set; an empty `needs` or
  `recommended` clears it, where any other empty field is refused. An edit
  leaves an ask holding only what its shape takes: one made to want a
  choice drops its `yes`, one made to want a yes its `options`,
  `recommended` and `needs`, and one whose options leave out the option
  recommended drops `recommended`, as the fold reads it, so an edit line
  never names the drop. A line without `recommended` reads as before, and
  an old reader passes over the field, skipping an edit that changes it
  alone, as it skips any line it cannot read. A reply's verdict is `yes`, `choose` (with its
  `option`), `answer` (a words ask's words, as its `note`), `comment`,
  `ignore` or `pickup`; a yes or a choice may carry a comment as its note.
  A pick-up names the session its message went to, by its id (`to`, 17
  November 2026; see "Parked's picked up"): an older reader passes over the
  field, and a pick-up written before it reads as going to no session
  known. The format's version stays 1: a new reader reads every old line, and an
  old reader skips an ask line it cannot read, as it skips any.

  **Parked items as the project's** (11 November 2026; see "Parked items
  are the project's") change no format and rewrite nothing. A `park` line
  stays in the file of the session that parked it, and its replies, marks,
  resolves, edits, reopens and drops go into that session's folder,
  whichever session's window or Claude writes them, each writer in its own
  file there. A project's parked items are read, not stored: the views gather
  them from every session filed under the project. Moving them to the
  project was set aside: an item's history is spread over its session's
  files and folded as one session, item ids are unique only within a
  session, and neither a mod nor the CLI can remove a line, so a move would
  have left every reader reading both places.

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

  **An edit answers to `ask`'s checks for what it changes** (17 November
  2026): to each check reading a field of the shape it names, what the ask
  wants among them, so an edit to what an ask wants answers for the whole
  shape. A check an ask breaks already, on fields the edit leaves alone,
  refuses none of it: a decide written before asks had options, which reads
  as a choice with none, takes a new title, `where` or `ref`, while an edit
  giving it one option, a yes or `needs` is refused as ever, each by the
  check it touches. One recommending an option is held to the choice's
  options too, so on such a decide it reads `A choice ask needs at least 2
  options.`, not the options it names, which are none. Until then every
  edit answered for the whole shape, and such a decide refused them all,
  its title too: `A choice ask needs at least 2 options.`

  The kinds: `status`, `ask` and `park`; `resolve`, `reopen` and
  `edit`, each naming an item; `reply`, Lee's answer to one; `delivered`,
  naming the replies Claude has been given; `drop` (18 November 2026),
  Lee's drop of a parked item, naming it (`item`), written in the session
  that parked it, in the writer's own file there (see "Dropping a parked
  item"); `finish`, the session finished,
  saying who (`lee` or `claude`) and with an optional reason; `unfinish`, a
  window joining it again; `move` (17 November 2026), the session moved to
  another project, named by its key (`project`), which reads as a folder's
  name, letters, digits, `-` and `_`, or the line is a bad one, so no reader
  makes a path of it; and `snoozeSession`, Lee's snooze of the session
  until a time (`until`), and `wakeSession`, Lee's waking of it now, Lee's
  alone and written to the writer's own file, never an inbox (13 November
  2026; see "Snooze"), which `snooze` and `wake` of an ask (23 October 2026)
  and `snoozeTurn` and `wakeTurn` of a turn (4 November 2026) came before,
  still read and no longer written. A `note`, Claude's note until notes
  went (17 November 2026), is still read, for its `id` alone: the id stays
  taken, and the line dates its session and counts in its writer's file as
  ever, but it posts nothing; an edit's `text` and `detail`, a note's, are
  read and ignored the same (see "Notes went"). The session holds the latest finish, when, by which
  writer and why, until an unfinish clears it. Who is a field of its own
  because Lee's pane and Claude's tool write as the same window.
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
  file held twice, byte for byte, read once while the move could append it
  twice; since the move went (27 October 2026), each line reads as itself.
- The status shown is the latest across writers. A status change is noticed
  by the board as it reads, comparing each status with the one before; it is
  never written down. The changes so noticed, the newest first, are the
  session's history, which Status opens to.
- A reply counts as delivered once a writer **in its session** has written a
  `delivered` mark naming it: Claude has it. For this session, the mod
  writes the reply and the mark together, once Claude Code has taken the
  message. For another session, the sender writes the reply into that
  session's inbox, and the window that submits it there writes the mark to
  its own file. A pick-up of another session's item goes to the window it
  was pressed in, which writes the reply and the mark together in the
  session that parked the item, in its own file there (11 November 2026;
  see Delivery). The CLI's answers go in as another session's replies do, as
  its letters, `inbox/cli.jsonl`, appended to; the window's mark is the
  trace the CLI reads them delivered by (20 October 2026). A reply is void
  where "Which replies go in" (under Delivery) says so, its reason kept with
  it in the fold, none on disk: a second answer to an item, one reaching an
  item closed or a session finished, one on its way as Claude closes its
  item or the session finishes, one an edit leaves fitting its item no more;
  and a mark makes any of those go in but the last, which it makes delivered
  and leaves void, settling nothing. Only replies count from an inbox.
- **Presence:** a mod can't tell that its own window died, so each attached
  window rewrites its heartbeat (`attachedAt`, `seenAt`) every 30 seconds, and
  a session is open while a heartbeat is under 90 seconds old. A mod can't
  delete a file either, so a window that lets go adds `leftAt`, and, where
  it lets go as its conversation ends while its Claude lives on into the
  next (a `/clear`, or a `/resume` in the same process), `livesOn`, true
  (12 November 2026, stage 8): that window is the ended conversation's no
  longer. Other values read as none. Of several
  windows on one session, the one attached longest submits its inbox, so two
  never both do. A heartbeat also says `where` its window is, as far as that
  is known (see "The menu bar"): `device`, `terminal`, `tmux` with its
  `socket` and `pane`, and `zmx` with its `session` (9 November 2026). It is
  read field by field, a bad one dropped, and a heartbeat is never lost
  over it; one written before it reads as ever. It also says its
  `directory` (12 November 2026, stage 8): the folder its Claude runs in,
  the resume command's `{dir}`, the engine's `$.session.root()`, which
  entering a worktree or `/cd` moves and a shell's `cd` does not, read as
  the window attaches and again at each beat, a read that fails keeping
  the last; read as `where` is, one written before it saying none. It
  also says the sitrep `version` its window runs (19 October 2026): the
  `version` in the plugin's manifest, `.claude-plugin/plugin.json` under the
  plugin's folder, read once as the mod loads and kept for the load, a failure
  too, since the manifest on disk may by then be newer than the code the
  window runs: SitRep replaces its copy whole at an update, under windows not
  yet reloaded, and a checkout under `app/plugin here` moves on. A manifest
  that cannot be read leaves it out, says so once in the debug log, and the
  heartbeat beats on; that window then reads as one needing a reload, which is
  safe, and rare. It is read as `where` is, field by field; a heartbeat with
  none, read today, is a window whose manifest did not read: one on a release
  from before heartbeats said it wrote under `works/`, which no reader reads
  any more (see "Two layouts, side by side", above). `sitrep watch` says which
  windows need a reload, for the menu to list. It also says the window's
  `state` (19 October 2026), with what the row shows of it, rewritten at once
  as it changes (how the mod hears it is under "A session's state"):

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
  - `sending` (22 October 2026) is the replies the window's messages carry
    to the session, each send's from its claim until the claim ends (see
    "Its replies on their way from the claim", under Delivery), each reply
    as its line will hold it, with when its message was claimed. A pick-up
    of another session's item is never said here (11 November 2026; see "A
    pick-up goes to the window it was pressed in", under Delivery):

    ```
    "sending": { "at": 1760000005000,
                 "replies": [{ "id": "q7rx", "item": "k3f9",
                               "verdict": "choose", "option": "Keep it" }] }
    ```

    A window sending several (5 November 2026) says them as a list of
    these, in the order claimed; sending one, it says it alone, as above,
    as windows said their one message before, so a reader on an older build
    still reads it. A reply's words go whole, a note of several lines too,
    so the boards show it as they show an inbox reply (`board --json`'s
    `reply`, the pane's `+3 lines`). It is read field by field: a reply that
    does not read as a reply line's fields do is dropped, and a message with
    no time, or with no reply that reads, is none, as is `sending` with none
    that reads; the heartbeat is kept. It is rewritten at once as a claim
    changes, through the window's serialised writes, and said again on every
    beat; a window that lets go says none.
    The mod's boards leave it out as they leave `state`, the replies it says
    showing on their items.
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
  folder too, or is handed the listing its look made of it, so a rename shows
  on every pane within a look. A session's heartbeats are read before its
  lines, its folder listed again after them where it has any (22 October
  2026: one more listing a look, so a send handed from a heartbeat to the
  lines is never missed). The sessions around the held one are read every 5
  seconds, each through its reader: they are glanced at, not watched. Every
  project is read, the pane open or closed, for the band's `elsewhere` and
  the All projects tab: each look lists each project's folder once, handing
  its listing to each of its sessions' reads, which list the session's
  folders and read again only a file that changed. A session is folded again
  only once its files changed, or once its own fold changes by time alone
  (core's `nextFoldChange`, 27 October 2026; the held one's too, at its
  watch's look, since 16 November 2026): as its part of the board does,
  and as any snooze standing on it runs out, one over an ask Lee's reply is
  on its way to, or in a finished session, among them, and one an ask it
  does not hold sets aside. This is not
  `watch`'s rule, which folds every session again as the board changes (see
  "Expiry") and stands for what it prints; a window shares whole folds, its
  `others` and the first message's listing among them, where a snooze the
  board leaves out still shows. A session off the board, with no live window
  and finished or idle past the views, is read only on a whole look, every 10
  seconds as `watch` reads its own (core's `reading.ts`), its first look
  whole; between them it is folded from the files it last read, so its
  folders are not listed. The window's pace allows half a look's slack, as a
  look reads the clock a little after its timer fires: without it, a whole
  look read a few milliseconds late left the one two looks on just short, and
  whole looks came every 15 seconds. With the pane open, the session it looks
  at and those replies wait for or went to are read in full too, at every
  look whatever their state, and so is the session of the item Lee is
  answering in the prompt, open or not, read at once as the press begins
  answering it.
- **What a look carries** into `$.state`, every 5 seconds, is what the
  board draws, and no more (17 November 2026). For every project: its
  current sessions in brief and what every session of it parked, which
  the band, All projects and Parked draw. What grows without end, as its
  sessions live, only for the projects that draw it: each session's name
  by its id, for the held session's project and the project of the place
  the open board shows, a session's or a project's, where Parked's picked
  up names the session a pick-up went to, with the name of every session
  the pick-ups it lists went to, wherever that session is filed now (18
  November 2026: once the session that parked an item or the one that
  picked it up moved to another project, the item read `picked up` alone,
  as the names were only of the sessions filed under the project); what
  was taken off the Parked of
  every session filed under it, finished and idle ones included, only while
  the open board shows a view of the project, its own or a session's, home
  among them, which draw it; and its old sessions, only while the open board
  shows the project's view, the only place that draws them. Of each list,
  the latest 3 it shows and how many there are, and every one only while
  that list shows all, so a long past costs no more than its count until Lee
  asks for it. The old sessions are read from the sessions the look reads
  already, every one filed under the project, as Parked's are: no walk of
  their own. A look keeps a project with no current session and nothing
  parked while the open board shows a view of it, so a finished session's
  view there, its items all picked up, still draws what was taken off.
  A move on the board moves at once and reads around
  after, as a press of a project list's toggle reads around again (6bedc72
  read first, and a move waited a look behind it, up to a second and a half
  just after a window started, for ever on a hung read). So a view draws
  its picked up, and a project's its old sessions, only once the look has
  carried them, a beat after it opens: never counted by this session's
  alone and then by all. The held session's own picked up are always whole,
  from its fold; a look from before the window took up the session it
  holds, which read that session as one around, gives the view neither list
  until the next, since what it carried, only in part, would count that
  session twice, or list it as old. A pane drawn but not marked open, which
  only a test mounts, draws neither.

  Until 17 November 2026 a look carried a project's history too, its
  current sessions' changes of status, for its view, and what was taken off
  its Parked for its view alone. Across a switch of builds either way, by
  `/reload-plugins`, nothing throws: every list a project carries is
  optional, and a view draws none it does not find. A build from before,
  reading what this one carried, finds no history and draws none, and
  passes over the old sessions; this one, reading what a build from before
  carried, passes over its history, and draws no old sessions, and a
  session's view no picked up, until its own first look, 5 seconds at most.
- The pane's last view lives in the window's `$.state` only: where it looks,
  the item opened there, and, apart from that, how much each list of the
  board's past shows (`shown`, by the list), the held send Ready to send's one row for several
  shows (`heldShown`, by the ids of the replies it carries; 5 November
  2026), and where Claude Code last seated the pane on each surface, kept
  when it closes (see "The band"); a pane an older load saved, without any
  of these, reads as none. `$.store` is unused so far.

## The structure

Settled with Lee on 9 November 2026, from first principles, as Lee asked
where the logic would live were SitRep designed afresh. Three lines open
it:

- **The board lives with Claude Code, and never depends on SitRep
  running.** Quit SitRep and every window's pane, its band and Claude's
  tools go on working; an upgrade quits SitRep, and so do a restart and a
  crash.
- **SitRep is a window onto the board, and does the Mac's own work.** The
  notch, the strip, the menu bar item and the banners show the board;
  finding a session's window and bringing it forward are the Mac's.
- **The plugin ships inside SitRep.** Installing it alone is possible, but
  not supported (27 October 2026; see "Where it lives").

Then where each part lives:

- **The board's rules live once, in core**, in TypeScript, shared by the
  mod, which must be TypeScript, as Claude Code runs it, and the CLI.
- **Files are the store**, the folder the truth, with no server (see
  "Storage").
- **SitRep reads the board through `sitrep watch`, and never repeats a
  board rule**: what a row says, what needs Lee, what is new, and which of a
  session's windows a jump tries first come worked out by core.
- **The Mac's own work belongs in SitRep, in Swift**: finding where a
  session's window shows, the jump, whether a session is on screen, opening
  a window, and Spaces. It sits behind two interfaces, the two axes the jump
  already has (see "The jump"):
  - **terminal drivers**: focus the window on a device; open a new window
    and type a command into it;
  - **multiplexer adapters**: list a session's clients. How to attach is
    no adapter's: it is the user's resume command (stage 8, rethought on
    13 November 2026). Until then they also gave the facts a session's
    window recorded (its name, socket, pane) for the open command (step C
    of stage 7), which the rethink folds into the resume command.
- **The mod still records where its window is**, in its heartbeat's
  `where`: only it sees its environment, its device, `$TMUX_PANE` and
  `$ZMX_SESSION`.

**The drift it corrects.** "The app holds no sitrep logic" (13 October
2026) was there to keep the board's rules out of the app, and swept the
Mac's own work into the CLI with them: the jump was built in TypeScript,
asking `ps`, osascript and lsappinfo for what the app can ask macOS itself.
The rule now reads "no board logic" (see "The menu bar"), and stage 7 moves
the Mac's work into SitRep (see "Stages", under "The menu bar"). The CLI
stops being a product of its own, as the plugin alone is not one, and
becomes SitRep's bridge to core: `watch`, and the snoozes and wakes the
card's row menu writes.

**Considered and set aside:**
- **Everything in Swift**, the mod calling SitRep for the board: every
  window would stall whenever SitRep is down, as an upgrade quits it.
- **A central engine**, one process every surface talks to: a server to
  start, keep and restart, where files already share the state.
- **Core run inside SitRep on JavaScriptCore**, and the Bun CLI dropped.
  The purest form: the board's rules still written once, in TypeScript, and
  no Bun in SitRep. It was the named later destination, since the CLI is only
  SitRep's bridge, until Lee dropped it on 18 November 2026: the compiled CLI
  works, and nobody feels Bun.

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
    `doneInFull`) was read in today's names (`hooks/older.ts`), so a window
    reloaded mid-session kept its session, its place on the pane and Ready
    to send; that went on 27 October 2026, no Claude process being older
    than this Mac's boot on 22 October. `older.ts` also read a message in
    flight a load from before the window held messages (23 October 2026)
    left without `isHeld` as not held; windows started since the boot may
    still run such a load, so that stays: the slot reads a claim saying no
    `isHeld` as not held, and a claim not held and not taken is let go
    after its quiet time, whatever it says. Since a window holds several
    messages in flight (5 November 2026) the slot keeps them as a list, but
    one alone as itself and none as null, as loads before kept the one
    message, and reads either: so a window reloaded into this build mid-send
    keeps its send, and one switched back to an older build (`app/plugin
    app` after a live test) reads a lone send, and none, as it always did. A
    list of several it reads as one message it cannot place, carrying
    nothing, so their replies show in its Ready to send as still to send;
    it takes nothing from the inbox meanwhile, and once a turn has ended and
    its quiet time passed it lets the list go, then throws on what follows,
    the message naming no source, so no toast says so. An update of its
    that leaves the message as it stands, as a press of send does, writes
    back an object spread from the list,
    `{ "0": …, "1": …, "isHeld": false }`: this build reads that as no
    claim, nor as the claims inside it, since that build may have let Lee
    cancel their replies or send them again. A reader on an older build drops a heartbeat's `sending` list, as
    it drops any `sending` it cannot read, so it has those replies waiting
    on Lee, not on their way, while several are said.
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
      the header, each section's heading, each entry of a list (an ask, a
      status change, a parked item, one picked up or closed, a closed ask, a
      session, a project), each list's toggle, Status whole, the foot, and
      a blank row closing the list; the blank
      row between sections is the next block's own. Docked, a `Client`
      spans each block down the column the pane keeps free beside its
      lines (`hooks/draw/measure.tsx`), drawing nothing, and posts the rows
      the block takes whenever they change. It is keyed by its block, a
      session's item by its address, and a status change by its session,
      its time and its writer, with its place among one writer's changes
      of one millisecond. Claude Code draws nothing of a tree holding two
      `Client`s under one key: keyed by their time, a send of several
      pick-ups, each logged in Notes as it was then, left the docked pane
      blank until newer lines pushed all but one out of Notes (8 October to
      5 November 2026). The list is as tall as its blocks, and a block sits as far
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
    refused the call, so the pane claims from its send button's own
    handler, and submits there while Claude is between turns. Since 22
    October 2026 the window holds a message claimed mid-turn rather than
    submit it to wait (see Delivery), and submits it from the `turn.complete`
    hook, never waiting on it there: a hook awaiting its own submit never
    ends, while one not awaited starts its turn about 13 ms after the last
    ends (a probe, 2.1.308).
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
    The window now holds a message claimed mid-turn, so a reload mid-turn
    finds it held: the new load keeps holding it, and submits it as the turn
    ends, or at once should it find the window between turns. What the
    probes settled holds for one submitted as the turn ended.
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
  sitrep ask <title> --wants yes|choice|words [--yes <label>] [--option <choice>]... [--recommended <choice>] [--needs <words>] [--where <words>] [--ref <ref>]
  sitrep park <title> [--where <words>] [--ref <ref>]
  sitrep status [--name <words>] [--summary <line>] [--now <line>]... [--next <line>]
  sitrep answer <ask> (<answer> | --ignore)
  sitrep snooze <ask>... --until <ms>
  sitrep wake
  sitrep finish
  sitrep move <project>
  sitrep board [--json]
  sitrep list [--project <name>] [--json]
  sitrep watch
  ```

  - It runs no program (10 November 2026, stage 7, step B): `screen` and
    `jump`, below, were retired once SitRep read on screen and made its
    own jump, and the CLI's readings of tmux, zmx, `ps` and Ghostty, and
    the Bun binding's runner of programs, went with them.

  - It writes as the writer `cli`, appending to `<session>/cli.jsonl`, a
    snooze and a wake among its lines (see "Snooze"), and an answer to its
    letters in the session's inbox, `<session>/inbox/cli.jsonl`, the same
    way: each file's count goes on from that file, a torn last line ended
    first, and nothing is rewritten. It never writes a delivered mark or a
    heartbeat: it is never a window on the session. Until 27 October 2026,
    before a command read the board, it moved the old layout into today's
    (see "Storage").
  - What it posts is checked by core as Claude's tools' posts are, and a
    refusal prints the check's words. A post prints its item's id and nothing
    else, so a script can keep it. An ask says what it wants back with
    `--wants`, as the ask tool does, and its `--yes`, `--option`s, with
    `--recommended` where Claude leans toward one (13 November 2026), or
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
    { "v": 2, "here": "switchboard",
      "projects": [ { "key": "switchboard", "name": "Switchboard",
                      "open": 1, "waiting": 2, "snoozed": 1, "parked": 1,
                      "updatedAt": 1760000000000,
                      "sessions": [ { "id": "sr-k3f9qa", "name": "Dashboard redesign",
                                      "summary": "...", "now": ["..."], "next": null,
                                      "isOpen": true, "waiting": 1, "snoozed": 1,
                                      "parked": 1, "created": 1759990000000,
                                      "updatedAt": 1760000000000 } ] } ] }
    ```

    Each project's `sessions` were its `works`, their name from before a
    piece of work was called a session, until 27 October 2026, which moved
    `v` to 2.

    `snoozed` (23 October 2026) counts the asks Lee snoozed, which `waiting`
    leaves out (see "Snooze"); plain `list` says it among a session's facts,
    `(open, 1 waiting, 1 snoozed)`.

    `parked` (11 November 2026; see "Parked items are the project's"):
    a session's counts the items it parked; a project's counts every item
    parked in the project, from every session filed under it, finished and
    idle ones included, and a project with something parked is listed though
    none of its sessions is current, its `sessions` empty, and dated by the
    latest of the sessions holding its parked items; plain `list` says
    `no current sessions (2 parked)`. Until then a project's counted its
    current sessions' alone. A meaning changed, no shape: `v` did not move.

    `created` (4 November 2026) is when the session started, as its
    `session.json` says; `board --json`'s `session` and `watch`'s sessions
    carry it too, built for the SitRep window to say when it started. A
    field added: `v` did not move.

    `list` runs no program. Each session said `onScreen` until 27 October
    2026, whether a jump could reach it (see "The jump", step 2), which only
    `--json` worked out, asking tmux twice per socket; the app's plain menu
    was its only reader, and it went with the menu. `v` stayed 1: no reader
    is left to trip on the field's going. It came back on 4 November 2026 as
    a command of its own, `screen` (below), built for the SitRep window, and
    went again on 10 November 2026.
  - `screen` (4 to 10 November 2026) said whether each session a window
    held was on screen: whether a jump could reach it, a terminal window of
    this Mac showing it or tmux able to make one show it, exactly as the
    jump found it (see "The jump", step 2), by the same reading. It was
    built for the SitRep window's rows and pages, to say whether a session
    was on screen; once the window went (5 November 2026) the app ran it no
    more, and it was kept only for stage 7's parity check (A2), then
    retired with the jump in step B. What follows is the record of it.
    - Three states, never two: `on`, a place shows the session or a select
      would make one; `off`, none does, every program asked of its windows
      having answered; `unknown`, none found, as tmux gave no answer for a
      socket one of its windows runs under, or `ps` none where that server
      has clients, whose apps it tells, or where a window runs in zmx, whose
      clients only `ps` tells (9 November 2026). A jump that could not tell
      said so rather than calling the session off screen, and so did
      `screen`: unknown was never off. A window in no multiplexer asks
      neither, so is never unknown; a live window saying not where it is is
      off, as no jump can reach it.
    - Only the sessions a live window held were listed: one no window holds
      is away, which the board says already. A finished session a window
      still holds is listed with the rest. Each session's heartbeats are
      read first, and only one with a live window is read past them and
      folded, so a run costs what the open sessions do, not the board's
      history.
    - One reading for the run, over every listed session's windows: tmux
      was asked twice for each socket and `ps` once, beside it, where any runs
      in a multiplexer, each given 2 seconds, as for a jump, however many
      sessions run under them. Nothing fails the run: what gives no answer
      makes its sessions unknown, and is named. It selects, writes and
      focuses nothing. Over a copy of Lee's board (4 November 2026: 107
      sessions, 18 held) a run took 0.2 seconds of CPU, against 0.27 while
      it folded every session, and 0.3 to 0.55 seconds' wall on a Mac at a
      load of 230; Bun's start is 0.02 of it. Those runs read `ps`'s
      `comm`. Since 9 November 2026 it reads `tdev` and `args` (see "The
      jump", step 2), a median of 122ms a `ps` against `comm`'s 104 at a
      load of 110, where `tty` in `tdev`'s place took 580; a run over one
      window in zmx took 0.15 seconds of CPU and 0.23 to 0.33 seconds' wall
      at a load of 70 to 90.
    - `--json` was `v` 1, the sessions by id, and `unanswered` naming what
      gave no answer, `tmux`, `ps`, or neither; plain `screen` said the same
      a line each (`sr-k3f9qa  Dashboard redesign: on screen`, `not on
      screen`, `not known`), then what gave no answer. Each session on
      screen named the app showing it, the first place a jump would bring
      forward, as `"Ghostty"`: in a multiplexer the app its client descended
      from, which `$TERM_PROGRAM`, `tmux` in tmux, cannot tell; `null` where
      it was not on screen (4 November 2026, for the session page's meta
      line; added to `v` 1, which a reader that ignored it read as before).

      ```
      { "v": 1,
        "sessions": [ { "id": "sr-k3f9qa", "is": "on", "app": "Ghostty" },
                      { "id": "sr-bbbbbb", "is": "unknown", "app": null } ],
        "unanswered": ["tmux"] }
      ```

    - It was a command of its own, not a field of `list` or of `watch`'s
      lines: on screen changes with Lee's tmux and terminal windows, which
      write nothing to the folder, so no change of the board would carry
      it, and `watch`, which runs for the app's whole life, would have asked
      tmux and `ps` at every look, the window shut or not, for the one
      window that showed it. `list` runs no program, and keeps so. The window asked for it on
      its own cadence, only while it showed. The reading stayed in the
      CLI's `screen.ts`, one place, which a jump read too, so zmx came in
      there behind the same states (9 November 2026), as a multiplexer
      adapter (see "The jump"), until SitRep read on screen itself (stage
      7, A2).

    `board --json` is
    `{ v, project: { key, name }, session, asks, parked, history, resolved }`:
    the session as `list` gives it, its open asks, what it parked, its latest
    8 status changes, the newest first, each its headline (`text`), its
    `detail`, `by` and `at`, and its resolved asks (20 October 2026), closed,
    the ignored aside, the newest closed first, as a session's Resolved lists
    them. `history` took the place of `log` as notes went (17 November
    2026): `log` went, and with it its lines' `kind`, `id` and `ref`, and
    a change's `text` lost its `Status: ` prefix (`now drawing Inbox`, once
    `Status: now drawing Inbox`), so `v` moved to 4; `watch`'s own `v` did
    not, as the app reads no board.
    `parked` stays what the session parked, which its view lists first;
    plain `board` prints Claude's board text, so it lists the project's (11
    November 2026; see "The board text's Parked", under "Claude's side").
    It carries the session's own history alone, never a project's, so the
    project's view losing its history (17 November 2026; see "Old
    sessions") left its shape, and `v`, as they were.
    `watch` carries it too, in this shape, for each session the app follows,
    folded as the watch folds (below). Its `v` was 3 since its session is `session` (27 October 2026),
    `work` before; 2 since its asks say what they want back (`wants`, `yes`,
    `needs`) in place of their kind. Each ask, open or resolved, carries
    `reply`, where Lee's reply to it stands (below, under `answer`), and
    `snoozedUntil`, when Lee's snooze of its session wakes while it is
    snoozed, else
    null, as for one Lee's reply is on its way to and for every ask of a
    finished session (23 October 2026; see "Snooze"); a resolved one when
    it closed, by Lee's answer or Claude's resolve, and Claude's reason
    where Claude resolved it with one, Lee's answer having closed it first
    or not. `session` carries `snoozed`, and `created` (4 November 2026; `v`
    did not move), as `list`'s sessions do:

    ```
    { "id": "k1", "wants": "yes", "yes": "Go", "title": "Give the go for stage 3",
      "where": null, "options": [], "recommended": null, "needs": null, "ref": null,
      "state": "closed", "at": 1760000000000,
      "reply": { "is": "delivered", "isAnswer": true, "words": "→ Go",
                 "since": 1760000090000 },
      "snoozedUntil": null,
      "closedAt": 1760000090000, "reason": null }
    ```

    `recommended` (13 November 2026) is the option of a choice Claude
    recommends, null where it recommends none, as on any other ask; a
    field added: `v` did not move.

    No `v` moved for 20 October 2026's changes. `reply` and `resolved` are
    fields added, which a reader that does not know them passes over. One
    meaning changed too: `waiting`, in `list --json`, `board --json` and
    `watch`, leaves out an ask Lee's reply is on its way to, an answer or a
    comment (see "A session's state"), and `watch`'s session `state`, its
    rows and its head follow it, while its session's `asks` keep such an
    ask, its `reply` saying it is on its way. `watch` and `board --json`
    list a session's asks alike, by core's `openAsks`: those open, waiting
    or replied. The SitRep window was their one reader, and a reader of the
    old meaning would only count fewer asks waiting on Lee, never trip on a
    shape.
  - `answer` (20 October 2026) answers a yes or a choice ask, or ignores
    any ask, as Lee does on the board, built for the SitRep window to answer
    through, and since 24 November 2026 the asks panel and a new ask's
    banner (see "Answering from the panel"): the ask by its id, then the
    answer in the words of the button Lee pressed, a yes ask's yes
    (`sitrep answer k1 Go`) or one of a choice ask's options (`sitrep
    answer k2 Keep it`), matched exactly, as the board shows them; or
    `--ignore` in their place, the pane's `✕ ignore`, which every ask
    offers, a words ask among them. It prints nothing.
    - Since 24 November 2026 it answers a words ask too, with the words
      given (`sitrep answer k3 Ship the Tuesday build`): a reply `{verdict:
      'answer', note}`, its words the `note`, as the pane's words answer
      is. The words keep to one line, as every answer given does. Words
      that are empty, or only spaces, are refused (`k3 wants words: give
      them after its id.`). Until then a words ask was refused, its words
      needing Claude Code's prompt.
    - It writes a reply, `yes`, `choose` with its option, `answer` with its
      words, or `ignore`, into
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
      with no moment of "sent, and Claude has it", and Resolved lists none.
      The message that delivers it tells Claude the ask is closed, and a
      resolve of it after passes quietly, writing nothing (13 November
      2026; until then Claude resolved it after, its reason over Lee's
      ignore).
    - Refused, exit 1 and nothing written: a comment and a permission
      prompt, which need Claude Code's prompt (a comment is no word it
      takes, `There is no --comment.`; a permission prompt is no ask on the
      board, and is answered in its window); a words ask given no words; a
      decide written before
      asks had options, which offers none to choose (`k5 gives no options to
      choose from: answer it in Claude Code's prompt.`); an ask closed (`k1 is
      already closed.`) or ignored (`k4 is already ignored.`); one with
      another answer of Lee's on its way already, from the pane or the CLI,
      a pane's send to its own session from its claim (22 October 2026),
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
      sitrep: run /reload-plugins in it first.`): one from before this
      release voids no second answer (see "Versions side by side"), and one
      from before today's layout read only `works/`, never seeing an answer
      written under `sessions/`. The CLI's own version is its plugin's
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
      inbox, not yet delivered, since it was written, or in a live window's
      message to its own session, since that was claimed (22 October 2026;
      see "Its replies on their way from the claim", under Delivery), Lee's
      answer before a comment where both are; else `delivered` where Claude
      has an answer the ask, edited under it, no longer takes (it waits on
      Lee again);
      else `null`, with none sent, one gone void as its ask was edited under
      it before Claude had it (the ask can be answered again), or only a
      comment Claude has. `words` is the reply as the board shows it on one
      row (`→ Go`, `ignored`, `comment: “Tighten the copy”`). Those were
      built for the SitRep window's card: "on its way" on an open ask, "sent,
      and Claude has it" on the ask the answer just closed, as the pane's
      Asks keep one for a moment, and then Resolved, where `board --json`
      lists it.
  - `finish` (20 October 2026) finishes a session no window holds, as the
    pane's `✓ finish this session` does, built for the SitRep window's `✓
    Finish this session`, which the app no longer runs: Lee's finish, `{
    "type": "finish", "who": "lee" }`, in the CLI's own file, nothing in the
    inbox. It prints nothing. Asking first is the caller's. A session a live window holds is refused (`Dashboard
    redesign is open in a window: tell Claude there to finish it.`), as is
    one already finished (`This session is already finished.`); an unknown
    one is exit 2.
  - `move` (17 November 2026) moves a session to another project on the
    board, as Claude's `move` tool does (see "A session moves to another
    project at Lee's word"): the project's name, matched as `start` matches
    one, the last argument taking every word left (`sitrep move Trey
    Research --session sr-k3f9qa`). One line in the CLI's own file; it
    prints nothing. It makes no project: a name no project has is refused
    (`There is no project named Contoso.`), as `list --project` refuses one,
    since the CLI's file system appends and never writes a file whole
    (`cli/io.ts`), and a project's file is made by writing it; Claude's
    `move` makes one. The project the session is in already is refused
    (`Help desk redesign is in Northwind already.`). A session a live window
    holds moves all the same: the window follows it. `board`, `park` and
    `move` read every project, as the session's project is whichever its
    lines name, its parked items among those of every session filed under
    it. That costs `board` time: `bun cli/shell/run.ts board --session …`
    on a copy of Lee's state (29 projects, 139 sessions), best of 12, took
    0.12 seconds with moves against 0.07 before them, timed on 17 November
    2026. Accepted: `board` is run by hand, and SitRep reads the board
    through `watch`.
  - `jump` (13 October to 10 November 2026) brought the terminal window
    showing the session to the front, on whatever Space it was (see "The
    jump"), and printed nothing. A session no jump could reach was refused
    (`Dashboard redesign is not on screen: no terminal window on this Mac
    shows it.`), as was one whose devices no terminal answered, or whose
    pane's window tmux would not select. One an app gave no answer in time
    ended with exit 3. SitRep made its own jump from 9 November 2026
    (stage 7, A3), and step B retired this one.
  - `watch`, designed 16 October 2026 and built 19 October 2026, is how the
    SitRep app hears the board: one per Mac, which the app starts as its
    child, so it stops with the app, and the app starts it again if it
    exits: no daemon. It takes no words but `--help`; on its standard input
    it hears which sessions are followed, whose boards its lines carry
    (below, **Following**): the app, since the SitRep window went (5
    November 2026), gives it `/dev/null` and follows none. It reads the
    one folder that holds every project and session (see Storage), and
    what it prints is core's: a session's
    state and its rows (`core/rows.ts`); the board as every surface shows
    it, what is new, and when the board next changes by time alone
    (`core/feed.ts`).
    - **Two-way, 27 October 2026.** The SitRep window read a session's
      detail by running `board --json`, a process for each read: as a
      session was picked, for each session of a project opened, again
      whenever the line named one shown changed, and after each of its own
      writes. Each run read and folded again a session the app's one
      `watch` held folded already. So the app told the watch what the
      window followed, and the watch printed those boards in its lines: no
      process per read, and a session's board and its row always came from
      the same look.
    - **A line per change.** A line of JSON at its start, then one only when
      the board it shows differs from the last line's, its own time aside,
      or it carries a board (below, `boards`), each written whole and at
      once. A finished session is in no row and no project, though a
      window still live on it is among the windows; an away session is in
      both, its asks still counting. It carries no
      project without a current session, nor does `list --json`, but one
      with something parked (11 November 2026). A state
      folder not there yet, as
      before any Claude window has written, is an empty board, and what
      comes into it shows.

      ```
      { "v": 3, "at": 1760000060000, "version": "0.2.0",
        "head": { "needYou": 2, "sessions": 1 },
        "rows": [
          { "session": "sr-k3f9qa", "section": "needsYou",
            "isAway": false, "project": "switchboard",
            "name": "Dashboard redesign", "projectName": "Switchboard",
            "letters": "Sw",
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
        "snoozed": [],
        "projects": [
          { "key": "switchboard", "name": "Switchboard",
            "directory": "/Users/lee/Code/switchboard", "open": 1,
            "waiting": 1, "snoozed": 0, "parked": 0,
            "updatedAt": 1760000000000,
            "sessions": [
              { "id": "sr-k3f9qa", "name": "Dashboard redesign",
                "summary": "...", "now": ["..."], "next": null,
                "isOpen": true, "waiting": 1, "snoozed": 0, "parked": 0,
                "updatedAt": 1760000000000, "state": "needsYou",
                "since": 1760000000000,
                "doing": { "is": "working",
                           "line": { "lead": "Reading", "mono": "...",
                                     "subject": null, "more": null,
                                     "until": null },
                           "since": 1760000000000 },
                "asks": [ ... ], "parkedItems": [],
                "lastWindow": null } ] } ],
        "windows": [
          { "writer": "b1c2d3e4-...", "session": "sr-k3f9qa",
            "name": "Dashboard redesign", "project": "Switchboard",
            "version": "0.2.0", "needsReload": false,
            "where": { "device": "/dev/ttys001", "terminal": "ghostty",
                       "tmux": null, "zmx": null },
            "state": { "is": "working", "since": 1760000000000,
                       "tool": { "name": "Read", "subject": "..." },
                       "question": null },
            "attachedAt": 1760000000000, "jumpOrder": 0 } ],
        "new": [],
        "boards": {
          "sr-k3f9qa": { "v": 4,
                         "project": { "key": "switchboard", "name": "Switchboard" },
                         "session": { "id": "sr-k3f9qa", ... },
                         "asks": [ ... ], "parked": [], "history": [ ... ],
                         "resolved": [] },
          "sr-zzzzzz": null } }
      ```

    - `rows` are the panel's, the strip's and the menu's, in their order
      (see "The rows"), a row a session (`v` 2, 22 October 2026). A row is
      its `session`, which names it for as long as it stands, so the app
      keeps a row's place by it; its `section` (`needsYou`, `yourTurn` or
      `working`; on its own work is in `working`, at its end), and
      `isAway`, a Needs you row of a session no window holds; its project's
      key, its session's `name` and its project's (`projectName`), the
      strip's two `letters` (the project's capitals where it has two, else
      its first two), its `lines`, its `second` line, and `since`, the
      instant its time counts from: its newest line's on Needs you, else its
      one line's. Needs you's newest first, and Your turn above Working,
      changed only the order and that instant (4 November 2026): `v` did not
      move, as no reader trips on them. `second` is the project and the
      session, or, for an away
      row, "No window holds it. Carry it on in Claude.", which the app shows
      as it comes, under a Working or Your turn row's line and an away row's
      name. A Needs you row a window holds shows its `name` over its
      `projectName` (board F). `name` and `projectName` came in with board F
      (22 October 2026): a field added, `v` did not move.
    - A row's `lines`, never empty, are what it says: on Needs you one per
      ask waiting on Lee, not snoozed, permission prompt and question, the
      newest first (the oldest first until 4 November 2026); on any other
      row one, its state's. A line's `key` names
      it for as long as it stands (`ask:<session>:<ask>`,
      `stop:<session>:<window>:<since>`, `turn:<session>`). `is` is what the
      line is (`ask`, `permission`, `question`, `working`, `onItsWork` or
      `yourTurn`); then its `ask` or its window (`writer`), its words
      (`first`), and its `since`, which the app ticks: an ask's posting or
      reopening, a stop's showing, the turn's end or, working, its start.
      `first` is in parts: `lead`, which a working row shimmers; `mono`, the
      subject set in mono; `subject`, one set plain, as on its own work's "3
      agents"; `more`, a question's `+2`; `until`, when the wake a row on its
      own work waits on is due, which the app words as its countdown after
      the lead. `subject` and `until` came in with on its own work (22
      October 2026), null on every other line.
    - `head`: how many lines need Lee, away ones among them, and how many
      sessions the rows hold; none needing Lee is "All clear".
    - `snoozed` (23 October 2026): the Snoozed rows, a session each, apart
      from `rows` and never among them, the soonest to wake first; each
      line an ask snoozed or, since 4 November 2026, its turn, under the key
      it has in Needs you, with when it wakes (`wakesAt`), and the row's
      `wakesAt` its soonest line's (see "Snooze", whose example shows a
      row). Since 13 November 2026 a session's asks and its turn are one
      row, where until then each had its own. Each session and project counts
      its asks snoozed as `snoozed`, which `waiting` leaves out, and each ask
      carries `snoozedUntil`, as in `board --json`. Fields added: `v` did not
      move.
    - `projects`: those with a current session, or with something parked,
      which the app does not read (5 November 2026), each counting what is
      parked in it as `list --json` does (11 November 2026), in the order
      the SitRep window listed them: a session where its row sits, those
      with none after, the latest updated first; a project where its first
      session sits. Each session is as `list
      --json` gives it, with its `state` (`needsYou`, `working`, `onItsWork`,
      `yourTurn` or `away`), `since`, when its state began, its row's oldest
      line's (its row's own `since` its newest's, since 4 November 2026),
      else its latest line's, `doing`, and its open asks, as `board --json`
      lists them (core's
      `openAsks`): waiting, on Lee or on a window to deliver Lee's reply, or
      replied, Claude's to act on, each with its `reply`, which tells them
      apart. So a reply going into a session's inbox is a line, its board
      among `boards` where it is followed, and its mark is another.
      `doing` (20 October 2026) is
      what the session is doing, as the SitRep window's line under its name
      said it, there for every session (core's `doingOf`): a window's
      permission prompt or question, the one shown first; else the window its
      turn row comes from; each as that row's `is`, its `first` as `line`, and
      its `since`. With no window holding it, `away`, "No window holds it.
      Carry it on in Claude.", since its latest line. So a session needing Lee
      for its asks alone, which has no row of its windows', still says what
      they do. A field added: `v` did not move.
      `parkedItems` (4 November 2026) is what the session parked, oldest
      first, in posting order, as `board --json`'s `parked`, each item as it
      lists one (`id`, `title`, `where`, `ref`, `at`): on every session,
      followed or not, where before only a followed session's board held
      them. It was what the SitRep window's Parked list read, every item on
      the board. An item picked up, closed or dropped leaves it. A field
      added: `v` did not move. It stays the session's own (11 November
      2026): a finished session's, in no project's `sessions`, are on no
      line, and no surface of the app shows parked items.
      `lastWindow` (12 November 2026, stage 8) is, for an away session, the
      window it was last in: its latest heartbeat by when it was last seen,
      as it let go, else at its latest beat (core's `lastWindowOf`, ranking
      by `lastSeenAt` as `rejoinable` does), so a `/clear` moves it on to
      the conversation after. It carries what a click needs to carry the
      session on, and no more: the `writer`, the Claude Code session it ran,
      the resume command's `{claude}`; its `where`, as its heartbeat said
      it, the pty its Claude ran on among it; `ownsDevice`, whether that pty
      is still its conversation's, so a Claude running or suspended on it is
      that one, which fills `{tty}` and the default command's guard; and
      its `directory`, the folder its Claude ran in, `{dir}`, null from a
      window on a build from before heartbeats said it. Null for a session
      a live window holds, for one no window ever held, and for one whose
      last window's conversation would take up another session as it
      resumed: its writer's latest heartbeat, across the whole board, is on
      another session (core's `rejoinable`, which a resumed conversation
      takes up by), as a window that let go of it for another's is, live
      there or ended. A device is the latest conversation's seen on it:
      `ownsDevice` is false where the window let go with `livesOn`, its
      Claude gone on into another conversation, or a heartbeat on the
      board, of any session, live or let go, was seen on that device later
      (`lastSeenAt`). `where` is given whole either way, as a Claude
      suspended there is looked for on its pty, whoever came after, and its
      multiplexer session tells whether this Mac shows it (stage 8). Until
      stage 8's rethink (13 November 2026; the next PR removes it) it also
      carried `attaches`, whether a click might jump to or attach the place
      it was in, true only in a zmx session no later conversation was seen
      in (core's `isThere`): the rethink carries a session on from its
      Claude, never from the place. Time the Mac slept ages no heartbeat
      (core's `pauses.ts`), so a wake reads no live session as away. A
      field of the session, as SitRep reads a session's windows already by
      the session, not a list of its own: away windows are no live
      windows, and `windows` stays every live one. A field added: `v` did
      not move. SitRep reads it as it reads the projects' names, in any
      shape: one that does not read is none. With the rethink each live
      window carries its `directory` too (below), so a held session's
      click has its `{dir}`.
    - `windows`: every live window, the longest attached first, a finished
      session's among them, with its session's name and project, its
      `version`, and `needsReload` where it says none, or one behind the
      CLI's own `version`, dotted part by part. Not `seenAt`: every beat
      would be a line. Nor `loadedAt`, which only the mod's fence reads.
      `jumpOrder` (9 November 2026) is the window's place in the order a
      jump tries its session's windows, 0 first (core's `windowsOf`, see
      "The jump"), counted among that session's windows alone; none on a
      window saying no `where`, which no jump tries, so the windows of a
      session with a `jumpOrder`, taken by it, are the jump's places to
      try, each `where` in turn. A field of each window, not a reordering
      of the list, which Settings reads as the longest attached first. A
      field added: `v` did not move. `directory` (stage 8's rethink, 13
      November 2026, built in the PR after it) is the folder the window's
      Claude runs in, as its heartbeat says it, null where it says none: a
      held session's `{dir}` for the resume command. A field added: `v`
      does not move.
    - `new`: the keys of the lines needing Lee this watch has not shown, a
      new ask by its id or a window's new stop by when it showed. A row
      holding one **arrives**: a session new to the board, one coming to
      need Lee from working or your turn, or one in Needs you gaining a
      line. Since rows went by session a row keeps its key through all
      three, so an arrival is this, not a key new to the app, as it was
      while each ask and stop was a row of its own (22 October 2026). An
      arrival swells the notch, washes its row on the card, and on the strip
      moves its mark into Needs you at once, flashing, or flashes it where it is
      already in Needs you. A row **changes section** when its session
      comes into Needs you or leaves it: on the card, while it is out, it
      leaves its held place for its place in its new section (see "The
      rows"). The first line has none, so the app does not swell at its
      start, and what it shows counts as shown. A line gone and back, as a window's heartbeat late or an ask's folder away
      for a look, is not new again until it has been gone more than a day
      of the watch's own time (core's `FORGET_MS`), counted from its going;
      by then it is let go. So a finished session joined again brings back
      as new only the asks this watch has not shown. A line in `snoozed` is
      kept among those shown, asleep, however long it sleeps, and its
      absence from Needs you never makes it new: back there, it is new only
      once its snooze's time has woken it, as its line in core says
      (`woke`, never printed), and woken by Lee it comes back as shown (see
      "Snooze"). One that leaves Snoozed for nowhere, as when Lee replies to
      it, is a line gone as any is, so taken back after its time it is not
      new.
    - **Following.** Each line `watch` reads on its standard input is JSON,
      `{"follow": ["sr-k3f9qa", ...]}`: the whole set of sessions followed
      now, in place of the set last given. The SitRep window gave it the
      sessions it showed; since it went (5 November 2026) the app writes
      nothing there, its standard input `/dev/null`, so the watch follows
      none and looks on its own cadence. Every such line,
      its set changed or not, wakes the watch for a look at once, cutting its
      wait short, or, heard while a look is under way, making the next come
      at once: so the app has it look straight after a write of its own.
      Several heard at once wake one look, the last one's set standing. A
      line is whole at its newline; one that does not read (not JSON, no
      `follow`, or a `follow` that is not a list of text) is passed over,
      changing and waking nothing. Standard input ending changes nothing:
      the set last given stands, a piece with no newline after it passed
      over, and the watch ends only as under **Ending**. Run by hand, its
      standard input a terminal or `/dev/null`, it follows nothing, and
      prints as it did before it heard any (`cli/follow.ts`).
    - `boards`: by session id, the board of each session followed that is
      new to the set or whose board changed since the watch last printed
      it, in `board --json`'s shape, parsed, not as text; null where the
      watch finds no such session, as one no project files or one whose
      `session.json` does not fold. Where two projects file one id, it is
      the first's, as `board --json` finds it. It is folded as the line's
      own `projects` and rows are, in the same look, heartbeats aged without
      the time the Mac slept (**Pauses**, below), so it always agrees with
      them; `board --json` folds with no pauses, so run just after a sleep
      longer than a heartbeat's 90 seconds it can say a session's window
      gone (`isOpen` false) where the carried board, and the line, say it
      live until the window beats again. A null is printed once, as the
      change it is, like any other. A session dropped from the set is let
      go of, so followed again it is new, though dropped and followed again
      before a look. The boards of the sessions followed come on the line
      the look after their follow line prints. For a follow line written
      before the watch started, the first line need not carry them, as
      nothing orders the first look against the watch hearing its standard
      input, so the app never counts on it (live, 27 October 2026: a
      follow line written into a fifo before the watch started was carried
      on the second line, 6 to 45 ms after the first). With none to carry,
      `boards` is `{}`. A session's board changing prints a line where the
      session is followed; one nobody follows prints nothing unless the
      board every surface shows changed too. It took the
      place of `changed` (27 October 2026), the ids of the sessions whose
      `board --json` had changed since the last line, which the window ran
      `board --json` again for.
    - It is stable as `list --json` is: every field is always there (a list
      empty, any other value null where there is none), and `v` moves only
      with a change a reader would trip on. A new value in a field that
      names one of a set (a row's `is`, a session's `state` and its
      `doing`'s `is`, an ask's `wants`, a window's state's `is`, and the
      like) is such a change: the app reads them strictly and refuses a
      line holding a value it does not know. New words in a line, as an
      away ask's `second`, are not. Since the SitRep window went (5
      November 2026) the app reads only `head`, the
      rows, `snoozed`, the windows and `new`, so a change to `projects` or
      `boards` leaves it reading the board.
      On its own work breaks this once, by plan (22 October 2026):
      `onItsWork` came into the rows', the sessions', the doings' and the
      windows' kinds without `v` moving, the app taking it in the same
      change, so an app built before it refuses a line holding it until it
      is built again. The rows grouped by session moved `v` to 2 (22
      October 2026): a row became a session holding its lines, keyed by the
      session, with its section; what was a row's (its key, `is`, `ask`,
      `writer`, `first` and its own `since`) became a line's; and `head`'s
      `needYou` counts lines. The app read 2 alone, so one built before
      it said it couldn't read the board until it was built again. `boards`
      in place of `changed` moved `v` to 3 (27 October 2026), the app
      reading 3 alone from then. A turn snoozed breaks it once more, by
      plan (4 November 2026, see "A turn snoozes too"): `snoozed`'s lines
      gained `is`, and a turn's holds `ask` and `wakesAt` null, `v` staying
      3, the app taking it in the same change, so an app built before it
      refuses a line holding a turn asleep until it is built again.
    - **The loop.** It looks every second, as the mod's readers do, and at
      once on a line on its standard input: a file is read again only once
      its size or time moved, a folder listed again only once its time
      moved, as an entry made, removed or renamed there moves it, and a
      session folded again only once its files changed (`cli/held.ts`). A
      session's board is made as it is folded, so carrying one costs no
      fold of its own. A session off the board, finished or idle past the
      views, is read every 10 seconds: it changes rarely, and only a join or
      a post brings it back. A finished one a live window still holds is
      read at every look, so the window's state is heard at once, and so is
      one followed, off the board or not, so its board is never a look
      behind. The shell lists, stats and reads at once, not through a
      promise's round trip to a thread, at about a tenth of the cost
      (measured on Bun 1.4). At rest
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
      stale, a snooze running out (23 October 2026), or an
      idle session dropping out of the views. It looks again at that
      instant, folding every session afresh. A snooze runs out on the wall
      clock, which no pause holds back.
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
      listing no longer shows is let go, and all under it.
    - **The move**, of the old layout, ran as it started and every 10
      minutes after, until it went on 27 October 2026 (see "Two layouts,
      side by side", under "Storage").
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
      and to its standard input, and lets go of the wait under way, any of
      which would otherwise hold the process open: Bun lets a run end with
      its standard input's pipe still open once nothing listens and it is
      paused (probed on Bun 1.4.3).
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

- Palette (Tokyo Night): sessions `#7aa2f7`,
  parked `#bb9af7`, ok `#9ece6a`, now `#73daca`, soft `#a9b1d6`,
  grey `#7a82ab`, faint `#565f89`, rules `#3b4261`, tab `#292e42`; and,
  of its own, recommended `#7178c7`, a darker lilac than a primary button's.
  Claude Code's own orange, the notch card's: ask `#d77757`, and the
  new-ask pulse `#ff9c7b`, that orange at the OKLCH lightness the old
  pulse had, 0.79 where the ask's is 0.67, so the pulse still flashes
  brighter.
- **White:** anything clickable, and the main content.
- **Soft:** lines describing the item above them (a summary, what a session is
  doing, a reply, a status change's detail), and the line a section with nothing in it
  shows (`Nothing waiting on you.`).
- **Grey:** ages, counts, heading notes. The toggles at a list's foot (Status's history,
  Parked's picked up, a project's old sessions, RESOLVED's `show all`), the
  way back and a session's project are a quieter press, drawn dim (a
  Button's own `dimColor`: Claude Code 2.1.294 refuses a Button with a
  label and a coloured child, and blanks the pane; 2.1.326 takes one, as
  the recommended option's button shows). **Faint:** closed things (an away
  session, an old session's last status, an ask Lee's send just closed, a
  status change's `●`), but not
  RESOLVED's asks nor Parked's picked up: each is a row to open, its `●`
  green and its title white; and every tree's `│ ├ └`.
  Section headings' rules and the tabs' rule are the rule colour.
- **Colour:** glyphs, headings and orange waiting counts only; in the ask's
  orange, the `needs:` line of a words ask, since it is a request of Lee's,
  not a description; a tree line's label (`Added:`, `see`), in its
  item's colour; and the word ending the recommended option's button, in
  a darker lilac than the primary's own (`#7178c7`), quieter than the
  option and never grey.
- Glyphs: `●` ask in orange, `●` parked in purple, `●` under way in green, `●` next in grey, `●` resolved and picked up in green, `✓` done on buttons, `└ ├` trees, `⌂` home.
  No glyph that reads as "expand" unless it expands. A new ask's `●`
  pulses `● ◉ ● ◉`, each `◉` in the brighter orange. A snoozed ask's `●`
  is grey, and a finished session's faint.
- **The pane's marks are the notch's** (Lee, 19 November 2026). The notch
  card marks an ask with an orange circle, its colour saying what is
  needed, so the pane does too: an ask's `●` in Claude Code's orange, a
  parked item's in the pane's purple. The parked circle is filled, never
  hollow, and so is every frame of the pulse: on the notch a hollow
  circle means away, and one shape carries one meaning. Until then an ask was a `◆` in Tokyo Night's amber
  (`#e0af68`), pulsing `◆ ◈ ◇ ◈` in its orange (`#ff9e64`), and a parked
  item a purple `◇`. Claude's `asked:` and `parked:` rows in the chat
  open with the same marks in their colours, the words dim, so neither
  reads as Claude Code's own `●` before a tool call. All projects still
  marks no session's state.
- **One row for every list.** A status change, a parked item, one picked
  up or closed, an ask in Asks and a resolved ask are drawn alike: the mark, the title (white, and the
  press that opens it) on one line, clipped, and the age on the right, in
  grey. Opened, the title shows in full, a `│` beside its further lines, and
  the detail hangs from the mark as a tree; an opened ask's buttons and hint
  come after its tree, at its title's column. A wrapped title is a press per
  line (a Button's label never wraps), all of them one hover group, a
  `hover` scope made from its press key, so the whole title lights
  whichever line the pointer is on.
- Breathing room: a column each side, a blank row under the tab rule
  where there is no way back, after an opened ask's buttons, between
  projects in All projects, between a project's sessions and before the
  old sessions at their foot, and between sections; none between the
  entries of a list (asks, history, parked, picked up, old sessions, resolved), nor between the tabs and
  their rule.
- No indents left floating: anything hanging off an item hangs from a `└`.

## Where it lives

Its own repository, `leeovery/sitrep`: private until sitrep was stable,
then public, from 18 November 2026, which was half the point of its own
repository. It began in kit, Lee's Mac
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
How the app updates changed on 16 October 2026 (Sparkle, below), and on 27
October 2026 went back to `brew upgrade` while the repository was private.
On 18 November 2026, with the repository public, Lee settled on Homebrew
alone: there is no Sparkle.

- **On a Mac, sitrep is the app**, from a Homebrew cask in `homebrew-tools`,
  and from nowhere else (no download of its own), so every install updates
  the same way. That way was `brew upgrade` until 16 October 2026, when the
  app was to update itself; it is `brew upgrade` again since 27 October
  2026, and stays so. The app the cask downloads is quarantined,
  so a release is signed with Lee's Developer ID and notarized (stage 4).
  The cask exists since 27 October 2026, `Casks/sitrep.rb` in
  `leeovery/homebrew-tools`: `brew install --cask leeovery/tools/sitrep`.
  It downloads `SitRep-<version>.zip` from the release's public URL,
  `https://github.com/leeovery/sitrep/releases/download/v<version>/SitRep-<version>.zip`,
  with Homebrew's own download, no token and no strategy of its own. Its
  `livecheck` reads GitHub's latest release. It leaves `auto_updates`
  unset, so `brew upgrade` updates the app. Its uninstall quits the app and its notices helper. Its zap takes SitRep's
  preferences, caches, saved state and its copy of the plugin; never the
  board's folder, nor `~/Library/Logs/press`, where a release logs on a
  Mac that releases (`~/Library/Logs/SitRep` until 22 November 2026). A zap leaves Claude Code with the plugin registered
  from the folder it removed, so the README says to uninstall it there.
  The tap's `update-formula` workflow writes each release's version and
  sha256 into it, sent by `press upload` (`app/release-upload` until 22
  November 2026); until 18 November 2026 it
  wrote the asset's id too (see "Public, with no token", under stage 4).
  They were placeholders until the first release, 0.3.0 on 28 October 2026.
- **`brew upgrade` reopens SitRep; an install or a reinstall does not**
  (6 November 2026, leeovery/homebrew-tools#6). The cask has no
  `postflight` now: Homebrew 7 deprecates it, and its own reopen, from the
  cask's `uninstall quit:`, starts SitRep again after an upgrade that
  quit it, so the new app's start refreshes its copy of the plugin
  straight away (see "After an update"), and the two never part. A first
  install and `brew reinstall --cask sitrep` leave SitRep stopped: open
  it, or run `app/open`, after. Proven live on 9 November 2026, 0.3.0 to
  0.4.0: brew quit SitRep, swapped the bundle, and printed "Reopening 1
  application closed during upgrade", and SitRep came back on its own,
  with no warning. From 28 October 2026 the cask's
  `postflight` opened `/Applications/SitRep.app` after every install and
  upgrade, tried three times a second apart, since an `open` straight
  after a bundle is moved in once failed with LaunchServices error -600
  (seen with `app/build`, 14 October 2026); Lee asked for it then, since
  he restarts his Mac rarely and the app and the plugin must never drift.
  Leaving SitRep running through an upgrade, to notice its newer self on
  disk, was weighed and ruled out: brew would remove the bundle from under
  a running app and its notices helper.
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
  Built 20 October 2026 (stage 3, step 9). Since 2 November 2026 the first
  welcome window offers the three, and registers SitRep at login unless
  Lee turns the switch off (see "The welcome window").
- **Anything of sitrep SitRep did not install is left exactly as it is.**
  SitRep reads `claude plugin marketplace list --json` and `claude plugin
  list --json` as it starts, and decides from both. It adds and installs
  only when neither shows anything of sitrep: no `sitrep` marketplace, and
  no installed plugin named `sitrep` from any marketplace. It refreshes
  only its own copy, the `sitrep` marketplace being a folder marketplace of
  that very folder. A `sitrep` marketplace anywhere else (a checkout of Lee's,
  as `app/plugin here` makes it, the GitHub one), or any installed `sitrep`
  not from its own copy (`sitrep@kit`, since sitrep began in kit's
  marketplace), is foreign: it is never removed, replaced or re-pointed, no
  second sitrep is installed beside it, which would leave each window running
  two mods, and SitRep runs that plugin's CLI from where Claude loads it:
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
  gone, the list says `[]` while the plugin still loads from a checkout.
  Under `app/plugin here` (below) the app changes nothing and runs the
  checkout's CLI; before the first release it ran the clone's this way.
- **Trouble does not leave SitRep without a board.** SitRep remembers the
  plugin folder of the last look that went well. A look that meets trouble
  (no `claude`, a list that fails, times out or does not read, a step that
  fails) runs that folder's CLI while the folder is there, else its own
  copy's, and says the trouble in the card and the menu. It looks again a
  second later, the wait doubling to half a minute, as `watch`'s back-off
  does, until a look goes well; `watch` starts again only when the folder
  it settles on is another.
- **Homebrew updates the app; there is no Sparkle** (Lee, 18 November
  2026). `brew upgrade` replaces the app and Homebrew reopens it, and the
  app's start moves the plugin with it (below), so a second updater would
  only update the same app another way. Sparkle was ruled out on 14
  October, since `brew upgrade` already updates a cask. It was taken back on
  16 October, because `brew upgrade` reaches only those who run it, where an
  app that updates itself reaches everyone. It then waited while the
  repository was private (27 October 2026), as the feed, and the zips it
  names, would have needed GitHub's authentication. Once the repository was
  public, the menu's Check for Updates…, and General's Update automatically
  and Check Now, were dropped with it.
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
- **This Mac runs the cask's SitRep** since the first release (28 October
  2026), and builds over it (below).
- **Everyone else** (Linux, Windows, no menu bar wanted) was to install the
  plugin alone from the GitHub marketplace: `claude plugin marketplace add
  leeovery/sitrep`, then `claude plugin install sitrep@sitrep`. Since 27
  October 2026 the plugin and the app come as one, and there is no
  everyone else: the app carries some of what the board does, such as the
  sound for a new ask (see "Settings"). Lee: "This isn't a supported thing
  anymore. Although it's possible, they come as one."
- **Ruled out:** the plugin first, its mod building the app whenever the
  plugin's version moved on (a Claude mod compiling a Mac app, and Xcode's
  tools wanted on every Mac); the Mac App Store, whose sandbox forbids
  running another program (even tmux's queries), controlling Ghostty, and
  writing Claude's settings. Sparkle was ruled out here too, taken back on
  16 October 2026, and dropped on 18 November 2026 (above).

**On this Mac**, since the first release (28 October 2026), as on any
other: SitRep from the cask, at `/Applications/SitRep.app`, and the plugin
from SitRep's own copy, so a merge to `main` reaches no window until a
release. Until then this Mac read the plugin from the clone,
`~/Code/sitrep`, as a folder marketplace, so an edit plus `/reload-plugins`
was a change and the clone's checkout the code every window ran, and
`app/build` (stage 3) installed the app to `~/Applications/SitRep.app`.
Work happens in a worktree, the clone kept on `main`.
- **`app/plugin` switches where the plugin comes from**, for a live test.
  `app/plugin here` points the `sitrep` marketplace at the checkout it is
  in, a worktree or the clone, by `claude plugin marketplace add` over the
  registration, then `claude plugin marketplace update sitrep` and `claude
  plugin update sitrep@sitrep` (an install where it is not installed), so
  Claude's record follows. `app/plugin app` points it back at SitRep's copy,
  and `app/plugin` alone says which it is: or that the marketplace's folder
  is gone, that `sitrep@sitrep` is not installed or is disabled, or that a
  `sitrep` from another marketplace is. Each window takes a switch up at
  its next `/reload-plugins`. SitRep looks at the plugin only as it starts,
  its looks ending at the first that runs, so either form ends with SitRep
  running, as the cask's install left it until 6 November 2026: started
  where it is not running, and quit (`app/quit`, as `app/build` does) and started again
  where the switch changed anything. On a checkout, SitRep finds a
  marketplace not its own and runs the checkout's CLI, on Bun; back on its
  copy, its start refreshes the copy, which an update or `app/build` left
  at its old build while a checkout was the plugin. A switch to where the
  plugin already comes from, installed at the folder's version, leaves
  Claude Code as it is, and only starts a SitRep that is not running, so a
  run after an open that failed, or a quit that gave up, is retried by
  running it again. Nothing is switched or quit before `app/open --check`
  finds `/Applications/SitRep.app` there to start. It keeps SitRep's rule:
  with a `sitrep` installed from another marketplace (`sitrep@kit`) it
  refuses, naming it, rather than put a second beside it.
  - With SitRep's copy gone (a zap, or a removal by hand) while a checkout
    is the plugin, SitRep cannot make it again, since it leaves a
    marketplace not its own as it is. So `app/plugin app` then uninstalls
    `sitrep@sitrep` and removes the `sitrep` marketplace, saying so, and
    starts SitRep, whose start, with nothing of sitrep in either list,
    copies, adds and installs its plugin as at its first start.
  - A worktree removed while it is the plugin leaves the marketplace naming
    a folder that is gone: windows load no sitrep at their next
    `/reload-plugins`, and SitRep meets trouble and never re-points it. So
    `app/plugin app` comes before a live worktree's removal.
  - `app/quit` stops only Lee's own SitRep and notices helper, and gives up,
    saying so, on one still running: SitRep five seconds after its signal,
    the helper after two seconds' grace to quit as SitRep ends and five
    after its own, about seven in all.
    `app/open` starts `/Applications/SitRep.app` for both scripts, three
    tries a second apart, as the cask's `postflight` did.
  - Tested against the real `claude`, its config (`CLAUDE_CONFIG_DIR`) and
    the home in a scratch folder, with `pgrep`, `pkill` and `open` stood in
    for.
- **`app/build` installs over the cask's copy**, at
  `/Applications/SitRep.app`. The login item and macOS's permissions
  remember the app by where it is, so a build there keeps both, and there
  is never a second bundle with the id `com.leeovery.sitrep`. It changes
  the plugin too: while SitRep's copy is the marketplace, the build's start
  refreshes the copy from what the build carries, so every window runs the
  building checkout's mod from its next `/reload-plugins`. `brew reinstall
  --cask sitrep` puts the release back, and the next release's `brew
  upgrade` replaces the build.
- kit's `[manual]` step installs the plugin from the GitHub marketplace on
  any other Mac until kit declares the cask.

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
- The build's renames on disk (`works/`, `work.json`) were the first use:
  readers read the old names and the new, writers wrote only the new, and
  the old files moved once no window ran an old version. A window not yet
  reloaded read only the old names, so it saw nothing written under the new
  ones until it reloaded, as with newer lines. Built 19 October 2026,
  `works/` to `sessions/` and `work.json` to `session.json`; the old names'
  reads and the move went on 27 October 2026, with nothing of the old layout
  left on any Mac (see "Storage").
- A window on a release from before 20 October 2026 voids no second answer:
  two answers to one ask that land at once (two runs of `sitrep answer`, or
  the CLI and a pane's letter) both go in from it, until it reloads, and the
  board records both delivered, as Claude had them. One from before today's
  layout (no `version` in its heartbeat) read only `works/`, so it would
  never have seen the CLI's answers, written under `sessions/`. So `sitrep
  answer` refuses while the window delivering the session runs a sitrep
  behind the CLI's, by `needsReload` (see "One engine, two front ends"),
  saying to `/reload-plugins` it; the version moves at each release, this
  one among them, 0.1.0 to 0.2.0. Known limits, all of a window not yet
  reloaded: one that only takes a session up later, after the answer was
  written, is not refused; a session's second answer still reaches Claude
  from a window before this release that delivers it; and one before this
  release, as a sender, letters a second answer into a session whose window
  runs this release, which rightly voids it, `answered`, while the old
  window's own Ready to send, reading by the old rules, keeps showing it on
  its way until that window reloads.
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
October 2026). The copy the app carries has it compiled (`bun build
--compile`), so a Mac with the app needs no Bun; a checkout of the plugin, as
`app/plugin here` makes one live, runs it on Bun. Bun reads a file by its
extension, so what it compiles is `cli/shell/run.ts`, which `bin/sitrep`
imports; compiled, the CLI finds its manifest from its binary's folder, since
its own source's folder is then one inside the binary.

The engine's types sit in `.claude-plugin/types/`, kept out of git by their
own `.gitignore`; `.worktreeinclude` copies them into a worktree. The mod's
type-check leaves `cli/shell` out; it is checked on its own
(`tsc -p cli/shell`), against what it calls of Bun, declared there, since the
plugin keeps no packages.

## The menu bar

Decided with Lee on 13 October 2026, on the board as `sr-m4e8nb`, its surface
redrawn as the notch and its panel on 14 and 15 October 2026. One place on the
Mac, on every Space, for what waits on Lee across every project, and a click
that takes Lee to the window a session is in.

- **A native Mac app**, with no Dock icon. Its surface is **the notch**: a
  black shape at the edge of the screen that opens into a panel of Lee's
  sessions, or **the strip** in its place (below). It replaces the menu
  bar's list, first planned as projects opening to their sessions.
- **The menu bar item stays**, as a native menu: the panel's sessions with a
  click to each, what shows at the screen's edge, Settings and quitting
  (17 October 2026; see "The menu bar item").
- **macOS notifications for a new ask**, silent, since SitRep plays its own
  sound for a new ask and Lee hears it once (the window's chime until 27
  October 2026; see "Settings"). A banner's sound would follow the alert
  volume, 0 on Lee's Mac, where SitRep's plays at the output volume. They
  are off by default once
  the notch exists, since the notch swells and lights for a new ask, and a
  setting turns them on. Asks landing on one board post the oldest first,
  so Notification Center, which stacks the last posted on top, shows the
  newest there, as Needs you does (4 November 2026; core's order until
  then, which with Needs you newest first would have stacked the oldest on
  top).
  - **SitRep's notices helper posts them, never SitRep** (26 October
    2026), so a click on one never activates SitRep. macOS activates the
    app that posted a notification as Lee clicks its body, and with
    "switch to a Space with open windows" on, which the jump needs (see
    "The jump"), it goes first to a Space with one of that app's windows.
    Lee had a SitRep window open on Space 13, and on Space 11 clicked
    the notification for an ask from a session on Space 12: macOS took
    him to 13, then the jump to 12 (24–26 October 2026). SitRep cannot
    stop the activation. The helper is a windowless app inside
    SitRep.app, so macOS has no Space to take Lee to; it hands the click
    to SitRep, which jumps as from any other click. Lee chose it from
    three routes.
  - **The helper** is `SitRep.app/Contents/Helpers/SitRepNotices.app`,
    its bundle id SitRep's and `.notices`, an `LSUIElement` app with
    SitRep's icon and the name SitRep, so a banner's header still says
    SitRep, and System Settings › Notifications lists it as an app of
    its own named SitRep, asking Lee's leave once. It holds nothing of
    SitRep's: macOS's notifications and the relay alone. Every use of
    them is its: asking leave, posting (the test notification among
    them), and reading the leave and alert style for Settings. SitRep
    keeps the decisions, what to post and when (`Notices`).
  - **The relay** is a distributed notification each way, named under
    the helper's bundle id, its payload a plist of strings, local to the
    Mac. SitRep to the helper: ready, post, a request for the leave, or
    to ask for it first, each with an id its answer gives back, and hand
    back the front. The helper to SitRep: ready, with its own pid,
    clicked (the session's id), answered (24 November 2026; see "Its
    buttons", below), and the leave. Each carries SitRep's pid,
    whichever way it goes, and each side reads only its own SitRep's, so
    a helper left over from another SitRep is not heard, nor heeds one.
    Each side says ready as it starts listening. The helper answers each
    of SitRep's readies with its own; SitRep answers only the first of
    each helper, by its pid, so the two stop, and a helper macOS starts
    for a click whose ready comes before the last one's end is heard,
    and that end, told late, changes nothing of it. SitRep takes a ready
    only from a helper still running, as a ready and an end come by
    different ways, in no order. SitRep holds what it says until a
    helper is ready; while a helper it watches runs without having said
    so, its ready perhaps lost, SitRep says its own again for each thing
    held. A read of the leave the helper does not answer within 2
    seconds is unknown, and dropped, so it is never sent later;
    Settings' row then says no more than "Notifications in macOS", and
    Settings reads its other rows meanwhile. A helper that ends leaves
    what it was sent unanswered, as unknown; what was not yet sent, an
    ask among it, waits for the next.
  - **Its life.** SitRep starts the helper as it starts
    (`NSWorkspace.openApplication`, not activated, not added to recent
    items, the one running where it runs), and watches whichever helper
    says it is ready, SitRep's own or one macOS started for a click, for
    its ending, once the end of any watched before it is told. The
    helper runs beside SitRep only until it ends: SitRep starts it again
    only as it next has something to say, so a helper that ends as it
    starts, before its ready, is not started over and over, and a click
    on a banner starts one of macOS's own. The one exception: a helper
    left running from the SitRep before, as when SitRep restarts at once
    and is handed it, ends without a word for this one, and is followed
    by one of this SitRep's own, once, where something waits.
    `app/build` waits for the helper to quit after SitRep, stopping it
    after two seconds, so the new SitRep is not handed the old one.
    The helper serves the SitRep.app
    it sits in, the copy running from that bundle, and quits as that
    SitRep ends, watching its `NSRunningApplication`. A click that
    starts the helper while SitRep is not running starts SitRep, not
    activated, and is held until SitRep says it is ready.
  - **Its buttons** (24 November 2026, Paper's board D on the page
    "Answering from the notch" of the file "SitRep · side panel"). A new
    ask's banner answers the ask, with the buttons macOS draws, shown as
    the pointer reaches the banner, by the ask's shape:
    - a yes: one button, its yes, in the ask's words (`Go`);
    - a choice: a button for each option, in Claude's order, which macOS
      gathers under Options where there are several;
    - a words ask: Reply, macOS's text field in the banner, with Send.

    No banner offers Ignore: closing a banner is not ignoring its ask. A
    banner's answer goes at once, with no Undo, since a banner has nowhere
    to show one; the asks panel's two seconds are the panel's alone (see
    "Answering from the panel"). A click on the banner itself still jumps,
    as before. The post SitRep relays carries the ask's shape beside its
    words: its id, what it wants, its yes and its options. The helper
    registers a category of the banner's own, its actions those buttons,
    before posting it, and relays a button's response back to SitRep: the
    ask's id, and the answer pressed or the words typed. SitRep runs
    `sitrep answer` with them, the words kept to one line as the CLI keeps
    them. A refusal, the ask answered in its window meanwhile among them,
    posts a banner "Not answered" over the CLI's words, as a refused
    snooze posts "Not snoozed". A banner for Lee's turn, the test
    notification, a refusal's banner and the banner of an ask with no
    options to choose from have no buttons.
- **Answering from the edge** (24 November 2026; see "Answering from the
  panel"): a yes or a choice from the asks panel, and a yes, a choice or
  words from a new ask's banner (below), each through `sitrep answer`. A
  words ask on the panel, a permission prompt and Claude Code's question
  stay in Claude Code: the panel shows them, and takes Lee there. From 17
  October 2026 until then, all answering stayed in Claude Code.
- **Clicking** a session, an ask or a macOS notification takes Lee to the
  Ghostty window showing that session, on whatever Space it is, and leaves
  SitRep's windows on their own Space. A
  notification's click activates the notices helper, not SitRep. A click
  on a notification naming no session (a refusal, or the test with no
  window holding one) hides the helper, handing the front back to the app
  Lee was in, as nothing jumps; so does a click whose jump SitRep refuses,
  or whose window could not be opened, or is opening already from a click a
  moment ago (stage 7, step C), SitRep telling the helper that relayed it,
  while it listens, and no later one. A click turned away as another jump runs leaves it, as that
  jump brings its window forward. A click that starts the helper is told
  as it launches, perhaps before macOS's activation lands, so the helper
  not yet active hides as it next becomes active, within a second, and
  an activation later than that, of its own, is never hidden. A session no
  terminal on this Mac shows, held or away, is carried on by Lee's
  resume command, in a new window of the terminal he chose, a Claude of it
  suspended where this Mac shows it jumped to instead (stage 8, rethought
  on 13 November 2026). Until then a session a multiplexer held had a
  window opened for it running his open command (stage 7, step C), and an
  away session was carried on from its last window, by the jump, the open
  command or the resume command (stage 8, 12 November 2026).
- **The app holds no board logic** (9 November 2026; see "The structure").
  It runs one `sitrep watch` as its child, which tells it the board as it
  changes (see "One engine, two front ends"), and repeats none of the
  board's rules. Each jump was a one-off call to the CLI until stage 7
  moved the jump into the app (A3, 9 November 2026), as the Mac's own work
  is the app's: SitRep jumps from the watch's last line. Written
  on 13 October 2026 as "the app holds no sitrep logic", which kept the
  board's rules out of the app and swept the Mac's own work into the CLI
  with them; corrected on 9 November 2026. First written as the app
  watching the state folder and asking the CLI for the board; changed on
  16 October 2026 so that presence expiry and what is new, which decides
  the notch's swell, are worked out in core, not in the app. Once a remote
  surface exists, the app also hosts serving.
- **tmux, zmx and Ghostty stay at the edge.** Only the jump, the read of
  which sessions this Mac shows, and the opening of a window (`Opening`,
  typing the resume command) know them;
  core and the pane never do, beyond a heartbeat's `where` naming a tmux
  pane or a zmx session, and the app does since stage 7 moved the jump into
  it, behind its drivers and adapters. Portal is not involved, but as the
  resume command Lee may give (stage 8; "Sitrep should have no knowledge
  of Portal", Lee, 13 November 2026).

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
an ask or, since 13 November 2026, Lee's turn, it is 15 × 124, with the
light inside. It opens into a black panel:
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

**Lit by what is needed** (13 November 2026, Lee). The light is orange
while any ask waits; otherwise blue while any session stands at Lee's
turn; otherwise unlit, as before. The blue is #3F93FB: the orange's
OKLCH lightness and chroma, 0.663 and 0.174, at the hue of macOS's system
blue, 255.5, so it matches the orange in strength and neither shouts over
the other. The light's other colours are the orange's turned the same
way, its tips #1F65B7, its breath's peak #7CB5FF and its spots #AED0FF,
the two lightest with their chroma cut to what sRGB holds. Going out, it
keeps the colour it last had. Every mark follows one grammar: colour says
what is needed, orange for an ask and blue for Lee's turn; fill says where
the session is, filled where this Mac shows it and hollow away (see "How
each row reads"). Until then the light lit for asks alone, and orange was
the only colour that waited on Lee.

Six steps were tried, from a bloom to a glow inside the material. A bloom
looked blurred from across the room. Lee wanted "the crisp edges on the
black background", with a little happening inside: subtle, and narrower.

**The rows** (16 October 2026). The panel shows every session that needs
Lee, away ones included, and every session a window holds, working, on its
own work or your turn (see "A session's state"). An away session with
nothing waiting stays off it. A session a window holds that no terminal
on this Mac shows, its Claude running hidden or attached only from
another device, stays on it dimmed, keeping its state, and its place
outside Needs you, as an away row is dimmed (stage 8's rethink, 13
November 2026, Lee's choice): SitRep reads which sessions this Mac shows every few seconds,
and core knows nothing of it. In this order (13 November 2026):
1. needs you: its asks first, an ask, a permission prompt or a question
   waiting, then its turns, the sessions at Lee's turn; each the sessions
   this Mac shows first, then the away ones, each newest first by its
   row's newest line, as core orders them; a session held where this Mac
   doesn't show it, which core has among those it shows, leads the away
   ones;
2. working, longest running first;
3. on its own work: those waiting on a wake first, the soonest due first,
   then the rest, the longest waiting first.

Your turn joined Needs you on 13 November 2026, decided with Lee: an ask
and a finished turn both mean "go back to this session", Claude needing
Lee explicitly or implicitly, so they share one section, on the card and
the menu, and one total, "11 need you", which the card's eyebrow tells
in two, its asks and its stopped (see "The sections"); the strip followed
the next day (see "The strip").
**Stopped** is what the Mac app calls a blue row to Lee (Lee, 13 November
2026): Claude has stopped and waits on him. Settings' Notifications says
"when Claude stops" for the turn's banner, sound and pulse, the turn's
banner is titled "Stopped", and the eyebrow's blue count is the stopped;
until then the app said "Your turn", and "when it's my turn". This design
still says "your turn" where it names core's state, `yourTurn`, as the
code, saved settings keys included (`notifiesTurns`, `playsTurnSound`,
`turnSound`, `pulsesTurns`), keeps its names, so nothing stored changes
meaning; the plugin's own board inside Claude Code is unchanged.
A session is one row in Needs you, never two (Lee, 13 November 2026): one
at his turn with asks waiting, not snoozed, is an ask's row, orange,
counted by its asks, its turn adding no row and no count; only one at his
turn with none waiting is a your-turn row, blue, counted as 1. So three
sessions with asks, one holding two, make 4, and seven others at his turn
make "11 need you". Core's rows already were so, a session's asks winning
over its windows' state.
Core still orders the rows as before, asks, then turns, then working,
and only `watch` reads that order; the app
regroups Needs you itself (`inPanelOrder`), since only it knows which
sessions this Mac shows, so core's feed and the plugin's own board are
unchanged. Until then the order was: needs you, newest first, with away
ones last, a session this Mac didn't show keeping its place; your turn,
newest first; working; on its own work.

Your turn came up under Needs you, over the hairline, on every surface (4
November 2026, Paper's board I, "Yours, above the line"). Lee: a your-turn
session waits on him as much as an ask does, and a working one doesn't, so
Your turn belongs up with Needs you and Working lower; and the less
important section had the taller rows. Of the plan: "I'm happy to go with
your recommendation"; of the board: "Yea, this looks great." Working and on
its own work had come above your turn with on its own work (22 October
2026), as board A, the base of the card's sections, put Working above Your
turn; Your turn was second before that. Needs you went newest first the
same day, on every surface together, at Lee's earlier asking, so a new ask
comes in at the top; it was oldest first, by each row's oldest line, until
4 November 2026.

**The sections** (22 October 2026, Paper's board D, "One list, two sizes",
from boards A, B and C). Lee, of the three boards: "A is kind of the base,
but using B's flattened, one-line turn, and then using C's collapsing turns
that move outside of the period." So the card lists its rows in sections,
each under an eyebrow: Needs you, its asks then its turns, Working (on its
own work at its end), then Snoozed, since 13 November 2026, when Your turn
joined Needs you (see "The rows"). From 4 November 2026 they were Needs
you, Your turn, Working, then Snoozed (board I), and Working came before
Your turn until then. A section with no rows is left out, its eyebrow
with it.
- **The head goes.** "4 need you · 6 sessions" told what the eyebrows now
  carry. It stays only where there is nothing to list, as the empty card's
  "All clear", "Looking for sessions…" or why SitRep can't read the board,
  and while the board is stale, to say when it was last known current, "as
  of 12:04", over the sections. With no head, the first eyebrow sits 4
  under the card's top padding of 12, so the first row stands at 44, where
  it stood under the head.
- **An eyebrow** is 28 tall: the section's name 10 in, 11 semibold in white
  at 55%, Needs you's too, its turns in it or not; its count, or Needs
  you's two (below), 6 after it, 11 semibold in tabular figures, the faint
  grey (#5C5C63) for Snoozed and white at 30% for Working; and at its
  right a chevron, 10 by 6 and stroked 1.5 in white at 25% with round
  caps, in a box 15 by 24 that stands 7.5 in, so the chevron ends where a
  row's time does. Needs you has two counts side by side, the second 6
  after the first (Lee, 13 November 2026): its asks in orange, the lines
  of its ask rows, the asks and the windows stopped on a prompt (Kit's one
  and Tailspin's three are 4), then its stopped in #124's blue, its
  your-turn rows, one a session; each is drawn only above zero, so 4 asks
  and 7 stopped read "4 7", asks alone the orange one, stopped alone the
  blue. On glass the same, in Claude's orange and the blue. Until then it
  had one count, in orange, the turns counted in it since they joined
  Needs you that morning, so 4 asks and 7 turns read 11. Working counts
  its rows, as Your turn did; Snoozed counts its lines, as Needs you its
  lines. Every eyebrow after the first
  sits 14 under the last row above it, or the eyebrow above where that
  section is folded: the space alone tells the sections apart (board J2,
  4 November 2026; see "No hairline"). Earlier that day, from board I, the
  eyebrow after the hairline followed it straight on, Your turn's sat 10
  under Needs you's last row and Snoozed's 10 under Working; until board I
  the hairline came after Needs you, Working's eyebrow followed it, and
  Your turn's sat 10 under Working.
- **No hairline** (4 November 2026, Paper's board J2, "One shape, no
  rules"): the card draws no rule between its sections, only the 14 over
  each eyebrow after the first. Lee, of board I's card live: "I don't
  really like the difference in design. We've got a horizontal rule
  between Your Turn and Working, but there's no rule between Working and
  Snoozed and no rule between Needs You and Your Turn… I'm leaning towards
  not and just using the spacing." A rule at one of three boundaries made
  the sections look unlike each other. The menu bar's menu keeps its
  separator, a menu's own idiom (see "The menu bar item"), and the strip
  is unchanged. From board I that morning the hairline divided what waits
  on Lee from what doesn't:
  it sat after Your turn, "N earlier" included, whenever another section
  followed; with no Your turn, after Needs you; with neither, there was
  none. Until board I it sat after Needs you only.
- **Folding.** A click on an eyebrow folds its section to the eyebrow
  alone, its chevron pointing right (6 by 10); a click again unfolds it.
  Either changes at once, with no motion, as the Settings card does (Lee,
  22 October 2026, of the motion there: "a bit jarring"). The folds are kept
  across opens and launches, a value of their own in the app's defaults
  under "card", each section saved folded or unfolded, so one added later
  takes its own default: Snoozed, folded at first, reads folded from a value
  saved before it was, and every other section open. A fold of Your turn
  saved before 13 November 2026 is passed over, as a section this version
  does not know is, and Needs you takes its own. The folds are one setting
  with the strip's (14 November 2026, Lee): a section folded on the card is
  folded on the strip and the other way, each reading it as it lays out,
  so switching Show between the notch and the strip shows the same folds.
  An arrival unfolds Needs you, at once, while Lee has the notch show the
  board: a row holding a line
  new to the board, as swells the notch, whether the session is new, comes
  to need Lee or gains a line. The unfold is kept, as a click's is: Needs
  you stays open until Lee folds it again. With the strip chosen, Needs
  you folded stays folded, and its count on the strip flashes (14 November
  2026; until then an arrival unfolded it whichever showed). At once is
  for what the fold changes only, the section's rows coming or going;
  every other row keeps
  its own motion, one folding away finishing and one arriving, the new
  ask's own row among them, folding in.
- **One shape** (board J2, 4 November 2026): every row is one line, 30
  tall, inset 10, its lift's corners 10, with no gap between rows, in black
  and on glass alike (see "How each row reads"). Lee, of board I's card,
  its rows of two heights: they "look a little odd". From board I that
  morning Needs you's and Your turn's rows were drawn whole, two lines, 49
  tall, and Working's and Snoozed's one line; from 22 October 2026 until
  board I Your turn's rows were the one line and Working's two, so the less
  important section had the taller rows.
- **No "N earlier"** (board J2, 4 November 2026): Your turn shows every
  row, however long ago its turn ended. Lee: "Your Turn shouldn't have
  Earlier. It should just be expanded." Settings' "Your turn folds after"
  went with it; a value saved for it is read and passed over, as a retired
  key is. Until then, your-turn sessions whose turn ended longer ago than
  the fold period (an hour unless Lee set four hours, today or never)
  folded into one line at Your turn's end, shown only while at least one
  had: 34 tall, 2 under the row above, its ring at white 35%, "8 earlier"
  in 13 regular in the soft grey, then 7 after it their projects, 12 in the
  faint grey, comma-separated, each once in the rows' order, cut short with
  an ellipsis, and a right chevron. A click opened it in place, the earlier
  sessions under it as ordinary your-turn rows, the line staying as their
  eyebrow with its chevron pointing down; a click again folded them, each
  at once. Whether it was open was never kept: it was folded each time the
  card came out, since what it held was stale. The period was measured
  from each row's time, its turn's end, against the wall clock: "today"
  folded what ended before local midnight, and "never" showed no "N
  earlier". As time passed a row folded in where it passed the period, at
  once, the card drawn again at that moment, and nothing polled.
- **Snoozed** (23 October 2026, Paper's board G; see "Snooze") is the
  card's last section, under Working since 4 November 2026 (under Your
  turn until then), 14 under it as every eyebrow after the first (10 from
  board I until board J2, that day): a row for each session Lee snoozed,
  its lines its asks and its turn, the soonest to wake first, as `watch`'s
  `snoozed` has them (one row since 13 November 2026; its asks' and its
  turn's apart from 4 November). A snoozed session whose window stopped on
  a prompt or a question has a row in Needs you as well, as two rows of
  the one session. It is folded at first, to its eyebrow and its count.
  Its rows are the card's and the strip's (the strip's since 14 November
  2026, the card's alone until then): the menu shows none, nothing in it
  lights or swells the notch, and none of its rows washes. With
  nothing else to list, the card lists Snoozed with no head.

**A row is a session**, on every surface (22 October 2026, Paper's board D,
"One list, two sizes"). Lee, of a first draw that set a session's asks
under a line of its own: "It shouldn't look different if a session has
multiple asks." So a row has lines, and one shape serves every section: a
Needs you row has a line for each ask waiting and each permission prompt or
question its windows are stopped on, the newest first (the oldest first
until 4 November 2026); any other row has one, its state's. It is one row:
one lift, one press, one pick, and a click anywhere on it jumps to the
session, but on a Needs you row's arrow, which opens the asks panel (24
November 2026; see "Answering from the panel"). Needs you sorts by each
row's newest line, newest first (by its
oldest, oldest first, until 4 November 2026), and its count, on its
eyebrow, is of lines: the asks and stops waiting, not the sessions.

**A Needs you row shows the session, not its asks** (22 October 2026,
Paper's board F, "The session, and +2", which Lee approved, superseding
board D's stack of lines and board E). Its title is the session's name, the
line under it its project's name, the dot as before, on every surface that
shows it: the card, the strip's tab and the menu. More than one line
waiting adds a quiet count after the name, the plain number of lines
waiting: "Build the Mac app 4" for four; one line shows none, the row itself
saying something waits. No ask's words are on the row, so a question's own
"+2" is not either. Until 6 November 2026 the count read "+N", N the lines
after the first, left from when the row led with its first ask; with the
name leading, Lee read "+3" for four as wrong: "it's not plus, it's not
additional, it's just four." A Snoozed row's count is the same.

Core decides the rows (`core/rows.ts`, 19 October 2026), and `sitrep
watch` prints them in this order, for the app to draw as they come: a row
per session that needs Lee, its lines its asks waiting and its live
windows' stops, showing only those; else a row per session a window holds,
of one line: working where any of its windows is, the one whose turn began
last, else on its own work where any is, else your turn, each the one whose
turn ended last. Each line says what it is, its words as below, and the
instant its time counts from: an ask's posting, or its reopening; a stop's
showing; the turn's end on your turn and on its own work; the turn's start
while working. A row's time is its newest line's (its oldest's until 4
November 2026), what it shows and what orders it; what says how long a
session has needed Lee, as `watch`'s session `since`, keeps its oldest
line's. While a tool runs, a working row
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

Rows keep their places while the panel is open: a changed row moves only once
it closes. Each part, Needs you's asks, its turns, Working or Snoozed, is held
on its own and the parts follow in their order, so each section stays together
under its eyebrow, and Needs you's asks over its turns, however the order
changes meanwhile (22 October 2026, rows by session, then the card's sections;
Needs you's asks and turns since 13 November 2026, Your turn a section of its
own until then). A row going from an ask to a turn, its asks answered, or
from a turn to an ask, changes part, as a row changing section does. A row is kept by its session, so one
gaining or losing a line in Needs you, as a second ask comes, is the same
row, its count changed where it stands, at once, as is one going from working
to on its own work, both Working. A row changing section, its session coming
to need Lee, its asks answered, or its turn ending, leaves its held place and
takes its place in its new section: it folds away where it was and unfolds in
the other, as two rows, as when each ask was a row of its own, washed where
it arrives and never as it folds away. Meanwhile a row gone folds away where it was, and a new
one unfolds, washed if it needs Lee (20 October 2026). A row new to a
section, new to the board or come from another, goes under the row core has
above it in that section, or at the section's top where core has none there.
A click on a dimmed row, away or held where this Mac doesn't show it,
carries its session on: a Claude of it suspended where this Mac shows it
is jumped to, starting nothing; otherwise a new window in the terminal Lee
chose runs his resume command (stage 8, rethought with Lee on 13 November
2026). From 12 November 2026 an away row's click went by what was left of
its last window instead: the terminal showing it, a window opened onto it
where it was still alive, or Claude started again where nothing was left.
Until then a click on it did nothing, and what it would open was left for
later (Lee, 16 October 2026). This replaces the first list, needs you, your turn, working,
quiet and not on screen: quiet was your turn, and not on screen is a fact
about where a window is, for the jump.

**How each row reads**, drawn in Paper's "Panel rows" (surfaces round 1,
16 October 2026; Lee: "everything looks great"). Since board J2 (4
November 2026; see "One shape") every row on the card is one line, 30
tall: a mark, its words cut short with an ellipsis, its project in a lane
at their right, 12 in the faint grey on their baseline, its own width and
never cut, 12 after the words at the least, and a time on the right in the
36 lane. From board I that morning a row above the hairline had two lines
and a row below it one; until board I a mark, two lines, and a time on the
right, Your turn's row alone on one line from 22 October 2026:
- **needs you** (board F, 22 October 2026; one line since board J2, 4
  November 2026): an orange dot with its glow; the session's name, 13
  medium in the text colour, cut short; its project at its right; how long
  its newest line has waited (its oldest until 4 November 2026). One row
  of 30 however many lines wait, an ask, a permission prompt or a question
  alike. Its window may still be working: needs you wins, so nothing else
  shows. More than one line waiting adds their count after the name, "4"
  for four: 13, weight 500, in the soft grey, in tabular figures, 6 after
  the name on its baseline; the name is cut short before it, never the
  count. Until board
  J2 it was drawn whole, 49 tall, the name 14 medium with its project's
  name under it (55 until 26 October 2026, when Lee found the two-line rows
  too spaced against Your turn's one-line rows: 7 above the two lines and 8
  below, not 10 and 11);
- **away, with an ask** (3 November 2026): its mark is a hollow orange ring,
  7 across, its stroke 1.5 inside it, with no glow, on every surface: the
  card, the strip and the menu. The filled dot and its glow stay for an
  ask whose window is there. Orange says an ask waits on Lee; hollow, that no window holds it,
  as Slack and Teams mark someone away. Since stage 8's rethink (13
  November 2026) a session a window holds that no terminal on this Mac
  shows takes the ring and the dimming too: hollow, that no window
  here shows it. Lee: "Rather than the orange circle,
  we need a better icon to indicate that it's an ask, but there's no window
  open." Until then the dot stayed orange. A turn away takes the same
  ring in blue (13 November 2026). Its words dim as one: its title,
  its count, the line under it and, where it would read brighter than its
  title, its time, each to 0.61 of its ink, so the title stays the brighter
  of its two lines and both sit below the rows round them. Lee: "The title
  and the project should be dimmed at the same ratio so that they're
  different to each other, but then dimmed relative to their siblings."
  0.61 is the least that keeps the black card's second line, its soft grey
  dimmed, at the faint grey (#5C5C63) or brighter, about 3:1 on the black.
  Until then each surface dimmed its own way: the card its title to #6E6E76
  and the line under it to the faint grey, the sidebar its name alone, its
  project left brighter than it, and the strip its words to #8A8A92. Under
  the pointer it doesn't lift, and its title is still the session's name.
  On the card's one line since board J2 (4 November 2026) its project at
  its right is left in the faint grey, which the dimmed second line came to,
  and the ring alone says no window holds it; until then its second line
  said "No window holds it. Carry it on in Claude." in place of its
  project;
- **your turn**, on one line (board B's, in board D, 22 October 2026;
  Lee: "B's flattened, one-line turn"): since 13 November 2026 a blue dot 7
  across with its glow, an ask's dot in blue, and away a hollow blue ring 7
  across, unlit, an away ask's ring in blue: colour says what is needed,
  fill where the session is. Until then an open white ring 9 across with
  a stroke of 1.5 in the 12 mark lane, so its shape differed from the dot,
  not only its colour, which Lee found said nothing; what Claude left Lee,
  the board's "now", 13 regular
  in the text colour, cut short, regular so Needs you keeps the heavier
  title; its project at its right; how long it has waited, faint, in the
  36 lane. It lifts, presses, jumps and washes as any row does. From board
  I that morning until board J2 (4 November 2026) it was drawn whole, 49
  tall, its words 14 regular with "project · session" under them, 12 in
  the soft grey, its lift radius 14;
- **working**, on one line (board I, 4 November 2026; two lines until
  then): 30 tall, inset 10, a turning arc in the mark lane, and a slow
  grey-to-white shimmer along its verb, as Claude Code's own; while a tool
  runs, the verb, 13 medium, and 6 after it what it acts on, 13 regular in
  #8E8E95, or a path or command in mono 12, still; else the board's "now";
  its project in a lane at its right, 12 in the faint grey, on its
  baseline, its own width and never cut, 12 after the words at the least;
  how long the turn has run, in the 36 lane. The session's name is not on
  the row. It is greyer than the rest: it needs nothing. Its lift radius is
  10, as every row's on one line, so two lifts side by side meet, as board
  D's did (14 until 4 November 2026).
  Every arc turns in step (3 November 2026): on every surface, the card, the
  strip and the menu, each turns from the one clock, the
  phase it starts at the clock's time within its period, so two arcs turning
  at one pace are at one angle however far apart they started. Each had
  started at a phase of its own until then.
- **on its own work** (Paper's board D, "One list, two sizes", 22 October
  2026): the working row's layout, all of it still, on one line since board
  I. Its mark is a ring of round-capped dashes that never turns, #8E8E95,
  centred in the working mark's 11-wide lane (r 4.5, its stroke 1.5, dashes
  1.6 with gaps of 2.12); its verb 13 medium in #B4B4BA, what it waits on 13
  regular in #8E8E95 6 after it, or a command in mono 12 as working sets
  one (14 and the command's 13 on two lines, until 4 November 2026); its
  project at its right as working's; how long since its turn ended.
  Nothing of it runs: no shimmer, no turning, and only a wake's countdown
  is drawn again, as it reads differently.
- **snoozed** (Paper's board G, 23 October 2026): a needs you row quieted,
  on one line since board I (4 November 2026), 30 tall. Its dot 7 across
  with no glow, its orange dimmed by the away rows' 0.61, which stands it
  about as bright on the black as the faint grey, #5C5C63, it was until 13
  November 2026 (on glass the orange at 0.61); the session's name 13 in the soft
  grey, #98989F, cut short, its count faint after it; its project in a lane
  at its right, 12 in the faint grey. An away row is drawn the same, since
  an ask Lee put off urges nothing until it wakes; it still jumps nowhere.
  In its time's place, when it wakes, in the soft grey, 12 in tabular
  figures, 24-hour and local, said by the calendar week, Monday to Sunday,
  as Snooze counts it, the first of these that holds (Lee, 18 November
  2026):

  | When it wakes | Words | Spoken |
  |---|---|---|
  | today | "17:42" | "17:42" |
  | tomorrow | "tomorrow 09:00" | "tomorrow 09:00" |
  | later this week | "Sat 09:00" | "Saturday 09:00" |
  | in the next calendar week | "next week" | "next week" |
  | further out, or a day gone by | "3 Dec 09:00" | "3 December 09:00" |

  So Sunday's tomorrow, a Monday, is "tomorrow 09:00", and a Saturday's
  next Saturday is "next week". A day gone by is worded only as a time
  that has come already. The spoken forms are kept for VoiceOver, but no
  row hands them to it yet (`spoken: true` has no caller). Snoozed with no time, it says "until it
  moves" (13 November 2026). The pane's `snoozed until` says the same,
  from core's `wakeWords`, the app's `WakeTime.words` its copy. Until 18
  November 2026 the app said a weekday for each of the six days after
  today, tomorrow among them, then a date, and the pane "tomorrow", a
  weekday to six days on, then a date. Its lane is the
  time's 36, grown to fit the words where they are wider, still ending
  where a time does, the name and project cut short before it. The words
  change only at midnight, a week's edge among them, so the card is drawn
  again then for them, never each minute. Until board I it had two lines,
  its project under its name.
- **a turn snoozed** (board I, 4 November 2026; see "A turn snoozes too"),
  a session's turn alone, with no ask asleep beside it, which would make
  its row a snoozed ask's (13 November 2026, "The row snoozes"): a
  snoozed row whose mark is the snoozed ask's dot in blue, dimmed the same,
  since 13 November 2026; until then your turn's ring in the faint grey, 9
  across, its stroke 1.5, #5C5C63; its session's name 13 in the soft grey, its
  project in the lane at its right, and in its time's place when it wakes,
  or "until it moves", in the soft grey.

The shimmer stays neutral. Orange is for asks only: the dot, the wash and a
new row's "now"; blue is for Lee's turn's dot alone (13 November 2026). Lee had suggested working titles shimmer white or
grey to orange, then left it to Claude; it can change after a test. The
sections are told apart by the space over their eyebrows and the eyebrows
themselves, and their rows by their marks (board J2, 4 November 2026; a
hairline sat after what waited on Lee until then). A row under the pointer
lifts to #141416, with no ⏎ hint, since the panel never takes the
keyboard; an eyebrow never lifts. With nothing needing Lee, the notch rests
with no light; with nothing at all, the head reads "All clear".

Each row says what it is, its project at its right (and drawn whole, with
its project and session beneath, or a Needs you row's project, until 4
November 2026). A
click jumps: the row presses in and spins for up to 450ms in its time lane,
the panel drains, and a caption says where it jumped. A new ask
makes the notch over-swell twice, to 25 deep, about 450ms apart, as each
comes back through its 15. The light flashes with each, and its row, new or
gaining the line, gets an orange wash for 2 seconds. Since 13 November 2026
the swell and its flashes, the notch's pulse, are a setting, on for a new
ask by default; a session moving into Lee's turn pulses it the same way
where Lee turns that on, off by default, as the steady blue light shows it
already (see Settings, Notifications). With a pulse off, what it would have
pulsed for lights the notch with none. Lee set the swell on the display
(15 October 2026). The prototype swells once, to 19, which Lee found a
little too quiet, and Lee thought it might look nice twice.

**A right-click on any row brings up its menu** (board F, 22 October
2026): Jump to the window, as a click; on an away row, or one this Mac
doesn't show, as its click does (stage 8; disabled on an away row until
12 November 2026). While the
menu shows, the card holds open as if the pointer rested where it was
opened, wherever the pointer goes on the menu, and its grace starts only
once the menu closes, so a choice made on it finds its row still there.
Under the pointer a row's time stays, but on a Needs you row with an ask
the asks panel answers, whose arrow takes its place (24 November 2026; see
"Answering from the panel"): the button that took its place until 5
November 2026, opening the session in the SitRep window, went with the
window, and so did the menu's Open in SitRep.

On a row whose lines hold asks, or a your-turn row (since 4 November 2026,
board I), the menu goes on, after a separator, with Snooze (board G, 23
October 2026; see "Snooze"): a submenu of the choices offered, as Lee set
them in Settings' Snooze pane: In an hour, Later today, Tonight while its
time is to come (both 17 November 2026), Tomorrow, This weekend while its
time is to come and Next week, each with the time it wakes on its right,
in white at 45%, at 70% on the
highlighted item, then a separator and Until
it moves, with no time on its right, the same on every row (13 November
2026). The time says only what the choice's name does not (Lee, 18
November 2026): the clock alone where the name fixes the day, In an hour
"15:42", Later today "18:42", Tonight "19:00" and Tomorrow "09:00"; the
weekday and clock for This weekend, "Sat 09:00", and Next week, "Mon
09:00" (`WakeTime.besideChoice`). A snoozed row's relative words would
repeat the name, "Tomorrow · tomorrow 09:00". Until 18 November 2026 the
menu worded each time as a snoozed row did then, "Sat 09:00" beside
Tomorrow on a Friday. A choice runs `sitrep snooze` of the row's session
with the ids of the asks the row showed, none on a your-turn row, its time
worked out at the press, none for Until it moves, so an ask landed since
is never snoozed unseen. A Snoozed row's menu ends with Wake now, in
Snooze's place, which runs `sitrep wake` of its session. A row of stops
alone offers no Snooze. From 4 to 13 November 2026 only a your-turn row's
Snooze had Until it moves, and its choices and Wake now named the turn,
`--turn`, by its end, which went as the row came to snooze whole (see "The
row snoozes"). A working row offers none. The CLI refusing either says why in a banner, "Not
snoozed" or "Not woken" over the CLI's words, as a refused finish does. The
system's menu sets a submenu's items as its own: the times are each item's
second column, set on a tab stop past the widest name, and brighter as the
item is highlighted. The card's rows are drawn layers, which VoiceOver
does not read today, so neither the button nor the menu is offered to it.

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
  `.stationary`, `.ignoresCycle`), and hidden while a full-screen app has
  its display: clear and letting every click through, never ordered out
  (under "The strip", "Windows and full screen");
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

### Answering from the panel

Decided with Lee on 24 November 2026, and drawn in Paper (the file "SitRep
· side panel", the page "Answering from the notch"). Board F is the design,
keeping boards E1 and E2's arrow; boards A, B and E were drawn and not
taken; board D is the banner (see "The menu bar", "Its buttons"). One
(getone.one) and every notch app for Claude Code answer from the screen's
edge, and SitRep's plumbing was there already: `sitrep answer` writes a
reply into the session's inbox, and the session's window delivers it as
"From the board:" (see "One engine, two front ends"). Until then this
section was a line under "The notch and its panel", "Later: answering from
the panel": a yes or a choice would go through the session's inbox, and a
permission prompt would need a hook that holds Claude Code's prompt open.

**Rejected: the notch opening by itself** (board C, "peek"). SitRep never
interrupts: nothing on its surfaces opens, pops or takes focus by itself;
it lights and waits, and Lee comes to it.

**The row's arrow** (boards E1 and E2, kept in F). A Needs you row with at
least one board ask the panel can answer, a yes, a choice or a words ask,
has two places to click:
- its words: a click jumps to the session's window, as before;
- its arrow, at its right end: a button of its own, 40 wide and 26 tall,
  radius 8, in the time lane's place while the pointer is on the row, the
  time showing otherwise. Unlit, its chevron is the soft grey on the row's
  hover fill; it lights as the pointer reaches it, its fill #34343B and
  its chevron white. A click on it opens the asks panel.

A row whose waiting lines are only Claude Code's own permission prompts or
questions has no arrow, since the panel can't answer those. Nor have
Stopped rows, Working rows or Snoozed rows.

**The asks panel** (board F) opens beside the list, level with the row,
its first line level with the row's line. It overlaps the list's right
edge by 8 points and sits on top of it, with a hairline border, white at
15%, and a shadow, as a Mac submenu opens beside its menu (Lee, with a
screenshot of a Paper menu's Services submenu). It is the panel's black,
372 wide, radius 24, its height its content's. The row stays lit, its
hover fill and its arrow lit, while its asks panel is open.

It shows one ask at a time, the session's asks in the row's order, newest
first:
- **The top line:** the session's name, 12 semibold in white, and its
  project, 12 in the faint grey. At its right, page dots where the session
  has more than one ask: the current one orange, 14 × 5, the others 5 × 5,
  #3A3A40.
- **The ask's title,** 17 semibold, letter-spacing -0.02em, its line 22;
  under it "Asked 4m ago", 12 in the faint grey, the age from the ask's
  posting or reopening, as its line on the row counts from.
- **Its answers** as numbered rows, full width: 38 tall, radius 11, fill
  #1C1C1F, border #34343A. A keycap, 20 × 20, radius 6, fill #2C2C31,
  holds its number, 11 semibold in the soft grey; the label is 13 medium
  in white. The recommended option's row ends in "recommended", 11 medium
  in the faint grey. A yes has one row, its yes; a choice a row for each
  option, in Claude's order.
- **A words ask** has one outlined row, with no fill and its border
  #2C2C31, its keycap holding ↗, reading "Answer in Claude": a click jumps
  to the session's window. So does an ask with no options to choose from.
- **The foot:** Ignore and Snooze ▾, in the soft grey, and, for a yes or a
  choice, an outlined "Open in Claude ↗" at its right, which jumps.

The numbers are labels only. No keys answer, only clicks (Lee, 24 November
2026): the panel never takes the keyboard.

**Opening and closing.** Another row's arrow moves the asks panel to that
session; a click on the lit arrow again closes it. The asks panel stays
open while the pointer is over the list or over it. Leaving both starts the
panel's grace and closes both, as leaving the panel does today. Answering
steps to the session's next ask; after its last, the asks panel closes. An
ask that leaves the board meanwhile, answered in its window or resolved,
leaves the asks panel with it, and the asks panel closes once none is left.

**Answering, with two seconds to undo.** A click on an answer row turns it
white: a white fill, its label in ink, and a check in its keycap's place. A
line at the asks panel's foot reads "Sending Threaded", the answer's words
after "Sending", with a countdown ring and an outlined Undo. After 2
seconds SitRep runs `sitrep answer <ask> <answer>`. Ignore runs `sitrep
answer <ask> --ignore` with the same two seconds, its line reading
"Ignoring". While an answer is held, the asks panel takes no other.
- Undo within the two seconds takes it back, and nothing is written.
- Leaving the notch within the two seconds, or moving the asks panel to
  another row, doesn't cancel: the answer still goes.
- Once it goes, the asks panel steps to the session's next ask.
- A refusal from the CLI, as an ask answered in its window meanwhile,
  posts a banner "Not answered" over the CLI's words, as Snooze's refusals
  post "Not snoozed".

The answer then travels as any `sitrep answer` does: into the session's
inbox, delivered by the session's window as "From the board:". The ask
leaves Needs you once its answer is on its way, as the feed already drops
it.

**Snooze ▾** offers the row's Snooze, the choices of its right-click
menu's submenu (see "A right-click on any row brings up its menu"), and
snoozes the session as that does, closing the asks panel.

**Black and Glass.** The asks panel draws in both Materials, as the panel
does. In Glass it is the panel's glass, its words in the system's label
colours, as the Glass rows are; its rows, keycaps and outlines keep their
shapes, filled in the glass's tints in place of the black's greys, and its
current page dot and its sending line keep Claude's orange and white.

**Not in this build** (see "Later"): the strip, whose tab could take the
arrow later; the menu bar item; permission prompts and Claude Code's
question dialog; keys.

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
were settled in the browser spike (below, "How the strip moves"), whose
prototype is `prototypes/strip/strip.html`.
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
    two seconds, and the ring flashes twice, as the notch swells twice; a
    session stopping, where it flashes (below, "Moving"), flashes its blue,
    its glow brighter, unwashed (14 November 2026), and a flash shows only
    while the mark waits on Lee for what arrived, never running on in
    another colour;
  - **away, with an ask**: orange, the letters dim;
  - **your turn**: blue, with the glow, the letters white, and away the
    letters dim, as an ask's mark in blue (13 November 2026; white, with no
    glow, until then);
  - **working**: a grey track with a pale arc turning round it, the letters
    grey;
  - **on its own work** (3 November 2026): the dotted ring round the
    letters in the 24pt ring's place, in working's grey, eight round-capped
    dashes going round evenly, 1.6 showing between their caps, never
    turning, so it reads as the card's ring grown; the card's own dashes
    there would be nineteen dots. From 22 October 2026 it was working's mark
    held still, which read as a frozen spinner (Lee: "four items that are
    showing with a frozen spinner"). A click's jump still turns an arc on
    it, in the ring's place, as on any mark, and the ring comes back after.
  - **in Snoozed** (14 November 2026): an ask's ring orange and a turn's
    blue, each dimmed as a Snoozed row's dot is, with no glow, the letters
    faint, in black and on glass alike; it never flashes nor washes.

  **Three sections**, as the panel's (14 November 2026, Lee): Needs you,
  Working and Snoozed, in the panel's order, a hairline between each two
  that show, so one over Working and one over Snoozed. Needs you's ask
  marks, then its stopped marks, in the panel's Needs you order; Working's,
  on its own work's among them; Snoozed's, the soonest to wake first, a
  session with a row in Needs you and one in Snoozed a mark in each. The
  prototype was brought to these places, and to Snoozed and the folds, and
  its timelines recorded again by the recorder that made them, so the
  strip is still checked against it frame by frame. The prototype and its
  recorder are in `prototypes/strip` (16 November 2026, from Lee's clone's
  scratch folders), its README saying how to record again; its sessions
  became placeholders then, worded so each tab measures as before, and
  recorded again the timelines came out the same frame for frame. Earlier
  on 14 November the
  strip's Needs you became one, as the panel's is (Lee's pick): "One
  hairline sits under Needs you", its ask marks, then its stopped marks,
  all over it, working's and on its own work's under it, and "The strip
  shows no Snoozed". For a
  day after Your turn joined Needs you (13 November 2026) the strip kept
  its old places: a your-turn mark, blue, under the hairline and over
  working's, and the orange count holding asks alone, since moving them
  needed the timelines recorded again. From 4 November 2026 the marks had
  taken the panel's order of then, your turn's under the hairline and
  above working's, as the prototype had them; the card's hairline moved
  under Your turn (board I) and went that day (board J2), but the strip's
  stayed under needs you, where its places for needs you end. The letters
  are the
  project's capitals where it has two (SitRep SR, VanArsdel VA), else its
  first two (Switchboard Sw, agntc ag); two sessions of one project share them.
  A session with several lines waiting is still one mark.
- **Under the pointer** a mark pours its panel row out of the strip as a
  tab, the material flaring at both ends. A click jumps, as in the panel,
  on the tab or on the mark itself (Lee, 18 October 2026: "I can hover to
  see the card but shouldn't have to click the expanded card"); with no tab
  out yet, the ring presses in and its own arc turns. An away mark's tab
  says "No window holds it. Carry it on in Claude.", and a click on it or
  on the mark carries its session on, as an away row's does (stage 8;
  until 12 November 2026 neither took a click). A session a window holds
  that this Mac doesn't show keeps its state's mark and tab, dimmed, an
  ask's mark the hollow ring, and its click runs as a dimmed row's (stage
  8's rethink, 13 November 2026). A click on a count past its section's
  room opens its tab; on a section folded, it unfolds it (below, "Folded").
  A Snoozed mark's tab says when it wakes, as its card row does, its words
  soft as that row's, and a click on it, or on the mark, jumps to its
  session, as any does. A tab, or a
  count's row, has room for one line: a session needing Lee shows its name
  over its project, its newest line's time (its oldest's until 4 November
  2026), and with several waiting their count ("+N" for the lines after
  the first until 6 November 2026), set dim 6 after the name, as a question's
  "+2" was (board F, 22 October 2026, after the proposal Lee agreed: "a row
  is a session on every surface"). An away one's name sits over "No window
  holds it. Carry it on in Claude.", its words dimming as one, as the
  panel's (see "The rows"; 3 November 2026), on the black and on glass, in
  a tab and in a count's rows alike. A tab's title says what follows its
  verb on every kind, as the card's row does, and on a working tab the
  verb alone shimmers, what follows it still in its grey; with a count,
  what follows gives way, cut with an ellipsis, before the count does (17
  November 2026).
- **Moving.** The strip never shuts, so the panel's "a changed row moves
  only once it closes" becomes one rule (Lee, 14 November 2026): a mark
  moves at once whenever its session changes group, pointer on the strip or
  not, a menu open or not. The groups are the panel's, in its order: Needs
  you's asks, its stopped, Working, those on their own work among it, and
  Snoozed. Moving, a mark leaves its place and grows into the one the
  panel's order gives it in its new group, under the one of its group above
  it, the marks below sliding down to make room, or lands in its section's
  count, folded or past its room. So an ask answered, or a stopped one's
  turn ended, Claude working again, leaves Needs you for Working at once,
  out of its count too; a stopped session asking moves up among the asks at
  once, and an ask whose session comes to its turn down among the stopped; a
  session Lee snoozes moves into Snoozed, and one he wakes, or its time
  wakes, out of it, its row elsewhere moving too wherever the wake changes
  its group, as a session stopped on a prompt whose ask wakes, the other of
  its two asks still asleep. Only the order within a group waits: a change
  that moves a row there, as an ask asked again, shows in place, and the
  marks re-sort a second after the pointer leaves the strip, as the
  prototype's settle does. A session new to the strip comes in at its place
  in the same way, so nothing else re-sorts under the pointer or an open
  menu: one `new` names, or one stopping, as below, and any other,
  unflashed, as needs you with nothing new among them on a run's first
  board, or a session's row new in Snoozed, its row elsewhere staying. One
  gone fades where it is, and the rest close up. One update's moves are
  placed together, each with the others counted for every section's room,
  and laid out once, so each takes its final place at once, at launch too,
  and grows in there. How a move shows is apart from whether it moves. A
  mark arrives when `new` names any of its lines (see "One engine, two front
  ends"): moving in, new to the strip or from another group, its ring
  flashes twice, as a new one's does; one staying in its group, a second ask
  come, flashes where it is. A session stopping, moved from working or on
  its own work into Lee's turn as `LastBoard.newTurns` decides it for the
  banner, moves in before the stopped, its ring flashing twice (14 November
  2026). One its time wakes, which `new` names, arrives in Needs you as a
  new one does, flashing its ring. Any other move is unflashed: one back at
  a turn whose end it stood at before, so no stop for the banner, and one
  Lee snoozes or wakes. Each flashes only as Settings' pulses say, as the
  notch's pulse follows them (14 November 2026): an ask arriving flashes
  twice and is washed while "Pulse for a new ask" is on, and a session
  stopping flashes twice, in its blue and unwashed, while "Pulse when Claude
  stops" is on; with its pulse off either moves all the same, unflashed, and
  any flash its mark still showed ends. Until then a turn ending changed in
  place under the hairline, and an ask flashed whatever its pulse. An ask
  woken into a full Needs you pushes the last stopped mark showing into the
  count, as any ask does; neither Needs you's count nor that push ever
  counts a session Lee snoozed. Earlier on 14 November each mark was held to
  its row's section, not its group: one crossing into Needs you, or into
  Snoozed or out of it, moved at once, and any other change, one leaving
  Needs you for Working among them, showed in place and moved at the
  re-sort; a session new to the strip that nothing named came in as all the
  marks re-sorted at once; and a wake was told by the session's row in
  Snoozed going, which missed the first of a stopped session's two asks
  asleep waking, its row in Snoozed staying: its mark flashed among the
  stopped and moved up among the asks only at the re-sort. Before that a
  session's moves were found three ways, by `new`, by a stop and by a snooze
  or a wake renaming its mark, which missed a wake whose session's row
  elsewhere stayed: an ask woken into a session working sat under Working's
  hairline until the re-sort, which waited while the pointer stayed on the
  strip. Before that a mark Lee snoozed or woke changed in place and moved
  at the re-sort, which left an ask he woke inside Snoozed's folded count,
  and one he snoozed over the hairline, while the pointer stayed on the
  strip. Until then the strip showed no Snoozed (see "Snooze"): an ask
  asleep was no mark, and one Lee woke changed in place.
- **Folded** (14 November 2026, Lee). The strip folds a section as the
  card does, by the one setting both read (see "Folding"), Snoozed folded
  at first. A section folded is one count ring in exactly one place, its
  number the section's sessions, with no plus, looking otherwise as a count
  past the room, which itself has no plus while none of its section's
  marks shows beside it: Needs you's orange while it holds an ask and blue
  while all it holds are stopped, Working's grey, and Snoozed's
  the faint grey of the rows' projects, on the track. Under the pointer it
  pours the section's sessions as one tab of rows, each a click to its
  session; a click on the ring unfolds the section, here and on the card.
  Folding and unfolding lay the strip out again at once, the marks below
  sliding. An arrival into Needs you folded lands in its count, which
  flashes as a count past the room does, as Settings' pulses say.
- **A right-click** (14 November 2026, Lee) on a session's mark, its tab,
  or its row on a count's tab brings up its row's menu on the card, the
  same one (Jump to the window; Snooze, or Wake now in Snoozed), each for
  the session by its own id, with the fold of the section the strip has it
  in at its foot after a separator: Collapse and the section's name, or
  Expand where it is folded, as on its folded count's tab. On a section
  folded, Expand and its name alone; on a count past its room, Collapse
  and its name alone. While the menu shows the strip holds as if the
  pointer rested where it was opened, its hover held on what it was opened
  on however a board slides the marks under that point, so a tab out stays
  out, no other pours, and nothing re-sorts under the choice; a board that
  moves the session meanwhile leaves its Jump going to its mark as the strip
  has it then, the count it is folded into pressing in where no tab is out.
  A mark that a fold or a push puts into a count takes its tab back with it.
- **Too many.** The strip has as many places as Max gives it, or as the
  full height holds: about 30 (32 on a 1117pt screen, 27 on a 982pt one),
  never fewer than one for each section showing. Each section takes its
  places in its turn, keeping one for each after it that holds any (14
  November 2026): Needs you, its asks and its stopped, first, keeping one
  for Working whenever any is working, on its own work among it, and one
  for Snoozed whenever any is snoozed; then Working, keeping Snoozed's;
  Snoozed last. A section folded takes exactly one, its count. Until then
  Needs you kept one for Working alone. Past its
  room, the sessions last in its order fold into a count of their own, the
  needs-you group's last place, over the hairline (Lee, 19 October 2026:
  "new asks should collapse into a number of collapsed icons... in the
  bottom of their own panel"), in this order: the away stopped, then the
  stopped, then the away asks, then the oldest asks. The count's "+N"
  counts the sessions it holds, its ring blue while all it holds are
  stopped and orange while it holds an ask, the only other it can hold, as
  a session working again leaves it at once; its tab lists them as rows,
  each as its own tab words it (14 November 2026). From 19 October
  2026 the count held asks alone, always orange, the oldest folding since
  Needs you went newest first (4 November 2026; the newest until then),
  and your turn took its places with working, past them in the grey
  count. Working takes the places left but Snoozed's, and past them its
  last place is the grey count ("+3"); Snoozed takes the rest, past them
  its last place its own faint count. Under the pointer each count pours
  out what it holds as one tab of rows, which scroll on a short strip. A
  new ask arriving past needs you's room while a stopped mark shows below its
  place takes its place among the asks all the same, under the one the
  panel's order has above it, the marks below sliding down, and the last
  stopped mark showing goes into the count, its tab drawing back if it
  has one out (Lee, 14 November 2026). What shows is judged as the strip
  stands once the arriving session has left its old place, so the only
  working session asking frees its place for Needs you first. No stopped
  mark shows above its place, as the stopped keep to their own run of
  Needs you, under the asks; until the group rule one could, before a
  re-sort, and stayed. With no stopped mark showing below its place, a new
  ask lands in the count, and a session stopping lands there whatever shows,
  the marks showing never moving: only asks push stopped marks out. Landing
  so, out of the panel's order, it waits for the re-sort as any order within
  a group does, and a second after the pointer leaves the strip the panel's
  order comes back. Until then every arrival past the room landed in the
  count, the marks showing never moving. One landing there flashes the
  count's ring twice in the count's own colour, orange while it holds an
  ask, each only with its pulse on, an ask washing it too; several landing
  in one update, or folded there by another arriving, add up, an ask's
  showing over a stop's; one landing there quietly ends a flash the count
  still shows for that same session, as does that session leaving the count.
  A count going keeps its colour as it fades. An ask answered in the count
  leaves it at once for Working, its row going from the count's tab: the
  count shrinks, or goes and the last folded mark takes its place (Lee, 14
  November 2026). Until then its row changed in place, and the count shrank
  at the re-sort; Lee: "It works."
- **Windows and full screen:** macOS lets no app reserve screen space as the
  Dock does, so a window filling the screen goes under the strip's 36pt; Lee
  hasn't said how that reads. Nothing of SitRep's goes over a full-screen
  window, the notch as well as the strip (Lee, 19 October 2026: "It should
  be hidden. Nothing should go over the top of a full screen window"): while
  a full-screen app has the panel's display, the panel is hidden, clear and
  letting every click through, and it shows again as the display leaves it.
  A maximised window doesn't count, and each display is judged on its own.
  How SitRep tells, as the spike found:
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
  - **Hidden is clear, never ordered out.** The edge was ordered out over
    full screen and back in after, and came back on one Space only (26
    October 2026): read through SkyLight, the notch's window was on all 18
    Spaces as Chrome went full screen, and on the one it came back to once
    ordered in again, until SitRep restarted. On every other Space it showed
    for half a second as the Space slid in, then went. Lee: "It flashes,
    it's there momentarily, and then it disappears". Once pinned, a window
    stayed pinned through later round trips: Lee, choosing the notch over
    the strip, saw no notch until a restart. So the edge's window, and the
    jump's caption's, which hid the same way, are ordered in once, as they
    are made, and never out: hidden, each is clear and lets every click
    through, and the turns and sweeps Core Animation runs for it in the
    render server are paused, to run again as it shows.
- **Material:** Black, the bezel's, or Glass, macOS 26's Liquid Glass, for
  the strip and its tabs alike, as one shape (Lee, 18 October 2026: "I like
  the glass and the black, actually"). See Settings.

**How the strip moves**, felt in the browser spike (18 October 2026, the
prototype's Strip tab, now `prototypes/strip/strip.html`; Lee kept its
defaults):
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

### The menu bar item

The item in the menu bar and its native menu, drawn in Paper's "The menu
bar item" (surfaces round 4, 17 October 2026). A first drawing kept the
menu to a SitRep window, Settings and Quit. Lee, with Spaceman's menu
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
    clear", counting asks and turns alike since 13 November 2026: "11 need
    you" where 4 asks and 7 turns wait, one total in words where the card's
    eyebrow has two counts. Each is a native item with a subtitle (macOS 14.4): what it is,
    then its project and session, and its time on the right as the item's
    badge. An item is a session, as a row is, with room for one line: one
    needing Lee shows its name over its project, its newest line's time,
    and with several waiting their count, as the strip's tab does (board
    F, 22 October 2026). The line under each row shows at rest, not only under the pointer (3 November 2026; Lee:
    "default for the project name to show on all the menu items"; see the
    build's note on the rows, under "Stages"). A working row's arc turns
    while the menu is open, once a second as the panel's and in step with
    it, but only while a working row shows: nothing runs with none, and
    under Reduce motion it holds still (3 November 2026). A row on its own
    work is faint, as a working row is, its mark the dotted ring, and a
    wake's countdown is set again as it ticks, with the badges. An away
    ask's mark is the away ring (see "The rows"), and a your-turn row's the
    blue dot, or away the blue ring (13 November 2026; the template open
    ring until then). A separator sits after Needs you, where the panel's hairline was until board J2 (4
    November 2026), which took it off the card; the menu keeps it, a
    menu's own idiom. A click jumps;
  - **Show**: Notch, Strip or Nothing, inline, the one in use ticked, so
    pinning the strip takes one click. With Nothing, the menu carries the
    board, and the glyph still lights for needs you;
  - **Show Welcome Window**, the welcome window at its first step (see "The
    welcome window"); "Welcome…" until 3 November 2026. Lee: "'Welcome'
    doesn't mean anything… If that's meant to be the 'show welcome' or
    'show onboarding' again, then say so.";
  - **Settings… ⌘,**, the Settings window (see "Settings");
    **Quit SitRep ⌘Q**. No Check for Updates…: Homebrew updates the app
    (18 November 2026; see "Installing and updating").
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
- **An away session** is enabled since stage 8 (12 November 2026), its
  click carrying it on: its words keep the disabled ink of their own, as
  the panel's dim, but under the pointer, where the highlight's ink takes
  over, and its ring stays orange, as the panel's. A session a window
  holds that this Mac doesn't show is drawn the same, keeping its state's
  mark, an ask's the hollow ring, and clicked the same (stage 8's rethink,
  13 November 2026). Until 12 November 2026 an away session was
  disabled, with no window to jump to, its ring dimmed with its words, as
  macOS dims a disabled item's image (accepted, 20 October 2026, of the
  dot it had until 3 November 2026).
- **Every session** the panel has is listed. Past twelve rows the list
  ended with "4 more…", which opened the SitRep window, until the window
  went (5 November 2026).
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
    ("4 need you · as of 12:04"). The notch and the strip keep the last
    board too, marked as stale.
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
  - **Its standard input is `/dev/null`** (5 November 2026), so `watch`
    follows no session and looks on its own cadence (see "Following", under
    `watch`). From 27 October 2026 the app wrote the sessions the SitRep
    window showed there, a follow line to each run as it started and again
    as the set changed, on a pipe written on a queue of its own; that went
    with the window. A run stopped while it waits on Lee's PATH, as SitRep
    starts another on the plugin it settles on, begins nothing once the
    PATH comes, so only the run started in its place runs.
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
    16MB among them); the "as of" is that instant, not the board's own time,
    since `watch` prints only on a change. A line that reads ends it. 16MB
    leaves room enough: 81 sessions made a line of 626KB, and the largest
    board is about 90KB, growing with its Resolved. Every session's parked
    items on the line (4 November 2026) took it from 39KB to 70KB over a
    copy of Lee's board, 28 sessions holding 106 of them. The limit is that
    high because `watch` counts a board as printed once written, so a
    refused line would lose its boards until they next changed.
  - **The first board of a run after another** is a run's first line: its
    `new` is empty, as on any run's first line, though the board may have
    moved while `watch` was down. The app decides no rows of its own, so a row that needed Lee
    and came while `watch` was down gets no swell or flash: accepted.
- **The icon** in the menu bar is the light's glyph (see "The icon"): white
  on a dark menu bar and black on a light one, its bar lit as the notch's
  light is, orange while an ask waits, else blue while Lee's turn does
  (13 November 2026; lit orange for asks alone until then), since the
  notch is on one display and the menu bar on every one. The header carries SitRep's app icon, which never changes.
  Round 4 drew a placeholder, a screen with a bar at its edge and a dot for
  needs you; round 6 replaced it.

This replaces the 13 October plan, a menu slimmed to Settings and quitting
with the plain list of sessions kept as a fallback, and round 4's first
drawing, which left the sessions to a SitRep window.

### The welcome window

What SitRep's first start opens: one window that shows what SitRep does,
sets the first few settings and asks macOS for what it needs. Drawn in
Paper's "Welcome window", boards A to F (28 October 2026), from Lee's
brief: pictures, what it does at a high level, the notch in its forms and
that it moves, an ask answered, the board, the first settings (the notch's
style, the sound, open at login) and the permissions. Lee, 2 November 2026:
"All those designs in paper look really good", once the stage's notch sat
flush with the screen's edge, running up to the menu bar, as the real one
does; the boards first drew it on a band of black.
- **When it opens:** on its own once, at SitRep's first start on a Mac
  where none has closed yet, beside the plugin's first install (step 9 of
  stage 3, under "Stages"), Lee's Mac included, at the build that brings
  it. However it closes, quitting SitRep included, it never opens on its
  own again; a crash or a Force Quit while it shows, which close nothing,
  leave it to open at the next start. The menu's Show Welcome Window opens
  it at its first step at any time.
- **One shape for every step:** a window of SitRep's own, 840 by 540, never
  resized, black, at radius 14, opening centred on the Space Lee is on, as
  About SitRep does. The words sit on the left in a column of 330: a
  headline of two lines at most, one grey paragraph, then the step's
  controls. The rest is **the stage**, a small desktop inset at the right,
  with a menu bar, a Ghostty window and SitRep's edge down its left. A
  footer never moves: a back chevron, six dashes for the steps, the one
  Lee is on long and blue, then Skip setup and Continue ↵, a white pill
  that Return presses. Blue is for the choice and the progress; orange
  stays for needs you, so it appears only on the stage. Paper holds the
  sizes, colours and spacing.
- **The stage is SitRep's own views** at the stage's size, the notch, the
  strip, the panel and its rows, fed a made-up board, never a video, so the
  pictures cannot drift from the app. It loops what its step says, and
  pauses while the window is not in front. Under Reduce motion, the Mac's
  or SitRep's, its states cross-fade.
- **The steps**, each a headline over the words in Paper:
  1. **Hello, from the edge:** "Every session, at the edge of your screen."
     SitRep's icon and a line on what it is; the board's aside, "About a
     minute. Everything here is in Settings later.", went in the build
     (Lee, 3 November 2026: "It's like answering a question that nobody
     asked… Can you remove that line?"). The stage's panel is open on
     Needs you and Working; until 13 November 2026 on Needs you, Your turn
     and Working (Working before Your turn until 4 November 2026), when its
     session at Lee's turn went, as it would light the resting notch blue.
     The loop plays the notch at
     rest, an ask landing, the swell twice and the light, the pour into
     the panel and the close. Continue reads Continue here too; the
     board's "Show me" went in the build, as Lee couldn't tell what it did
     (3 November 2026).
  2. **An ask, from Claude to you:** "Claude asks. You answer." One soft
     loop on the stage, with nothing to press (Lee, 3 November 2026: "I
     don't want it interactive in that way… Soft animation in the
     walkthrough is enough to demonstrate what it does… just keep it
     simple"): an ask lands, the notch swells twice and lights; the
     pointer reaches the notch and the panel pours open on the ask's row;
     a click on the row takes it to the session, the stage's Ghostty
     window coming forward with the ask in it; the ask is answered there,
     a line of the answer under it; then the light goes out, the ask
     leaves, and the loop rests. The panel is the real one's, so it shows
     no answers: answering from the panel is still later (above, "The
     notch and its panel"). Beside the paragraph, three lines name the
     moments, An ask lands, Open it from the notch, Answer it in its
     session, each lit as the loop plays it. The drawn board's three rows,
     its Send a test ask on the real edge and the SitRep window's slide-in
     went with the change. Nothing on this step sounds, sends anything or
     needs macOS's leave. No pointer is drawn, so in both loops, step 1's
     and this one, the only row the stage lights is the ask's (Lee, 3
     November 2026, of working rows lit "as if there's an invisible mouse
     moving up through the card"): the unseen pointer rests at the notch's
     home in the panel's side padding while it pours and steps onto the
     ask's row at once. In step 1's loop it then glides off the row at the
     row's own height, out past the panel's front, so the meniscus closes
     with its tongue; in this one it leaves with the jump, which drains the
     panel. It never crosses another row. On the strip it rests on the
     ask's own mark, where the layout puts it, never a drawn centre still
     sliding, and with no mark yet there is no pointer at all. A restyle of
     the notch, or the other shape chosen, while the loop plays plays it
     again from its start (17 November 2026).
  3. **Your edge:** "Choose what sits at your edge." Notch or Strip as
     Settings' own pictures, at the window's size, the one chosen ringed in
     the accent; under them a grouped form in System Settings' rows: Style,
     Meniscus or Card; Material, Black or Glass (from macOS 26, as in
     Settings); and Edge, Left or Right. At Strip, Length, Grows or Full,
     takes Style's place in a cross-fade, one row for another, so the form
     keeps its height and holds only what applies. Settings' Edge pane
     changes at once instead, as its height changes with it (Lee found its
     motion jarring). Under the form, a quiet text button, Show nothing
     at the edge, sets Show to Nothing (Lee, 3 November 2026: "I think I
     should be able to say nothing"): neither tile is ringed, the rows
     stay but dim, the line "Only the menu bar's light. Choose Notch or
     Strip to bring it back." takes the button's place, and the stage
     shows no edge from here on, step 4's chime lighting its menu bar
     item instead; steps 1 and 2 still show the notch, which they teach.
     The drawn boards left Nothing to Settings. Each press sets the setting
     itself, so the stage and the real edge, at full size beside the
     window, move at once. The stage's notch is lit, as for needs you,
     since at rest it is 7 points of black a first look would miss.
  4. **Its sound, and its start:** "Hear it when Claude needs you." A list
     of macOS's alert sounds, Glass first and chosen, four shown and the
     rest a scroll away, and No sound last, after a hairline, which turns
     off Settings' Play a sound for a new ask. A click on a row plays it
     once and swells the stage's notch with it, so the sound and the light
     are learnt together. Arriving plays nothing, and closing the window
     stops a sound. Then Open SitRep at login, a switch, on by default, as
     SitRep is only of use while it runs. Its line, "macOS confirms it
     with a notice", warns of the one surprise, and the stage shows
     "Background Items Added" as it will come. Sound and start share a
     step, keeping the welcome at six.
  5. **What it asks of macOS:** "Two things to allow, both optional."
     Asked last, once Lee has seen what each is for, each row's reason one
     clause about something he watched. Notifications turns on Notify me
     of a new ask, off by default as in Settings, and asks macOS through
     the notices helper; the stage shows the banner as it will come.
     Control Ghostty is the jump's leave. macOS asks for it only while
     Ghostty runs, so where it isn't running Allow… opens it first. A row
     has four states: to ask, a button named for what it does, Turn On…
     or Allow…, never dressed as macOS's own dialog; asking, a spinner,
     and after ten seconds a line saying where macOS put its prompt; on, a
     green check; refused, Open System Settings…, for Notifications or
     Privacy & Security › Automation. They are read again each time the
     window comes forward. Neither holds Continue back, and both stay in
     Settings.
  6. **Ready, and what's left:** "You're set. One thing in Claude Code."
     `/reload-plugins` first, in Geist Mono with a Copy button, since a
     Claude Code window already open keeps the mod it loaded until then;
     new windows need nothing. Then Lee's choices played back in four
     rows, in what-happens words, not settings' names: At the edge, A new
     ask, At login, A click, each with its fix in place where something was
     left off, as Allow… for Ghostty. Skip setup goes, with nothing left
     to skip, and Continue reads Done. **Done closes the window**, and the
     real notch, at rest, shows the stage's callout beside it once, "Your
     notch. Point at it." over "It lights up when a session needs you";
     the first hover takes it away for good. The strip, if chosen, shows
     it as the notch would.
- **Leaving early:** Skip setup, ⌘W or the close button keep what Lee set
  and the defaults for the rest: the notch on the left, Meniscus, Black,
  Glass, and open at login, macOS's notice with it. Nothing is asked of
  macOS.
- **Borrowed**, from Lee's saved references and what was looked at:
  Dockset's one window with a live picture leading each step, its
  dependent rows swapped in place, and its constant footer (the dex, 17
  September 2026); One's choices previewed on a stage as they are made (7
  October 2026); Ice's and Wispr Flow's permissions asked last, each with
  its reason, never blocking; and Linear's closing playback.
- **Settled in the build** (its first PR, 2 November 2026):
  - **The stage's edge** runs SitRep's own run and surfaces on a made-up
    screen of the stage's, drawn by the same call as the real edge's, so
    it cannot drift from it. It is at 0.7 of its size on step 1, where the
    panel needs the room, and at its real size on steps 3, 4 and 6, where
    the notch is the subject. It sleeps while nothing on it moves, stops
    while the window is behind, and still draws a setting changed then.
  - **Placeholders, never Lee's projects:** every sample says what goes
    there, "The ask, in Claude's words" over "Project · Session", in a
    terminal titled "project · claude", and Settings' Notifications preview
    takes the same words, from one place (Lee, 2 November 2026: "use
    placeholders to indicate what the notification will show, not real
    projects of mine"). The boards in Paper were changed to match.
  - **The login item** is the switch, as General's is. The first welcome
    registers SitRep as Lee reaches step 4, or as the window closes if he
    never does, quitting SitRep included; it never registers one already
    on or waiting on his approval, and a press makes it his. A welcome
    opened again changes nothing until pressed, and promises macOS's
    notice only while one is still to come. Show Welcome Window while the
    window shows goes back to the first step and keeps the visit.
  - **Step 6 when the plugin's first install failed:** Settings' words for
    the plugin's row, in place of `/reload-plugins`.
  - **The playback where nothing is set:** "Silent", for a new ask with
    neither sound nor notification; "Doesn't open SitRep", with Turn On;
    "Waits for your approval", with Login Items Settings…; and "The menu
    bar's light alone", for Show at Nothing.
- **Settled in the build** (its second PR, 3 November 2026):
  - **The callout** stands 14 points past the shape's resting front,
    level with the notch's home, for the notch and the strip alike, as the
    stage shows it; it is placed from where the shape rests, never from a
    frame still moving, and placed again as the notch lights or goes dark.
    Due while no shape shows (Show at Nothing, or a full-screen app), it
    waits for one. It never takes a click, and only while it is due does
    the edge tell it of a hover.
  - **Quitting:** a SIGTERM, as `app/quit` sends, quits SitRep as Quit
    SitRep does, so the welcome closes as its close button would, and is
    done with. A SitRep stuck past three seconds of that, or sent a second
    SIGTERM, ends anyway, so `app/quit` can always stop it.
  - **Step 5's rows when macOS can't answer:** Ghostty not installed, the
    row says so and offers nothing until it is installed; Ghostty not
    opening, or not answering once open, a line says so and Allow… stays.
    Turn On… keeps asking while macOS's prompt is up, however long Lee
    leaves it, and says so only when the notices helper gives no answer.
    Step 6's A click shows the same states, a spinner while it asks.
    "Open System Settings…" for Notifications also turns on Notify me of
    a new ask; while macOS refuses, A new ask's playback promises no
    notification and carries that fix.
  - **Step 6's A click** with the leave: "Opens the session's window".
- **Settled in the build** (Lee's notes on the live welcome, 3 November
  2026):
  - **Keyboard focus** rests on nothing as the window opens, as in the
    Mac's own setup assistants, and Return presses Continue. Lee: "I don't
    like that 'skip setup' is focused by default, and that I don't seem to
    be able to change that focus. That's odd Mac behaviour." Nothing is the
    window itself as first responder: put there as it orders in, and again
    whenever it keys having opened or gone behind on nothing, since AppKit,
    keying a window, may give focus to a control (4 November 2026). Live,
    with the window's content as first responder, SwiftUI gave its own focus
    to its first control at once, Skip setup at step 1, key window or not,
    and drew its ring as the window keyed; accessibility named only the
    content as focused throughout, so only a capture tells. The window made
    once and reused also carried a visit's focus into the next open, after
    its close button, so each open makes the window afresh: centred again,
    its stage's loop from the start. Tab from nothing rings Skip setup, then
    Continue; Tab and Shift-Tab go through the step's controls in reading
    order, the footer last; where the control holding focus goes with its
    step, focus goes back to nothing. The key view loop is worked out again
    after each layout of the window's content, as SwiftUI's buttons join and
    leave it unseen by AppKit, which left Tab on a step gone (offscreen, 3
    November 2026). Brought forward while open, or keyed again after going
    behind, the window keeps focus Lee gave, while its control stays.
    Left: ⌘-Tab away and back with focus on nothing still rings Skip setup
    live, though the window is put back as first responder as it keys
    (Lee's try, 4 November 2026); "good enough", and parked. Continue's
    focus ring is a pill and back's a circle.
  - **The stage's menu bar item** is lit while the stage's board has an
    ask, as the real glyph lights for needs you, and on step 4 each chime
    lights it for as long as the notch swells, whatever the shape. So at
    Nothing it rests as step 4 opens, lights for every sound chosen, and
    rests on step 6, where the board is calm.
  - **Done at Nothing** leaves the real callout unarmed: someone who chose
    to show nothing at the edge never meets "Your notch. Point at it."
    weeks later, the day they pick a shape. A callout armed by an earlier
    Done still waits for a shape, as above.

### Settings

Settings is a window of its own, laid out as Xcode 27's Settings, drawn in
Paper's "Settings window", boards A to D, from Lee's screenshots of Xcode
27 (27 October 2026: "I wonder if we could make our settings like this. In
hindsight, do you think maybe it was a mistake to build settings into the
window, and that they should have been two separate things?"); Lee approved
the boards as drawn on 2 November 2026. It replaces round 7's page of the
SitRep window (Paper's "Settings in the window", 21 October 2026), which had
replaced round 5's window of three panes (Paper's "Settings", 17 October
2026). A Mac app's Settings is a window of its own that ⌘, opens; a setting
is often changed while watching the edge, with no need for the board; and
Settings had grown past what one page of the board's window held well. The
rows inside are rounds 8 and 9's, as Lee approved them: only where they
live changed, and how they group.
- **Where it opens:** the menu's Settings…, and ⌘, while any of SitRep's
  windows is key.
  There is one: opening it again brings it forward. It opens centred in the
  upper part of the screen on the Space Lee is on, and otherwise stays on
  its own Space, as About SitRep does; ⌘W or its close button shuts it. It
  opens on the pane it last showed, General the first time.
- **Xcode 27's frame** (Paper's boards A to D): 820 by 620 to start, and
  resizable. A sidebar floats 8 in from the window's edges, 180 wide, with
  the traffic lights on it, listing the five panes as rows 32 tall, each
  with its symbol, General's gear, Edge's screen with the notch at its
  side, Notifications' bell, Snooze's moon with its z's and Claude Code's
  terminal. The pane shown is the accent while the window is key and the
  system's grey when not. The toolbar holds back and forward in one
  capsule, which step through the
  panes shown, as ⌘[ and ⌘] do while it is key, the app's Go menu's, as
  System Settings' do; and the pane's name beside it, 15 bold. A pane is
  sections:
  each a header, 13 semibold in the label colour, 10 in from its card's
  edge and 10 over it, then its card; the sections 26 apart, in a column
  from 20 past the sidebar to 20 from the window's right, with no cap. A
  pane longer than the window scrolls under the toolbar, with the system's
  scroll edge; a short one leaves the rest of the window empty, as Xcode's
  do. The window's colours are the system's: Paper drew them as Lee's
  screenshots show them on his Mac, the window #292D3A, the sidebar
  #252831, a card #323541, the accent #2E70D4, not the card's black. The
  window has a least size at which every row's control keeps its place
  beside its words.
- **Its rows:** cards at radius 12, as Xcode's, split by the system's
  separator, a pixel of the screen it is laid out on, half a point at 2×
  and a whole one at 1×, where half a point rounded to none under every
  other row of 52 (17 November 2026), 10 in from both ends, one box deep:
  rows of SitRep's own at the form's metrics, not SwiftUI's grouped Form, whose
  sections draw their own fill and insets, scroll on their own and draw
  nothing as a still. A row's label is 13, its line under it 11 in the
  secondary colour; a row is at least 52 tall with a line, 38 without, its
  words and its control 10 in from the card's edges, and a line wraps,
  growing the row, before its control gives up any width. The controls are
  the system's, never redrawn, each at the regular size and its own width
  against the card's right: segmented controls, their segments equal, as
  SwiftUI's picker sets them (Meniscus · Card is 155, where Paper drew 156:
  its widths were Inter's, and the control's are SF's); a pop-up as wide as
  its widest choice, as every Mac pop-up is; bordered push buttons; and the
  mini switch, 36 by 16, as the HIG gives a grouped form. Orange stays for
  needs you, so it appears only inside the pictures and the glyph. The
  panes, top to bottom in the sidebar: General, Edge, Notifications, Snooze
  (17 November 2026) and Claude Code.
- **Edge**, round 9's What stays on screen, named in the sidebar for
  where it all goes, opens on a card of its own, the **Show row**, set as
  Xcode's Appearance pane opens on its own and as System
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
- **The rows under Show** are the ones that apply to the choice, in a
  section named for it, Notch or Strip, so its header says what they tune,
  then Reduce motion in a section of its own, Motion, as it is about how
  SitRep moves whichever shape is at the edge. They change at once, always,
  with no motion: as the choice changes, or Length with Max, the section's
  name and rows change and the pane takes its new height in the frame the
  pictures change in (Lee, 22 October 2026, of the system's transition
  there: "the animation on the panel when switching the notch mode is a bit
  jarring"):
  - **Notch:** Edge, Left or Right ("or drag it across the middle");
    Display, the main one unless another is chosen; Style, Meniscus or Card
    ("Meniscus pours, Card slides"); Material. Then Motion.
  - **Strip:** Edge; Display; Length, Grows or Full ("grows with what's on
    it, or runs the screen's height"); Max, only at Grows, a slider 160
    wide whose right end is Full ("how long it grows"); Material. Then
    Motion.
  - **Nothing:** neither section; the pane is the Show row's card alone,
    and Show has a line under it, as a row's line is set, saying the menu
    carries the board. Under the notch or the strip,
    Show has no line.

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
  it, its caption and Send Test, a push button, which sends a sample, "Test
  notification", "This is what SitRep's notifications look like", naming no
  session, so its click jumps nowhere and hands the front back (Lee, 26
  October 2026: a test of a real project's took him to its session, which a
  test should not). Then three sections, each setting a new ask and Lee's
  turn apart (13 November 2026, Lee), the ask's rows first. **Banners:**
  Notify me of a new ask, off by default, its line "Silent; a click on it
  jumps to the session"; Notify me when Claude stops, off by default, its
  line the same; and
  macOS's own answer, "Allowed by macOS, as banners", with Notification
  Settings… for SitRep's page in System Settings: the notices helper's,
  which macOS lists as SitRep (see "The menu bar"). Each is read, asked
  and sent through the helper. **Sound:** Play a sound for a new ask, a switch,
  on by default, its line "Once, whichever session it lands in"; and Sound,
  a pop-up of macOS's alert sounds by name, read from `/System/Library/Sounds`
  (Basso … Tink), Glass by default, the chime the windows played. Choosing
  one plays it once, as System Settings › Sound does; it greys while the
  switch is off. The sound is SitRep's since 27 October 2026, moved from
  each window's mod (Lee: "It should be in the notification section, and it
  should be toggleable. It might get annoying, and you might want to turn it
  off. Also, you should be able to pick from a list of different sounds,
  with the current one being the default."). It plays once for an ask that
  lands or comes back from snooze, whichever session it lands in, whatever
  shows at the edge, Nothing included, and whether or not banners are on,
  which are silent. It plays as an ordinary sound, at the output volume,
  never as a notification's or an alert sound, which follow the alert
  volume. Under them, since 13 November 2026, Play a sound when Claude
  stops, off by default, its line "Once, as a session's turn ends", and its
  own Sound, Tink by default, so the two are told apart by ear; it greys
  as the ask's does. A board that brings both plays the ask's alone.
  **Notch:** Pulse for a new ask, on by default, "It swells and its light
  flashes", as it always had; and Pulse when Claude stops, off by default,
  "It swells as a session's turn ends" (see "The notch and its panel").
  The strip follows each, an arriving mark flashing only while its pulse
  is on (14 November 2026; see "The strip").
  Lee's turn is all off by default: Lee wants no sound for it, and the
  steady blue light shows it already. The turn's three labels said "when
  it's my turn" until later on 13 November 2026, when the app named the
  blue rows Stopped (see "The rows"); their lines, which speak of
  Claude's turn ending, stayed.

  **What fires for Lee's turn** (13 November 2026): its notification, its
  sound and its pulse fire once, as Claude ends a turn: a session at his
  turn on a line of `watch`, which the line before showed working or on
  its own work, from a turn that ended later than any it has stood at his
  turn from. A move into his turn from anywhere else never fires: from
  needing him, as when Claude asked and ended its turn as one and Lee
  snoozes the ask or answers it from another window, the turn long
  ended; from his turn itself, as when a window joins a session there, a
  resume or a second Claude, which restarts its turn's time; or from off
  the rows, a snooze woken or a session new to them. Nor does it fire
  again for a turn flickered out of and back to, nor for sessions at his
  turn as SitRep starts, nor on any run's first line, as a new ask's do
  not (`LastBoard.newTurns`; until a review the same day, a move from
  needing him or from an earlier turn fired too, which fired for an ask
  Lee had snoozed and for a joining window). Its notification says
  "Stopped" ("Your turn" until later on 13 November 2026; see "The rows"),
  its project and session, then what Claude left Lee, and its click
  carries the session on, as an ask's does. The saved settings keep their
  meaning:
  `notifiesNewAsks`, `playsSound` and `sound` are a new ask's still, and
  his turn's are keys of their own, `notifiesTurns`, `playsTurnSound`,
  `turnSound` and `pulsesTurns`, beside the ask's `pulsesNewAsks`.
- **Snooze** (17 November 2026; see "Lee sets the times", under
  "Snooze"): one section, **Choices**, a card of six rows, one for each of
  Snooze's choices in their order, each its name, a line under it saying
  when it wakes, and against the card's right its controls, then its
  switch. While the switch is off its controls grey, as Sound greys with
  its switch, and the row's words stay. In an hour has the switch alone,
  "One hour from when you snooze"; Later today a pop-up of 1, 2, 3 or 4
  hours, "This many hours from when you snooze"; Tonight the time, "At
  this time today; not offered once it has passed"; Tomorrow the time, "At
  this time tomorrow"; This weekend a pop-up, Saturday or Sunday, and the
  time, "On this day this week; not offered once it has passed"; Next week
  a pop-up of the weekdays, Monday first, and the time, "On this day next
  week". Each pop-up at its own width, as every Mac pop-up is, so This
  weekend's two days stand narrower than Next week's seven. A time is the
  system's time field with its stepper, its hour and minute in the Mac's
  own clock, 12-hour or 24, given 6 more than AppKit's own width, where its
  last digit ran into its edge. Each choice keeps its controls in its own
  row, on purpose, where Notifications gives a sound's pop-up a row of its
  own under its switch: a row for each choice's switch and one for its
  times would make 12, twice the card for the same six choices. Under the
  card, its caption: "SitRep's Snooze menus and the pane in Claude Code
  offer these. The menus also offer Until it moves.", the menus the
  card's and the strip's. Saved under "snooze" in the app's defaults, and
  written to `snooze.json` (see "Storage") as it changes. Not yet drawn in
  Paper.
- **General**: Startup, Terminal and Resume command, as stage 8's
  rethink regroups it (13 November 2026; built in the PR after it). Until
  then Startup, Ghostty and, since 10 November 2026, New windows (below).
  **Startup:** Open at login, its line "SitRep is only of use while it
  runs". Until 4 November 2026 a section between Startup and Ghostty,
  **Sessions**, held "Your turn folds after", "Older ones fold into one
  line, which opens in place", a pop-up of An hour, the default, Four
  hours, Today or Never: how long a your-turn row stayed on the card
  before it folded into "N earlier", saved under "app" as `foldsAfter`
  (22 October 2026). It went with the
  card's "N earlier" (board J2; see "The sections"): a value saved for it
  is read and passed over, as the separate Settings window's `pane` is,
  and is not written again.
  **Terminal** (13 November 2026), one card: Terminal, a pop-up of the
  terminals SitRep has a driver for, Ghostty alone, saved under "app" as
  `terminal` (its `$TERM_PROGRAM`, `ghostty`); beneath it, in the same
  card, as it follows from the choice, the leave to control Ghostty,
  worded as macOS words a permission, by what SitRep can do with it:
  "Bring a session's Ghostty window to the front", "So a click on a
  session jumps to it". The heading New windows goes.
  **Resume command** (13 November 2026), a section of its own, not grouped
  with the terminal: one row, Command, its field pre-filled with the
  default, `cd {dir} && claude --resume {claude}`, its text monospaced at
  the label's 13, kept exactly as typed (macOS's smart quotes, smart
  dashes, text replacement and spelling correction off in it), the label
  and the command on one line of text, the field 360 wide where the column
  has room and giving way before the label at the window's least width,
  so the row keeps its 38. Under the card, its caption, with Restore
  Default on its right, as Send Test and Copy sit by theirs, enabled while
  the field differs from the default: "Clicking a session this Mac doesn't
  show opens a new window and types this command into your login shell.
  {claude} is its Claude Code session id, {dir} the folder it ran in,
  and {tty} the terminal that Claude still runs on, empty unless it does.
  Each is replaced with a quoted value. It takes plain shell syntax only:
  anything more goes in a script." Saved as typed, under a key of
  its own (see stage 8's plan): the open command saved as `openCommand` is
  read and passed over, and a resume command never set reads as the
  default. A command that can't run says why under the label and the
  field, in a row's line, as each key is typed: the refusal a click gives,
  its subject "The command", naming no session, each part it sets in
  backticks shown monospaced between typographic quotes, as "The command uses
  `(`, which SitRep can't check. …"; an empty one, "The command is
  empty." (20 November 2026, as the terminal phase's review found a
  refused command said nothing until a click, and nothing at all with
  SitRep's banners off). Not yet drawn in Paper.
  As it stood until 13 November 2026: **Ghostty**, the leave alone in a
  section of its own; **New windows** (stage 7, C): how a window is
  opened for a session no window shows. Terminal, the pop-up; and Open
  command, the field above, empty until Lee gave one. Under the card,
  "Clicking a session that isn't showing in a terminal opens a new window
  and runs this command. {session}, {socket} and {pane} are replaced with
  quoted values." (until 12 November 2026). Saved as `openCommand`. Under
  it, since stage 8 (12 November 2026), Resume command, the same literal
  field, empty until Lee gave one, saved as `resumeCommand`: what a window
  opened for an away session ran where nothing was left of its last
  window. The caption then said what each was for: "Clicking a session
  that isn't showing in a terminal opens a new window. The open command
  attaches to a session still running, with {session}, {socket} and
  {pane}. The resume command starts Claude again where nothing is left,
  with {claude}, its session id, and {dir}, the folder it ran in. Each is
  replaced with a quoted value." No row carries an icon. General has no
  update rows: Homebrew updates the app (18 November 2026).
- **Claude Code**, the plugin's pane. **Plugin:** the Claude Code plugin,
  "Puts each Claude Code session on the board", up to date; with every
  window current, that row is the pane. The plugin's folder and its version
  are not in it: the version is About SitRep's. **Needs /reload-plugins**,
  only while some Claude Code windows run an older plugin than SitRep's:
  each such window a row, its session over its project and the version it
  runs ("SitRep · 0.3.0"), with Show, a push button that jumps to it as the
  menu's item for it does; under the card, "Type /reload-plugins in each; a
  new window needs nothing", the command in the monospaced face, with Copy,
  since SitRep cannot reload a window. A window leaves the list as it
  reloads, and the last takes the section with it. While any is behind,
  the pane's row in the sidebar carries their number on its right, as
  System Settings counts its updates, so the window points here from any
  pane. Round 8 listed them in Show Windows, a pull-down on the plugin's
  row.
- **A dot when it's fine, a button when it's yours.** Each row says its state
  where its control goes. All well, that is a green dot, 7, and a word, Up
  to date or Allowed, in the secondary colour, with nothing to press. When
  something wants Lee, the words move into the row's 11-point line and say
  what is wrong, and a push button at its own width takes him to the fix,
  its ellipsis saying it opens somewhere else. No blue
  words and no ↗: blue is left to the switches, the menu's highlight and
  the chosen picture.
  - **Windows on an older plugin:** "Updated to 0.3.1. 3 windows run 0.3.0
    until /reload-plugins", with no control of its own: the windows are
    the rows of Needs /reload-plugins under it. Once every window runs the
    new one, the row is up to date again.
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
    Settings…. Notify me when Claude stops greys the same, "the notch
    lights blue instead". Each says the notch swells only while its own
    pulse is on, "the notch lights instead" with Pulse for a new ask off,
    "the notch swells and lights blue instead" with Pulse when Claude
    stops on (13 November 2026).
  - **Waiting on Lee's approval to open at login:** the switch gives way to
    Login Items Settings….

  What macOS says is read as a pane comes into sight while the Settings
  window is key: each time the window comes forward on it, as Lee may have
  changed it in System Settings, and as Lee turns to it. About SitRep, or
  any other window, coming forward reads nothing.
- **How the notch moves is not a setting.** It ships fixed (see "The app
  ships these values fixed", under "The notch and its panel"). A first
  drawing had a Feel pane with the prototype's dials; Lee took it out.
- **Borrowed:** Xcode 27's Settings for the frame, the sidebar and the
  sections, from Lee's screenshots; and from Lee's saved references,
  Dockset's native controls in a styled frame, a live picture leading each
  step, and leaves named by what they give.

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
  licences, no update button, as Homebrew updates the app. Only its
  close button is live, and it or ⌘W shuts it. It opens centred, in the
  upper part of the screen, on the Space Lee is on, and otherwise stays on
  its own, as Settings does.
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
October 2026 (stage 3, step 5). The jump stayed in the CLI, in TypeScript,
until stage 7 moved it into SitRep, in two layers (each `cli/` file named
in this section went in step B, 10 November 2026):
- **a driver per terminal app**, Ghostty's the one built (`cli/ghostty.ts`:
  steps 3 and 4, every behaviour as it was): it recognises its windows, by
  the `$TERM_PROGRAM` in the heartbeat's `where` outside tmux and by its
  program among the tmux client's ancestors under it, finds the window on a
  device, and brings it forward;
- **one tmux layer**, shared by every driver (`cli/tmux.ts`): which clients
  show a pane, and selecting the pane's tmux window where none does (step
  2). So tmux or not works for any terminal.

**Two axes, and one step between them** (9 November 2026, as Lee moved
from tmux to zmx). The tmux layer became the first of the **multiplexer
adapters** (`cli/multiplexer.ts`): each has one job, given the session a
window recorded, to list the client processes showing it, and, for tmux,
the select that makes a client show the pane. tmux's is in `cli/tmux.ts`,
zmx's in `cli/zmx.ts`. The **terminal drivers** are the other axis, as
before: each brings forward the window on a device, Ghostty's the one
built, and an app with no driver is brought forward whole. Between them
every client of every multiplexer goes through **one step, its seat**
(`seatOf`, `cli/processes.ts`): its ancestry walked to the nearest terminal
app, the app its place is in, and the device of that app's own child, the
terminal's pty, the device its driver is asked for (step 2). A window in no
multiplexer stays as it was: Claude's own device and `$TERM_PROGRAM`.
Another multiplexer, screen or Zellij, is one more adapter, beside what
every window records of where it is: zmx also needed its field in `Where`,
`$ZMX_SESSION` read as the window attaches, and its line in `watch`'s
windows. Another terminal is one more driver: Terminal and iTerm2, both of
which give each tab's tty by AppleScript, stay parked.

**A window in two multiplexers**, one run inside the other, is in the
innermost (9 November 2026, from review): a multiplexer passes its
variables on to what runs in it, tmux started in a zmx session keeping
`$ZMX_SESSION` and zmx started in a tmux pane `$TMUX` and `$TMUX_PANE`, so
the outer one's names a session the window is not on, and a jump could
select a tmux window for nothing. The innermost is the one whose own pty
is the window's device: tmux tells its pane's (`#{pane_tty}`, in the same
`list-panes`), zmx none without a further program. So tmux is innermost
where its pane is on the window's device, else zmx is; where tmux cannot
tell, its pane gone or its server silent, both are asked, tmux first. Moot
on Lee's Mac, which runs zmx alone.

A driver declares what it can do beyond bringing a window forward, which
every driver must: select a tab or a split, and show a session's state, in a
tab's title or by OSC 7501. They are declared in the driver's shape and
built for none: Ghostty's declares none yet. A terminal with no driver still
has its sessions shown, and a click on one brings that terminal app forward
(step 2). Other drivers, and Ghostty's tabs and splits, stay parked, and the
shape allows them. A jump made in Swift, in the app, was parked too, until
Lee decided on 9 November 2026 that the jump and on screen move into SitRep
(stage 7; see "The structure"). **SitRep makes its own jump since then**
(A3, below), at parity with the CLI's, and runs `sitrep jump` no more,
which step B retired from the CLI on 10 November 2026, with `sitrep
screen`. Steps 1 to 4, after "SitRep's own jump", are the jump as the CLI
made it, written as it stood then: the spec SitRep's was built to, and the
record; "SitRep's own jump", next, says where SitRep's goes another way.
Only step 1, the mod recording where its window is, is the plugin's still.

**SitRep's own jump** (9 November 2026, stage 7, A3). `Jump`, in
`SitRepScreen`, beside the screen's reading it starts from:
- **A session no terminal shows that a multiplexer holds** has a window
  opened for it, where the jump refused it as not on screen, since 10
  November 2026 (stage 7, C, under "Stages"). Since stage 8's rethink (13
  November 2026) a session no terminal on this Mac shows, held or away,
  runs the resume command instead, and the jump, unchanged, goes only to a
  session here, or to a Claude suspended where this Mac shows it.
- **From the watch's last line**, never the board's files: the session's
  windows that say where they are, in core's order (`jumpOrder`, never
  their place in the line); from a watch older than the order, whose
  windows carry none, every one saying where it is, in the line's order.
  The session is named by its row, its Snoozed row, a window, or, with
  none of those, its project's list on the line (`projects`, read for the
  names alone and in any shape or none), as the CLI named it by its
  status.
- **One rule for the board** (`JumpBoard`): a jump reads the line of a
  watch that is running and has printed. While the watch starts, starts
  again or is stale, as from a banner clicked as SitRep starts, the jump
  waits for its next line, within its 15 seconds. It is refused in the
  watch's words only once they run out, "SitRep can't read the board:"
  and why, as the views say it, or "SitRep has no board yet: sitrep watch
  has printed none."; never as the Mac too busy, which is for a jump that
  had its board. With no plugin to run the watch, it is refused at once in
  the plugin's words, until a plugin is found and its watch starts, when a
  jump waits as at any start.
- **Lee's PATH**, for tmux, is asked for once the board is in hand, within
  the jump's limit, so a later click ends that wait as any other.
- **Off the main thread, one step after another**: the front and the
  screen read together, then each place's select and bringing forward in
  turn. A jump stopped, by a later click (`OneJump`) or its limit, is
  cancelled, and ends between its steps: tmux, run as its child, is killed
  with its group; an Apple Event in flight is let go, not recalled, and the
  next jump does not wait on it. Ghostty handles events in the order sent,
  so a later click's land after it.
- **Ghostty asked by Apple Events built by hand** (`GhosttyEvents`), as
  AppleScript built the CLI's program, never `NSAppleScript` or osascript:
  each a Get Data or a Ghostty command, its codes from Ghostty's dictionary
  (`sdef`, 1.4.0: `Gtrm`, `Gtty`, `Gwnd`, `Gtab`, `GTsl`, `Ghst` `Fcus` and
  `AcWn`), sent to the Ghostty `NSRunningApplication` finds running, by its
  process, so none launches it, on a thread of its own, each waiting 5
  seconds at most. The questions are the program's: the terminals on the
  device; whether the tab holding it is selected; for one not selected, the
  window holding it, then `activate window` on the window Ghostty named,
  where the program asked `first window whose …` in one event; the half
  second's pause; then `focus` on the terminal the lookup named. Each is
  sent by `AESendMessage`, waiting for its reply, as `sendEvent` sends it,
  for the reply it keeps whatever the send's status: `sendEvent`, failing,
  gives no reply, and its error has no documented field for the words
  Ghostty gave, so an error of Ghostty's is read from its reply (`errn`,
  `errs`), words and all, and the Apple Event Manager's own from the
  status. Every code a specifier carries is four bytes, as AppleScript
  sends it: `kAEAll`, the `every` ordinal, imports into Swift as an
  eight-byte `Int`, and is sent as an `OSType`.
- **The front heard, not polled** (`KeptInFront`): the app in front as the
  jump begins is NSWorkspace's `frontmostApplication`; each app coming to
  the front is heard (`didActivateApplicationNotification`) from before the
  lookup, so a hand-back between a window activated and its terminal
  focused, which the CLI's watch could miss, is heard too; and Ghostty is
  brought forward again where another app is heard in front after it within
  the second after the focus, once, through LaunchServices
  (`NSWorkspace.openApplication`, as `open -b`), once found running.
- **An app with no driver** is brought forward whole through
  LaunchServices, once found running: by its bundle id, the first of those
  given that runs; by its bundle's path among the running apps, where the
  CLI took the client's ancestry as proof it ran.
- **The limits**: 2 seconds for each tmux run and each bringing forward, 5
  for each Apple Event, 15 for the whole jump, its wait for a board and for
  Lee's PATH among it. osascript's 8 seconds went with osascript, and with
  them exit 3: a jump unanswered now is one at SitRep's own limit, its
  board in hand.
- **The words** are the CLI's, but where the CLI's no longer fit:
  - the process table giving no answer is "the process table", where it
    was `ps`;
  - macOS refusing control of Ghostty is "Not authorized to send Apple
    events to Ghostty. (-1743)", osascript's sentence without its prefix;
    any other error Ghostty gives is "Ghostty got an error: <its words>
    (<its number>)";
  - Ghostty not answering, and a Ghostty too old, name SitRep where the
    CLI's named sitrep: "… or macOS is asking whether SitRep may control
    Ghostty.", "… so SitRep cannot jump to one: …";
  - a session not on the board, as one finished since its banner, is "There
    is no such session on the board, in any project.", the CLI's exit 2
    but for its id, which Lee never sees; the CLI, reading every session's
    files, named a finished one by its status and refused it as not on
    screen;
  - a jump that ran out of time waiting for a board says the board is not
    there (above), which the CLI, reading the files, never waited for.
- **A Ghostty too old** is still told apart, but by other errors:
  AppleScript's -2753 and -2741 came from compiling and running the
  program, and an event built by hand gets neither. The lookup, the first
  event, failing with -1708 (no handler takes Get Data, a Ghostty with no
  scripting at all) or -1728 (no specifier naming a terminal's `tty`
  resolves, a Ghostty before 1.4) is the refusal for a Ghostty too old; a
  later event's -1728 is a terminal gone since it was found, in Ghostty's
  words. Both codes are expected from Cocoa scripting, not yet seen:
  `LiveEventsTests` (`SITREP_LIVE_EVENTS=1`) sends the lookup to
  Calculator and TextEdit, and must find each read as too old. Should an
  app answer the lookup with no terminal and no error, a Ghostty before 1.4
  would be refused as no window answering, not as too old.

1. Each Claude window records, in its heartbeat, the terminal device it is
   on, the terminal program (`$TERM_PROGRAM`), its tmux socket and pane
   when it runs in tmux, and its zmx session (`$ZMX_SESSION`, whole, spaces
   and `·` kept) when it runs in zmx (9 November 2026), worked out once as
   it attaches. A process Claude Code starts has no terminal of its own
   (`ps` gives `??`, live), so the mod runs a small shell walk up the
   processes from there to the first with one, which is Claude Code's. A
   walk that finds none leaves the device out and says so in the debug log;
   the window attaches all the same.
2. A click finds the places that can show the session, each a terminal app of
   this Mac and the device of its window, the session's windows in turn: the
   one that needs Lee first, else the one active last (below). Outside a
   multiplexer it is Claude's own device, when its `$TERM_PROGRAM` names an
   app sitrep knows;
   an app with no driver is brought forward whole, so a window in one counts
   without knowing its device. With tmux it is each client tmux lists whose
   current window is the pane's window and which descends from a terminal app
   of this Mac, each device once; where no such client shows it, each such
   client attached to a tmux session holding the pane's window, which a select
   will make show it (below). `list-panes -a` gives each pane's window and
   tmux session, a pane once for each session its window is in, and
   `list-clients` each client's current window and session, all by tmux's ids;
   a window keeps its id in every session. Every tmux the CLI runs is told
   its client takes UTF-8 (`tmux -u`): run as SitRep runs it, with no UTF-8
   locale and no `$TMUX`, a tmux 3.8 server writes each tab of a `-F` format
   as `_`, and every session read as off screen, so no jump from the app went
   anywhere (live, 22 October 2026, the first restart after brew's tmux 3.8).
   Every program the CLI ran got a UTF-8 character type
   (`LC_CTYPE=UTF-8`) where the CLI was started with no locale at all, as
   SitRep starts it (`cli/locale.ts`, 5 November 2026, until step B left
   the CLI no program to run): with none, `ps`
   mangles a path that isn't ASCII, so an app at `Café.app` was named
   `CafM-CM-)` and a jump could not bring it forward (checked live). A locale
   Lee set is left as it is, so a CLI started with a locale that is not
   UTF-8 (`LANG=C`) has `ps` print a zmx session's `·` as `M-BM-7`, and
   every session whose name holds one reads off screen; SitRep starts it
   with none, and Lee's shells name a UTF-8 one.
   One `ps` snapshot settles each
   client's app, the nearest app among its ancestors: a Ghostty window's
   client runs `tmux < zsh < login < ghostty`, a phone's or iPad's `tmux < zsh
   < mosh-server`, one over ssh from another Mac `sshd` (all checked live, 13
   October; the terminal's name, `xterm-ghostty`, would count the ssh one
   too), and neither of the last two descends from an app. tmux and `ps` each
   get 2 seconds; one that cannot start, fails or does not answer shows
   nothing, so nothing hangs over them. Lee's tmux sessions were one window
   each, so for Lee every attached Ghostty window showed its pane already. A
   jump that could not tell, tmux or `ps` giving no answer in time, says so
   rather than calling the session off screen. A missing tmux is one that
   cannot start: its sockets' windows are unknown, never off, as a tmux
   server outlives its program being removed; a window in zmx or in none
   never runs tmux, so tmux missing never touches it (checked 9 November
   2026, tmux no longer installed on Lee's Mac). tmux exiting with an error
   answers no server only where its own words say none runs on the socket:
   `no server running on`, a socket refusing, a stale file nothing listens
   on, or `error connecting to` it with `(No such file or directory)`, no
   socket at all, as tmux's client words them. Its words are the last line
   it writes, as a wrapper or the loader may warn ahead of it. Any other
   error, a protocol mismatch after an upgrade, a socket it may not open, a
   lost server, or none in words, is a server tmux could not talk to: its
   sessions are unknown, so a jump refuses them saying what tmux said
   (`tmux said "protocol version mismatch (client 8, server 7)"`) and no
   window is opened for them (12 November 2026).

   **The seat** (9 November 2026). The same snapshot gives each client's
   device: the tty of its app's own child among its ancestors, the
   terminal's pty, through any relaying pty between them; where that child
   is on none, the client's own (tmux's `client_tty`, `ps`'s tty for zmx).
   A client on no tty of its own, a tmux control-mode client over pipes, is
   on none, as before (step 3). `ps` is asked for `pid=,ppid=,tdev=,args=`,
   once a look: the command line, as zmx's clients are told by it, where it
   gave `comm` before, and the terminal by its device's numbers, `16/32` for
   `/dev/ttys032` (major 16 is a pty; any other is no device), as asking
   for its name (`tty`) made `ps` about five times slower, a median of
   580ms against 122ms at a load of 110 (from review, measured the same
   day). macOS's `ps` truncates every column but the last to its width, so
   the program and its arguments cannot both come whole; a process's
   program is read as its command line up to its first argument that is an
   option or a path (a space, then `-` and more, or `/`). That keeps the
   spaces of `/Applications/Visual Studio Code.app/…/Code Helper (Plugin)
   --type=utility` and the lone dash of `/Applications/Visual Studio Code -
   Insiders.app`, and leaves out an app only an argument names; the app is
   then its program's outermost bundle, or a driver's where the last part of
   its path is the driver's program, a plain word after it left aside
   (`…/ghostty launchd`). A program whose own path holds ` /` or a ` -`
   followed by more than a space would be misread: none is known. Over
   live snapshots of Lee's Mac (about 1,390 processes, 258 of them in an
   app) the app told from the command line was the one the released code
   told from `comm` for every process but one caught as it started, whose
   command line `ps` gives as `(name)` until it can read it.
   For tmux the seat replaced `client_tty` as the device, the same device
   wherever the client is on its terminal's pty, as each of Lee's Ghostty,
   Terminal and VS Code clients is (`tmux < zsh < login < ghostty`, login on
   the client's own tty). They differ only behind a relay: a client in
   `script`, `asciinema rec`, `expect`, `unbuffer` or Portal sits on the
   relay's pty, which no terminal is on, and the seat finds Ghostty's. A
   client in no app has no place by either, so `client_tty` stays only as
   the fallback for an app's child on no tty.

   **zmx** (9 November 2026). Lee moved from tmux to zmx on 7 November 2026,
   through Portal, his own session tool, and removed tmux; every jump then
   failed (`… shows on /dev/ttys087, but no Ghostty window there
   answered.`), as the window said no tmux and its own device, the zmx
   session's pty, which no terminal is on. Seen live, read-only, on 9
   November 2026: Claude runs on `ttys087`, the pty the session's server
   holds, with `ZMX_SESSION=sitrep-Xq4mR2`, `TERM_PROGRAM=ghostty` and no
   `$TMUX`; the server is `zmx attach sitrep-Xq4mR2 /opt/homebrew/bin/portal
   state hydrate …`, its parent launchd, on no tty; the client Lee sees is
   `zmx attach sitrep-Xq4mR2` on `ttys032`, Portal's own relaying pty, under
   `portal open /sit` < `-/bin/zsh` < `/usr/bin/login -flp me …` on
   `ttys036` < Ghostty; and Ghostty has a terminal on `ttys036`, none on
   `ttys032` or `ttys087`. So the device is the seat's, Ghostty's own
   child's, neither the client's nor the session's. zmx 1.0.1 lists no
   session's clients (`zmx list` gives each session's name, a count of
   clients, and a `pid` that is the shell on the session's pty, not its
   server's), so they are read from `ps`: each process whose command line
   is exactly `zmx attach <session>`, by any path to zmx, on a tty, the name
   compared whole after `attach `, so a name's spaces and `·`
   (`agentic-workflows-v2 · contoso-build`) need no parsing. The session's
   server is no client by its tty and its parent: it runs on none, under
   launchd, and in no terminal app, though its line may equal a client's,
   as for a session a bare `zmx attach <session>` made; Portal's servers
   have their command after the name. `ps` runs with a UTF-8 character type
   where the CLI was started with no locale (above), so the `·` comes
   through. A zmx session is one terminal, shown whole by each client:
   there is no window or pane to select, and a session is on screen where a
   client of it is in a terminal app with a place. `ps` giving no answer
   leaves it unknown, never off, as only `ps` tells its clients. Proven
   live on 9 November 2026 with SitRep's build of #104: once the window had
   reloaded the plugin, so that it recorded its zmx session, Lee's notch
   jump to it from another Space, through Portal's relay, landed on the
   window, and his typing went in.
   - **Clients not found, accepted.** A client attached by another form,
     `zmx a <session>`, `zmx attach --labels … <session>`, or `zmx attach
     <session> <command>` from a terminal, is not found: Portal attaches
     every client as `zmx attach <session>` (11 clients, live), and making
     a session with a command it does in a server of its own.
   - **A client switched in place keeps its first session's name**, a known
     limit: `zmx attach B` typed inside an attach on A, or Portal's exec
     fallback, switches the client without a new process, so its command
     line still names A, and it reads as A's client, B's window off screen.
     Portal records the same limit (`docs/design/zmx-backend.md` in its
     repository). Its own switch starts a fresh `zmx attach B`, so the
     normal path is right. Not guarded: telling it would cost a `zmx list`
     a look, and that names no client either.

   `list --json`'s `onScreen` said whether a jump could reach the session: a
   place showed it, or a select would make one show it. Its name and `v`
   stayed as they were before the select (19 October 2026), so a reader that
   took `true` to mean a jump could reach it read it as before. It went on
   27 October 2026, the plain menu its only reader (see "One engine, two
   front ends"), and came back on 4 November 2026 as `sitrep screen`, with
   unknown beside on and off, built for the SitRep window, until step B
   retired it on 10 November 2026. It read the screen as the jump did, tmux
   and `ps`, and asked Ghostty nothing, as decided on 6 November 2026 when
   the jump began asking Ghostty by device (step 3): `ps` answers in about
   60ms where any question to Ghostty takes 230ms or more, it sent no Apple
   Event, so it could neither raise macOS's prompt for leave to control
   Ghostty nor wait 5 seconds on a locked screen, and SitRep ran it while
   its window showed. SitRep's own reading (stage 7, A2) asks Ghostty
   nothing either.

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
   for it is stage 7, step C.

   The select runs only in a jump, after tmux, `ps` and the front are read
   and before the place's app is asked anything, within the 2 seconds
   tmux's reads have, and once a jump however many places need it, so one
   that hangs costs its 2 seconds once. Nothing selected is put back: a
   select made for a device whose terminal then does not answer, or in a
   jump that is refused in the end, leaves that tmux session on the pane's
   window, which is where Lee was going.

   **A place that fails gives way to the next** (19 October 2026, from
   review): a select tmux does not make, a window that does not answer, or
   an app that cannot be asked (Ghostty not answering in time, older than
   1.4, or macOS refusing sitrep control of it), and the next place is
   tried, another client, the next window, another app. An app that cannot
   be asked is passed over at its places after, so a Ghostty not answering
   costs its 5 seconds once. Only once no place is left is the jump
   refused, in the words of what stopped the first place, the one most
   wanted: `Dashboard redesign is in a tmux window no terminal shows, and
   tmux would not select it: can't find window: @45`, or `… and tmux gave
   no answer when asked to select it.`; Ghostty's own words for a Ghostty
   that cannot be asked; and, for a window that did not answer, every
   device whose window did not. So a session in one Ghostty window is
   refused exactly as before. Until 6 November 2026 an app with no window
   open was passed over too, and refused as off screen: the knock's
   listing told it, and nothing asks that now (step 3).

   **A terminal with no driver** (19 October 2026) is brought forward as an
   app, by `open` within 2 seconds, and nothing more: no window of it picked
   out, no watch of the front, no select beyond the tmux layer's. It is never launched:
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
   which keeps its own rule, the one attached longest. The order is core's
   (`core/windows.ts`, `windowsOf`, 9 November 2026), so `watch` carries it
   to SitRep as each window's `jumpOrder` and the CLI's jump reads the same.
3. Ghostty's driver asks Ghostty for the terminal on the device and focuses
   it, in one program (6 November 2026): `focus` the first of `terminals
   whose tty is` the device, its window activated first where its tab is
   not selected (step 4). Since Ghostty 1.4.0 its AppleScript gives each
   terminal `tty`, the device it is on, in the form tmux gives a client's
   (`/dev/ttys041`), and `pid`, its foreground process's (checked on this
   Mac the same day, read-only, against 23 terminals and 19 tmux clients;
   Lee ran the focus live that morning). The program prints a fixed word,
   `focused`, once the terminal is focused, and nothing for a device no
   terminal is on, or Ghostty not running; the device goes in as an
   argument, never spliced into the program's text. A device that prints
   nothing gives way to the next place. The word is fixed, not the device
   echoed back, so that an empty device, printing nothing, can never read
   as a terminal focused (review, the same day).
   - **Only a tty is a device.** tmux gives a control-mode client
     (`tmux -C` over pipes) an empty `client_tty`, and `ps` puts one started
     from a Ghostty window's shell in Ghostty; such a client is no place
     for a driver, so it neither shows the pane nor stops a select making
     another client show it. Before the review, one listed first was asked
     for and its empty answer taken for a landed jump, the real Ghostty
     client after it never tried.
   - **A relaying pty is found** (9 November 2026). A client run inside
     `script`, `asciinema rec`, `expect`, `unbuffer` or Portal in a Ghostty
     window is on the relay's own pty, which no Ghostty terminal is on; its
     seat (step 2) is Ghostty's own child's device, so the jump asks for the
     terminal there. Until then it was accepted as not found for tmux, the
     device tmux's `client_tty`; zmx made it the common case, every one of
     Lee's windows attached through Portal's relay.
   - The program first checks Ghostty is running: telling it anything would
     launch it.
   - Each question to Ghostty, each Apple Event the program sends, waits at
     most 5 seconds: AppleScript's `with timeout` holds for each event, not
     for the program around them; and the program is killed at 8 seconds in
     all (below, "The latest click wins"). With the screen locked, Ghostty
     still answers a trivial question at once but nothing about its
     terminals, and AppleScript's own limit is two minutes (found live, 13
     October). The jump then refuses in plain words.
   - **An older Ghostty** is refused in plain words, not served another
     way: `This Ghostty cannot say which of its windows is on a device, so
     sitrep cannot jump to one: update Ghostty to 1.4 or later.` The
     program itself is the check, with no question asked first: a Ghostty
     whose dictionary has no `tty` reads the word as a variable, which
     compiles and fails as the lookup runs (-2753), and one with no
     dictionary at all, from before Ghostty could be scripted, fails to
     compile (-2741), Ghostty running or not; osascript's words with
     either code are the refusal (both checked on this Mac: the program
     with a name Ghostty 1.4 does not know, and compiled against
     Calculator, which has no dictionary). First built to read Ghostty's
     `version` before the lookup, `considering numeric strings`; dropped in
     review the same day, as a tip build's version may be a commit hash,
     which no comparison of numbers reads, and it cost an Apple Event a
     jump. Chosen over keeping the knock (below) as a fallback for an older
     Ghostty, which would have kept all of its code and tests for a Ghostty
     Lee no longer runs; Ghostty updates itself.
   - **`ps` stayed**, and with it every rule of step 2, until SitRep read
     the kernel's table in its place (stage 7, A2). Skipping it was
     weighed and dropped on measurement the same day: a question to Ghostty
     costs more than `ps`. `tty of terminals` took 230–584ms and one `whose
     tty` lookup 231–296ms a program, where `ps` takes 58–63ms beside
     tmux's 5–7, so asking Ghostty which clients' devices it holds before
     the focus would add 0.2s or so to every jump. Folding that question
     into the focus, trying each client's device in turn with no `ps`,
     would save at most the 55ms `ps` outlasts tmux by, and cost a lookup
     (50–130ms more in the same program) for each client tried before
     Ghostty's that is not Ghostty's: as measured, Lee's phone and an ssh
     client were attached on the same tmux windows as Ghostty windows. It
     would also give up making a select only for the place tried before
     its app is asked, or try Ghostty's places first across windows, ahead
     of a window that needs Lee in another app.
   - **The knock, the listing and remembered terminals are gone** (6
     November 2026). Until Ghostty 1.4 its AppleScript gave a terminal no
     device, so the driver wrote a working directory report (OSC 7) naming a
     fresh marker to the device, listed every terminal's directory, asked
     which now reported the marker, focused it, and put the old directory
     back, holding the put-back against SIGTERM; and a knock that answered
     added the device's terminal to `ghostty-terminals.jsonl` in sitrep's
     folder, so a later jump focused it by its id (14 October 2026). Each
     device's terminal is now asked for directly, so a first jump costs
     what a remembered terminal's did, and nothing is written to a device.
     A `ghostty-terminals.jsonl` an earlier release left is ignored: nothing
     reads or writes it, and the CLI's file system only appends, so it is
     not deleted. It sits beside `projects/`, which is all the mod and the
     CLI list there.

4. sitrep focuses that terminal (Ghostty's `focus`). With macOS's "switch to
   a Space with open windows" on, macOS goes to its Space. Tried live: from
   Space 9 to the Litware window on Space 12, then back to Space 1. It needs no
   Accessibility permission and no window manager.

   **A terminal in a tab not selected** has its window activated first
   (Ghostty's `activate window`), then, after a pause of half a second, is
   focused; one in the selected tab is focused at once, as before. With
   macOS's native tabs, a tab not selected has a window on no Space, and
   focusing its terminal brought that tab, and the whole tab group with it,
   to the Space Lee was on, instead of taking Lee to the window's. Watched
   live on 6 November 2026, Ghostty 1.4.0 on macOS 26.7.1, the jump of #98
   doing it; the jump before it used the same `focus`, so it was no
   regression. On the Space Lee is on, a tab not selected was focused
   rightly all along. Four probes that day, each begun with the window's
   other tab selected, Lee on another Space and Finder in front, each
   finding the terminal by its tty and its window and tab among Ghostty's:
   - `select tab` the tab, then `focus` the terminal: the window came to
     Lee's Space. ✗
   - `activate window`, then `focus` straight away: the window came to
     Lee's Space. ✗
   - `activate window`, `delay 1.0`, `focus`: macOS slid to the window's
     Space and showed the right tab. ✓
   - `activate window`, `delay 0.5`, `focus`: the same. ✓

   Each of the last two took, as a whole osascript run, 1.68s and 1.16s:
   osascript's start, the probe's lookup (the terminal by its tty, then a
   walk over Ghostty's windows in order, asking each tab for its
   terminals' ids, stopping at the tab holding it), the pause and the
   focus; so about 0.67s each beside the pause.

   Half a second it is, on one run, and a second on one: the margin is
   unmeasured. A slower slide, under load or onto a second display, could
   bring the focus before the Space has changed, and the tab to Lee's
   Space as before. The program asks, after finding the terminal,
   whether its tab is selected, in one question: `selected of (tabs of
   (windows whose tty of terminals contains` the device`) whose tty of
   terminals contains` it`)`, which Ghostty answers as a list of lists, a
   window's and its tab's, `{{false}}` for a tab not selected, and `{}` for
   a terminal in no window, which is focused as one selected. Only then is
   the window asked for, to activate it. Measured read-only on this Mac
   the same day, 19 windows and 23 tabs, a program each, osascript's start
   included: the lookup alone, as before, median 244ms; with the tab's
   question, as for a tab selected, 275ms; with the window's too, as for
   one not selected, 300ms. The probes' lookup, its walk included, as a
   program with no pause and no focus, took 850–1000ms for the 18th and
   the 19th of the 19 windows, the Mac at a load of about 90; it walks
   further the later the window stands in Ghostty's order, which is why
   the probes' own runs, on another window, spent less. A tab's
   `terminals` include its split panes, and Ghostty has one window for
   each tab group (both read in Ghostty 1.4.0's source, review, the same
   day), so the question finds a terminal in a split as in a tab of its
   own.

   **The cost accepted:** a tab not selected in a window on Lee's own Space
   pays the half second too, where `focus` alone would do. Ghostty's
   scripting cannot say which Space a window is on. And `activate window`
   raises the group's selected tab (Ghostty's `selectedController.window`),
   so for the half second the other tab shows, after the slide, and on
   Lee's own Space too, before the focus brings the right one.

   **Left be:** a terminal closing during the pause fails the focus
   (-1728), and one closing between the tab's question and the window's
   lookup fails that lookup (-1719); either is a jump refused in
   osascript's words, for a window that has just gone.

   **The front watch on a tab not selected, watched live** (6 November
   2026). The watch below ("The front kept") was timed from the focus:
   Ghostty in front at about 0.2s, the app Lee was in taking the front back
   at about 0.5s. For a tab not selected the slide begins at `activate
   window`, half a second before the focus, so the hand-back might have
   come between the focus and the watch's first look, 60–120ms after it,
   the watch then seeing the other app first, never Ghostty, and bringing
   nothing forward. Lee's two notch jumps from SitRep's build of #100, each
   from Space 7 with Finder in front to a tab not selected in a window on
   Space 12, slid to Space 12 and showed the right tab, the tab changing
   about 300ms after the slide, and he went on typing into that terminal
   after each, with no click reported: the front held, as far as two runs
   show. A rare miss is not ruled out.

   **The instant Space switch, tried and not built** (6 November 2026). A
   throwaway tool posted Spaceman's synthetic Dock-swipe gesture before
   Ghostty's focus, across 10 Spaces on one display. The Space arrived in
   about 156ms, then the focus took about 200ms, focused at about 0.41s,
   against the slide's focus at about 0.23s followed by macOS's quick
   slide. Lee saw a difference but found both very quick, and kept the
   slide. Building it would need an Accessibility grant and a private
   gesture an update could break, would cover only the display under the
   pointer, and would still slide on a first jump to each window. The jump
   instead finds its terminal by tty (Ghostty 1.4.0), built the same day
   (step 3); `ps` stayed, as measured there. The switch is left for now, not
   ruled out: the research, the live timings and the test tool's source
   are kept in Lee's clone at `.scratch/space-switch/` (`README.md`,
   `main.swift`).

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

   A notification's click begins its jump with the notices helper in
   front, as macOS activated it (see "The menu bar"), where SitRep was
   before: another app, as Finder is, so the watch runs, and a hand-back
   to the helper brings Ghostty forward again. Nothing in the CLI names
   SitRep or the helper (26 October 2026).

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

   **What a jump costs.** Measured live on 14 October 2026 with 24 Ghostty
   terminals open: a first jump about 0.6s, tmux's two lists 10ms beside
   `ps` at 75ms, then the knock's listing 230–640ms and its find and focus
   210–315ms; a jump to a remembered terminal 265–360ms, tmux and `ps` then
   one focus. osascript's own start is about 70ms, and Ghostty is slow to
   answer, so the time is Ghostty's, not the programs' starts;
   `lsappinfo front` takes 11ms.

   Since 6 November 2026 every jump, the first too, is what a remembered
   terminal's was: tmux beside `ps`, then the one program. Measured
   read-only that day, 23 Ghostty terminals and 19 tmux clients, the Mac at
   a load of about 10: tmux's two lists 5–7ms each, `ps` 58–63ms, osascript
   with a trivial question (`get version`) 60–74ms, the program's lookup
   without its focus 231–296ms, and 246–432ms with a device Ghostty does
   not hold tried first; Lee's live focus by tty that morning took about
   200ms. So a jump is about 60ms, then 200–350ms: 0.26–0.41s, against
   about 0.6s for a first jump before. With another app in front, the CLI
   stays up to a second more, watching, the window already forward.

   The same day the program began asking whether the terminal's tab is
   selected (step 4), which adds about 30ms to every jump (medians 244ms
   for the lookup alone, 275ms with the tab's question); a tab not
   selected adds the window's lookup and the half second's pause, about
   0.55s more, and its activation.

**The latest click wins** (4 November 2026). With the Mac's load near
250 from parallel Swift builds, Lee could reach no Ghostty window by a jump
for three minutes. SitRep's log: `sitrep jump --session sr-h5c2rv: did not
answer within 180 seconds` (16:11:04). SitRep ran one jump at a time and
took no click while one ran, so every click in those minutes waited behind
the stuck one, and Lee saw the row spin for 450ms, then nothing. The CLI
gave tmux and `ps` 2 seconds and each question to Ghostty 5, yet the run
took 180, so some step ran unbounded. Lee's go, the same day: "Build it".
- **A click while a jump runs stops it, and jumps in its place**, from any
  surface: Lee clicked again, so he has changed his mind, or the first is
  stuck. The new jump runs once the one it stopped has ended, so two never
  run at once (until 6 November 2026, so two never knocked on one terminal
  at once). A click on the session the jump runs to, before it says it is
  still jumping (below), joins it: a double-click, or a quick second
  click, would otherwise kill it midway and add a whole start of Bun,
  and both clicks hear how it ends. Once it says it is still jumping, a
  click on its session is Lee trying again, and starts it over; a click on
  another session always wins at once. A jump a click stopped says
  nothing: no banner, no caption. Until 4 November 2026 a click while a
  jump ran started none: the menu's jump items were disabled, and the
  card's, the strip's and the window's clicks refused.
- **The CLI's jump was stopped gently, with everything it started**, until
  A3 (9 November 2026), when SitRep's own jump took its place and is
  stopped by its task (below); this stays for the record. `SitRepCLI.jump`
  and its gentle stop (`Stopping.gently`) went in step B (10 November
  2026). At the limit,
  or stopped by a click, the CLI's process group is told to end (SIGTERM):
  the CLI, and osascript, tmux, `ps`, lsappinfo and `open`, which share its
  group, and a second on the group is killed (SIGKILL), whatever is left
  of it. The grace was for the knock's marker, which the CLI put back
  straight to the device before it exited (step 3); since 6 November 2026
  the CLI holds nothing to put back and dies at the signal, so the grace
  costs time only for a CLI stuck, and SitRep's stop is as it was. The
  next jump waits for the stopped one to end: at most the grace, and the
  half second SitRep gives a run's output to drain. `Process` makes each child the leader
  of a group of its own, and Bun's children stay in it (both checked on
  this Mac the same day); a group not the child's own, which would be
  SitRep's, is never signalled. Chosen over the CLI ending its own children
  on SIGTERM: a group signal needs nothing of the CLI, works while Bun is
  still starting or stuck, and the SIGKILL after it nothing stuck can
  ignore. Every other run of the CLI is killed with its group at once; a
  login shell, asked for Lee's PATH, is killed alone, as before, so
  whatever its startup files launched, an ssh-agent among it, is left be.
  Killing osascript
  recalls no Apple Event already sent: a starved Ghostty can still focus a
  terminal late. And a program killed after Ghostty focused but before its
  reply refuses a jump that landed, with no watch of the front after it;
  accepted, as both need Ghostty answering only just too late.
- **The whole jump gives up after 15 seconds**, Bun's start and the board's
  read among it, where it was 180, a backstop. A jump takes under a second
  as Ghostty answers, a little over to a tab not selected, for its half
  second's pause (step 4), and one Ghostty does not answer is refused at its
  first question, after 5 seconds; past 15, the Mac is too busy for a jump
  to land while Lee still wants it. The 15 run from the CLI's start, so
  they do not count the wait for a jump it stopped to end. The CLI's own
  limits stood, until step B retired its jump: 2 seconds
  for each of tmux, `ps`, lsappinfo and `open`, 5 for each question to
  Ghostty, and 8 for its program (below).
- **The step that ran unbounded: each Ghostty program.** osascript ran with
  no limit of its own, only each Apple Event in it waiting at most 5
  seconds. Its own start, finding Ghostty and reading its terms, none of it
  an event, fell outside every limit, and so did the sum of a program's
  events: a find tried 20 times, a listing asked three questions a try and
  was tried three times, each answered just inside 5 seconds by a Ghostty
  starved of the CPU. Each program is now killed at 8 seconds in all: time
  for one question to go unanswered, so a Ghostty not answering is still
  told in its own words, and for osascript's start under load. One killed
  ends the jump unanswered, exiting 3 with "Ghostty did not answer within 8
  seconds: most likely the Mac is too busy.", as for a question timing
  out; SitRep told exit 3 as it told its own limit, until A3, and exit 3
  went with the CLI's jump in step B. Since 6 November
  2026 a jump runs one Ghostty program a device: a lookup, the question
  whether its tab is selected, and a focus, with, for a tab not selected,
  the window's lookup, its activation and a half second's pause before it.
  Bun's start and the board's read stay outside every step's limit,
  inside the 15 seconds.
  Which step ran the 180 seconds is not known, the log saying only that the
  CLI did not answer; osascript was the one program the jump ran without a
  limit of its own.
- **SitRep's own jump is stopped by its task** (A3, 9 November 2026; see
  "SitRep's own jump"), with no process group to signal and no grace: it
  is cancelled, and ends between its steps, tmux killed with its group and
  an Apple Event in flight let go, so the next jump, which still runs only
  once the stopped one has ended, waits a moment at most. Each step has its
  own limit, so none runs unbounded, and the whole jump's 15 seconds stand.
- **The caption says what is happening**, for a jump from anywhere, the
  card, the strip, the menu or a banner, in the
  caption's look and place, on the edge's screen while the edge shows.
  "Still jumping…" once a jump has run 2 seconds with no answer: it comes
  in as a caption does, and holds until the jump ends; then a row's
  "Jumped to SitRep's window" takes its place, or it goes as a caption
  does. A jump given no answer in time, at SitRep's limit or a program's,
  says "Couldn't jump: the Mac is too busy.", played as a caption is: the
  15 seconds cover Bun, the board, tmux, `ps`, lsappinfo and `open`, and an
  app with no driver involves no Ghostty, so the words name none; since
  A3 they cover the wait for a board and for Lee's PATH, tmux, the process
  table, Ghostty's events and LaunchServices, and the words are the same
  once the jump has its board; one whose time ran out waiting for a board
  is refused as the board not there, its banner saying why.
  Each caption comes in, or goes, from the pill's opacity as it is, so one
  taking another's place, or an answer cutting a coming in short, never
  jumps. A jump a later click stopped leaves the caption as it is, the
  later one running on. Every failed jump is still told in a banner, the
  too busy one saying "The Mac is too busy to jump." under "SitRep could
  not jump", so the menu and the window, which have no caption of their
  own, and an edge hidden or set to Nothing, still say it. VoiceOver
  announces each caption as it shows; until 4 November 2026 it announced
  none, the edge being drawn layers.

Why tmux comes in at all: walking up the processes never reaches the window.
Claude's chain is `launchd → tmux server → zsh → claude`, the window's is
`Ghostty → login → zsh → tmux attach`, and the two meet only inside tmux,
which is what lets a tmux session outlive a crash and be picked up from the phone.
Ruled out: an environment variable (Ghostty gives a shell no window id),
AppleScript (before Ghostty 1.4 no device or pid on a terminal; since, the
device it gives is the tmux client's, not Claude's pane's), the window
server and Accessibility (nothing ties a window to its device), recording
the front window as each shell starts (a race, and blind to windows already
open), and tmux passing an escape sequence through from Claude's own pane
(a tmux setting, and it reached a window only while that pane was on show).

### Stages

1. **Each window records where it is**: its device, and its tmux socket and
   pane. Built 13 October 2026.
2. **`sitrep jump --work <id>`** in the CLI, the whole jump, runnable from a
   shell; and `list --json` says whether each session is on screen, so the
   panel knows what to offer (the jump retired in stage 7, step B, on 10
   November 2026). Built 13 October 2026, reviewed at xhigh,
   and run live twice with Lee watching: Finder in front, to the Litware
   window on its Space and back, about half a second a jump, every
   directory as it was. Stages 1 and 2 landed together (kit-config #2);
   after a `/reload-plugins`, a jump on real sessions went from Finder to the
   Litware window's Space and back, half a second each way, every directory
   as it was (13 October 2026).
3. **The app**, and what the plugin gives it: the words and the versions,
   the live feed, the jump's drivers, the notch and its panel, the strip,
   the menu bar item, the macOS notification, Settings, the SitRep window
   (since removed), and installing the plugin. It is a `.app` of its own (no
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
      nothing over full screen. The SitRep window had none: it was an
      ordinary window, its design taken as it stood, and its hard part,
      answering, was plumbing a spike over sample data would not test. PR #5
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
      folder's rules once more after their fixes; the move and the reads
      in their order are under "Storage", gone since 27 October 2026.
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

      The clone was the live plugin until the first release (28 October
      2026): each is proven by the CLI run live over a state folder of its
      own, and reached Lee's windows as it merged, at their next
      `/reload-plugins`.
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
        prototypes; one while a jump runs, from anywhere, jumps in its
        place, the latest click winning (see "The jump"), where until 4
        November 2026 none was taken while a jump ran, from the panel, the
        menu or a banner, the menu's works disabled then; a row folding away
        takes none either. Once the jump has jumped, "Jumped to SitRep's
        window" shows 90ms into the drain, or as the jump answers if that is
        later, and never once its moment has passed. The CLI's answer names
        no place, so the caption names the row's project. It sits at the
        top of the notch's screen, centred, 22 under the menu bar, where the
        prototypes put it 22 under their stage's top, with no blur behind
        it. A jump refused leaves no caption, and its banner says why. A
        jump from anywhere still running 2 seconds on, or given up at its
        limit, says so in it (4 November 2026; see "The jump").
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
        on the line's `new`, as on any run's first line, comes in with
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
        spin is over. As the panel's, a click while a jump runs, from
        anywhere, jumps in its place (none was taken until 4 November 2026);
        an answer to an earlier click changes nothing; and the
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
        marks and its hairline, the first twelve of them (every one since
        the window went, 5 November 2026); its heading the
        panel head's words, "4 need you · as of 12:04" while the board is
        stale. `sitrep list` is no longer read by the menu, nor the listing
        it kept. The app's `list()` and its `Listing`, left behind for their
        tests alone, went on 27 October 2026.
      - **The rows**, each a native item: its title the row's first line,
        set as attributed text, its words in the menu's font and its subject
        in the system's mono, a question's "+2" after (since rows by session,
        a row's newest line, its oldest until 4 November 2026, and "+N" for
        its other lines in its place; since board F, a Needs you row's
        session's name and its count, "+N" until 6 November 2026 and the
        plain number since, its project as its subtitle); core's second
        line as its subtitle; its time as its badge. A working row's words are in
        the secondary label colour, its arc fainter than the other marks;
        under the pointer the colour is taken off, through the menu
        delegate's `willHighlight`, so the highlight's own ink shows. An away
        row has no action, so macOS draws it disabled, dimming its mark with
        its words, its title in the disabled ink. The line under a row went
        missing at rest on macOS 26, showing only under the pointer, found 3
        November 2026: `willHighlight` set the rows the pointer left and
        reached again, and setting an open menu item's attributed title, even
        to the one it has, tells the menu it changed, which draws the item
        again without its subtitle; setting the same subtitle again tells it
        nothing, so brings nothing back. A row's title is now set only where
        it differs, and then its subtitle is taken off and set again after
        it, so the line shows again, at rest and under the pointer alike. Its
        image and its badge, set while the menu is open as the arc turns and
        the time ticks, tell the menu only of themselves and keep the line,
        as read offscreen from the view the menu makes for the item. An item
        with an attributed title shows no subtitle before macOS 15, so
        before it a row's title is plain, and before 14.4, which has no
        subtitles, the second line is its tooltip. The marks, the tick and
        the commands' symbols are each the item's 16-point image, the state
        column turned off.
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
        rows then showing, and while a working row shows its arc turns (3
        November 2026): its image swapped each 30th of a second for one of
        thirty frames drawn once, the frame the clock's place in the second,
        by a timer in the menu's tracking mode that starts only with a
        working row in the menu and stops as the last goes or the menu
        closes (`MenuTurn`).
      - **Open SitRep Window** and "N more…" opened the SitRep window,
        until it went (5 November 2026).
      - **The glyph** is drawn from the icon drawing's SVG: at rest a
        template; lit, its housing drawn in the ink of the bar it is drawn
        on, light or dark, its bar orange. It lights from the board's
        "needs you", kept while the board is stale.
      - **What Lee sets** is kept in one place (`Preferences`): the edge's
        settings, saved as one value as before, and beside them, under a
        key of their own and as leniently read, whether a new ask notifies
        (off), whether it plays a sound (on) and which (Glass), and the pane
        ⌘, opens. The menu's Show and every control in
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
        usual. Several are sent in core's order.
        Each names the ask's project and session from the
        board's projects, so an away ask's says them too, where its second
        line does not; its click jumps nowhere. Turning the switch on asks
        macOS for leave, unless Lee answered before. The switch's line says
        what tells Lee instead: the notch's swell, the strip's flash, or the
        menu bar's light with Nothing. Send sends a sample naming no
        session, which a click jumps nowhere from. Since 26 October 2026 the
        notices helper posts them all (see "The menu bar").
      - **The sound** (27 October 2026) keeps the same rule and guards, its
        own switch in place of Notify me's: once for a line, however many
        asks it brings, and none for a window's new stop. An ask its
        snooze's time woke is among a line's `new` as one that landed is
        (`newRows`, in core/feed.ts), so it plays too; one Lee woke is not.
        An ask that lands or wakes while `watch` is not running plays
        nothing, as it sends no banner: a run's first line counts all it
        shows as shown, so the app starting, a restart after a crash's
        backoff and a renewal play nothing for what came before.
        `AlertSounds` reads a saved name macOS lacks (one edited by hand,
        saved on another Mac, or dropped by a later macOS) as Glass, so the
        pop-up and the sound played agree.
        `Chime.due` names the sound a line plays, and `AlertSounds` plays it
        through `NSSound`, stopped first, so a sound chosen again as it
        plays starts over; the player is given, so the tests play nothing.
        The mod plays nothing: `host.ui.play` and `sounds/` are gone. Lee
        heard it live the same day, with Submarine chosen.
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
      - the window itself, built from 20 October to 5 November 2026, last
        to Paper's A1–A4, and removed on 5 November 2026 at Lee's call
        after his live look, because it fell well short of the drawings.
        The menu now lists every session, with no "N more…" and no Open
        SitRep Window after them; the card's row keeps its time under the
        pointer, with no button in its place, and its menu has no Open in
        SitRep, its click jumping as before. The CLI kept what was built
        for it, `screen` until stage 7's step B retired it (10 November
        2026); the app's side of it went with the window: the follow input,
        `screen`, `answer`, `finish`, and reading `projects` and `boards`.
        Its saved keys are taken out at the app's start.
   9. **Installing the plugin**: the app's first start installs it, and its
      relaunch refreshes it (Installing and updating, under "Where it
      lives"). Built 20 October 2026, and reviewed twice the same day:
      - **The bundle carries the plugin**, in `Contents/Resources/Plugin`:
        `app/bundle` copies what Claude Code loads (`.claude-plugin`,
        `hooks`, `core`, `types`; `sounds` too, until the sound became
        SitRep's on 27 October 2026) as the checkout stands, files
        not yet committed among them but not the ignored ones, compiles the
        CLI into `bin/sitrep` with `bun build --compile`, and stamps it
        with a digest of its files (`.sitrep-build`); the app's source, the
        tests, the CLI's source and this design stay behind. The bundle's
        signature verifies with it inside (`codesign --verify --deep
        --strict`). `app/bundle` refuses a folder that already holds a
        bundle. The Info.plist's `SitRepPlugin` is gone.
      - **The compiled CLI is signed with the Developer ID** since 27
        October 2026, first of the bundle's parts, before the digest, so
        the digest is of the CLI as it ships; until then it kept Bun's ad
        hoc signature. It runs under the hardened runtime with
        `allow-jit` alone (`app/CLI.entitlements`), found by trial that
        day on Bun 1.4.3: with no entitlements it still answered, but
        JavaScriptCore ran with its JIT off, a hot loop four times slower;
        `allow-jit` gave the JIT back. `allow-unsigned-executable-memory`,
        which allows more, and `disable-library-validation` are not needed:
        it loads only the system's libraries. Signed so, it answered `list
        --json`, a note and `watch` from inside the bundle, against a
        scratch `XDG_STATE_HOME`. Its identifier is SitRep's
        bundle id and `.cli`. A signature records when it was made, so
        every build's digest is new and replaces the copy. Since 22
        November 2026 press signs it, after the digest, so `app/bundle`
        mixes a random value into the digest instead, to the same end.
      - **The copy is not quarantined.** A cask's download marks every file
        it holds `com.apple.quarantine`, and copying keeps the mark, so
        SitRep takes it off every file of its copy before swapping it in
        (27 October 2026). The copy is SitRep's own sealed payload, approved
        with SitRep, but its CLI runs outside the bundle, from Claude's hooks
        and from the app, where macOS would judge a quarantined program with
        no ticket stapled to it on its own, by a lookup online that could
        refuse it offline at its first run.
      - **The jump was proven live** from a build signed with the Developer
        ID, 27 October 2026: it went as before, and macOS asked nothing.
        TCC's stored leave to control Ghostty still named SitRep Local's
        certificate, so that jump sent Ghostty no Apple Event or macOS kept
        the leave; macOS may yet ask once more.
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
   control Ghostty. It ran one jump at a time: two knocking on one
   terminal at once could leave it reporting `$HOME`, as the later one took
   the earlier one's marker for a directory it could not know. Since 4
   November 2026 the latest click wins, stopping the one running, and
   since 6 November a jump knocks on nothing (see "The jump").

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
     `~/Applications/SitRep.app`, replacing what is there, and starts it;
     since 28 October 2026 to `/Applications/SitRep.app`, over the cask's copy
     (stage 4). Since step 9 `app/bundle` makes the signed bundle, into a
     folder given, and `app/build` installs what it made. Since 22 November
     2026 `app/bundle` only lays the bundle out, unsigned, and `app/build`
     signs it with `press sign --dev`, as `.press.toml` says, before it
     installs it (see "Through press", under stage 4).
     Always that place: the login item and macOS's permissions remember an
     app by where it is. It stops a running SitRep with a signal, since
     asking it to quit by an Apple Event would itself want leave to control
     it.
   - **Signed with "SitRep Local"** until 27 October 2026, a self-signed
     certificate `app/make-certificate` made once per Mac and trusted for
     code signing. macOS ties the leave to control Ghostty to the app's
     signature, and an ad hoc signature changes with every build, so each
     rebuild would ask again; that one stayed put, its designated
     requirement the bundle id and the certificate. Lee's Developer ID
     replaced it on 27 October 2026 for every build, `app/build`'s and a
     release's alike, and `app/make-certificate` went (stage 4). Its
     designated requirement is the bundle id and the team, so a build from
     a checkout and a release share the leave, notifications and the login
     item. The change may ask once more for leave to control Ghostty; Lee's
     first jump after it went as before, with no prompt (step 9).
   - **`com.leeovery.sitrep`**, named SitRep, with no Dock icon.
   - **Its version is the plugin's**, read from `plugin.json` as it builds:
     one version covers both.
   - **Hardened runtime, with the apple-events entitlement**, already:
     notarising at stage 4 needs it, so the leave to control Ghostty is
     proven as a release will ask for it.
   - **Lee's login shell's PATH.** As it starts, the app asks the shell in
     Lee's user record, as a login and interactive shell, for its PATH
     printed between markers, since Oh My Zsh prints around it; about 0.3s.
     Interactive, as step 2 needs `claude`, which only an interactive shell's
     PATH has. The shell's answer is kept. With none it falls back to
     Homebrew's folders, `~/.bun/bin` and the system's, logs it, and asks the
     shell again at the next run, so a shell slow as Lee logs in costs one
     run, not every run until a restart. Every child gets that PATH and
     otherwise the app's own environment, and a time limit, only a backstop
     for a CLI that hangs: 10 seconds for a run on one session's files, a
     write, as for the `list --json` the plain menu ran and the
     `board --json` the window ran before it followed boards through
     `watch`, and 180 for a jump, well above any realistic one. A jump takes under a
     second as Ghostty answers, and one Ghostty does not answer at all, as
     with the screen locked, is refused at its first question, after 5
     seconds. It is no true ceiling: the 5 seconds hold for each question to
     Ghostty, each Apple Event, and a program sends several (a listing three
     a try, a focus two, a find some 40), so a Ghostty answering every
     question only just inside its 5 seconds could keep a jump going past
     180, and the app would then report that the jump did not answer. Raised
     from 120 when the jump began remembering terminals and watching the
     front, 14 October 2026, and cut to 15 on 4 November 2026, after a jump
     ran all 180 (see "The jump").
   - **The main checkout's path stamped in.** `app/build` writes the folder
     of the repository's main checkout, the live plugin, into the app's
     Info.plist (`SitRepPlugin`), even when it builds in a worktree; the
     app runs that folder's `bin/sitrep`. Step 9 took it out (20 October
     2026): the app runs the CLI of the plugin the `sitrep` marketplace
     names, which on this Mac was the main checkout until the first release
     and is SitRep's own copy since (stage 4), from any build.
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
4. **Releases**, decided with Lee on 27 October 2026. First planned as a
   GitHub Action on a macOS runner that built the app, published Sparkle's
   feed and updated the cask, once sitrep was stable and public.
   - **The repository stayed private** until 18 November 2026, and the
     cask needed a GitHub token until then: a new Mac gets SitRep from the
     cask in `leeovery/homebrew-tools`. Sparkle waited until the repository
     was public, and was then dropped: `brew upgrade` updates the app (18
     November 2026; see "Installing and updating").
   - **mint cuts a release** (`./release`): the version, in `plugin.json`,
     which the app takes, the tag `v<version>`, and the GitHub release. Its
     `preflight` runs `press check`, its `pre_tag` every gate, since no CI
     does, then builds the release (`press prepare`); its `post_release`
     uploads it (`press upload`). Until 22 November 2026 the scripts below
     built and uploaded it (`app/release-build`, `app/release-upload`).
   - **Through press** (22 November 2026): press, the owner's release tool in
     kit-config, took over from the release scripts, `app/release-build`,
     `app/release-common`, `app/release-upload`, `app/notarize` and
     `app/signing-common`, which went. `.press.toml` says what SitRep builds
     and ships: the app, the CLI and the notices helper inside it, each
     signed by its identifier with its entitlements, inside out, under the
     hardened runtime, the zip `SitRep-<version>.zip`, its sha256, and the
     cask in `leeovery/homebrew-tools`. press takes the steps the bullets
     below set out: it builds HEAD in a worktree of its own, by
     HEAD's own `app/bundle`, signs it from the signing keychain, which it
     unlocks itself, notarises, staples and checks it as a quarantined
     download would be, keeps the zip in `~/Library/Caches/press/sitrep/<version>/`,
     pruning others a month old, logs to
     `~/Library/Logs/press/sitrep-<version>.log`, and sends the cask its
     version and sha256 only for the latest release. The app's Info.plist
     carries the version without a pre-release suffix, the bundled plugin
     the version whole. What differs: press checks the tracked tree
     against HEAD before it builds, and again with HEAD before it keeps the build, where
     `app/release-build` counted untracked files too (mint still refuses
     them before its hooks run); and press signs the CLI after `app/bundle`
     has stamped the plugin, so `app/bundle` mixes a random value into the
     `.sitrep-build` digest, which the CLI's signature, made before it, used
     to make new for every build. press keeps the rules the bullets below
     set out, not the scripts' mechanics: those bullets marked "the
     scripts'" are history. Its work folder and lock are its own,
     `~/Library/Caches/press/sitrep/work` and `lock`, not
     `.sitrep-release-work` and `.sitrep-release-lock`; a failed run
     removes the apps it built and its worktree; `SITREP_RELEASE_CACHE` is
     gone, press's folders being its config's; `press prepare <version>
     [<ref>]` and `press upload <version>` build and upload by hand, where
     `app/release-build <version> [<ref>]` and `app/release-upload
     <version>` did; press, not `app/signing-common`, unlocks the signing
     keychain; and press sends the submission without waiting, then waits
     on it in rounds, where `app/notarize` sent it with `--wait`.
   - **Built on this Mac, not in CI** (Lee's choice): with the Xcode Lee
     tests with, no certificate in GitHub, and no macOS runner's minutes.
     It builds on a Mac only because the Developer ID's key and the notary
     login live in this Mac's signing keychain; Lee's other tools rightly
     build in CI (28 October 2026).
   - **Built before the tag** (the scripts', `app/release-build`), the last of mint's
     `pre_tag`, once every gate has passed: from HEAD, which mint tags once
     it commits its bookkeeping, in a git worktree of its own outside the
     repository, by HEAD's own `app/bundle --release`. mint's `pre_tag` runs
     before mint writes the new version into `plugin.json`, so `app/bundle`
     takes the version from `MINT_NEW_VERSION` when mint sets it, else from
     `plugin.json`, stamps it into the app's and the helper's Info.plist and
     writes it into the bundled plugin's `plugin.json`, as mint's
     `version_pattern` writes it; `app/release-build` checks the app and the
     bundled plugin carry it. mint commits whatever `pre_tag` leaves in the
     working tree, untracked files included, into the tag as `pre_tag`'s
     artifacts, so the tree may differ from HEAD only in mint's
     bookkeeping, `plugin.json` in its version alone, `CHANGELOG.md` and
     `.mint.toml`, untracked files counted: anything else would be tagged
     unbuilt, so it stops the release. The check runs before the build and
     again once Apple has answered, before the build is kept, with HEAD
     still the commit built, as the build and Apple's wait take minutes in
     which the clone can change. So a `--notes-file` for mint lives outside
     the repository. A tag already there for the version stops it too: HEAD
     isn't then what's to be tagged. Then notarised and stapled
     (`app/notarize`), and the zip of the stapled app, its sha256 and the
     commit built kept in `~/Library/Caches/SitRep/release/<version>/`,
     replacing that version's; other versions' builds are kept a month, so
     a trial build, as `app/release-build 0.0.0-check`, never takes the one
     a failed upload still needs. The worktree and the bundle are made in
     `.sitrep-release-work` there, which each run clears first, its
     worktree removed even when locked or gone, as mint's cancel kills a
     hook before its own cleanup, which would leave a signed SitRep.app for
     macOS to launch by its bundle id, and a kill during `git worktree add`
     leaves the worktree locked. As runs share that folder, one runs at a
     time, holding `.sitrep-release-lock` there, which names its process;
     another refuses while that process lives, and takes the lock over once
     it's gone. A cleanup that fails after a good build only says so, so it
     never costs the release another wait on Apple. `SITREP_RELEASE_CACHE`,
     an absolute path with no `.` or `..`, never `/`, keeps the builds
     elsewhere, as a trial run's scratch folder; a run removes nothing there
     but builds as it keeps them, a folder named as a version whose `commit`
     names a commit, and the work folder and lock it makes.
     A failure anywhere in that, the build, the signing, the certificate or
     the notary's login gone, or Apple refusing, stops the release before
     its tag, for mint to be run again once it's put right: nothing is
     public yet. By hand, `app/release-build <version> [<ref>]` builds the
     version given, from HEAD or from the ref, as a tag's tree.
   - **Uploaded after it** (the scripts', `app/release-upload`), mint's `post_release`,
     once the tag and the release are pushed: the zip kept uploaded to the
     release as `SitRep-<version>.zip`, replacing one there, and the cask
     sent its version and sha256 (below). Nothing is built after the
     tag: the zip is taken only where its sha256 matches, the commit built
     lies under the tag, and the tag changes nothing since but mint's
     bookkeeping, as its commits of the version, the changelog and its
     answers in `.mint.toml` change nothing a build reads but the version,
     which the build already carries. Otherwise it stops, saying to build
     the tag again with `app/release-build <version> v<version>`, which
     notarises, then upload it with `app/release-upload <version>`. mint
     only warns when `post_release` fails, so run again by hand, with no
     mint environment, `app/release-upload` uploads the version
     `plugin.json` names, or the version given (`app/release-upload
     0.3.1`), tagged `v<version>`, from what's kept, which needs no signing
     or Apple again. A re-run's upload replaces the asset with the same
     kept zip, under the same name and with the same sha256.
   - **Why before the tag** (Lee, 5 November 2026, as Switchboard had
     adopted that day): every failure about the app, or the means of
     signing it, comes before mint's point of no return, so a release is
     never published that can't have its zip, and what's left after it is
     moving a file already right. Waiting on Apple costs nothing: a tag
     without its zip reaches no Mac, as the cask follows the tap.
   - **The gap after `pre_tag`,** known and left open: `pre_tag`'s checks
     end with it, and mint then writes the notes, runs its check on their
     files and waits at the review gate before it commits and tags. A
     commit, or a pull, made in the clone then is tagged unbuilt, and so is
     an uncommitted edit to `plugin.json` beyond its version, as mint's
     bookkeeping commit takes the file from the working tree by its path.
     The release is published, and `app/release-upload` refuses the zip as
     not of the tag; `app/release-build <version> v<version>`, then
     `app/release-upload <version>`, finish it. Closing it needs a mint
     hook nearer the tag. So the clone is left alone while mint runs.
   - **Logged** (the scripts'). mint shows nothing of a hook that succeeds, and only its
     stderr when it fails, so both stages write everything to stderr and
     to `~/Library/Logs/SitRep/release-<version>.log`, naming the log as
     they start; the log keeps the zip's sha256, the commit built, the
     asset's id and, when sending the cask fails, the command that sends
     it. A dry run does nothing: mint runs no hooks then.
   - **Signed with Lee's Developer ID** (the scripts'), `Developer ID Application:
     PointsBox Limited (CQKZZ4FN6V)` in the signing keychain,
     `~/Library/Keychains/signing.keychain-db`, by `app/bundle` for every
     build, `app/build`'s too, so a build from a checkout and a release
     share macOS's leave (see step 3's "Signed with"). The signing keychain,
     which kit's developer-id step makes, holds the identity and
     notarytool's profile and opens with the `.p12`'s password,
     `DEVELOPER_ID_P12_PASSWORD`, which kit writes to `~/.secrets.zsh`:
     `app/bundle` and `app/notarize` unlock it themselves
     (`app/signing-common`), reading the password from `~/.secrets.zsh`
     where the shell lacks it or holds an old one, so neither asks, at the
     Mac or over SSH. It signs by the identity's hash, and refuses, listing
     them, when the signing keychain holds two of the name, as after a
     renewal. Inside out, never with
     `--deep`: the CLI (step 9), the notices helper, then the app, each
     under the hardened runtime. A release's carry a secure timestamp,
     which notarising needs; getting one needs the network, and without it
     `codesign` fails, and `app/bundle` with it. `app/build`'s carry none,
     so it builds offline. It then checks each part: signed by the Developer ID,
     under the runtime, a release's timestamped, and with exactly its
     entitlements, the app's Apple Events, the CLI's `allow-jit`, and none
     for the helper; and verifies the CLI's own signature, which the app's
     `--deep` checks only as a file it seals.
   - **Notarised and stapled for a release only** (the scripts'). `app/notarize` zips the
     app with `ditto`, sends it with `notarytool submit --wait` under the
     keychain profile `notarytool` in the signing keychain, the Mac's one
     login for notarising,
     shared by every app built here, waits again with `notarytool wait` when a
     wait ends in progress, as a dropped connection leaves it, prints
     `notarytool log` when Apple refuses it, staples the ticket and
     validates it, and zips the stapled app for download. Then that zip as
     a download: its app unpacked, its staple validated, since `spctl` alone
     can pass by looking the ticket up online, then marked quarantined as
     Safari marks a download, and `spctl -a -t exec` must say it is
     accepted, from a notarised Developer ID. `app/build` doesn't notarise:
     a build installed from a checkout is never quarantined, and notarising
     would add minutes to every install.
   - **Proven on 27 October 2026**, on a bundle in a temporary folder: the
     notary service accepted it at the first submission
     (`6d05e210-ae07-41b7-917d-ad3ebf4404f5`), its log listing no issues
     and the CLI among the ticket's contents; stapled, the quarantined copy
     was "accepted, source=Notarized Developer ID", where `app/build`'s,
     signed but not notarised, was "rejected, source=Unnotarized Developer
     ID". The CLI answered from inside the stapled bundle. Nothing was
     uploaded: the first release is Lee's. The jump from a build signed so
     went as before, live, with no prompt (step 9); macOS may yet ask once
     more for leave to control Ghostty.
   - **The cask and the tap's update** (the scripts'), built 27 October 2026. The cask,
     `Casks/sitrep.rb` in `leeovery/homebrew-tools`, downloads the release's
     zip from its public URL, by the zip's name (see "Installing and
     updating"); it needs macOS 14 and an arm64 Mac, as the app and its CLI
     are arm64 only, so an Intel Mac needs an x64 build beside them. Once
     it has uploaded, `app/release-upload` sends the tap's `update-formula`
     workflow, through `gh api`, the event `update-formula` with `tool`
     `sitrep`, the version and the zip's sha256, which the workflow checks
     (`X.Y.Z`, 64 hex digits), writes into the cask's own lines and
     commits, one run at a time. It sends at every run that uploads, which
     matters after `app/release-build` has built the zip again or after an
     earlier send failed, but only for the latest release: Homebrew takes any version other than the one installed as
     an upgrade, so the cask on an older one would downgrade every Mac. A
     204 from GitHub only says the dispatch was taken, so `app/release-upload`
     then finds the run it started, the first of the tap's `update-formula`
     runs with a newer id than the last before it (an id, unlike a time,
     doesn't hang on this Mac's clock) and named by the workflow's
     `run-name` for this cask and version, "Update sitrep to v<version>",
     so another tool's run started beside it isn't taken for it, within a
     minute, logs its URL, and
     waits on it, bounded by the workflow's 5-minute timeout. A failed
     send, no run found, or a run that fails fails the release run, saying
     the command that sends it again and the run's URL; the upload stays.
     A rerun uploads the same kept zip, with the same sha256, but `gh
     release upload --clobber` deletes the old asset first: if that upload
     fails, installs of the current version get a 404 until a rerun
     succeeds. Only after `app/release-build` has built the zip again does
     its sha256 change, and installs fail the cask's sha256 until the
     workflow commits the new one, about a minute, or until a rerun or the
     command sends it, if the send or the update fails.
   - **Public, with no token** (18 November 2026): the repository went
     public, and the cask stopped needing a token. Until then the cask
     downloaded the zip through GitHub's API by the asset's id, with a
     download strategy of its own that sent `HOMEBREW_GITHUB_API_TOKEN`,
     and `app/release-upload` sent the tap the asset's id beside the
     version and sha256, as the only way to download from a private
     repository. Now the cask names the zip's public URL by version, with
     no strategy, no `asset_id` and no token, `livecheck` reads GitHub's
     latest release where it had skipped, and the tap's workflow takes the
     version and sha256 alone. A Mac that installed with a token needs
     nothing new: its next `brew upgrade` takes the new cask.
   - **Where the build runs**: in `pre_tag`, before the tag, since 5
     November 2026 (see "Why before the tag"). On 28 October 2026 Lee chose
     `post_release`, after the tag and the push, where `app/release` built,
     notarised and uploaded, a failure leaving the release without its zip
     and the cask on the last version until `app/release <version>`, run
     again, built and notarised again.
   - **The first release:** 0.3.0, cut on 28 October 2026, once the tap's
     branch with the cask and the workflow's `sitrep` had merged in
     `leeovery/homebrew-tools`; its dispatch replaced the cask's
     placeholders. Then this Mac moved onto the cask: `app/build`'s
     `~/Applications/SitRep.app` went first, since two copies with one
     bundle id let Launch Services, the login item and a banner's click
     pick either, and the clone stopped being the marketplace; the cask
     installed SitRep like any other Mac's, and the plugin comes from
     SitRep's copy. `app/build` installs over `/Applications/SitRep.app`,
     and `app/plugin` points the `sitrep` marketplace at a checkout for a
     live test, and back (see "Where it lives"). Still to come: kit
     declares the cask, its `[manual]` step giving way to it. Whether
     `claude plugin update` follows `main` or the tags was left to settle
     for the plugin alone from GitHub, which went as the plugin and the
     app came as one (27 October 2026).
   - **A new Mac's first start:** the welcome window (see "The welcome
     window"), approved on 2 November 2026. It is built with the Settings
     window, approved the same day, Settings moving out of the SitRep
     window into a window of its own laid out as Xcode 27's (see
     "Settings"), as the welcome's steps hand on to it.
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
   `portal-rex` were on 13 October. Folded into stage 7 as its step C (9
   November 2026), for zmx as for tmux: one open command, a setting; and
   into stage 8's one resume command on 13 November 2026.
7. **The Mac's work moves into SitRep**, planned with Lee on 9 November
   2026 (see "The structure"): the jump and on screen first, at parity with
   the CLI's; then the CLI's retired; then a window opened for a session no
   terminal shows (step D, a Space chosen to open it on, dropped with Lee
   on 10 November 2026). Each step is a PR of its own, leaving SitRep
   working, with DESIGN brought up to date in it.

   **A. The jump and on screen in SitRep**, at parity with the CLI's (see
   "The jump"): the tmux and zmx adapters, the innermost of two, the seat,
   Ghostty's driver by tty, a tab not selected activated with its half
   second's pause, the front kept, an app with no driver brought forward
   whole, the order places are tried in and a place that fails giving way,
   unknown never taken for off, and the refusals in the same plain words.
   The latest click still wins (`OneJump`), and the caption and banners
   say what they say now. **Built on 9 November 2026**, in three PRs
   (below): SitRep has made its own jump since the third.
   - **Decided:**
     - **Apple Events sent from Swift**, not through osascript. The leave to
       control Ghostty is SitRep's already, though the CLI's osascript asks
       (stage 3, step 1), so nothing new is asked. Ghostty is found running
       by `NSRunningApplication`, not by asking it.
     - **Processes from the kernel**, not `ps`: one `sysctl`
       (`KERN_PROC_ALL`) gives every process's parent and terminal device,
       `proc_pidpath` a process's program, exactly, and its command line
       (`KERN_PROCARGS2`) is read only where it is needed, a zmx client's.
       The program read from `ps`'s command line up to its first option or
       path goes, and so do its known misreadings, and the UTF-8 character
       type the CLI gives `ps`. This absorbs the parked "skip `ps`": the
       seat still walks the ancestry, from the kernel's table.
     - **The front heard, not polled**: the app in front as the jump begins
       is NSWorkspace's `frontmostApplication`, and the hand-back is heard
       as `didActivateApplicationNotification` within the same second, in
       place of lsappinfo every 50ms. Ghostty is brought forward again
       through LaunchServices (`NSWorkspace.openApplication`), as `open -b`
       brings it now, with no Apple Event; so is an app with no driver, once
       `NSRunningApplication` finds it running, never launched.
     - **tmux is still asked through its program**, `tmux -u` as now, 2
       seconds a run, and so is the select.
     - **Which window first stays core's**, as SitRep repeats no board
       rule: the order a jump tries a session's windows in
       (`windowsOf`) is core's (`core/windows.ts`), and `watch` carries
       it as each window's `jumpOrder`, so SitRep never ranks windows
       itself (built 9 November 2026, as A1). SitRep
       jumps from the watch's last line, at most a look old, where the CLI
       read the board as it started.
     - **The limits carry over**: 2 seconds for each tmux run, 5 for each
       Apple Event, 15 for the whole jump. osascript's 8 seconds go with
       osascript, and exit 3 with the CLI's jump.
     - **On screen** is read in Swift as the jump reads it, its three states
       as `sitrep screen` gave them. Nothing shows it until step C: SitRep
       has not run `screen` since its window went (5 November 2026). Since
       stage 8's rethink (13 November 2026) the rows show it, as here or
       not, read every few seconds.
     - **Proposed, and built (A3):** the events built by hand
       (`NSAppleEventDescriptor`, each sent with its 5-second timeout, off
       the main thread), not `NSAppleScript`, which runs on the main
       thread, where a Ghostty not answering would freeze every surface for
       its 5 seconds. A jump stopped by a later click is cancelled between
       its steps; an event in flight is not recalled, as now, and the next
       jump does not wait on it, since Ghostty handles events in the order
       sent, so the later click's focus lands last: a test pins the first
       two, and a live run must prove the last. The drivers, the adapters
       and the reading in a library target of their own beside
       `SitRepCore`, `SitRepScreen`, with a test target of their own.
   - **Tests:**
     - **Today's TypeScript tests are the spec**: `tests/jump.test.ts`,
       `tests/screen.test.ts` and `tests/onscreen.test.ts`, 110 between
       them, each rule pinned again in Swift. They went in step B, with
       what they tested (10 November 2026). The
       window order's three went to `tests/windows.test.ts` with it (A1),
       core's, so Swift pins none of them.
     - **Swift test doubles** for the process table, tmux, Ghostty, the
       front and the clock, each a protocol the real one fills.
     - **Fixtures small, or built in code**: a process tree made by a
       builder (an app, its child on a tty, a relay, a client), never a long
       literal. Big Swift literal fixtures crashed the compiler three times
       (20 and 22 October and 4 November 2026).
     - **Parity, live and read-only**: SitRep's reading beside `sitrep
       screen --json` over Lee's own windows, every session the same state
       and app; and the kernel's table beside `ps`'s snapshot, each
       process's parent, device and app the same, as the command line was
       checked against `comm` on 9 November 2026. Then jumps with Lee's go:
       under zmx through Portal, to a tab not selected on another Space,
       with Finder in front.
   - **Settled with Lee** (9 November 2026): at A's merge SitRep switches
     to its own jump outright, with no hidden setting to go back to the
     CLI's; the last release is a `brew reinstall` away.
   - **Risks:**
     - **An older Ghostty's refusal** must be found again: osascript's
       -2753 and -2741 were its words, and events built by hand fail
       otherwise. This Mac runs Ghostty 1.4.0, so it is found as those were,
       by sending the events to an app without the terms.
     - **Bringing forward from SitRep**: macOS 14's cooperative activation
       may treat an activation SitRep asks for unlike `open`'s, so the front
       kept is proven live before it replaces `open`.
     - **Another user's processes**: `login` runs as root, and its command
       line cannot be read; the seat needs only its parent and its device,
       which `KERN_PROC_ALL` gives for every process. The parity check
       confirms it.
     - **What a jump costs is measured, not assumed**: it loses Bun's
       start, `ps` (60–120ms) and osascript's start (60–74ms), leaving
       mostly Ghostty's own 200–300ms.
     - **A window attached within the last look** is not yet in the
       watch's line, so not tried.
   - **Built in three PRs**, SitRep unchanged until the last: A1 moves the
     order a jump tries a session's windows in into core, carried by the
     watch's line; A2 reads on screen in Swift; A3 brings Ghostty's driver
     by Apple Events, the front and the jump, and switches SitRep to them.
     - **A2, built on 9 November 2026**: `SitRepScreen`, a library target
       beside `SitRepCore` with a test target of its own, which nothing
       called until A3. The kernel's table, the seat, apps by their program's
       path, the tmux and zmx adapters, the innermost of two, and the
       three states, each rule of the TypeScript tests pinned again, read
       from the watch's own `Where`, which gained its zmx session. Where it
       differs from the CLI's:
       - **A program replaced on disk as it ran**, an app updated under
         it, is one `proc_pidpath` cannot tell (ENOENT, live: Claude's and
         Mac Performance Monitor's), which the plan missed: there the
         program is the path it was started by, from its command line. A
         Ghostty updated while running would otherwise have read every
         session off screen.
       - **A zmx client's command line is read only where its program's
         file is named `zmx`**, which keeps the reads to a few a look, so
         a zmx installed under another name reads off screen.
       - **One zmx session's clients are tried oldest first**, by process
         id, where `ps` listed them by terminal, then id.
       - **Places with no device are told apart by their app**, so two
         windows in iTerm2 bring it forward once. The CLI compared each
         app as an object it made afresh, so it merged none.
       - **A device that is no tty is none**, as core's `parseWhere` drops
         it.

       The parity check, run live the same day: 1,388 processes in both
       the kernel's table and `ps`, each with the same parent and device;
       the same app for each of the 260 the CLI found in one, and 3 more
       the CLI's reading of `ps` missed, helpers whose command line starts
       with no path; and the same places for each of 12 zmx sessions, all
       through Portal's relay.
     - **A3, built on 9 November 2026**: SitRep's own jump (see "SitRep's
       own jump", under "The jump"), `Jump` in `SitRepScreen`, and SitRep
       switched to it outright: every click, from the notch, the strip, the
       menu, Settings or a banner, runs it through `OneJump`, and none runs
       `sitrep jump`, which step B deleted with `SitRepCLI.jump`. The
       watch's windows are read with their `jumpOrder`, which the watch's
       line did not print until A3's review found it missing (A1 had core
       give each window one, but `watch` wrote none out); a line from a
       watch before it is jumped from in its own order. Each rule of
       `tests/jump.test.ts` on the flow, the front, the focus's answers,
       the order, the limits and the words is pinned again in Swift, with
       doubles for Ghostty, the Mac's apps and the clock, fixtures built in
       code; so are the latest click winning, a jump stopped between its
       steps, and the next not waiting on an event in flight. Where it
       goes another way than the CLI's:
       - **The window of a tab not selected** is asked for, then
         activated, in two events, where the program's `activate window
         (first window whose …)` was one: the window as Ghostty names it is
         one AppleScript itself sends back, as the lookup's terminal is.
       - **The hand-back is heard from before the lookup**, so one landing
         between a window's activation and its terminal's focus counts.
       - **An app with no driver found by its bundle's path** is looked
         for among the running apps before LaunchServices is asked, where
         the CLI took `ps` seeing its program as proof it ran.
       - **The words** where the CLI's no longer fit (listed under "SitRep's
         own jump"): "the process table" for `ps`, osascript's sentence
         for -1743 without its prefix, "Ghostty got an error: … (n)" for
         any other, SitRep where Ghostty's refusals said sitrep, the CLI's
         no such session without its id, and the board not there for a
         jump that ran out of time waiting for one.
       - **A Ghostty too old** by -1708 or -1728 on the lookup, in place of
         AppleScript's -2753 and -2741; expected, not yet seen.
       - **A jump reads the board of a watch running and printed**, waiting
         for the next line while the watch starts, starts again or is
         stale, within its 15 seconds, then refused in the watch's words;
         at once in the plugin's with none to run the watch.
       - **A session with no row and no window** is named by its project's
         list on the line, as the CLI named it by its status.
       - **Events are sent by `AESendMessage`**, so an error Ghostty gives
         keeps its words, which `sendEvent`, throwing, drops.
       - **No program limit beside the jump's own**: osascript's 8 seconds
         and the CLI's exit 3 went with them.
     - **To prove live, with Lee's go** (nothing of it was run in building
       it, as each moves Lee's screen or asks macOS for a leave):
       1. No new prompt: SitRep, which held the leave to control Ghostty
          for the CLI's osascript, sends its own events under it.
       2. A jump under zmx through Portal, to a selected tab on another
          Space, with Finder in front: the slide, the terminal focused, and
          typing going in with no click, the front kept by
          `NSWorkspace.openApplication` from SitRep under macOS 14's
          cooperative activation.
       3. The same to a tab not selected: the slide to the window's Space
          and the right tab, not the tab brought to Lee's Space. Watch the
          hand-back there: one heard between `activate window` and the
          focus, in the half second's pause, settles the hand-back's watch
          before the focus, so Ghostty is brought forward again at once,
          and a second hand-back after the focus is not put right. Should
          the front be lost after that slide, the watch is to begin at the
          focus, or hear more than one hand-back.
       4. Two clicks on two sessions in quick succession: the second
          lands, the first says nothing.
       5. The too old codes: `LiveEventsTests` sends the lookup to
          Calculator and TextEdit, each read as too old: -1708 (no handler
          takes Get Data) or -1728 (no specifier naming a terminal's `tty`
          resolves) on the lookup alone, the reading not yet seen.
       6. What a jump costs, from SitRep's log (`jump`): Bun's start, `ps`
          and osascript's start gone, so mostly Ghostty's own time.
       7. Events sent by `AESendMessage` land as `sendEvent`'s did: the
          lookup answers with the terminal, a selected tab's question with
          `{{true}}`, and a jump to a terminal closed since it was found
          shows Ghostty's own words in its banner.
       8. A jump clicked as SitRep starts, before the watch's first line,
          lands once the line comes; and a session in two windows, one
          stopped on Lee, is jumped to that one, as the watch's line now
          carries each window's `jumpOrder`.

       **Proven live on 10 November 2026**, by Lee, with this Mac's build:
       - **1 and 2, 6 too**: no new Automation prompt, and a Portal session
         on another Space reached with Finder in front, several times: about
         40ms of the jump's own work, then the second's watch for the
         hand-back (SitRep's log: "jumped, in 1,041ms").
       - **3**: a session in a tab not selected, on another Space: macOS
         slid there, the tab showed, and his typing went in.
       - **A session no window shows** was refused as "SitRep could not
         jump / <name> is not on screen: no terminal window on this Mac
         shows it.", and reached again once its window was reopened.
       - **A notification's click** from another Space brought him to the
         session.
       - **4, dropped**: a jump acts in about 40ms, so a second click
         cannot overtake it by hand; the tests cover the latest click
         winning.
       - **5, parked**: `LiveEventsTests`, the too old codes, not run.
       - **Ghostty already in front** as a jump begins was not run on its
         own.

   **B. `sitrep jump` and `sitrep screen` retired** from the CLI once
   SitRep calls neither: `screen` had had no caller since the SitRep window
   went, and was kept only for A's parity check; `jump` once SitRep's own
   had replaced it.
   - **Built on 10 November 2026**: every file the list below names went,
     with its tests (`tests/jump.test.ts`, `tests/screen.test.ts`,
     `tests/onscreen.test.ts` and `tests/locale.test.ts`), and the CLI's
     test world lost its fake tmux, zmx, `ps`, lsappinfo, `open` and
     Ghostty. The CLI's `Io` has no `run`, so it runs no program, and `list`
     needs no test that it runs none; `jump` and `screen` left its commands,
     its help and its exit codes (exit 3, an app unanswered, with them), and
     `screen --json`, which only the on-screen reading filled, went whole;
     `list --json` and `watch` lost no field. In SitRep, `SitRepCLI.jump`,
     its limit, grace and exit status, and `Stopping.gently` went; so did
     A2's parity check (`ParityTests`), which ran the CLI's reading of
     `ps`. What stays: core's `where.ts` and the mod recording `where`, as
     the watch carries each window's and SitRep jumps from it; core's
     `windows.ts`, the order the watch's `jumpOrder` gives, and its
     `windowsOf`, which only the tests read now, as the order's statement;
     and `Stopping.group`, which SitRep's tmux and every run of the CLI
     are still ended by.
   - **Decided:**
     - **What goes**: `cli/jump.ts`, `screen.ts`, `processes.ts`,
       `tmux.ts`, `zmx.ts`, `ghostty.ts`, `front.ts`, `apps.ts`,
       `driver.ts`, `multiplexer.ts`, `look.ts` and `locale.ts`, the Bun
       binding's runner of programs, and their tests; in SitRep,
       `SitRepCLI.jump`, and `Stopping.gently`, which only the jump used.
       The CLI then runs no program at all.
     - **It absorbs the parked "let the CLI own the jump's safety"**
       (nothing built for it: it went with the jump), a
       lock every caller of `sitrep jump` takes and no AppleScript left
       running when a jump is killed: no CLI jump is left to lock, SitRep's
       `OneJump` is the one caller's lock, and no osascript runs.
     - **The mod is untouched**: it records `where` as now, and `watch`
       still carries each window's.
   - **Settled with Lee** (9 November 2026): nothing of his runs `sitrep
     jump` from a shell or a script, so after B a jump comes only from
     SitRep.
   - **Risks:** few. The plugin and SitRep ship as one, so no SitRep runs a
     CLI without the jump it needs.

   **C. A window opened for a session no window shows**: one a live window
   holds, alive in its multiplexer with no client in a terminal app, which
   a jump refuses today as not on screen. Stage 6 is this step. Its shape
   was settled with Lee on 10 November 2026, replacing what the plan of 9
   November said (an attach command for each multiplexer, and a Space
   picker, step D, now dropped). **Superseded on 13 November 2026** by
   stage 8's rethink: a session no terminal on this Mac shows, held or
   away, is dimmed, and its click runs the one resume command, into
   which the open command's attach folds; the open command, its
   placeholders and its separate path go. What follows is the record of
   what was decided, built and proven live, and stands as that.
   - **Two concerns, kept apart:**
     - **Discovery is the multiplexers'**: the tmux and zmx adapters read
       whether any terminal shows a session (step A), and give the facts a
       session's window recorded: its zmx session's name, its tmux socket
       and pane. They know nothing of opening.
     - **Opening is the settings'**: SitRep has no built-in way to attach.
       It opens a window in the terminal Lee chose and runs the one command
       Lee gave it there.
   - **Decided with Lee** (10 November 2026):
     - **One open command, a setting**, empty until Lee gives one: for Lee,
       `portal open -s {session}`. SitRep knows no Portal, no `zmx attach`
       and no `tmux attach`: what the command does is the user's, and
       whether it works is the user's too.
     - **Placeholders**, filled from the facts of the session's live
       window, each value quoted for the shell: `{session}` (the zmx
       session's name, `$ZMX_SESSION`; in tmux, the name of the session
       holding Claude's pane, asked of tmux as the window opens, as tmux
       sessions can be renamed), `{socket}` and `{pane}` (tmux's). A
       command naming one the session has no fact for, or one SitRep does
       not know, is refused at the click in plain words.
     - **The terminal, a setting**: a menu of the terminals SitRep has a
       driver for, Ghostty alone today. Used only to open a window: a jump
       reads which app shows a session from the processes, and needs no
       setting. Inferring it was weighed and left: as a window is opened
       no terminal shows the session, so it could only be the terminal the
       session started in, which need not be the one wanted.
     - **The terminal driver opens the window**: a new window running the
       user's own login shell, with the filled command typed in as its
       first line and a return (Ghostty's `initial input`), then focused,
       and the terminal kept in front as a jump keeps it. So the command
       runs with the user's own PATH and environment, as if typed by hand,
       and a detach leaves the user at the prompt. SitRep closes no window,
       ever, and sets nothing on how a window ends.
     - **On the current Space.** No Space picker: SitRep takes Lee to a
       window wherever it is, and choosing where a new one goes is outside
       that. Lee moves the window after, or goes to the Space first.
     - **Only where SitRep knows no terminal shows the session**: never on
       unknown, which could make a second window of one already there;
       never for a window in no multiplexer, as closing its terminal ended
       its Claude, leaving nothing to attach to; never on an away row,
       which stage 8 carries on.
     - **A command that fails** shows its own error in the window it
       opened, at the user's prompt: SitRep does not watch it.
     - **Only into a terminal already running**: SitRep never launches it
       (Ghostty's `new window` would, and Ghostty opens a first window of
       its own as it starts), and says so in plain words.
     - **One window per click**: an opening is remembered for 10 seconds,
       so a second click while the new window's shell starts opens no
       second window.
     - **What SitRep says**: the caption "Opened a window for <project>"; a
       refusal's banner "SitRep could not open a window", with why.
     - **A session gone needs nothing new.** When its Claude ends, its
       window stops beating, and within 90 seconds (at once on a clean
       exit) no live window holds the session: it reads as no window
       holding it, and there is nothing to open. A click in those seconds
       runs the command, and the command's own error says the session is
       gone (Portal's `-s` never makes one). A new Claude that takes the
       session up, by `claude --resume` or by joining it, beats with its
       own window's facts, and the session can be jumped to or opened
       again, by its new name.
   - **Settled with Lee** (9 November 2026), still standing: a click opens
     the window at once, where a jump is refused today, with no "Open in a
     New Window" beside Jump; a new window, not a tab; an away row stays
     parked (a Claude started to carry its session on is a feature of its
     own: stage 8).
   - **Probed live** (10 November 2026, with Lee's go), which settled the
     typing above: Ghostty runs a configuration's `command` as `login -flp
     <user> /bin/bash --noprofile --norc -c "exec -l <command>"`, with
     launchd's PATH (`/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin` and
     Ghostty's own folder: no `zmx`, no `portal`), and keeps the window when
     the command ends ("Process exited. Press any key to close the
     terminal."). A window opened with `initial input` instead ran Lee's
     own shell, his full PATH, the line once his prompt came, and came up
     focused, on the Space he was on, with no Space switch. The typed line
     also shows once above "Last login", echoed by the terminal before the
     shell starts.
   - **Safety, the typing's own**: the line goes through the terminal's
     line discipline and the shell's line editor, which act on control
     characters before any quoting, so a value holding one could erase the
     line typed so far and run the rest. A command or value holding a
     character that does not print is refused, and a placeholder must
     stand as a whole word outside any quotes (found in review, 10 November
     2026).
   - **Risks:** a shell startup file that reads the terminal (an update
     prompt) could take the typed line; tmux's attach by pane id and its
     session name asked by pane are checked on a Mac with tmux before
     relied on (this one has none).
   - **Built on 10 November 2026**, nothing of it run live (each opens a
     window on Lee's screen):
     - **The jump answers what it can open**: where no terminal shows the
       session, the first of its windows, in core's order, that the
       innermost multiplexer it runs in holds alive (`Screen.attachable`: a
       tmux pane on its server, a live window's zmx session) is openable,
       and the jump fills the open command for it (`OpenCommand`). Then
       `Clicks`, in SitRep, opens the window (`Opening`) under `OneJump`,
       as a jump of its own: the latest click wins, and a click on the same
       session before the jump or the opening says it is still under way
       joins it, so a double-click opens one window. An opening has 20
       seconds of its own, past which "SitRep gave up waiting for Ghostty to
       open a window for <name> after 20 seconds; one may still appear."
     - **The facts are the adapters'** (`Multiplexer.facts`): zmx's
       `{session}` is the window's `$ZMX_SESSION`, and zmx is never run;
       tmux's `{socket}` and `{pane}` are the heartbeat's, and its
       `{session}` is asked of tmux (`display-message -p -t <pane>
       '#{session_name}'`) at the click, only where the command names it.
       tmux not on the PATH is told apart from tmux not answering in its 2
       seconds, and from its error, in its words.
     - **The command is read as the shell reads it**: `{name}`, a name of
       letters and underscores, but never after an unescaped `$` or `#`
       (`${…}`, tmux's `#{…}`), nor escaped, nor, in quotes, one whose
       name is no placeholder's; an escaped `$` and `$$` open no `$'…'`;
       backticks are read as quotes, as bash scans `` `…` `` for its
       closing backtick before any quoting inside it, so a backtick in a
       value quoted there would end it (proven in bash in review, 10
       November 2026). Each value is in single quotes, always, never bare,
       as a bare word can be a zsh global alias. Refused at the click, before anything is asked or sent,
       each under the banner "SitRep could not open a window": none given
       ("No terminal window shows <name>. To open one for it, set an open
       command in Settings."); a character in it that does not print; a
       placeholder SitRep does not know; one in quotes, or joined to other
       text; one the session's multiplexer gives no fact for ("<name> runs
       in zmx, which gives no {pane}. A zmx session gives {session}."); and
       a fact holding a character that does not print, a tab, a line break
       and an escape by name, the rest by their code point.
     - **Ghostty's driver** opens the window as probed: `new surface
       configuration` (`GhstNSCf`), its `initial input` (`GScI`) the line
       and a return, then `new window with configuration` it (`GhstNWin`,
       `GNwS`); then `focus` on `focused terminal of selected tab of` the
       window Ghostty answered with (`GTfT` of `GWsT`), and Ghostty kept in
       front as a jump keeps it. Once `new window` answers, the window is
       opened, whatever the focus does. Whether Ghostty runs is read as the
       opening begins; one quit since is sent nothing. A Ghostty that takes
       no `new surface configuration` (-1708) is too old to open a window,
       in plain words; `new window` unanswered in its 5 seconds says a
       window may still appear.
     - **One window per click** (`RecentOpenings`): an opening is
       remembered as it begins, and again as `new window` is about to be
       sent, so a slow first event costs none of its 10 seconds, and
       forgotten only where it failed before it was sent:
       Ghostty not running, its first event refused, or the opening stopped
       before then. A click on the session meanwhile, with no terminal yet
       showing it, opens nothing, posts no banner and hands the front back.
       Given up at its 20 seconds, an opening says a window may still
       appear only where `new window` was sent.
     - **The captions** name the project, as "Jumped to <project>'s
       window" does: "Opened a window for <project>"; "A window for
       <project> is opening" for a click on one opening already; and
       "Still opening…" for an opening two seconds on, as a jump says
       "Still jumping…".
     - **Settings**, General's New windows (see "Settings"); the terminal
       chosen is the driver the opening goes through.
   - **Known limits:** the typed line assumes a POSIX shell (zsh, bash,
     sh), not fish. Under a bash login shell in a locale that is not UTF-8,
     readline reads a value's non-ASCII bytes as Meta keys; Ghostty sets a
     UTF-8 `LANG` where none is set, so only a startup file setting `C` or
     `POSIX` meets it.
   - **To prove live, with Lee's go:**
     1. With no open command, a click on a session no window shows: the
        banner says to set one in Settings, and nothing opens.
     2. With `portal open -s {session}`, a Portal session detached from
        every window: a new Ghostty window on the Space showing, his
        shell's prompt, the line typed and run, and the session attached,
        focused, typing going in with no click, Finder in front as it
        began.
     3. A double-click on it, and a click again within 10 seconds: one
        window.
     4. Ghostty quit, a click: the banner says to open Ghostty, and Ghostty
        does not start.
     5. A notification's click on a session no window shows, from another
        Space: the window opens on the Space showing.
     6. On a Mac with tmux, `tmux attach -t {session}` and `tmux -S
        {socket} attach -t {pane}`: tmux names the session by the pane, and
        attaches by the pane's id.
   - **Proven live on 11 November 2026** (this Mac's build of #112): 2,
     twice, on Portal session `Portal-709WBV`: the window opened, the line
     ran, the session attached; a click straight after closing a window
     opens one, as the screen is read at the click, not from a heartbeat.
     3: a double-click, both clicks taken, opened one window. Not run: 1
     and 5 (the tests cover them); 4, as quitting Ghostty closes every
     window Lee has; 6, as this Mac has no tmux. A row no terminal shows
     looks as any other: rows show the board, and whether a terminal shows
     a session is read at the click. Until 13 November 2026: since stage
     8's rethink such a row is dimmed, read every few seconds, and its
     click runs the resume command.

8. **An away row carried on**, decided with Lee on 12 November 2026 and
   built that day (#119), then rethought with him on 13 November 2026,
   after its first live test, as **a session this Mac doesn't show, carried
   on by one command**. The rethink is the rule. The build of 12 November,
   under "As first decided and built", is the record, each part the rethink
   supersedes marked so. The next PR brings the code to the rule (below,
   "The plan for the next PR"); until then the build runs as recorded.

   **The first live test** (13 November 2026), this Mac's build of #119:
   after Lee ended a Claude with `/exit`, its row's click took him to a
   Ghostty window holding a bare shell. The build reasoned from the place a
   Claude last ran, not from the Claude: a window still showing the
   session's zmx session got a jump; a zmx session still alive got an
   attach by the open command; only otherwise did the resume command run. A
   zmx session outlives the Claude in it, so the place was there and the
   Claude was not. Lee: SitRep exists so he can answer what Claude asks of
   him, so a click must land him on a Claude. And "Sitrep should have no
   knowledge of Portal": Portal enters only through a command Lee
   configures.

   **The rule** (decided with Lee, 13 November 2026):
   - **Here.** A session is here only when its Claude is live, a window
     holding it on the board, as now, and a terminal on this Mac that
     SitRep can take Lee to shows that Claude. Shown is either:
     - its terminal's ancestry reaches a terminal app the jump can bring
       forward; or
     - the ancestry of a multiplexer client attached to its multiplexer
       session does.

     Any terminal app counts, not only Ghostty: Ghostty by its driver, the
     others brought forward whole, as the jump brings them today. An
     ancestry that reaches sshd or another remote login does not: Lee's
     phone or iPad over SSH, rootshell, or Portal there. A window behind
     others, on another Space or minimized counts, since the jump reaches
     it. An away session is never here. Here is the app's alone: core's
     held and away are unchanged, and the feed says nothing of it. New
     windows still open in the terminal chosen in Settings.
   - **How it is read.** From the process table, by a read of its own: the
     jump's reading stays as it is, proven, and Lee wants it left alone.
     For every live window on the board at once, the table read once, and
     tmux asked for its clients where a window runs in it: a window in a
     multiplexer is here where a client of its session is seated in a
     terminal app (`Processes.seat`, the step the jump seats its clients
     by), a tmux pane in a tmux window no client has current counting where
     a select would show it, as the jump makes one; a window in no
     multiplexer is here where a process on its device has a terminal app
     among its ancestors. The heartbeat's `$TERM_PROGRAM`, which the jump
     goes by outside a multiplexer, is not read: a Claude reached over SSH
     whose shell carries Ghostty's is not here. Read every few seconds and
     on each watch line, one read at a time, off the main thread; and read
     again at the click, the same read of the seats alone, which picks the
     way: here, the jump, exactly as today; not here, the command. Where
     the jump and the read disagree, the heartbeat saying Ghostty and the
     ancestry sshd, the read decides. A session here whose jump then fails
     is refused in the jump's words, as today, and nothing starts. Since
     20 November 2026 the same read tells who views each held session (see
     "The board in a terminal"): every client showing it gives a viewer, `mac` where it is
     seated in a terminal app here, as above, or `ssh:` and the address in
     its `SSH_CONNECTION` where an SSH login reached it, OpenSSH's or
     `tsshd`, trzsz-ssh's, which Lee's phone reaches the Mac through.
     `tsshd` joins the remote logins `seenFromHere` cuts from their
     parents, which the notch and the click go by too, and changes nothing
     either shows: it runs under launchd, so no ancestry through it ever
     reached a terminal app. Only that variable is read from another
     process's environment, and only its first field kept. A session is
     here where `mac` is among its viewers, so the notch is unchanged. The
     read also maps each zmx session's tty, and each tmux pane's, to its
     viewers, reading the command line of each zmx server beside its
     clients'. The click's read reads neither, nor any environment. Each
     read is written to `here.json` while any session is held (see
     "Storage"), for the board in a terminal, which reads it at every look:
     the one reader of here outside the app. That costs a debug build's
     read 28ms against 23.5ms, over 1,317 processes and 25 zmx sessions.
   - **What the read costs.** It asks Ghostty nothing, as `sitrep screen`
     did not (6 November 2026): no Apple Event, so no prompt for leave to
     control Ghostty and no 5 seconds' wait on a locked screen. The
     kernel's table is read once: one `sysctl`, `proc_pidpath` for every
     process, the command line of each whose program is zmx, and each
     window's ancestry walked through it. tmux is asked through its
     program, a subprocess, as the jump asks it:
     `list-panes -a` and `list-clients` for each socket a live window runs
     under, the two at once, each with its 2 seconds. So a tmux user pays
     two runs of tmux a socket at each read, and a server that hangs costs
     its 2 seconds at each read, its sessions unknown meanwhile. On Lee's
     Mac, with no tmux, none run. Measured on Lee's Mac (an M1 Max, 13
     November 2026), over its real table of 1,336 processes, 46 sessions
     read at once, 33 of them in zmx and 14 here: the whole read 23ms in a
     release build (30ms in a debug one), the table's own look 5ms of it,
     where `ps` had answered in about 60ms (6 November 2026). So it runs
     every **3 seconds** between the watch's lines, under 1% of a core,
     and a row's look lags the screen by about that at most. A first cut
     seated every process on a window's device, 120ms in a debug build;
     the read seats only the processes on a device whose parent is on
     another or none, through which all the rest descend.
   - **Where it can't tell.** The read's unknown, as the jump's (tmux not
     answering, or answering an error other than no server; the table
     giving no answer), is never taken for not here, as the jump never
     takes unknown for off: a row keeps the look it last read, and one
     never read is drawn as here. At the click an unknown is refused in the
     jump's words ("Could not tell whether <name> is on screen: …"), and
     nothing starts.
   - **The rows.** A session not here is drawn with the away look, dimmed,
     a hollow ring where an ask waits, wherever rows are drawn: the panel,
     the strip and the menu bar's menu. A session a window holds that this
     Mac doesn't show, working, your turn, on its own work or needs you,
     stays on the panel dimmed, keeping its state: its section, its words
     and its mark, but for the hollow ring where an ask waits (Lee's
     choice). Its place in its section stays core's, which knows nothing of
     here, so a held session needing Lee is not put among the away ones at
     Needs you's end. An away session with
     no Claude and nothing waiting stays off the panel, as now. The away
     look is drawn in Paper only for Needs you; a dimmed working, your-turn
     or on-its-own-work row is not drawn yet.
   - **The click.** On a session here: the jump, unchanged. On a session
     not here, from its row, its strip mark or tab, its menu bar row, its
     right-click Jump or its notification:
     - a Claude of that session suspended (Ctrl-Z) where this Mac shows it
       keeps the rule built on 12 November 2026 (b3ada08): the jump, saying
       "<name> is suspended in this window: type fg to bring it back.",
       starting nothing;
     - otherwise SitRep opens a new window in the terminal chosen in
       Settings, Ghostty, and types the resume command into Lee's own login
       shell there, with a Return, as step C
       of stage 7 typed the open command. Typed at a prompt, a one-liner,
       an alias, a function or a script all work.
   - **One command, the resume command**, in place of the open command and
     the resume command beside it. Step C's attach of a live session no
     window shows folds into it: what reaches a Claude running hidden is
     the user's command, as what brings back a Claude ended is. Its
     placeholders, each replaced by a value quoted for the shell:
     - `{claude}`: the Claude Code session id of the session's latest
       conversation: the writer the rejoinable rule gives an away session
       (its `lastWindow`), or, for one a window holds, the live writer; of
       several live windows, the one a jump tries first, which gives
       `{dir}` and `{tty}` too;
     - `{dir}`: the folder that Claude ran in, the heartbeat's `directory`.
       A session whose window ran a plugin from before heartbeats said it
       has none, and a command using `{dir}` then refuses, saying so;
     - `{tty}`: the terminal device that session's Claude still runs on,
       filled only while SitRep sees that Claude on it, running or
       suspended, with no later conversation seen on that device
       (`ownsDevice`); otherwise empty, `''`. Devices are reused: after a
       restart, or a Claude's end, a stale device could attach the wrong
       pane.

     `{session}`, `{socket}` and `{pane}` go: SitRep keeps no multiplexer
     knowledge for resuming. The jump keeps what it needs to find windows.
   - **The default**: `cd {dir} && claude --resume {claude}`, pre-filled in
     Settings so Lee sees it, with Restore Default, enabled while the field
     differs from the default. Lee's saved open command is dropped; his
     saved resume command, unset, becomes the default. A field cleared to
     empty refuses, saying to set one or restore the default.
   - **The guard**: the default refuses while that session's Claude is
     still alive but not shown here: a window holds it on the board, or
     SitRep sees its Claude on its device, running (the device its own,
     `ownsDevice`) or suspended, whoever was seen there after, as a later
     conversation started in the shell it was suspended in leaves it there.
     With a Claude seen there: "<name>'s Claude is still running where this
     Mac doesn't show it: set a resume command that can reach it, in
     Settings." Held, with none seen there, as a tab just closed whose
     window holds the session until its heartbeat goes stale: "<name>'s
     window has just stopped answering: try again in a moment." A command
     Lee wrote always runs: what it does is his. The default is told by its
     text, so a command saved the same as it is the default.
   - **One window per click**, kept from the build: a click while an
     opening is on its way opens no second window, until the session reads
     as here or the board holds it. An away session's opening lasts 120
     seconds at most. A session a window held at the click is held already,
     so only here forgets its opening, and its command reaches a Claude
     already running, which reads as here within a read or two: its
     opening lasts 10 seconds, as the build's attach did, so a command that
     failed holds back no click for long.

   **Examples**, recorded as examples, never as SitRep's knowledge:
   - **Lee's Portal one-liner.** Portal's `hook list` maps each Portal
     session to the Claude its resume hook registered, while it runs,
     through a restart, until an explicit `/exit`, tab-separated: the key,
     `on-resume`, the command, the session.
     ```
     s=$(portal hook list | awk -F'\t' -v id={claude} 'index($3, "--resume " id) {print $1; exit}'); [ -n "$s" ] && portal open -s "$s" || portal open -p {dir} -- claude --resume {claude}
     ```
     It attaches the Portal session holding that Claude, running hidden or
     holding Portal's resume panel after a restart; otherwise it starts a
     Portal session in the folder, resuming the conversation. Dry-run
     against the real hook list on 13 November 2026. It is to become a
     Portal command (`portal open --claude {claude} -p {dir}`, say), as
     reading `hook list` belongs in Portal.
   - **tmux, by `{tty}`:**
     ```
     t=$(tmux list-panes -a -F '#{pane_tty} #{session_name}' | awk -v d={tty} '$1==d {print $2; exit}'); [ -n "$t" ] && tmux attach -t "$t" || tmux new -c {dir} claude --resume {claude}
     ```
   - **Claude with no multiplexer:** the default.

   **Settings**, General (see "Settings"): Startup, unchanged; Terminal,
   the Terminal pop-up with Ghostty's leave beneath it in one card; and
   Resume command, a section of its own, its one field pre-filled, with
   Restore Default. Not yet drawn in Paper.

   **Refusals**, in plain words, each under the banner "SitRep could not
   open a window", nothing opened:
   - the field empty: "The resume command in Settings is empty. To carry
     <name> on, set one, or restore the default.";
   - the guard's, above;
   - a `{dir}` with no folder, in the words of 12 November 2026 (below);
   - the command's reading, held to plain shell syntax since 20 November
     2026 (below): a character that does not print; a placeholder SitRep
     does not know; one inside quotes, "The resume command in Settings
     puts {dir} in quotes. Remove them: SitRep quotes each value itself.";
     any other part, named as found, "The resume command in Settings uses
     `(`, which SitRep can't check. Put that part in a script and pass it
     {claude}, {dir} or {tty}, as in ~/bin/resume {claude} {dir}.", a
     backtick named "a backtick"; and a quote or a `$(…)` left open, "The
     resume command in Settings opens `"` but never closes it.";
   - the chosen terminal not running, as an opening's;
   - the process table giving no answer, as the build's: "Could not tell
     whether <name>'s Claude is still running: the process table gave no
     answer.", as `{tty}`, the guard and the suspended rule all read it;
   - here unknown at the click, in the jump's words;
   - a Claude suspended where this Mac shows it, whose window the jump
     could not bring forward, as the build's: "<name> is suspended in its
     window, which SitRep could not bring forward: type fg there to bring
     it back.";
   - an away session with no last window, its conversation one that would
     take up another session: as one no window holds, as now.

   The build's unknown zmx session ("a zmx process's command line gave no
   answer") goes with the read it came from, and its refusal of a Claude
   running on its device narrows to the guard, the default's alone.

   **Plain shell syntax only** (Lee, 20 November 2026). The reader tried
   to refuse each place a shell reads a value again, and each of three
   reviews found more ways for a folder's name to run as code across sh,
   bash 3.2 and 5.3, zsh, dash and ksh: 14 in the last alone, among them
   bash 5.3's `${ cmd; }`, zsh's glob qualifiers and `=(…)`, a `'` in a
   double-quoted `${…}` in zsh, dash and ksh, and ksh93's `x={dir}=(…)`. A
   list of what to refuse can't be finished; a list of what to accept can.
   So both readers, the app's `TypedCommand` and the panel's `lineOf`, one
   machine branch for branch, accept only:
   - words of ASCII letters, digits and `_ . / : @ % + , = -`, and `\`
     with the character after it;
   - a `~` starting a word, or right after its first `=` or a `:` past
     that, as in `PATH=~/bin:~/go/bin`, but never right before a
     placeholder: zsh and ksh read `~'root'` as `/var/root`, through the
     quotes;
   - spaces between words, and `|`, `||`, `&&` and `;`, never a tab,
     at which the shell SitRep types into completes;
   - redirections, `<`, `>` and `>>` to a word, and `>&` or `<&` to a
     single digit, as `2>&1`, which nothing may join;
   - `[` and `]` as words of their own;
   - `'…'`, holding anything; `"…"`, holding what prints but a backtick
     and `!`, and `\` only before `"` or `$`;
   - `$name`, `${name}`, `$?`, `$$` and `$1` to `$9`, one outside braces
     ending at a blank, an operator, a redirection, a `)`, a double
     quote, one of `/ - = , + @ % \ $` or the line's end, and in double
     quotes at a `'` too, as in `"$USER's"`, where every shell ends it:
     zsh reads
     `$x[…]` as a subscript, even in double quotes, `$x:F:…:` as a
     modifier evaluating the `…` as arithmetic, `$12` as
     `${12}` and `$$'…'` as `$$` and `$'…'`, and ksh reads `$x.y` as one
     name; never `$!`, whose `!` an interactive bash or zsh reads as
     history, nor `$#`, whose `#` zsh reads as the length of what follows,
     `$#$(…)` a glob qualifier (all proven 20 November 2026);
   - `$(…)` outside quotes, holding the same, however deep.

   A placeholder stands outside every quote, at the top level or in a
   `$(…)`, joined to a word or not. Anything else is refused, in words
   pointing to a script, and so is a value starting with a dash, which a
   program would read as an option.

   What takes code, a name or a number from its argument still passes as
   words, not refused by name: a builtin that does (`eval`, `trap`,
   `let`, `read`, `declare`, `typeset`, `local`, `export`, `printf -v`,
   `test`'s numeric comparisons, `shift`, `exit`, `return`, `ulimit`, …),
   or an assignment to a variable the shell evaluates (`PS1`, `PS4`,
   `PROMPT_COMMAND`, `ENV`, `BASH_ENV`, and integer ones such as
   `RANDOM`, `SECONDS` and `OPTIND`). A review of 20 November 2026 ran a
   value's `$(…)` or `a[$(…)]` through each. A command passing a
   placeholder to one is Lee's risk, as one passing it to `sh -c` is. So
   is zsh's GLOB_SUBST, an option Lee would set: with it, an unquoted
   parameter or `$(…)` holding a value runs a glob qualifier in it, so a
   command for such a shell puts them in double quotes.

   A seeded fuzz held the reader to the shells (20 November 2026):
   commands made from the grammar's parts and from refused ones, 60% of
   them mutated by random shell characters, each one taken filled with
   hostile folder names and run in sh, bash 3.2 and 5.3, zsh, dash and
   ksh. Its first rounds found zsh's `$$'…'`, `$#$(…)` and `$x:F:…:`, and
   the probes after them `$10:F:…:`. Its last 140,000 commands, 344,664
   shell runs, ran no value, and the Swift reader gave the panel's words
   on each of 60,000 more. With review's changes in, `"$USER's"` and
   `PATH=~/bin` passing, 60,000 more commands, 149,166 shell runs, ran
   none; nor did 6,000 lines typed into an interactive bash 3.2 and 5.3
   and zsh on a pty, 18,000 runs, history primed before each so a `!` in
   a value read as history would break out of its quotes. Both suites
   now hold their reader to 2,000 of the commands, each with the panel's
   line or refusal, in `tests/reader-cases.ts`.

   **Limits**, of the rule:
   - a row's look lags the screen by up to the read's few seconds; the
     click reads again, so it never acts on a stale row;
   - Claude Code run by Node, as npm installs it, is not told by its
     program: one running that way gives no `{tty}`, and the guard misses
     it, so the default resumes beside it;
   - a device a later Claude Code took up with no board session, so no
     heartbeat, reads as the session's own: the default refuses wrongly,
     the safe way, and `{tty}` names that other Claude's device;
   - a window still on a plugin from before `livesOn` that does a `/clear`
     before it reloads leaves its device reading as the ended
     conversation's: the default refuses, the safe way, and `{tty}` names
     the device the next conversation runs on;
   - for up to 10 seconds after a window joins a session it was off, the
     watch's kept read of the session it left can still give that one a
     last window: the default refuses, as its Claude runs on its device,
     and a command Lee wrote runs toward a Claude now on the other session;
   - a resume slower than 120 seconds to reach the board can be clicked
     again, a second window opening;
   - a `claude --resume` Lee runs himself elsewhere, clicked in the seconds
     before it beats, is resumed beside;
   - two sessions a conversation was last seen in within the same
     millisecond are settled by the order they are listed in, the same in
     the feed and the mod;
   - the typed line assumes a POSIX shell, as step C's does;
   - a command passing a placeholder to what takes code from its
     argument, a builtin such as `eval` or `trap`, or an assignment to a
     variable the shell evaluates, such as `PS4` or `RANDOM`, runs what
     the value holds: it is his, as the reader accepts plain syntax, and
     these are words;
   - with zsh's GLOB_SUBST set, an unquoted parameter or `$(…)` holding a
     value can run code; the panel's `-l -c` reads no `.zshrc`, but the
     app's interactive shell does;
   - a command Lee wrote that resumes beside a Claude still running is
     his, as its guard is.

   The build's limits that came from reading the place go with the place's
   reading: a zmx session alive with a bare shell attached as any other; a
   click after a restart, before Portal remade the session, resuming
   beside its resume panel; tmux in zmx passing `$ZMX_SESSION` on; a zmx
   run by another user reading unknown.

   **The plan for the next PR** (13 November 2026), the build of 12
   November wound back to the rule:
   - **Kept:**
     - `TypedCommand` and `ResumeCommand`, with `{tty}` added;
     - the heartbeat's `directory`;
     - `lastWindow`, as `{writer, where, directory, ownsDevice}`;
     - the rejoinable rule for which writer;
     - the suspended rule;
     - the process table's look for Claude on a device (`claude(on:)`);
     - `RecentOpenings`' resume kind;
     - `jumpedSaying` and `openedSaying`.
   - **Removed**, with their tests, so none is left for behaviour that is
     gone:
     - `OpenCommand`, its setting (`openCommand`, read and passed over, as
       `foldsAfter` is) and its placeholders: `Fact`,
       `MultiplexerKind.facts`, `Multiplexer.facts`, and tmux's question
       for the session holding a pane (`display-message`, `TmuxFailure`),
       which only the open command asked;
     - step C's separate attach path: `Screen.attachable`, `Attachable`,
       `Reading.holds`, `Jumped.openable`, and `RecentOpenings`' attach
       kind with its 10 seconds;
     - the `attaches` flag, with core's `isThere`, and `isLatestOn`'s use
       for a zmx session (it stays for the device, which `ownsDevice`
       reads);
     - the attach of a live zmx session: `Screen.leftOf`, `Left`,
       `Reading.isAlive`;
     - the jump to a window that shows a multiplexer session with no
       Claude in it (`Jump.jump(toLast:)`), the jump to an away session's
       last window, but for the suspended rule;
     - the unknown-zmx refusal: `Unanswered.commandLine`, and
       `Processes.unreadable`, which only it read;
     - the reading of zmx servers' command lines: zmx's
       `sessionNamed(by:)`, and its `tellsBy` back to step A's, a process
       of zmx's program on a tty, as only its clients' command lines are
       read for the jump.
   - **Added:**
     - the continuous read of here, from the process table on its own, and
       the dimmed rows for sessions not here, on the panel, the strip and
       the menu;
     - the click by that read, for held and away sessions alike: the jump,
       untouched, the suspended rule, or the resume command;
     - each live window's `directory` in the watch's `windows`, so a held
       session's click has `{dir}`; its `writer` is there already;
     - `{tty}`;
     - a placeholder joined to unquoted text read as allowed, so the
       examples stand as written (`-v id={claude}`, `-v d={tty}`):
       `id='uuid'` is one shell word, as is `--resume='uuid'`. One inside
       quotes or backticks is still refused, as its quoted value would end
       them early. Refused as joined since step C (10 November 2026);
     - the guard;
     - the Settings regroup, the pre-filled field and Restore Default.
       Settings saves every field of "app", so an untouched resume command
       is saved empty, the same as one cleared: the command moves to a key
       of its own, the old `resumeCommand` read where it holds a command
       and taken for unset where it is empty, so a saved empty one before
       the move reads as the default and one after it refuses.

   **Built** (13 November 2026), the first of the next PR's two slices,
   nothing of it run live: all the plan removes, and of what it adds all
   but the continuous read and the dimmed rows. Until the second slice,
   here is the jump's own reading of the screen at the click, as before
   the rethink (`Jump.jumpIfHere`, the one place the continuous read is to
   feed): a session a terminal shows is jumped to, one whether a terminal
   shows it unknown is refused in the jump's words, and any other is
   carried on (`Jump.carryOn`), held or away; no row is dimmed yet.
   - **The window it is carried on from** (`Board.resumeWindow`): for a
     held session the live window a jump tries first, else, none saying
     where it is, the first on the line, its device its own; for an away
     one its `lastWindow`. `MultiplexerKind` went with the open command's
     facts, as nothing else read it.
   - **A line from an older CLI**: a window with no `directory` gives no
     `{dir}`, so a command naming it refuses; a last window with no
     `ownsDevice` gives an empty `{tty}`, and the guard counts a Claude on
     its device as the session's.
   - **The suspended rule**: a Claude stopped on the window's device is
     jumped to where its window shows; where none shows it the session is
     carried on as any not here, the default refusing, as its Claude is
     alive; whether one shows it unknown is refused in the jump's words.
   - **One window per click**: an opening remembers whether a window held
     its session at the click, and the board holding it forgets only one
     that none held; a click that reads the session as here forgets it.
     `openedSaying` went, with `Opening.saying`, though the plan kept it,
     as nothing opens with a word now.
   - **Settings**: the command is saved under "app" as `resume`, none
     until Lee gives one, which reads as the default; Restore Default puts
     it back to none.

   **Built** (13 November 2026), the second slice, nothing of it run live:
   the continuous read, the dimmed rows and the click by the read.
   - **The read** (`HereReader`) is a reader of its own beside the jump's
     `ScreenReader`, which is unchanged. It reads the table once, with zmx's
     command lines, and each multiplexer for its windows, tmux only for
     their sockets. A window in a multiplexer is here where the jump's own
     reach finds a place for it (`Screen.reach`, its clients seated by
     `Processes.seat`); one in none where a process on its device is
     seated, only the device's top processes tried, those whose parent is
     on another device or none. Remote logins (`sshd`, `sshd-session`,
     `mosh-server`) are cut from their parents before any seat, so even an
     sshd started from a terminal's shell shows none of its sessions here.
   - **The click** reads afresh, by a reader made from the jump's own table
     and tmux: here, the jump, whose every failure, its finding no screen
     included, is refused in its words; not here, `carryOn`; unknown,
     refused. So a click on a session here reads the table twice, the read
     then the jump's. A held session whose table gives no answer is now
     refused as unknown, where the jump's reading had carried on one over
     ssh without the table.
   - **The watch** (`HereWatch`, owned by `Works`) reads at each line,
     after the read under way where one is, and every 3 seconds, skipping
     a tick while one is under way; off the main thread, its result taken
     on it. It keeps the sessions read as not here: unknown keeps the last
     look, one never read is here, and a session no window holds drops its
     look at the line that shows it so, and from any read that ends after.
     A session read as here forgets its opening.
   - **The rows**: the panel's board takes the sessions not here
     (`PanelBoard(_:notHere:)`), each drawn with `away` set, its section,
     words, lines and place as core gives them; the menu's likewise. A
     change of here tells the notch and the strip the last board again with
     nothing new on it (`retold`), so nothing swells or washes twice. On the
     strip an ask's mark takes the away look, and other marks keep theirs.
   - **The look**: no new styling. Working and on-its-own-work titles now
     dim by `Away.dim` on the card, the strip's tab and count rows and on
     glass, as a your-turn row's and an ask's did already; the menu dimmed
     every away row's words already.
   - **After review** (13 November 2026):
     - the suspended rule goes by the read of here, never the jump's
       `$TERM_PROGRAM` reading: a Claude suspended over ssh from another
       Mac's Ghostty, its heartbeat carrying Ghostty's, is carried on as
       any not here; one here whose window the jump finds on no screen is
       refused as one that did not come forward;
     - a Claude suspended on the device counts as alive whatever
       `ownsDevice` says, so the default never resumes beside it; `{tty}`
       is still filled only where the device is its own;
     - the guard's words follow the table: a held session with no Claude
       seen on its device has just stopped answering;
     - a held session's opening lasts 10 seconds, an away one's 120;
     - a placeholder in arithmetic or a subscript is refused;
     - a held session's missing folder is its window's, not its last
       window's;
     - each board reaches the edge and the menu before the read of here,
       so a change of here never redraws the board before.

   **To prove live, with Lee's go** (the rule's):
   1. A session whose Claude exited: the click resumes it by the command.
   2. With the Portal one-liner, a Claude running in a Portal session whose
      Ghostty window was closed: its row is dimmed, and the click attaches
      it.
   3. After a restart, the click attaches the Portal session holding
      Portal's resume panel.
   4. A session shown here: the jump.
   5. The default command refusing while the Claude runs hidden.
   6. A session attached only from another device reads as not here.
   7. The notification's click and the menu bar row go the same way.
   8. A dimmed working row and a dimmed your-turn row, seen by Lee, as
      neither is drawn in Paper.

   **Proven live on 13 November 2026** (#121, this Mac's build, the
   Portal one-liner as the resume command): all but 3, which waits on
   Lee's next restart.
   - 1: a Claude ended with `/exit`, its row dimmed with a hollow ring;
     the click opened a Ghostty window, the one-liner found no Portal
     session holding it and started one in the folder, and Claude resumed
     the conversation; the row turned bright as it beat.
   - 2: the same Claude, its window closed, Portal holding its session:
     the row dimmed within a read, and the click attached that session,
     the same Claude, nothing started.
   - 4 and 7: a click on the row shown here jumped to its window; the
     menu bar's row, the window closed, attached it; a new ask's
     notification, the session open only on Lee's phone, attached it on
     the Mac, Portal handing it over from the phone ("Taken by Ghostty on
     this Mac").
   - 5: with the default restored, the click on the hidden Claude opened
     nothing, the banner "SitRep could not open a window" with "Away row
     test's Claude is still running where this Mac doesn't show it: set a
     resume command that can reach it, in Settings."
   - 6: attached from the phone over SSH, the Mac's window closed, the
     row stayed dimmed.
   - 8: "Running sleep 90" dimmed in Working as its window closed, and
     the session's your-turn row dimmed after it.

   Lee's repeated runs of 1, each Claude ended with `/exit` before the
   next click, left one Portal session each, a bare shell: Portal's
   `open -p … -- <command>` keeps a shell after its command ends. Each
   click resumed rightly, as the resume hook's log showed each Claude's
   end (`prompt_input_exit`) before the next; one Claude ran the
   conversation throughout.

   **As first decided and built** (12 November 2026), the record. An
   away session is one no window holds, still current: its Claude ended,
   or the Mac restarted under it, with things still on it. A click on its
   row, its menu's Jump or its notification's click carries it on, by what
   is left of its last window, read at the click as a jump reads the
   screen. **The three cases below are superseded by the rethink** (13
   November 2026): they read the place, not the Claude.
   - **A terminal shows its multiplexer session**: the jump, to that
     window, as for any session.
   - **Its zmx session is alive, no terminal showing it**: the open
     command, as step C of stage 7 runs it, filled from the last window's
     facts (zmx gives `{session}`). For Lee this is the case
     after a restart: Portal brings each zmx session back in its folder,
     and one Claude ran in holds Portal's resume panel, its resume command
     registered by Lee's own Claude hook (`cd <folder> && claude --resume
     <id>`), so `portal open -s {session}` attaches it and Enter brings the
     same Claude back, which takes its board session up again. SitRep
     knows none of this: it attaches, as it would to any session alive in
     its multiplexer.
   - **Nothing is left to attach to**: its multiplexer session gone, its
     last window in none, or no longer its conversation's (below). The **resume command**, a second setting beside
     the open command, empty until Lee gives one, run as the open command
     is: typed as the first line of a new window, on the current Space,
     only into a running terminal, one window per click. Its placeholders
     are `{claude}`, the Claude Code session id the last window ran (its
     writer, which a `/clear` moves on, so the latest conversation), and
     `{dir}`, the folder that Claude ran in. For Lee: `portal open -p {dir}
     -- claude --resume {claude}`, Portal starting a session in that folder
     running the resume, which his hook then registers as any other; with
     no Portal, `cd {dir} && claude --resume {claude}`.
   - **What SitRep reads**: the session's latest window, by its heartbeat
     last seen, gives every fact. Only where its conversation would come
     back to this session: a click on a session runs the conversation that
     takes that session up again (`rejoinable`), so a session whose last
     window moved on to another, live there or not, has nothing to carry on
     from, and its click is refused in plain words. Where the last window is
     no longer its conversation's, the click resumes that conversation in
     a new window, never jumps to or attaches the window: one let go at a
     `/clear` or an in-process `/resume`, its Claude gone on into the next
     conversation there (its heartbeat says so); one in tmux, as a pane id
     does not outlive its server, and the pane it was in, if there still,
     holds a shell its Claude ended in; and one whose zmx session a later
     conversation was seen in, live or let go, on any session: a zmx
     session is the latest conversation's seen in it, which holds that
     one's Claude, or, after a restart, its resume panel. Only zmx keeps
     the attach: Portal brings its sessions back under the same names,
     holding the resume panel that is the point of it. The heartbeat starts saying its folder:
     the Claude process's own, which entering a worktree moves and a
     shell's `cd` does not (Lee's hook anchors the same way, for the same
     reason). A window on an older build says none, so a command naming
     `{dir}` for its session is refused at the click in plain words, as a
     placeholder with no fact is. Since Claude Code 2.1.28x, `claude
     --resume <id>` finds its conversation from any folder: the folder
     decides only where it lands. **Since the rethink** (13 November
     2026) the rejoinable rule and the folder stand; a last window read for
     an attach, and whether it is still its conversation's there, go with
     the attach.
   - **Refusals**, in plain words, as step C's are: an empty resume command
     says to set one in Settings ("No window holds <name>. To carry it on,
     set a resume command in Settings."); a terminal not running, as an
     opening's does; whether a terminal shows it unknown, as a jump's does,
     and nothing opens, a zmx process whose command line does not read
     among the unknowns of an away window's session, as it may be that
     session's. A heartbeat gone stale says only that the beat stopped,
     which a plugin no longer loading (as after `app/plugin app` once a
     worktree went, then a `/reload-plugins`) or a process suspended does
     too. So at the click, before anything is opened or resumed and before
     any command is checked, the process table is read for Claude Code on
     the pty the last window's Claude ran on:
     - **Suspended** (Lee's, 12 November 2026): you suspended it, so SitRep
       takes you to it and leaves bringing it back to you. A Claude Code
       process there stopped (`SSTOP`, as Ctrl-Z leaves it) refuses
       whoever was seen on that pty after, wrongly at worst, the safe way:
       SitRep starts nothing, never types `fg`, as Lee may be busy in that
       shell, and brings its terminal forward as a jump would, or attaches
       its zmx session by the open command where no terminal shows it,
       then says "<name> is suspended in this window: type fg to bring it
       back." in a banner, "SitRep started nothing", the front left with
       the window, the caption saying "Opened a window for…" where an
       opening is what took him there. Where it cannot bring the window
       forward, the open command unset or refused, or no reader for its
       multiplexer, among it, it still says so: "<name> is suspended in its
       window, which SitRep could not bring forward: type fg there to bring
       it back."
     - **Running**, on a pty still the conversation's (no later one seen
       on it): no resume ("<name>'s Claude may still be running in its
       window, on <device>, so SitRep starts no second. Quit it there, or
       carry it on in that window."). One running on a pty a later
       conversation was seen on is that one's, and refuses nothing. A zmx
       session the click may attach is attached first, as before.
     - **Unknown**, the table giving no answer: refused, as a jump is
       ("Could not tell whether <name>'s Claude is still running: the
       process table gave no answer."). No row is marked for a suspended
       Claude: Lee parked that.

     **Since the rethink** (13 November 2026): the suspended rule stands,
     for a Claude this Mac shows, its attach by the open command gone; the
     table's unknown stands; the running refusal narrows to the guard,
     which only the default command meets; whether a terminal shows the
     last window, and a zmx process's command line not reading, go.
   - **One window per click**, for a resume as for an opening: a resumed
     Claude reaches the board only once its terminal session is made,
     Claude started, the plugin loaded, the session taken up and a beat
     written, which can run past an opening's 10 seconds. So a resume is
     remembered until the board shows a window holding the session, 2
     minutes at most; the open command keeps its 10 seconds, as its client
     makes the next click a jump. Kept by the rethink, forgotten once the
     session reads as here or the board holds it; the open command's 10
     seconds go with it.
   - **Limits**, accepted in review (12 November 2026): rewritten for the
     rethink, above, and those that came from reading the place dropped.
   - **Settings**, General's New windows: the resume command under the open
     command, the same literal field. Superseded by the rethink: one
     command, in a section of its own (see "Settings").
   - **Looked up in Portal** (12 November 2026), not built against:
     `portal open -s` attaches and never makes a session; `portal open -p
     <dir> -- <cmd>` makes one in that folder running the command; a
     session Portal restores comes back holding its resume panel until
     answered.
   - **Built on 12 November 2026** (#119), nothing of it run live before
     the test of 13 November (each opens a window on Lee's screen). What
     the plan for the next PR removes, above, is superseded here: the
     attach, `attaches`, the reading of zmx servers, and the jump to an
     away session's last window but for the suspended rule.
     - **The folder** is the engine's `$.session.root()`: the session's
       project root, where it started or where `/cd` or a worktree move
       took it, which, by the engine's own word, a shell's `cd` does not
       move; `$.session.cwd()` is the one that follows it. Read as the
       window attaches and at each beat, so a worktree entered shows within
       30 seconds (see "Storage").
     - **The feed** carries each away session's `lastWindow` (see "One
       engine, two front ends"), and SitRep's `Board` reads it. Only on the
       session its writer's conversation takes up as it resumes, the one
       its latest heartbeat on the whole board is in, by `rejoinable`
       itself, never a copy of its rule (found in review, 12 November
       2026): a window that held A, then joined B, then ended left both
       naming it, so a click on A resumed it, and the resumed Claude took
       up B; with B finished, nothing took it up, and each click started
       another. Such a session is refused as any no window holds is
       ("<name> is not on screen"). A first fix that day gave none only
       while that writer was live elsewhere; this rule holds it too. And
       its `where` is left out where a live window is in the same zmx
       session, or the same tmux server's pane (found in the same review),
       so the click resumes the conversation there, a conversation of its
       own, beside the other Claude, never one showing the other session.
       Narrowed in a third review the same day: a `/clear` with the next
       conversation on no board session wrote nothing a live window could
       show, so the click went to the window running it; the leave now
       says `livesOn` (`session.end`'s reason `clear` or `resume`), and such
       a last window says no `where`. A window in tmux says none either: a
       pane id does not outlive its server. The last window is ranked by
       `lastSeenAt`, the one function `rejoinable` ranks by, where it was
       by `seenAt`, so a window that let go after another stopped beating
       is the last. Narrowed again in a fourth review: a zmx session whose
       last Claude belonged to another board session (W1 holding A in
       `kit` exits; a fresh `claude` in `kit` starts B, then ends) was
       attached from A, as only a live window took it, so after a restart
       Enter on the resume panel carried B on. A zmx session is now the
       latest conversation's seen in it, live or let go (`isLatestOn`, in
       place of the live-only `taken`), and a device the same. A fifth
       review found a Claude suspended with Ctrl-Z, a later `claude` in the
       same shell then holding another session, resumed beside: its pty was
       withheld as the later conversation's. So `where` is now given whole,
       with two flags, `attaches` and `ownsDevice`, where `where` and a
       `device` were each withheld before, and the click reads the pty
       first (above).
     - **The click** (`Jump.carryOn`): where the board names a last window,
       the session is away, and what is left of the window is read then.
       A window in a multiplexer is read as a jump reads it: on screen,
       jumped to; off screen and held, opened by the open command; off
       screen and not held, resumed; unknown, refused in a jump's words.
       Only an away window's zmx session is checked against the table
       (`Screen.leftOf`, `Reading.isAlive`); a live window's is held by the
       window, as step C has it. A window in no multiplexer, or saying no
       `where`, is resumed at once, never jumped to by its device, which a terminal may still
       show with Claude gone from it. A session the board shows a live
       window of is jumped to as ever.
     - **An away window's zmx session alive is told by the process table**,
       as no live window is there to prove it: a process of zmx's whose command line
       names the session, its server (`zmx attach <session>` on no tty,
       under launchd, with any command after) or a client. A command line
       is read by zmx's own forms (`zmx help`): `[a]ttach [--labels kv]
       <name> [command...]` and `[r]un <name> [-d] [command...]`, the name
       the first argument after the subcommand and any `--labels`, with its
       value or as `--labels=…`; any other subcommand names none (found in
       review, 12 November 2026; every server on this Mac is `zmx attach
       <name> …portal state hydrate`). A client a jump reaches is still
       only `zmx attach <session>` alone, as step A has it. So the table
       now reads the command line of every process whose program is named
       `zmx`, servers too, where step A read only those on a tty. A
       live window's is not: its heartbeat proves its zmx session alive,
       as before stage 8, the table asked only where its clients show (a
       second review found the first build asking it of live windows too,
       which put step C, proven live, at the mercy of a server's command
       line). zmx is still never run. A command line that does not read
       (`KERN_PROCARGS2` failing, as for a process gone as it is read) is
       told apart from one with none (`Processes.unreadable`): one of a
       process whose program is zmx, by its path, leaves an away window's
       session unknown where nothing names it ("a zmx process's command
       line gave no answer"), never gone, so the click is refused, never
       resumed beside a Claude Portal may yet bring back (found in review,
       12 November 2026).
     - **One command reader for both** (`TypedCommand`): the open command
       and the resume command are read, checked and filled by the same
       rules, each knowing its own placeholders, so `{session}` in the
       resume command is one SitRep does not know there. Refused in the
       open command's words, "The resume command in Settings …"; a
       `{dir}` the last window has none for: "<name>'s last window did not
       say which folder it ran in, as a window on an older sitrep does not,
       so SitRep has nothing to put for {dir}."
     - **The click reads the pty first** (`Jump.carryOn`'s `claude(on:)`,
       found in the fourth review, the suspended case decided with Lee in
       the fifth): before the jump, the open command or the resume, the
       process table is read once for Claude Code on the last window's pty,
       stopped (`kp_proc.p_stat`, `SSTOP`) or running. A suspended one is
       taken to (`suspended`), its word a new answer, `jumpedSaying`, whose
       banner is "SitRep started nothing" and which hands no front back,
       as a jump that landed does; an opening for it says the word once it
       opens (`Opening.saying`), as `openedSaying`, so the caption says a
       window was opened. An opening refused before anything opens falls
       back to the suspended words (found in review, 12 November 2026). Claude Code is told by
       its program's path, as the screen reading told no Claude before: a
       file named `claude` (Homebrew's), or one in a `claude/versions`
       folder, as Claude Code's own installer keeps each version, its file
       named by the version (`~/.local/share/claude/versions/2.1.322` on
       this Mac, 12 November 2026, run through the `~/.local/bin/claude`
       link). Its command line is never read.
     - **The resume opens as an opening does** (`Opening`), under its own
       20 seconds, remembered among the openings, so a second click opens
       no second window; its captions and banners are an opening's.
       Remembered until a watch line shows a window holding its session,
       which forgets it (`RecentOpenings.heard`, from each line `Works`
       hears), 2 minutes at most, where an opening's is 10 seconds (found
       in review, 12 November 2026: a resume can take longer than 10
       seconds to reach the board).
     - **Every surface clicks an away row**: the card's row and its menu's
       Jump, the strip's mark, its tab and a count's row, the menu bar
       menu's row and a notification's click, each lifting under the
       pointer as any row does; the notification names the session.
   - **To prove live, with Lee's go**, as listed on 12 November 2026,
     superseded by the rule's list above. Its first live test (13 November
     2026, above) led to the rethink; none of it was proven.
     1. After a restart, Portal's sessions back: a click on an away row
        attaches its zmx session by the open command, and Enter brings
        the same Claude back.
     2. With `portal open -p {dir} -- claude --resume {claude}`, a
        session whose zmx session is gone: a new window, Portal starting a
        session in the folder, and Claude resuming the conversation.
     3. A session whose window is still showing its zmx session: the jump.
     4. A notification's click and the menu's row on an away session go
        the same way.

9. **Answering from the panel and the banner**, decided with Lee on 24
   November 2026 (see "Answering from the panel", and "Its buttons" under
   "The menu bar"). In order, each step a PR:
   1. **`sitrep answer` takes words.** A words ask's words, a reply
      `{verdict: 'answer', note}` into the session's inbox, kept to one
      line; empty words refused; a comment and a permission prompt still
      refused (see "One engine, two front ends"). `docs/cli.md` waits for
      step 5.
   2. **The app reads each ask, and answers.** `Board` decodes each
      session's `asks` from the watch line, which carries them already:
      the id, what it wants, the yes, the title, the options, the option
      recommended and the reply. `SitRepCLI.answer` runs `sitrep answer`
      of an ask, with an answer or `--ignore`, giving back written or
      refused, as its snooze and wake do. A sender holds an answer two
      seconds, Undo taking it back, then runs it; a refusal posts the
      banner "Not answered" over the CLI's words, as a refused snooze
      posts "Not snoozed".
   3. **The row's arrow and the asks panel**, in Black and in Glass. The
      arrow on a Needs you row with an ask the panel answers; the asks
      panel beside the list, its window wider than the panel's while it is
      open, and taking clicks over the asks panel's shape as over the
      panel's; its pages, its answer rows, Ignore, Snooze, and the sending
      line with its countdown and Undo; staying open while the pointer is
      over the list or over it.
   4. **The banner's buttons**, through the notices helper. The post
      carries the ask's id, what it wants, its yes and its options; the
      helper registers a category for each banner, its actions the ask's
      buttons, or Reply for words, and relays a response, the ask's id and
      the answer or the words, back to SitRep, which runs the CLI at once.
   5. **The docs:** `docs/answering.md`, whose "SitRep, the Mac app,
      doesn't answer" goes; `docs/notch.md`; `docs/notifications.md`;
      `docs/cli.md`; and `docs/glossary.md`, for the asks panel and the
      row's arrow.

## The board in a terminal

Settled with Lee on 18 and 19 November 2026: the notch's panel as a
terminal app, for the screens with no notch, an iPad or a phone signed in
to the Mac over SSH in rootshell, and for a Ghostty tab on the Mac. The
full spec, the code it builds on, what that code can't give yet, the
questions still Lee's and the slices it is built in, is
`design/terminal-ui.md`; the looks are in Paper's "SitRep · terminal
look", the pick on its page "FINAL · board in a terminal".

- **One panel, drawn the same everywhere:** a dashboard to leave open
  beside your work, and a launcher to pick from. `sitrep` alone opens it on
  a terminal, on the alternate screen; `sitrep help` keeps the help, and
  every other command, `watch` among them, stays byte for byte. It reads
  the board as `watch` does, in its own process, so it needs no SitRep
  running.
- **Sessions by state, as the notch orders them:** Needs you, its asks in
  orange, then its Stopped in blue; Working; then Snoozed, folded at first.
  Each row names its project.
- **It doesn't answer asks**, as the notch didn't when it was settled; the
  notch's asks panel answers since 24 November 2026 (see "Answering from
  the panel").
- **Picking a row, by `o`, runs SitRep's resume command in place**, in
  the panel's own terminal, on the Mac as over SSH, so it behaves the same on
  every screen: the command a click runs for a session this Mac doesn't
  show (stage 8), filled and refused as the app fills and refuses it, the
  default's guard with it. A Claude suspended on the session's device
  refuses whatever the command, since the panel never jumps to it, and the
  line runs in a POSIX login shell alone, by `$SHELL -l -c`, which reads no
  `.zshrc`, where the app's typed line does. The panel never attaches
  a session itself, and knows no `zmx attach`, no `tmux attach` and no
  session tool: corrected by Lee on 19 November 2026, "It should never run
  zmx attach. We should be using the existing commands that are registered
  for this process." It takes the terminal back when the command ends, so
  with a command attaching in a plain shell, detaching comes back to the
  panel. A session a terminal on this Mac shows is no special case: the
  panel never jumps and never moves the Mac's screen. Lee: "As long as we
  always go through the command … It's generic enough that it's up to the
  user to handle their own scenarios through the registered commands."
  What becomes of a session open elsewhere is the command's business, not
  SitRep's. A session running in a terminal with no tmux or zmx can't be
  reached from the panel, which says so.
- **A new ask posts a terminal notification**, OSC 777, its title the
  ask's words and its body the project and session, which rootshell shows
  in the background and tmux passes through with passthrough on. It is on
  by default, and `--no-notify` turns it off. Claude stopping posts none,
  as in the app's defaults.
- **The marks keep the notch's grammar**: colour says what is needed,
  Claude Code's orange `#D77757` for an ask and blue for Stopped; fill says
  where, filled where the session is open on the device you're looking
  from and hollow away. `✻` is working, `◌` on its own work, and `◉` a new
  ask, for two seconds. Asks are circles, as on the notch card (19
  November 2026; round 1 drew diamonds).
- **The look** (19 November 2026, the fourth of four rounds): each session
  on two lines, its name and time, then its project and status line, under
  grey capital headings with a rule, `NEEDS YOU ●4 ●2 ───── ▿`, the words
  in `#7A82AB` at regular weight and the rule in `#565F89`. Every row starts
  flush at the margin, with no `▸`: the band alone marks the chosen row.
- **It fits the terminal it is in**, drawn first for 39×27, rootshell's
  narrowest, and for 69×46, 73×36 and 114×45, Lee's measured sizes, down to
  15 rows. Lee: "We build it dynamically. It will fit regardless."
- **The fill comes from SitRep** (20 November 2026): SitRep writes each
  read of here to `here.json` (see "Storage"), and the panel reads it at
  every look. No file, as with SitRep not running, or one 30 seconds old,
  leaves every held session filled.
- **Hollow means not open on the device you're looking from**, decided by
  Lee on 20 November 2026. Over SSH from his phone, in rootshell, every
  asking session drew hollow, though he had each open there, attached
  from the phone and detached on the Mac: hollow had meant no terminal on
  this Mac's screen shows it. Now a session attached from the device the
  panel is looked at from counts as here. On the Mac nothing changes: the
  panel dims what the notch dims. SitRep tells each session's viewers,
  `mac` or a device over SSH by its address, and each multiplexer tty's;
  the panel finds its own by its tty, where SitRep lists it, as inside
  zmx, else by its own `SSH_CONNECTION`, else it is on the Mac.
- **Reached from any shell, and documented** (20 November 2026, slice 9):
  the cask's `binary` stanza links the CLI the bundle carries,
  `Contents/Resources/Plugin/bin/sitrep`, a compiled binary needing no
  Bun, into Homebrew's `bin`, in a PR on the tap. `docs/terminal.md` is its
  page, calling it the terminal view, since the docs' "panel" is the
  notch's; its still, `art/screens/terminal.webp`, is the golden frame
  `panel-docs-73x18`, a world of the docs' placeholder names alone, drawn
  by termgrid.
- **Proven live on 20 November 2026,** by Lee, from a build of `f5e442c`, on
  his iPad and iPhone in rootshell over tssh:
  - **The dims by device:** from a plain tab on the iPad, the sessions
    attached there drew filled, Folio's (attached only in the Mac's Ghostty)
    and Fabric's (attached nowhere) hollow. On the iPhone, with nothing
    attached, every row drew hollow. Attaching the sitrep session there
    through Portal filled its row within seconds, while the iPad's view,
    whose attach Portal ended, drew it hollow. Taking the session back
    swapped them. Run inside a zmx session, the view found itself by its
    tty and drew the same.
  - **The pick:** `⏎` on a hollow row ran Lee's Portal resume command and
    attached the session at once. Portal's `Alt+D` detaches back to its
    picker, by design, and leaving the picker brought the view back.
    Portal labelled SitRep its terminal, because its walk takes any
    ancestor under a `.app/` (parked, a Portal fix).
  - **Notifications:** a new ask posted a banner on both devices while
    rootshell was in the background. rootshell holds an OSC 777 banner back
    for the tab in front, and a tap on one does nothing: rootshell returns a
    tap to its pane only for its own push notifications (parked).
  - **The band,** too strong at first on the phone's near-black, now stands
    one quiet step of contrast off any ground (#187).
- **`⏎` expands, `o` opens**, decided by Lee on 20 November 2026. He keeps
  the view open in a narrow strip on his iPad over SSH, to see what needs
  him, and reads there the rows its width cuts short, without ever opening
  a session by accident. So `⏎`, or a tap on the chosen row, expands it,
  its name and its words wrapped whole, each of several asks on a line of
  its own, and folds it again; one row at most, the band's. `o` alone
  opens, as `⏎` did, every answer as before. There is no view-only flag.
  "Open" stays the docs' word, and nothing says "attach".
- **`z` snoozes** (Lee, 20 November 2026), from that same strip: on a row
  that needs him, of asks or of his turn alone, it opens a menu of
  Snooze's times under the row, the notch's choices and words, worked out
  from `snooze.json` as the menu opens, then Until it moves. A choice
  writes exactly what `sitrep snooze` writes, the CLI's own line in its
  own file, naming the asks the row showed, so none is snoozed unseen. On
  a Snoozed row `z` writes `sitrep wake`'s line. On a row of a window's
  prompt alone, or a working one, the notch offers no Snooze, and `z` says
  why in words.
- **No title** (Lee, 20 November 2026), for that same strip, where every
  row counts: the ` sitrep` title row and the blank row under it are gone,
  and the body starts on row 0. A stale board's `as of 12:04`, the title
  row's only other use, stands at the key line's right end instead, the
  keys cut before it. The blank rows between sections give way below 13
  rows, the body as roomy there as it was below 15 under the title.
- **A blank top row** (Lee, 20 November 2026: "its a little snug at the
  top"): row 0 is blank again, with no title on it, while the whole body
  fits under it; short of room it gives way first, so it never costs a
  row. The docs frame is `panel-docs-73x18`.

Every other question the spec put to Lee he answered on 19 November 2026
as it recommended, and none is left open. So the CLI runs programs again, which it has not done
since 10 November 2026 (stage 7, step B), but only for a pick: the user's
resume command through the login shell, and `ps` for the guard and
`{tty}`; never zmx or tmux. SitRep writes who views each session, for the
panel's hollow marks.

## Later

Jumping to a session's window is now "The menu bar".

Left out of answering from the panel (24 November 2026; see "Answering
from the panel"):
- **Permission prompts and Claude Code's question dialog** from the
  panel: a probe of the engine's `classic.PermissionRequest` hook, which
  may hide the terminal's dialog while it waits.
- **The strip's tab taking the arrow**, to open the asks panel from the
  strip.
- **The menu bar item** answering, from its menu.

Dropped:
- a standalone toast plugin (Claude Code has one);
- a line in the new-ask toast saying the band opens it: Lee knows it does,
  and on the phone the toast is better short.

Dropped by Lee on 18 November 2026:
- an **agents** view (subagents, observed from engine events, grouped by
  what they're for);
- a **tmux indicator** reading the shared folder, since the band and the
  notch do its job;
- **Paper thumbnails** inline in Ghostty;
- a **shy notch**, pulling away as the cursor nears before giving up and
  pouring open (16 October 2026);
- a "re:" tag on Lee's transcript rows that came from the board, since
  "From the board:" marks them;
- **core run inside SitRep on JavaScriptCore** (see "The structure");
- an **instant Space switch** for the jump, A/B'd live on 6 November 2026
  against the slide: "They're both really quick." The slide stays.

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
   any reply. A words ask, a comment and a permission prompt stayed with
   Claude Code's prompt. Since 24 November 2026 it takes a words ask's
   words too, for the banner's Reply; a comment and a permission prompt
   still stay there (see "One engine, two front ends").

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

A throwaway mod with fake data modelled on Switchboard and six other
projects, run only in the window that designed sitrep. It settled every
surface above, and its drawing code became `hooks/draw`. Retired on 8 October
2026, once it was found drawing its fake data over the real pane: both named
their pane `board`, and a pane's id is not scoped to the plugin that opens it.
