# The board in any terminal

Type `sitrep` in a terminal, and the terminal view fills it with the board: what waits on you, and what is running. Leave it open in a Ghostty tab beside your work. Or reach it over SSH from a phone or an iPad, where no notch shows. Pick a session, and your resume command carries it on in that terminal.

![The terminal view in a terminal window, 73 columns wide. Under NEEDS YOU, counted 4 in orange and 2 in blue, come six sessions, each on two lines: the name and how long it has waited, then the project and status line. Data import asks to allow Bash, Help desk redesign asks whether to thread replies, and Shift schedules wants the rota approved, each with an orange dot. Email templates has a hollow orange dot and dimmed words. Release notes is Stopped, with a blue dot, and Warehouse map has a hollow blue one. Under WORKING 3, Mobile app runs npm test, Invoice ledger exports the ledger, and Catalog sync waits on 2 agents. SNOOZED 2 is folded. The last line reads ↑↓ pick, s snoozed, q quit.](../art/screens/terminal.webp)

*Needs you comes first, then Working. Snoozed starts folded.*

## Try it

1. Open a terminal on your Mac, or sign in to the Mac over SSH from your phone or iPad.
2. Type `sitrep`. The board fills the terminal.
3. Press `↓` to choose a session, then `⏎` to carry it on in this terminal.
4. Press `q` to leave. Your shell comes back as it was.

The Homebrew install links `sitrep` into the Homebrew `bin` folder, so any login shell on the Mac finds it.

## What happens

- **Sessions come in three sections.** Needs you comes first, then Working. Snoozed comes last, folded until you press `s`. Each session takes two lines: the name and a time, then the project and status line.
- **The dots match the notch.** An orange dot has asks or a permission prompt waiting, and a blue dot is Stopped. `✻` is working, and `◌` waits on work of its own, such as background agents.
- **A dimmed session has a hollow dot.** No terminal on this Mac shows that session. The notch dims the same sessions.
- **The board stays current.** It redraws within a second of each change, so you can leave it open for hours. The chosen row stays with its session while rows move.
- **A new ask posts a terminal notification.** The title is the ask, and the body names the project and session. To open the board without them, type `sitrep --no-notify`.
- **`⏎` runs your resume command here.** It is the command from Settings › General, run in this terminal. When the command ends, the board comes back.

## Good to know

- **The default command resumes only a session no window runs.** For a session open in a window, the default refuses, because it would start a second Claude. Set your own command that reaches that window, for example by attaching its zmx session. A session whose window runs in neither tmux nor zmx can't be reached from here. See [A click takes you there](jump.md).
- **The command runs in your login shell.** That shell reads `.zprofile` but not `.zshrc`, so an alias or a function from `.zshrc` won't run. A script on your PATH works. Like a click, it runs only plain shell syntax.
- **Notifications need a terminal that shows them.** The terminal view sends OSC 777, which Ghostty shows as a macOS notification. Inside tmux, set `allow-passthrough on`, or tmux holds it back.
- **Hollow dots need SitRep running.** SitRep tells the terminal view which sessions this Mac doesn't show. Without SitRep, only a session no window runs draws hollow.

## Reference

The last line of the terminal lists the keys that work now. These are all of them:

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j`, a tap | Choose a row, then move between rows |
| `PgUp` `PgDn` | Move by the rows in view |
| `Home` `End` | Go to the first or the last row |
| `⏎`, or a tap on the chosen row | Run the resume command for it |
| `s` | Open or fold Snoozed |
| `esc` | Clear the choice and any refusal |
| `q`, `Ctrl-C` | Leave |
| `Ctrl-Z` | Suspend the terminal view; `fg` brings it back |

If a pick can't run, a line above the keys says why. In a script or a pipe, `sitrep` with no command prints the help and opens nothing. Every other command is in [The `sitrep` command](cli.md).

## Related

- [A click takes you there](jump.md)
- [Settings, pane by pane](settings.md)
- [The edge of your screen](notch.md)
