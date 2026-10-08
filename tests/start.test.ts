import { expect, test, tier, type Engine } from 'claude-code/testing'
import { CURRENT_MS, parseEntries, parsePresence, startText, type WorkMeta } from '../core'
import { file, finish, MIN, note, T0, W1, W2 } from './support'
import { DASHBOARD, PROJECT, SESSION, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const DAY = 24 * 60 * MIN

const NOW = T0 + DAY

const meta = (id: string, name: string, by: string, created = T0): WorkMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created,
  by,
})

/** A work a conversation (this session, unless told) held before, letting go at `leftAt`, with a line of its own. */
const heldBefore = (w: World, work: WorkMeta, leftAt: number, writer = W1) => {
  const { paths } = w.elsewhere(work)

  w.beat(work.id, { writer, attachedAt: work.created, seenAt: leftAt, leftAt })
  w.put(paths.log(writer), file([work.created, note('n1', `Worked on ${work.name}`)]))

  return paths
}

/** The blocks the session's first message carries, as sitrep leaves them. */
const firstMessage = async ($: Engine) => (await $.prompt.context({ blocks: [] })).blocks

test('a session resumed in a new process takes up by itself the work it was last seen in', async ($, on) => {
  const w = world($, on, { now: NOW })

  heldBefore(w, meta('sr-aaaaaa', 'Lobby', W1), T0 + MIN)

  const paths = heldBefore(w, meta('sr-bbbbbb', 'Dashboard redesign', W1), T0 + 5 * MIN)

  w.elsewhere(meta('sr-cccccc', 'Request ledger', W2)).beat()
  await $.session.start(SESSION)

  expect(w.state.attachment).toEqual({
    project: PROJECT.key,
    work: 'sr-bbbbbb',
    writer: W1,
    attachedAt: NOW,
  })
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)).toEqual({
    writer: W1,
    attachedAt: NOW,
    seenAt: NOW,
  })

  await w.call('note', { text: 'Drew round 2' })
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.seq)).toEqual([1, 2])
})

test('a session seen in no work of its project takes nothing up', async ($, on) => {
  const w = world($, on, { now: NOW })

  w.elsewhere(meta('sr-cccccc', 'Request ledger', W2)).beat()
  await $.session.start(SESSION)

  expect(w.state.attachment ?? null).toBeNull()
  expect([...w.files.keys()].some(path => path.endsWith(`/presence/${W1}.json`))).toBe(false)
})

test('a session resumed in a new process never takes up by itself the work it finished, nor lists it', async ($, on) => {
  const w = world($, on, { now: NOW })
  const paths = heldBefore(w, meta('sr-bbbbbb', 'Dashboard redesign', W1), T0 + 5 * MIN)

  w.put(
    paths.log(W1),
    file([T0, note('n1', 'Worked on it')], [T0 + 4 * MIN, finish('claude', 'Shipped')]),
  )
  await $.session.start(SESSION)

  const [block] = await firstMessage($)

  expect(w.state.attachment ?? null).toBeNull()
  expect(block?.text).toBe(startText([]))
})

test("the session's first message lists the project's current works by id, and which this window took up", async ($, on) => {
  const w = world($, on, { now: NOW })

  heldBefore(w, meta('sr-bbbbbb', 'Dashboard redesign', W1), T0 + 5 * MIN)
  w.elsewhere(meta('sr-cccccc', 'Request ledger', W2)).beat()
  w.elsewhere(meta('sr-dddddd', 'An old idea', W2, NOW - CURRENT_MS - DAY))
  await $.session.start(SESSION)

  const [block, ...more] = await firstMessage($)

  expect(more).toEqual([])
  expect(block?.name).toBe('sitrep')
  expect(block?.text).toContain('- sr-bbbbbb: Dashboard redesign.')
  expect(block?.text).toContain('- sr-cccccc: Request ledger.')
  expect(block?.text).not.toContain('sr-dddddd')
  expect(block?.text).toContain('This window already holds sr-bbbbbb (Dashboard redesign)')
  expect(block?.text).toContain('join it by its id with the sitrep join tool')
})

test('with no current works in the project, the first message carries only how to keep the board', async ($, on) => {
  const w = world($, on, { now: NOW })

  await $.session.start(SESSION)
  w.elsewhere(meta('sr-dddddd', 'An old idea', W2, NOW - CURRENT_MS - DAY))

  const [block, ...more] = await firstMessage($)

  expect(more).toEqual([])
  expect(block?.name).toBe('sitrep')
  expect(block?.text).toBe(startText([]))
  expect(block?.text).not.toContain('sr-dddddd')
})

test('a work started in this session is listed, held, at the next conversation', async ($, on) => {
  const w = world($, on, { now: NOW })

  await w.begin()

  const [block] = await firstMessage($)

  expect(block?.text).toContain(`(${DASHBOARD.name}): post to its board as you go.`)
})

test('an in-process /resume takes up the work the resumed conversation was last seen in, though $.session.id() still names the last', async ($, on) => {
  const w = world($, on, { now: NOW })
  const paths = heldBefore(w, meta('sr-bbbbbb', 'Dashboard redesign', W2), T0 + 5 * MIN, W2)

  await $.session.start(SESSION)
  expect(w.state.attachment ?? null).toBeNull()

  await $.session.end({ reason: 'resume', sessionId: W1, resume: { id: W1 } })
  await $.classic.SessionStart({ source: 'resume', session_id: W2 })

  expect(w.state.attachment).toMatchObject({ work: 'sr-bbbbbb', writer: W2 })
  expect(parsePresence(w.text(paths.heartbeat(W2)), W2)).toMatchObject({ attachedAt: NOW })
})

test('a /clear, or any start that is not a resume, takes nothing up by its event', async ($, on) => {
  const w = world($, on, { now: NOW })

  heldBefore(w, meta('sr-bbbbbb', 'Dashboard redesign', W2), T0 + 5 * MIN, W2)
  await $.session.start(SESSION)
  await $.classic.SessionStart({ source: 'clear', session_id: W2 })
  await $.classic.SessionStart({ source: 'compact', session_id: W2 })

  expect(w.state.attachment ?? null).toBeNull()
})

test('a new process lists its works before its session starts: the rejoin comes first, so the listing names the work it took up', async ($, on) => {
  const w = world($, on, { now: NOW })

  heldBefore(w, meta('sr-bbbbbb', 'Dashboard redesign', W1), T0 + 5 * MIN)

  const [block] = await firstMessage($)

  expect(w.state.attachment).toMatchObject({ work: 'sr-bbbbbb', writer: W1 })
  expect(block?.text).toContain('This window already holds sr-bbbbbb (Dashboard redesign)')
})
