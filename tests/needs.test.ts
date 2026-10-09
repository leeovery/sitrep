import { expect, test } from 'claude-code/testing'
import {
  answerOf,
  boardMessage,
  boardText,
  checkAsk,
  checkEdit,
  fits,
  FROM_THE_BOARD,
  replyLine,
  type Ask,
  type AskKind,
  type Body,
  type Checked,
  type ReplyFields,
} from '../core'
import { ask, file, fold, MIN, park, reply, SENDER, seen, T0, W1 } from './support'

const NOW = T0 + 60 * MIN

const OUTPUT = "the command's output"

/** An ask that needs something back from Lee. */
const needing = (id: string, kind: AskKind, title: string, needs: string, options?: string[]) =>
  ({ type: 'ask', id, kind, title, options, needs }) satisfies Body

const EXPORT = needing('k1', 'do', 'Run the export', OUTPUT)
const FRAMES = needing(
  'k2',
  'decide',
  'Ship round 2, or redraw?',
  'which frames you would change',
  ['Ship it', 'Redraw'],
)
const PLAIN = ask('k3', 'review', 'Review round 1')
const PARKED = park('p1', 'A tmux indicator')

const WORK = fold({
  logs: {
    [W1]: file(...[EXPORT, FRAMES, PLAIN, PARKED].map((body): [number, Body] => [T0, body])),
  },
})

const PASTED = 'v1.2.3\n\n  exported 42 rows'

const refusal = <T>(checked: Checked<T>) => (checked.ok ? undefined : checked.error)
const value = <T>(checked: Checked<T>) => (checked.ok ? checked.value : undefined)

const askOf = (id: string) => WORK.items.get(id) as Ask

const messageOf = (...replies: ReplyFields[]) => boardMessage(WORK, replies)?.text

test('an ask says what it needs back on one line, for any kind; an empty one is absent', () => {
  expect(
    value(checkAsk({ kind: 'do', title: 'Run the export', needs: " the command's\n  output " })),
  ).toEqual({ type: 'ask', kind: 'do', title: 'Run the export', needs: OUTPUT })
  expect(
    value(checkAsk({ kind: 'review', title: 'Review it', needs: 'which frames' }))?.needs,
  ).toBe('which frames')
  expect(value(checkAsk({ kind: 'do', title: 'Run it', needs: ' \n ' }))?.needs).toBeUndefined()
  expect(value(checkAsk({ kind: 'do', title: 'Run it', needs: 42 }))?.needs).toBeUndefined()
})

test('an edit changes what an ask needs back, an empty one clearing it; no other item takes it', () => {
  expect(value(checkEdit(WORK, { item: 'k3', needs: ' which\nframes ' }))?.changes).toEqual({
    needs: 'which frames',
  })
  expect(value(checkEdit(WORK, { item: 'k1', needs: ' ' }))?.changes).toEqual({ needs: '' })
  expect(refusal(checkEdit(WORK, { item: 'k1', needs: 42 }))).toContain('cannot leave needs')
  expect(refusal(checkEdit(WORK, { item: 'p1', needs: OUTPUT }))).toBe(
    'An edit to a parked item changes title, where, ref; not needs.',
  )
})

test('the ask line keeps what it needs back as it folds; an edit changes it, and an empty one clears it', () => {
  const edit = (at: number, needs: string): [number, Body] => [
    at,
    { type: 'edit', item: 'k1', changes: { needs } },
  ]
  const after = (...edits: [number, Body][]) =>
    fold({ logs: { [W1]: file([T0, EXPORT], ...edits) } }).asks[0]

  expect(after()).toMatchObject({ kind: 'do', title: 'Run the export', needs: OUTPUT })
  expect(after(edit(T0 + MIN, 'the exit code'))?.needs).toBe('the exit code')
  expect(after(edit(T0 + MIN, ''))?.needs).toBeUndefined()
  expect(after(edit(T0 + MIN, ''), edit(T0 + 2 * MIN, 'the exit code'))?.needs).toBe(
    'the exit code',
  )
})

test('a yes or a choice on an ask that needs something back fits with its note or without, as on any ask', () => {
  expect(fits(askOf('k1'), { item: 'k1', verdict: 'yes', note: PASTED })).toBe(true)
  expect(fits(askOf('k1'), { item: 'k1', verdict: 'yes' })).toBe(true)
  expect(fits(askOf('k2'), { item: 'k2', verdict: 'choose', option: 'Redraw' })).toBe(true)
  expect(fits(askOf('k2'), { item: 'k2', verdict: 'choose' })).toBe(false)
  expect(fits(askOf('k1'), { item: 'k1', verdict: 'comment' })).toBe(false)
})

test('an edit giving an ask something to need back voids no yes on its way to it', () => {
  const work = fold({
    logs: {
      [W1]: file(
        [T0, PLAIN],
        [T0 + 2 * MIN, { type: 'edit', item: 'k3', changes: { needs: OUTPUT } }],
      ),
    },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k3', 'yes')]) },
    presence: { [W1]: seen(W1, NOW) },
  })

  expect(work.replies).toMatchObject([{ id: 'r1', delivery: 'waiting' }])
})

test("Lee's message says what a yes or a choice carries back in the ask's words; one bare says only the answer", () => {
  expect(
    messageOf(
      { item: 'k1', verdict: 'yes', note: 'v1.2.3' },
      { item: 'k2', verdict: 'choose', option: 'Redraw', note: 'Frames 2 and 5' },
      { item: 'k1', verdict: 'yes' },
      { item: 'k3', verdict: 'yes', note: 'Lovely' },
    ),
  ).toBe(
    [
      FROM_THE_BOARD,
      "- Run the export → done, with the command's output: “v1.2.3”",
      '- Ship round 2, or redraw? → Redraw, with which frames you would change: “Frames 2 and 5”',
      '- Run the export → done',
      '- Review round 1 → approved, with a comment: “Lovely”',
    ].join('\n'),
  )
})

test('a note of several lines arrives fenced under its reply, every line kept; the next reply follows on a line of its own', () => {
  expect(
    messageOf(
      { item: 'k1', verdict: 'yes', note: PASTED },
      { item: 'k3', verdict: 'comment', note: 'Thinner bars\nand a lighter grey' },
      { item: 'k3', verdict: 'yes', note: 'Ship it\nafter the copy pass' },
      { item: 'p1', verdict: 'pickup', note: 'Before the release\nwith the band' },
      { item: 'k2', verdict: 'choose', option: 'Ship it' },
    ),
  ).toBe(
    [
      FROM_THE_BOARD,
      "- Run the export → done, with the command's output:",
      '  ```',
      '  v1.2.3',
      '  ',
      '    exported 42 rows',
      '  ```',
      '- Review round 1 → comment:',
      '  ```',
      '  Thinner bars',
      '  and a lighter grey',
      '  ```',
      '- Review round 1 → approved, with a comment:',
      '  ```',
      '  Ship it',
      '  after the copy pass',
      '  ```',
      '- Pick up from parked: A tmux indicator.',
      '  ```',
      '  Before the release',
      '  with the band',
      '  ```',
      '- Ship round 2, or redraw? → Ship it',
    ].join('\n'),
  )
})

test('a pasted note holding a fence of its own is fenced by a longer one, so none of its lines closes it', () => {
  const note = 'Ran it:\n```\nok\n````'

  expect(replyLine(askOf('k1'), { item: 'k1', verdict: 'yes', note })).toBe(
    [
      "- Run the export → done, with the command's output:",
      '  `````',
      '  Ran it:',
      '  ```',
      '  ok',
      '  ````',
      '  `````',
    ].join('\n'),
  )
})

test("under its ask, the board shows what a reply carries back in the ask's words, quoted as typed", () => {
  expect(answerOf(askOf('k1'), { item: 'k1', verdict: 'yes', note: 'a\nb' })).toBe(
    "done, with the command's output: “a\nb”",
  )
  expect(
    answerOf(askOf('k2'), { item: 'k2', verdict: 'choose', option: 'Redraw', note: 'Two' }),
  ).toBe('→ Redraw, with which frames you would change: “Two”')
  expect(answerOf(askOf('k1'), { item: 'k1', verdict: 'yes' })).toBe('done')
})

test('the board text tells Claude what an open ask needs back, after its options', () => {
  expect(boardText(WORK)).toContain(
    `- k1 do, waiting on Lee: Run the export; needs: ${OUTPUT}\n` +
      '- k2 decide, waiting on Lee: Ship round 2, or redraw?; options: Ship it | Redraw; needs: which frames you would change\n',
  )
})
