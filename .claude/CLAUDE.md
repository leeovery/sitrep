# CLAUDE.md

sitrep is Lee's board inside Claude Code: a mod (`hooks/`), a pure core
(`core/`), a CLI (`cli/`), and SitRep, the Mac menu bar app (`app/`).
`DESIGN.md` is the design and the record of what was decided and proven
live; read the sections a change touches first.

## The live plugin

Lee's Mac runs SitRep from the Homebrew cask, at `/Applications/SitRep.app`,
and the plugin from SitRep's own copy, `~/Library/Application Support/sitrep`.
So a merge to `main` reaches no Claude window until a release. Keep the
clone on `main`, and work in a worktree.

- `app/plugin here` makes the checkout it is in the live plugin, for a live
  test: every Claude window runs it from its next `/reload-plugins`, and
  SitRep, started again, runs its CLI. `app/plugin app` puts SitRep's copy
  back, and `app/plugin` says which it is. Run `app/plugin app` before
  removing a worktree that is the live plugin: with its folder gone, windows
  load no sitrep at their next `/reload-plugins`, and SitRep never re-points
  the marketplace itself.
- `app/build` installs a build over the cask's copy, and changes the plugin
  too: while SitRep's copy is the plugin, the build's start refreshes the
  copy from what the build carries, so every window runs the building
  checkout's mod from its next `/reload-plugins`. `brew reinstall --cask
  sitrep` puts the release back, and the next release's `brew upgrade`
  replaces the build.

## Gates

```bash
claude plugin test .              # every test, the mod's and the CLI's
bunx tsc -p .                     # the mod, the core and the CLI
bunx tsc -p cli/shell             # the CLI's binding to Bun, on its own
swift build --package-path app    # the app
swift test --package-path app     # the app's tests
```

The type-checks need the engine's types in `.claude-plugin/types/`, which
git leaves out; `.worktreeinclude` copies them into a worktree.

## The app

`app/` is a Swift package, no Xcode project: the menu bar app, which runs
the plugin's CLI for the board and the jump. `app/bundle <folder>` makes the
bundle, the plugin inside it, into a folder, signed with Lee's Developer ID
from the keychain; `app/build` runs it, installs the bundle to
`/Applications/SitRep.app` over the cask's copy and starts it, replacing the
one running; `app/quit` and `app/open` stop and start SitRep for it and for
`app/plugin`.
`app/release`, run by mint's `post_release` (`./release`), builds a release
from its tag, notarizes it (`app/notarize`), uploads it to the GitHub
release and, for the latest release, sends the cask in
`leeovery/homebrew-tools` the new zip and waits on the tap's update,
logging to `~/Library/Logs/SitRep/release-<version>.log`.

## Live tests

A live run of the CLI points `XDG_STATE_HOME` at a folder of its own and
seeds its own sessions there, so it never writes to the real board in
`~/.local/state/sitrep`. A jump moves Lee's screen: run one only with Lee's
go.
