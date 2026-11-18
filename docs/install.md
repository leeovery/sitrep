# Installing and removing SitRep

One Homebrew command installs SitRep, and its first start installs the sitrep plugin into Claude Code.

## Requirements

- An Apple silicon Mac, on macOS 14 or later.
- Claude Code 2.1.326 or later, with the `claude` command installed.
- Homebrew.

Ghostty is recommended, not required. A click takes you to the exact window only in Ghostty. Any other terminal app comes forward whole: see [A click takes you there](jump.md).

## Installing

```bash
brew install --cask leeovery/tools/sitrep
```

The install leaves SitRep stopped, so open it from Applications. Then, in each Claude Code window already open, type:

```text
/reload-plugins
```

A window keeps the plugins it loaded until you reload them. A window you open later loads sitrep by itself.

## What the first start does

At its first start, SitRep installs the plugin it carries:

1. It copies the plugin to `~/Library/Application Support/sitrep`.
2. It adds that folder to Claude Code as the `sitrep` marketplace, with `claude plugin marketplace add`.
3. It installs `sitrep@sitrep`, with `claude plugin install`.

SitRep looks for `claude` where the Claude Code installers put it, then on the PATH of your login shell. Without it, SitRep installs nothing, and the menu says so.

If Claude Code already has a sitrep plugin, from a clone or another marketplace, SitRep leaves it alone. It installs no second copy, and runs that plugin's `sitrep` command.

The first start also opens the welcome window, which sets your first choices. Show Welcome Window, in the menu, opens it again.

## What SitRep asks macOS for

Apart from opening the app, SitRep works without any of these.

| What | When | Kept in System Settings |
|---|---|---|
| Opening an app from the internet | The first time you open SitRep | Not kept: asked once |
| Control Ghostty | Your first click that goes to Ghostty, or **Allow…** | Privacy & Security › Automation |
| Notifications | When you turn a banner on | Notifications, in the SitRep entry |
| Open at login | During the first welcome window | General › Login Items |

**Allow…** for Ghostty is in the welcome window, which opens Ghostty first if it isn't running. Settings › General shows it too, until macOS has asked. **Turn On…** in the welcome window turns on the banner for a new ask. If macOS holds Open at login for your approval, Settings › General says "Waiting for your approval in System Settings › Login Items".

## Updating

```bash
brew upgrade --cask sitrep
```

Homebrew quits SitRep and swaps in the new app. If SitRep was running, Homebrew opens it again. At that start, SitRep updates its copy of the plugin, and the plugin in Claude Code.

Each Claude Code window runs the old plugin until you type `/reload-plugins` there. Until then, the menu lists it under "Needs /reload-plugins".

## Removing SitRep

Remove the app first. A SitRep still installed puts the plugin back at its next start.

```bash
brew uninstall --cask sitrep
```

That removes the app only. To remove the copy of the plugin, the caches and the preferences too, add `--zap`:

```bash
brew uninstall --zap --cask sitrep
```

Then remove the plugin from Claude Code. Run these two commands even after a zap: Claude Code still lists the plugin from the folder the zap removed.

```bash
claude plugin uninstall sitrep@sitrep
claude plugin marketplace remove sitrep
```

### What stays on disk

| Folder | Removed by |
|---|---|
| `~/Library/Application Support/sitrep` | `--zap` only |
| `~/.local/state/sitrep`, the board | Nothing: delete it yourself |

No command here touches the board. Your sessions, asks and parked items stay in it until you delete the folder. A zap also leaves what macOS keeps in System Settings: the leave to control Ghostty, and the SitRep row in Notifications.

## When something's wrong

The menu bar item puts any trouble at the top of its menu, above your sessions:

| The menu says | What it means |
|---|---|
| SitRep can't find Claude Code | No `claude` command, where installers put it or on your PATH |
| SitRep can't find the sitrep plugin | Claude Code has sitrep from a place SitRep can't read; the line under it names the place |
| SitRep couldn't set up its plugin | A `claude plugin` step failed; the line under it gives the error |
| Needs /reload-plugins | These windows run an older plugin; click one to go to it |
| SitRep can't read the board | The board isn't current; the line under it says why |

SitRep tries again by itself, and runs the plugin it ran last meanwhile.

Settings › Claude Code shows the same: see [Settings, pane by pane](settings.md).

## Related

- [The `sitrep` command](cli.md)
- [Settings, pane by pane](settings.md)
- [Sounds, banners and the pulse](notifications.md)
