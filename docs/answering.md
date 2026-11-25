# Answering from the board

An ask waits in the pane with its buttons, so you answer it without finding the window or scrolling back through the chat. Each answer queues a reply. Then one send carries every reply to the right Claude, in this session or another. It helps most when several sessions wait on you.

![Claude Code in Ghostty, with the pane docked beside the chat. In the chat, a message from the board reads "From the board:", then "Which editor should replies use? → Markdown", then "This closes the ask: nothing more to do with it." In the pane, a choice asks "Thread replies, or keep them flat?", with the buttons Threaded · recommended, Flat, comment, ignore and snooze.](../art/screens/claude-code.webp)

*A reply sent from the pane reaches Claude as "From the board:", while the next ask waits.*

## Try it

1. Type `/sitrep` to open the pane, and press the title of an ask to open it.
2. Press a button, such as `✓ Go` or the option you pick. The reply waits in READY TO SEND, at the foot of the pane.
3. Press **send to Claude**. Claude gets a message that starts "From the board:".

## What happens

- **Each shape of ask has its own buttons.** A yes has one button in the verb Claude gave, such as `✓ Approve`. A choice has a button for each option, and the one Claude recommends ends in `· recommended`. A words ask has `✎ Answer`.
- **You write words in the Claude Code prompt.** After `✎ Answer`, the band reads `✎ Your next Enter answers "…"`. After `✎ comment`, it reads `✎ Your next Enter comments on "…"`. Press Escape once to reach the prompt, then write and press Enter. The words go to Ready to send, not to Claude, and `cancel` on the band backs out.
- **Replies wait in Ready to send.** They are grouped by where each goes, such as `to this session` or `to Onboarding flow`. Each has `✕`, and under its ask, `↺ undo`. A reply with words also has `✎ edit`, and a bare yes or choice has `✎ comment`. Nothing goes until you press **send to Claude**, and **cancel all** clears them. Until you send, the ask still counts. A snooze, a wake now or a finish never waits here: each takes effect at once.
- **A reply for this session arrives as your own message.** It starts "From the board:", and under each ask one line says what to do. "This closes the ask: nothing more to do with it." Or: "This leaves the ask open: act on it, then resolve it."
- **A send waits for Claude's turn to end.** If Claude is mid-turn, Ready to send shows `⧗ Waiting for Claude's turn to end.` and `↺ take back`. Taking it back returns your replies to Ready to send.
- **A reply for another session goes into that session's inbox.** The Claude Code window running that session sends it on to Claude. Its band shows `✦ 1 reply from the board` for a few seconds. If no window runs that session, the reply waits until one joins it.

## Good to know

- **You can answer from the Mac app too.** Answer from the notch, or from the banner for a new ask: see [Answering from the edge of your screen](answering-edge.md). From a shell, use `sitrep answer`, in [The `sitrep` command](cli.md).
- **A comment on its own leaves the ask open.** Every other reply closes it, `✕ ignore` included. An ignore tells Claude you've seen the ask and won't act on it.
- **The prompt must be empty to answer.** If a draft is there, the pane refuses, so its Enter can't send the wrong words.
- **An image waits in Ready to send too.** SitRep saves it as a file for Claude, and clears it after 14 days. If saving fails, the answer goes at once, to this window's session only.

## Reference

| Button | On | What it does |
|---|---|---|
| `✓ Go`, in the verb Claude gave | A yes | Says yes; closes the ask |
| One per option | A choice | Picks it; closes the ask |
| `✎ Answer` | A words ask | Sends words; closes the ask |
| `✎ comment` | A yes or a choice | Sends words; leaves it open |
| `✕ ignore` | Every ask | Closes the ask, unanswered |
| `snooze` | An ask waiting on you | Asks until when; puts that ask off |
| `↺ take back` | A send held | Returns its replies to Ready to send |
| `cancel all` | Ready to send | Clears the replies not sent |

## Related

- [Asks: what waits on you](asks.md)
- [The board in Claude Code](pane.md)
- [Putting a session off](snooze.md)
