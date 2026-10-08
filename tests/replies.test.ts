import { expect, test } from 'claude-code/testing'
import {
  answerOf,
  askAfter,
  boardMessage,
  deliverer,
  deliveryOf,
  FROM_THE_BOARD,
  parseEntries,
  STALE_MS,
  toDeliver,
  type AskKind,
  type AskState,
  type Verdict,
} from '../core'
import {
  ask,
  beat,
  delivered,
  file,
  fold,
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
  type Line,
} from './support'

/** When the folds below look: an hour in. */
const NOW = T0 + 60 * MIN

const REVIEW = ask('k1', 'review', 'Review Sessions & Runway, round 1')
const DECIDE = ask('k2', 'decide', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever'])
const TRY = ask('k3', 'try', 'Try signing in on the iPad')
const DO = ask('k4', 'do', 'Run the production apply')
const PARKED = park('p1', 'A tmux indicator across sessions')

const POSTED: Line[] = [REVIEW, DECIDE, TRY, DO, PARKED].map(body => [T0, body])

const IDS: Record<AskKind, string> = { review: 'k1', decide: 'k2', try: 'k3', do: 'k4' }

/** A reply in this window's own file, delivered with it, as the mod writes one after Claude takes it. */
const sent = (at: number, id: string, item: string, verdict: Verdict, extra = {}): Line[] => [
  [at, reply(id, item, verdict, extra)],
  [at, delivered(id)],
]

/** Every kind of ask, and the replies it takes, with where each leaves it once delivered. */
const EFFECTS: Array<[AskKind, Verdict, { option?: string; note?: string }, AskState]> = [
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
]

for (const [kind, verdict, extra, after] of EFFECTS) {
  const how = `${verdict}${extra.note === undefined ? '' : ' with a note'}`

  test(`a delivered ${how} on a ${kind} ask leaves it ${after}`, () => {
    const work = fold({
      logs: { [W1]: file(...POSTED, ...sent(T0 + MIN, 'r1', IDS[kind], verdict, extra)) },
    })
    const answered = work.asks.find(each => each.id === IDS[kind])

    expect(answered?.state).toBe(after)
    expect(answered?.answer?.id).toBe('r1')
    expect(answered?.closedAt).toBe(after === 'replied' ? undefined : T0 + MIN)
    expect(work.waiting).toBe(3)
  })
}

test('a delivered pick-up marks a parked item picked up, and it leaves the parked list', () => {
  const work = fold({ logs: { [W1]: file(...POSTED, ...sent(T0 + MIN, 'r1', 'p1', 'pickup')) } })

  expect(work.items.get('p1')).toMatchObject({ state: 'picked' })
  expect(work.parked).toEqual([])
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
  const work = fold({
    logs,
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'p1', 'pickup', { note: 'Before the release' })]),
    },
  })

  expect(work.log).toEqual([
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
  const work = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'p1', 'pickup')]) },
  })

  expect(work.log).toEqual([])
})

test('a parked item picked up twice is logged once: the second pick-up finds it picked', () => {
  const work = fold({
    logs: {
      [W1]: file(
        ...POSTED,
        ...sent(T0 + MIN, 'r1', 'p1', 'pickup'),
        ...sent(T0 + 2 * MIN, 'r2', 'p1', 'pickup'),
      ),
    },
  })

  expect(work.log.map(line => [line.kind, line.at])).toEqual([['pickup', T0 + MIN]])
})

test('a reply not yet delivered changes nothing', () => {
  const work = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, reply('r2', 'p1', 'pickup')]),
    },
  })

  expect(work.asks.map(each => each.state)).toEqual(['waiting', 'waiting', 'waiting', 'waiting'])
  expect(work.asks[0]?.answer).toBeUndefined()
  expect(work.asks[0]?.replies.map(each => each.id)).toEqual(['r1'])
  expect(work.parked.map(each => each.id)).toEqual(['p1'])
  expect(work.waiting).toBe(4)
})

test('a reply sent from another work takes effect once its window writes the delivered mark', () => {
  const work = fold({
    logs: { [W1]: file(...POSTED, [T0 + 5 * MIN, delivered('r1')]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(work.asks[0]).toMatchObject({ state: 'closed', closedAt: T0 + 5 * MIN })
  expect(work.replies[0]).toMatchObject({
    delivery: 'delivered',
    deliveredAt: T0 + 5 * MIN,
    by: SENDER,
  })
})

test('a delivered mark read before the reply it names still delivers it', () => {
  const work = fold({
    logs: { [W1]: file(...POSTED, [T0 + MIN, delivered('r1')]) },
    inbox: { [SENDER]: file([T0 + 2 * MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(work.asks[0]?.state).toBe('closed')
})

test('only a writer in the work can mark a reply delivered: a mark in an inbox is ignored', () => {
  const work = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')], [T0 + MIN, delivered('r1')]) },
  })

  expect(work.asks[0]?.state).toBe('waiting')
  expect(work.replies[0]?.delivery).not.toBe('delivered')
})

for (const [why, body] of [
  ['a pick-up on an ask', reply('r1', 'k1', 'pickup')],
  ['a yes on a decide ask', reply('r1', 'k2', 'yes')],
  ['a choice with no option', reply('r1', 'k2', 'choose')],
  ['a comment with no words', reply('r1', 'k1', 'comment', { note: '' })],
  ['an ignore on a parked item', reply('r1', 'p1', 'ignore')],
  ['a reply to no item', reply('r1', 'gone', 'yes')],
] as const) {
  test(`${why} fits nothing: it is neither kept nor sent`, () => {
    const work = fold({
      logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1')]) },
      inbox: { [SENDER]: file([T0 + MIN, body]) },
      presence: { [W1]: seen(W1, NOW) },
    })

    expect(work.replies).toEqual([])
    expect(work.waiting).toBe(4)
    expect(work.parked).toHaveLength(1)
    expect(toDeliver(work, W1)).toEqual([])
  })
}

test('a reply delivered after Claude closed the ask leaves it closed; a comment does not reopen it', () => {
  const work = fold({
    logs: {
      [W1]: file(
        ...POSTED,
        [T0 + 2 * MIN, resolve('k1', 'Approved in the chat')],
        [T0 + 3 * MIN, delivered('r1')],
      ),
    },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'comment', { note: 'One more thing' })]) },
  })

  expect(work.asks[0]).toMatchObject({
    state: 'closed',
    closedAt: T0 + 2 * MIN,
    reason: 'Approved in the chat',
  })
  expect(work.asks[0]?.answer).toBeUndefined()
})

test("Claude's resolve closes anything: a waiting ask, a replied one, a parked item", () => {
  const work = fold({
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

  expect(['k1', 'k3', 'p1'].map(id => work.items.get(id)?.state)).toEqual([
    'closed',
    'closed',
    'closed',
  ])
  expect(work.parked).toEqual([])
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

    const work = fold({ logs: { [W1]: file(...lines) } })

    expect(work.waiting, why).toBe(waiting)
    expect(work.asks[0]?.state, why).toBe(state)
  }

  const reopened = fold({ logs: { [W1]: file(...lines) } }).asks[0]

  expect(reopened).toMatchObject({ openedAt: at(4), replies: [{ id: 'r1' }, { id: 'r2' }] })
  expect(reopened?.answer).toBeUndefined()
  expect(reopened?.closedAt).toBeUndefined()
})

test('a reopened parked item is parked again', () => {
  const work = fold({
    logs: {
      [W1]: file(...POSTED, ...sent(T0 + MIN, 'r1', 'p1', 'pickup'), [T0 + 2 * MIN, reopen('p1')]),
    },
  })

  expect(work.parked.map(each => [each.id, each.state, each.answer])).toEqual([
    ['p1', 'parked', undefined],
  ])
})

test("an ask's rule stands on its own: a closed ask stays as it is, whatever the verdict", () => {
  const work = fold({ logs: { [W1]: file([T0, REVIEW], [T0 + MIN, resolve('k1')]) } })
  const closed = work.asks[0]!

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
  test(`an undelivered reply to a work with ${why} is ${delivery}`, () => {
    const work = inboxed(presence)

    expect(work.replies[0]?.delivery).toBe(delivery)
    expect(work.isOpen).toBe(delivery === 'waiting')
  })
}

test('the window attached longest delivers, so two windows never both submit', () => {
  const work = inboxed({
    [W1]: beat(W1, { attachedAt: T0 + 5 * MIN, seenAt: NOW }),
    [W2]: beat(W2, { attachedAt: T0 + 2 * MIN, seenAt: NOW - MIN }),
  })

  expect(work.deliverer).toBe(W2)
  expect(toDeliver(work, W2).map(each => each.id)).toEqual(['r1'])
  expect(toDeliver(work, W1)).toEqual([])
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

test('windows attached at the same moment elect by writer, the same way in every reader', () => {
  const presence = [
    { writer: W2, attachedAt: T0, seenAt: NOW },
    { writer: W1, attachedAt: T0, seenAt: NOW },
  ]

  expect(deliverer(presence, NOW)).toBe(W1)
  expect(deliverer([...presence].reverse(), NOW)).toBe(W1)
})

test('a delivered reply is never delivered again', () => {
  const work = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1')]) },
    inbox: {
      [SENDER]: file(
        [T0 + MIN, reply('r1', 'k1', 'yes')],
        [T0 + 3 * MIN, reply('r2', 'k4', 'yes')],
      ),
    },
    presence: { [W1]: seen(W1, NOW) },
  })

  expect(toDeliver(work, W1).map(each => each.id)).toEqual(['r2'])
})

test("Lee's message: one line per reply, in the spike's words, under From the board", () => {
  const work = fold({ logs: { [W1]: file(...POSTED) } })
  const message = boardMessage(work, [
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

  expect(message).toBe(
    [
      FROM_THE_BOARD,
      '- Review Sessions & Runway, round 1 → approved',
      '- Review Sessions & Runway, round 1 → approved, with a comment: “Tighten the gutters”',
      '- Try signing in on the iPad → it works',
      '- Run the production apply → done',
      '- Keep the ledger 400 days, or forever? → Forever',
      '- Keep the ledger 400 days, or forever? → answer: “Two years, then archive”',
      '- Review Sessions & Runway, round 1 → comment: “The runway bar is too tall”',
      '- Run the production apply → ignored',
      '- Pick up from parked: A tmux indicator across sessions',
      '- Pick up from parked: A tmux indicator across sessions. Before the release',
    ].join('\n'),
  )
  expect(message).not.toMatch(/\b(k[1-4]|p1|r\d)\b/)
})

test('the message leaves out replies that fit no item, and is nothing when none fits', () => {
  const work = fold({ logs: { [W1]: file(...POSTED) } })

  expect(
    boardMessage(work, [
      { item: 'gone', verdict: 'yes' },
      { item: 'k1', verdict: 'pickup' },
    ]),
  ).toBeUndefined()
  expect(
    boardMessage(work, [
      { item: 'gone', verdict: 'yes' },
      { item: 'k1', verdict: 'yes' },
    ]),
  ).toBe(`${FROM_THE_BOARD}\n- Review Sessions & Runway, round 1 → approved`)
})

test('under its item, the board shows a choice after an arrow and a pick-up in its own words', () => {
  const work = fold({ logs: { [W1]: file(...POSTED) } })
  const decide = work.asks[1]!
  const parked = work.parked[0]!

  expect(answerOf(decide, { item: 'k2', verdict: 'choose', option: 'Forever' })).toBe('→ Forever')
  expect(answerOf(decide, { item: 'k2', verdict: 'ignore' })).toBe('ignored')
  expect(answerOf(parked, { item: 'p1', verdict: 'pickup' })).toBe('pick it up')
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
  const work = fold({ logs: { [W1]: file(...POSTED) }, presence: { [W1]: seen(W1, NOW) } })

  expect(deliveryOf(work, ['r9'])).toBe('waiting')
})
