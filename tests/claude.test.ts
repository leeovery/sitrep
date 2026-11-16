import { expect, test } from './kit'
import {
  boardText,
  onBoardText,
  parkedBy,
  projectParked,
  startText,
  summarise,
  summariseProject,
  toldSummary,
} from '../core'
import {
  beat,
  choiceAsk,
  delivered,
  file,
  finish,
  fold,
  MIN,
  note,
  park,
  reply,
  resolve,
  SENDER,
  seen,
  snoozeSession,
  status,
  T0,
  W1,
  W2,
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
          status(['Waiting on your review of round 1', 'Drawing Inbox, round 2'], {
            next: 'Inbox, round 3',
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
        [T0 + 5 * MIN, park('p1', 'A priority badge')],
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
      'sitrep board: Help desk redesign (sr-k3f9qa)',
      'Summary: Redesign the help desk, page by page in Paper',
      'Now:',
      '- Waiting on your review of round 1',
      '- Drawing Inbox, round 2',
      'Next: Inbox, round 3',
      'Open asks:',
      '- k1 wants a yes (Approve), waiting on Lee: Review round 1; where: In Paper: page "round 1"',
      '- k2 wants a choice, waiting on Lee: Keep the ledger 400 days, or forever?; options: 400 days | Forever',
      '- k3 wants a yes (It works), Lee replied, yours to act on (comment: “It fails after the code”): Try it on the iPad',
      'Parked:',
      '- p1: A priority badge',
      'Latest notes:',
      '- n6: Note 6',
      '- n5: Note 5',
      '- n4: Note 4',
      '- n3: Note 3',
      '- n2: Note 2',
    ].join('\n'),
  )
})

test("the board text's Parked is the project's: what the session parked first, then what its other sessions parked, the oldest first, each by its session's name, its id given as the tools' session", () => {
  const ledger = fold({
    logs: {
      [W1]: file(
        [T0, status([], { name: 'Invoice ledger' })],
        [T0 + 3 * MIN, park('p1', 'Export the ledger as CSV', { where: 'In the spec' })],
        [T0 + 9 * MIN, park('p2', 'Archive old invoices')],
      ),
    },
  })
  const themes = fold({
    logs: {
      [W1]: file(
        [T0, status([], { name: 'Themes' })],
        [T0 + 4 * MIN, park('m2p8', 'A dark theme')],
      ),
      [W2]: file([T0 + 5 * MIN, finish('claude', 'Shipped')]),
    },
  })
  const parked = projectParked(
    [SESSION, { ...ledger, id: 'sr-1edger' }, { ...themes, id: 'sr-themes' }].flatMap(parkedBy),
  )

  expect(boardText(SESSION, parked)).toContain(
    [
      'Parked:',
      '- p1: A priority badge',
      '- p1, parked by "Invoice ledger" (session: sr-1edger): Export the ledger as CSV; where: In the spec',
      '- m2p8, parked by "Themes" (session: sr-themes): A dark theme',
      '- p2, parked by "Invoice ledger" (session: sr-1edger): Archive old invoices',
      'Latest notes:',
    ].join('\n'),
  )
  expect(boardText(SESSION, parkedBy(SESSION)), 'its own listed once').toBe(boardText(SESSION))
})

test('the guide has Claude finish a session whatever it parked: that stays its project’s', () => {
  expect(startText([])).toContain(
    "when the session is complete, with nothing left on it, finish it: what it parked stays its project's, and holds no finish back.",
  )
})

test('the board text never tells Claude a reply it has not been delivered', () => {
  expect(boardText(SESSION)).not.toContain('Lovely')
  expect(boardText(SESSION)).not.toContain('approved')
})

test('an empty board says so in every section', () => {
  expect(boardText(fold({ logs: {} }))).toBe(
    [
      'sitrep board: Help desk redesign (sr-k3f9qa)',
      'Summary: Redesign the help desk, page by page in Paper',
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
  const ledger = { ...summarise(closed), id: 'sr-1edger', name: 'Invoice ledger', waiting: 0 }
  const northwind = summariseProject('northwind', [toldSummary(SESSION), ledger])
  const contoso = {
    ...summariseProject('contoso', [{ ...ledger, id: 'sr-eeeeee', name: 'Onboarding' }]),
    name: 'Contoso',
  }

  expect(onBoardText([contoso, northwind])).toBe(
    [
      'On the board:',
      '- Contoso: sr-eeeeee "Onboarding"',
      '- Northwind: sr-k3f9qa "Help desk redesign", 2 waiting on Lee',
      '- Northwind: sr-1edger "Invoice ledger"',
    ].join('\n'),
  )
})

test("Claude's listing counts an ask whose answer from Lee is on its way as waiting on Lee, as its board text lists it, while Lee's count leaves it out", () => {
  const finished = fold({
    logs: { [W1]: file([T0, yesAsk('k1', 'Run it', 'Done')], [T0, finish('lee')]) },
  })

  expect(SESSION.asks[0]?.replies).toMatchObject([{ id: 'r2', delivery: 'waiting' }])
  expect(toldSummary(SESSION).waiting).toBe(2)
  expect(boardText(SESSION)).toContain('- k1 wants a yes (Approve), waiting on Lee: Review round 1')
  expect(summarise(SESSION).waiting, "Lee's surfaces count only what waits on Lee").toBe(1)
  expect(toldSummary(finished).waiting, 'a finished session waits on Lee for nothing').toBe(0)
})

test('a conversation starts knowing how to keep the board and talk to Lee beside it, every session on it by project, and which this window holds', () => {
  const projects = [summariseProject('northwind', [summarise(SESSION)])]
  const guide = startText([])

  expect(guide).toContain(
    'Start a session when the work will run across several turns or will need Lee',
  )
  expect(guide).toContain('Not for a quick question.')
  expect(guide).toContain(
    "Keep it current, since it tells Lee, away from this window, that something waits on him; but talk to Lee as if it weren't there: the chat alone tells him all he needs.",
  )
  expect(guide).toContain('resolve it yourself when Lee answers it in the chat')
  expect(guide).toContain(
    'a turn that ends on a decision or a question for Lee posts it as an ask, so it shows in Needs you, never only in the status; plain conversation needs none',
  )
  expect(guide).toContain(
    'Touch the board only once it is clear which project the work is on: the project being discussed, whatever folder this window started in.',
  )
  expect(guide).toContain(
    'When Lee carries on with a session on the board, join it by its id with the sitrep join tool.',
  )
  expect(guide).toContain(
    "Otherwise start one, naming its project as Lee would say it (SitRep, Switchboard), by the name it has on the board when it is one there, and giving the project's directory once you know it.",
  )
  expect(guide).toContain(
    'Item and session ids are yours alone: Lee sees none of them on the board or in the app, so never name one to him. Name an ask, a parked item or a session by its words.',
  )
  expect(guide).not.toContain('On the board')
  expect(guide, 'what Lee needs said in the chat, never by the board').toContain(
    'In the chat, give an ask\'s question and steps whole, and never point Lee to the board: no "it\'s on the board", no "check the board".',
  )
  expect(guide, 'saying what was parked, and naming the open asks now and then').toContain(
    "Saying you parked something is fine, as is naming the asks still open now and then, when several wait, though not at every turn's end.",
  )
  expect(guide).toContain(
    "An ask Lee hasn't answered that you still need, raise again in the chat.",
  )
  expect(guide, "the turn's order").toContain(
    "Every board call of a turn comes before your closing message to Lee, never after it. Before any tool call, write Lee a line at most: longer words before a tool call can reach him as a short summary, or not at all. What he must read goes after the turn's last tool call.",
  )
  expect(guide, 'sessions, never pieces of work').not.toMatch(/\bpieces? of work\b/i)
  expect(
    startText([summariseProject('quiet', [])]),
    'a project with no sessions lists nothing',
  ).toBe(guide)
  expect(startText(projects)).toBe(`${guide}\n${onBoardText(projects)}`)
  expect(startText(projects, summarise(SESSION))).toBe(
    `${guide}\n${onBoardText(projects)}\nThis window already holds sr-k3f9qa (Help desk redesign): post to its board as you go.`,
  )
})

/** Monday 26 October 2026, 09:00, local time: when the snooze under test wakes. */
const MONDAY = new Date(2026, 9, 26, 9).getTime()

/** Four asks, the session snoozed until Monday. */
const SNOOZING: Line[] = [
  [T0, yesAsk('k1', 'Give the ok for phase 3', 'Go')],
  [T0, yesAsk('k2', 'Review the plan')],
  [T0, choiceAsk('k3', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
  [T0, yesAsk('k4', 'Tag the release', 'Done')],
  [T0 + MIN, snoozeSession(MONDAY, 'k1', 'k2', 'k3', 'k4')],
]

/** The asks at `now`, Lee's answer to the last on its way in a window's message. */
const snoozedAt = (now: number, ...more: Line[]) =>
  fold(
    {
      logs: { [W1]: file(...SNOOZING, ...more) },
      presence: {
        [W2]: beat(W2, {
          attachedAt: T0,
          seenAt: now,
          sending: [{ at: T0 + 2 * MIN, replies: [{ id: 'r1', item: 'k4', verdict: 'yes' }] }],
        }),
      },
    },
    now,
  )

const SNOOZED = snoozedAt(NOW)

test("a snoozed ask reads as snoozed by Lee until its time, whole and local, in place of waiting on Lee, one with Lee's answer on its way among them", () => {
  expect(boardText(SNOOZED)).toContain(
    [
      'Open asks:',
      '- k1 wants a yes (Go), snoozed by Lee until Mon 26 Oct 09:00 (leave it until then): Give the ok for phase 3',
      '- k2 wants a yes (Approve), snoozed by Lee until Mon 26 Oct 09:00 (leave it until then): Review the plan',
      '- k3 wants a choice, snoozed by Lee until Mon 26 Oct 09:00 (leave it until then): Keep it, or drop it?; options: Keep it | Drop it',
      '- k4 wants a yes (Done), snoozed by Lee until Mon 26 Oct 09:00 (leave it until then): Tag the release',
      'Parked:',
    ].join('\n'),
  )
  expect(boardText(snoozedAt(MONDAY)), 'its time come').not.toContain('snoozed')
})

test("Claude's listing counts snoozed asks apart from those waiting on Lee, one Lee's answer is on its way to among them, where Lee's counts leave that one out of both", () => {
  const told = toldSummary(SNOOZED)

  expect([told.waiting, told.snoozed]).toEqual([0, 4])
  expect([summarise(SNOOZED).waiting, summarise(SNOOZED).snoozed]).toEqual([0, 3])
  expect(onBoardText([summariseProject('northwind', [told])])).toBe(
    'On the board:\n- Northwind: sr-k3f9qa "Help desk redesign", 4 snoozed by Lee',
  )
  expect(
    onBoardText([summariseProject('northwind', [{ ...told, waiting: 1, snoozed: 3 }])]),
    'some waiting too',
  ).toBe(
    'On the board:\n- Northwind: sr-k3f9qa "Help desk redesign", 1 waiting on Lee, 3 snoozed by Lee',
  )
  expect(
    toldSummary(snoozedAt(NOW, [T0 + 3 * MIN, finish('lee')])),
    'a finished session waits on Lee for nothing',
  ).toMatchObject({ waiting: 0, snoozed: 0 })
})
