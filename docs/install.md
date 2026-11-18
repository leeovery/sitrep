# Installing and removing SitRep

One Homebrew command installs SitRep, and its first start installs the sitrep plugin into Claude Code. This page says what the install sets up and what SitRep asks macOS for. It shows how to update and how to remove every part, and what to do when something's wrong.

## Requirements

- An Apple silicon Mac, on macOS 14 or later.
- Claude Code 2.1.326 or later, with the `claude` command installed.
- Homebrew.

Ghostty is recommended, not required. Only Ghostty gets a click to its exact window: see [A click takes you there](jump.md).

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

SitRep never touches a sitrep it didn't install. For example, you may run the plugin from a clone of the repository, or have a `sitrep` plugin from another marketplace. Then SitRep changes nothing in Claude Code, and installs no second copy. It runs the `sitrep` command of that plugin instead.

The first start also opens the welcome window. It shows what SitRep does, and sets your first choices. The menu item Show Welcome Window opens it again at any time.

## What SitRep asks macOS for

Apart from opening the app, SitRep works without any of these. Each one turns on one thing.

| What | When | Where it's kept |
|---|---|---|
| Opening an app from the internet | The first time you open SitRep | Not kept: asked once |
| Control Ghostty | Your first click that goes to Ghostty, or **Allow…** | Privacy & Security › Automation |
| Notifications | When you turn a banner on | Notifications, in the SitRep row |
| Open at login | During the first welcome | General › Login Items |

The places in the last column are in System Settings.

- **Control Ghostty** lets a click bring the Ghostty window forward. **Allow…** is in the welcome window and in Settings › General. macOS asks only while Ghostty runs.
- **Notifications** are for banners, which are off until you turn them on. **Turn On…** in the welcome turns on Notify me of a new ask. In Settings › Notifications, turning on either banner asks macOS too.
- **Open at login** is on after the first welcome, unless you turned it off there. macOS confirms it with a notice. If macOS holds it for your approval, Settings › General says "Waiting for your approval in System Settings › Login Items".

## Updating

```bash
brew upgrade --cask sitrep
```

Homebrew quits SitRep and swaps in the new app. If SitRep was running, Homebrew opens it again. At that start, SitRep replaces its copy of the plugin with the one the new app carries. It also updates the plugin in Claude Code, so Claude Code records the new version.

Each Claude Code window runs the old plugin until you type `/reload-plugins` there. Until then, the menu lists it under "Needs /reload-plugins". A click on it takes you to the window.

If you run a sitrep that SitRep didn't install, an update leaves that plugin as it is.

## Removing SitRep

Remove the app first. A SitRep still installed puts the plugin back at its next start.

```bash
brew uninstall --cask sitrep
```

That quits SitRep and removes the app only. To remove the copy of the plugin, the caches and the preferences too, add `--zap`:

```bash
brew uninstall --zap --cask sitrep
```

Then remove the plugin from Claude Code:

```bash
claude plugin uninstall sitrep@sitrep
claude plugin marketplace remove sitrep
```

After a zap, Claude Code still lists the plugin from the folder the zap removed. So run these two commands either way.

### What stays on disk

| Folder | Removed by |
|---|---|
| `~/Library/Application Support/sitrep` | `--zap` only |
| `~/.local/state/sitrep`, the board | Nothing: delete it yourself |

No command here touches the board. Your sessions, asks and parked items stay in it until you delete the folder.

## When something's wrong

The menu bar item puts any trouble at the top of its menu, above your sessions:

| The menu says | What it means |
|---|---|
| SitRep can't find Claude Code | No `claude` command, where installers put it or on your PATH |
| SitRep can't find the sitrep plugin | Claude Code has sitrep from a place SitRep can't read; the line under it names the place |
| SitRep couldn't set up its plugin | A `claude plugin` step failed; the line under it gives the error |
| Needs /reload-plugins | These windows run an older plugin; click one to go to it |
| SitRep can't read the board | The board isn't current; the line under it says why |

After trouble with the plugin, SitRep tries again by itself. It waits a second at first, and up to half a minute later on. Meanwhile it runs the plugin it ran last, so the board stays.

Settings › Claude Code says the same. Its Claude Code plugin row reads "Up to date" while every window runs the current plugin. Otherwise it says how many windows run an older one, or what went wrong. Under Needs /reload-plugins, **Show** takes you to each window, and **Copy** copies the command.

## Related

- [The `sitrep` command](cli.md)
- [Settings, pane by pane](settings.md)
- [Sounds, banners and the pulse](notifications.md)
