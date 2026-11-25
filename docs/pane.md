# The board in Claude Code

The pane shows the board inside Claude Code, docked beside the chat or inline under it. Its first tab is this session: what waits on you, where the work stands, and what Claude put off. Its second tab is every project and the sessions in it. The band above the prompt counts what waits, so you know when to open the pane.

![Claude Code in Ghostty, with the pane docked beside the chat. The tabs read "Help desk redesign 2" and "All projects 4". Under the session name and Northwind come ASKS with two asks, STATUS with what is under way and next, PARKED with three items, one from the Invoice ledger session, and RESOLVED with two asks.](../art/screens/claude-code.webp)

*The first tab shows this session.*

## Try it

1. In a Claude Code window running a session, type `/sitrep`. Or press `▸ show board` at the end of the band.
2. The first tab, such as `⌂ Help desk redesign`, shows this session.
3. Press `≡ All projects`, then a project name such as Northwind, to see its sessions.
4. To close the pane, press `hide board` on the band, or `✕ close` if the pane is inline.

## What happens

- **A session shows four sections, in order.** ASKS lists what waits on you, with its buttons. The project name beside the session opens the project. STATUS says what is under way and what is next, and `show history` opens every change to it. PARKED lists the project's parked items, this session's first, then those under `from other sessions`; `show picked up` lists those picked up, dropped or closed. RESOLVED lists the closed asks, ignored ones aside. PARKED and RESOLVED show the latest 3 until you press `show all`.
- **All projects lists each project with its open sessions.** Each line shows what waits there, such as `1 waiting`. A project with nothing open, waiting or parked folds into one line at the foot.
- **A project shows SESSIONS, ASKS and PARKED.** Under SESSIONS, `show old sessions` opens the old ones. A session is old once finished, or after 7 days with no window, no ask and no change. ASKS holds every session's asks, and PARKED the latest 3 of the project's parked items, each naming its session.
- **A parked item can be picked up.** Open it and press `pick it up`. The pick-up waits in Ready to send, and `✎ comment` under it adds a note. Then it goes to the Claude in this window. You can pick an item up only from a window running a session of its project.
- **A parked item can be dropped, from any window.** Press `✕ drop`, and the pane asks "Drop it? It leaves Parked, and Claude no longer sees it." Then `yes, drop it` takes it off the board at once. Claude learns only that the item is gone.
- **The band counts asks.** It reads `● 1 ask   2 elsewhere   ▸ show board`, and a click on a count opens the pane. When a new ask lands in this session, the ● pulses, and a toast says `● New ask:` and the ask title.

## Good to know

- **You can finish a session from the pane if no window runs it.** Open the session, and press `✓ finish this session` at the foot. Then press `yes, finish it`. Its open asks stop counting. If a window runs the session, tell Claude to finish it.
- **A finished session says so beside the project name at the top of its view,** such as `finished 1d ago`. Under ASKS, a line says "Finished: its asks can't be answered." In the Claude Code window still running that session, the asks still take a reply.
- **The pane docks only in a wide window.** Claude Code docks it beside the chat in fullscreen from 110 columns, and the band then has `hide board`. Otherwise the pane shows inline, and the band and the tabs end with `[ ✕ close ]`.

## Reference

| Where | What it shows |
|---|---|
| `⌂` tab | This session, and the asks waiting in it |
| `≡ All projects` tab | Every project, and the asks waiting in them all |
| ASKS | Asks, with their buttons |
| STATUS | Now and next; `show history` for the changes |
| PARKED | Parked items, 3 at first; pick up or drop |
| RESOLVED | Closed asks, 3 at first; `show all` for the rest |
| READY TO SEND | Replies and pick-ups not sent yet |
| The band | Asks here, asks elsewhere, show or hide |

## Related

- [Answering from the board](answering.md)
- [Asks: what waits on you](asks.md)
- [Sessions outlive their windows](sessions.md)
