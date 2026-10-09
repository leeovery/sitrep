import type { Args } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import type { WorkMeta } from '../core'
import { rowsOf } from './drawn'
import { ask, MIN, T0, W2 } from './support'
import { ELSEWHERE, postedId, world } from './world'

tier('user')

type World = ReturnType<typeof world>

type Board = Awaited<ReturnType<World['pane']>>

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

const reviews = (...titles: string[]) => titles.map(title => ({ kind: 'review', title }))

const NOTES = notes('PR #81 merged', 'PR #82 merged', 'The schema is drawn')

const PARKED = ['A tmux indicator', 'Thumbnails in the picker', 'Export the ledger as CSV'].map(
  title => ({ title }),
)

test('a session lists its log and its closed asks with no blank row between their entries', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await posted(w, 'note', ...NOTES)

  for (const id of await posted(w, 'ask', ...reviews('Review round 1', 'Review round 2'))) {
    await w.call('resolve', { item: id, reason: 'Done in the chat' })
    await w.clock.advance(MIN)
  }

  const rows = await boardRows(await w.opened())

  expect(listedUnder(rows, 'LOG')).toEqual([
    ' • The schema is drawn 5m',
    ' • PR #82 merged 6m',
    ' • PR #81 merged 7m',
  ])
  expect(listedUnder(rows, 'DONE')).toEqual([' ✓ Review round 2 1m', ' ✓ Review round 1 2m'])
})

test('the parked view lists its items with no blank row between them, for a session and for its project', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await posted(w, 'park', ...PARKED)

  const ui = await w.pane()
  const items = async () => runFrom(await boardRows(ui), /^ ◇ /)
  const drawn = [
    ' ◇ A tmux indicator 3m',
    ' ◇ Thumbnails in the picker 2m',
    ' ◇ Export the ledger as CSV 1m',
  ]

  await ui.press({ key: 'parked' })
  expect(await items()).toEqual(drawn)

  await ui.press({ key: 'back' })
  await ui.press({ key: 'tab:project' })
  await ui.press({ key: 'parked' })
  expect(await items()).toEqual(drawn)
})

test('the project view lists its log with no blank row between the lines, each naming its session', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await posted(w, 'note', ...NOTES)

  const ui = await w.pane()

  await ui.press({ key: 'tab:project' })
  expect(listedUnder(await boardRows(ui), 'LOG')).toEqual([
    ' • Dashboard redesign: The schema is drawn 1m',
    ' • Dashboard redesign: PR #82 merged 2m',
    ' • Dashboard redesign: PR #81 merged 3m',
  ])
})

test('For you keeps a blank row between its asks', async ($, on) => {
  const w = world($, on)

  await w.begin()
  await posted(w, 'ask', ...reviews('Review round 1', 'Review round 2'))

  const rows = await boardRows(await w.pane())
  const at = (title: string) => rows.findIndex(row => row.includes(title))

  expect(at('Review round 1')).toBeGreaterThan(at('Review round 2'))
  expect(rows[at('Review round 1') - 1], 'the row above the older ask').toBe('')
})

/** A work open in another window, in another project. */
const ORDERS: WorkMeta = {
  id: 'sr-0rders',
  name: 'Standing orders',
  summary: 'Standing orders, area by area',
  project: ELSEWHERE.key,
  root: '/Users/lee/Code/goosemates',
  created: T0,
  by: W2,
}

test('All projects keeps a blank row between its projects', async ($, on) => {
  const w = world($, on)
  const orders = w.elsewhere(ORDERS, ELSEWHERE.key)

  orders.write(ask('k5', 'review', 'Review the standing orders'))
  orders.beat()
  await w.begin()

  const ui = await w.opened()

  await ui.press({ key: 'tab:all' })

  const rows = await boardRows(ui)
  const goosemates = rows.findIndex(row => /^ Goosemates/.test(row))

  expect(goosemates).toBeGreaterThan(0)
  expect(rows[goosemates - 1], 'the row above the second project').toBe('')
  expect(rows[goosemates - 2]).toMatch(/└ Dashboard redesign/)
})
