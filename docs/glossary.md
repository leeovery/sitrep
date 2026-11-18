# Glossary: the board's words

Each word below means one thing on every page of these docs. The words are grouped by where you meet them, and listed A to Z in each group.

## On the board

**ask**: Something only you can do or decide, posted by Claude. It wants a yes, a choice or words back. It waits on you until you reply, or until you snooze its session.

**the board**: Everything Claude keeps for you: projects, the sessions in them, and their items. It is a folder of files in `~/.local/state/sitrep`, with no server, account or database. In Claude Code, the button that opens the pane says `show board`.

**finished**: A session that Claude or you marked finished, once nothing was left on it. Its parked items stay with the project. Asks it left open take no reply, except in the window that still holds it.

**parked item**: Something Claude raised and put off, to come back to later. It belongs to the project, and names the session that parked it. It never counts as waiting on you.

**project**: What a session is about, named by Claude the way you'd say it, such as Northwind. It is roughly a repository. The folder a window started in never decides it.

**resolved**: An item that is done with: an ask your reply closed, or any item Claude closed. The pane lists the resolved asks of a session under RESOLVED.

**session**: One line of work with Claude, with a status, asks and parked items. It outlives its window. After `/clear`, or in a new window told to carry on, it is the same session.

**session id**: The id the board gives a session, such as `sr-nw0001`. Claude uses it to join a session, and SitRep never shows it to you. It is not Claude Code's own session id, which names one conversation and changes on `/clear`.

**snoozed**: A session you put off until a time you pick. Its asks and your turn there stop counting until it wakes. Only you can snooze a session: Claude has no way to.

**status**: Where a session stands: its name, a one-line summary, what is under way now, and what comes next.

**Stopped**: A session at your turn: Claude has stopped, and no ask waits. It is the word the Mac app uses, shown in blue.

## In Claude Code

**the band**: The line above the Claude Code prompt. It counts the asks of this session and the asks waiting elsewhere, and ends with the button that shows or hides the pane. Each count opens the pane.

**drop**: Taking a parked item off the board from the pane, once you confirm. Claude learns only that the item is gone.

**the pane**: The board inside Claude Code, opened with `/sitrep` or from the band. It has two tabs: this session, and All projects.

**pick up**: Handing a parked item to the Claude in this window, from the pane. You can pick one up from any window that holds a session of its project.

**Ready to send**: The foot of the pane, where replies and pick-ups wait. Nothing goes to Claude until you press **send to Claude**.

**reply**: Your answer to an ask, given from the board, or a pick-up of a parked item. A reply for this session reaches Claude as your own message, marked "From the board:". A reply for another session waits in its inbox until a window of that session sends it on.

## At the edge of your screen

**the menu bar item**: The SitRep icon in the menu bar, and its menu. The menu lists your sessions under one total, such as "3 need you". The icon lights the same way the notch does.

**Needs you**: The first section of the panel: the sessions waiting on you. An orange row has an ask, or a window stopped on a permission prompt or a question. A blue row is Stopped.

**the notch**: The black SitRep shape at the left or right edge of your screen. It opens into the panel when you hover over it. Its light is orange while an orange row waits in Needs you, else blue while a session is Stopped.

**the panel**: What the notch opens: your sessions, in Needs you, Working and Snoozed. A click on a session takes you to it.

**the strip**: The other way to show the board at the screen edge: a narrow column with a mark for each session. You pick the notch, the strip or neither under Show, in the menu.

**Working**: The section of the panel for sessions that don't need you. Claude is running a turn there, or waits on work of its own, such as a background agent.

**a session this Mac doesn't show**: A session drawn dimmed: no window holds it, or no terminal on this Mac shows its Claude. For example, you reach that Claude only from another device. Its asks still count.

## Getting to a session

**the jump**: What a click on a session does: it brings forward the window that shows the session. Ghostty gets the exact window. Any other terminal app comes forward whole.

**the resume command**: What SitRep types into a new Ghostty window, for a session no window on this Mac shows. The default is `cd {dir} && claude --resume {claude}`. You can set your own in Settings › General.
