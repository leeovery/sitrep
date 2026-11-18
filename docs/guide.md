# Using SitRep

The board in Claude Code, the app, and what installing sets up, in full; pages for each feature will replace this one.

## Installing

The install leaves SitRep stopped, so open it from Applications; macOS asks once whether to open an app downloaded from the internet. At its first start SitRep copies the plugin it carries to `~/Library/Application Support/sitrep` and installs it there through `claude plugin`. It leaves alone a sitrep it didn't install, such as a clone registered as the `sitrep` marketplace, and runs that one's CLI instead. It needs the `claude` CLI where Claude Code's installers put it, or on your login shell's PATH. Should the plugin's install fail, the menu bar item's menu says why under its header, and so does the plugin's row in Settings › Claude Code.

The install asks macOS for nothing. What SitRep can use, it asks for in Settings, under General and Notifications:

- **Leave to control Ghostty**, so a click on a session brings its window forward: asked at the first jump, or with Allow… in General, and kept in System Settings › Privacy & Security › Automation.
- **Notifications**, off until you turn on Notify me of a new ask or Notify me when Claude stops, and kept in SitRep's row in System Settings › Notifications.
- **Open at login**, a switch in General, which macOS may hold for your approval in System Settings › General › Login Items.

## The board in Claude Code

- **The pane**, opened by `/sitrep` or the band, has two tabs: this session, and All projects. A session shows its asks first, then its status, its project's parked items, its own first, and resolved asks. Its status opens to its history, every change of it, and Parked to what was picked up or closed, each closed until you open it. A session's project, named beside it, opens that project. All projects opens each project, and each project its sessions, with its old sessions (finished, or idle over a week) folded under them, and every item parked in it, each naming the session that parked it. A finished session says so, and its asks take no reply, but in the window that still holds it. A parked item can be picked up from any window of its project, and goes to the Claude in that window.
- **The band** is the line above the prompt: this session's asks, what waits elsewhere, and the pane's show or hide. A new ask pulses it and shows a toast.
- **Ready to send.** Your replies queue at the pane's foot, grouped by the session each goes to, until you press **send to Claude** or **cancel all**. A words ask's answer, or a comment, is written in Claude Code's prompt. A snooze, a wake or a finish takes effect at once; snoozing an ask snoozes its session.

## SitRep, the app

A menu bar app with no Dock icon, on every Space. The notch and the strip step off the screen while a full-screen app has their display, and come back as it leaves.

- **The notch** sits at the screen's left or right edge, a little above the middle, and opens on hover into a panel of your sessions: Needs you, Working (those on their own work at its end) and Snoozed. It swells and lights when something needs you, and never takes the keyboard. Drag it along the edge, or across the middle to the other side.
- **Needs you** holds a row per session: first those with asks, in orange, then those where Claude has stopped and it's your turn, in blue, which SitRep calls **Stopped**. A session with asks is one orange row, however its turn stands. The section's header counts the asks in orange and the stopped in blue. The notch's light is orange while any ask waits, else blue while any session has stopped.
- **The strip** can stand in its place: a narrow column along the edge, a mark for each session, its ring carrying the session's state, that grows with what's on it or runs the screen's height.
- **The menu bar item** lists the panel's sessions under one total, "3 need you", each a click to its session. Then come Show (Notch, Strip or Nothing), Show Welcome Window, Settings… and Quit SitRep. Above the list it speaks up, in this order, when the plugin is in trouble, when a window needs `/reload-plugins`, and when SitRep can't read the board. Its glyph lights as the notch does.
- **A session this Mac doesn't show** is dimmed wherever rows are drawn, an ask's mark a hollow ring: its Claude has ended, runs where no terminal on this Mac shows it, or is reached only from another device. SitRep tells by reading which terminals each Claude descends from, every few seconds; a remote login, such as SSH, doesn't count.
- **Snooze**, on a row's menu, puts the session off in an hour, later today, tonight (offered until its time), tomorrow, this weekend (off by default), next week, or until it moves, its next turn ending, each time as Settings' Snooze pane sets it. Its asks and its turn go together into Snoozed, and come back at their time, or sooner with a new ask, your reply to one of its asks, or your prompt in its window.
- **Settings**, a window of its own (⌘,):
  - General: Open at login; the terminal new windows open in, Ghostty, with the leave to control it; and the resume command, with Restore Default.
  - Edge: Show (Notch, Strip or Nothing); its edge and display; for the notch, Style (Meniscus or Card); for the strip, Length (Grows or Full), and a Max slider at Grows; Black or Glass (from macOS 26); and Reduce motion.
  - Notifications: a test notification; banners, a sound and a pulse at the edge, each set apart for a new ask and for Claude stopping. A new ask's sound and pulse are on by default, the sound one of macOS's alert sounds, Glass unless you pick another; its banner is off, and so is everything for Claude stopping.
  - Snooze: each of Snooze's six choices on or off, and its time: Later today's hours, Tonight's and Tomorrow's times, This weekend's day and time (off by default), and Next week's day and time. SitRep writes them to `snooze.json` in the board's folder, which Claude Code's pane reads.
  - Claude Code: the plugin's state, and the windows that need `/reload-plugins`.
- **A new ask** plays the sound once, whichever session it lands in, and, with banners on, posts a silent macOS notification whose click takes you to the session. Claude stopping does the same, with its own settings.
- **A click on a session** goes by whether this Mac shows it, read again at the click:
  - shown: the jump brings forward the Ghostty window showing it, on whatever Space it is: in tmux, selecting the session's tmux window where no client shows it; in zmx, the window attached to the session. A terminal with no driver is brought forward whole;
  - its Claude suspended with Ctrl-Z in a window here: the jump, saying to type `fg`;
  - otherwise SitRep opens a new Ghostty window and types your **resume command** into your login shell there. The default is `cd {dir} && claude --resume {claude}`; `{claude}` is the session's Claude Code session id, `{dir}` the folder it ran in, and `{tty}` the terminal that Claude still runs on, empty unless it does, each replaced with a quoted value. Set your own in Settings › General, such as one that attaches the tmux session holding the Claude. The default refuses while that Claude may still be running elsewhere, since it would resume a second beside it; a command you set always runs.
