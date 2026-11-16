import { expect, test, tier, type Engine } from './kit'
import { CURRENT_MS, parseEntries, parsePresence, startText, type SessionMeta } from '../core'
import { CLI, file, finish, MIN, note, reply, T0, W1, W2, yesAsk } from './support'
import { HELP_DESK, PROJECT, CONVERSATION, PLUGIN_VERSION, REPO, WHERE, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const DAY = 24 * 60 * MIN

const NOW = T0 + DAY

const meta = (id: string, name: string, by: string, created = T0): SessionMeta => ({
  id,
  name,
  summary: `${name}, area by area`,
  project: 'northwind',
  root: '/Users/me/Code/northwind',
  created,
  by,
})

/** A session a conversation (this one, unless told) held before, letting go at `leftAt`, with a line of its own. */
const heldBefore = (w: World, session: SessionMeta, leftAt: number, writer = W1) => {
  const { paths } = w.elsewhere(session)

  w.beat(session.id, { writer, attachedAt: session.created, seenAt: leftAt, leftAt })
  w.put(paths.log(writer), file([session.created, note('n1', `Worked on ${session.name}`)]))

  return paths
}

/** The blocks the conversation's first message carries, as sitrep leaves them. */
const firstMessage = async ($: Engine) => (await $.prompt.context({ blocks: [] })).blocks

test('a conversation resumed in a new process takes up by itself the session it was last seen in', async ($, on) => {
  const w = world($, on, { now: NOW })

  heldBefore(w, meta('sr-aaaaaa', 'Lobby', W1), T0 + MIN)

  const paths = heldBefore(w, meta('sr-bbbbbb', 'Help desk redesign', W1), T0 + 5 * MIN)

  w.elsewhere(meta('sr-cccccc', 'Invoice ledger', W2)).beat()
  await $.session.start(CONVERSATION)

  expect(w.state.attachment).toEqual({
    project: PROJECT.key,
    session: 'sr-bbbbbb',
    writer: W1,
    attachedAt: NOW,
  })
  expect(parsePresence(w.text(paths.heartbeat(W1)), W1)).toEqual({
    writer: W1,
    attachedAt: NOW,
    seenAt: NOW,
    where: WHERE,
    directory: REPO,
    version: PLUGIN_VERSION,
    state: { is: 'yourTurn', since: NOW },
    loadedAt: NOW,
  })

  await w.call('note', { text: 'Drew round 2' })
  expect(parseEntries(w.text(paths.log(W1))).map(line => line.seq)).toEqual([1, 2])
})

test('a conversation seen in no session takes nothing up', async ($, on) => {
  const w = world($, on, { now: NOW })

  w.elsewhere(meta('sr-cccccc', 'Invoice ledger', W2)).beat()
  await $.session.start(CONVERSATION)

  expect(w.state.attachment ?? null).toBeNull()
  expect([...w.files.keys()].some(path => path.endsWith(`/presence/${W1}.json`))).toBe(false)
})

test('a conversation resumed in a new process never takes up by itself the session it finished, nor lists it', async ($, on) => {
  const w = world($, on, { now: NOW })
  const paths = heldBefore(w, meta('sr-bbbbbb', 'Help desk redesign', W1), T0 + 5 * MIN)

  w.put(
    paths.log(W1),
    file([T0, note('n1', 'Worked on it')], [T0 + 4 * MIN, finish('claude', 'Shipped')]),
  )
  await $.session.start(CONVERSATION)

  const [block] = await firstMessage($)

  expect(w.state.attachment ?? null).toBeNull()
  expect(block?.text).toBe(startText([]))
})

test("the conversation's first message lists the current sessions by project and id, and which this window took up", async ($, on) => {
  const w = world($, on, { now: NOW })

  heldBefore(w, meta('sr-bbbbbb', 'Help desk redesign', W1), T0 + 5 * MIN)
  w.elsewhere(meta('sr-cccccc', 'Invoice ledger', W2)).beat()
  w.elsewhere(meta('sr-dddddd', 'An old idea', W2, NOW - CURRENT_MS - DAY))
  await $.session.start(CONVERSATION)

  const [block, ...more] = await firstMessage($)

  expect(more).toEqual([])
  expect(block?.name).toBe('sitrep')
  expect(block?.text).toContain('- Northwind: sr-bbbbbb "Help desk redesign"')
  expect(block?.text).toContain('- Northwind: sr-cccccc "Invoice ledger"')
  expect(block?.text).not.toContain('sr-dddddd')
  expect(block?.text).toContain('This window already holds sr-bbbbbb (Help desk redesign)')
  expect(block?.text).toContain('join it by its id with the sitrep join tool')
})

test('the first message counts an ask whose answer from Lee is on its way as waiting on Lee: Claude has not been told the answer', async ($, on) => {
  const w = world($, on, { now: NOW })
  const ledger = w.elsewhere(meta('sr-cccccc', 'Invoice ledger', W2))

  ledger.write(yesAsk('k3', 'Review the ledger schema'), yesAsk('k4', 'Run the apply', 'Done'))
  await w.clock.advance(MIN)
  w.put(ledger.paths.letters(CLI), file([w.clock.now(), reply('r1', 'k3', 'yes')]))
  await $.session.start(CONVERSATION)

  const [block] = await firstMessage($)

  expect(block?.text).toContain('- Northwind: sr-cccccc "Invoice ledger", 2 waiting on Lee')
})

test('with no current sessions on the board, the first message carries only how to keep the board', async ($, on) => {
  const w = world($, on, { now: NOW })

  await $.session.start(CONVERSATION)
  w.elsewhere(meta('sr-dddddd', 'An old idea', W2, NOW - CURRENT_MS - DAY))

  const [block, ...more] = await firstMessage($)

  expect(more).toEqual([])
  expect(block?.name).toBe('sitrep')
  expect(block?.text).toBe(startText([]))
  expect(block?.text).not.toContain('sr-dddddd')
})

test('a session started in this conversation is listed, held, at the next conversation', async ($, on) => {
  const w = world($, on, { now: NOW })

  await w.begin()

  const [block] = await firstMessage($)

  expect(block?.text).toContain(`(${HELP_DESK.name}): post to its board as you go.`)
})

test('an in-process /resume takes up the session the resumed conversation was last seen in, though $.session.id() still names the last', async ($, on) => {
  const w = world($, on, { now: NOW })
  const paths = heldBefore(w, meta('sr-bbbbbb', 'Help desk redesign', W2), T0 + 5 * MIN, W2)

  await $.session.start(CONVERSATION)
  expect(w.state.attachment ?? null).toBeNull()

  await $.session.end({ reason: 'resume', sessionId: W1, resume: { id: W1 } })
  await $.classic.SessionStart({ source: 'resume', session_id: W2 })

  expect(w.state.attachment).toMatchObject({ session: 'sr-bbbbbb', writer: W2 })
  expect(parsePresence(w.text(paths.heartbeat(W2)), W2)).toMatchObject({ attachedAt: NOW })
})

test('a /clear, or any start that is not a resume, takes nothing up by its event', async ($, on) => {
  const w = world($, on, { now: NOW })

  heldBefore(w, meta('sr-bbbbbb', 'Help desk redesign', W2), T0 + 5 * MIN, W2)
  await $.session.start(CONVERSATION)
  await $.classic.SessionStart({ source: 'clear', session_id: W2 })
  await $.classic.SessionStart({ source: 'compact', session_id: W2 })

  expect(w.state.attachment ?? null).toBeNull()
})

test('a new process lists its sessions before its conversation starts: the rejoin comes first, so the listing names the session it took up', async ($, on) => {
  const w = world($, on, { now: NOW })

  heldBefore(w, meta('sr-bbbbbb', 'Help desk redesign', W1), T0 + 5 * MIN)

  const [block] = await firstMessage($)

  expect(w.state.attachment).toMatchObject({ session: 'sr-bbbbbb', writer: W1 })
  expect(block?.text).toContain('This window already holds sr-bbbbbb (Help desk redesign)')
})
