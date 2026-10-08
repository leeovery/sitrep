import { expect, test } from 'claude-code/testing'
import { boardText, startText, summarise, worksText } from '../core'
import {
  ask,
  delivered,
  file,
  fold,
  MIN,
  note,
  park,
  reply,
  resolve,
  SENDER,
  seen,
  status,
  T0,
  W1,
  type Line,
} from './support'

const NOW = T0 + 60 * MIN

const WORK = fold(
  {
    logs: {
      [W1]: file(
        [
          T0 + 1 * MIN,
          status(['Waiting on your review of round 1', 'Drawing Usage, round 2'], {
            next: 'Usage, round 3',
          }),
        ],
        [
          T0 + 2 * MIN,
          {
            type: 'ask',
            id: 'k1',
            kind: 'review',
            title: 'Review round 1',
            where: 'In Paper: page "round 1"',
          },
        ],
        [
          T0 + 2 * MIN,
          ask('k2', 'decide', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever']),
        ],
        [T0 + 2 * MIN, ask('k3', 'try', 'Try it on the iPad')],
        [T0 + 2 * MIN, ask('k4', 'do', 'Run the apply')],
        [T0 + 3 * MIN, reply('r1', 'k3', 'comment', { note: 'It fails after the code' })],
        [T0 + 3 * MIN, delivered('r1')],
        [T0 + 4 * MIN, resolve('k4')],
        [T0 + 5 * MIN, park('p1', 'A tmux indicator')],
        ...[1, 2, 3, 4, 5, 6].map((n): Line => [T0 + (5 + n) * MIN, note(`n${n}`, `Note ${n}`)]),
      ),
    },
    inbox: { [SENDER]: file([T0 + 20 * MIN, reply('r2', 'k1', 'yes', { note: 'Lovely' })]) },
    presence: { [W1]: seen(W1, NOW) },
  },
  NOW,
)

test("the board text lists the work's open items by id, for Claude to check and repair", () => {
  expect(boardText(WORK)).toBe(
    [
      'sitrep board: Dashboard redesign (sr-k3f9qa)',
      'Summary: Redesign the dashboard, area by area in Paper',
      'Now:',
      '- Waiting on your review of round 1',
      '- Drawing Usage, round 2',
      'Next: Usage, round 3',
      'Open asks:',
      '- k1 review, waiting on Lee: Review round 1; where: In Paper: page "round 1"',
      '- k2 decide, waiting on Lee: Keep the ledger 400 days, or forever?; options: 400 days | Forever',
      '- k3 try, Lee replied, yours to act on (comment: “It fails after the code”): Try it on the iPad',
      'Parked:',
      '- p1: A tmux indicator',
      'Latest notes:',
      '- n6: Note 6',
      '- n5: Note 5',
      '- n4: Note 4',
      '- n3: Note 3',
      '- n2: Note 2',
    ].join('\n'),
  )
})

test('the board text never tells Claude a reply it has not been delivered', () => {
  expect(boardText(WORK)).not.toContain('Lovely')
  expect(boardText(WORK)).not.toContain('approved')
})

test('an empty board says so in every section', () => {
  expect(boardText(fold({ logs: {} }))).toBe(
    [
      'sitrep board: Dashboard redesign (sr-k3f9qa)',
      'Summary: Redesign the dashboard, area by area in Paper',
      'Now:',
      '- none',
      'Next: none',
      'Open asks:',
      '- none',
      'Parked:',
      '- none',
      'Latest notes:',
      '- none',
    ].join('\n'),
  )
})

test('the works listing gives each work its id, and says whether a window has it and what waits', () => {
  const closed = fold({ logs: { [W1]: file([T0, ask('k1', 'do', 'Run it')]) } })

  expect(worksText([summarise(WORK), { ...summarise(closed), id: 'sr-zzzzzz' }])).toBe(
    [
      'sitrep pieces of work:',
      '- sr-k3f9qa: Dashboard redesign. Redesign the dashboard, area by area in Paper (open in a window; 2 waiting on Lee)',
      '- sr-zzzzzz: Dashboard redesign. Redesign the dashboard, area by area in Paper (no window has it open; 1 waiting on Lee)',
    ].join('\n'),
  )
  expect(worksText([])).toBe('sitrep pieces of work:\n- none')
})

test('a session starts knowing its works by id, how to take one up, and which this window holds', () => {
  const works = [summarise(WORK)]
  const join =
    'When Lee carries on with one of these, join it by its id with the sitrep join tool before posting to its board.'

  expect(startText(works)).toBe(`${worksText(works)}\n${join}`)
  expect(startText(works, works[0])).toBe(
    `${worksText(works)}\nThis window already holds sr-k3f9qa (Dashboard redesign): post to its board as you go. ${join}`,
  )
})
