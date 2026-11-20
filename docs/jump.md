# A click takes you there

With several Claude Code windows open, finding the one that needs you takes time. A click on a session in SitRep brings forward the Ghostty window running it, on whatever Space it is. If no terminal on this Mac shows the session, SitRep opens a new Ghostty window and resumes the conversation there.

## Try it

1. Hover over the notch, and click a session in the panel.
2. The first time, macOS asks whether SitRep may control Ghostty. Click **Allow**.
3. Ghostty comes forward, with the Claude Code window running that session in front.

A click works the same from other places:

- a mark on the strip;
- a session in the menu bar item;
- a banner;
- **Jump to the window**, in the menu that opens when you right-click a session.

## What happens

At each click, SitRep checks again whether this Mac shows the session. So a row drawn a few seconds before never sends you to the wrong place.

| If the session is | A click |
|---|---|
| In a Ghostty window | Brings that window forward |
| In a tmux window no terminal shows | Selects that tmux window, then brings it forward |
| In zmx | Brings forward the terminal window attached to it |
| In another terminal app | Brings that app forward whole |
| Suspended with Ctrl-Z, on this Mac | Brings the window forward, and says to type `fg` |
| Shown by no terminal on this Mac | Opens a new Ghostty window, and types the resume command |

## Good to know

- **The default never resumes a second Claude.** If the session's Claude may still be running somewhere this Mac doesn't show, the default resume command refuses, and a banner says why. A command you set always runs: what it does is yours.
- **Ghostty must be running, at 1.4 or later.** SitRep opens a new window only in a Ghostty already running, and refuses an older Ghostty. Ghostty is the only terminal that gets an exact window, or a new one.
- **Control of Ghostty is a macOS setting.** To give it before your first jump, press **Allow…** in Settings › General. If you refused it, press **Open System Settings…** there, and turn SitRep on for Ghostty under Automation.
- **One click, one window.** A second click on the same session, while its window opens, opens no other. A click on another session stops the first jump.

## Reference

SitRep types the resume command into your login shell, in the new Ghostty window, with a Return. This is the default:

```text
cd {dir} && claude --resume {claude}
```

SitRep replaces each placeholder with a quoted value:

| Placeholder | Replaced with |
|---|---|
| `{claude}` | The Claude Code session id of the conversation |
| `{dir}` | The folder that Claude ran in |
| `{tty}` | The terminal device that Claude still runs on; empty if none |

Set your own in Settings › General, under Resume command. A one-liner, an alias, a function or a script all work. **Restore Default** puts the default back.

SitRep runs only plain shell syntax, so a folder name never runs as code. The command may hold:

- words, and a `~` at the start of one;
- `|`, `||`, `&&` and `;`;
- redirections: `<`, `>`, `>>` and `2>&1`;
- tests, such as `[ -n "$s" ]`;
- single quotes, and double quotes around text;
- variables, such as `$s` and `${s}`;
- `$(…)`, holding the same.

Leave each placeholder outside quotes, because SitRep quotes the value itself. A banner names any other part, for example a backtick or `${x:-y}`. Put that part in a script, and pass the script the placeholders:

```text
~/bin/resume {claude} {dir}
```

## Related

- [The edge of your screen](notch.md)
- [Settings, pane by pane](settings.md)
- [Installing and removing](install.md)
