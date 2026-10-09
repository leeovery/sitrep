import { expect, test } from 'claude-code/testing'
import { EXIT, main, WRITER } from '../cli/main'
import { boardText, foldWork, parseEntries, serialise, VERSION, type WorkPaths } from '../core'
import { ask, file, META, MIN, note, status, T0, W1 } from './support'
import { ENV, FIRST_ID, NEXT_ID, NOW, terminal } from './terminal'
import { ELSEWHERE } from './world'

type Terminal = ReturnType<typeof terminal>

/** Another piece of work, in this project or another. */
const LOBBY = { ...META, id: 'sr-bbbbbb', name: 'Lobby' }

const WORK = ['--work', META.id]

/** The work as the mod's fold reads it from the files the terminal holds: its window's lines, and the CLI's. */
const folded = (t: Terminal, paths: WorkPaths, now = NOW) => {
  const work = foldWork(
    {
      meta: t.text(paths.meta),
      logs: Object.fromEntries(
        [W1, WRITER].flatMap(writer => {
          const held = t.files.get(paths.log(writer))

          return held === undefined ? [] : [[writer, held.text]]
        }),
      ),
    },
    now,
  )

  if (work === undefined) {
    throw new Error('the work did not fold')
  }

  return work
}

const cliLines = (t: Terminal, paths: WorkPaths) => parseEntries(t.text(paths.log(WRITER)))

test('a note prints its id and nothing more, and appends one line to the CLI’s own file', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const run = await t.run(
    'note',
    'Round 3 drawn',
    '--detail',
    'Frames 1–6',
    '--detail',
    'In Paper',
    '--ref',
    'docs/plan.md',
    ...WORK,
  )

  expect(run).toEqual({ exit: EXIT.done, out: `${FIRST_ID}\n`, err: '' })
  expect(cliLines(t, paths)).toEqual([
    {
      v: VERSION,
      at: NOW,
      seq: 1,
      type: 'note',
      id: FIRST_ID,
      text: 'Round 3 drawn',
      detail: ['Frames 1–6', 'In Paper'],
      ref: 'docs/plan.md',
    },
  ])
})

test("the CLI's note is in the log as the mod folds it, and its ask counts as waiting", async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: [[T0, ask('k1', 'review', 'Review round 1')]] })

  await t.run('note', 'Round', '3', 'drawn', ...WORK)
  await t.run('ask', 'try', 'Try', 'it', 'on', 'the', 'iPad', '--where', 'On the iPad', ...WORK)

  const work = folded(t, paths)

  expect(work.log.map(line => [line.kind, line.id, line.text, line.by])).toEqual([
    ['note', FIRST_ID, 'Round 3 drawn', WRITER],
  ])
  expect(work.waiting).toBe(2)
  expect(work.asks.map(each => [each.id, each.kind, each.title, each.where, each.by])).toEqual([
    ['k1', 'review', 'Review round 1', undefined, W1],
    [NEXT_ID, 'try', 'Try it on the iPad', 'On the iPad', WRITER],
  ])
})

test('a decide ask takes its options, one --option each', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const run = await t.run(
    'ask',
    'decide',
    'Keep the sidebar, or drop it?',
    '--option',
    'Keep it',
    '--option',
    'Drop it',
    '--ref',
    'DESIGN.md',
    ...WORK,
  )

  expect(run.out).toBe(`${FIRST_ID}\n`)
  expect(folded(t, paths).asks.at(0)).toMatchObject({
    kind: 'decide',
    options: ['Keep it', 'Drop it'],
    ref: 'DESIGN.md',
    state: 'waiting',
  })
})

test("an ask takes what Lee's answer must carry back with --needs, kept on its line; an empty one is absent", async () => {
  const t = terminal()
  const paths = t.seed(META)
  const run = await t.run(
    'ask',
    'do',
    'Run the export',
    '--needs',
    "the command's\n output",
    ...WORK,
  )

  await t.run('ask', 'do', 'Run the apply', '--needs', ' ', ...WORK)

  expect(run).toEqual({ exit: EXIT.done, out: `${FIRST_ID}\n`, err: '' })
  expect(cliLines(t, paths).map(line => line.type === 'ask' && line.needs)).toEqual([
    "the command's output",
    undefined,
  ])
  expect(folded(t, paths).asks.map(each => each.needs)).toEqual(["the command's output", undefined])
})

test("an input core's checks refuse ends as refused, with the check's words, and writes nothing", async () => {
  const t = terminal()
  const paths = t.seed(META)
  const refused = async (...words: string[]) => {
    const run = await t.run(...words, ...WORK)

    expect(run.exit).toBe(EXIT.refused)
    expect(run.out).toBe('')

    return run.err
  }

  expect(await refused('ask', 'decide', 'Keep it?', '--option', 'Keep it')).toBe(
    'sitrep: A decide ask needs at least 2 options.\n',
  )
  expect(await refused('ask', 'review', 'Review it', '--option', 'Yes')).toBe(
    'sitrep: Only a decide ask takes options.\n',
  )
  expect(await refused('ask', 'approve', 'Approve it')).toBe(
    "sitrep: An ask's kind is one of review, decide, try, do.\n",
  )
  expect(await refused('ask', 'review')).toBe(
    'sitrep: An ask needs a title: one line, starting with the verb.\n',
  )
  expect(await refused('note', ' ')).toBe('sitrep: A note needs its text: one line.\n')
  expect(await refused('park')).toBe('sitrep: A parked item needs a title: one line.\n')
  expect(await refused('status')).toBe(
    'sitrep: A status needs at least one of name, summary, now and next.\n',
  )
  expect(await refused('status', '--name', '')).toBe(
    'sitrep: A status keeps a name and a summary: neither can be empty.\n',
  )
  expect(t.files.has(paths.log(WRITER))).toBe(false)
})

test('park prints its id, and the work counts it parked', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const run = await t.run('park', 'A tmux indicator', '--where', 'DESIGN.md, Later', ...WORK)

  expect(run.out).toBe(`${FIRST_ID}\n`)
  expect(folded(t, paths).parked.map(each => [each.id, each.title, each.where])).toEqual([
    [FIRST_ID, 'A tmux indicator', 'DESIGN.md, Later'],
  ])
})

test('a status gives only what changed, the rest kept as it stands, and prints nothing', async () => {
  const t = terminal()
  const paths = t.seed(META, {
    lines: [[T0, status(['Drawing Usage, round 2'], { next: 'Usage, round 3' })]],
  })

  expect(await t.run('status', '--now', 'Reviewing round 2', ...WORK)).toEqual({
    exit: EXIT.done,
    out: '',
    err: '',
  })
  expect(folded(t, paths).status).toEqual({
    name: META.name,
    summary: META.summary,
    now: ['Reviewing round 2'],
    next: 'Usage, round 3',
    at: NOW,
    by: WRITER,
  })
  expect(folded(t, paths).log.at(0)?.text, 'the board logs the change').toBe(
    'Status: now reviewing round 2',
  )
})

test('a status clears what is under way with --now "", and what is next with --next ""', async () => {
  const t = terminal()
  const paths = t.seed(META, {
    lines: [[T0, status(['Drawing Usage'], { next: 'Usage, round 3' })]],
  })

  await t.run('status', '--now', '', '--next', '', '--name', 'Dashboard', ...WORK)

  expect(folded(t, paths).status).toMatchObject({
    name: 'Dashboard',
    summary: META.summary,
    now: [],
    next: undefined,
  })
})

test('the CLI appends after what its file holds: its count goes on, and nothing before is rewritten', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const before = file([T0, note('n1', 'Generated round 1')], [T0, note('n2', 'Generated round 2')])

  t.files.set(paths.log(WRITER), { text: before, mtimeMs: T0 })
  await t.run('note', 'Generated round 3', ...WORK)

  const after = t.text(paths.log(WRITER))

  expect(after.startsWith(before)).toBe(true)
  expect(cliLines(t, paths).map(entry => entry.seq)).toEqual([1, 2, 3])
})

test('a line left torn in its file is ended first, so the torn line stays the only casualty', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const torn = `${serialise({ v: VERSION, at: T0, seq: 1, type: 'note', id: 'n1', text: 'Whole' })}{"v":1,"at":`

  t.files.set(paths.log(WRITER), { text: torn, mtimeMs: T0 })
  await t.run('note', 'After the tear', ...WORK)

  expect(cliLines(t, paths).map(entry => [entry.seq, 'text' in entry && entry.text])).toEqual([
    [1, 'Whole'],
    [2, 'After the tear'],
  ])
})

test('two runs at once, each reading the file before either wrote, both land, with one count', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const held = t.holdAppends(2)
  const runs = Promise.all([
    main(['note', 'Round 3 drawn', ...WORK], t.io),
    main(['ask', 'review', 'Review round 3', ...WORK], t.io),
  ])

  await held.arrived
  held.release()

  expect(await runs).toEqual([EXIT.done, EXIT.done])
  expect(cliLines(t, paths).map(entry => [entry.seq, entry.type])).toEqual([
    [1, 'note'],
    [1, 'ask'],
  ])

  const work = folded(t, paths)

  expect(work.log.map(line => line.text)).toEqual(['Round 3 drawn'])
  expect(work.waiting).toBe(1)
})

test('the work is the one --work names, else SITREP_WORK’s, and --work wins', async () => {
  const t = terminal({ env: { ...ENV, SITREP_WORK: LOBBY.id } })
  const dashboard = t.seed(META)
  const lobby = t.seed(LOBBY)

  await t.run('note', 'Into the dashboard', ...WORK)
  await t.run('note', 'Into the lobby')

  expect(folded(t, dashboard).log.map(line => line.text)).toEqual(['Into the dashboard'])
  expect(folded(t, lobby).log.map(line => line.text)).toEqual(['Into the lobby'])
})

test('with no work named, a command on one is refused, saying both ways to name it', async () => {
  const t = terminal()
  const nameIt =
    'sitrep: Name the piece of work: --work sr-xxxxxx, or SITREP_WORK in the environment.\n'

  t.seed(META)

  for (const words of [['note', 'Hello'], ['board'], ['status', '--next', 'Lunch']]) {
    expect(await t.run(...words)).toEqual({ exit: EXIT.refused, out: '', err: nameIt })
  }

  expect(
    (await terminal({ env: { ...ENV, SITREP_WORK: '' } }).run('board')).err,
    'an empty SITREP_WORK names none',
  ).toBe(nameIt)
})

test('a work id that is not one is refused as join refuses it', async () => {
  const t = terminal({ env: { ...ENV, SITREP_WORK: 'dashboard' } })

  expect(await t.run('board')).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: Name the piece of work by the id start gave it: sr- and six characters.\n',
  })
})

test('an id filed in no project is no such work, and ends as such', async () => {
  const t = terminal()

  t.seed(META)

  expect(await t.run('note', 'Hello', '--work', 'sr-zzzzzz')).toEqual({
    exit: EXIT.noWork,
    out: '',
    err: 'sitrep: There is no piece of work sr-zzzzzz on the board, in any project.\n',
  })
})

test('a work whose work.json is torn is no such work', async () => {
  const t = terminal()
  const paths = t.seed(META)

  t.files.set(paths.meta, { text: '{"v":1,"id":', mtimeMs: T0 })

  expect((await t.run('board', ...WORK)).exit).toBe(EXIT.noWork)
})

test('a work is found in whichever project files it, whatever folder the CLI runs in', async () => {
  const t = terminal({ cwd: '/Users/lee' })
  const there = t.seed(LOBBY, { project: ELSEWHERE.key })

  t.seed(META)

  expect((await t.run('note', 'Found it over there', '--work', LOBBY.id)).exit).toBe(EXIT.done)
  expect(folded(t, there).log.map(line => line.text)).toEqual(['Found it over there'])
})

test('board prints the board as Claude’s board tool reads it', async () => {
  const t = terminal()
  const paths = t.seed(META, {
    lines: [
      [T0, status(['Drawing Usage'])],
      [T0, ask('k1', 'review', 'Review round 1')],
    ],
  })
  const run = await t.run('board', ...WORK)

  expect(run).toEqual({ exit: EXIT.done, out: `${boardText(folded(t, paths))}\n`, err: '' })
  expect(t.files.has(paths.log(WRITER)), 'reading the board writes nothing').toBe(false)
})

test('help: every command in brief, how a work is named, the exit codes, and answering not yet', async () => {
  const t = terminal()
  const { exit, out, err } = await t.run('--help')

  expect([exit, err]).toEqual([EXIT.done, ''])
  expect(out).toContain(
    '  sitrep ask <kind> <title> [--where <words>] [--needs <words>] [--option <choice>]... [--ref <ref>]\n',
  )
  expect(out).toContain('  sitrep list [--project <name>] [--json]\n')
  expect(out).toContain('--work sr-xxxxxx, else $SITREP_WORK')
  expect(out).toContain('2 no such piece of work')
  expect(out).toContain('Answering an ask from here: not yet.')
  expect((await t.run('help')).out).toBe(out)
  expect((await t.run('-h')).out).toBe(out)
})

test("a command's help is its usage, what it does and each of its words, however it is asked for", async () => {
  const t = terminal()
  const help = (await t.run('note', '--help')).out

  expect(help).toBe(
    [
      'Usage: sitrep note <text> [--detail <line>]... [--ref <ref>] [--work <id>]',
      '',
      "Add a line to the board's log: something Lee would want to know later. Prints its id.",
      '',
      '  <text>           one line, starting with the verb',
      '  --detail <line>  a line it opens to; one each',
      '  --ref <ref>      where your own record of it is',
      '  --work <id>      the piece of work: sr- and six characters; else $SITREP_WORK',
      '',
    ].join('\n'),
  )
  expect((await t.run('help', 'note')).out).toBe(help)
  expect((await t.run('note', 'Hello', '-h')).out).toBe(help)
})

test('no words, an unknown command or a word that will not read is a usage error, pointing at the help', async () => {
  const t = terminal()
  const bare = await t.run()

  expect([bare.exit, bare.out]).toEqual([EXIT.refused, ''])
  expect(bare.err).toContain('sitrep <command> --help says more.')
  expect(await t.run('answer', 'k1')).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: There is no command answer. sitrep --help lists them.\n',
  })
  expect((await t.run('help', 'answer')).exit).toBe(EXIT.refused)
  expect(await t.run('list', '--work', META.id)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: There is no --work. sitrep list --help says more.\n',
  })
})

test('a failure the world throws is told, and ends as refused', async () => {
  const t = terminal({ env: {} })

  expect(await t.run('list')).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: sitrep needs HOME or XDG_STATE_HOME to place its folder\n',
  })
})

test('a run stamps its lines with the time it ran', async () => {
  const later = T0 + 90 * MIN
  const t = terminal({ now: () => later })
  const paths = t.seed(META)

  await t.run('note', 'Later on', ...WORK)

  expect(cliLines(t, paths).at(0)?.at).toBe(later)
})
