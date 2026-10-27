import { expect, test, tier } from 'claude-code/testing'
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
  CLI,
  file,
  finish,
  META,
  note,
  reply,
  snooze,
  T0,
  unfinish,
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

test('a window around going stale shows within a look, though no file changed', async ($, on) => {
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

  w.elsewhere(LEDGER).write(yesAsk('k3', 'Review the ledger schema'), snooze('k3', wakes))
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

  ledger.write(yesAsk('k3', 'Review the ledger schema'), snooze('k3', wakes))
  w.put(ledger.paths.letters(CLI), file([T0 + 1, reply('r1', 'k3', 'yes')]))
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

test("a look lists each project's folder once for all its sessions, and a rename there shows within it", async ($, on) => {
  const w = world($, on)
  const ids = ['sr-0rders', 'sr-2staff', 'sr-3teams']
  const goosemates = projectPaths(ROOT, ELSEWHERE.key).dir
  const projectListings = () => w.listed.filter(path => path === goosemates).length

  w.project(ELSEWHERE.key, { name: 'Goosemates', created: T0, by: W3 })

  for (const id of ids) {
    w.elsewhere(orders(id), ELSEWHERE.key).write(yesAsk('k1', 'Review the standing orders'))
  }

  await w.begin()

  const before = projectListings()

  await w.clock.advance(AROUND_MS)
  expect(projectListings() - before).toBe(1)

  w.project(ELSEWHERE.key, { name: 'Goose Mates', created: T0, by: W3 })
  await w.clock.advance(AROUND_MS)
  expect(ids.map(id => around(w, id)?.project)).toEqual(ids.map(() => 'Goose Mates'))
})
