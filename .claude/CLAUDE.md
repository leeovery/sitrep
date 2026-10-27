# CLAUDE.md

sitrep is Lee's board inside Claude Code: a mod (`hooks/`), a pure core
(`core/`), a CLI (`cli/`), and SitRep, the Mac menu bar app (`app/`).
`DESIGN.md` is the design and the record of what was decided and proven
live; read the sections a change touches first.

## This clone is the live plugin

On Lee's Mac, Claude Code reads the `sitrep` marketplace straight from this
folder, so whatever the checkout holds is what every Claude window runs at
its next `/reload-plugins`. Keep the checkout on `main`, and work in a
worktree.

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
`~/Applications/SitRep.app` and starts it, replacing the one running.
`app/release`, run by mint's `post_release` (`./release`), builds a release
from its tag, notarizes it (`app/notarize`) and uploads it to the GitHub
release, logging to `~/Library/Logs/SitRep/release-<version>.log`.

## Live tests

A live run of the CLI points `XDG_STATE_HOME` at a folder of its own and
seeds its own sessions there, so it never writes to the real board in
`~/.local/state/sitrep`. A jump moves Lee's screen: run one only with Lee's
go.
