import type { SitrepQueued } from '../types'
import { expect, test, tier } from './kit'
import { CLEAR_AFTER_DROP_MS, TAKEN } from '../hooks/answering'
import { AROUND_MS } from '../hooks/around'
import { itemKey } from '../hooks/places'
import { at, entered, LIST } from './answers'
import { rowsOf } from './drawn'
import { DAY, GO, HELD, LEDGER, meta, MIN, PROJECT, T0, W1, W3 } from './data'
import { finish, yesAsk, type Line } from './lines'
import { pane, sceneFrom, type Drawn } from './render'
import { asked, toProject, world, type World } from './world'

tier('user')

/** Two days on: a finish a day old. */
const NOW = T0 + 2 * DAY

/** A session of Northwind's that another window had. */
const SHIPPED = meta('sr-5h1pp3', 'Export to CSV', W3)

/** Two asks of a session, the first to be answered before the session is finished, where it is. */
const ASKS: readonly Line[] = [
  [T0, yesAsk('k1', 'Ship it?', 'Ship')],
  [T0, yesAsk('k2', 'Tag it?', 'Tag')],
]

/** Claude finishing the session a day ago. */
const FINISHED: Line = [NOW - DAY, finish('claude')]

/** Lee's yes on the first ask of `session`, queued. */
const yesOn = (session: string): SitrepQueued => ({
  project: PROJECT.key,
  session,
  item: 'k1',
  verdict: 'yes',
})

/** The presses a reply is given by, or taken back by: an ask's, a queued reply's ✎, ↺ undo and ✕, and send. */
const REPLYING = /^(yes|choose|answer|comment|ignore|rewrite|readyrewrite|undo|unready|send$)/

const replying = async (ui: Drawn) =>
  (await ui.findAll({ type: 'Button' }))
    .map(each => String(each.key ?? ''))
    .filter(key => REPLYING.test(key))
    .sort()

/** Another session's view, the asks it holds, finished or not, and the second opened. */
const elsewhere = (isFinished: boolean) =>
  pane(
    sceneFrom({
      now: NOW,
      around: [{ meta: SHIPPED, lines: isFinished ? [...ASKS, FINISHED] : ASKS }],
      queue: [yesOn(SHIPPED.id)],
      pane: {
        place: { level: 'session', project: PROJECT.key, session: SHIPPED.id },
        selected: itemKey(SHIPPED.id, 'k2'),
      },
    }),
  )

/** This session's view, the asks it holds, finished or not, and the second opened. */
const here = (isFinished: boolean) =>
  pane(
    sceneFrom({
      now: NOW,
      lines: isFinished ? [...ASKS, FINISHED] : ASKS,
      queue: [yesOn(HELD.id)],
      pane: { selected: itemKey(HELD.id, 'k2') },
    }),
  )

/** Every press a reply to the two asks goes by, where a reply reaches them. */
const reached = (session: string) => {
  const queued = itemKey(session, 'k1')
  const open = itemKey(session, 'k2')

  return [
    `comment:${open}`,
    `ignore:${open}`,
    `readyrewrite:${queued}`,
    `rewrite:${queued}`,
    'send',
    `undo:${queued}`,
    `unready:${queued}`,
    `yes:${open}`,
  ]
}

test("every press a reply goes by is there while a reply reaches the session, finished or not where this window holds it; where another session was finished, only the queued reply's undo and ✕", async () => {
  const queued = itemKey(SHIPPED.id, 'k1')

  expect(await replying(elsewhere(false)), 'another session, not finished').toEqual(
    reached(SHIPPED.id),
  )
  expect(await replying(here(false)), 'this session, not finished').toEqual(reached(HELD.id))
  expect(await replying(here(true)), 'this session, finished').toEqual(reached(HELD.id))
  expect(await replying(elsewhere(true)), 'another session, finished').toEqual([
    `undo:${queued}`,
    `unready:${queued}`,
  ])
})

test("a reply queued to another session's ask before it was finished says it can't be sent, on its ask and in Ready to send, and goes nowhere: no send", async () => {
  const ui = elsewhere(true)
  const queued = itemKey(SHIPPED.id, 'k1')

  expect(rowsOf(await ui.find({ key: `ask:${queued}` })).at(-1)).toMatch(
    /· can't be sent: the session was finished ↺ undo$/,
  )
  expect(rowsOf(await ui.find({ key: `readyanswer:${queued}` }))).toEqual([
    "└ → Ship · can't be sent: the session was finished",
  ])
  expect(await ui.find({ key: 'send' })).toBeUndefined()
})

test('a words ask of this session, finished by Claude while this window holds it, answered with ✎ Answer: queued, and delivered in this window’s message, closing it', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, LIST)
  const ui = await w.opened()

  await w.call('finish', { reason: 'Shipped' })
  await ui.press({ key: `answer:${w.item(id)}` })
  expect(await entered(w, $, 'Ada')).toEqual({ drop: TAKEN.answer })
  expect(w.state.queue).toEqual([{ ...at(w, id), verdict: 'answer', note: 'Ada' }])

  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: 'send' })
  expect(w.prompts.map(each => each.text.split('\n')[1])).toEqual([
    `- ${LIST.title} → the command's output: “Ada”`,
  ])
  expect(w.state.board?.asks.map(each => each.state)).toEqual(['closed'])
})

test('✎ comment and ✎ edit work on an ask of this session, finished while this window holds it', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = await asked(w, GO)
  const ui = await w.opened()

  await w.call('finish', { reason: 'Shipped' })
  await ui.press({ key: `comment:${w.item(id)}` })
  expect(await entered(w, $, 'After the copy pass')).toEqual({ drop: TAKEN.comment })
  await w.clock.advance(CLEAR_AFTER_DROP_MS)
  await ui.press({ key: `rewrite:${w.item(id)}` })
  expect(w.box.text).toBe('After the copy pass')
  expect(await entered(w, $, 'After the copy pass, please')).toEqual({ drop: TAKEN.comment })
  expect(w.state.queue).toEqual([
    { ...at(w, id), verdict: 'comment', note: 'After the copy pass, please' },
  ])
})

/** The ledger asking for Lee's yes, from another window of Northwind's, the board on the project's view, Lee's yes queued on it; then Claude finishing the ledger. */
const yesThenFinished = async (w: World) => {
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k4', 'Approve the ledger schema'))
  await w.begin()
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()
  const there = w.item('k4', LEDGER.id)

  await toProject(ui)
  await ui.press({ key: `pick:${there}` })
  await ui.press({ key: `yes:${there}` })
  ledger.write(finish('claude', 'Shipped'))
  await w.clock.advance(AROUND_MS)

  return { ui, there, paths: ledger.paths }
}

test("a reply queued to another window's session before it was finished can't be sent, says why on its ask and in Ready to send, and undoes", async ($, on) => {
  const w = world($, on)
  const { ui, there } = await yesThenFinished(w)

  expect(rowsOf(await ui.find({ key: `readyanswer:${there}` }))).toEqual([
    "└ → Approve · can't be sent: the session was finished",
  ])
  expect(await ui.find({ key: 'send' })).toBeUndefined()

  await ui.press({ key: `old:project:${PROJECT.key}` })
  await ui.press({ key: `go:${LEDGER.id}` })
  expect(rowsOf(await ui.find({ key: `ask:${there}` })).at(-1)).toMatch(
    /· can't be sent: the session was finished ↺ undo$/,
  )
  await ui.press({ key: `undo:${there}` })
  expect(w.state.queue).toEqual([])
})

test("send carries this session's reply and leaves out one to another session finished since it was queued, writing nothing into its inbox", async ($, on) => {
  const w = world($, on)
  const { ui, paths } = await yesThenFinished(w)
  const id = await asked(w, GO)

  await ui.press({ key: 'tab:session' })
  await ui.press({ key: `pick:${w.item(id)}` })
  await ui.press({ key: `yes:${w.item(id)}` })
  await ui.press({ key: 'send' })

  expect(w.prompts.map(each => each.text.split('\n')[1])).toEqual([`- ${GO.title} → Go`])
  expect(w.files.has(paths.letters(W1)), 'nothing written into its inbox').toBe(false)
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: LEDGER.id, item: 'k4', verdict: 'yes' },
  ])
})
