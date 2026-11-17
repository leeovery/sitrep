import type { SitrepPane } from '../types'
import { expect, test, tier } from './kit'
import { C } from '../hooks/look'
import { itemKey } from '../hooks/places'
import { rowsOf } from './drawn'
import { DAY, ELSEWHERE, HELD, meta, PROJECT, T0, W3 } from './data'
import type { Neighbour } from './filing'
import { delivered, finish, park, reply, status, wordsAsk, yesAsk } from './lines'
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

/** The faint line under ASKS where an ask was left open, its session finished, no reply reaching it. */
const FINISHED_LINE = "Finished: its asks can't be answered."

const AROUND: readonly Neighbour[] = [
  {
    meta: SHIPPED,
    lines: [
      [T0, status(['Shipping the export'], { ...SHIPPED, next: 'Announce it' })],
      [T0, yesAsk('k1', 'Ship it?', 'Ship')],
      [T0, park('p1', 'Paginate the export')],
      [NOW - DAY, finish('claude', 'Shipped')],
    ],
  },
  {
    meta: QUIET,
    lines: [[NOW - DAY, status(['Archiving last year'], { ...QUIET, next: 'Prune it' })]],
  },
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

  expect(await context(SHIPPED.id, SHIPPED.name)).toBe(
    'Export to CSV · Northwind · finished 1d ago',
  )
  expect(await context(QUIET.id, QUIET.name)).toBe('Invoice archive · Northwind · closed')
  expect(await context(SHIPPED.id, SHIPPED.name, 32), 'cut short with the aside').toBe(
    'Export to CSV · Northwind · fin…',
  )
})

test("a finished session's STATUS says why it was finished, where its finish says", async () => {
  const status = async (session: string) =>
    rowsOf(await viewOf(session).find({ type: 'Box' }), ACROSS).map(row => row.trim())

  expect(await status(SHIPPED.id)).toContain('✓ finished: Shipped')
  expect((await status(QUIET.id)).filter(row => row.includes('finished:'))).toEqual([])
})

test("a finished session's STATUS draws what was under way and what was next faint, so neither reads as going on; a closed one's as ever", async () => {
  const colours = async (session: string, now: string, next: string) => {
    const ui = viewOf(session)

    return [
      (await ui.find({ type: 'Text', text: now }))?.props.color,
      (await ui.find({ type: 'Text', text: `next: ${next}` }))?.props.color,
    ]
  }

  expect(await colours(SHIPPED.id, 'Shipping the export', 'Announce it')).toEqual([
    C.faint,
    C.faint,
  ])
  expect(await colours(QUIET.id, 'Archiving last year', 'Prune it')).toEqual([undefined, C.soft])
})

/** This session, Claude having finished it a day ago while this window holds it, its words ask and its yes ask open, the pane as `shown`. */
const heldFinished = (shown: Partial<SitrepPane> = {}) =>
  pane(
    sceneFrom({
      now: NOW,
      lines: [
        [T0, wordsAsk('k1', 'What name?', 'a name')],
        [T0, yesAsk('k2', 'Ship it?', 'Ship')],
        [NOW - DAY, finish('claude')],
      ],
      pane: shown,
    }),
  )

test('this session, finished by Claude while this window holds it, says finished, and its asks keep their answers and count as waiting here: a reply goes to the Claude right here', async () => {
  const ask = itemKey(HELD.id, 'k2')
  const ui = heldFinished({ selected: ask })
  const keys = await pressKeys(ui)

  expect(await ui.find({ type: 'Text', text: /finished 1d ago$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '2 waiting' }), 'as its buttons say').toBeDefined()
  expect(keys.filter(key => /^(yes|comment|ignore|snooze):/.test(key))).toEqual([
    `yes:${ask}`,
    `comment:${ask}`,
    `ignore:${ask}`,
  ])
  expect(await ui.find({ type: 'Text', text: FINISHED_LINE })).toBeUndefined()
})

test("this session, finished while this window holds it, reads finished in its project: `finished` where `closed` goes, dim, and open nowhere, in the project's view or All projects", async () => {
  const project = heldFinished({ place: { level: 'project', project: PROJECT.key } })
  const all = heldFinished({ place: { level: 'all' } })

  expect(rowsOf(await project.find({ key: `sess:${HELD.id}` }), ACROSS)[0]).toMatch(
    /^Help desk redesign ⌂ +finished · 2 waiting$/,
  )
  expect((await project.find({ key: `go:${HELD.id}` }))?.props.dimColor).toBe(true)
  expect(await project.find({ type: 'Text', text: '0 of 1 open' })).toBeDefined()
  expect(await all.find({ type: 'Text', text: '0 sessions open' })).toBeDefined()
  expect(await all.find({ key: `go:${HELD.id}` }), 'hung as open').toBeUndefined()
})

test("this session finished, nothing waiting there, says `finished` on its row's right in its project", async () => {
  const ui = pane(
    sceneFrom({
      now: NOW,
      lines: [[NOW - DAY, finish('claude')]],
      pane: { place: { level: 'project', project: PROJECT.key } },
    }),
  )

  expect(rowsOf(await ui.find({ key: `sess:${HELD.id}` }), ACROSS)[0]).toMatch(
    /^Help desk redesign ⌂ +finished$/,
  )
})

test("a finished session's open ask waits on no one: a faint mark, a dim title, no reply and no snooze opened, the heading counting it left open, and a faint line saying why", async () => {
  const ui = viewOf(SHIPPED.id, { selected: ASK })
  const keys = await pressKeys(ui)

  expect(await ui.find({ type: 'Text', text: 'nothing waiting · 1 left open' })).toBeDefined()
  expect((await ui.find({ type: 'Text', text: FINISHED_LINE }))?.props.color).toBe(C.faint)
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
