# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
