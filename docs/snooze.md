# Putting a session off

Some asks can wait until tomorrow. Snooze puts them off until a time you pick, and they wait under Snoozed. Snooze a row, and the whole session goes: its asks and your turn there. Snooze one ask in Claude Code or the asks panel, and only that ask goes. At that time it comes back to Needs you.

## Try it

1. Hover over the notch, and right-click a session under Needs you.
2. Choose **Snooze**, then **Tomorrow**.
3. The session leaves Needs you. Unfold Snoozed at the foot of the panel, and its row says when it wakes, such as `tomorrow 09:00`.

In the terminal view, choose the row and press `z`, then pick Tomorrow. To put off only one ask, press `snooze` on it in the Claude Code pane, or use **Snooze ▾** in the asks panel.

## What happens

- **A row snoozes the whole session.** One ask, from the pane or the asks panel, snoozes only itself. If it was the last ask waiting, your turn waits with it until Claude ends another turn.
- **Snoozed holds it.** Snoozed is the last section of the panel, folded at first to a count. The count has one line for each ask asleep, and one for a snoozed turn.
- **The pane keeps the asks in sight.** A snoozed ask stays under ASKS, drawn faint, with `snoozed until tomorrow 09:00` and `wake now`. The heading counts both, such as `1 waiting · 2 snoozed`.
- **Its time wakes it.** The asks come back to Needs you, with the sound and the pulse a new ask brings. In the Claude Code window running that session, a toast says `● Back from snooze:` and the ask title. Your turn comes back quietly.
- **Something new wakes a snoozed session sooner:**
  - a new ask in the session;
  - your reply to one of its asks;
  - your prompt in the Claude Code window running that session.
- **You can wake it yourself.** Right-click its row under Snoozed and choose **Wake now**, or press `wake now` in the pane. In the terminal view, press `z` on its row under Snoozed.

## Good to know

- **Only you snooze.** Claude has no tool for it, and leaves snoozed asks until they wake.
- **A permission prompt never snoozes.** A Claude Code window waiting at one stays in Needs you, though its session is snoozed.
- **Until it moves has no time.** It wakes the session when Claude next ends a turn there, or for any of the reasons above. Only the right-click menus and the terminal view offer it.
- **Something new never wakes one ask snoozed alone.** Its time wakes it, and so do waking it yourself, answering it, or Claude asking it again.

## Reference

| Choice | Wakes, by default |
|---|---|
| In an hour | One hour from when you snooze |
| Later today | 3 hours from when you snooze |
| Tonight | 18:00, offered until then |
| Tomorrow | 09:00 tomorrow |
| This weekend | Saturday 09:00, offered until then; off by default |
| Next week | Monday 09:00 next week |
| Until it moves | When Claude next ends a turn there |

Settings › Snooze turns each of the first six choices on or off. It sets the time of each one but In an hour. The pane in Claude Code reads them from `snooze.json`, in the board's folder, so it offers the same choices. With every choice off, the menu offers only Until it moves, and the pane offers no snooze. See [Settings, pane by pane](settings.md).

A snoozed row in the app and `snoozed until` in the pane say when a session wakes in the same words. The week runs Monday to Sunday.

| When it wakes | It reads |
|---|---|
| today | `17:42` |
| tomorrow | `tomorrow 09:00` |
| later this week, Monday to Sunday | `Sat 09:00` |
| the next calendar week | `next week` |
| further out | `3 Dec 09:00` |

Beside each choice, the Snooze menu shows only what the choice name leaves out: `09:00` beside Tomorrow, and `Sat 09:00` beside This weekend.

## Related

- [Asks: what waits on you](asks.md)
- [The edge of your screen](notch.md)
- [Sessions outlive their windows](sessions.md)
