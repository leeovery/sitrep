# The board in any terminal

Type `sitrep` in a terminal, and the terminal view fills it with the board: what waits on you, and what is running. Answer a yes or a choice with one key, even from a phone over SSH, away from your Mac. Open a session no window runs, and your resume command carries it on.

![The terminal view in a window titled sitrep. Under NEEDS YOU, Help desk redesign is the chosen row, with its asks open under it. The ask reads "Thread replies, or keep them flat?", asked 4m ago, with two short bars at the right for two asks, the first orange. Its answers are 1 Threaded · Recommended, 2 Flat, and 3 Flat, with a quote of the one it answers. Under them reads x Ignore, z Snooze, o Open. Below come Data import, dimmed, and a blue row, Drafted the new rota. WORKING 2 and a folded SNOOZED 1 follow. The last line reads 1–3 answer, ←→ ask, esc close.](../art/screens/terminal.webp)

*Help desk redesign with the first of its two asks open: `1` answers Threaded.*

## Try it

1. Open a terminal on your Mac, or sign in to it over SSH, with Remote Login on in System Settings › General › Sharing.
2. Type `sitrep`. The board fills the terminal.
3. Press `↓` until the chosen row shows `▹`, then `⏎`. Its asks open under it.
4. Press `1` to send the first answer. For two seconds, `u` takes it back.

Press `q` to return to your shell.

Homebrew links `sitrep` into its `bin` folder, which needs to be on your PATH.

## What happens

- **Each session takes one line.** Snoozed rows and rows of asks show the session name, with a count if more than one thing waits. A Stopped or Working row shows what Claude did or is doing. The project and time stand at the right.
- **A dot says what waits.** An orange dot has asks or a permission prompt waiting, and a blue dot is Stopped. In Working, `✻` runs a turn, and `◌` waits on work of its own. A dimmed row isn't open on the device you're looking from; in Needs you its dot is hollow.
- **`⏎` opens a row's asks if the row shows the asks mark, `▹`.** Each ask shows its title and age, then numbered answers, Claude's pick first. With several asks, `←` `→` page.
- **A number key answers, with two seconds to undo.** The line under the answers reads `Sending Threaded` beside a filling ring and `u undo`. A window of that session sends it on to Claude, starting "From the board:". `q` sends a held answer first, then leaves.
- **The line under the answers names the other keys.** `x` ignores the ask, with the same two seconds. `z` snoozes this ask only, and `o` opens its session.
- **The board stays current** within a second, and each new ask posts a terminal notification. Ghostty shows one as a macOS notification; inside tmux, set `allow-passthrough on`. To turn them off, type `sitrep --no-notify`.

## Good to know

- **Some asks need Claude Code.** A row of only permission prompts shows no `▹`. A words ask shows no answers: press `o` to answer it in Claude.
- **`o` runs your resume command here.** Set it in Settings › General. When it ends, the terminal view comes back. The default refuses a session a window still runs, because it would start a second Claude: see [A click takes you there](jump.md).
- **The command runs in your login shell,** which must be sh, bash, zsh, dash or ksh. In zsh it reads `.zprofile` but not `.zshrc`, so an alias belongs in a script on your PATH.

## Reference

The last line names the keys that work now.

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j`, a tap | Choose a row |
| `⏎`, or a tap on the chosen row | Open its asks, or expand it; `⏎` again closes |
| `1`–`9` | Answer the ask shown, or take a Snooze menu choice |
| `←` `→` | Show the ask before or after |
| `u` | Take back an answer, within two seconds |
| `x` | Ignore the ask shown |
| `z` | Snooze the row or the ask shown; wake a snoozed row |
| `o` | Open the session: run the resume command |

- `s` unfolds or folds Snoozed.
- `PgUp` `PgDn`, `Home` `End` move a page, or to the first or last row. The wheel or a swipe scrolls.
- `q` or `Ctrl-C` leaves, and `Ctrl-Z` suspends until `fg`.
- `esc` closes a menu, then the asks, then clears the choice.

If a key can't act, or an answer is refused, the words above the keys say why. Every other command is in [The `sitrep` command](cli.md).

## Related

- [Answering from the edge of your screen](answering-edge.md)
- [A click takes you there](jump.md)
- [Same keys, wherever the board shows](keys.md)
