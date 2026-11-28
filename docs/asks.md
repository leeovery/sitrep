# Asks: what waits on you, in one place

When Claude needs something only you can do or decide, it posts an ask. SitRep counts the asks in all your sessions, above the Claude Code prompt and at the edge of your screen. It also shows each session that is Stopped: Claude has stopped, and it's your turn. So from any window, you can see what waits on you.

![Claude Code in Ghostty, with the pane docked beside the chat. The band above the prompt reads "2 asks" and "2 elsewhere". The pane shows the Help desk redesign session, with two asks under ASKS: a choice between Threaded and Flat, with Threaded marked recommended, and a review of Tickets and Replies.](../art/screens/claude-code.webp)

*The band counts this session's two asks, and the pane lists them.*

## Try it

1. In a Claude Code window, give Claude work that needs your decision. For example: "Start a session on Northwind, and ask me which editor replies should use."
2. Claude posts an ask, and the band above the prompt shows `● 1 ask`.
3. Type `/sitrep` to open the pane. The ask waits under ASKS, with its buttons.

## What happens

- **An ask takes one of three shapes.** A yes has one button in Claude's words, such as `✓ Go`. A choice has a button for each option, and the option Claude recommends ends in `· recommended`. A words ask has `✎ Answer`, for words you write back.
- **Every ask has more buttons.** Each has `✕ ignore` and `snooze`, and a yes or a choice also has `✎ comment`. [Answering from the board](answering.md) covers each one.
- **A new ask announces itself.** In the Claude Code window running that session, the ● on the band pulses, and a toast says `● New ask:` and the ask title. SitRep plays a sound and pulses the notch, wherever the session is.
- **The band counts asks, and nothing else that waits on you.** First come the asks of this session, then the asks in every other session, such as `2 elsewhere`. A click on a count opens the pane.
- **The pane lists them.** A session lists its asks under ASKS, with a count such as `2 waiting`. Each tab of the pane counts the asks under it.
- **Needs you gathers every session that waits on you.** In the panel the notch opens, an orange row has asks, or a window waiting at a permission prompt. A blue row is Stopped. The Needs you heading counts the orange lines in orange, and the Stopped sessions in blue.
- **The edge lights up.** The notch light is orange while any orange row waits. With none, it is blue while a session is Stopped. The menu bar item lights the same way, and its menu gives one total, such as "3 need you".

## Good to know

- **Snoozed sessions stop counting.** If you snooze a session, its asks and your turn there stop counting until it wakes. A new ask in that session wakes it at once. See [Putting a session off](snooze.md).
- **Parked items never count.** Claude puts off what can wait under PARKED in the pane, and none of it waits on you.
- **Dimmed sessions still count.** SitRep dims a session that no terminal on this Mac shows, for example one you reach from another device. Its asks still count.
- **Sent replies stop counting.** An ask still counts while your reply waits in Ready to send. It stops once you press **send to Claude**, even before Claude reads it. The asks of a finished session stop counting too.

## Reference

| Where | What it counts or shows |
|---|---|
| The band | Asks in this session, then asks elsewhere |
| The pane tabs | Asks in this session; asks in every project |
| Needs you, orange | Asks, and windows waiting at a permission prompt |
| Needs you, blue | Stopped sessions, one each |
| The notch light | Orange for an orange row; blue for Stopped |
| The menu bar item | One total, such as "3 need you" |
| A new ask | A sound and a notch pulse, on by default; a banner, off by default |

The settings for the sound, the banner and the pulse are in [Sounds, banners and the pulse](notifications.md).

## Related

- [Answering from the board](answering.md)
- [The edge of your screen](notch.md)
- [The board in any terminal](terminal.md)
