# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.1] - 2026-11-18

🔧 Changed
- Claude now refers to "the user" instead of "Lee" in its board instructions, tool descriptions, replies and messages — the board's wording reads correctly for anyone using it.
- CLI help text and refusal messages say "the user" or "you" instead of "Lee".

## [0.7.0] - 2026-11-18

💥 Breaking
- Notes are gone: the `sitrep note` command and Claude's note tool are removed, and the NOTES section no longer appears on the board — use asks, parked items or the status history instead.
- `sitrep board --json` (now version 4) replaces `log` with `history`, which holds only status changes — update any script that reads `log`.

✨ Added
- Settings › Snooze pane — switch each of six choices on or off (In an hour, Later today, Tonight, Tomorrow, This weekend, Next week) and set their hours, days and times; the menus and Claude Code's pane offer the same choices.
- Move a session to another project at your word — Claude's new move tool and `sitrep move <project>` carry the whole session over, and every window holding it follows.
- Status history in the Claude Code pane — every change of a session's status, opened from Status.
- Parked now has a "picked up" list showing what was picked up or closed, and says which session picked each item up.
- A project's view folds its old sessions (finished, or idle over a week) under its sessions, opened on demand.
- A session's view names its project as a press that opens it, and says when the session finished and why.

🔧 Changed
- Asks left open in a finished session wait on no one — they show faint with no buttons, and only the window still holding that session can reply.
- The recommended option now ends its own button's label rather than sitting beside it.
- Claude now posts an ask when it leaves you something to do, such as a release, a merge or a command to run.
- Strip tabs and rows cut long titles to fit while keeping the "more" count visible.
- A snooze wakes at the time its menu item showed, even if the menu stood open for a while, and a time already past is refused with a notice.

🐛 Fixed
- Editing an ask no longer refuses a change over a rule the edit doesn't touch, such as giving an older ask a new title.
- The hairline between rows in Settings no longer disappears on 1× screens.
- The welcome stage's pointer finds the ask's row again after you change the strip or notch settings while it plays.

## [0.6.0] - 2026-11-16

Sessions where Claude has stopped now count as your turn, and a click on a session no terminal on this Mac shows carries it on in a new window.

💥 Breaking
- The "Open command" setting is replaced by a resume command (`cd {dir} && claude --resume {claude}` by default) with new placeholders `{claude}`, `{dir}` and `{tty}` — `{session}`, `{socket}` and `{pane}` are gone, so set a new command in Settings › General if you wrote your own.
- `sitrep snooze` and `sitrep wake` now act on the whole session and no longer take `--turn` — name the asks the row shows after `--`, and use `--until` or none for "until it moves".

✨ Added
- Stopped sessions (Claude finished and it's your turn) count in Needs you in blue beside orange asks, light the notch, strip and menu bar glyph blue, and are counted separately in the section header.
- Clicking a session no terminal on this Mac shows opens a new Ghostty window that types your resume command; one suspended with Ctrl-Z takes you to its window and tells you to type `fg`.
- Sessions not shown on this Mac are dimmed on every surface, read every few seconds, with a remote login such as SSH not counting as here.
- Snooze a whole session from its row menu until later today, tomorrow, next week or until it moves — its asks and its turn go to Snoozed together and wake early on a new ask, your reply or your prompt in its window.
- Notification settings are now separate for a new ask and for Claude stopping: banner, sound and notch pulse for each, with the stopping ones off by default.
- Claude can mark a recommended option on a choice ask (`recommended`, or `--recommended` in the CLI) — it is shown beside the option on the board, and a typed "(recommended)" is read as that and removed.
- Right-click on the strip's marks, rows and counts opens a menu to jump, snooze, wake, and collapse or expand the section.
- Sections folded on the notch card or on the strip are now shared by both, and Snoozed sessions now appear on the strip.
- The strip shows a hairline between each section (Needs you, Working, Snoozed) and can fold a section into one count.
- Restore Default button for the resume command in Settings.
- Messages from the board now say under each ask whether the reply closes it or leaves it open for Claude to act on.
- The README and app carry a new logo.

🔧 Changed
- The "Your turn" section is merged into Needs you, with asks listed above stopped sessions and the menu's heading counting both.
- Clicking an away session's row, mark or menu item now acts on it instead of doing nothing, and its row lifts under the pointer like any other.
- Settings is reorganised: Terminal and Resume command sections in General, Ghostty permission moved under Terminal, and separate Banners, Sound and Notch groups under Notifications.
- The welcome stage no longer shows a "your turn" row.
- Jump refusals now include tmux's own error when it can't be reached, instead of reporting only that it gave no answer.

🐛 Fixed
- Resolving an ask you already closed, or a parked item you picked up, now passes quietly instead of being refused.
- `edit` now accepts an item's one line as either `text` or `title`.
- Other plugins' rows above the Claude Code prompt keep working beside the band on Claude Code 2.1.323 and later.
- A window whose conversation ends with `/clear` or an in-process `/resume` is no longer counted as still holding the old session.

## [0.5.0] - 2026-11-11

💥 Breaking
- `sitrep jump` and `sitrep screen` are removed from the CLI — SitRep now does its own jumping to a session's window; scripts that called them have no replacement.

✨ Added
- Clicking a session no terminal window shows opens a new Ghostty window running your own command — set the terminal and the open command (with `{session}`, `{socket}` and `{pane}` placeholders) under Settings → General → New windows.
- Captions and banners for opening a window — "Still opening…", "Opened a window for…", "A window for… is opening", and "SitRep could not open a window" when it fails.
- Items a session parks now belong to its project — any session of the project sees them on its board, and can resolve, reopen or edit them with the session's id.
- Picking up a parked item from a window sends the pick-up to that window's session, whichever session of the project parked it.
- Projects with only parked items now show in the lists, as "no current sessions (N parked)" in `sitrep list`.
- Windows in the board's JSON output carry `jumpOrder`, the order a jump tries a session's windows.

🔧 Changed
- Jumping to a session's window is now built into SitRep, rather than run through the CLI — it no longer starts the CLI for each click.
- Parked items no longer keep a session current, and finishing a session leaves what it parked in place.
- Jumps waiting on the watch's first board line wait for it, and are refused only if it never comes.

🐛 Fixed
- A quick second click on a session no longer opens a second window for it.

## [0.4.1] - 2026-11-09

Clicking a session, ask or notification now brings forward the Ghostty window for sessions running in zmx.

✨ Added
- Jump support for sessions in zmx — a click brings forward the Ghostty window attached to the session, as it already does for tmux.
- Session output in JSON now includes a `zmx` field with the session name (null where not in zmx).

🔧 Changed
- Jumps find a window's terminal app from the full command line of its processes — apps whose paths contain spaces, such as Visual Studio Code - Insiders, are recognised more reliably.
- Jumps into a window running tmux inside zmx, or zmx inside tmux, now use the innermost multiplexer's session.

## [0.4.0] - 2026-11-09

A welcome window and a tabbed Settings window replace the old SitRep window, so setup and settings live in one place instead of a big in-app board.

💥 Breaking
- The SitRep window is gone, along with "Open SitRep Window" and the "Your turn folds after" setting — use the notch, strip or menu to see sessions and click to jump, and the Claude Code board to answer asks.
- Answering asks, finishing sessions and `sitrep watch` following sessions are no longer done from the app — `sitrep answer`/`finish` still exist, but the app no longer drives them.

✨ Added
- Welcome window on first launch, reopenable from "Show Welcome Window" — walks through the edge, sound, permissions and plugin reload, with a live preview of your notch or strip.
- Settings is now its own window with General, Edge, Notifications and Claude Code panes, plus Back/Forward in the toolbar and ⌘[ / ⌘].
- Claude Code pane in Settings lists windows needing `/reload-plugins`, with Show and Copy buttons, and a count in the sidebar.
- Snooze a "Your turn" row from the notch card, including "Until it moves" — it returns when the session takes another turn (`sitrep snooze --turn`, `sitrep wake --turn`).
- A one-time callout beside the notch or strip after finishing the welcome, until you first point at it.
- "Still jumping…" and "Couldn't jump: the Mac is too busy" captions when a jump runs long or gives up.
- `sitrep screen` reports whether each open session is reachable on screen.
- Working arcs in the menu bar menu now turn while the menu is open.
- Attach an image to an answer typed in Claude Code's prompt — it goes straight to the session.
- Several sends can wait in Claude Code's Ready to send at once, each with its own take-back, and "send now" appears when you've interrupted Claude.
- A SIGTERM now quits SitRep cleanly, as Quit does.
- Developer tooling: `app/plugin here|app` switches the live plugin source.

🔧 Changed
- Card rows are now one line each, with a plain count after a session's name (e.g. "3" instead of "+2"), and sections are separated by spacing rather than a hairline.
- A later click on a jump replaces one in progress, instead of being refused while another runs.
- Away asks show a hollow orange ring and dimmed words instead of an orange dot.
- Needs you rows are now ordered newest first; Your turn now sits above Working.
- The menu bar menu lists every session, not just the first twelve.
- Jumping to a Ghostty window now uses Ghostty 1.4's terminal lookup instead of writing a marker to the terminal.
- New-ask notifications are posted oldest first, so the newest ends up on top.
- Claude is told to give questions in full in the chat after its last tool call, and is warned when its words reached you only as a summary.
- Strip marks for sessions on their own work now show a dotted ring.

🗑️ Removed
- "N earlier" folding on the card.
- The row button that opened a session in the SitRep window.

🐛 Fixed
- Truncated card titles no longer overrun their room.
- Menu bar rows keep their second line on macOS 26.
- Non-ASCII app paths no longer break jump lookups.
- Ghostty sessions are no longer reported as unreachable when tmux gives a control-mode client.

## [0.3.0] - 2026-10-28

Initial release.
