import { expect, test } from 'claude-code/testing'
import { EXIT, main, WRITER } from '../cli/main'
import {
  boardText,
  foldSession,
  parseEntries,
  serialise,
  STALE_MS,
  VERSION,
  type SessionPaths,
} from '../core'
import {
  beat,
  file,
  finish,
  META,
  MIN,
  note,
  park,
  snoozeSession,
  status,
  T0,
  W1,
  W2,
  yesAsk,
  type Line,
} from './support'
import { ENV, FIRST_ID, NEXT_ID, NOW, terminal } from './terminal'
import { ELSEWHERE } from './world'

type Terminal = ReturnType<typeof terminal>

/** Another session, in this project or another. */
const LOBBY = { ...META, id: 'sr-bbbbbb', name: 'Lobby' }

const SESSION = ['--session', META.id]

/** The session as the mod's fold reads it from the files the terminal holds: its window's lines, and the CLI's. */
const folded = (t: Terminal, paths: SessionPaths, now = NOW) => {
  const session = foldSession(
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

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

const cliLines = (t: Terminal, paths: SessionPaths) => parseEntries(t.text(paths.log(WRITER)))

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
    ...SESSION,
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
  const paths = t.seed(META, { lines: [[T0, yesAsk('k1', 'Review round 1')]] })

  await t.run('note', 'Round', '3', 'drawn', ...SESSION)
  await t.run(
    'ask',
    'Try',
    'it',
    'on',
    'the',
    'iPad',
    '--wants',
    'yes',
    '--yes',
    'It works',
    '--where',
    'On the iPad',
    ...SESSION,
  )

  const session = folded(t, paths)

  expect(session.log.map(line => [line.kind, line.id, line.text, line.by])).toEqual([
    ['note', FIRST_ID, 'Round 3 drawn', WRITER],
  ])
  expect(session.waiting).toBe(2)
  expect(session.asks.map(each => [each.id, each.yes, each.title, each.where, each.by])).toEqual([
    ['k1', 'Approve', 'Review round 1', undefined, W1],
    [NEXT_ID, 'It works', 'Try it on the iPad', 'On the iPad', WRITER],
  ])
})

test('a choice ask takes its options, one --option each', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const run = await t.run(
    'ask',
    'Keep the sidebar, or drop it?',
    '--wants',
    'choice',
    '--option',
    'Keep it',
    '--option',
    'Drop it',
    '--ref',
    'DESIGN.md',
    ...SESSION,
  )

  expect(run.out).toBe(`${FIRST_ID}\n`)
  expect(folded(t, paths).asks.at(0)).toMatchObject({
    wants: 'choice',
    options: ['Keep it', 'Drop it'],
    ref: 'DESIGN.md',
    state: 'waiting',
  })
})

test('a yes ask takes its button with --yes; a words ask what its words are with --needs, an empty one absent', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const run = await t.run(
    'ask',
    'Run the export',
    '--wants',
    'words',
    '--needs',
    "the command's\n output",
    ...SESSION,
  )

  await t.run('ask', 'Run the apply', '--wants', 'words', '--needs', ' ', ...SESSION)
  await t.run('ask', 'Give the go for stage 3', '--wants', 'yes', '--yes', 'Go', ...SESSION)

  expect(run).toEqual({ exit: EXIT.done, out: `${FIRST_ID}\n`, err: '' })
  expect(cliLines(t, paths).map(line => line.type === 'ask' && line.needs)).toEqual([
    "the command's output",
    undefined,
    undefined,
  ])
  expect(folded(t, paths).asks.map(each => [each.wants, each.yes, each.needs])).toEqual([
    ['words', undefined, "the command's output"],
    ['words', undefined, undefined],
    ['yes', 'Go', undefined],
  ])
})

test("an input core's checks refuse ends as refused, with the check's words, and writes nothing", async () => {
  const t = terminal()
  const paths = t.seed(META)
  const refused = async (...words: string[]) => {
    const run = await t.run(...words, ...SESSION)

    expect(run.exit).toBe(EXIT.refused)
    expect(run.out).toBe('')

    return run.err
  }

  expect(await refused('ask', 'Keep it?', '--wants', 'choice', '--option', 'Keep it')).toBe(
    'sitrep: A choice ask needs at least 2 options.\n',
  )
  expect(
    await refused('ask', 'Review it', '--wants', 'yes', '--yes', 'Go', '--option', 'Yes'),
  ).toBe('sitrep: Only a choice ask takes options.\n')
  expect(await refused('ask', 'Review it', '--wants', 'yes')).toContain(
    "sitrep: A yes ask needs yes: its button's words",
  )
  expect(await refused('ask', 'Run it', '--wants', 'yes', '--yes', 'Go', '--needs', 'x')).toBe(
    'sitrep: Only a words ask takes needs: what its words are.\n',
  )
  expect(await refused('ask', 'Approve it')).toBe(
    "sitrep: An ask's wants is one of yes, choice, words: a yes, one of its options, or words.\n",
  )
  expect(await refused('ask', 'review', 'Approve it')).toBe(
    "sitrep: An ask's wants is one of yes, choice, words: a yes, one of its options, or words.\n",
  )
  expect(await refused('ask', '--wants', 'words')).toBe(
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

test('park prints its id, and the session counts it parked', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const run = await t.run('park', 'A tmux indicator', '--where', 'DESIGN.md, Later', ...SESSION)

  expect(run.out).toBe(`${FIRST_ID}\n`)
  expect(folded(t, paths).parked.map(each => [each.id, each.title, each.where])).toEqual([
    [FIRST_ID, 'A tmux indicator', 'DESIGN.md, Later'],
  ])
})

test("park draws an id apart from every item parked in the session's project, as Claude's park does", async () => {
  const t = terminal()
  const paths = t.seed(META)

  t.seed(LOBBY, { lines: [[T0, park(FIRST_ID, 'Export the ledger as CSV')]] })

  expect((await t.run('park', 'A tmux indicator', ...SESSION)).out).toBe(`${NEXT_ID}\n`)
  expect(folded(t, paths).parked.map(each => each.id)).toEqual([NEXT_ID])
})

test('a status gives only what changed, the rest kept as it stands, and prints nothing', async () => {
  const t = terminal()
  const paths = t.seed(META, {
    lines: [[T0, status(['Drawing Usage, round 2'], { next: 'Usage, round 3' })]],
  })

  expect(await t.run('status', '--now', 'Reviewing round 2', ...SESSION)).toEqual({
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

  await t.run('status', '--now', '', '--next', '', '--name', 'Dashboard', ...SESSION)

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
  await t.run('note', 'Generated round 3', ...SESSION)

  const after = t.text(paths.log(WRITER))

  expect(after.startsWith(before)).toBe(true)
  expect(cliLines(t, paths).map(entry => entry.seq)).toEqual([1, 2, 3])
})

test('a line left torn in its file is ended first, so the torn line stays the only casualty', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const torn = `${serialise({ v: VERSION, at: T0, seq: 1, type: 'note', id: 'n1', text: 'Whole' })}{"v":1,"at":`

  t.files.set(paths.log(WRITER), { text: torn, mtimeMs: T0 })
  await t.run('note', 'After the tear', ...SESSION)

  expect(cliLines(t, paths).map(entry => [entry.seq, 'text' in entry && entry.text])).toEqual([
    [1, 'Whole'],
    [2, 'After the tear'],
  ])
})

test('a file listed that will not read is not there, and the run goes on', async () => {
  const t = terminal()
  const paths = t.seed(META, { lines: [[T0, yesAsk('k1', 'Review round 1')]] })
  const { read } = t.io.fs

  t.files.set(paths.log(W2), { text: file([T0, note('n2', 'Drew round 2')]), mtimeMs: T0 })
  t.io.fs.read = async path =>
    path === paths.log(W2) ? Promise.reject(new Error(`EACCES: ${path}`)) : read(path)

  const run = await t.run('board', ...SESSION)

  expect(run.exit).toBe(EXIT.done)
  expect(run.out).toContain('Review round 1')
  expect(run.out).not.toContain('Drew round 2')
})

test('two runs at once, each reading the file before either wrote, both land, with one count', async () => {
  const t = terminal()
  const paths = t.seed(META)
  const held = t.holdAppends(2)
  const runs = Promise.all([
    main(['note', 'Round 3 drawn', ...SESSION], t.io),
    main(['ask', 'Review round 3', '--wants', 'yes', '--yes', 'Approve', ...SESSION], t.io),
  ])

  await held.arrived
  held.release()

  expect(await runs).toEqual([EXIT.done, EXIT.done])
  expect(cliLines(t, paths).map(entry => [entry.seq, entry.type])).toEqual([
    [1, 'note'],
    [1, 'ask'],
  ])

  const session = folded(t, paths)

  expect(session.log.map(line => line.text)).toEqual(['Round 3 drawn'])
  expect(session.waiting).toBe(1)
})

test('the session is the one --session names, else SITREP_SESSION’s, and --session wins', async () => {
  const t = terminal({ env: { ...ENV, SITREP_SESSION: LOBBY.id } })
  const dashboard = t.seed(META)
  const lobby = t.seed(LOBBY)

  await t.run('note', 'Into the dashboard', ...SESSION)
  await t.run('note', 'Into the lobby')

  expect(folded(t, dashboard).log.map(line => line.text)).toEqual(['Into the dashboard'])
  expect(folded(t, lobby).log.map(line => line.text)).toEqual(['Into the lobby'])
})

test('with no session named, a command on one is refused, saying both ways to name it', async () => {
  const t = terminal()
  const nameIt =
    'sitrep: Name the session: --session sr-xxxxxx, or SITREP_SESSION in the environment.\n'

  t.seed(META)

  for (const words of [['note', 'Hello'], ['board'], ['status', '--next', 'Lunch']]) {
    expect(await t.run(...words)).toEqual({ exit: EXIT.refused, out: '', err: nameIt })
  }

  expect(
    (await terminal({ env: { ...ENV, SITREP_SESSION: '' } }).run('board')).err,
    'an empty SITREP_SESSION names none',
  ).toBe(nameIt)
})

test('a session id that is not one is refused as join refuses it', async () => {
  const t = terminal({ env: { ...ENV, SITREP_SESSION: 'dashboard' } })

  expect(await t.run('board')).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: Name the session by the id start gave it: sr- and six characters.\n',
  })
})

test('an id filed in no project is no such session, and ends as such', async () => {
  const t = terminal()

  t.seed(META)

  expect(await t.run('note', 'Hello', '--session', 'sr-zzzzzz')).toEqual({
    exit: EXIT.noSession,
    out: '',
    err: 'sitrep: There is no session sr-zzzzzz on the board, in any project.\n',
  })
})

test('a session whose session.json is torn is no such session', async () => {
  const t = terminal()
  const paths = t.seed(META)

  t.files.set(paths.meta, { text: '{"v":1,"id":', mtimeMs: T0 })

  expect((await t.run('board', ...SESSION)).exit).toBe(EXIT.noSession)
})

test('a session is found in whichever project files it, whatever folder the CLI runs in', async () => {
  const t = terminal({ cwd: '/Users/lee' })
  const there = t.seed(LOBBY, { project: ELSEWHERE.key })

  t.seed(META)

  expect((await t.run('note', 'Found it over there', '--session', LOBBY.id)).exit).toBe(EXIT.done)
  expect(folded(t, there).log.map(line => line.text)).toEqual(['Found it over there'])
})

test('board prints the board as Claude’s board tool reads it', async () => {
  const t = terminal()
  const paths = t.seed(META, {
    lines: [
      [T0, status(['Drawing Usage'])],
      [T0, yesAsk('k1', 'Review round 1')],
    ],
  })
  const run = await t.run('board', ...SESSION)

  expect(run).toEqual({ exit: EXIT.done, out: `${boardText(folded(t, paths))}\n`, err: '' })
  expect(t.files.has(paths.log(WRITER)), 'reading the board writes nothing').toBe(false)
})

test("finish finishes a session no window holds as Lee's finish on the board does, in the CLI's own file, and prints nothing", async () => {
  const t = terminal()
  const paths = t.seed(META, {
    lines: [[T0, yesAsk('k1', 'Review round 1')]],
    seenAt: NOW - STALE_MS - 1,
  })

  expect((await t.run('list')).out).toContain(META.id)
  expect(await t.run('finish', ...SESSION)).toEqual({ exit: EXIT.done, out: '', err: '' })
  expect(cliLines(t, paths)).toEqual([{ v: VERSION, at: NOW, seq: 1, type: 'finish', who: 'lee' }])
  expect(folded(t, paths)).toMatchObject({
    finished: { at: NOW, by: WRITER, who: 'lee' },
    waiting: 0,
  })
  expect(t.files.has(paths.letters(WRITER)), 'nothing goes to its inbox').toBe(false)
  expect((await t.run('list')).out).toBe('No current sessions on the board.\n')
})

test('finish refuses a session a live window holds, which is finished there, and one already finished; an unknown one is no such session', async () => {
  const t = terminal()
  const held = t.seed(META, { seenAt: NOW })
  const done = t.seed(LOBBY, { lines: [[T0, finish('claude', 'Shipped')]] })

  expect(await t.run('finish', ...SESSION)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: Dashboard redesign is open in a window: tell Claude there to finish it.\n',
  })
  expect((await t.run('finish', '--session', LOBBY.id)).err).toBe(
    'sitrep: This session is already finished.\n',
  )
  expect((await t.run('finish', '--session', 'sr-zzzzzz')).exit).toBe(EXIT.noSession)
  expect([held, done].some(paths => t.files.has(paths.log(WRITER)))).toBe(false)
})

/** When the snoozes under test wake: an hour after the CLI runs. */
const WAKES = NOW + 60 * MIN

/** The session's window posted three asks, and holds it at Lee's turn. */
const ASKED = {
  seenAt: NOW,
  lines: [
    [T0, yesAsk('k1', 'Review round 1')],
    [T0, yesAsk('k2', 'Ship it', 'Go')],
    [T0, yesAsk('k3', 'Tag the release', 'Done')],
  ] satisfies Line[],
}

/** The asks its row shows, after `--` as answer's. */
const SHOWN = ['--', 'k1', 'k2', 'k3']

const DONE = { exit: EXIT.done, out: '', err: '' }

test("snooze writes one line, the session's, to the CLI's own file, naming the asks its row shows after -- as answer's, nothing in the inbox, and prints nothing; wake likewise", async () => {
  const t = terminal()
  const paths = t.seed(META, ASKED)

  expect(await t.run('snooze', '--until', String(WAKES), ...SESSION, ...SHOWN)).toEqual(DONE)
  expect(folded(t, paths).asks.map(ask => [ask.id, ask.snoozedUntil])).toEqual([
    ['k1', WAKES],
    ['k2', WAKES],
    ['k3', WAKES],
  ])
  expect(await t.run('wake', ...SESSION)).toEqual(DONE)
  expect(cliLines(t, paths)).toEqual([
    { v: VERSION, at: NOW, seq: 1, type: 'snoozeSession', until: WAKES, asks: ['k1', 'k2', 'k3'] },
    { v: VERSION, at: NOW, seq: 2, type: 'wakeSession' },
  ])
  expect(t.files.has(paths.letters(WRITER)), 'nothing goes to its inbox').toBe(false)
  expect(folded(t, paths).asks.map(ask => ask.snoozedUntil)).toEqual([
    undefined,
    undefined,
    undefined,
  ])
})

test('a session at its turn alone snoozes naming no asks, as the app does past its dashes; a wake as its snooze has just run out is no refusal', async () => {
  let now = NOW
  const t = terminal({ now: () => now })
  const paths = t.seed(META, { seenAt: NOW })

  expect(await t.run('snooze', '--until', String(NOW + 30_000), ...SESSION, '--')).toEqual(DONE)
  expect(folded(t, paths).snooze).toEqual({ until: NOW + 30_000, at: NOW, asks: [] })
  now = NOW + 40_000
  expect(await t.run('wake', ...SESSION)).toEqual(DONE)
  expect(folded(t, paths, now).snooze).toBeUndefined()
})

test('a snooze with no time holds until it moves, its line with none; board --json says so of each ask, its snoozedUntil null', async () => {
  const t = terminal()
  const paths = t.seed(META, ASKED)

  expect(await t.run('snooze', ...SESSION, ...SHOWN)).toEqual(DONE)
  expect(cliLines(t, paths)).toEqual([
    { v: VERSION, at: NOW, seq: 1, type: 'snoozeSession', asks: ['k1', 'k2', 'k3'] },
  ])

  const board = JSON.parse((await t.run('board', '--json', ...SESSION)).out) as {
    session: { waiting: number; snoozed: number }
    asks: { snoozedUntil: number | null; untilItMoves: boolean }[]
  }

  expect(board.session).toMatchObject({ waiting: 0, snoozed: 3 })
  expect(board.asks.map(ask => [ask.snoozedUntil, ask.untilItMoves])).toEqual([
    [null, true],
    [null, true],
    [null, true],
  ])
})

test('a snooze or a wake refused ends as refused, in the check’s words, and writes nothing; an unknown session is no such session', async () => {
  const t = terminal()
  const paths = t.seed(META, ASKED)
  const refused = (error: string) => ({ exit: EXIT.refused, out: '', err: `sitrep: ${error}\n` })
  const until = ['--until', String(WAKES)]

  t.seed(LOBBY)
  expect(await t.run('snooze', 'k1', 'zz', ...until, ...SESSION)).toEqual(
    refused('There is no item zz on this board.'),
  )
  expect(await t.run('snooze', 'k1', 'k2', ...until, ...SESSION)).toEqual(
    refused('An ask waits on Lee that the snooze did not name: look at it, then snooze again.'),
  )
  expect(await t.run('snooze', ...until, '--session', LOBBY.id)).toEqual(
    refused('Lobby needs nothing of Lee: there is nothing to snooze.'),
  )
  expect(await t.run('snooze', '--until', 'soon', ...SESSION, ...SHOWN)).toEqual(
    refused(
      'A snooze wakes at a time in milliseconds since the epoch, or with none until it moves.',
    ),
  )
  expect(await t.run('snooze', '--until', String(NOW), ...SESSION, ...SHOWN)).toEqual(
    refused('That time has come already: give one still to come.'),
  )
  expect(await t.run('wake', ...SESSION)).toEqual(refused('Dashboard redesign is not snoozed.'))
  expect(t.files.has(paths.log(WRITER))).toBe(false)
  expect((await t.run('snooze', ...until, '--session', 'sr-zzzzzz')).exit).toBe(EXIT.noSession)
  expect((await t.run('wake', '--session', 'sr-zzzzzz')).exit).toBe(EXIT.noSession)
})

test('what the CLI prints says what is snoozed: each ask its snoozedUntil while it is, else null; each session and project how many in list --json and board --json, and plain list among its facts', async () => {
  const t = terminal()

  t.seed(META, ASKED)
  await t.run('snooze', '--until', String(WAKES), ...SESSION, ...SHOWN)

  const listed = JSON.parse((await t.run('list', '--json')).out) as {
    projects: {
      waiting: number
      snoozed: number
      sessions: { waiting: number; snoozed: number }[]
    }[]
  }
  const board = JSON.parse((await t.run('board', '--json', ...SESSION)).out) as {
    session: { waiting: number; snoozed: number }
    asks: { id: string; snoozedUntil: number | null }[]
  }

  expect((await t.run('list')).out).toContain(`${META.id}  ${META.name} (open, 3 snoozed)`)
  expect(listed.projects[0]).toMatchObject({
    waiting: 0,
    snoozed: 3,
    sessions: [{ waiting: 0, snoozed: 3 }],
  })
  expect(board.session).toMatchObject({ waiting: 0, snoozed: 3 })
  expect(board.asks.map(ask => [ask.id, ask.snoozedUntil])).toEqual([
    ['k1', WAKES],
    ['k2', WAKES],
    ['k3', WAKES],
  ])
})

test("board --json gives no snooze where Lee's side has none: an ask Lee's answer is on its way to in a window's message, and every ask of a finished session, their snoozes standing", async () => {
  const t = terminal()
  const lines: Line[] = [...ASKED.lines, [T0 + MIN, snoozeSession(WAKES, 'k1', 'k2', 'k3')]]
  const asksOf = async (id: string) => {
    const board = JSON.parse((await t.run('board', '--json', '--session', id)).out) as {
      session: { waiting: number; snoozed: number }
      asks: { id: string; snoozedUntil: number | null }[]
    }

    const { waiting, snoozed } = board.session

    return [{ waiting, snoozed }, board.asks.map(ask => [ask.id, ask.snoozedUntil])]
  }
  const paths = t.seed(META, { lines })
  const lobby = t.seed(LOBBY, { lines: [...lines, [T0 + 2 * MIN, finish('lee')]] })

  t.files.set(paths.heartbeat(W2), {
    text: beat(W2, {
      attachedAt: NOW,
      seenAt: NOW,
      sending: [{ at: NOW, replies: [{ id: 'r1', item: 'k1', verdict: 'yes' }] }],
    }),
    mtimeMs: NOW,
  })
  expect(await asksOf(META.id)).toEqual([
    { waiting: 0, snoozed: 2 },
    [
      ['k1', null],
      ['k2', WAKES],
      ['k3', WAKES],
    ],
  ])
  expect(await asksOf(LOBBY.id)).toEqual([
    { waiting: 0, snoozed: 0 },
    [
      ['k1', null],
      ['k2', null],
      ['k3', null],
    ],
  ])
  expect(folded(t, lobby).asks[1]?.snoozedUntil, 'standing, for a join to find').toBe(WAKES)
})

test('help: every command in brief, how a session is named, and the exit codes', async () => {
  const t = terminal()
  const { exit, out, err } = await t.run('--help')

  expect([exit, err]).toEqual([EXIT.done, ''])
  expect(out).toContain(
    '  sitrep ask <title> --wants yes|choice|words [--yes <label>] [--option <choice>]... [--recommended <choice>] [--needs <words>] [--where <words>] [--ref <ref>]\n',
  )
  expect(out).toContain(
    '  sitrep answer <ask> (<answer> | --ignore)\n  sitrep snooze <ask>... [--until <ms>]\n  sitrep wake\n  sitrep finish\n',
  )
  expect(out).toContain('  sitrep list [--project <name>] [--json]\n  sitrep watch\n')
  expect(out).toContain('--session sr-xxxxxx, else $SITREP_SESSION')
  expect(out).toContain('2 no such session')
  expect((await t.run('help')).out).toBe(out)
  expect((await t.run('-h')).out).toBe(out)
})

test("a command's help is its usage, what it does and each of its words, however it is asked for", async () => {
  const t = terminal()
  const help = (await t.run('note', '--help')).out

  expect(help).toBe(
    [
      'Usage: sitrep note <text> [--detail <line>]... [--ref <ref>] [--session <id>]',
      '',
      "Add a line to the board's log: something Lee would want to know later. Prints its id.",
      '',
      '  <text>           one line, starting with the verb',
      '  --detail <line>  a line it opens to; one each',
      '  --ref <ref>      where your own record of it is',
      '  --session <id>   the session: sr- and six characters; else $SITREP_SESSION',
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
  expect(await t.run('resolve', 'k1')).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: There is no command resolve. sitrep --help lists them.\n',
  })
  expect((await t.run('help', 'resolve')).exit).toBe(EXIT.refused)
  expect(await t.run('list', '--session', META.id)).toEqual({
    exit: EXIT.refused,
    out: '',
    err: 'sitrep: There is no --session. sitrep list --help says more.\n',
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

  await t.run('note', 'Later on', ...SESSION)

  expect(cliLines(t, paths).at(0)?.at).toBe(later)
})
