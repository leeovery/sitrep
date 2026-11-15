import { expect, test, tier } from './kit'
import {
  CURRENT_MS,
  OFF_BOARD_MS,
  projectPaths,
  STALE_MS,
  type SessionMeta,
  type SessionPaths,
} from '../core'
import { AROUND_MS } from '../hooks/around'
import {
  beat,
  finish,
  META,
  note,
  reopen,
  resolve,
  SLOW,
  snoozeSession,
  T0,
  unfinish,
  W1,
  W2,
  W3,
  yesAsk,
} from './support'
import { ELSEWHERE, ROOT, toProject, world } from './world'

tier('user')

type World = ReturnType<typeof world>

const LEDGER: SessionMeta = { ...META, id: 'sr-1edger', name: 'Request ledger', by: W2 }

/** A session of Goosemates', with no window on it. */
const orders = (id: string): SessionMeta => ({
  ...META,
  id,
  name: 'Standing orders',
  project: 'goosemates',
  by: W3,
})

/** A session around as the last look put it in `$.state`; undefined where it is not current. */
const around = (w: World, id: string) =>
  w.state.projects?.flatMap(project => project.sessions).find(session => session.id === id)

/** How many times the mod has listed a session's folder. */
const listings = (w: World, paths: SessionPaths) =>
  w.listed.filter(path => path === paths.dir).length

test('a line posted in a session around shows within a look', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  await w.begin()
  expect(around(w, LEDGER.id)?.asks.map(ask => ask.id)).toEqual(['k3'])

  ledger.write(yesAsk('k4', 'Run the ledger migration'))
  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)?.asks.map(ask => ask.id)).toEqual(['k3', 'k4'])
})

test('a window around going stale shows within a look, though no file changed', SLOW, async ($, on) => {
  const w = world($, on)

  w.elsewhere(LEDGER).beat()
  await w.begin()
  await w.clock.advance(STALE_MS)
  expect(around(w, LEDGER.id)?.isOpen).toBe(true)

  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)?.isOpen).toBe(false)
})

test('a session around ageing out of the views goes within a look, though no file changed', async ($, on) => {
  const w = world($, on, { now: T0 + CURRENT_MS - AROUND_MS })

  w.elsewhere(LEDGER)
  await w.begin()
  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)).toBeDefined()

  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)).toBeUndefined()
})

test('a snooze running out in a session around, no window on it, shows within a look', async ($, on) => {
  const w = world($, on)
  const wakes = T0 + 2 * AROUND_MS

  w.elsewhere(LEDGER).write(yesAsk('k3', 'Review the ledger schema'), snoozeSession(wakes, 'k3'))
  await w.begin()
  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)).toMatchObject({ waiting: 0, snoozed: 1 })

  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)).toMatchObject({ waiting: 1, snoozed: 0 })
})

test("a snooze running out over an ask around that Lee's reply is on its way to reaches the ask within a look, though the board's counts do not move", async ($, on) => {
  const w = world($, on)
  const wakes = T0 + 2 * AROUND_MS
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'), snoozeSession(wakes, 'k3'))
  w.put(
    ledger.paths.heartbeat(W3),
    beat(W3, {
      attachedAt: T0,
      seenAt: T0,
      sending: [{ at: T0 + 1, replies: [{ id: 'r1', item: 'k3', verdict: 'yes' }] }],
    }),
  )
  await w.begin()
  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)?.asks[0]).toMatchObject({ snoozedUntil: wakes })

  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)?.asks[0]).not.toHaveProperty('snoozedUntil')
  expect(around(w, LEDGER.id)?.asks[0]?.wokeAt).toBe(wakes)
  expect(around(w, LEDGER.id)).toMatchObject({ waiting: 0, snoozed: 0 })
})

test('a session around off the board is read only at a whole look, every OFF_BOARD_MS: a post that brings it back shows at the next one', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(note('n1', 'Drew the schema'), finish('claude'))
  await w.begin()

  const read = listings(w, ledger.paths)

  await w.clock.advance(AROUND_MS)
  expect(listings(w, ledger.paths), 'a look that is not whole lists no folder of it').toBe(read)

  await w.clock.advance(AROUND_MS)
  expect(OFF_BOARD_MS).toBe(2 * AROUND_MS)
  expect(listings(w, ledger.paths), 'the whole look').toBeGreaterThan(read)

  ledger.write(unfinish(), yesAsk('k3', 'Review the ledger schema'))
  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id), 'not read since').toBeUndefined()

  await w.clock.advance(AROUND_MS)
  expect(around(w, LEDGER.id)?.asks.map(ask => ask.id)).toEqual(['k3'])
})

test('a session off the board that the board looks at is read at every look', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  ledger.write(finish('claude'))
  await w.clock.advance(OFF_BOARD_MS)
  expect(w.state.others?.[0]?.board.finished).toBeDefined()

  const read = listings(w, ledger.paths)

  ledger.write(unfinish())
  await w.clock.advance(AROUND_MS)
  expect(listings(w, ledger.paths), 'a look that is not whole').toBeGreaterThan(read)
  expect(w.state.others?.[0]?.board.finished).toBeUndefined()
})

test("a look lists each project's folder once for all its sessions, and each session's own on the board, though the look is not whole; a rename there shows within it", async ($, on) => {
  const w = world($, on)
  const ids = ['sr-0rders', 'sr-2staff', 'sr-3teams']
  const goosemates = projectPaths(ROOT, ELSEWHERE.key).dir
  const projectListings = () => w.listed.filter(path => path === goosemates).length

  w.project(ELSEWHERE.key, { name: 'Goosemates', created: T0, by: W3 })

  const sessions = ids.map(id => w.elsewhere(orders(id), ELSEWHERE.key))

  for (const session of sessions) {
    session.write(yesAsk('k1', 'Review the standing orders'))
  }

  await w.begin()

  const before = projectListings()
  const sessionsBefore = sessions.map(session => listings(w, session.paths))

  await w.clock.advance(AROUND_MS)
  expect(projectListings() - before).toBe(1)
  expect(
    sessions.map((session, i) => listings(w, session.paths) - (sessionsBefore[i] ?? 0)),
    'each on the board, at a look that is not whole',
  ).toEqual(ids.map(() => 1))

  w.project(ELSEWHERE.key, { name: 'Goose Mates', created: T0, by: W3 })
  await w.clock.advance(AROUND_MS)
  expect(ids.map(id => around(w, id)?.project)).toEqual(ids.map(() => 'Goose Mates'))
})

test('a look that reads the clock a few ms late, and the next two on time, leave a whole look every second look', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)
  const late = T0 + OFF_BOARD_MS

  // Every read of the attachment as the look at `late` fires answers 8 ms on,
  // so that look reads the clock then.
  on('state.get', { plugin: 'sitrep', key: 'attachment' }, async ($, e, next) => {
    if (w.clock.now() === late) {
      await w.clock.sleep(8)
    }

    return next(e)
  })
  ledger.write(note('n1', 'Drew the schema'), finish('claude'))
  await w.begin()
  await w.clock.advance(AROUND_MS)

  const before = listings(w, ledger.paths)

  await w.clock.advance(AROUND_MS + 8)

  const whole = listings(w, ledger.paths)

  expect(whole, 'whole, read 8 ms late').toBeGreaterThan(before)

  await w.clock.advance(AROUND_MS - 8)
  expect(listings(w, ledger.paths), 'not whole').toBe(whole)

  await w.clock.advance(AROUND_MS)
  expect(listings(w, ledger.paths), 'whole, though 8 ms short of OFF_BOARD_MS').toBeGreaterThan(
    whole,
  )
})

test('a send and the first message read a session off the board afresh, at a look that is not whole', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))
  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  await ui.press({ key: `yes:${LEDGER.id}:k3` })
  ledger.write(resolve('k3'), finish('claude'))
  await w.clock.advance(AROUND_MS)
  expect(w.state.others?.[0]?.board.finished, 'off the board as last read').toBeDefined()

  ledger.write(unfinish(), reopen('k3'))
  await ui.press({ key: 'send' })
  expect(w.files.has(ledger.paths.letters(W1)), 'the send found it open').toBe(true)

  ledger.write(finish('claude'))
  await w.clock.advance(AROUND_MS)
  ledger.write(unfinish())

  const [listing] = (await $.prompt.context({ blocks: [] })).blocks

  expect(listing?.text, 'the first message found it open').toContain(LEDGER.id)
})
