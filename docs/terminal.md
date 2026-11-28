# The board in any terminal

Type `sitrep` in a terminal, and the terminal view fills it with the board: what waits on you, and what is running. Answer a yes or a choice with one key, even from a phone over SSH, away from your Mac. Open a session no window runs, and your resume command carries it on.

![The terminal view in a window titled sitrep. Under NEEDS YOU, Help desk redesign is the chosen row, with its asks open under it. The ask reads "Thread replies, or keep them flat?", asked 4m ago, with two dots for two asks. Its answers are 1 Threaded · Recommended, 2 Flat, and 3 Flat, with a quote of the one it answers. Under them reads x Ignore, z Snooze, o Open. Below come Data import, dimmed, and a blue Stopped row. WORKING 2 and a folded SNOOZED 1 follow. The last line reads 1–3 answer, ←→ ask, esc close.](../art/screens/terminal.webp)

*The first of two asks in Help desk redesign, open: `1` answers Threaded.*

## Try it

1. Open a terminal on your Mac. Or sign in to the Mac over SSH, with Remote Login on in System Settings › General › Sharing.
2. Type `sitrep`. The board fills the terminal.
3. Press `↓` until the chosen row shows `▹` at its right end, then `⏎`. The asks of that session open under it.
4. Press `1` to send the first answer. For two seconds, `u` takes it back.

Press `q` to return to your shell. Homebrew links `sitrep` into the Homebrew `bin` folder, which a shell needs on its PATH.

## What happens

- **Each session takes one line.** A row of asks shows the session name and a count. A Stopped or Working row shows what Claude did or is doing. The project and the time stand at the right. Press `⏎` to expand a row the width cuts short.
- **A dot says what waits.** An orange dot has asks or a permission prompt waiting, and a blue dot is Stopped. In Working, `✻` runs a turn, and `◌` waits on work of its own. A row with a hollow dot and dimmed words isn't open on the device you're looking from. Without SitRep running, only a session no window runs is dimmed.
- **`⏎` opens the asks on a row that shows `▹`.** Each ask shows its title and age, then numbered answers, Claude's pick first. With several asks, `←` `→` page through them. `⏎` or `esc` closes them.
- **A digit answers, with two seconds to undo.** The foot reads `Sending Flat` beside a filling ring and `u undo`. Then the answer goes into the session inbox, and the session window sends it to Claude, starting "From the board:". `q` sends a held answer first, then leaves.
- **The foot names the other keys for the ask shown.** `x` ignores it, with the same two seconds. `z` snoozes this ask only, and `o` opens its session.
- **The board stays current** within a second, and each new ask posts a terminal notification. To turn notifications off, type `sitrep --no-notify`.

## Good to know

- **Permission prompts stay in Claude Code.** A row of only permission prompts shows no `▹`, and `⏎` expands it. A words ask shows no answers: press `o` to answer it in Claude.
- **A refused answer says so.** If the ask was answered elsewhere or changed, the words above the keys say why, and the ask stays.
- **The default resume command refuses a session a window still runs,** because it would start a second Claude. A script that takes `{tty}` can attach that window instead: see [A click takes you there](jump.md). The command runs in your login shell, so fish can't run it.
- **Ghostty shows terminal notifications** as macOS notifications. Inside tmux, set `allow-passthrough on`, or tmux holds them back.

## Reference

The last line names the keys that work now.

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j`, a tap | Choose a row |
| `⏎`, or a tap on the chosen row | Open its asks, or expand it; `⏎` again closes |
| `1`–`9` | Answer the ask shown, or take a Snooze menu choice |
| `←` `→` | Show the ask before or after |
| `u` | Take back an answer, within 2 seconds |
| `x` | Ignore the ask shown |
| `z` | Snooze the row or the ask shown; wake a snoozed row |
| `o` | Open the session: run the resume command |

`s` unfolds or folds Snoozed. `q` or `Ctrl-C` leaves, and `Ctrl-Z` suspends until `fg`. `esc` closes a menu, then the asks, then clears the choice. Every other command is in [The `sitrep` command](cli.md).

## Related

- [Answering from the edge of your screen](answering-edge.md)
- [A click takes you there](jump.md)
- [Same keys, wherever the board shows](keys.md)
