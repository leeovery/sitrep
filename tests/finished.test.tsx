import type { SitrepPane } from '../types'
import { expect, test, tier } from './kit'
import { C } from '../hooks/look'
import { itemKey } from '../hooks/places'
import { rowsOf } from './drawn'
import { DAY, ELSEWHERE, HELD, meta, PROJECT, T0, W3 } from './data'
import type { Neighbour } from './filing'
import { delivered, finish, park, reply, status, yesAsk } from './lines'
import { pane, sceneFrom, type Drawn } from './render'
import { ACROSS, DOCKED, toProject, world } from './world'

tier('user')

/** Two days on: what the sessions around wrote is a day old or more. */
const NOW = T0 + 2 * DAY

/** A session of Northwind's Claude finished a day ago, an ask and an item it parked left open. */
const SHIPPED = meta('sr-5h1pp3', 'Export to CSV', W3)

/** A session of Northwind's left with no window, not finished. */
const QUIET = meta('sr-qu1et0', 'Invoice archive', W3)

const ASK = itemKey(SHIPPED.id, 'k1')

const AROUND: readonly Neighbour[] = [
  {
    meta: SHIPPED,
    lines: [
      [T0, status(['Shipping the export'], SHIPPED)],
      [T0, yesAsk('k1', 'Ship it?', 'Ship')],
      [T0, park('p1', 'Paginate the export')],
      [NOW - DAY, finish('claude', 'Shipped')],
    ],
  },
  { meta: QUIET, lines: [[NOW - DAY, status(['Archiving last year'], QUIET)]] },
]

/** A session's view, the sessions around beside this one, the pane as given. */
const viewOf = (session: string, shown: Partial<SitrepPane> = {}, props = DOCKED) =>
  pane(
    sceneFrom({
      now: NOW,
      around: AROUND,
      pane: { place: { level: 'session', project: PROJECT.key, session }, ...shown },
    }),
    props,
  )

/** The keys of every press drawn. */
const pressKeys = async (ui: Drawn) =>
  (await ui.findAll({ type: 'Button' })).map(each => String(each.key ?? ''))

test("a finished session's view says so beside its project, and how long ago; a session only left without a window says closed", async () => {
  const context = async (session: string, name: string, cells = ACROSS) => {
    const ui = viewOf(session, {}, { ...DOCKED, bodyColumns: cells + 2 })
    const rows = rowsOf(await ui.find({ type: 'Box' }), cells)

    return rows.find(row => row.trim().startsWith(`${name} ·`))?.trim()
  }

  expect(await context(SHIPPED.id, SHIPPED.name)).toBe('Export to CSV · Northwind · finished 1d')
  expect(await context(QUIET.id, QUIET.name)).toBe('Invoice archive · Northwind · closed')
  expect(await context(SHIPPED.id, SHIPPED.name, 32), 'cut short with the aside').toBe(
    'Export to CSV · Northwind · fin…',
  )
})

test('this session, finished by Claude while this window holds it, says finished, and its asks keep their answers: a reply goes to the Claude right here', async () => {
  const ask = itemKey(HELD.id, 'k1')
  const ui = pane(
    sceneFrom({
      now: NOW,
      lines: [
        [T0, yesAsk('k1', 'Ship it?', 'Ship')],
        [NOW - DAY, finish('claude')],
      ],
      pane: { selected: ask },
    }),
  )

  expect(await ui.find({ type: 'Text', text: /finished 1d$/ })).toBeDefined()
  expect(await ui.find({ key: `yes:${ask}` })).toBeDefined()
  expect(
    await ui.find({ type: 'Text', text: "The session is finished: a reply can't reach it." }),
  ).toBeUndefined()
})

test("a finished session's open ask waits on no one: a faint mark, a dim title, no reply and no snooze opened, the heading counting it left open, and a faint line saying why", async () => {
  const ui = viewOf(SHIPPED.id, { selected: ASK })
  const keys = await pressKeys(ui)

  expect(await ui.find({ type: 'Text', text: 'nothing waiting · 1 left open' })).toBeDefined()
  expect(
    (await ui.find({ type: 'Text', text: "The session is finished: a reply can't reach it." }))
      ?.props.color,
  ).toBe(C.faint)
  expect(rowsOf(await ui.find({ key: `ask:${ASK}` }), ACROSS)[0]).toMatch(/^◆ Ship it\?/)
  expect((await ui.find({ type: 'Text', text: '◆' }))?.props.color).toBe(C.faint)
  expect((await ui.find({ key: `pick:${ASK}` }))?.props.dimColor).toBe(true)
  expect(
    keys.filter(key => /^(yes|choose|answer|comment|ignore|snooze|wake|finish)/.test(key)),
  ).toEqual([])
})

test("what still works on a finished session's view stays: its parked item picks up, and its asks, its lists and the way about move or open", async () => {
  const ui = viewOf(SHIPPED.id, { selected: itemKey(SHIPPED.id, 'p1') })

  expect(await pressKeys(ui)).toEqual([
    'tab:session',
    'tab:all',
    'up',
    `proj:${PROJECT.key}`,
    `pick:${ASK}`,
    `history:${SHIPPED.id}`,
    `ppick:${itemKey(SHIPPED.id, 'p1')}`,
    `pickup:${itemKey(SHIPPED.id, 'p1')}`,
    `comment:${itemKey(SHIPPED.id, 'p1')}`,
  ])
})

test("a session another window holds still offers its ask's reply; only a finished one's goes", async () => {
  const ui = pane(
    sceneFrom({
      now: NOW,
      around: [{ meta: QUIET, lines: [[NOW - DAY, yesAsk('k1', 'Archive it?', 'Archive')]] }],
      pane: {
        place: { level: 'session', project: PROJECT.key, session: QUIET.id },
        selected: itemKey(QUIET.id, 'k1'),
      },
    }),
  )

  expect(await ui.find({ key: `yes:${itemKey(QUIET.id, 'k1')}` })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '1 waiting' })).toBeDefined()
})

test("an ask Claude left open in a session it finished, its view opened from the project's old sessions, offers no reply to send", async ($, on) => {
  const w = world($, on)

  w.elsewhere(SHIPPED).write(
    status(['Shipping'], SHIPPED),
    yesAsk('k1', 'Ship it?', 'Ship'),
    finish('claude'),
  )
  await w.begin()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `old:project:${PROJECT.key}` })
  await ui.press({ key: `go:${SHIPPED.id}` })
  await ui.press({ key: `pick:${ASK}` })

  expect(w.state.pane?.selected).toBe(ASK)
  expect(await ui.find({ key: `yes:${ASK}` })).toBeUndefined()
  expect(await ui.find({ key: 'send' })).toBeUndefined()
})

test("a finished session's view in a project with nothing else on the board still draws what was taken off its Parked", async () => {
  const shifts = meta('sr-0sh1ft', 'Shift schedules', W3, { project: ELSEWHERE.key })
  const ui = pane(
    sceneFrom({
      now: NOW,
      around: [
        {
          meta: shifts,
          project: ELSEWHERE.key,
          lines: [
            [T0, park('p1', 'Approve the rota')],
            [T0 + 1, reply('r1', 'p1', 'pickup', { to: HELD.id })],
            [T0 + 1, delivered('r1')],
            [T0 + 2, finish('claude')],
          ],
        },
      ],
      pane: { place: { level: 'session', project: ELSEWHERE.key, session: shifts.id } },
    }),
  )

  expect((await ui.find({ key: `pickedup:project:${ELSEWHERE.key}` }))?.props.label).toBe(
    'show picked up 1',
  )
})
