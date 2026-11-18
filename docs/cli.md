# The `sitrep` command: the board from a shell

Run `sitrep` to see the board from a shell, or to post to it from a script. Most people never need it: Claude keeps the board through its own tools, and SitRep runs the command for you.

## Where it is

The command is `bin/sitrep` in the plugin's folder. SitRep installs its own copy of the plugin, so the command is here:

```text
~/Library/Application Support/sitrep/bin/sitrep
```

That copy is a single program, and needs nothing else installed. To type `sitrep` in your shell, add an alias:

```bash
sr=~/Library/"Application Support"/sitrep
alias sitrep="$sr/bin/sitrep"
```

If you run the plugin from a clone of the repository, the `bin/sitrep` in the clone runs on Bun.

## An example

List your sessions, then print one of them:

```console
$ sitrep list
Northwind
  sr-nw0001  Help desk redesign (2 waiting, 1 parked)
  sr-nw0002  Invoice ledger
Contoso
  sr-ct0001  Shift schedules (1 waiting)
$ sitrep board --session sr-nw0001
sitrep board: Help desk redesign (sr-nw0001)
Summary: Redesign the help desk, page by page
Now:
- Laying out the ticket page
Next: The replies page
Open asks:
- xsaq wants a choice, waiting on the user: Pick the editor for replies; options: Threaded | Flat; recommended: Threaded
- 7way wants a yes (Approve), waiting on the user: Review the ticket page
Parked:
- dbp3: Dark mode for the help desk
```

The list shows each session id, with what waits on you. The board names each item by a short id, such as `xsaq`. Other commands take these ids.

## The commands

| Command | What it does |
|---|---|
| `list` | Lists the sessions in each project, with their ids |
| `board` | Prints a session: status, open asks, and the parked items of the project |
| `status` | Sets where a session stands, giving only what changed |
| `ask <title>` | Posts an ask, and prints its id |
| `park <title>` | Parks an item on the project of the session, and prints its id |
| `answer <ask> <answer>` | Answers a yes or a choice ask, the way you would on the board |
| `snooze <ask>...` | Snoozes a session, until a time or until it moves |
| `wake` | Wakes a snoozed session now |
| `finish` | Finishes a session that no window holds |
| `move <project>` | Moves a session to another project on the board |
| `watch` | Prints the board as JSON at each change, for SitRep |

`sitrep --help` lists every command with its flags. `sitrep <command> --help` says more about one.

## Naming the session

Every command but `list` and `watch` works on one session. Name it with `--session`:

```bash
sitrep wake --session sr-nw0001
```

Or set `SITREP_SESSION` once, and leave the flag off:

```bash
export SITREP_SESSION=sr-nw0001
sitrep wake
```

If you give both, `--session` wins. The pane and SitRep never show a session id, but `sitrep list` does.

## Posting an ask

An ask takes `--wants`, and then the flags for its shape:

| `--wants` | Its flags |
|---|---|
| `yes` | `--yes <label>`, the button's verb, 20 characters at most |
| `choice` | `--option <choice>` for each option, two at least; `--recommended <choice>` for the one you lean toward |
| `words` | `--needs <words>`, what the words should be (optional) |

For example, a choice:

```bash
sitrep ask Pick the editor for replies \
  --wants choice \
  --option Threaded --option Flat \
  --recommended Threaded \
  --session sr-nw0001
```

The title needs no quotes: every word that isn't a flag goes into it. Both `ask` and `park` also take two flags:

- `--where <words>` says in words where to look.
- `--ref <ref>` points to your own record of the item.

## Other flags

- **`status`** takes `--name`, `--summary`, `--now` and `--next`. Give `--now` once for each line under way: together they replace the whole list. `--now ""` empties it, and `--next ""` clears it.
- **`answer`** takes the ask id, then a yes in its own words or one of the options. Give `--ignore` in place of an answer to ignore any ask. An answer to a words ask, or a comment, needs the Claude Code prompt.
- **`snooze`** names every ask waiting on you in the session, so none is snoozed unseen. `--until <ms>` sets the wake time, in milliseconds since the epoch. Without it, the session sleeps until it moves.
- **`list`** shows the sessions that aren't finished and have a window, an ask waiting, or a change in the last week. Projects whose directory holds your current folder come first. `--project <name>` lists only that project.

An answer goes into the inbox of the session. The Claude Code window running that session sends it to Claude as your own message, now or once a window takes the session up.

## JSON for tools

`list` and `board` take `--json`. Each prints one JSON object, with a `v` field for the version of its shape.

| Command | What the JSON holds |
|---|---|
| `list --json` | Every project listed, with counts and each session |
| `board --json` | One session: open asks, the items it parked itself, the latest status changes, and resolved asks |

Note that `board --json` holds only the items this session parked. The text form lists every parked item of the project.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Done |
| `1` | A usage error, a refused input, or a failure |
| `2` | No such session |

A refusal prints one line to standard error, starting `sitrep:`, that says what to fix. Run with no command, `sitrep` prints the help to standard error and exits 1.

## Related

- [How Claude keeps the board](claude-and-sitrep.md)
- [Installing and removing](install.md)
- [The board's words](glossary.md)
