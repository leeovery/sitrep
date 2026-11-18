# The board in Claude Code

The pane shows the board inside Claude Code, beside the chat or over it. Its first tab is this session: what waits on you, where the work stands, and what Claude put off. Its second tab is every project and the sessions in it. The band above the prompt counts what waits, so you know when to open the pane.

![Claude Code in Ghostty, with the pane docked beside the chat. The tabs read "Help desk redesign 2" and "All projects 4". Under the session name and Northwind come ASKS with two asks, STATUS with what is under way and next, PARKED with three items, one from the Invoice ledger session, and RESOLVED with two asks.](../art/screens/claude-code.webp)

*The first tab shows this session, in the order the pane always uses.*

## Try it

1. In a Claude Code window that holds a session, type `/sitrep`. Or press `▸ show board` at the end of the band.
2. The first tab, such as `⌂ Help desk redesign`, shows this session.
3. Press `≡ All projects`, then a project name such as Northwind. Its view lists every session in it.
4. Press `hide board` on the band to close the pane.

## What happens

- **A session shows four sections, in order.** ASKS lists what waits on you, with its buttons. STATUS says what is under way and what is next, and `show history` opens every change to it. PARKED lists the items of the project, this session first, then those under `from other sessions`. RESOLVED lists the asks closed lately.
- **All projects lists each project with its open sessions.** Each line shows what waits there, such as `1 waiting`. A project with nothing open, waiting or parked folds into one line at the foot. The name of a project opens its view.
- **A project shows SESSIONS, ASKS and PARKED.** Under SESSIONS, `show old sessions` opens those finished, or idle for over 7 days. ASKS holds the asks of every session, and PARKED every item parked in the project, each naming the session it came from.
- **A parked item can be picked up.** Open it and press `pick it up`, or `✎ with a comment`. The pick-up waits in Ready to send, then goes to the Claude in this window. You can pick an item up only from a window that holds a session of its project.
- **A parked item can be dropped, from any window.** Press `✕ drop`, and the pane asks "Drop it? It leaves Parked, and Claude no longer sees it." Then `yes, drop it` takes it off the board at once. Claude learns only that the item is gone.
- **The band counts asks.** It reads `◆ 1 ask   2 elsewhere   ▸ show board`, and a click on a count opens the pane. When a new ask lands in this session, the ◆ pulses, and a toast says `◆ New ask:` and the ask title.

## Good to know

- **You can finish a session from the pane if no window runs it.** Open the session, and press `✓ finish this session` at the foot. Then press `yes, finish it`. Its open asks stop counting. A session that a window runs, you finish by telling Claude.
- **A finished session says so beside its project,** such as `finished 1d ago`. Under ASKS, a line says "Finished: its asks can't be answered." The one exception is the window that still holds it, where the asks still take a reply.
- **What left Parked stays in view.** `show picked up` lists each item with how it left: `picked up by` a session, `closed by Claude`, or `dropped by you`.
- **The pane changes shape with room.** Docked beside the chat, the band has `hide board`. Shown inline, as on a phone, the tabs end with `[ ✕ close ]`. Below 64 columns, the band shows counts only, such as `+2`.

## Reference

| Where | What it shows |
|---|---|
| `⌂` tab | This session, and the asks waiting in it |
| `≡ All projects` tab | Every project, and the asks waiting in them all |
| ASKS | Asks, with their buttons |
| STATUS | Now and next; `show history` for the changes |
| PARKED | The items of the project; pick up or drop |
| RESOLVED | The latest 3 closed; `show all` for the rest |
| READY TO SEND | Replies and pick-ups not sent yet |
| The band | Asks here, asks elsewhere, show or hide |

## Related

- [Answering from the board](answering.md)
- [What waits on you](asks.md)
- [Sessions outlive their windows](sessions.md)
