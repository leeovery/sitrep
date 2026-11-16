import type { Args } from 'claude-code'
import { expect, test, tier } from './kit'
import type { SessionMeta } from '../core'
import { rowsOf } from './drawn'
import { ELSEWHERE, MIN, T0, W2 } from './data'
import { yesAsk } from './lines'
import { postedId, toProject, world, type Board, type World } from './world'

tier('user')


/** The board's rows, as drawn. */
const boardRows = async (ui: Board) => rowsOf(await ui.find({ type: 'Box' }))

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

const notes = (...texts: string[]) => texts.map(text => ({ text }))

/** Asks for Lee's approval, each saying where to look. */
const reviews = (...titles: string[]) =>
  titles.map(title => ({
    wants: 'yes',
    yes: 'Approve',
    title,
    where: `In Paper: page ${title.slice(-7)}`,
  }))

const NOTES = notes('PR #81 merged', 'PR #82 merged', 'The schema is drawn')

const PARKED = ['A priority badge', 'Thumbnails in the picker', 'Export the ledger as CSV'].map(
  title => ({ title }),
)

test(
  'a session lists its notes and its closed asks with no blank row between their entries',
  async ($, on) => {
    const w = world($, on)

    await w.begin()
    await posted(w, 'note', ...NOTES)

    for (const id of await posted(w, 'ask', ...reviews('Review round 1', 'Review round 2'))) {
      await w.call('resolve', { item: id, reason: 'Done in the chat' })
      await w.clock.advance(MIN)
    }

    const rows = await boardRows(await w.opened())

    expect(listedUnder(rows, 'NOTES')).toEqual([
      ' • The schema is drawn 5m',
      ' • PR #82 merged 6m',
      ' • PR #81 merged 7m',
    ])
    expect(listedUnder(rows, 'RESOLVED')).toEqual([' ✓ Review round 2 1m', ' ✓ Review round 1 2m'])
  },
)

test('PARKED lists its items with no blank row between them, in a session and in its project, each naming its session there', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await posted(w, 'park', ...PARKED)

  const ui = await w.pane()

  expect(listedUnder(await boardRows(ui), 'PARKED')).toEqual([
    ' ◇ A priority badge 3m',
    ' ◇ Thumbnails in the picker 2m',
    ' ◇ Export the ledger as CSV 1m',
  ])

  await toProject(ui)
  expect(listedUnder(await boardRows(ui), 'PARKED')).toEqual([
    ' ◇ Help desk redesign: A priority badge 3m',
    ' ◇ Help desk redesign: Thumbnails in the picker 2m',
    ' ◇ Help desk redesign: Export the ledger as CSV 1m',
  ])
})

test('the project view lists its notes with no blank row between the lines, each naming its session', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await posted(w, 'note', ...NOTES)

  const ui = await w.pane()

  await toProject(ui)
  expect(listedUnder(await boardRows(ui), 'NOTES')).toEqual([
    ' • Help desk redesign: The schema is drawn 1m',
    ' • Help desk redesign: PR #82 merged 2m',
    ' • Help desk redesign: PR #81 merged 3m',
  ])
})

test('ASKS lists its asks as rows with no blank row between them, each its mark, title and age, no where', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const [, , newest = ''] = await posted(
    w,
    'ask',
    ...reviews('Review round 1', 'Review round 2', 'Review round 3'),
  )
  const ui = await w.pane()

  await ui.press({ key: `pick:${w.item(newest)}` })

  const rows = await boardRows(ui)
  const at = rows.findIndex(row => row.startsWith(' ASKS'))

  expect(rows.slice(at + 1, at + 5)).toEqual([
    ' ◆ Review round 3 1m',
    ' ◆ Review round 2 2m',
    ' ◆ Review round 1 3m',
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
    ' ◆ Review round 2 1m',
    ' └ → Approve · not sent yet ↺ undo ✎ comment',
    ' ◆ Review round 1 2m',
    ' └ ignored · not sent yet ↺ undo',
  ])

  const turn = w.holdPrompts()
  const pressed = ui.press({ key: 'send' })

  await turn.arrived
  expect(await asksListed(), 'on its way').toEqual([
    ' ◆ Review round 2 1m',
    ' └ → Approve · on its way',
    ' ◆ Review round 1 2m',
    ' └ ignored · on its way',
  ])

  turn.end()
  await pressed
})

test('an opened ask has a blank row after its buttons and hint, so the next ask does not run into them', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await posted(w, 'ask', ...reviews('Review round 1', 'Review round 2'))

  const rows = await boardRows(await w.pane())
  const at = (title: string) => rows.findIndex(row => row.includes(title))

  expect(rows.slice(at('Review round 2'), at('Review round 1') + 1)).toEqual([
    ' ◆ Review round 2 1m',
    ' └ In Paper: page round 2',
    '   [ ✓ Approve ] [ ✎ comment ] [ ✕ ignore ] [ snooze ]',
    "   Your reply waits in Ready to send. Ignore tells Claude you've seen it and won't act on it.",
    '',
    ' ◆ Review round 1 2m',
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

test('All projects keeps a blank row between its projects', async ($, on) => {
  const w = world($, on)
  const shifts = w.elsewhere(SHIFTS, ELSEWHERE.key)

  shifts.write(yesAsk('k5', 'Review the shift schedules'))
  shifts.beat()
  await w.begin()

  const ui = await w.opened()

  await ui.press({ key: 'tab:all' })

  const rows = await boardRows(ui)
  const contoso = rows.findIndex(row => /^ Contoso/.test(row))

  expect(contoso).toBeGreaterThan(0)
  expect(rows[contoso - 1], 'the row above the second project').toBe('')
  expect(rows[contoso - 2]).toMatch(/└ Help desk redesign/)
})
