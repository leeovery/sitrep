# Answering from the board

An ask waits in the pane with its buttons, so you answer it without finding the window or scrolling back through the chat. Each press queues a reply. Then one send carries every reply to the right Claude, in this session or another. It helps most when several sessions wait on you at once.

![Claude Code in Ghostty, with the pane docked beside the chat. In the chat, a message from the board reads "From the board:", then "Which editor should replies use? → Markdown", then "This closes the ask: nothing more to do with it." In the pane, a choice asks "Thread replies, or keep them flat?", with the buttons Threaded · recommended, Flat, comment, ignore and snooze.](../art/screens/claude-code.webp)

*A reply sent from the pane reaches Claude as "From the board:", while the next ask waits.*

## Try it

1. Type `/sitrep` to open the pane, and press the title of an ask to open it.
2. Press a button, such as `✓ Go` or the option you pick. The reply waits in READY TO SEND, at the foot of the pane.
3. Press **send to Claude**. Claude gets a message that starts "From the board:".

## What happens

- **Each shape of ask has its own buttons.** A yes has one button in the verb Claude gave, such as `✓ Approve`. A choice has a button for each option, and the one Claude recommends ends in `· recommended`. A words ask has `✎ Answer`. The table below lists every button.
- **You write words in the Claude Code prompt.** After `✎ Answer` or `✎ comment`, the band reads `✎ Your next Enter answers "…"`, with `cancel`. Press Escape once to reach the prompt, then write and press Enter. The words go to Ready to send, not to Claude.
- **Replies wait in Ready to send.** They are grouped by where each goes, such as `to this session` or `to Supplier portal`. Each reply has `✕`, and its ask shows `↺ undo` and `✎ edit`. Nothing goes until you press **send to Claude**, and **cancel all** clears them.
- **Some presses take effect at once.** A snooze, a wake now, or a finish never waits in Ready to send.
- **A reply for this session arrives as your own message.** It starts "From the board:", and under each ask one line says what to do. "This closes the ask: nothing more to do with it." Or: "This leaves the ask open: act on it, then resolve it." If Claude is mid-turn, the box says `⧗ Waiting for Claude's turn to end.`, and `↺ take back` returns your replies to the queue.
- **A reply for another session goes into the inbox of that session.** The Claude Code window running that session sends it on to Claude, and its band shows `✦ 1 reply from the board`. If no window runs that session, the reply waits until one joins it.

## Good to know

- **SitRep, the Mac app, doesn't answer.** It snoozes and wakes a session, and a click takes you to the window. You answer there, from the pane. To answer from a shell, use `sitrep answer`, in [The `sitrep` command](cli.md).
- **An ask counts until you send.** It still counts while your reply waits in Ready to send. It stops once you press **send to Claude**.
- **A comment on its own leaves the ask open.** Every other reply closes it, `✕ ignore` included, which tells Claude you've seen the ask and won't act on it.
- **The prompt must be empty to answer.** A draft there is refused, so its Enter can't send the wrong words. An answer with an image attached goes to Claude at once, and only to the session of this window.

## Reference

| Button | On | What it does |
|---|---|---|
| `✓ Go`, in the verb Claude gave | A yes | Says yes; closes the ask |
| One per option | A choice | Picks it; closes the ask |
| `✎ Answer` | A words ask | Sends words; closes the ask |
| `✎ comment` | A yes or a choice | Sends words; leaves it open |
| `✕ ignore` | Every ask | Closes the ask, unanswered |
| `snooze` | Every ask | Puts the session off, at once |
| `↺ take back` | A send held | Returns its replies to the queue |
| `cancel all` | Ready to send | Clears the replies not sent |

## Related

- [What waits on you](asks.md)
- [The board in Claude Code](pane.md)
- [Putting a session off](snooze.md)
