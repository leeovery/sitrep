# Sessions outlive their windows

A session is one line of work with Claude, kept on the board. It keeps its status, history and asks after a `/clear`, and in a new Claude Code window the next day. Claude joins it again by its id. You can also move a session to another project, finish it, and find it later among old sessions.

## Try it

1. In a Claude Code window holding the Help desk redesign session, type `/clear`.
2. Tell Claude: "Carry on with the help desk redesign."
3. Claude joins the session by its id.
4. Type `/sitrep`. The pane shows the status and asks the session had before the `/clear`.

## What happens

- **Claude finds the session by its id.** Each new conversation starts with a list of the current sessions, each with an id. So Claude can match your words to the right session, even if nothing else recorded the id.
- **A resumed conversation needs no telling.** After `claude --resume` or `/resume`, the window takes up the session it was last in by itself. It never takes up a finished session.
- **A session moves to another project at your word.** Say "Move this session to Contoso", and Claude moves the whole session. Its asks, parked items, status and history all go with it. Every window holding that session shows `Moved to Contoso.`
- **Parked items belong to the project.** A session that finishes or goes idle leaves what it parked under PARKED, in every session of the project. A move takes them to the new project.
- **Claude finishes a session once nothing is left on it.** A finished session leaves the session lists, and its open asks stop counting.
- **Old sessions fold away.** In the pane, a project folds them at the foot of SESSIONS, behind `show old sessions 4`. Each one says when it ended, such as `finished 1d` or `idle 8d`.

## Good to know

- **You can finish a session no window runs.** Open it in the pane, and press `✓ finish this session` at its foot. The pane asks `Finish Invoice ledger? Its open asks stop counting.` Press `yes, finish it`. To finish a session a window runs, tell Claude in that window.
- **Finishing can be undone.** If Claude joins a finished session by its id, the session opens again. Its asks wait on you again.
- **An old session is finished, or idle.** Idle means over 7 days since it last changed, with no window and nothing waiting on you. A session with an ask waiting stays current, however old it is.
- **Two ids, two jobs.** The board gives each session an id, such as `sr-nw0001`, which never changes. Claude Code has its own session id, which names one conversation and changes on `/clear`. The pane and the Mac app never show the session id, but the `sitrep` command does.

## Reference

| You want to | Do this |
|---|---|
| Carry on after `/clear` | Tell Claude to carry on |
| Carry on in a new window | Name the work to Claude |
| Move a session | Tell Claude which project |
| Finish a session a window runs | Tell Claude there |
| Finish one no window runs | `✓ finish this session` in the pane |
| See old sessions | `show old sessions` in a project |

The `sitrep` command can also move and finish sessions: see [The sitrep command](cli.md).

## Related

- [Putting a session off](snooze.md)
- [The board in Claude Code](pane.md)
- [How Claude keeps the board](claude-and-sitrep.md)
