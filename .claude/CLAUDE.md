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
  SitRep, started, runs its CLI. `app/plugin app` puts SitRep's copy back,
  and `app/plugin` says which it is. Either form ends with SitRep running,
  started again where the switch changed anything, so a run whose start
  failed is retried by running it again. Run `app/plugin app` before
  removing a worktree that is the live plugin: with its folder gone, windows
  load no sitrep at their next `/reload-plugins`, and SitRep never re-points
  the marketplace itself.
- `app/build` installs a build over the cask's copy, and changes the plugin
  too: while SitRep's copy is the plugin, the build's start refreshes the
  copy from what the build carries, so every window runs the building
  checkout's mod from its next `/reload-plugins`. `brew reinstall --cask
  sitrep` puts the release back and leaves SitRep stopped (the cask has no
  postflight since 6 November 2026, and Homebrew's own reopen covers only
  `brew upgrade`), so start it with `app/open` after. The next release's
  `brew upgrade` replaces the build.

## Gates

```bash
claude plugin test .              # every test, the mod's and the CLI's
bunx tsc -p .                     # the mod, the core and the CLI
bunx tsc -p cli/shell             # the CLI's binding to Bun, on its own
bunx tsc -p cli/frames            # the panel's golden-frame checker
bun cli/frames/check.ts           # the panel's frames, and the width sweep
swift build --package-path app    # the app
swift test --package-path app     # the app's tests
```

The type-checks need the engine's types in `.claude-plugin/types/`, which
git leaves out; `.worktreeinclude` copies them into a worktree.

`tests/real-names.txt` lists the names no test may use. It names Lee's real
work, so git leaves it out too. The main clone holds the master copy, and
`.worktreeinclude` copies it from there into each worktree. Without it the
app's tests skip their scans, so the release refuses to run without it.

## The app

`app/` is a Swift package, no Xcode project: the menu bar app, which runs
the plugin's CLI for the board, and makes the jump itself. `app/bundle <folder> <version>`
lays the bundle out, the plugin inside it, into a folder, unsigned; press,
Lee's release tool (`~/bin/press`, reading `.press.toml`), signs it with
his Developer ID from the signing keychain, which it unlocks itself.
`app/build` runs `app/bundle` at `plugin.json`'s version, then
`press sign --dev`, which signs it with no timestamp, installs the bundle to
`/Applications/SitRep.app` over the cask's copy and starts it, replacing the
one running; `app/quit` and `app/open` stop and start SitRep for it and for
`app/plugin`.
A release (`./release`) is built before mint's tag and uploaded after it,
by press. `press check`, mint's `preflight`, checks the Mac can sign and
notarize. `press prepare`, the last of mint's `pre_tag`, builds HEAD in a
worktree of its own, the bundle stamped with the version mint is about to
tag, signs it inside out, notarizes and staples it, and keeps the zip in
`~/Library/Caches/press/sitrep/<version>/`; uncommitted changes, a tag
taken, or HEAD moving before the zip is kept, stop it.
`press upload`, mint's `post_release`, uploads that zip to the GitHub
release, building the tag again where what's kept doesn't fit it beyond
mint's bookkeeping (`plugin.json` in its version alone, `CHANGELOG.md`,
`.mint.toml`), and, for the latest release, sends the cask in
`leeovery/homebrew-tools` the new zip and waits on the tap's update. Both
log to `~/Library/Logs/press/sitrep-<version>.log`.

## Live tests

A live run of the CLI points `XDG_STATE_HOME` at a folder of its own and
seeds its own sessions there, so it never writes to the real board in
`~/.local/state/sitrep`. A jump moves Lee's screen: run one only with Lee's
go.

## Writing the docs

The README and `docs/` are written for someone who runs several Claude Code
windows on a Mac, often across several projects. The code wins over every
page: check each claim, and each label shown on screen, in `hooks/`,
`core/`, `cli/` and `app/Sources`. Every page follows these rules, and a
reviewer checks them:

1. **One idea a sentence.** Fewer than 5% of a page's sentences run over 25
   words.
2. **One topic a paragraph,** its point first, 3 to 5 sentences. No
   paragraph runs over 100 words.
3. **Example first, rule after.** Show the command or the steps and what
   the reader sees, then explain. A tool's output goes in a `console` or
   `text` fence.
4. **No fact-chains.** Three or more items make a list. Conditions make an
   if-then table.
5. **Name the thing.** At most one "its" a sentence, and only for the
   subject. Repeat the noun rather than leave a pronoun to work out.
6. **No possessive chains.** One possessive a noun phrase, and under 1.5 per
   100 words on a page. A natural possessive ("the session's asks") beats
   "the asks of the session"; a verb ("the session holds") beats both.
   Never drop the verb from a second clause.
7. **Plain words in their usual sense:** "if", not "where"; "only", not
   "alone"; "because" and "for example", not "as".
8. **One term, one meaning.** Each term is defined once, in
   `docs/glossary.md`, and never used for anything else. If one word has
   two senses, give the second sense a new word.
9. **Headings that inform,** the first two words carrying it. H3 at most.
10. **The main path on the page.** Edge cases go one level down, behind a
    clear link.
11. **Link to whole pages.** Never link to a heading in another file: the
    GitHub phone app opens such a link at the top of the page.
12. **Benefits first, and specific:** a number or something the reader sees,
    never praise.
13. **"You" and the active voice.** Give a condition before the instruction
    it governs.

The pages are read in the GitHub app on a phone, so:

- code lines run 52 columns at most, each comment on a line of its own
  above its command;
- tables run 4 columns at most, with short cells;
- no `<br>` or other forced line breaks.

Never name a page `claude.md` or `readme.md`: a Mac folds them to
`CLAUDE.md` and `README.md`, and Claude Code loads a `claude.md` as
instructions.

A feature page runs 300 to 700 words, with headings no deeper than H2, in
this order:

- **Title:** the benefit in the reader's words, the first two words
  carrying it.
- **Opening:** 40 to 60 words on what it does for the reader, and when
  they'd want it.
- **The moment:** one still or clip from `art/`, with a one-line caption,
  only once one exists.
- **Try it:** the shortest working example, before any rule: two to four
  steps, slash commands, clicks or shell commands. SitRep is a Mac app and
  a Claude Code plugin, so most are steps, not shell commands.
- **What happens:** 3 to 6 one-sentence bullets on what the reader will
  notice.
- **Good to know:** 2 to 4 bullets of limits, costs and objections.
- **Reference:** a table of 8 rows at most, or links to the reference
  pages.
- **Related:** 2 or 3 links to other pages.

No table of contents. The glossary gives each term in bold, then one to
three plain sentences.

`docs/asks.md` is the first page written to it: match its voice and build.

Measure every page and meet its limits; the script exits 1 on a failure:

```bash
python3 -I ~/.claude/skills/readme-and-docs/scripts/measure.py \
  --root . docs/<page>.md --detail
```

Name nothing real: no person, account, machine, session id or other
project. Use these placeholders: projects Northwind, Contoso, Fabrikam,
Tailspin, Woodgrove and Litware; sessions "Help desk redesign", "Shift
schedules", "Invoice ledger", "Onboarding flow", "Mobile app" and "Data
import"; ids such as `sr-nw0001`. Check every name against
`tests/real-names.txt`.

The docs call the person "you", never Lee. Claude's own texts say "the
user".
