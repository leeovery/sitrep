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

The board has its own words, each defined once in the [glossary](docs/glossary.md).

Claude's tools are in [How Claude keeps the board](docs/claude-and-sitrep.md), and every CLI command is in [The `sitrep` command](docs/cli.md).

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
- **press**, the owner's release tool (one script in kit-config, `~/bin/press`, its Mac's signing, notary, tap and folders in `~/.config/press/config.toml`), which signs every build of the app as `.press.toml` lists its parts;
- **the Developer ID certificate**, `Developer ID Application: PointsBox Limited (CQKZZ4FN6V)`, in the signing keychain, `~/Library/Keychains/signing.keychain-db`, which kit's developer-id step makes: press signs with it, and stops without it. The keychain opens with `DEVELOPER_ID_P12_PASSWORD`, which kit writes to `~/.secrets.zsh`; press unlocks it itself, reading the password from `~/.secrets.zsh` where the shell lacks it or holds an old one, so nothing asks, at the Mac or over SSH.

`app/bundle <folder> <version>` lays the app out, unsigned, and needs neither. Without them `app/build` can't run: a contributor without them runs the gates below, and Lee builds and installs the app.

The engine's types live in `.claude-plugin/types/`, which git leaves out; `.worktreeinclude` copies them into a worktree.

Every change passes the gates:

```bash
claude plugin test .              # every test, the mod's and the CLI's
bunx tsc -p .                     # the mod, the core and the CLI
bunx tsc -p cli/shell             # the CLI's binding to Bun, on its own
swift build --package-path app    # the app
swift test --package-path app     # the app's tests
```

`app/build` lays the app out (`app/bundle`), signs it with the Developer ID (`press sign --dev`, with no timestamp, so it builds offline), installs it to `/Applications/SitRep.app` over the cask's copy and starts it, replacing the one running, so the login item and macOS's permissions carry over. It doesn't notarize: a build installed from a checkout is never quarantined. It changes the plugin too: while SitRep's copy is the plugin, the build's start refreshes the copy from what the build carries, so every Claude window runs the building checkout's mod from its next `/reload-plugins`. `brew reinstall --cask sitrep` puts the release back, leaving SitRep stopped, so open it, or run `app/open`, after; the next release's `brew upgrade` replaces the build.

`app/screens` draws the README's pictures again into `art/screens`, with nothing shown on the screen, each over a made-up board, at 2x on one made-up desktop: Claude Code in a Ghostty window with the board docked at its side, as a WebP, the board and the band from the mod's own drawing and Claude Code's screen round them a mock; and the notch opening at the screen's edge as the pointer comes to it, filmed from the app's own drawing and put together as an animated WebP. It needs `cwebp` and `img2webp` (`brew install webp`), and draws the window in JetBrainsMono Nerd Font Mono, which must be installed. Run it whenever the look changes, and commit what it draws.

## Releasing

A release is cut and built on a Mac, by mint:

```bash
./release              # a patch release; -m minor, -M major
./release --dry-run    # the plan, with nothing changed and no hooks run
```

mint sets the version in `.claude-plugin/plugin.json`, which the app takes too. The app is built, signed and notarized before mint's tag, so a failure in any of that stops the release with nothing public yet. Its `preflight` hook, `press check`, checks in seconds that the Mac can sign and notarize: the signing keychain opens, and notarytool's profile signs in. Its `pre_tag` hook runs every gate above, since no CI does, then `press prepare`, which, as `.press.toml` says:

1. stops when the checkout has uncommitted changes, or the tag is taken;
2. builds the app from HEAD, in a worktree of its own, by HEAD's own `app/bundle`, stamped with the version mint is about to tag (its `Info.plist` without a pre-release's suffix, the plugin with the version whole);
3. signs it inside out (the CLI, the notices helper, then the app), notarizes and staples it, and checks that Gatekeeper accepts a quarantined copy as notarized, unpacked from the zip as a download;
4. checks HEAD is still the commit built, then keeps the zip, its sha256 and the commit built in `~/Library/Caches/press/sitrep/<version>/`, where other versions' builds are kept a month.

Then mint writes the notes, commits the version and the changelog, tags `v<version>`, pushes, and makes the GitHub release. Its `post_release` hook runs `press upload`, which:

1. checks the kept zip is whole and was built from what the tag holds, but for mint's bookkeeping (the version in `plugin.json`, `CHANGELOG.md`, `.mint.toml`), and builds the tag again, which notarizes again, where it wasn't;
2. uploads it as `SitRep-<version>.zip` to the release, replacing one there, and checks GitHub lists it at its size;
3. when the release is the latest, sends the cask in `leeovery/homebrew-tools` the version and the zip's sha256, and waits for the tap's workflow to commit them. A rerun for an older release leaves the cask alone, since the cask on an older version would downgrade every Mac.

Both log everything to `~/Library/Logs/press/sitrep-<version>.log`. mint only warns when `post_release` fails, so run it again by hand, `press upload <version>` (`--dry-run` says what it would upload and send): it uploads what's kept, or the tag built again, and sends the cask again. When the upload went and a step before the tap's run failed (finding the latest release, listing the tap's runs, sending the cask) or the tap started no run within a minute, it prints the command that sends the cask again. When the tap's run started, it prints the run's URL, and if that run fails, the URL and the command. `press prepare 0.0.0-check` checks signing and notarizing without releasing anything.

Leave the clone alone while mint runs. `pre_tag`'s checks end with it, and mint then writes the notes and waits at the review gate before it tags: a commit or a pull made then, or an edit to `plugin.json` beyond its version, is tagged unbuilt, and `press upload` builds the tag again before it uploads. Closing the gap needs a mint hook nearer the tag.

The cask downloads the zip from the release's public URL, `https://github.com/leeovery/sitrep/releases/download/v<version>/SitRep-<version>.zip`, with no token. A rerun of `press upload` uploads the same kept zip, with the same sha256, but `gh release upload --clobber` deletes the old asset first: if that upload fails, installs of the current version get a 404 until a rerun succeeds. Only after the tag is built again does the zip's sha256 change: until the tap's workflow commits the new one, about a minute later, installs fail the cask's checksum, and if the sending or the update fails in between, they keep failing until a rerun or the printed command sends it again.

Once per Mac that releases, beside the Developer ID certificate:

- notarytool's login saved in the signing keychain as the Mac's one profile `notarytool`, shared by every app built here, which kit's notarytool step makes;
- `gh` logged in as an account that can upload to this repository's releases and dispatch to `leeovery/homebrew-tools`;
- mint: `brew install leeovery/tools/mint`.
