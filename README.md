<div align="center">

# 📋 SitRep

**A board for your Claude Code sessions**

Claude keeps a board as it works: where each session stands, what it needs from you,
<br>and what you'd want to know later. You see it in Claude Code and at the edge of your Mac's screen,
<br>answer from it, and a click takes you to the window a session is in.

[![Platform: macOS 14+ on Apple silicon](https://img.shields.io/badge/platform-macOS%2014%2B%20%C2%B7%20Apple%20silicon-lightgrey.svg)](#install)
[![Swift](https://img.shields.io/badge/Swift-6.0+-F05138.svg)](https://www.swift.org)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-D97757.svg)](#claude-and-sitrep)

[Install](#install) · [Quick start](#quick-start) · [How it works](#how-it-works) · [Claude and sitrep](#claude-and-sitrep) · [The board in Claude Code](#the-board-in-claude-code) · [SitRep, the app](#sitrep-the-app) · [Commands](#commands) · [Developing](#developing)

</div>

---

## Why SitRep?

With several Claude Code windows open across several projects, what waits on you is spread through their chats, and a question asked an hour ago in a window you've moved away from waits there unseen.

- **The chat stays primary.** Claude talks to you in the chat as it always does, and also puts a line on the board. Nothing moves out of the chat, and Claude's real record stays wherever the project keeps one.
- **What waits on you, in one place.** Every session's asks, across every project, counted above Claude Code's prompt and lit at the edge of your screen.
- **Answer without hunting.** A yes or a choice is a button. Your reply reaches Claude as your own message, in its own window.
- **A click takes you there.** A session, an ask or a notification brings forward the Ghostty window showing that session, on whatever Space it is, in tmux, in zmx or in neither.
- **Sessions outlive their windows.** After a `/clear`, or in a new Claude told to carry on, it is the same session, with its asks and notes.
- **Put an ask off.** Snooze one until later today, tomorrow or next week; it counts nowhere until it wakes.
- **Best effort, and honest.** A missed update breaks nothing, and the board never says Claude knows something it wasn't told.

## Install

You need an Apple silicon Mac on macOS 14 or later, and Claude Code.

The repository is private, so Homebrew needs a GitHub token that can read it, as `HOMEBREW_GITHUB_API_TOKEN`: a classic token with the `repo` scope, or a fine-grained one for `leeovery/sitrep` with read access to its contents.

```bash
export HOMEBREW_GITHUB_API_TOKEN=...   # in your shell's profile, to keep it
brew install --cask leeovery/tools/sitrep
```

The install leaves SitRep stopped, so open it from Applications; macOS asks once whether to open an app downloaded from the internet. At its first start SitRep copies the plugin it carries to `~/Library/Application Support/sitrep` and installs it there through `claude plugin`. It leaves alone a sitrep it didn't install, such as a clone registered as the `sitrep` marketplace, and runs that one's CLI instead. It needs the `claude` CLI where Claude Code's installers put it, or on your login shell's PATH. Should the plugin's install fail, the menu bar item's menu says why under its header, and so does the Claude Code plugin row in Settings › General.

The install asks macOS for nothing. What SitRep can use, it asks for in Settings, under General and Notifications:

- **Leave to control Ghostty**, so a click on a session brings its window forward: asked at the first jump, or with Allow… in General, and kept in System Settings › Privacy & Security › Automation.
- **Notifications**, off until you turn on Notify me of a new ask, and kept in SitRep's row in System Settings › Notifications.
- **Open at login**, a switch in General, which macOS may hold for your approval in System Settings › General › Login Items.

## Quick start

1. Open SitRep, then run `/reload-plugins` in each Claude Code window already open.
2. Work as you do. When the work will run across several turns or will need you, Claude starts a session and keeps its board.
3. Watch the line above the prompt, `◆ 1 ask  2 elsewhere  ▸ show board`: each count opens the board.
4. Run `/sitrep`, or press `show board`, to open the board in Claude Code. Answer an ask, then press **send to Claude**.
5. Move the pointer onto SitRep's notch, at the left edge of the main display a little above the middle, to see every session, and click one to jump to its window.

## How it works

```
Claude Code window ──tools──▶ the mod ──writes──▶ ~/.local/state/sitrep
  (every one)                  │                         │
                               ├─ the pane and the band  ├─ sitrep watch ─────▶ SitRep
                               └─ delivers your replies  └─ sitrep snooze, wake ◀─ a row's Snooze
```

- **The mod runs in every Claude Code window.** It registers Claude's tools, draws the board in the window, and writes what Claude posts into the board's folder.
- **The folder is the state.** `~/.local/state/sitrep` (or `$XDG_STATE_HOME/sitrep`) holds every project and session, a file for each writer. No database, no server, no background service.
- **The core holds the rules**, shared by the mod and the CLI: what a reply does to an ask, what counts as waiting, what folds away.
- **SitRep leaves the board's rules to the core**, and changes the board only through the CLI. It runs one `sitrep watch`, which prints the board as it changes, and calls the CLI for each snooze and wake. A click's jump to a session's window is SitRep's own.
- **Your replies arrive as your own message.** A reply for this session is sent as you, marked "From the board:"; while Claude is mid-turn it waits for the turn to end, and you can take it back until then.
- **A reply for another session goes into its inbox.** That session's window sends it on, now or once a window takes the session up.

The board has its own words: a **project**, roughly a repository, named as you'd say it; its **sessions**; and in each a **status**, **asks** (what only you can do or decide), **notes** (what you'd want to know later), **parked** items (put off, to come back to), **resolved** items and **snoozed** asks. A session Claude or you **finished** leaves the board.

## Claude and sitrep

The mod gives Claude these tools. Only the main conversation can call them; a subagent puts what it would post in its report.

| Tool | What it does |
|---|---|
| `start` / `join` | Starts a session in a project, or joins one by its id |
| `status` | Sets the session's name, summary, what is under way, and what is next |
| `ask` | Posts an ask that wants a yes, a choice or words, with where to look |
| `note` | Adds a note, with detail lines and a pointer |
| `park` | Parks something to come back to |
| `resolve` / `reopen` / `edit` | Closes, reopens or corrects an item, with a reason |
| `finish` | Finishes the session once it is complete, with nothing left on it |
| `project` | Renames the session's project, or says where it lives |
| `board` | Reads the board back, so Claude can check and repair it |

- **Each conversation's first message tells Claude how to keep the board**, and lists every current session on it with its id, so Claude can join one you carry on with, or start a new one.
- **Claude asks only when it needs you**, says it in the chat as well, and picks the shape by what you give back. A yes's button is the verb you're giving: `✓ Go`, `✓ Approve`, `✓ It works`.
- **Drift gets noticed.** When the board changes, its open items ride into Claude's next turn, and a join hands Claude the board as it stands (its status, open asks, parked items and latest notes) to correct anything stale.
- **Claude has no tool for snoozing.** Snoozing an ask is yours.

## The board in Claude Code

- **The pane**, opened by `/sitrep` or the band, has two tabs: this session, and All projects. A session shows its asks first, then its status, notes, parked items and resolved asks. All projects opens each project, and each project its sessions.
- **The band** is the line above the prompt: this session's asks, what waits elsewhere, and the pane's show or hide. A new ask pulses it and shows a toast.
- **Ready to send.** Your replies queue at the pane's foot, grouped by the session each goes to, until you press **send to Claude** or **cancel all**. A words ask's answer, or a comment, is written in Claude Code's prompt. A snooze, a wake or a finish takes effect at once.

## SitRep, the app

A menu bar app with no Dock icon, on every Space. The notch and the strip step off the screen while a full-screen app has their display, and come back as it leaves.

- **The notch** sits at the screen's left or right edge, a little above the middle, and opens on hover into a panel of your sessions: Needs you, Working, Your turn and Snoozed. It swells and lights when something needs you, and never takes the keyboard. Drag it along the edge, or across the middle to the other side.
- **The strip** can stand in its place: a narrow column along the edge, a mark for each session, that grows with what's on it or runs the screen's height.
- **The menu bar item** lists the panel's sessions, each a click to its window but an away session's. Then come Show (Notch, Strip or Nothing), Show Welcome Window, Settings… and Quit SitRep. Above the list it speaks up, in this order, when the plugin is in trouble, when a window needs `/reload-plugins`, and when SitRep can't read the board.
- **Settings**, a window of its own (⌘,):
  - What stays on screen: Show (Notch, Strip or Nothing); its edge and display; for the notch, Style (Meniscus or Card); for the strip, Length (Grows or Full), and a Max slider at Grows; Black or Glass (from macOS 26); and Reduce motion.
  - Notifications: a test notification, Notify me of a new ask, and Play a sound for a new ask, on by default, its sound one of macOS's alert sounds, Glass unless you pick another.
  - General: Open at login and the leave to control Ghostty.
  - Claude Code: the plugin's state.
- **A new ask** plays the sound once, whichever session it lands in, and, with notifications on, posts a silent macOS notification whose click jumps to the session.
- **The jump** brings forward the Ghostty window showing a session: in tmux, selecting the session's tmux window where no client shows it; in zmx, the window attached to the session. A terminal with no driver is brought forward whole.

## Commands

The CLI is `bin/sitrep` in the plugin's folder; the app's copy is `~/Library/Application Support/sitrep/bin/sitrep`. A command on a session names it with `--session sr-xxxxxx`, else `$SITREP_SESSION`, and `sitrep <command> --help` says more.

| Command | What it does |
|---|---|
| `sitrep list` | Every project's current sessions, with their ids and what waits on you |
| `sitrep board` | A session's status, open asks, parked items and latest notes, with their ids |
| `sitrep status` | Sets where a session stands, giving only what changed |
| `sitrep ask` | Posts an ask, and prints its id |
| `sitrep note` | Adds a note, and prints its id |
| `sitrep park` | Parks something to come back to, and prints its id |
| `sitrep answer` | Answers a yes or a choice ask, or ignores any ask, into the session's inbox |
| `sitrep snooze` | Snoozes asks until a time |
| `sitrep wake` | Wakes snoozed asks now |
| `sitrep finish` | Finishes a session no window holds |
| `sitrep watch` | Prints the board as a line of JSON at the start and at each change, for SitRep |

`list` and `board` take `--json`. Exit codes: 0 done; 1 a usage error, a refused input or a failure; 2 no such session.

## Updating

```bash
brew upgrade --cask sitrep
```

The upgrade quits SitRep, swaps it, and starts the new one if SitRep was running. As it starts, the new app refreshes its copy of the plugin, so the two never part; each Claude window runs the new plugin from its next `/reload-plugins`.

## Uninstalling

```bash
brew uninstall --cask sitrep
```

That removes the app and nothing else: the plugin it installed stays installed in Claude Code, from `~/Library/Application Support/sitrep`, and keeps working in every window. `brew uninstall --zap --cask sitrep` also removes that folder and SitRep's preferences, so tell Claude Code the plugin is gone too:

```bash
claude plugin uninstall sitrep@sitrep
claude plugin marketplace remove sitrep
```

Neither touches the board itself, `~/.local/state/sitrep`.

## Developing

A development Mac runs SitRep from the cask and the plugin from SitRep's own copy, as any Mac does, so a merge to `main` reaches no Claude window until a release. Keep the clone on `main`, and work in a worktree. [DESIGN.md](DESIGN.md) is the design, and the record of what was decided and proven live.

```bash
app/plugin here   # this checkout as the sitrep plugin, for a live test
app/plugin app    # SitRep's own copy again
app/plugin        # which one Claude Code has now
```

A switch reaches each Claude window at its next `/reload-plugins`. SitRep looks at the plugin only as it starts, so either form ends with SitRep running: started where it isn't, and started again where the switch changed anything. On its copy, that start refreshes the copy, and makes it again if it's gone. A switch to where the plugin already comes from leaves Claude Code as it is and only starts a SitRep that isn't running, so running it again retries a start that failed. None puts a second sitrep beside one from another marketplace. Run `app/plugin app` before removing a worktree that is the live plugin: with its folder gone, windows load no sitrep at their next `/reload-plugins`, and SitRep never re-points the marketplace itself.

It needs:

- **Bun**: the `bin/sitrep` of a checkout under `app/plugin here` runs on it, the gates run `bunx`, and `app/bundle` compiles the app's CLI with `bun build --compile`;
- **Xcode**, for Swift 6 and the `actool` that compiles the icon;
- **jq**, which `app/plugin` reads Claude Code's lists with;
- **the Developer ID certificate**, `Developer ID Application: PointsBox Limited (CQKZZ4FN6V)`, in the login keychain: `app/bundle` signs with it, and stops without it.

The repository holds the mod (`hooks/`), the core (`core/`), the CLI (`cli/`) and the app (`app/`, a Swift package with no Xcode project), under one version. The engine's types live in `.claude-plugin/types/`, which git leaves out; `.worktreeinclude` copies them into a worktree.

Every change passes the gates:

```bash
claude plugin test .              # every test, the mod's and the CLI's
bunx tsc -p .                     # the mod, the core and the CLI
bunx tsc -p cli/shell             # the CLI's binding to Bun, on its own
swift build --package-path app    # the app
swift test --package-path app     # the app's tests
```

`app/build` builds the app, signs it with the Developer ID, installs it to `/Applications/SitRep.app` over the cask's copy and starts it, replacing the one running, so the login item and macOS's permissions carry over. It doesn't notarize: a build installed from a checkout is never quarantined. It changes the plugin too: while SitRep's copy is the plugin, the build's start refreshes the copy from what the build carries, so every Claude window runs the building checkout's mod from its next `/reload-plugins`. `brew reinstall --cask sitrep` puts the release back, leaving SitRep stopped, so open it, or run `app/open`, after; the next release's `brew upgrade` replaces the build.

## Releasing

A release is cut and built on a Mac, by mint:

```bash
./release              # a patch release; -m minor, -M major
./release --dry-run    # the plan, with nothing changed and no hooks run
```

mint sets the version in `.claude-plugin/plugin.json`, which the app takes too. The app is built, signed and notarized before mint's tag, so a failure in any of that stops the release with nothing public yet. Its `pre_tag` hook runs every gate above, since no CI does, then `app/release-build`, which:

1. stops when the working tree differs from HEAD in anything but mint's bookkeeping (the version in `plugin.json`, `CHANGELOG.md`, `.mint.toml`), untracked files included, since mint commits whatever `pre_tag` leaves into the tag; so a `--notes-file` lives outside the repository;
2. builds the app from HEAD, in a worktree of its own, by HEAD's own `app/bundle`, stamped with the version mint is about to tag;
3. notarizes and staples it (`app/notarize`), and checks that Gatekeeper accepts the zip as a download;
4. checks the working tree again, and that HEAD is still the commit built, then keeps the zip, its sha256 and the commit built in `~/Library/Caches/SitRep/release/<version>/`, where other versions' builds are kept a month.

Then mint writes the notes, commits the version and the changelog, tags `v<version>`, pushes, and makes the GitHub release. Its `post_release` hook runs `app/release-upload`, which builds nothing:

1. checks the kept zip is whole and was built from what the tag holds, but for mint's bookkeeping;
2. uploads it as `SitRep-<version>.zip` to the release, replacing one there;
3. when the release is the latest, sends the cask in `leeovery/homebrew-tools` the version, the zip's sha256 and the asset's id, and waits for the tap's workflow to commit them. A rerun for an older release leaves the cask alone, since the cask on an older version would downgrade every Mac.

Both log everything to `~/Library/Logs/SitRep/release-<version>.log`. mint only warns when `post_release` fails, so run it again by hand, `app/release-upload` or `app/release-upload <version>`: it uploads what's kept and sends the cask again. When nothing fitting is kept, it says to build the tag again first, `app/release-build <version> v<version>`, which notarizes again. When the upload went and a step before the tap's run failed (finding the latest release, listing the tap's runs, sending the cask) or the tap started no run within a minute, it prints the command that sends the cask again. When the tap's run started, it prints the run's URL, and if that run fails, the URL and the command.

Leave the clone alone while mint runs. `pre_tag`'s checks end with it, and mint then writes the notes and waits at the review gate before it tags: a commit or a pull made then, or an edit to `plugin.json` beyond its version, is tagged unbuilt, and `app/release-upload` refuses the zip. `app/release-build <version> v<version>`, then `app/release-upload <version>`, finish that release. Closing the gap needs a mint hook nearer the tag.

A rerun replaces the zip, and GitHub deletes the asset it replaces. Until the tap's workflow commits the new asset's id, about a minute later, the cask names a deleted asset, so installs fail; if the sending or the update fails in between, the cask stays broken until a rerun or the printed command sends it again.

Once per Mac that releases, beside the Developer ID certificate:

- notarytool's login saved in the keychain as the Mac's one profile `notarytool`, shared by every app built here: `xcrun notarytool store-credentials notarytool`;
- `gh` logged in as an account that can upload to this repository's releases and dispatch to `leeovery/homebrew-tools`;
- mint: `brew install leeovery/tools/mint`.
