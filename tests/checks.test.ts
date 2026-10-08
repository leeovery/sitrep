import { expect, test } from 'claude-code/testing'
import {
  checkAsk,
  checkEdit,
  checkJoin,
  checkNote,
  checkPark,
  checkReopen,
  checkResolve,
  checkStart,
  checkStatus,
  type Checked,
} from '../core'
import { ask, delivered, file, fold, MIN, note, park, reply, resolve, T0, W1 } from './support'

/** A board holding one of each item, and an ask Lee has commented on. */
const WORK = fold({
  logs: {
    [W1]: file(
      [T0, ask('k1', 'review', 'Review round 1')],
      [T0, ask('k2', 'decide', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
      [T0, ask('k3', 'try', 'Try it on the iPad')],
      [T0, note('n1', 'Merged')],
      [T0, park('p1', 'Later')],
      [T0, ask('k9', 'do', 'Run the apply')],
      [T0 + MIN, resolve('k9')],
      [T0 + MIN, reply('r1', 'k3', 'comment', { note: 'It fails' })],
      [T0 + MIN, delivered('r1')],
    ),
  },
})

const CURRENT = {
  name: 'Dashboard redesign',
  summary: 'Area by area',
  now: ['Drawing Usage'],
  next: 'Usage, round 3',
}

const refusal = <T>(checked: Checked<T>) => (checked.ok ? undefined : checked.error)
const value = <T>(checked: Checked<T>) => (checked.ok ? checked.value : undefined)

test('what Claude posts is trimmed and kept to one line', () => {
  expect(
    value(
      checkAsk({
        kind: 'review',
        title: '  Review\n Sessions &   Runway ',
        where: '\tIn Paper:\n page 1 ',
        ref: ' ',
      }),
    ),
  ).toEqual({
    type: 'ask',
    kind: 'review',
    title: 'Review Sessions & Runway',
    where: 'In Paper: page 1',
  })
  expect(
    value(checkNote({ text: ' Merged\nPR #82 ', detail: [' 6 files ', '', '6 files', 'a\nb'] })),
  ).toEqual({
    type: 'note',
    text: 'Merged PR #82',
    detail: ['6 files', 'a b'],
  })
})

test('an item with no words where its title or text goes is refused', () => {
  expect(refusal(checkAsk({ kind: 'review', title: ' \n ' }))).toContain('needs a title')
  expect(refusal(checkAsk({ kind: 'review' }))).toContain('needs a title')
  expect(refusal(checkNote({ text: '' }))).toContain('needs its text')
  expect(refusal(checkPark({ title: 42 }))).toContain('needs a title')
  expect(refusal(checkStart({ name: 'Dashboard', summary: ' ' }))).toContain('needs a summary')
  expect(refusal(checkStart({ summary: 'Area by area' }))).toContain('needs a name')
})

test('an ask of no known kind is refused, naming the kinds', () => {
  expect(refusal(checkAsk({ kind: 'approve', title: 'Approve it' }))).toBe(
    "An ask's kind is one of review, decide, try, do.",
  )
})

test('a decide ask needs at least two options, each one line, none repeated', () => {
  expect(refusal(checkAsk({ kind: 'decide', title: 'Keep it?' }))).toContain('at least 2 options')
  expect(
    refusal(checkAsk({ kind: 'decide', title: 'Keep it?', options: ['Keep it', ' Keep it '] })),
  ).toContain('at least 2 options')
  expect(
    value(checkAsk({ kind: 'decide', title: 'Keep it?', options: [' Keep\nit ', 'Drop it', ''] }))
      ?.options,
  ).toEqual(['Keep it', 'Drop it'])
})

test('only a decide ask takes options', () => {
  expect(refusal(checkAsk({ kind: 'review', title: 'Review it', options: ['Yes', 'No'] }))).toBe(
    'Only a decide ask takes options.',
  )
  expect(
    value(checkAsk({ kind: 'review', title: 'Review it', options: [] }))?.options,
  ).toBeUndefined()
})

test('a work is joined by its id, as start gave it', () => {
  expect(value(checkJoin({ work: ' sr-k3f9qa ' }))).toEqual({ work: 'sr-k3f9qa' })

  for (const work of [undefined, 'k3f9qa', 'sr-K3F9QA', 7]) {
    expect(refusal(checkJoin({ work })), String(work)).toContain('by the id start gave it')
  }
})

test('a status keeps what Claude leaves out, and an empty next clears it', () => {
  expect(value(checkStatus({ now: ['Drawing Usage, round 2', ' '] }, CURRENT))).toEqual({
    type: 'status',
    name: 'Dashboard redesign',
    summary: 'Area by area',
    now: ['Drawing Usage, round 2'],
    next: 'Usage, round 3',
  })
  expect(value(checkStatus({ next: '' }, CURRENT))?.next).toBeUndefined()
  expect(value(checkStatus({ now: 'One thing under way' }, CURRENT))?.now).toEqual([
    'One thing under way',
  ])
})

test('a status that names nothing, empties its name or gives now as no list is refused', () => {
  expect(refusal(checkStatus({}, CURRENT))).toContain('at least one of')
  expect(refusal(checkStatus({ name: ' ' }, CURRENT))).toContain('neither can be empty')
  expect(refusal(checkStatus({ now: 3 }, CURRENT))).toContain('a list of lines')
})

test('resolve and reopen name an item on the board by its id', () => {
  expect(value(checkResolve(WORK, { item: ' k1 ', reason: ' Done in\nthe chat ' }))).toEqual({
    type: 'resolve',
    item: 'k1',
    reason: 'Done in the chat',
  })
  expect(refusal(checkResolve(WORK, { item: 'zz' }))).toBe('There is no item zz on this board.')
  expect(refusal(checkReopen(WORK, {}))).toContain('by its id')
})

test('resolving what is closed, or reopening what is open as posted, is refused', () => {
  expect(refusal(checkResolve(WORK, { item: 'k9' }))).toBe('k9 is already closed.')
  expect(refusal(checkReopen(WORK, { item: 'k1' }))).toBe('k1 is already open.')
  expect(refusal(checkReopen(WORK, { item: 'p1' }))).toBe('p1 is already open.')
  expect(value(checkReopen(WORK, { item: 'k3' }))).toEqual({ type: 'reopen', item: 'k3' })
  expect(value(checkReopen(WORK, { item: 'k9' }))).toEqual({ type: 'reopen', item: 'k9' })
})

test("an edit changes only the fields of its item's type, each put right", () => {
  expect(
    value(checkEdit(WORK, { item: 'k1', title: ' Review\nround 2 ', reason: 'Round 2 is up' })),
  ).toEqual({
    type: 'edit',
    item: 'k1',
    changes: { title: 'Review round 2' },
    reason: 'Round 2 is up',
  })
  expect(
    value(checkEdit(WORK, { item: 'n1', text: 'Merged #82', detail: ['6 files'] }))?.changes,
  ).toEqual({
    text: 'Merged #82',
    detail: ['6 files'],
  })
  expect(refusal(checkEdit(WORK, { item: 'n1', title: 'A title' }))).toBe(
    'An edit to a note changes text, detail, ref; not title.',
  )
  expect(refusal(checkEdit(WORK, { item: 'p1' }))).toBe(
    'An edit names a field to change: for a parked item, title, where, ref.',
  )
  expect(refusal(checkEdit(WORK, { item: 'k1', title: ' ' }))).toContain('cannot leave title empty')
})

test('an edit leaves an ask with the options its kind calls for', () => {
  expect(refusal(checkEdit(WORK, { item: 'k1', kind: 'decide' }))).toContain('at least 2 options')
  expect(
    value(checkEdit(WORK, { item: 'k1', kind: 'decide', options: ['Ship it', 'Hold it'] }))
      ?.changes,
  ).toEqual({
    kind: 'decide',
    options: ['Ship it', 'Hold it'],
  })
  expect(refusal(checkEdit(WORK, { item: 'k2', options: ['Keep it'] }))).toContain(
    'at least 2 options',
  )
  expect(refusal(checkEdit(WORK, { item: 'k1', options: ['Ship it', 'Hold it'] }))).toBe(
    'Only a decide ask takes options.',
  )
  expect(value(checkEdit(WORK, { item: 'k2', kind: 'review' }))?.changes).toEqual({
    kind: 'review',
  })
})
