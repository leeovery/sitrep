# Settings, pane by pane

Settings is a window of its own, with five panes in a sidebar. This page lists every control, with the choices and the default for each. Each pane links to the page that explains it.

To open Settings, click the SitRep icon in the menu bar, and choose **Settings…**. If a SitRep window is in front, ⌘, opens it too. Settings opens on the pane it last showed.

## General

How a new window opens for a session, and how SitRep starts. See [A click takes you there](jump.md).

| Control | Choices | Default | What it does |
|---|---|---|---|
| Open at login | On, off | On, from the welcome window | Starts SitRep when you log in |
| Terminal | Ghostty | Ghostty | The terminal a new window opens in |
| Bring a session's Ghostty window to the front | Allow…, or Open System Settings… | Asked at the first jump | Lets a click reach the window |
| Command | Any command | See below | Typed in a new Ghostty window |

SitRep types the command only for a session that no terminal on this Mac shows. The default resumes the session in Claude Code:

```text
cd {dir} && claude --resume {claude}
```

SitRep replaces each placeholder with a quoted value: see [A click takes you there](jump.md). **Restore Default** puts the default back.

## Edge

What stands at the edge of your screen. See [The edge of your screen](notch.md).

| Control | Choices | Default | What it does |
|---|---|---|---|
| Show | Notch, Strip, Nothing | Notch | What shows at the edge |
| Edge | Left, Right | Left | The side it stands on |
| Display | Main display, or another | Main display | The screen it shows on |
| Style | Meniscus, Card | Meniscus | How the notch opens |
| Length | Grows, Full | Grows | How long the strip is |
| Max | A slider | Full | How far the strip grows |
| Material | Black, Glass | Black | The look, from macOS 26 |
| Reduce motion | On, off | Off | Less movement at the edge |

The pane shows only the settings for your choice under Show. Style is for the notch only. Length and Max are for the strip only, and Max shows only at Grows. With Nothing, the menu bar item carries the board, and the pane holds only Show.

## Notifications

What a new ask does, and what Claude stopping does. See [Sounds, banners and the pulse](notifications.md).

| Control | Choices | Default | What it does |
|---|---|---|---|
| Notify me of a new ask | On, off | Off, unless the welcome window turns it on | A banner for each ask |
| Notify me when Claude stops | On, off | Off | A banner titled "Stopped" |
| Play a sound for a new ask | On, off | On | Once, whichever session |
| Sound | macOS alert sounds | Glass | The sound for a new ask |
| Play a sound when Claude stops | On, off | Off | Once, as a turn ends |
| Sound | macOS alert sounds | Tink | The sound for Claude stopping |
| Pulse for a new ask | On, off | On | Swells and flashes for an ask or a prompt |
| Pulse when Claude stops | On, off | Off | The notch swells and flashes |

At the top of the pane, **Send Test** sends a sample banner. Under the banner switches, a setting says what macOS allows. If macOS stops banners, **Notification Settings…** opens the place in System Settings to allow them.

## Snooze

The choices that Snooze offers, in the menus and in the pane in Claude Code. See [Putting a session off](snooze.md).

| Choice | Its setting | Default | When it wakes |
|---|---|---|---|
| In an hour | None | On | An hour from now |
| Later today | 1 to 4 hours | On, 3 hours | That many hours on |
| Tonight | A time | On, 18:00 | That time today |
| Tomorrow | A time | On, 09:00 | That time tomorrow |
| This weekend | Saturday or Sunday, a time | Off, Saturday 09:00 | That day this week |
| Next week | A day, a time | On, Monday 09:00 | That day next week |

Each choice has a switch, and a choice switched off is not offered. Tonight and This weekend are not offered once their time has passed. The menus also offer **Until it moves**, which has no time.

## Claude Code

The plugin that puts each Claude Code session on the board. See [Installing and removing](install.md).

| Row | What it shows |
|---|---|
| Claude Code plugin | "Up to date"; how many windows run an older plugin; or what is wrong |
| A window under Needs /reload-plugins | A window that runs an older plugin, with **Show** |

The Needs /reload-plugins section shows only while a window runs an older plugin. **Show** takes you to that window. **Copy** copies `/reload-plugins`, for you to type in each one. While any window waits, the sidebar shows their number beside Claude Code.

## Related

- [The edge of your screen](notch.md)
- [Sounds, banners and the pulse](notifications.md)
- [Putting a session off](snooze.md)
