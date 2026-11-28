# Same keys, wherever the board shows

Press `z` on a session to snooze it, `o` to go to its window, and `1` to answer an ask. These keys work the same at the notch, in the terminal view, and in Claude Code. Press ⌃⌥S, and you reach every session without the mouse.

## Try it

1. Open Settings › Edge. Under Keys, click **Allow…** beside Accessibility. In the macOS prompt, click **Open System Settings**, and turn SitRep on.
2. Press ⌃⌥S. The panel opens, with the first session in Needs you chosen.
3. If the chosen session has no ask, press `↓` until one does. If the notch is on the right, press `←`; otherwise press `→`. The asks panel opens.
4. Press `1` to send the first answer. For two seconds, `⌘Z` takes it back.

## What happens

- **Pointing gives the panel the keys.** The panel takes the keys as your pointer opens it, and the row under the pointer is chosen. Off the rows, `↓` chooses the first. The first key the panel doesn't use goes to the window in front, then lets go until the pointer moves.
- **The shortcut gives the panel every key.** Opened with ⌃⌥S, the panel holds the keys until it closes, and other plain keys do nothing. `esc` closes a menu, then the asks panel, then the panel. `⏎`, `o` and ⌃⌥S close it too.
- **`⏎` goes there, and the arrow keys look closer.** `⏎` and `o` jump to the window. The arrow key pointing away from the notch opens the asks panel, then pages on. The other arrow key pages back, then closes it.
- **Numbers choose what is open.** In the asks panel, `1` to `9` answer, and each answer row shows its number in a keycap.
- **The pane presses buttons by key.** In Claude Code, `1` to `9` press the answers of an opened ask in order. `x` presses `✕ ignore` or `✕ drop`, and `z` presses `snooze` for that ask only.

## Good to know

- **The panel needs Accessibility to read keys.** Without it, the panel takes no keys and shows no keycaps, and ⌃⌥S opens it with nothing chosen. Settings › Edge then says "Not allowed, so the notch's panel takes no keys".
- **Keys with ⌘, ⌃, ⌥ or Fn go through.** Unless a menu is open, such a key reaches the window in front, and so does F1 to F20. Under the shortcut, it closes the panel too. Only the shortcut itself, and `⌘Z` while an answer sends, stay with SitRep.
- **A password prompt turns the keys off.** While a window takes a password, macOS gives SitRep no keys.
- **The pane takes keys only while it holds the keyboard.** Press ctrl+x tab or click the pane first, and `esc` hands the keys back to the prompt. The pane draws no numbers.

## Reference

With the notch on the right, `←` and `→` swap.

On the panel:

| Key | What it does |
|---|---|
| `↑` `↓`, `k` `j` | Choose another row |
| `⏎`, `o` | Jump to the window |
| `→` | Open the asks panel |
| `z` | Open the Snooze menu, or wake a snoozed row |
| `s` | Unfold or fold Snoozed |
| `esc` | Close the panel |

In the asks panel:

| Key | What it does |
|---|---|
| `1`–`9` | Answer with that row |
| `x` | Ignore |
| `z` | Open the **Snooze ▾** menu |
| `⏎`, `o` | **Open in Claude ↗** |
| `→` | Show the next ask |
| `←` | Show the ask before, or close |
| `esc` | Close the asks panel |
| `⌘Z` | Undo, while an answer sends |

In both Snooze menus, `1` to `9` choose and `z` closes, and `k` `j` move like `↑` `↓`.

The terminal view keeps its own list, in [The board in any terminal](terminal.md). Its asks differ:

- `⏎` opens the asks of a row.
- `←` `→` page.
- `u` undoes an answer, because `⌘Z` can't reach a terminal.

With Show set to Nothing, or the notch hidden by a full-screen app, ⌃⌥S opens the menu bar item's menu.

To change or clear the shortcut, see [Settings, pane by pane](settings.md).

## Related

- [The edge of your screen](notch.md)
- [Answering from the edge of your screen](answering-edge.md)
- [The board in any terminal](terminal.md)
