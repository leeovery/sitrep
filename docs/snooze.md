# Snooze: put a session off

Some asks can wait until tomorrow. Snooze puts a whole session off until a time you pick: its asks and your turn there stop counting, and the session waits under Snoozed. At that time it comes back to Needs you, the way a new ask arrives. A new ask there, or your reply, brings it back sooner.

## Try it

1. Hover over the notch, and right-click a session under Needs you.
2. Choose **Snooze**, then **Tomorrow**. Beside each choice, the menu shows when it wakes, such as `Thu 09:00`.
3. The session leaves Needs you. Unfold Snoozed at the foot of the panel, and its row says when it wakes.

In Claude Code, open an ask in the pane and press `snooze`, then `tomorrow`.

## What happens

- **The whole session snoozes.** Its asks and your turn there go together. Snoozing one ask from the pane snoozes its session.
- **Snoozed holds it.** Snoozed is the last section of the panel, folded at first, with a count of the asks asleep in it. The strip shows a mark for each snoozed session, below a line of its own.
- **The pane keeps the asks in sight.** A snoozed ask stays under ASKS, dimmed, with `snoozed until tomorrow 09:00` and `wake now`. The heading counts both, such as `1 waiting · 2 snoozed`.
- **Its time wakes it.** The session comes back to Needs you, with the sound and the pulse a new ask brings. In the Claude Code window running that session, a toast says `◆ Back from snooze:` and the ask title.
- **Something new wakes it sooner:**
  - a new ask in the session;
  - your reply to one of its asks;
  - your prompt in the Claude Code window running that session.
- **You can wake it yourself.** Right-click its row under Snoozed and choose **Wake now**, or press `wake now` in the pane.

## Good to know

- **Only you snooze a session.** Claude has no tool for it. Claude sees the snooze on the board, and leaves the asks until then.
- **A permission prompt never snoozes.** A Claude Code window waiting at one stays in Needs you, though its session is snoozed.
- **Until it moves has no time.** It wakes the session when Claude next ends a turn there, or for any of the reasons above. Only the menus in the Mac app offer it.
- **The pane snoozes only from an ask.** A session at your turn with no ask snoozes from its row in the Mac app.

## Reference

| Choice | Wakes, by default |
|---|---|
| In an hour | One hour from when you snooze |
| Later today | 3 hours from when you snooze |
| Tonight | 18:00, offered until then |
| Tomorrow | 09:00 tomorrow |
| This weekend | Saturday 09:00; off by default |
| Next week | Monday 09:00 next week |
| Until it moves | When Claude next ends a turn there |

Settings › Snooze turns each of the first six choices on or off, and sets when each one wakes. SitRep writes them to `snooze.json` in `~/.local/state/sitrep`, and the pane reads that file, so it offers the same choices. With every choice off, the menu offers only Until it moves, and the pane offers no snooze. See [Settings, pane by pane](settings.md).

## Related

- [Asks: what waits on you](asks.md)
- [The edge of your screen](notch.md)
- [Sessions outlive their windows](sessions.md)
