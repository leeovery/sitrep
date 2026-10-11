import { expect, test, tier } from 'claude-code/testing'
import {
  parseEntries,
  parseMeta,
  parsePresence,
  parseProject,
  projectPaths,
  workPaths,
} from '../core'
import { SPECS } from '../hooks/tools'
import { file, finish, META, MIN, T0, W1, W2 } from './support'
import {
  DASHBOARD,
  ELSEWHERE,
  PROJECT,
  REPO,
  ROOT,
  SESSION,
  startedId,
  postedId,
  world,
} from './world'

tier('user')

const TOOLS = [
  'start',
  'join',
  'status',
  'ask',
  'note',
  'park',
  'resolve',
  'reopen',
  'edit',
  'finish',
  'project',
  'board',
]

/** The lines a file holds. */
const linesOf = (w: ReturnType<typeof world>, path: string) => parseEntries(w.text(path))

test('a session start registers every tool, each schema loaded up front', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  expect(w.registered).toEqual(TOOLS.map(name => ({ name, isDeferred: false })))
})

test('start files the work under the project it names, attaches the window and says to record the id', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  const answer = await w.call('start', DASHBOARD)
  const id = startedId(answer)
  const paths = workPaths(ROOT, PROJECT.key, id)

  expect(answer.result).toBe(
    `Started Dashboard redesign as ${id}, in a new project, Switchboard. Record ${id} wherever the project tracks this work, so a later window can join it.`,
  )
  expect(parseProject(w.text(projectPaths(ROOT, PROJECT.key).file))?.name).toBe('Switchboard')
  expect(parseMeta(w.text(paths.meta))).toEqual({
    id,
    name: DASHBOARD.name,
    summary: DASHBOARD.summary,
    project: 'Switchboard',
    root: REPO,
    created: w.clock.now(),
    by: W1,
  })
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)?.leftAt).toBeUndefined()
  expect(w.state.attachment).toEqual({
    project: PROJECT.key,
    work: id,
    writer: W1,
    attachedAt: w.clock.now(),
  })
  expect(w.state.board?.status.name).toBe('Dashboard redesign')
})

test('start refuses a work with no name, no summary or no project, and writes nothing', async ($, on) => {
  const w = world($, on)
  const noProject =
    'A piece of work needs its project: its name as Lee would say it, such as SitRep or Switchboard.'

  await $.session.start(SESSION)

  expect((await w.call('start', { name: 'Dashboard', project: 'SitRep' })).deny).toBe(
    'A piece of work needs a summary: one line on what it is for.',
  )
  expect((await w.call('start', { summary: 'Area by area' })).deny).toContain('needs a name')
  expect((await w.call('start', { name: 'Dashboard', summary: 'Area by area' })).deny).toBe(
    noProject,
  )
  expect((await w.call('start', { ...DASHBOARD, project: ' -!- ' })).deny).toBe(noProject)
  expect((await w.call('start', { ...DASHBOARD, directory: 'Code/sitrep' })).deny).toBe(
    "A project's directory is an absolute path: where the project lives.",
  )
  expect(w.files.size).toBe(0)
})

test('join attaches to a work by its id, in whichever project it is filed', async ($, on) => {
  const w = world($, on)
  const here = { ...META, id: 'sr-aaaaaa', by: 'cli' }
  const there = { ...META, id: 'sr-bbbbbb', name: 'Lobby', project: 'goosemates', by: 'cli' }

  w.seed(here)
  w.seed(there, ELSEWHERE.key)
  await $.session.start(SESSION)

  const joined = await w.call('join', { work: 'sr-bbbbbb' })

  expect(String(joined.result)).toMatch(
    /^Joined Lobby \(sr-bbbbbb\)\. Correct anything on it that is stale against what you know\. The board as it stands:\n/,
  )
  expect(String(joined.result)).toContain('sitrep board: Lobby (sr-bbbbbb)')
  expect(w.state.attachment).toMatchObject({ project: ELSEWHERE.key, work: 'sr-bbbbbb' })
  expect(w.files.has(workPaths(ROOT, ELSEWHERE.key, 'sr-bbbbbb').heartbeat(W1))).toBe(true)

  await w.call('join', { work: 'sr-aaaaaa' })

  expect(w.state.attachment).toMatchObject({ project: PROJECT.key, work: 'sr-aaaaaa' })
})

test('join refuses an id of the wrong shape, or one no project holds', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  expect((await w.call('join', { work: 'dashboard' })).deny).toContain('by the id start gave it')
  expect((await w.call('join', { work: 'sr-zzzzzz' })).deny).toBe(
    'There is no piece of work sr-zzzzzz on the board, in any project.',
  )
  expect(w.state.attachment).toBeUndefined()
})

test('starting or joining while attached lets go of the work held before', async ($, on) => {
  const w = world($, on)
  const first = await w.begin()

  await w.clock.advance(1_000)

  const second = startedId(await w.call('start', { ...DASHBOARD, name: 'Lobby' }))

  expect(parsePresence(w.text(first.paths.heartbeat(W1)), W1)?.leftAt).toBe(w.clock.now())
  expect(w.state.attachment?.work).toBe(second)

  await w.call('join', { work: first.id })

  expect(
    parsePresence(w.text(workPaths(ROOT, PROJECT.key, second).heartbeat(W1)), W1)?.leftAt,
  ).toBeDefined()
  expect(w.state.attachment?.work).toBe(first.id)
})

test('status sets what changed, keeps the rest, and the board logs the change itself', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()

  expect((await w.call('status', { now: ['Drawing Usage, round 2'] })).result).toBe('Status set.')
  expect(w.state.board?.status).toMatchObject({
    name: DASHBOARD.name,
    summary: DASHBOARD.summary,
    now: ['Drawing Usage, round 2'],
  })
  expect(w.state.board?.log[0]?.text).toBe('Status: now drawing Usage, round 2')
  expect(linesOf(w, paths.log(W1)).map(line => line.type)).toEqual(['status'])
  expect((await w.call('status', {})).deny).toContain('at least one of')
})

test('ask posts an ask with a fresh id; a choice ask with too few options is refused', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const options = ['Keep it', 'Drop it']
  const answer = await w.call('ask', { wants: 'choice', title: 'Keep the band?', options })
  const id = postedId(answer)

  expect(answer.result).toBe(`Posted ask ${id}.`)
  expect(w.state.board?.asks).toMatchObject([{ id, wants: 'choice', options, state: 'waiting' }])
  expect(w.state.board?.waiting).toBe(1)
  expect(linesOf(w, paths.log(W1)).at(-1)).toMatchObject({ type: 'ask', id, seq: 1 })
  expect((await w.call('ask', { wants: 'choice', title: 'Keep it?' })).deny).toBe(
    'A choice ask needs at least 2 options.',
  )
})

test("ask posts a yes in its button's words; one wanting a yes with none, or wanting no shape, is refused", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', { wants: 'yes', yes: 'Go', title: 'Give the go' }))

  expect(w.state.board?.asks).toMatchObject([{ id, wants: 'yes', yes: 'Go' }])
  expect((await w.call('ask', { wants: 'yes', title: 'Give the go' })).deny).toContain(
    "A yes ask needs yes: its button's words",
  )
  expect((await w.call('ask', { kind: 'review', title: 'Review it' })).deny).toBe(
    "An ask's wants is one of yes, choice, words: a yes, one of its options, or words.",
  )
})

test('ask takes what the words of a words ask are, and edit changes them or clears them with an empty one', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const id = postedId(
    await w.call('ask', { wants: 'words', title: 'Run the export', needs: "the command's output" }),
  )
  const needs = () => w.state.board?.asks[0]?.needs

  expect(linesOf(w, paths.log(W1)).at(-1)).toMatchObject({ needs: "the command's output" })
  expect(needs()).toBe("the command's output")
  expect((await w.call('edit', { item: id, needs: 'the exit code' })).result).toBe(`Edited ${id}.`)
  expect(needs()).toBe('the exit code')
  expect((await w.call('edit', { item: id, needs: '' })).result).toBe(`Edited ${id}.`)
  expect(needs()).toBeUndefined()
  expect(
    (await w.call('ask', { wants: 'yes', yes: 'Done', title: 'Run it', needs: 'x' })).deny,
  ).toBe('Only a words ask takes needs: what its words are.')
})

test('edit changes what an ask wants back under the same checks: to a yes with its words, to a choice with its options', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', { wants: 'words', title: 'Pick the next stage' }))

  expect((await w.call('edit', { item: id, wants: 'yes' })).deny).toContain('A yes ask needs yes')
  expect((await w.call('edit', { item: id, wants: 'choice' })).deny).toBe(
    'A choice ask needs at least 2 options.',
  )
  await w.call('edit', { item: id, wants: 'choice', options: ['Stage 3', 'Stage 4'] })
  expect(w.state.board?.asks[0]).toMatchObject({ wants: 'choice', options: ['Stage 3', 'Stage 4'] })
  await w.call('edit', { item: id, wants: 'yes', yes: 'Go' })
  expect(w.state.board?.asks[0]).toMatchObject({ wants: 'yes', yes: 'Go' })
  expect(w.state.board?.asks[0]?.options).toBeUndefined()
})

test('the ask and edit tools take wants, yes, options and needs; the ask says how to choose a shape and word its yes', () => {
  const [ask, edit] = ['ask', 'edit'].map(name => SPECS.find(spec => spec.name === name))

  for (const field of ['wants', 'yes', 'options', 'needs']) {
    expect(ask?.inputSchema?.properties, field).toHaveProperty(field)
    expect(edit?.inputSchema?.properties, field).toHaveProperty(field)
  }

  expect(ask?.inputSchema?.required).toEqual(['wants', 'title'])
  expect(ask?.inputSchema?.properties).not.toHaveProperty('kind')
  expect(ask?.description).toContain(
    'Want a yes when Lee gives a go, an approval, or word that it works or is done, its button the verb Lee gives (Go, Approve, Done)',
  )
})

test('note logs a line with its detail; a note with no text is refused', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const answer = await w.call('note', { text: 'Merged the band', detail: ['PR #82'] })
  const id = postedId(answer)

  expect(answer.result).toBe(`Logged note ${id}.`)
  expect(w.state.board?.log[0]).toMatchObject({ id, text: 'Merged the band', detail: ['PR #82'] })
  expect((await w.call('note', { text: ' ' })).deny).toBe('A note needs its text: one line.')
})

test('park puts an item by to come back to; one with no title is refused', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const answer = await w.call('park', { title: 'Look at the glance again', where: 'In the spike' })
  const id = postedId(answer)

  expect(answer.result).toBe(`Parked ${id}.`)
  expect(w.state.board?.parked).toMatchObject([{ id, title: 'Look at the glance again' }])
  expect((await w.call('park', {})).deny).toBe('A parked item needs a title: one line.')
})

test('resolve closes an item, reopen opens it again; each refuses where the item already is', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' }),
  )

  expect((await w.call('reopen', { item: id })).deny).toBe(`${id} is already open.`)
  expect((await w.call('resolve', { item: id, reason: 'Approved in the chat' })).result).toBe(
    `Resolved ${id}.`,
  )
  expect(w.state.board?.asks[0]).toMatchObject({ state: 'closed', reason: 'Approved in the chat' })
  expect((await w.call('resolve', { item: id })).deny).toBe(`${id} is already closed.`)
  expect((await w.call('reopen', { item: id })).result).toBe(`Reopened ${id}.`)
  expect(w.state.board?.asks[0]?.state).toBe('waiting')
  expect((await w.call('resolve', { item: 'zzzz' })).deny).toBe(
    'There is no item zzzz on this board.',
  )
})

test("edit corrects an item's own fields; a field its kind has not is refused", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('note', { text: 'Merged the bnad' }))

  expect((await w.call('edit', { item: id, text: 'Merged the band' })).result).toBe(`Edited ${id}.`)
  expect(w.state.board?.log[0]?.text).toBe('Merged the band')
  expect((await w.call('edit', { item: id, title: 'Merged' })).deny).toContain('not title')
})

test('finish marks the attached work done with its reason, the window staying attached; a second is refused', async ($, on) => {
  const w = world($, on)
  const { id, paths } = await w.begin()

  await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' })

  expect((await w.call('finish', { reason: '  Shipped in PR #82 ' })).result).toBe(
    'Marked done. This window stays attached; joining the work again reopens it.',
  )
  expect(linesOf(w, paths.log(W1)).at(-1)).toMatchObject({
    type: 'finish',
    who: 'claude',
    reason: 'Shipped in PR #82',
  })
  expect(w.state.attachment?.work).toBe(id)
  expect(w.state.board).toMatchObject({ waiting: 0, finished: { who: 'claude', by: W1 } })
  expect((await w.call('finish')).deny).toBe('This piece of work is already marked done.')
})

test('join reopens a finished work, saying who had marked it done and why', async ($, on) => {
  const w = world($, on)
  const lobby = w.elsewhere({ ...META, id: 'sr-bbbbbb', name: 'Lobby', by: W2 })
  const themes = w.elsewhere({ ...META, id: 'sr-cccccc', name: 'Themes', by: W2 })

  lobby.write({ type: 'ask', id: 'k1', wants: 'yes', yes: 'Done', title: 'Run it' }, finish('lee'))
  themes.write(finish('claude', 'Shipped'))
  await w.clock.advance(MIN)
  await $.session.start(SESSION)

  const joined = String((await w.call('join', { work: 'sr-bbbbbb' })).result)

  expect(joined).toMatch(
    /^Joined Lobby \(sr-bbbbbb\)\. Lee had marked it done; joining it reopened it\. Correct anything on it that is stale against what you know\. The board as it stands:\n/,
  )
  expect(linesOf(w, lobby.paths.log(W1)).map(line => line.type)).toEqual(['unfinish'])
  expect(w.state.board).toMatchObject({ waiting: 1 })
  expect(w.state.board?.finished).toBeUndefined()

  expect(String((await w.call('join', { work: 'sr-cccccc' })).result)).toContain(
    'Claude had marked it done (Shipped); joining it reopened it.',
  )
})

test('a line posted to a finished work leaves it done: only a join reopens it, once', async ($, on) => {
  const w = world($, on)
  const lobby = w.elsewhere({ ...META, id: 'sr-bbbbbb', name: 'Lobby', by: W2 })

  w.put(
    lobby.paths.log('cli'),
    file([T0, finish('lee')], [T0 + MIN, { type: 'note', id: 'n1', text: 'From a script' }]),
  )
  await w.clock.advance(2 * MIN)
  await $.session.start(SESSION)
  await w.call('join', { work: 'sr-bbbbbb' })
  await w.call('join', { work: 'sr-bbbbbb' })

  expect(linesOf(w, lobby.paths.log(W1)).map(line => line.type)).toEqual(['unfinish'])
})

test("board reads back the work's open items with their ids", async ($, on) => {
  const w = world($, on)
  const { id } = await w.begin()
  const ask = postedId(
    await w.call('ask', { wants: 'yes', yes: 'Approve', title: 'Review round 1' }),
  )
  const read = String((await w.call('board')).result)

  expect(read).toContain(`sitrep board: Dashboard redesign (${id})`)
  expect(read).toContain(`- ${ask} wants a yes (Approve), waiting on Lee: Review round 1`)
})

test('every tool but start and join refuses while no work is attached, saying to start or join one', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  for (const tool of TOOLS.slice(2)) {
    expect(
      (await w.call(tool, { item: 'k1', text: 'x', title: 'x', wants: 'yes', yes: 'Done' })).deny,
      tool,
    ).toBe('No piece of work is attached to this window: start one, or join one by its id, first.')
  }
})

test("a subagent's call is refused, telling it to put the item in its report", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const before = new Map(w.files)

  for (const tool of TOOLS) {
    const answer = await w.call(
      tool,
      { ...DASHBOARD, wants: 'yes', yes: 'Done', title: 'Run it' },
      'a1',
    )

    expect(answer.deny, tool).toContain('Put this in your report instead')
  }

  expect(w.files).toEqual(before)
})
