# Contributing to SitRep

SitRep is four parts under one version: the mod (`hooks/`), which runs in every Claude Code window; a pure core (`core/`); a Bun CLI (`cli/`); and the Mac app (`app/`, a Swift package with no Xcode project). [DESIGN.md](DESIGN.md) is the design, and the record of what was decided and proven live: read the sections a change touches first.

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
- **Your replies arrive as your own message.** A reply for this session is sent as you, marked "From the board:", and says under each ask whether it closes it or leaves it open for Claude to act on; while Claude is mid-turn it waits for the turn to end, and you can take it back until then.
- **A reply for another session goes into its inbox.** That session's window sends it on, now or once a window takes the session up.

The board has its own words: a **project**, roughly a repository, named as you'd say it; its **sessions**; and in each a **status**, **asks** (what only you can do or decide), **parked** items (put off, to come back to, and the project's, not only the session's) and **resolved** items. Claude stopped, waiting on you with no ask, is your **turn**, which SitRep calls **Stopped**. A session you **snooze** counts nowhere until it wakes. A session Claude or you **finished** leaves the board, and what it parked stays with its project.

## Claude and sitrep

The mod gives Claude these tools. Only the main conversation can call them; a subagent puts what it would post in its report.

| Tool | What it does |
|---|---|
| `start` / `join` | Starts a session in a project, or joins one by its id |
| `status` | Sets the session's name, summary, what is under way, and what is next |
| `ask` | Posts an ask that wants a yes, a choice or words, with where to look, and for a choice the option Claude recommends |
| `park` | Parks something to come back to, on the session's project |
| `resolve` / `reopen` / `edit` | Closes, reopens or corrects an item, with a reason: one of the session's, or something another session of the project parked |
| `finish` | Finishes the session once it is complete, with nothing left on it; what it parked holds no finish back |
| `project` | Renames the session's project, or says where it lives |
| `move` | Moves the session, whole, to another project when you ask: its asks, parked items, status and history go with it, and a name no project has makes a new one |
| `board` | Reads the board back, with the project's parked items, so Claude can check and repair it |

- **Each conversation's first message tells Claude how to keep the board**, and lists every current session on it with its id, so Claude can join one you carry on with, or start a new one.
- **Claude asks only when it needs you**, says it in the chat as well, and picks the shape by what you give back. A yes's button is the verb you're giving: `✓ Go`, `✓ Approve`, `✓ It works`. A choice ends the button of the option Claude leans toward with `· recommended`, and a "(recommended)" Claude types into an option's words is read as that and taken out.
- **No refusals for what does no harm.** Resolving an ask you already closed, or a parked item you picked up, passes quietly, and an edit takes an item's line as `text` or `title` alike.
- **Drift gets noticed.** When the board changes, its open items ride into Claude's next turn, and a join hands Claude the board as it stands (its status, open asks and parked items) to correct anything stale.
- **Claude has no tool for snoozing.** Snoozing a session is yours.

## The CLI

The CLI is `bin/sitrep` in the plugin's folder; the app's copy is `~/Library/Application Support/sitrep/bin/sitrep`. A command on a session names it with `--session sr-xxxxxx`, else `$SITREP_SESSION`, and `sitrep <command> --help` says more.

| Command | What it does |
|---|---|
| `sitrep list` | Every project's current sessions, with their ids and what waits on you; with `--project <name>`, only that project's |
| `sitrep board` | A session's status, open asks and its project's parked items, with their ids; with `--json`, the session alone: its open asks, the items it parked itself, its latest status changes and its resolved asks |
| `sitrep status` | Sets where a session stands, giving only what changed |
| `sitrep ask` | Posts an ask, and prints its id |
| `sitrep park` | Parks something to come back to, on the session's project, and prints its id |
| `sitrep answer` | Answers a yes or a choice ask, or ignores any ask, into the session's inbox |
| `sitrep snooze` | Snoozes a session, its asks and its turn, until a time, or with no `--until` until it moves |
| `sitrep wake` | Wakes a snoozed session now |
| `sitrep finish` | Finishes a session no window holds |
| `sitrep move <project>` | Moves a session into a project already on the board; it makes no project |
| `sitrep watch` | Prints the board as a line of JSON at the start and at each change, for SitRep |

`ask` takes `--wants yes|choice|words`, then `--yes <label>` for a yes, `--option <choice>` for each of a choice's options with `--recommended <choice>` for the one you lean toward, or `--needs <words>` for words. `snooze` names each ask the session's row shows, and `--until` in milliseconds since the epoch. `list` and `board` take `--json`. Exit codes: 0 done; 1 a usage error, a refused input or a failure; 2 no such session.

## Developing

A development Mac runs SitRep from the cask and the plugin from SitRep's own copy, as any Mac does, so a merge to `main` reaches no Claude window until a release. Keep the clone on `main`, and work in a worktree.

```bash
app/plugin here   # this checkout as the sitrep plugin, for a live test
app/plugin app    # SitRep's own copy again
app/plugin        # which one Claude Code has now
```

A switch reaches each Claude window at its next `/reload-plugins`. SitRep looks at the plugin only as it starts, so either form ends with SitRep running: started where it isn't, and started again where the switch changed anything. On its copy, that start refreshes the copy, and makes it again if it's gone. A switch to where the plugin already comes from leaves Claude Code as it is and only starts a SitRep that isn't running, so running it again retries a start that failed. If Claude Code already has a sitrep plugin from another marketplace, neither form installs a second one beside it: it says so, and changes nothing. Run `app/plugin app` before removing a worktree that is the live plugin: with its folder gone, windows load no sitrep at their next `/reload-plugins`, and SitRep never re-points the marketplace itself.

It needs:

- **Bun**: the `bin/sitrep` of a checkout under `app/plugin here` runs on it, the gates run `bunx`, and `app/bundle` compiles the app's CLI with `bun build --compile`;
- **Xcode**, for Swift 6 and the `actool` that compiles the icon;
- **jq**, which `app/plugin` reads Claude Code's lists with;
- **the Developer ID certificate**, `Developer ID Application: PointsBox Limited (CQKZZ4FN6V)`, in the login keychain: `app/bundle` signs with it, and stops without it.

Without that certificate, `app/bundle` and `app/build` can't run: a contributor without it runs the gates below, and Lee builds and installs the app.

The engine's types live in `.claude-plugin/types/`, which git leaves out; `.worktreeinclude` copies them into a worktree.

Every change passes the gates:

```bash
claude plugin test .              # every test, the mod's and the CLI's
bunx tsc -p .                     # the mod, the core and the CLI
bunx tsc -p cli/shell             # the CLI's binding to Bun, on its own
swift build --package-path app    # the app
swift test --package-path app     # the app's tests
```

`app/build` builds the app, signs it with the Developer ID, installs it to `/Applications/SitRep.app` over the cask's copy and starts it, replacing the one running, so the login item and macOS's permissions carry over. It doesn't notarize: a build installed from a checkout is never quarantined. It changes the plugin too: while SitRep's copy is the plugin, the build's start refreshes the copy from what the build carries, so every Claude window runs the building checkout's mod from its next `/reload-plugins`. `brew reinstall --cask sitrep` puts the release back, leaving SitRep stopped, so open it, or run `app/open`, after; the next release's `brew upgrade` replaces the build.

`app/screens` draws the README's pictures again into `art/screens`, with nothing shown on the screen, each over a made-up board, at 2x on one made-up desktop: Claude Code in a Ghostty window with the board docked at its side, as a PNG, the board and the band from the mod's own drawing and Claude Code's screen round them a mock; and the notch opening at the screen's edge as the pointer comes to it, filmed from the app's own drawing and put together as an animated WebP. It needs `img2webp` (`brew install webp`), and draws the window in JetBrainsMono Nerd Font Mono, which must be installed. Run it whenever the look changes, and commit what it draws.

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
3. when the release is the latest, sends the cask in `leeovery/homebrew-tools` the version and the zip's sha256, and waits for the tap's workflow to commit them. A rerun for an older release leaves the cask alone, since the cask on an older version would downgrade every Mac.

Both log everything to `~/Library/Logs/SitRep/release-<version>.log`. mint only warns when `post_release` fails, so run it again by hand, `app/release-upload` or `app/release-upload <version>`: it uploads what's kept and sends the cask again. When nothing fitting is kept, it says to build the tag again first, `app/release-build <version> v<version>`, which notarizes again. When the upload went and a step before the tap's run failed (finding the latest release, listing the tap's runs, sending the cask) or the tap started no run within a minute, it prints the command that sends the cask again. When the tap's run started, it prints the run's URL, and if that run fails, the URL and the command.

Leave the clone alone while mint runs. `pre_tag`'s checks end with it, and mint then writes the notes and waits at the review gate before it tags: a commit or a pull made then, or an edit to `plugin.json` beyond its version, is tagged unbuilt, and `app/release-upload` refuses the zip. `app/release-build <version> v<version>`, then `app/release-upload <version>`, finish that release. Closing the gap needs a mint hook nearer the tag.

The cask downloads the zip from the release's public URL, `https://github.com/leeovery/sitrep/releases/download/v<version>/SitRep-<version>.zip`, with no token. A rerun of `app/release-upload` uploads the same kept zip, with the same sha256, but `gh release upload --clobber` deletes the old asset first: if that upload fails, installs of the current version get a 404 until a rerun succeeds. Only after `app/release-build` has built the zip again does its sha256 change: until the tap's workflow commits the new one, about a minute later, installs fail the cask's checksum, and if the sending or the update fails in between, they keep failing until a rerun or the printed command sends it again.

Once per Mac that releases, beside the Developer ID certificate:

- notarytool's login saved in the keychain as the Mac's one profile `notarytool`, shared by every app built here: `xcrun notarytool store-credentials notarytool`;
- `gh` logged in as an account that can upload to this repository's releases and dispatch to `leeovery/homebrew-tools`;
- mint: `brew install leeovery/tools/mint`.
