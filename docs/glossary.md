# Glossary: the board's words

Each word below means one thing on every page of these docs. The words are grouped by where you meet them, and listed A to Z in each group.

## On the board

**ask**: Something only you can do or decide, posted by Claude. It wants a yes, a choice or words back. It waits on you until you send a reply, Claude resolves it, or its session is finished. Snoozing its session only pauses it.

**the board**: Everything Claude keeps for you: projects, the sessions in them, and their items. It is a folder of files in `~/.local/state/sitrep`, with no server, account or database. In Claude Code, the button that opens the pane says `▸ show board`.

**current**: A session that isn't finished, and has a window, an ask waiting, or a change in the last 7 days. The first message Claude gets in a conversation lists only current sessions.

**finished**: A session that is closed. Claude finishes one once nothing is left on it. You can finish one from the pane if no window runs it, and its open asks then stop counting. Its parked items stay with the project.

**inbox**: Where a reply waits until a window of its session sends it on to Claude. Replies for another session go there, and so do answers from the asks panel or `sitrep answer`. Each session has one.

**item id**: The short id of an ask or a parked item, such as `xsaq`. The `sitrep` command prints an item id when it posts an ask or parks an item. Its other commands, such as `answer` and `snooze`, take the id.

**old session**: A session that is no longer current: finished, or 7 days with no window, no ask waiting and no change. A project in the pane folds its old sessions under `show old sessions`.

**parked item**: Something Claude raised and put off, to come back to later. It belongs to the project, and names the session that parked it. It never counts as waiting on you. Under PARKED in the pane, `show picked up` lists the items you picked up or dropped, and those Claude closed.

**project**: What a session is about, named by Claude the way you'd say it, such as Northwind. It is roughly a repository. The folder a window started in never decides it.

**resolved**: An item that is done with: an ask your reply closed, or any item Claude closed. The pane lists the resolved asks of a session under RESOLVED. Asks you ignored don't show there.

**session**: One line of work with Claude, with a status and asks. The items it parks belong to its project. It outlives its window. After `/clear`, or in a new window told to carry on, it is the same session.

**session id**: The id the board gives a session, such as `sr-nw0001`. Claude uses it to join a session. The pane and the Mac app never show it, but the `sitrep` command does. It is not Claude Code's own session id, which names one conversation and changes on `/clear`.

**Snooze menu**: The list of snooze choices, each with the time it wakes, then Until it moves. In the Mac app, it opens from **Snooze** when you right-click a row. In the terminal view, `z` opens it under the chosen row. **Snooze ▾** in the asks panel offers the times only, for one ask.

**snoozed**: Put off by you until a time you pick: a whole session, or one ask. In a snoozed session, the asks and your turn there stop counting until it wakes, and a new ask wakes it at once. A session can also snooze until it moves. A snoozed ask stops counting by itself, and nothing new wakes it. Only you can snooze: Claude has no way to.

**status**: Where a session stands: its name, a one-line summary, what is under way now, and what comes next.

**Stopped**: A session at your turn: Claude has stopped and waits for your next message, with no ask waiting. The Mac app shows it in blue, and titles its banner Stopped. The pane has no label for it, and says "your turn there" only when it asks whether to snooze a session.

**Until it moves**: The snooze choice with no time. It wakes the session when Claude next ends a turn there, or sooner, the way any snooze wakes.

**window**: One running Claude Code, wherever it shows: a Ghostty window, a tab, or a tmux pane. A window runs one session at a time.

## In Claude Code

**the band**: The line above the Claude Code prompt. It counts the asks of this session and the asks waiting elsewhere, and ends with the button that shows or hides the pane. Each count opens the pane.

**drop**: Taking a parked item off the board from the pane, once you confirm. Claude learns only that the item is gone.

**the pane**: The board inside Claude Code, opened with `/sitrep` or from the band. It has two tabs: one named for this session, such as "⌂ Help desk redesign", and All projects.

**permission prompt**: Claude Code asking you in the window to allow a tool. A question Claude Code puts to you there counts the same way. SitRep counts a window waiting at one, beside the asks.

**pick up**: Handing a parked item to the Claude in this window, from the pane. You can pick one up from any window running a session of its project.

**Ready to send**: The foot of the pane, where replies and pick-ups wait. Nothing goes to Claude until you press **send to Claude**.

**reply**: Your answer or comment on an ask, given from the board, or a pick-up of a parked item. A reply for this session reaches Claude as your own message, marked "From the board:". A reply for another session goes into its inbox.

**toast**: A short note Claude Code shows in the window. SitRep shows one when a new ask lands in this session: `● New ask:` and the ask title.

## In the Mac app

**asks panel**: What the arrow on a row opens, beside the panel or the tab on the strip: one session's asks, one at a time. A click answers a yes or a choice, with two seconds to undo. A words ask shows there too, with **Open in Claude ↗** to answer it in Claude.

**banner**: A macOS notification from SitRep, for a new ask or for Claude stopping. A click on one takes you to the session. Both are off until you turn them on in Settings › Notifications. **Turn On…** in the welcome window also turns on the banner for a new ask. A failure banner, such as "SitRep could not jump", "Not snoozed" or "Not answered", shows even with both switches off.

**dimmed session**: A session drawn dimmed, because it isn't open on the device you're looking from. In the panel and on the strip, that device is this Mac's screen, so a session you reach only over SSH is dimmed. In the terminal view, that device can be a phone or iPad over SSH, and a dimmed session in Needs you has a hollow dot. Its asks still count. While SitRep isn't running, the terminal view dims only a session no window runs.

**mark**: A session on the strip: a ring holding two letters of its project. The colour of the ring says where the session stands.

**the menu bar item**: The SitRep icon in the menu bar, and its menu. The menu lists your sessions under one total, such as "3 need you". The icon lights the same way the notch does. SitRep has no Dock icon, so this is where you reach it.

**Needs you**: The first section of the panel and of the terminal view: the sessions waiting on you. An orange row has asks, or a window waiting at a permission prompt. The terminal view shows the same with an orange dot. A blue row or dot is Stopped.

**the notch**: The SitRep shape at the left or right edge of your screen, black by default, on every Space. It opens into the panel when you hover over it. Its light is orange while an orange row waits in Needs you. With none, it is blue while a session is Stopped.

**the panel**: What the notch opens: your sessions, in Needs you, Working and Snoozed. A click on a session takes you to it.

**the pulse**: The notch swelling and flashing its light. By default it comes for a new ask, and when a window starts waiting at a permission prompt. For Claude stopping, you turn it on in Settings › Notifications.

**row**: A session in the panel, in the terminal view, or in the menu of the menu bar item. In the panel, a row in Needs you has a line for each ask or permission prompt waiting. In the terminal view, a row takes two lines until you expand it. The first holds the name, with a count if more than one thing waits. The second holds the project, then the newest thing it waits on or is doing. In Snoozed, the second line holds the thing that wakes soonest instead, the oldest if several wake together.

**row's arrow**: The button on a row in Needs you that opens the asks panel. It sits at the end of the row nearer the middle of the screen. At the left edge it takes the place of the time, and at the right edge the place of the dot. It shows only if the session has an ask: a yes, a choice or a words ask. It shows while the pointer is on the row, and stays lit while the asks panel for that row is open. A tab on the strip shows it at the far end.

**the strip**: The other way to show the board at the screen edge: a narrow column with a mark for each session. You choose Notch, Strip or Nothing under Show, in the menu or in Settings › Edge.

**the welcome window**: The window SitRep opens at its first start. It shows what SitRep does, and sets your first choices, such as the sound. The first time, it also turns on Open at login. It also asks macOS for banners and control of Ghostty, both optional. Show Welcome Window, in the menu, opens it again.

**Working**: The section of the panel and of the terminal view for sessions that don't need you. Claude is running a turn there, or waits on work of its own, such as a background agent.

## In a terminal

**expand**: To show a row of the terminal view whole: press `⏎`, or tap the chosen row. Its name and words wrap over as many lines as they need, and several asks take a line each. Press `⏎` again to fold it.

**terminal notification**: A notification that the terminal itself shows, such as Ghostty showing a macOS notification. The terminal view sends one for each new ask, unless you open it with `sitrep --no-notify`.

**the terminal view**: The board in a terminal, opened by typing `sitrep` with no command. It shows Needs you, Working and Snoozed, each session on two lines until you expand it. It works in any terminal, on the Mac or over SSH.

## Getting to a session

**the jump**: What a click on a session does: it brings forward the terminal that shows the window. Ghostty gets the exact Ghostty window. Any other terminal app comes forward whole.

**plain shell syntax**: What a resume command may hold: words, pipes and `&&`, redirections, quotes, variables such as `$s`, and `$(…)`. The shells sh, bash, zsh, dash and ksh all read it the same way, so SitRep knows where each value lands. SitRep refuses a command that holds anything else, and names the part it found.

**the resume command**: What SitRep types into a new Ghostty window, for a session no terminal on this Mac shows. The terminal view runs it in its own terminal, for the session you open with `o`. The default is `cd {dir} && claude --resume {claude}`. You can set your own in Settings › General.
