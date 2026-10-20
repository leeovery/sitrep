import { expect, test } from 'claude-code/testing'
import {
  answerOf,
  answerState,
  askAfter,
  boardMessage,
  checkEdit,
  deliveredMark,
  deliverer,
  deliveryOf,
  FROM_THE_BOARD,
  parseEntries,
  sentLines,
  STALE_MS,
  toDeliver,
  type AskKind,
  type AskState,
  type Body,
  type Session,
  type Verdict,
} from '../core'
import {
  beat,
  choiceAsk,
  CLI,
  delivered,
  file,
  fold,
  kindAsk,
  MIN,
  park,
  reopen,
  reply,
  resolve,
  SENDER,
  seen,
  T0,
  W1,
  W2,
  wordsAsk,
  yesAsk,
  type Line,
} from './support'

/** When the folds below look: an hour in. */
const NOW = T0 + 60 * MIN

const REVIEW = yesAsk('k1', 'Review Sessions & Runway, round 1', 'Approve')
const DECIDE = choiceAsk('k2', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever'])
const TRY = yesAsk('k3', 'Try signing in on the iPad', 'It works')
const DO = yesAsk('k4', 'Run the production apply', 'Done')
const PARKED = park('p1', 'A tmux indicator across sessions')

const POSTED: Line[] = [REVIEW, DECIDE, TRY, DO, PARKED].map(body => [T0, body])

/** An ask wanting words, and one wanting a yes, for the shapes' own rules. */
const WORDS = wordsAsk('k5', 'Run sitrep list and paste what it prints', "the command's output")
const GO = yesAsk('k6', 'Give the go for stage 3', 'Go')

const SHAPED: Line[] = [WORDS, GO, DECIDE].map(body => [T0, body])

/** A reply in this window's own file, delivered with it, as the mod writes one after Claude takes it. */
const sent = (at: number, id: string, item: string, verdict: Verdict, extra = {}): Line[] => [
  [at, reply(id, item, verdict, extra)],
  [at, delivered(id)],
]

/** Every shape of ask, by an ask of it, and the replies it takes, with where each leaves it once delivered. */
const EFFECTS: Array<[string, Verdict, { option?: string; note?: string }, AskState]> = [
  ['k6', 'yes', {}, 'closed'],
  ['k6', 'yes', { note: 'After the copy pass' }, 'closed'],
  ['k6', 'comment', { note: 'Hold it until Monday' }, 'replied'],
  ['k6', 'ignore', {}, 'ignored'],
  ['k2', 'choose', { option: 'Forever' }, 'closed'],
  ['k2', 'choose', { option: 'Forever', note: 'Storage is cheap' }, 'closed'],
  ['k2', 'comment', { note: 'Two years, then archive' }, 'replied'],
  ['k2', 'ignore', {}, 'ignored'],
  ['k5', 'answer', { note: 'exported 42 rows' }, 'closed'],
  ['k5', 'ignore', {}, 'ignored'],
]

const SHAPES: Record<string, string> = { k2: 'choice', k5: 'words', k6: 'yes' }

for (const [id, verdict, extra, after] of EFFECTS) {
  const how = `${verdict}${extra.note === undefined ? '' : ' with words'}`

  test(`a delivered ${how} on an ask wanting ${SHAPES[id]} leaves it ${after}`, () => {
    const session = fold({
      logs: { [W1]: file(...SHAPED, ...sent(T0 + MIN, 'r1', id, verdict, extra)) },
    })
    const answered = session.asks.find(each => each.id === id)

    expect(answered?.state).toBe(after)
    expect(answered?.answer?.id).toBe('r1')
    expect(answered?.closedAt).toBe(after === 'replied' ? undefined : T0 + MIN)
    expect(session.waiting).toBe(2)
  })
}

/** Asks as written before asks said what they want back, by their kinds, one needing something back. */
const KINDS: Record<AskKind, Body> = {
  review: kindAsk('o1', 'review', 'Review Sessions & Runway, round 1'),
  decide: kindAsk('o2', 'decide', 'Keep the ledger 400 days, or forever?', {
    options: ['400 days', 'Forever'],
  }),
  try: kindAsk('o3', 'try', 'Try signing in on the iPad'),
  do: kindAsk('o4', 'do', 'Run the production apply'),
}
const NEEDING = kindAsk('o5', 'do', 'Run the export', { needs: "the command's output" })

const OLD: Line[] = [...Object.values(KINDS), NEEDING].map(body => [T0, body])

const OLD_IDS: Record<AskKind | 'needs', string> = {
  review: 'o1',
  decide: 'o2',
  try: 'o3',
  do: 'o4',
  needs: 'o5',
}

/** Every kind of ask once written, and the replies written to it then, with where each still leaves it once delivered. */
const OLD_EFFECTS: Array<
  [AskKind | 'needs', Verdict, { option?: string; note?: string }, AskState]
> = [
  ['review', 'yes', {}, 'closed'],
  ['review', 'yes', { note: 'Tighten the gutters' }, 'closed'],
  ['try', 'yes', {}, 'closed'],
  ['do', 'yes', {}, 'closed'],
  ['decide', 'choose', { option: 'Forever' }, 'closed'],
  ['decide', 'choose', { option: 'Forever', note: 'Storage is cheap' }, 'closed'],
  ['decide', 'comment', { note: 'Two years, then archive' }, 'closed'],
  ['review', 'comment', { note: 'The runway bar is too tall' }, 'replied'],
  ['try', 'comment', { note: 'It fails after the code' }, 'replied'],
  ['do', 'comment', { note: 'Not until Monday' }, 'replied'],
  ['review', 'ignore', {}, 'ignored'],
  ['decide', 'ignore', {}, 'ignored'],
  ['try', 'ignore', {}, 'ignored'],
  ['do', 'ignore', {}, 'ignored'],
  ['needs', 'yes', { note: 'v1.2.3' }, 'closed'],
  ['needs', 'yes', {}, 'closed'],
  ['needs', 'comment', { note: 'Not until Monday' }, 'replied'],
  ['needs', 'answer', { note: 'v1.2.3' }, 'closed'],
  ['needs', 'ignore', {}, 'ignored'],
]

for (const [kind, verdict, extra, after] of OLD_EFFECTS) {
  const how = `${verdict}${extra.note === undefined ? '' : ' with a note'}`

  const written = kind === 'needs' ? 'do needing something back' : kind

  test(`a delivered ${how} on an ask written as a ${written} still leaves it ${after}`, () => {
    const session = fold({
      logs: { [W1]: file(...OLD, ...sent(T0 + MIN, 'r1', OLD_IDS[kind], verdict, extra)) },
    })
    const answered = session.asks.find(each => each.id === OLD_IDS[kind])

    expect(answered?.state).toBe(after)
    expect(answered?.answer?.id).toBe('r1')
    expect(session.waiting).toBe(4)
  })
}

test('an ask written by its kind reads as the shape its kind maps to, any needing something back as words', () => {
  const session = fold({ logs: { [W1]: file(...OLD) } })

  expect(
    session.asks.map(({ id, wants, yes, options, needs }) => [id, wants, yes, options, needs]),
  ).toEqual([
    ['o1', 'yes', 'Approve', undefined, undefined],
    ['o2', 'choice', undefined, ['400 days', 'Forever'], undefined],
    ['o3', 'yes', 'It works', undefined, undefined],
    ['o4', 'yes', 'Done', undefined, undefined],
    ['o5', 'words', 'Done', undefined, "the command's output"],
  ])
})

test("old replies read in their ask's words; a decide's comment is still its answer", () => {
  const session = fold({ logs: { [W1]: file(...OLD) } })
  const message = boardMessage(session, [
    { item: 'o1', verdict: 'yes' },
    { item: 'o3', verdict: 'yes', note: 'On the iPad mini too' },
    { item: 'o2', verdict: 'comment', note: 'Two years, then archive' },
    { item: 'o5', verdict: 'yes', note: 'v1.2.3' },
  ])

  expect(message?.text).toBe(
    [
      FROM_THE_BOARD,
      '- Review Sessions & Runway, round 1 → Approve',
      '- Try signing in on the iPad → It works, with a comment: “On the iPad mini too”',
      '- Keep the ledger 400 days, or forever? → answer: “Two years, then archive”',
      "- Run the export → Done, with the command's output: “v1.2.3”",
    ].join('\n'),
  )
})

test("an old edit changing an ask's kind, or what it needs back, reshapes it by the kind", () => {
  const session = fold({
    logs: {
      [W1]: file(
        ...OLD,
        [T0 + MIN, { type: 'edit', item: 'o1', changes: { kind: 'do', needs: 'the exit code' } }],
        [T0 + MIN, { type: 'edit', item: 'o5', changes: { needs: '' } }],
        [T0 + MIN, { type: 'edit', item: 'o3', changes: { kind: 'decide', options: ['A', 'B'] } }],
      ),
    },
  })

  expect(
    session.asks.map(({ id, wants, yes, options, needs }) => [id, wants, yes, options, needs]),
  ).toEqual([
    ['o1', 'words', 'Done', undefined, 'the exit code'],
    ['o2', 'choice', undefined, ['400 days', 'Forever'], undefined],
    ['o3', 'choice', undefined, ['A', 'B'], undefined],
    ['o4', 'yes', 'Done', undefined, undefined],
    ['o5', 'yes', 'Done', undefined, undefined],
  ])
})

test('an edit saying what an old ask wants reads it by that shape from then on, its kind gone', () => {
  const session = fold({
    logs: {
      [W1]: file(
        ...OLD,
        [T0 + MIN, { type: 'edit', item: 'o5', changes: { wants: 'words', needs: '' } }],
        [T0 + MIN, { type: 'edit', item: 'o2', changes: { wants: 'choice', title: 'Keep it?' } }],
        ...sent(T0 + 2 * MIN, 'r1', 'o2', 'comment', { note: 'Two years' }),
      ),
    },
  })

  expect(session.items.get('o5')).toMatchObject({ wants: 'words', kind: undefined, yes: undefined })
  expect(session.items.get('o5')).not.toHaveProperty('needs', expect.anything())
  expect(session.items.get('o2')).toMatchObject({
    wants: 'choice',
    kind: undefined,
    state: 'replied',
  })
})

test("a comment on its way to an old decide still closes it once delivered, though Claude edited the ask's title meanwhile", () => {
  const pending: Line[] = [
    ...OLD,
    [T0 + MIN, reply('r1', 'o2', 'comment', { note: 'Two years, then archive' })],
  ]
  const checked = checkEdit(fold({ logs: { [W1]: file(...pending) } }), {
    item: 'o2',
    title: 'Keep the ledger two years, or forever?',
  })

  if (!checked.ok) {
    throw new Error(checked.error)
  }

  const session = fold({
    logs: {
      [W1]: file(...pending, [T0 + 2 * MIN, checked.value], [T0 + 3 * MIN, delivered('r1')]),
    },
  })

  expect(session.items.get('o2')).toMatchObject({
    kind: 'decide',
    title: 'Keep the ledger two years, or forever?',
    state: 'closed',
    answer: { id: 'r1', delivery: 'delivered' },
  })
})

test('a delivered pick-up marks a parked item picked up, and it leaves the parked list', () => {
  const session = fold({ logs: { [W1]: file(...POSTED, ...sent(T0 + MIN, 'r1', 'p1', 'pickup')) } })

  expect(session.items.get('p1')).toMatchObject({ state: 'picked' })
  expect(session.parked).toEqual([])
})

test('the board logs a delivered pick-up itself, with Lee’s note as its detail', () => {
  const logs = {
    [W1]: file(
      ...POSTED,
      [T0 + 2 * MIN, delivered('r1')],
      [T0 + 3 * MIN, park('p2', 'Paper thumbnails inline in Ghostty')],
      ...sent(T0 + 4 * MIN, 'r2', 'p2', 'pickup'),
    ),
  }
  const session = fold({
    logs,
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'p1', 'pickup', { note: 'Before the release' })]),
    },
  })

  expect(session.log).toEqual([
    {
      kind: 'pickup',
      at: T0 + 4 * MIN,
      by: W1,
      text: 'Picked up from parked: Paper thumbnails inline in Ghostty',
      detail: [],
    },
    {
      kind: 'pickup',
      at: T0 + 2 * MIN,
      by: SENDER,
      text: 'Picked up from parked: A tmux indicator across sessions',
      detail: ['Before the release'],
    },
  ])
  expect(parseEntries(logs[W1]).map(entry => entry.type)).toEqual([
    ...POSTED.map(([, body]) => body.type),
    'delivered',
    'park',
    'reply',
    'delivered',
  ])
})

test('an undelivered pick-up adds no line to the log', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'p1', 'pickup')]) },
  })

  expect(session.log).toEqual([])
})

test('a parked item picked up twice is logged once: the second pick-up finds it picked', () => {
  const session = fold({
    logs: {
      [W1]: file(
        ...POSTED,
        ...sent(T0 + MIN, 'r1', 'p1', 'pickup'),
        ...sent(T0 + 2 * MIN, 'r2', 'p1', 'pickup'),
      ),
    },
  })

  expect(session.log.map(line => [line.kind, line.at])).toEqual([['pickup', T0 + MIN]])
})

test('a reply not yet delivered leaves its item as it was, but its ask, answered, no longer waits on Lee', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, reply('r2', 'p1', 'pickup')]),
    },
  })

  expect(session.asks.map(each => each.state)).toEqual(['waiting', 'waiting', 'waiting', 'waiting'])
  expect(session.asks[0]?.answer).toBeUndefined()
  expect(session.asks[0]?.replies.map(each => each.id)).toEqual(['r1'])
  expect(session.parked.map(each => each.id)).toEqual(['p1'])
  expect(session.waiting).toBe(3)
})

test('a reply sent from another session takes effect once its window writes the delivered mark', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0 + 5 * MIN, delivered('r1')]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(session.asks[0]).toMatchObject({ state: 'closed', closedAt: T0 + 5 * MIN })
  expect(session.replies[0]).toMatchObject({
    delivery: 'delivered',
    deliveredAt: T0 + 5 * MIN,
    by: SENDER,
  })
})

test('a delivered mark read before the reply it names still delivers it', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0 + MIN, delivered('r1')]) },
    inbox: { [SENDER]: file([T0 + 2 * MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(session.asks[0]?.state).toBe('closed')
})

test('only a writer in the session can mark a reply delivered: a mark in an inbox is ignored', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, delivered('r1')]) },
  })

  expect(session.asks[0]?.state).toBe('waiting')
  expect(session.replies[0]?.delivery).not.toBe('delivered')
})

for (const [why, body] of [
  ['a pick-up on an ask', reply('r1', 'k1', 'pickup')],
  ['a yes on a choice ask', reply('r1', 'k2', 'yes')],
  ['a choice on a yes ask', reply('r1', 'k1', 'choose', { option: '400 days' })],
  ['an answer on a yes ask', reply('r1', 'k1', 'answer', { note: 'Approved' })],
  ['a choice with no option', reply('r1', 'k2', 'choose')],
  ['a comment with no words', reply('r1', 'k1', 'comment', { note: '' })],
  ['an ignore on a parked item', reply('r1', 'p1', 'ignore')],
  ['a reply to no item', reply('r1', 'gone', 'yes')],
] as const) {
  test(`${why} fits nothing: it is neither kept nor sent`, () => {
    const session = fold({
      logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1')]) },
      inbox: { [SENDER]: file([T0 + MIN, body]) },
      presence: { [W1]: seen(W1, NOW) },
    })

    expect(session.replies).toEqual([])
    expect(session.waiting).toBe(4)
    expect(session.parked).toHaveLength(1)
    expect(toDeliver(session, W1)).toEqual([])
  })
}

test('a reply delivered after Claude closed the ask leaves it closed; a comment does not reopen it', () => {
  const session = fold({
    logs: {
      [W1]: file(
        ...POSTED,
        [T0 + 2 * MIN, resolve('k1', 'Approved in the chat')],
        [T0 + 3 * MIN, delivered('r1')],
      ),
    },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'comment', { note: 'One more thing' })]) },
  })

  expect(session.asks[0]).toMatchObject({
    state: 'closed',
    closedAt: T0 + 2 * MIN,
    reason: 'Approved in the chat',
  })
  expect(session.asks[0]?.answer).toBeUndefined()
})

test("Claude's resolve closes anything: a waiting ask, a replied one, a parked item", () => {
  const session = fold({
    logs: {
      [W1]: file(
        ...POSTED,
        ...sent(T0 + MIN, 'r1', 'k3', 'comment', { note: 'Fails after the code' }),
        [T0 + 2 * MIN, resolve('k1')],
        [T0 + 2 * MIN, resolve('k3')],
        [T0 + 2 * MIN, resolve('p1')],
      ),
    },
  })

  expect(['k1', 'k3', 'p1'].map(id => session.items.get(id)?.state)).toEqual([
    'closed',
    'closed',
    'closed',
  ])
  expect(session.parked).toEqual([])
})

test('waiting counts open asks with no delivered reply since they were opened or last reopened', () => {
  const at = (minutes: number) => T0 + minutes * MIN
  const steps: Array<[string, Line[], number, AskState]> = [
    ['posted', [[at(0), REVIEW]], 1, 'waiting'],
    ['commented on', sent(at(1), 'r1', 'k1', 'comment', { note: 'Too tall' }), 0, 'replied'],
    [
      'reopened once Claude acted on it',
      [[at(2), reopen('k1', 'Shortened the bar')]],
      1,
      'waiting',
    ],
    ['approved', sent(at(3), 'r2', 'k1', 'yes'), 0, 'closed'],
    ['reopened after closing', [[at(4), reopen('k1')]], 1, 'waiting'],
  ]
  const lines: Line[] = []

  for (const [why, more, waiting, state] of steps) {
    lines.push(...more)

    const session = fold({ logs: { [W1]: file(...lines) } })

    expect(session.waiting, why).toBe(waiting)
    expect(session.asks[0]?.state, why).toBe(state)
  }

  const reopened = fold({ logs: { [W1]: file(...lines) } }).asks[0]

  expect(reopened).toMatchObject({ openedAt: at(4), replies: [{ id: 'r1' }, { id: 'r2' }] })
  expect(reopened?.answer).toBeUndefined()
  expect(reopened?.closedAt).toBeUndefined()
})

test('a reopened parked item is parked again', () => {
  const session = fold({
    logs: {
      [W1]: file(...POSTED, ...sent(T0 + MIN, 'r1', 'p1', 'pickup'), [T0 + 2 * MIN, reopen('p1')]),
    },
  })

  expect(session.parked.map(each => [each.id, each.state, each.answer])).toEqual([
    ['p1', 'parked', undefined],
  ])
})

test("an ask's rule stands on its own: a closed ask stays as it is, whatever the verdict", () => {
  const session = fold({ logs: { [W1]: file([T0, REVIEW], [T0 + MIN, resolve('k1')]) } })
  const closed = session.asks[0]!

  expect((['yes', 'comment', 'ignore'] as const).map(verdict => askAfter(closed, verdict))).toEqual(
    ['closed', 'closed', 'closed'],
  )
})

const inboxed = (presence: Record<string, string>) =>
  fold({
    logs: { [W1]: file(...POSTED) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
    presence,
  })

for (const [why, presence, delivery] of [
  ['a window seen just now', { [W1]: seen(W1, NOW) }, 'waiting'],
  [
    'a window seen as long ago as a heartbeat may be',
    { [W1]: seen(W1, NOW - STALE_MS) },
    'waiting',
  ],
  ['a window gone quiet for longer', { [W1]: seen(W1, NOW - STALE_MS - 1) }, 'closed'],
  [
    'a window that let go',
    { [W1]: beat(W1, { attachedAt: T0, seenAt: NOW, leftAt: NOW }) },
    'closed',
  ],
  ['no window at all', {}, 'closed'],
] as const) {
  test(`an undelivered reply to a session with ${why} is ${delivery}`, () => {
    const session = inboxed(presence)

    expect(session.replies[0]?.delivery).toBe(delivery)
    expect(session.isOpen).toBe(delivery === 'waiting')
  })
}

test('the window attached longest delivers, so two windows never both submit', () => {
  const session = inboxed({
    [W1]: beat(W1, { attachedAt: T0 + 5 * MIN, seenAt: NOW }),
    [W2]: beat(W2, { attachedAt: T0 + 2 * MIN, seenAt: NOW - MIN }),
  })

  expect(session.deliverer).toBe(W2)
  expect(toDeliver(session, W2).map(each => each.id)).toEqual(['r1'])
  expect(toDeliver(session, W1)).toEqual([])
})

test('a window gone quiet or let go hands delivery to the next oldest; with none, no one delivers', () => {
  const quiet = seen(W1, T0)
  const left = beat(W1, { attachedAt: T0, seenAt: NOW, leftAt: NOW })
  const live = beat(W2, { attachedAt: T0 + 30 * MIN, seenAt: NOW })

  expect(deliverer([], NOW)).toBeUndefined()
  expect(inboxed({ [W1]: quiet, [W2]: live }).deliverer).toBe(W2)
  expect(inboxed({ [W1]: left, [W2]: live }).deliverer).toBe(W2)
  expect(inboxed({ [W1]: quiet }).deliverer).toBeUndefined()
})

test('while a live window on an old version is on a session, the longest attached of those delivers, and the rest wait', () => {
  const versioned = beat(W1, { attachedAt: T0, seenAt: NOW, version: '0.1.0' })
  const old = { attachedAt: T0 + 30 * MIN, seenAt: NOW }

  expect(inboxed({ [W1]: versioned, [W2]: beat(W2, old) }).deliverer).toBe(W2)
  expect(
    inboxed({ [W1]: versioned, [W2]: seen(W2, NOW - STALE_MS - 1) }).deliverer,
    'the old one gone quiet',
  ).toBe(W1)
  expect(
    inboxed({ [W1]: versioned, [W2]: beat(W2, { ...old, leftAt: NOW }) }).deliverer,
    'the old one let go',
  ).toBe(W1)
})

test('windows attached at the same moment elect by writer, the same way in every reader', () => {
  const presence = [
    { writer: W2, attachedAt: T0, seenAt: NOW },
    { writer: W1, attachedAt: T0, seenAt: NOW },
  ]

  expect(deliverer(presence, NOW)).toBe(W1)
  expect(deliverer([...presence].reverse(), NOW)).toBe(W1)
})

test('a delivered reply is never delivered again', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1')]) },
    inbox: {
      [SENDER]: file(
        [T0 + MIN, reply('r1', 'k1', 'yes')],
        [T0 + 3 * MIN, reply('r2', 'k4', 'yes')],
      ),
    },
    presence: { [W1]: seen(W1, NOW) },
  })

  expect(toDeliver(session, W1).map(each => each.id)).toEqual(['r2'])
})

test("Lee's message: one line per reply, in the spike's words, under From the board", () => {
  const session = fold({ logs: { [W1]: file(...POSTED) } })
  const message = boardMessage(session, [
    { item: 'k1', verdict: 'yes' },
    { item: 'k1', verdict: 'yes', note: 'Tighten the gutters' },
    { item: 'k3', verdict: 'yes' },
    { item: 'k4', verdict: 'yes' },
    { item: 'k2', verdict: 'choose', option: 'Forever' },
    { item: 'k2', verdict: 'comment', note: 'Two years, then archive' },
    { item: 'k1', verdict: 'comment', note: 'The runway bar is too tall' },
    { item: 'k4', verdict: 'ignore' },
    { item: 'p1', verdict: 'pickup' },
    { item: 'p1', verdict: 'pickup', note: 'Before the release' },
  ])

  expect(message?.text).toBe(
    [
      FROM_THE_BOARD,
      '- Review Sessions & Runway, round 1 → Approve',
      '- Review Sessions & Runway, round 1 → Approve, with a comment: “Tighten the gutters”',
      '- Try signing in on the iPad → It works',
      '- Run the production apply → Done',
      '- Keep the ledger 400 days, or forever? → Forever',
      '- Keep the ledger 400 days, or forever? → comment: “Two years, then archive”',
      '- Review Sessions & Runway, round 1 → comment: “The runway bar is too tall”',
      '- Run the production apply → ignored',
      '- Pick up from parked: A tmux indicator across sessions',
      '- Pick up from parked: A tmux indicator across sessions. Before the release',
    ].join('\n'),
  )
  expect(message?.text).not.toMatch(/\b(k[1-4]|p1|r\d)\b/)
  expect(message?.replies).toHaveLength(10)
})

test('the message leaves out replies that fit no item, and says which it carries; it is nothing when none fits', () => {
  const session = fold({ logs: { [W1]: file(...POSTED) } })

  expect(
    boardMessage(session, [
      { item: 'gone', verdict: 'yes' },
      { item: 'k1', verdict: 'pickup' },
    ]),
  ).toBeUndefined()
  expect(
    boardMessage(session, [
      { item: 'gone', verdict: 'yes' },
      { item: 'k1', verdict: 'yes' },
    ]),
  ).toEqual({
    text: `${FROM_THE_BOARD}\n- Review Sessions & Runway, round 1 → Approve`,
    replies: [{ item: 'k1', verdict: 'yes' }],
  })
})

test("under its item, the board shows a yes in its button's words and a choice after an arrow, and a pick-up in its own words, a note by its first line", () => {
  const session = fold({ logs: { [W1]: file(...POSTED) } })
  const [review, decide] = session.asks
  const parked = session.parked[0]!

  expect(answerOf(review!, { item: 'k1', verdict: 'yes' })).toBe('→ Approve')
  expect(answerOf(decide!, { item: 'k2', verdict: 'choose', option: 'Forever' })).toBe('→ Forever')
  expect(answerOf(decide!, { item: 'k2', verdict: 'ignore' })).toBe('ignored')
  expect(answerOf(parked, { item: 'p1', verdict: 'pickup' })).toBe('pick it up')
  expect(
    answerOf(parked, { item: 'p1', verdict: 'pickup', note: 'Before the release\nwith the band' }),
  ).toBe('pick it up, with a comment: “Before the release”')
})

test('replies sent into an inbox are delivered once every one is marked; until then they wait on the window, or for one', () => {
  const letters = {
    [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, reply('r2', 'k4', 'yes')]),
  }
  const marked = (...ids: string[]) =>
    fold({
      logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered(...ids)]) },
      inbox: letters,
      presence: { [W1]: seen(W1, NOW) },
    })

  expect(deliveryOf(marked('r1', 'r2'), ['r1', 'r2'])).toBe('delivered')
  expect(deliveryOf(marked('r1'), ['r1', 'r2'])).toBe('waiting')
  expect(deliveryOf(marked('r1'), ['r1'])).toBe('delivered')
  expect(deliveryOf(fold({ logs: { [W1]: file(...POSTED) }, inbox: letters }), ['r1'])).toBe(
    'closed',
  )
})

test('a reply the fold has not read yet is not delivered', () => {
  const session = fold({ logs: { [W1]: file(...POSTED) }, presence: { [W1]: seen(W1, NOW) } })

  expect(deliveryOf(session, ['r9'])).toBe('waiting')
})

/** An edit making k1, the review, a choice: a yes no longer fits it. */
const DECIDED: Body = {
  type: 'edit',
  item: 'k1',
  changes: { wants: 'choice', options: ['Now', 'Later'] },
}

test('a reply on its way whose item an edit changed past fitting goes void: a mark naming it changes nothing, and the item can be answered again', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED], [T0 + 3 * MIN, delivered('r1')]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
    presence: { [W1]: seen(W1, NOW) },
  })

  expect(session.replies).toMatchObject([{ id: 'r1', delivery: 'void', voidedAt: T0 + 2 * MIN }])
  expect(session.asks[0]?.state).toBe('waiting')
  expect(session.asks[0]?.answer).toBeUndefined()
  expect(session.waiting).toBe(4)
  expect(toDeliver(session, W1)).toEqual([])
  expect(deliveryOf(session, ['r1'])).toBe('void')
})

test('a void reply stays void, though its item changes back; one delivered before the edit stays delivered', () => {
  const back: Body = { type: 'edit', item: 'k1', changes: { wants: 'yes', yes: 'Approve' } }
  const voided = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED], [T0 + 3 * MIN, back]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
    presence: { [W1]: seen(W1, NOW) },
  })
  const delivers = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1')], [T0 + 3 * MIN, DECIDED]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(voided.replies[0]?.delivery).toBe('void')
  expect(toDeliver(voided, W1)).toEqual([])
  expect(delivers.replies[0]?.delivery).toBe('delivered')
  expect(delivers.asks[0]?.state).toBe('closed')
})

test('replies sent into an inbox are delivered once each is delivered or void; void when every one is', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED], [T0 + 3 * MIN, delivered('r2')]) },
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, reply('r2', 'k4', 'yes')]),
    },
    presence: { [W1]: seen(W1, NOW) },
  })

  expect(deliveryOf(session, ['r1', 'r2'])).toBe('delivered')
  expect(deliveryOf(session, ['r1'])).toBe('void')
})

test("the lines recording the session's own replies are each reply and one mark; none once their ids are written", () => {
  const replies = [
    { type: 'reply', id: 'r1', item: 'k1', verdict: 'yes' },
    { type: 'reply', id: 'r2', item: 'k4', verdict: 'ignore' },
  ] as const
  const before = fold({ logs: { [W1]: file(...POSTED) } })
  const after = fold({
    logs: {
      [W1]: file(...POSTED, ...sentLines(before, replies).map((body): Line => [T0 + MIN, body])),
    },
  })

  expect(sentLines(before, replies)).toEqual([...replies, delivered('r1', 'r2')])
  expect(sentLines(after, replies)).toEqual([])
  expect(after.asks.map(each => each.state)).toEqual(['closed', 'waiting', 'waiting', 'ignored'])
})

test('the mark for inbox replies names those not marked yet, and is nothing once every one is', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1')]) },
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, reply('r2', 'k4', 'yes')]),
    },
  })

  expect(deliveredMark(session, ['r1', 'r2'])).toEqual([delivered('r2')])
  expect(deliveredMark(session, ['r1'])).toEqual([])
})

/** Where Lee's answer to one of a session's asks stands. */
const standing = (session: Session, id: string) => {
  const ask = session.asks.find(each => each.id === id)

  return ask === undefined ? undefined : answerState(ask)
}

test('an answer written into an inbox is on its way, since it was sent; once marked it is delivered, since then, and has closed its ask', () => {
  const letters = {
    [SENDER]: file([T0 + MIN, reply('r1', 'k2', 'choose', { option: 'Forever' })]),
  }
  const sent = fold({ logs: { [W1]: file(...POSTED) }, inbox: letters })
  const marked = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1')]) },
    inbox: letters,
  })

  expect(standing(sent, 'k2')).toMatchObject({
    is: 'onItsWay',
    reply: { id: 'r1' },
    since: T0 + MIN,
  })
  expect(sent.asks[1]?.state).toBe('waiting')
  expect(standing(marked, 'k2')).toMatchObject({
    is: 'delivered',
    reply: { id: 'r1', option: 'Forever' },
    since: T0 + 2 * MIN,
  })
  expect(marked.asks[1]?.state).toBe('closed')
})

test('an ask has no answer standing with none sent, one gone void, a comment Claude has, or once Claude closed or reopened it', () => {
  const letters = { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) }
  const commented = sent(T0 + MIN, 'r1', 'k1', 'comment', { note: 'Tighten the gutters' })
  const cases: [string, Session][] = [
    ['none sent', fold({ logs: { [W1]: file(...POSTED) } })],
    ['void', fold({ logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED]) }, inbox: letters })],
    ['a comment', fold({ logs: { [W1]: file(...POSTED, ...commented) } })],
    [
      'resolved',
      fold({ logs: { [W1]: file(...POSTED, ...commented, [T0 + 2 * MIN, resolve('k1')]) } }),
    ],
    [
      'reopened',
      fold({
        logs: {
          [W1]: file(...POSTED, ...sent(T0 + MIN, 'r1', 'k1', 'yes'), [T0 + 2 * MIN, reopen('k1')]),
        },
      }),
    ],
  ]

  for (const [why, session] of cases) {
    expect(standing(session, 'k1'), why).toBeUndefined()
  }
})

test('of two replies on their way to one item, the first goes in and the second is void, never delivered: Claude has one answer', () => {
  const letters = {
    [CLI]: file(
      [T0 + MIN, reply('r1', 'k2', 'choose', { option: '400 days' })],
      [T0 + MIN, reply('r2', 'k2', 'choose', { option: 'Forever' })],
    ),
    [SENDER]: file([T0 + MIN, reply('r3', 'k2', 'ignore')]),
  }
  const presence = { [W1]: seen(W1, NOW) }
  const sent = fold({ logs: { [W1]: file(...POSTED) }, inbox: letters, presence })
  const marked = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1', 'r2', 'r3')]) },
    inbox: letters,
    presence,
  })

  expect(sent.replies.map(each => [each.id, each.delivery, each.voidedAt])).toEqual([
    ['r1', 'waiting', undefined],
    ['r2', 'void', T0 + MIN],
    ['r3', 'void', T0 + MIN],
  ])
  expect(boardMessage(sent, toDeliver(sent, W1))?.text).toBe(
    'From the board:\n- Keep the ledger 400 days, or forever? → 400 days',
  )
  expect(marked.asks[1]).toMatchObject({ state: 'closed', answer: { id: 'r1' } })
  expect(
    marked.replies.map(each => each.delivery),
    'a mark naming the void ones, as a window on an old release would write, changes nothing',
  ).toEqual(['delivered', 'void', 'void'])
})
