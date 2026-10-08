import { expect, test, tier } from 'claude-code/testing'
import { parseEntries, parseMeta, parsePresence, projectOf, workPaths } from '../core'
import { META, W1 } from './support'
import {
  DASHBOARD,
  ELSEWHERE,
  LOOSE,
  PROJECT,
  REPO,
  ROOT,
  SESSION,
  startedId,
  postedId,
  world,
  WORKTREE,
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
  'board',
]

/** The lines a file holds. */
const linesOf = (w: ReturnType<typeof world>, path: string) => parseEntries(w.text(path))

test('a session start registers every tool, each schema loaded up front', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  expect(w.registered).toEqual(TOOLS.map(name => ({ name, isDeferred: false })))
})

test("start files the work under the session's project, attaches the window and says to record the id", async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  const answer = await w.call('start', DASHBOARD)
  const id = startedId(answer)
  const paths = workPaths(ROOT, PROJECT.key, id)

  expect(answer.result).toBe(
    `Started Dashboard redesign as ${id}. Record ${id} wherever this project tracks this work, so a later window can join it.`,
  )
  expect(parseMeta(w.text(paths.meta))).toEqual({
    id,
    ...DASHBOARD,
    project: 'switchboard',
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

test("a worktree's work is filed under its repository's project; outside git, under the folder's", async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)
  w.become({ cwd: WORKTREE })

  const inWorktree = startedId(await w.call('start', DASHBOARD))

  expect(parseMeta(w.text(workPaths(ROOT, PROJECT.key, inWorktree).meta))?.root).toBe(WORKTREE)

  w.become({ cwd: LOOSE })

  const loose = startedId(await w.call('start', DASHBOARD))

  expect(w.files.has(workPaths(ROOT, projectOf(LOOSE).key, loose).meta)).toBe(true)
})

test('start refuses a work with no name or no summary, and writes nothing', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  expect((await w.call('start', { name: 'Dashboard' })).deny).toBe(
    'A piece of work needs a summary: one line on what it is for.',
  )
  expect((await w.call('start', { summary: 'Area by area' })).deny).toContain('needs a name')
  expect(w.files.size).toBe(0)
})

test('join attaches to a work by its id, looking in this project first, then in every other', async ($, on) => {
  const w = world($, on)
  const here = { ...META, id: 'sr-aaaaaa', by: 'cli' }
  const there = { ...META, id: 'sr-bbbbbb', name: 'Lobby', by: 'cli' }

  w.seed(here)
  w.seed(there, ELSEWHERE.key)
  await $.session.start(SESSION)

  const joined = await w.call('join', { work: 'sr-bbbbbb' })

  expect(String(joined.result)).toMatch(/^Joined Lobby \(sr-bbbbbb\)\. The board as it stands:\n/)
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
    'There is no piece of work sr-zzzzzz on the board, in this project or any other.',
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
  expect(w.state.board?.status).toMatchObject({ ...DASHBOARD, now: ['Drawing Usage, round 2'] })
  expect(w.state.board?.log[0]?.text).toBe('Status: now drawing Usage, round 2')
  expect(linesOf(w, paths.log(W1)).map(line => line.type)).toEqual(['status'])
  expect((await w.call('status', {})).deny).toContain('at least one of')
})

test('ask posts an ask with a fresh id; a decide ask with too few options is refused', async ($, on) => {
  const w = world($, on)
  const { paths } = await w.begin()
  const options = ['Keep it', 'Drop it']
  const answer = await w.call('ask', { kind: 'decide', title: 'Keep the band?', options })
  const id = postedId(answer)

  expect(answer.result).toBe(`Posted ask ${id}.`)
  expect(w.state.board?.asks).toMatchObject([{ id, kind: 'decide', options, state: 'waiting' }])
  expect(w.state.board?.waiting).toBe(1)
  expect(linesOf(w, paths.log(W1)).at(-1)).toMatchObject({ type: 'ask', id, seq: 1 })
  expect((await w.call('ask', { kind: 'decide', title: 'Keep it?' })).deny).toBe(
    'A decide ask needs at least 2 options.',
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

  const id = postedId(await w.call('ask', { kind: 'review', title: 'Review round 1' }))

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

test("board reads back the work's open items with their ids", async ($, on) => {
  const w = world($, on)
  const { id } = await w.begin()
  const ask = postedId(await w.call('ask', { kind: 'review', title: 'Review round 1' }))
  const read = String((await w.call('board')).result)

  expect(read).toContain(`sitrep board: Dashboard redesign (${id})`)
  expect(read).toContain(`- ${ask} review, waiting on Lee: Review round 1`)
})

test('every tool but start and join refuses while no work is attached, saying to start or join one', async ($, on) => {
  const w = world($, on)

  await $.session.start(SESSION)

  for (const tool of TOOLS.slice(2)) {
    expect((await w.call(tool, { item: 'k1', text: 'x', title: 'x', kind: 'do' })).deny, tool).toBe(
      'No piece of work is attached to this window: start one, or join one by its id, first.',
    )
  }
})

test("a subagent's call is refused, telling it to put the item in its report", async ($, on) => {
  const w = world($, on)

  await w.begin()

  const before = new Map(w.files)

  for (const tool of TOOLS) {
    const answer = await w.call(tool, { ...DASHBOARD, kind: 'do', title: 'Run it' }, 'a1')

    expect(answer.deny, tool).toContain('Put this in your report instead')
  }

  expect(w.files).toEqual(before)
})
