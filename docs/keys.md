# Same keys, wherever the board shows

Press `z` on a session to snooze it, `o` to go to its window, and `1` to answer an ask. Each key does the same thing wherever it works: at the notch, in the terminal view, and in Claude Code. Press ⌃⌥S, and you reach every session without the mouse.

## Try it

1. Open Settings › Edge. Under Keys, click **Allow…** beside Accessibility. In the macOS prompt, click **Open System Settings**, and turn SitRep on.
2. Press ⌃⌥S. The panel opens, with the first session in Needs you chosen.
3. If the chosen session has no ask, press `↓` until one does. Then press `⏎`, and the asks panel opens.
4. Press `1` to send the first answer. For two seconds, `⌘Z` takes it back.

## What happens

- **Pointing gives the panel the keys.** Once the pointer moves on the panel, the row under it is the chosen row. The first key that isn't one of the panel's keys goes to the window in front. The panel then lets go until the pointer moves again.
- **The shortcut gives the panel every key.** Opened with ⌃⌥S, the panel holds the keys until it closes, and other plain keys do nothing. `esc` closes a menu, then the asks panel, then the panel. ⌃⌥S again or `o` closes it too.
- **`⏎` looks closer, and `o` goes there.** On the panel, `⏎` opens the asks panel for the chosen row, and `o` jumps to the window.
- **Numbers choose what is open.** In the asks panel, `1` to `9` answer, and each answer row shows its number in a keycap. `1` is the first row: on a choice, the option Claude recommends, if it marked one. The Snooze menu that `z` opens numbers its choices, and so does the **Snooze ▾** menu.
- **The pane presses buttons by key.** In Claude Code, `1` to `9` press the answers of an opened ask in order. `x` presses `✕ ignore` or `✕ drop`, and `z` presses `snooze` for that ask only.

## Good to know

- **The panel needs Accessibility to read keys.** Without it, the panel takes no keys and shows no keycaps, and ⌃⌥S opens it with nothing chosen. Settings › Edge then says "Not allowed, so the notch's panel takes no keys".
- **Keys with ⌘, ⌃, ⌥ or Fn go through.** Unless a menu is open, such a key reaches the window in front, and so does F1 to F20. Under the shortcut, it closes the panel too. Only the shortcut itself, and `⌘Z` while an answer sends, stay with SitRep.
- **A password prompt turns the keys off.** While a window takes a password, for example Ghostty at a `sudo` prompt, macOS gives SitRep no keys.
- **The pane takes keys only while it holds the keyboard.** Press ctrl+x tab or click the pane first, and `esc` hands the keys back to the prompt. The pane draws no numbers.

## Reference

On the panel, with a session chosen:

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j` | Choose another row |
| `⏎` | Open or close the asks panel |
| `o` | Jump to the window |
| `z` | Open the Snooze menu, or wake a snoozed row |
| `s` | Unfold or fold Snoozed |
| `esc` | Close the panel |

In the asks panel, for the ask it shows:

| Key | What it does |
|---|---|
| `1`–`9` | Answer with that row |
| `x` | Ignore |
| `z` | Open the **Snooze ▾** menu |
| `o` | **Open in Claude ↗** |
| `←` `→` | Show the ask before or after |
| `⏎`, `esc` | Close the asks panel |
| `⌘Z` | Undo, while an answer sends |

In the Snooze menu that `z` opens, and the **Snooze ▾** menu, `1` to `9` choose and `z` closes. There, `k` `j` move like `↑` `↓`. The Snooze menu from a right-click has no numbers.

The terminal view keeps its own list: see [The board in any terminal](terminal.md).

If Show is set to Nothing, or a full-screen app hides the notch, ⌃⌥S opens the menu of the menu bar item.

To change or clear the shortcut, see [Settings, pane by pane](settings.md).

## Related

- [The edge of your screen](notch.md)
- [Answering from the edge of your screen](answering-edge.md)
- [The board in any terminal](terminal.md)
