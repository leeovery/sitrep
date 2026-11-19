import type { Args } from 'claude-code'
import { expect, test, tier } from './kit'
import type { Body, SessionMeta } from '../core'
import { C } from '../hooks/look'
import { EVERY_PROJECT, projectPlace } from '../hooks/places'
import { glyphColors, rowsOf } from './drawn'
import { ELSEWHERE, HELD, heldItem, LEDGER, MIN, PROJECT, T0, W2, type Asked } from './data'
import { askOf, park, resolve, status, yesAsk, type Line } from './lines'
import { pane, sceneFrom, type Desk, type Drawn } from './render'
import { DOCKED, postedId, world, type World } from './world'

tier('user')

/** The board's rows, as drawn. */
const boardRows = async (ui: Drawn) => rowsOf(await ui.find({ type: 'Box' }))

/** The rows of the board drawn from a desk, the board looking at a place, home unless told. */
const rowsAt = (desk: Desk, place: Desk['pane'] = {}) =>
  boardRows(pane(sceneFrom({ ...desk, pane: place })))

/** The rows from the first that matches `first` up to the blank row after it, or the end. */
const runFrom = (rows: readonly string[], first: RegExp) => {
  const start = rows.findIndex(row => first.test(row))
  const end = rows.findIndex((row, i) => i > start && row === '')

  return start < 0 ? [] : rows.slice(start, end < 0 ? undefined : end)
}

/** The rows a section lists under its heading, up to the blank row that ends it. */
const listedUnder = (rows: readonly string[], heading: string) =>
  runFrom(rows, new RegExp(`^ ${heading} ─`)).slice(1)

/** Claude posts each with `tool`, one a minute: their ids. */
async function posted(w: World, tool: string, ...each: Args[]) {
  const ids: string[] = []

  for (const args of each) {
    ids.push(postedId(await w.call(tool, args)))
    await w.clock.advance(MIN)
  }

  return ids
}

/** Lines Claude writes one a minute, the first at T0. */
const minutely = (...bodies: Body[]) => bodies.map((body, i): Line => [T0 + i * MIN, body])

/** Asks for Lee's approval, each saying where to look. */
const reviews = (...titles: string[]) =>
  titles.map(
    title =>
      ({
        wants: 'yes',
        yes: 'Approve',
        title,
        where: `In Paper: page ${title.slice(-7)}`,
      }) satisfies Asked,
  )

/** The reviews as the ask tool writes them, `k1` onwards. */
const reviewLines = (...titles: string[]) =>
  reviews(...titles).map((review, i) => askOf(`k${i + 1}`, review))

const CHANGES = [
  status(['Merging PR #81']),
  status(['Merging PR #82']),
  status(['Drawing the schema']),
]

const PARKED = [
  park('p1', 'A priority badge'),
  park('p2', 'Thumbnails in the picker'),
  park('p3', 'Export the ledger as CSV'),
]

test("a session lists its status's history and its closed asks with no blank row between their entries", async () => {
  const rows = await rowsAt(
    {
      lines: minutely(
        ...CHANGES,
        ...reviewLines('Review round 1', 'Review round 2'),
        resolve('k1', 'Done in the chat'),
        resolve('k2', 'Done in the chat'),
      ),
      now: T0 + 7 * MIN,
    },
    { shown: { [`history:${HELD.id}`]: 'latest' } },
  )

  expect(listedUnder(rows, 'STATUS')).toEqual([
    ' • Drawing the schema',
    ' hide history',
    ' • now drawing the schema 5m',
    ' • now merging PR #82 6m',
    ' • now merging PR #81 7m',
  ])
  expect(listedUnder(rows, 'RESOLVED')).toEqual([' ✓ Review round 2 1m', ' ✓ Review round 1 2m'])
})

test("PARKED lists every item parked in the project with no blank row between them: in a session, its own first, unnamed, then the others', each naming its session; in the project, the oldest first, each naming its session; each counting them all", async () => {
  const desk: Desk = {
    lines: minutely(...PARKED),
    around: [{ meta: LEDGER, lines: [[T0 - MIN, park('p1', 'Archive old invoices')]], seenAt: T0 }],
    now: T0 + 3 * MIN,
  }
  const session = await rowsAt(desk)
  const project = await rowsAt(desk, { place: projectPlace(PROJECT.key) })

  expect(listedUnder(session, 'PARKED')).toEqual([
    ' ● A priority badge 3m',
    ' ● Thumbnails in the picker 2m',
    ' ● Export the ledger as CSV 1m',
    ' from other sessions',
    ' ● Invoice ledger: Archive old invoices 4m',
  ])
  expect(listedUnder(project, 'PARKED')).toEqual([
    ' ● Invoice ledger: Archive old invoices 4m',
    ' ● Help desk redesign: A priority badge 3m',
    ' ● Help desk redesign: Thumbnails in the picker 2m',
    ' ● Help desk redesign: Export the ledger as CSV 1m',
  ])

  for (const rows of [session, project]) {
    expect(rows.find(row => row.startsWith(' PARKED'))).toMatch(/ 4 to come back to$/)
  }
})

/** The colours of the marks in the blocks keyed `prefix`, in the order drawn. */
const marksIn = async (ui: Drawn, prefix: string) =>
  (await ui.findAll({ type: 'Box' }))
    .filter(block => block.key?.startsWith(`block:${prefix}`))
    .flatMap(block => glyphColors(block, '●'))

test("an ask's ● is orange and a parked item's purple, in a session and in its project, another session's items too", async () => {
  const desk: Desk = {
    lines: minutely(...reviewLines('Review round 1', 'Review round 2'), ...PARKED),
    around: [{ meta: LEDGER, lines: [[T0 - MIN, park('p9', 'Archive old invoices')]], seenAt: T0 }],
    now: T0 + 5 * MIN,
  }
  const session = pane(sceneFrom(desk))
  const project = pane(sceneFrom({ ...desk, pane: { place: projectPlace(PROJECT.key) } }))

  for (const [view, ui] of [['session', session], ['project', project]] as const) {
    expect(await marksIn(ui, 'ask:'), `${view}: ASKS`).toEqual([C.ask, C.ask])
    expect(await marksIn(ui, 'parked:'), `${view}: PARKED`).toEqual(Array(4).fill(C.parked))
  }
})

test("in a session's PARKED, a faint `from other sessions` heads the items other sessions parked, with no blank row, even where it parked none itself; at 60 columns and 40", async () => {
  const around: Desk['around'] = [
    { meta: LEDGER, lines: [[T0 - MIN, park('p1', 'Archive old invoices')]], seenAt: T0 },
  ]
  const parkedRows = async (desk: Desk, cells: number) => {
    const ui = pane(sceneFrom({ ...desk, around, now: T0 + 3 * MIN }), {
      ...DOCKED,
      bodyColumns: cells + 2,
    })

    return listedUnder(rowsOf(await ui.find({ type: 'Box' }), cells), 'PARKED').map(row =>
      row.trimEnd(),
    )
  }
  const mine: Desk = { lines: minutely(park('p1', 'A priority badge')) }

  expect(await parkedRows(mine, 60)).toEqual([
    ' ● A priority badge                                      3m',
    ' from other sessions',
    ' ● Invoice ledger: Archive old invoices                  4m',
  ])
  expect(await parkedRows(mine, 40)).toEqual([
    ' ● A priority badge                  3m',
    ' from other sessions',
    ' ● Invoice ledger: Archive old inv…  4m',
  ])
  expect(await parkedRows({}, 40), 'none of its own').toEqual([
    ' from other sessions',
    ' ● Invoice ledger: Archive old inv…  4m',
  ])

  const label = await pane(sceneFrom({ ...mine, around, now: T0 + 3 * MIN })).find({
    type: 'Text',
    text: 'from other sessions',
  })

  expect(label?.props.color).toBe(C.faint)
})

test('ASKS lists its asks as rows with no blank row between them, each its mark, title and age, no where', async () => {
  const rows = await rowsAt({
    lines: minutely(...reviewLines('Review round 1', 'Review round 2', 'Review round 3')),
    now: T0 + 3 * MIN,
  })
  const at = rows.findIndex(row => row.startsWith(' ASKS'))

  expect(rows.slice(at + 1, at + 5)).toEqual([
    ' ● Review round 3 1m',
    ' ● Review round 2 2m',
    ' ● Review round 1 3m',
    '',
  ])
})

test('a reply waiting on an ask not opened, or on its way, still hangs from it, as a pick-up from a parked row', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const [older = '', newer = ''] = await posted(
    w,
    'ask',
    ...reviews('Review round 1', 'Review round 2'),
  )
  const ui = await w.pane()
  const asksListed = async () => {
    const rows = await boardRows(ui)
    const at = rows.findIndex(row => row.startsWith(' ASKS'))

    return rows.slice(at + 1, at + 5)
  }

  await ui.press({ key: `yes:${w.item(newer)}` })
  await ui.press({ key: `pick:${w.item(older)}` })
  await ui.press({ key: `ignore:${w.item(older)}` })
  await ui.press({ key: `pick:${w.item(older)}` })

  expect(await asksListed(), 'waiting to be sent').toEqual([
    ' ● Review round 2 1m',
    ' └ → Approve · not sent yet ↺ undo ✎ comment',
    ' ● Review round 1 2m',
    ' └ ignored · not sent yet ↺ undo',
  ])

  const turn = w.holdPrompts()
  const pressed = ui.press({ key: 'send' })

  await turn.arrived
  expect(await asksListed(), 'on its way').toEqual([
    ' ● Review round 2 1m',
    ' └ → Approve · on its way',
    ' ● Review round 1 2m',
    ' └ ignored · on its way',
  ])

  turn.end()
  await pressed
})

test('an opened ask has a blank row after its buttons and hint, so the next ask does not run into them', async () => {
  const rows = await rowsAt(
    { lines: minutely(...reviewLines('Review round 1', 'Review round 2')), now: T0 + 2 * MIN },
    { selected: heldItem('k2') },
  )
  const at = (title: string) => rows.findIndex(row => row.includes(title))

  expect(rows.slice(at('Review round 2'), at('Review round 1') + 1)).toEqual([
    ' ● Review round 2 1m',
    ' └ In Paper: page round 2',
    '   [ ✓ Approve ] [ ✎ comment ] [ ✕ ignore ] [ snooze ]',
    "   Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it.",
    '',
    ' ● Review round 1 2m',
  ])
})

/** A session open in another window, in another project. */
const SHIFTS: SessionMeta = {
  id: 'sr-0sh1ft',
  name: 'Shift schedules',
  summary: 'Shift schedules, area by area',
  project: ELSEWHERE.key,
  root: '/Users/me/Code/contoso',
  created: T0,
  by: W2,
}

test('All projects keeps a blank row between its projects', async () => {
  const rows = await rowsAt(
    {
      around: [
        {
          meta: SHIFTS,
          project: ELSEWHERE.key,
          lines: [[T0, yesAsk('k5', 'Review the shift schedules')]],
          seenAt: T0,
        },
      ],
    },
    { place: EVERY_PROJECT },
  )
  const contoso = rows.findIndex(row => /^ Contoso/.test(row))

  expect(contoso).toBeGreaterThan(0)
  expect(rows[contoso - 1], 'the row above the second project').toBe('')
  expect(rows[contoso - 2]).toMatch(/└ Help desk redesign/)
})
