# Sessions outlive their windows

A session is one line of work with Claude, kept on the board. It keeps its status, history and asks after a `/clear`, and in a new Claude Code window the next day. Claude joins it again by its id. You can also move a session to another project, finish it, and find it later among old sessions.

## Try it

1. In the Claude Code window running the Help desk redesign session, type `/clear`.
2. Tell Claude: "Carry on with the help desk redesign."
3. Claude joins the session by its id.
4. Type `/sitrep`. The pane shows the status and asks the session had before the `/clear`.

## What happens

- **Claude finds the session by its id.** Each new conversation starts with a list of the current sessions, each with an id. So Claude can match your words to the right session, even if nothing else recorded the id.
- **A resumed conversation needs no telling.** After `claude --resume` or `/resume`, the window takes up the session it was last in by itself. It never takes up a finished session.
- **A session moves to another project at your word.** Say "Move this session to Contoso", and Claude moves the whole session. Its asks, parked items, status and history all go with it. Every Claude Code window running that session shows `Moved to Contoso.`
- **Parked items belong to the project.** What a session parked stays with the project after the session finishes or goes idle. It shows under PARKED in the project's view, and in each session's view. A move takes the items to the new project.
- **Claude finishes a session once nothing is left on it.** A finished session leaves the session lists, and its open asks stop counting.
- **Old sessions fold away.** In the pane, a project folds them at the foot of SESSIONS, behind `show old sessions 4`. Each one says when it ended, such as `finished 1d` or `idle 8d`.

## Good to know

- **You can finish a session no window runs.** Open it in the pane, and press `✓ finish this session` at its foot. The pane asks `Finish Invoice ledger? Its open asks stop counting.` Press `yes, finish it`. To finish a session a window runs, tell Claude in that window.
- **Claude lists only current sessions.** An old session is not in the list Claude starts with, so naming it finds nothing. Claude can still join it by an id recorded in the project's own notes, and a finished session then opens again.
- **An old session is finished, or idle.** Idle means over 7 days since it last changed, with no window and nothing waiting on you. A session with an ask waiting never becomes an old session, however long it waits.
- **Two ids, two jobs.** The board gives each session an id, such as `sr-nw0001`, which never changes. Claude Code has its own session id, which names one conversation and changes on `/clear`. The pane and the Mac app never show the session id, but the `sitrep` command does.

## Reference

| You want to | Do this |
|---|---|
| Carry on after `/clear` | Tell Claude to carry on |
| Carry on in a new window | Name the session to Claude |
| Move a session | Tell Claude which project |
| Finish a session a window runs | Tell Claude there |
| Finish one no window runs | `✓ finish this session` in the pane |
| See old sessions | `show old sessions` in a project |

The `sitrep` command can also move and finish sessions: see [The sitrep command](cli.md).

## Related

- [Putting a session off](snooze.md)
- [The board in Claude Code](pane.md)
- [How Claude keeps the board](claude-and-sitrep.md)
