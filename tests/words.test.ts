import { expect, test } from './kit'
import {
  answerOf,
  boardMessage,
  boardText,
  fits,
  FROM_THE_BOARD,
  moreLines,
  replyLine,
  type Ask,
  type Body,
  type ReplyFields,
} from '../core'
import { MIN, SENDER, T0, W1 } from './data'
import { choiceAsk, file, fold, kindAsk, park, reply, seen, wordsAsk, yesAsk } from './lines'

const NOW = T0 + 60 * MIN

const OUTPUT = "the command's output"

const EXPORT = wordsAsk('k1', 'Run the export', OUTPUT)
const FEEDBACK = wordsAsk('k2', 'Say how round 2 reads')
const GO = yesAsk('k3', 'Give the ok for phase 3', 'Go')
const FRAMES = choiceAsk('k4', 'Ship round 2, or redraw?', ['Ship it', 'Redraw'])
const OLD = kindAsk('k5', 'do', 'Run the apply', { needs: OUTPUT })
const PARKED = park('p1', 'A priority badge')

const SESSION = fold({
  logs: {
    [W1]: file(
      ...[EXPORT, FEEDBACK, GO, FRAMES, OLD, PARKED].map((body): [number, Body] => [T0, body]),
    ),
  },
})

const PASTED = 'v1.2.3\n\n  exported 42 rows'

const askOf = (id: string) => SESSION.items.get(id) as Ask

const messageOf = (...replies: ReplyFields[]) => boardMessage(SESSION, replies)?.text

test('a words ask keeps what its words are as it folds; an edit changes it, and an empty one clears it', () => {
  const edit = (at: number, needs: string): [number, Body] => [
    at,
    { type: 'edit', item: 'k1', changes: { needs } },
  ]
  const after = (...edits: [number, Body][]) =>
    fold({ logs: { [W1]: file([T0, EXPORT], ...edits) } }).asks[0]

  expect(after()).toMatchObject({ wants: 'words', title: 'Run the export', needs: OUTPUT })
  expect(after(edit(T0 + MIN, 'the exit code'))?.needs).toBe('the exit code')
  expect(after(edit(T0 + MIN, ''))?.needs).toBeUndefined()
  expect(after(edit(T0 + MIN, ''), edit(T0 + 2 * MIN, 'the exit code'))?.needs).toBe(
    'the exit code',
  )
})

test('an ask edited away from words keeps no needs; one edited to words takes them', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, EXPORT],
        [T0, GO],
        [T0 + MIN, { type: 'edit', item: 'k1', changes: { wants: 'yes', yes: 'Done' } }],
        [T0 + MIN, { type: 'edit', item: 'k3', changes: { wants: 'words', needs: 'the plan' } }],
      ),
    },
  })

  expect(session.items.get('k1')).toMatchObject({ wants: 'yes', yes: 'Done', needs: undefined })
  expect(session.items.get('k3')).toMatchObject({
    wants: 'words',
    yes: undefined,
    needs: 'the plan',
  })
})

test('a words ask takes an answer with words, or an ignore; nothing else', () => {
  expect(fits(askOf('k1'), { item: 'k1', verdict: 'answer', note: PASTED })).toBe(true)
  expect(fits(askOf('k1'), { item: 'k1', verdict: 'answer' })).toBe(false)
  expect(fits(askOf('k1'), { item: 'k1', verdict: 'ignore' })).toBe(true)
  expect(fits(askOf('k1'), { item: 'k1', verdict: 'yes', note: PASTED })).toBe(false)
  expect(fits(askOf('k1'), { item: 'k1', verdict: 'comment', note: 'Later' })).toBe(false)
  expect(fits(askOf('k3'), { item: 'k3', verdict: 'answer', note: 'Go' })).toBe(false)
})

test('a yes or a choice fits with a comment as its note, or without one', () => {
  expect(fits(askOf('k3'), { item: 'k3', verdict: 'yes' })).toBe(true)
  expect(fits(askOf('k3'), { item: 'k3', verdict: 'yes', note: 'After the copy pass' })).toBe(true)
  expect(fits(askOf('k4'), { item: 'k4', verdict: 'choose', option: 'Redraw', note: 'Two' })).toBe(
    true,
  )
})

test('an edit making a yes ask want words voids the yes on its way; an edit to what the words are voids no answer', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, GO],
        [T0, EXPORT],
        [T0 + 2 * MIN, { type: 'edit', item: 'k3', changes: { wants: 'words' } }],
        [T0 + 2 * MIN, { type: 'edit', item: 'k1', changes: { needs: 'the exit code' } }],
      ),
    },
    inbox: {
      [SENDER]: file(
        [T0 + MIN, reply('r1', 'k3', 'yes')],
        [T0 + MIN, reply('r2', 'k1', 'answer', { note: '0' })],
      ),
    },
    presence: { [W1]: seen(W1, NOW) },
  })

  expect(session.replies).toMatchObject([
    { id: 'r1', delivery: 'void' },
    { id: 'r2', delivery: 'waiting' },
  ])
})

test("Lee's message gives an answer under what its words are, a yes in its button's words, a comment as one", () => {
  expect(
    messageOf(
      { item: 'k1', verdict: 'answer', note: 'v1.2.3' },
      { item: 'k2', verdict: 'answer', note: 'It reads well' },
      { item: 'k3', verdict: 'yes' },
      { item: 'k3', verdict: 'yes', note: 'After the copy pass' },
      { item: 'k4', verdict: 'choose', option: 'Redraw', note: 'Frames 2 and 5' },
      { item: 'k5', verdict: 'yes', note: 'v1.2.3' },
    ),
  ).toBe(
    [
      FROM_THE_BOARD,
      "- Run the export → the command's output: “v1.2.3”",
      '  This closes the ask: nothing more to do with it.',
      '- Say how round 2 reads → answer: “It reads well”',
      '  This closes the ask: nothing more to do with it.',
      '- Give the ok for phase 3 → Go',
      '- Give the ok for phase 3 → Go, with a comment: “After the copy pass”',
      '  This closes the ask: nothing more to do with it.',
      '- Ship round 2, or redraw? → Redraw, with a comment: “Frames 2 and 5”',
      '  This closes the ask: nothing more to do with it.',
      "- Run the apply → Done, with the command's output: “v1.2.3”",
      '  This closes the ask: nothing more to do with it.',
    ].join('\n'),
  )
})

test('words of several lines arrive fenced under their reply, every line kept; the next reply follows on a line of its own', () => {
  expect(
    messageOf(
      { item: 'k1', verdict: 'answer', note: PASTED },
      { item: 'k3', verdict: 'comment', note: 'Thinner bars\nand a lighter grey' },
      { item: 'k3', verdict: 'yes', note: 'Ship it\nafter the copy pass' },
      { item: 'p1', verdict: 'pickup', note: 'Before the release\nwith the band' },
      { item: 'k4', verdict: 'choose', option: 'Ship it' },
    ),
  ).toBe(
    [
      FROM_THE_BOARD,
      "- Run the export → the command's output:",
      '  ```',
      '  v1.2.3',
      '  ',
      '    exported 42 rows',
      '  ```',
      '  This closes the ask: nothing more to do with it.',
      '- Give the ok for phase 3 → comment:',
      '  ```',
      '  Thinner bars',
      '  and a lighter grey',
      '  ```',
      '- Give the ok for phase 3 → Go, with a comment:',
      '  ```',
      '  Ship it',
      '  after the copy pass',
      '  ```',
      '  This closes the ask: nothing more to do with it.',
      '- Pick up from parked: A priority badge.',
      '  ```',
      '  Before the release',
      '  with the band',
      '  ```',
      '- Ship round 2, or redraw? → Ship it',
      '  This closes the ask: nothing more to do with it.',
    ].join('\n'),
  )
})

test('pasted words holding a fence of their own are fenced by a longer one, so none of their lines closes it', () => {
  const note = 'Ran it:\n```\nok\n````'

  expect(replyLine(askOf('k1'), { item: 'k1', verdict: 'answer', note })).toBe(
    [
      "- Run the export → the command's output:",
      '  `````',
      '  Ran it:',
      '  ```',
      '  ok',
      '  ````',
      '  `````',
    ].join('\n'),
  )
})

test('under its ask, the board shows an answer as its words, and any note by its first line, counting the lines after', () => {
  expect(answerOf(askOf('k1'), { item: 'k1', verdict: 'answer', note: PASTED })).toBe('“v1.2.3”')
  expect(moreLines({ note: PASTED })).toBe(2)
  expect(answerOf(askOf('k3'), { item: 'k3', verdict: 'yes', note: 'a\nb' })).toBe(
    '→ Go, with a comment: “a”',
  )
  expect(
    answerOf(askOf('k3'), { item: 'k3', verdict: 'comment', note: 'Hold it\nuntil Monday' }),
  ).toBe('comment: “Hold it”')
  expect(moreLines({ note: 'one line' })).toBe(0)
  expect(moreLines({})).toBe(0)
})

test('the board text tells Claude what each open ask wants back, a yes by its words, and what words it needs', () => {
  expect(boardText(SESSION)).toContain(
    [
      `- k1 wants words, waiting on the user: Run the export; needs: ${OUTPUT}`,
      '- k2 wants words, waiting on the user: Say how round 2 reads',
      '- k3 wants a yes (Go), waiting on the user: Give the ok for phase 3',
      '- k4 wants a choice, waiting on the user: Ship round 2, or redraw?; options: Ship it | Redraw',
      `- k5 wants words, waiting on the user: Run the apply; needs: ${OUTPUT}`,
    ].join('\n'),
  )
})
