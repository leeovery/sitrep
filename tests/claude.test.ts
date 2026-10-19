import { expect, test } from 'claude-code/testing'
import { boardText, onBoardText, startText, summarise, summariseProject } from '../core'
import {
  choiceAsk,
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
  yesAsk,
  type Line,
} from './support'

const NOW = T0 + 60 * MIN

const SESSION = fold(
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
            wants: 'yes',
            yes: 'Approve',
            title: 'Review round 1',
            where: 'In Paper: page "round 1"',
          },
        ],
        [
          T0 + 2 * MIN,
          choiceAsk('k2', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever']),
        ],
        [T0 + 2 * MIN, yesAsk('k3', 'Try it on the iPad', 'It works')],
        [T0 + 2 * MIN, yesAsk('k4', 'Run the apply', 'Done')],
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

test("the board text lists the session's open items by id, for Claude to check and repair", () => {
  expect(boardText(SESSION)).toBe(
    [
      'sitrep board: Dashboard redesign (sr-k3f9qa)',
      'Summary: Redesign the dashboard, area by area in Paper',
      'Now:',
      '- Waiting on your review of round 1',
      '- Drawing Usage, round 2',
      'Next: Usage, round 3',
      'Open asks:',
      '- k1 wants a yes (Approve), waiting on Lee: Review round 1; where: In Paper: page "round 1"',
      '- k2 wants a choice, waiting on Lee: Keep the ledger 400 days, or forever?; options: 400 days | Forever',
      '- k3 wants a yes (It works), Lee replied, yours to act on (comment: “It fails after the code”): Try it on the iPad',
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
  expect(boardText(SESSION)).not.toContain('Lovely')
  expect(boardText(SESSION)).not.toContain('approved')
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

test('the board listing gives each session a line: its project, its id, its name and what waits on Lee', () => {
  const closed = fold({ logs: { [W1]: file([T0, yesAsk('k1', 'Run it', 'Done')]) } })
  const ledger = { ...summarise(closed), id: 'sr-1edger', name: 'Request ledger', waiting: 0 }
  const switchboard = summariseProject('switchboard', [summarise(SESSION), ledger])
  const sitrep = {
    ...summariseProject('sitrep', [{ ...ledger, id: 'sr-wdsqvn', name: 'sitrep' }]),
    name: 'SitRep',
  }

  expect(onBoardText([sitrep, switchboard])).toBe(
    [
      'On the board:',
      '- SitRep: sr-wdsqvn "sitrep"',
      '- Switchboard: sr-k3f9qa "Dashboard redesign", 2 waiting on Lee',
      '- Switchboard: sr-1edger "Request ledger"',
    ].join('\n'),
  )
})

test('a conversation starts knowing how to keep the board, every session on it by project, and which this window holds', () => {
  const projects = [summariseProject('switchboard', [summarise(SESSION)])]
  const guide = startText([])

  expect(guide).toContain(
    'Start a session when the work will run across several turns or will need Lee',
  )
  expect(guide).toContain('Not for a quick question.')
  expect(guide).toContain('say it in the chat as well')
  expect(guide).toContain('when Lee answers it in the chat, resolve the ask')
  expect(guide).toContain(
    'Touch the board only once it is clear which project the work is on: the project being discussed, whatever folder this window started in.',
  )
  expect(guide).toContain(
    'When Lee carries on with a session on the board, join it by its id with the sitrep join tool.',
  )
  expect(guide).toContain(
    "Otherwise start one, naming its project as Lee would say it (SitRep, Switchboard), by the name it has on the board when it is one there, and giving the project's directory once you know it.",
  )
  expect(guide).not.toContain('On the board')
  expect(guide, 'sessions, never pieces of work').not.toMatch(/\bpieces? of work\b/i)
  expect(
    startText([summariseProject('quiet', [])]),
    'a project with no sessions lists nothing',
  ).toBe(guide)
  expect(startText(projects)).toBe(`${guide}\n${onBoardText(projects)}`)
  expect(startText(projects, summarise(SESSION))).toBe(
    `${guide}\n${onBoardText(projects)}\nThis window already holds sr-k3f9qa (Dashboard redesign): post to its board as you go.`,
  )
})
