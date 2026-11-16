import { expect, test } from './kit'
import { parseEntries, statusChange, type StatusFields } from '../core'
import { file, fold, MIN, note, status, T0, W1, W2 } from './support'

const REVIEWING = 'Waiting on your review of Orders & Invoices, round 1'
const DRAWING = 'Drawing Usage, round 2'

const BEFORE: StatusFields = {
  name: 'Dashboard redesign',
  summary: 'Redesign the dashboard, area by area in Paper',
  now: [REVIEWING],
  next: 'Usage, round 2',
}

const changed = (after: Partial<StatusFields>) => statusChange(BEFORE, { ...BEFORE, ...after })

test("a line taken on reads as the spike's: now also, with what is still there in the detail", () => {
  expect(changed({ now: [REVIEWING, DRAWING] })).toEqual({
    text: 'Status: now also drawing Usage, round 2',
    detail: [`Added: ${DRAWING}`, `Still there: ${REVIEWING}`],
  })
})

test('a line swapped for another reads as now, the dropped one in the detail', () => {
  expect(changed({ now: [DRAWING] })).toEqual({
    text: 'Status: now drawing Usage, round 2',
    detail: [`Added: ${DRAWING}`, `No longer: ${REVIEWING}`],
  })
})

test('a line swapped while another stays reads as now, not now also', () => {
  expect(
    statusChange(
      { ...BEFORE, now: [REVIEWING, 'Drawing Usage, round 1'] },
      { ...BEFORE, now: [REVIEWING, DRAWING] },
    ),
  ).toEqual({
    text: 'Status: now drawing Usage, round 2',
    detail: [`Added: ${DRAWING}`, 'No longer: Drawing Usage, round 1', `Still there: ${REVIEWING}`],
  })
})

test('a line dropped reads as no longer', () => {
  expect(statusChange({ ...BEFORE, now: [REVIEWING, DRAWING] }, BEFORE)).toEqual({
    text: 'Status: no longer drawing Usage, round 2',
    detail: [`No longer: ${DRAWING}`, `Still there: ${REVIEWING}`],
  })
})

test('several lines taken on name the first and count the rest', () => {
  expect(changed({ now: [REVIEWING, DRAWING, 'Writing the Usage spec'] })?.text).toBe(
    'Status: now also drawing Usage, round 2 (and 1 more)',
  )
})

test('a line that opens on a name or an acronym keeps its capital', () => {
  expect(changed({ now: ['PR #82 in its second review'] })?.text).toBe(
    'Status: now PR #82 in its second review',
  )
})

test("what comes next, the name and the summary each earn a line when they're all that changed", () => {
  expect(changed({ next: 'Usage, round 3' })).toEqual({
    text: 'Status: next is Usage, round 3',
    detail: ['Next: Usage, round 3'],
  })
  expect(changed({ next: undefined })).toEqual({
    text: 'Status: nothing next',
    detail: ['Next: none'],
  })
  expect(changed({ name: 'Dashboard, round 2' })).toEqual({
    text: 'Status: renamed to Dashboard, round 2',
    detail: ['Name: Dashboard, round 2'],
  })
  expect(changed({ summary: 'Area by area' })).toEqual({
    text: 'Status: summary changed',
    detail: ['Summary: Area by area'],
  })
})

test('what is under way heads a change of several fields; the detail holds them all', () => {
  expect(
    changed({ now: [REVIEWING, DRAWING], next: 'Usage, round 3', summary: 'Area by area' }),
  ).toEqual({
    text: 'Status: now also drawing Usage, round 2',
    detail: [
      `Added: ${DRAWING}`,
      `Still there: ${REVIEWING}`,
      'Next: Usage, round 3',
      'Summary: Area by area',
    ],
  })
})

test('the same status again, or its lines in another order, earns no line', () => {
  expect(changed({})).toBeUndefined()
  expect(
    statusChange(
      { ...BEFORE, now: [REVIEWING, DRAWING] },
      { ...BEFORE, now: [DRAWING, REVIEWING] },
    ),
  ).toBeUndefined()
})

test('the board logs status changes itself as it folds, comparing each with the one before across writers', () => {
  const logs = {
    [W1]: file(
      [T0 + 1 * MIN, status([REVIEWING])],
      [T0 + 3 * MIN, status([REVIEWING])],
      [T0 + 4 * MIN, note('n1', 'Orders & Invoices drawn')],
    ),
    [W2]: file([T0 + 5 * MIN, status([REVIEWING, DRAWING])]),
  }
  const session = fold({ logs })

  expect(session.log.map(line => [line.kind, line.text, line.at, line.by])).toEqual([
    ['status', 'Status: now also drawing Usage, round 2', T0 + 5 * MIN, W2],
    ['note', 'Orders & Invoices drawn', T0 + 4 * MIN, W1],
    [
      'status',
      'Status: now waiting on your review of Orders & Invoices, round 1',
      T0 + 1 * MIN,
      W1,
    ],
  ])
  expect(session.log.filter(line => line.kind === 'status').map(line => line.id)).toEqual([
    undefined,
    undefined,
  ])
  expect([...parseEntries(logs[W1]), ...parseEntries(logs[W2])].map(entry => entry.type)).toEqual([
    'status',
    'status',
    'note',
    'status',
  ])
})

test("a session's first status is compared with the session as it was started", () => {
  const renamed = fold({
    logs: { [W1]: file([T0 + MIN, status([], { name: 'Dashboard, round 2' })]) },
  })
  const unchanged = fold({ logs: { [W1]: file([T0 + MIN, status([])]) } })

  expect(renamed.log.map(line => line.text)).toEqual(['Status: renamed to Dashboard, round 2'])
  expect(unchanged.log).toEqual([])
})
