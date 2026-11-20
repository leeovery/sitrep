# The board in any terminal

Type `sitrep` in a terminal, and the terminal view fills it with the board: what waits on you, and what is running. Leave it open in a Ghostty tab, or reach it over SSH from a phone or iPad. Open a session no window runs, and your resume command carries it on there.

![The terminal view in a terminal window. Under NEEDS YOU, counted 3 in orange and 1 in blue, come three sessions, each on two lines: the name and a time, then the project and what it waits on. Help desk redesign has an orange dot and a count of 2. Data import has a hollow orange dot and dimmed words. Shift schedules has a blue dot, Stopped. Under WORKING 2, Mobile app is running npm test, and Invoice ledger is waiting on 2 agents. SNOOZED 1 is folded. The last line reads ↑↓ pick, s snoozed, q quit.](../art/screens/terminal.webp)

*Three sessions need you, one of them run by no window, while two work.*

## Try it

1. Open a terminal on your Mac. Or sign in to the Mac over SSH, with Remote Login on in System Settings › General › Sharing.
2. Type `sitrep`. The board fills the terminal.
3. Press `↓` to reach a session no window runs, such as one whose Claude you quit, then press `o` to open it here.
4. Press `q` to leave, back to your shell.

Homebrew links `sitrep` into the Homebrew `bin` folder, which a shell needs on its PATH.

## What happens

- **Sessions come in three sections.** Needs you comes first, then Working. Snoozed comes last, folded until you press `s`. Each session takes two lines: the name, a count if more than one thing waits, and a time. Then come the project and what the session waits on or is doing. Press `⏎` to expand a row the width cuts short.
- **A dot says what waits.** An orange dot has asks or a permission prompt waiting, and a blue dot is Stopped. A row new to Needs you shows `◉` for 2 seconds. In Working, `✻` runs a turn, and `◌` waits on work of its own.
- **A dimmed session has dimmed words.** It isn't open on the device you're looking from. In Needs you, its dot is hollow, and a Working row keeps `✻` or `◌`. In Snoozed, nothing marks it.
- **The board stays current** within a second, the chosen row following its session. Each new ask posts a terminal notification. To turn notifications off, type `sitrep --no-notify`.
- **`o` runs your resume command here.** Set it in Settings › General. When it ends, the terminal view comes back.
- **`z` snoozes the chosen row** from the Snooze menu, with your times from Settings › Snooze. In Snoozed, `z` wakes the row.

## Good to know

- **The default command refuses a session a window still runs,** even a hollow one, because it would start a second Claude. To reach that window, set a script that takes `{tty}` and `{claude}`. It attaches the tmux or zmx session on `{tty}`, or resumes `{claude}` if `{tty}` is empty. A window in neither can't be reached from here. See [A click takes you there](jump.md).
- **The command runs in your login shell:** sh, bash, zsh, dash or ksh only. With fish, `o` opens nothing, and says why. In zsh, it reads `.zprofile` but not `.zshrc`, so a `.zshrc` alias won't run. A script on your PATH will.
- **Notifications need a terminal that shows them.** The terminal view sends OSC 777, which Ghostty shows as a macOS notification. Inside tmux, set `allow-passthrough on`, or tmux holds it back.
- **Dimming needs SitRep running.** Without SitRep, only a session no window runs is dimmed.

## Reference

The last line names the main keys. Here is every key:

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j`, a click or a tap | Choose a row, then move between rows |
| `PgUp` `PgDn`, `Home` `End` | Move a page, or to the first or last row |
| The wheel, or a swipe | Scroll the rows; the chosen row stays |
| `⏎`, or a tap on the chosen row | Expand the chosen row, or fold it |
| `o` | Open the chosen row: run the resume command |
| `z` | Snooze the chosen row, or wake it |
| `s` | Unfold or fold Snoozed |
| `q`, `Ctrl-C` | Leave; `Ctrl-Z` suspends, and `fg` brings it back |

`esc` closes the Snooze menu, or else clears the choice. Any key clears the words above the keys. If `o` or `z` can't act, or the command fails within 2 seconds, those words say why. Every other command is in [The `sitrep` command](cli.md).

## Related

- [A click takes you there](jump.md)
- [Settings, pane by pane](settings.md)
- [The edge of your screen](notch.md)
