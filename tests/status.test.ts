import { expect, test } from './kit'
import { parseEntries, statusChange, type StatusFields } from '../core'
import { MIN, T0, W1, W2 } from './data'
import { file, fold, status } from './lines'

const REVIEWING = 'Waiting on your review of Tickets & Replies, round 1'
const DRAWING = 'Drawing Inbox, round 2'

const BEFORE: StatusFields = {
  name: 'Help desk redesign',
  summary: 'Redesign the help desk, page by page in Paper',
  now: [REVIEWING],
  next: 'Inbox, round 2',
}

const changed = (after: Partial<StatusFields>) => statusChange(BEFORE, { ...BEFORE, ...after })

test("a line taken on reads as the spike's: now also, with what is still there in the detail", () => {
  expect(changed({ now: [REVIEWING, DRAWING] })).toEqual({
    text: 'now also drawing Inbox, round 2',
    detail: [`Added: ${DRAWING}`, `Still there: ${REVIEWING}`],
  })
})

test('a line swapped for another reads as now, the dropped one in the detail', () => {
  expect(changed({ now: [DRAWING] })).toEqual({
    text: 'now drawing Inbox, round 2',
    detail: [`Added: ${DRAWING}`, `No longer: ${REVIEWING}`],
  })
})

test('a line swapped while another stays reads as now, not now also', () => {
  expect(
    statusChange(
      { ...BEFORE, now: [REVIEWING, 'Drawing Inbox, round 1'] },
      { ...BEFORE, now: [REVIEWING, DRAWING] },
    ),
  ).toEqual({
    text: 'now drawing Inbox, round 2',
    detail: [`Added: ${DRAWING}`, 'No longer: Drawing Inbox, round 1', `Still there: ${REVIEWING}`],
  })
})

test('a line dropped reads as no longer', () => {
  expect(statusChange({ ...BEFORE, now: [REVIEWING, DRAWING] }, BEFORE)).toEqual({
    text: 'no longer drawing Inbox, round 2',
    detail: [`No longer: ${DRAWING}`, `Still there: ${REVIEWING}`],
  })
})

test('several lines taken on name the first and count the rest', () => {
  expect(changed({ now: [REVIEWING, DRAWING, 'Writing the Inbox spec'] })?.text).toBe(
    'now also drawing Inbox, round 2 (and 1 more)',
  )
})

test('a line that opens on a name or an acronym keeps its capital', () => {
  expect(changed({ now: ['PR #82 in its second review'] })?.text).toBe(
    'now PR #82 in its second review',
  )
})

test("what comes next, the name and the summary each earn a line when they're all that changed", () => {
  expect(changed({ next: 'Inbox, round 3' })).toEqual({
    text: 'next is Inbox, round 3',
    detail: ['Next: Inbox, round 3'],
  })
  expect(changed({ next: undefined })).toEqual({
    text: 'nothing next',
    detail: ['Next: none'],
  })
  expect(changed({ name: 'Help desk, round 2' })).toEqual({
    text: 'renamed to Help desk, round 2',
    detail: ['Name: Help desk, round 2'],
  })
  expect(changed({ summary: 'Area by area' })).toEqual({
    text: 'summary changed',
    detail: ['Summary: Area by area'],
  })
})

test('what is under way heads a change of several fields; the detail holds them all', () => {
  expect(
    changed({ now: [REVIEWING, DRAWING], next: 'Inbox, round 3', summary: 'Area by area' }),
  ).toEqual({
    text: 'now also drawing Inbox, round 2',
    detail: [
      `Added: ${DRAWING}`,
      `Still there: ${REVIEWING}`,
      'Next: Inbox, round 3',
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

test('the board notices status changes itself as it folds, comparing each with the one before across writers, and keeps them as its history, the newest first', () => {
  const logs = {
    [W1]: file([T0 + 1 * MIN, status([REVIEWING])], [T0 + 3 * MIN, status([REVIEWING])]),
    [W2]: file([T0 + 5 * MIN, status([REVIEWING, DRAWING])]),
  }
  const session = fold({ logs })

  expect(session.history.map(line => [line.text, line.at, line.by])).toEqual([
    ['now also drawing Inbox, round 2', T0 + 5 * MIN, W2],
    ['now waiting on your review of Tickets & Replies, round 1', T0 + 1 * MIN, W1],
  ])
  expect(session.history[0]?.detail).toEqual([
    'Added: Drawing Inbox, round 2',
    'Still there: Waiting on your review of Tickets & Replies, round 1',
  ])
  expect(
    [...parseEntries(logs[W1]), ...parseEntries(logs[W2])].map(entry => entry.type),
    'no change is written down',
  ).toEqual(['status', 'status', 'status'])
})

test("a session's first status is compared with the session as it was started", () => {
  const renamed = fold({
    logs: { [W1]: file([T0 + MIN, status([], { name: 'Help desk, round 2' })]) },
  })
  const unchanged = fold({ logs: { [W1]: file([T0 + MIN, status([])]) } })

  expect(renamed.history.map(line => line.text)).toEqual(['renamed to Help desk, round 2'])
  expect(unchanged.history).toEqual([])
})
