# The board in any terminal

Type `sitrep` in a terminal, and the terminal view fills it with the board: what waits on you, and what is running. Leave it open in a Ghostty tab beside your work. Or reach it over SSH from a phone or an iPad, where no notch shows. Open a session whose Claude has ended, and your resume command carries it on in that terminal.

![The terminal view in a terminal window. Under NEEDS YOU, counted 3 in orange and 1 in blue, come three sessions, each on two lines: the name and a time, then the project and what it waits on. Help desk redesign has an orange dot and a count of 2. Data import has a hollow orange dot and dimmed words. Shift schedules has a blue dot, Stopped. Under WORKING 2, Mobile app is running npm test, and Invoice ledger is waiting on 2 agents. SNOOZED 1 is folded. The last line reads ↑↓ pick, s snoozed, q quit.](../art/screens/terminal.webp)

*Three sessions need you, one of them with no window left, while two work.*

## Try it

1. Open a terminal on your Mac. Or sign in to the Mac over SSH, with Remote Login on in System Settings › General › Sharing.
2. Type `sitrep`. The board fills the terminal.
3. Press `↓` to reach a session whose Claude has ended, its dot hollow. Press `⏎` to open it here.
4. Press `q` to leave, back to your shell.

Homebrew links `sitrep` into the Homebrew `bin` folder, which a shell needs on its PATH.

## What happens

- **Sessions come in three sections.** Needs you comes first, then Working. Snoozed comes last, folded until you press `s`. Each session takes two lines: the name, a count if more than one thing waits, and a time. Then come the project and what the session waits on or is doing.
- **A dot says what waits.** An orange dot has asks or a permission prompt waiting, and a blue dot is Stopped. A row new to Needs you shows `◉` on an orange wash for 2 seconds. In Working, `✻` runs a turn, and `◌` waits on work of its own.
- **A dimmed session has dimmed words.** No terminal on this Mac shows it, the same sessions the notch dims. In Needs you, its dot is hollow, and a Working row keeps `✻` or `◌`. In Snoozed, only the dot dims, and it stays filled.
- **The board stays current,** within a second of each change. The chosen row stays with its session while rows move.
- **A new ask posts a terminal notification.** It shows the ask, the project and the session. Asks waiting at the start post none. To open the terminal view without notifications, type `sitrep --no-notify`.
- **`⏎` runs your resume command here.** It is the command from Settings › General. When the command ends, the terminal view comes back.

## Good to know

- **The default command refuses a session a window still runs,** because it would start a second Claude. To reach that window, set a script that takes `{tty}` and attaches the tmux or zmx session on that device. A window in neither can't be reached from here. See [A click takes you there](jump.md).
- **The command runs in your login shell:** sh, bash, zsh, dash or ksh only. With fish, `⏎` opens nothing, and says why. If that shell is zsh, it reads `.zprofile` but not `.zshrc`, so a `.zshrc` alias won't run. A script on your PATH works.
- **Notifications need a terminal that shows them.** The terminal view sends OSC 777, which Ghostty shows as a macOS notification. Inside tmux, set `allow-passthrough on`, or tmux holds it back.
- **Dimming needs SitRep running.** SitRep tells the terminal view which sessions this Mac doesn't show. Without SitRep, only a session no window runs is dimmed.

## Reference

The last line names the main keys. Here are all of them:

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j`, a click or a tap | Choose a row, then move between rows |
| `PgUp` `PgDn` | Move by the rows in view |
| `Home` `End` | Go to the first or the last row |
| The wheel, or a swipe | Scroll the rows; the chosen row stays |
| `⏎`, or a click or a tap on the chosen row | Run the resume command for the chosen row |
| `s` | Unfold or fold Snoozed |
| `esc` | Clear the choice and any words above the keys |
| `q`, `Ctrl-C` | Leave; `Ctrl-Z` suspends, and `fg` brings it back |

If `⏎` can't run the command, or the command fails within 2 seconds, words above the keys say why. Every other command is in [The `sitrep` command](cli.md).

## Related

- [A click takes you there](jump.md)
- [Settings, pane by pane](settings.md)
- [The edge of your screen](notch.md)
