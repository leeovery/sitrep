# sitrep

sitrep is a board inside Claude Code: where each session stands and what
waits on you. Claude keeps it as it works, setting a session's status,
posting asks, noting what you'd want to know later, and you answer from the
board.

It comes as one:

- **the mod** (`hooks/`), which runs in every Claude Code window and writes
  the board;
- **the core** (`core/`), the board's rules, shared by the mod and the CLI;
- **the CLI** (`cli/`, run as `bin/sitrep`), which reads the board, answers
  asks and jumps to a session's window;
- **SitRep**, the Mac menu bar app (`app/`), which shows the board and
  carries the plugin and its CLI.

The board lives in `~/.local/state/sitrep`. [DESIGN.md](DESIGN.md) is the
design, and the record of what was decided and proven live.

## Installing on a Mac

SitRep needs an Apple silicon Mac on macOS 14 or later. The repository is
private, so Homebrew needs a GitHub token that can read it, as
`HOMEBREW_GITHUB_API_TOKEN`: a classic token with the `repo` scope, or a
fine-grained one for `leeovery/sitrep` with read access to its contents.

```bash
export HOMEBREW_GITHUB_API_TOKEN=...   # in your shell's profile, to keep it
brew install --cask leeovery/tools/sitrep
```

Then open SitRep from Applications. macOS asks once whether to open an app
downloaded from the internet. At its first start SitRep installs the Claude
Code plugin from the copy it carries, into
`~/Library/Application Support/sitrep`, through `claude plugin`; each
Claude window takes it up at its next `/reload-plugins`. It leaves alone a
sitrep it didn't install, such as a clone registered as the `sitrep`
marketplace, and runs that one's CLI instead.

The install asks macOS for nothing. What SitRep can use, it asks for in its
Settings, under General and Notifications:

- **Leave to control Ghostty**, so a click on a session brings its window
  to the front: asked at the first jump, or with Allow… in General, and
  kept in System Settings › Privacy & Security › Automation.
- **Notifications**, off until you turn them on: Notify me of a new ask, and
  SitRep's row in System Settings › Notifications.
- **Open at login**, a switch in General, which macOS may hold for your
  approval in System Settings › General › Login Items.

## Updating

```bash
brew upgrade --cask sitrep
```

The new app refreshes its copy of the plugin as it starts, so the two never
part; each Claude window runs the new plugin from its next
`/reload-plugins`.

## Developing

Until the first release, this Mac reads the plugin straight from this clone,
`~/Code/sitrep`, as the `sitrep` marketplace: whatever the checkout holds is
what every Claude window runs at its next `/reload-plugins`. So keep the
clone on `main`, and work in a worktree. The engine's types live in
`.claude-plugin/types/`, which git leaves out; `.worktreeinclude` copies
them into a worktree.

The gates:

```bash
claude plugin test .              # every test, the mod's and the CLI's
bunx tsc -p .                     # the mod, the core and the CLI
bunx tsc -p cli/shell             # the CLI's binding to Bun, on its own
swift build --package-path app    # the app
swift test --package-path app     # the app's tests
```

`app/build` builds the app, signs it with the Developer ID, installs it to
`~/Applications/SitRep.app` and starts it, replacing the one running. It
doesn't notarize: a build installed from the clone is never quarantined.

## Releasing

A release is cut and built on this Mac, by mint:

```bash
./release                        # a patch release; -m minor, -M major
./release --set-version 0.3.0    # the first release, which sets its version
./release --dry-run              # the plan, with nothing changed and no hooks run
```

mint sets the version in `.claude-plugin/plugin.json`, which the app takes
too, so one version covers the plugin and the app. Its `pre_tag` hook runs
every gate above first, since no CI does; then it writes the notes, tags
`v<version>`, pushes, and makes the GitHub release. Its `post_release` hook runs `app/release`,
which:

1. builds the app from the tag's tree, by the tag's own `app/bundle`;
2. notarizes and staples it (`app/notarize`), and checks that Gatekeeper
   accepts the zip as a download;
3. uploads `SitRep-<version>.zip` to the release, replacing one there;
4. sends the cask in `leeovery/homebrew-tools` the version, the zip's
   sha256 and the asset's id, whose workflow commits them.

`app/release` logs everything to
`~/Library/Logs/SitRep/release-<version>.log`. mint only warns when it
fails, so run it again by hand, `app/release` or `app/release 0.3.0`; a
run builds, notarizes, uploads and sends the cask again. When only the
sending failed, it says the command that sends it again.

Once per Mac that releases:

- the Developer ID certificate, `Developer ID Application: PointsBox
  Limited (CQKZZ4FN6V)`, in the login keychain;
- notarytool's login saved in the keychain as the profile `sitrep`:
  `xcrun notarytool store-credentials sitrep`;
- `gh` logged in as an account that can upload to this repository's
  releases and dispatch to `leeovery/homebrew-tools`;
- mint: `brew install leeovery/tools/mint`.
