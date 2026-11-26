# The `sitrep` command: the board from a shell

Run `sitrep` to see the board from a shell, or to post to it from a script. Most people never need it: Claude keeps the board through its own tools, and SitRep runs the command for you.

## Where it is

The command is `bin/sitrep` in the plugin's folder. SitRep installs its own copy of the plugin, so the command is here:

```text
~/Library/Application Support/sitrep/bin/sitrep
```

That copy is a single program, and needs nothing else installed. SitRep.app carries a copy of its own, and the Homebrew install links that copy into the Homebrew `bin` folder. Any shell or script with that folder on its PATH runs `sitrep`.

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
- xsaq wants a choice, waiting on the user: Thread replies, or keep them flat?; options: Threaded | Flat; recommended: Threaded
- 7way wants a yes (Approve), waiting on the user: Review the ticket page
Parked:
- dbp3: Dark mode for the help desk
```

The list gives each session id. The brackets count what the session holds:

- `open`: a window is running the session.
- `waiting`: asks waiting on you.
- `snoozed`: asks snoozed, with their session or alone.
- `parked`: items the session parked, which never wait on you.

A project with nothing current but parked items shows `no current sessions (1 parked)`. The board names each item by a short id, such as `xsaq`. Other commands take these ids.

## The commands

| Command | What it does |
|---|---|
| `list` | Lists the sessions in each project, with their ids |
| `board` | Prints a session: status, open asks, and the project's parked items |
| `status` | Sets where a session stands, giving only what changed |
| `ask <title>` | Posts an ask, and prints its id |
| `park <title>` | Parks an item on the session's project, and prints its id |
| `answer <ask> <answer>` | Answers a yes, a choice or a words ask, the way you would on the board |
| `snooze <ask>...` | Snoozes a session, or one ask with `--ask` |
| `wake` | Wakes a snoozed session now |
| `finish` | Finishes a session no window is running |
| `move <project>` | Moves a session to a project already on the board; it makes none |
| `watch` | Prints the board as JSON at each change, for SitRep |

In a terminal, `sitrep` with no command opens the board there: see [The board in any terminal](terminal.md). `sitrep --help` lists every command with its flags. `sitrep <command> --help` says more about one.

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

| `--wants` | Flag | What it gives |
|---|---|---|
| `yes` | `--yes <label>` | The button's verb, 20 characters at most. Required |
| `choice` | `--option <choice>` | One option each time; two at least |
| `choice` | `--recommended <choice>` | The option you lean toward |
| `words` | `--needs <words>` | What the words should be. Optional |

For example, a choice, which prints the new ask id:

```console
$ sitrep ask "Thread replies, or keep them flat?" \
    --wants choice \
    --option Threaded --option Flat \
    --recommended Threaded \
    --session sr-nw0001
xsaq
```

Every word that isn't a flag goes into the title. Quote the title if it holds a character the shell reads, such as `?`. Both `ask` and `park` also take two flags:

- `--where <words>` says in words where to look.
- `--ref <ref>` points to your own record of the item.

## Other flags

- **`status`** takes `--name`, `--summary`, `--now` and `--next`. Give `--now` once for each line under way: together they replace the whole list. `--now ""` empties it, and `--next ""` clears it.
- **`answer`** takes the ask id, then the answer. For a yes, that is the word on its button, such as `Approve`. For a choice, it is one of the options. For a words ask, it is your words, on one line. `--wants yes`, `choice` or `words` says what the ask wanted when you saw it: if the ask now wants something else, the answer is refused.

  `--ignore`, in place of an answer, ignores any ask. A comment needs the Claude Code prompt. The answer goes into the session's inbox. The session's Claude Code window sends it to Claude as your own message, now or once a window takes the session up.
- **`snooze`** names every ask waiting on you in the session, so none is snoozed unseen. A session at your turn with no asks takes no ids. `--until <ms>` sets the wake time, in milliseconds since the epoch. Without it, the session sleeps until it moves. In the terminal view, `z` writes the same line, and its menu works out the time.

  `--ask <id>` in place of the ids snoozes only that ask, and needs `--until`. The other asks stay waiting. The asks panel snoozes one ask this way. The pane writes the same line through its own window.
- **`list`** shows the current sessions. Projects whose directory holds your current folder come first. `--project <name>` lists only that project.

For example, approve the review from the sample, then snooze the session for an hour:

```bash
sitrep answer 7way Approve --session sr-nw0001
sitrep snooze xsaq \
  --until $(( ($(date +%s) + 3600) * 1000 )) \
  --session sr-nw0001
```

## JSON for tools

`list` and `board` take `--json`. Each prints one JSON object, with a `v` field for the version of its shape.

| Command | What the JSON holds |
|---|---|
| `list --json` | Every project listed, with counts and each session |
| `board --json` | One session: open asks, the items it parked itself, the latest status changes, and resolved asks |

The text form of `board` lists every item parked in the project, not only this session's.

In `board --json` and `watch`, a choice lists the option Claude recommends first, then the rest in Claude's order. The text form keeps Claude's order.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Done |
| `1` | A usage error, a refused input, or a failure |
| `2` | No such session |
| `129`, `130`, `131`, `143` | The terminal view ended by SIGHUP, SIGINT, SIGQUIT or SIGTERM |

A refusal prints one line to standard error, starting `sitrep:`, that says what to fix.

If SIGTERM or SIGHUP comes while the terminal view runs your resume command, `sitrep` waits for that command to end, then exits 143 or 129.

With no command, `sitrep` opens the terminal view only if standard input and output are both a terminal, and `TERM` isn't `dumb`. Otherwise it prints the help to standard error and exits 1.

## Related

- [How Claude keeps the board](claude-and-sitrep.md)
- [Installing and removing](install.md)
- [The board's words](glossary.md)
