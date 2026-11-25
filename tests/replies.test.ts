import { expect, test } from './kit'
import {
  answerOf,
  barredBy,
  boardMessage,
  checkEdit,
  checkSnoozeAsk,
  deliveredMark,
  deliverer,
  deliveryOf,
  FROM_THE_BOARD,
  messageText,
  parseEntries,
  replyState,
  sentLines,
  STALE_MS,
  standingComment,
  takenOff,
  toDeliver,
  waitsOnLee,
  type AskKind,
  type AskState,
  type Barred,
  type Body,
  type ReplyFields,
  type Session,
  type SessionFiles,
  type Verdict,
} from '../core'
import { CLI, MIN, SENDER, T0, W1, W2 } from './data'
import {
  beat,
  choiceAsk,
  delivered,
  file,
  finish,
  fold,
  kindAsk,
  oldNote,
  park,
  reopen,
  reply,
  resolve,
  seen,
  snooze,
  snoozeSession,
  status,
  wordsAsk,
  yesAsk,
  type Line,
} from './lines'

/** When the folds below look: an hour in. */
const NOW = T0 + 60 * MIN

const REVIEW = yesAsk('k1', 'Review Tickets & Replies, round 1', 'Approve')
const DECIDE = choiceAsk('k2', 'Keep the ledger 400 days, or forever?', ['400 days', 'Forever'])
const TRY = yesAsk('k3', 'Try signing in on the iPad', 'It works')
const DO = yesAsk('k4', 'Run the production apply', 'Done')
const PARKED = park('p1', 'A priority badge across all tabs')

const POSTED: Line[] = [REVIEW, DECIDE, TRY, DO, PARKED].map(body => [T0, body])

/** An ask wanting words, and one wanting a yes, for the shapes' own rules. */
const WORDS = wordsAsk('k5', 'Run sitrep list and paste what it prints', "the command's output")
const GO = yesAsk('k6', 'Give the ok for phase 3', 'Go')

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

  const says = after === 'replied' ? 'open' : 'closed'

  test(`Lee's message under a ${how} on an ask wanting ${SHAPES[id]} says it leaves the ask ${says}`, () => {
    const session = fold({ logs: { [W1]: file(...SHAPED) } })
    const lines = boardMessage(session, [{ item: id, verdict, ...extra }])?.text.split('\n')

    expect(lines?.at(-1)).toBe(
      says === 'open'
        ? '  This leaves the ask open: act on it, then resolve it, or reword it with edit to hand it back to the user.'
        : '  This closes the ask: nothing more to do with it.',
    )
  })
}

/** Asks as written before asks said what they want back, by their kinds, one needing something back. */
const KINDS: Record<AskKind, Body> = {
  review: kindAsk('o1', 'review', 'Review Tickets & Replies, round 1'),
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
  ['review', 'comment', { note: 'The macros bar is too tall' }, 'replied'],
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
      '- Review Tickets & Replies, round 1 → Approve',
      '  This closes the ask: nothing more to do with it.',
      '- Try signing in on the iPad → It works, with a comment: “On the iPad mini too”',
      '  This closes the ask: nothing more to do with it.',
      '- Keep the ledger 400 days, or forever? → answer: “Two years, then archive”',
      '  This closes the ask: nothing more to do with it.',
      "- Run the export → Done, with the command's output: “v1.2.3”",
      '  This closes the ask: nothing more to do with it.',
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

test('each pick-up one send delivers takes its item off Parked at its time, each with its own reply', () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, park('p1', 'One')],
        [T0, park('p2', 'Two')],
        [T0 + MIN, reply('r1', 'p1', 'pickup')],
        [T0 + MIN, reply('r2', 'p2', 'pickup', { note: 'After the fix' })],
        [T0 + MIN, delivered('r1', 'r2')],
      ),
    },
  })

  expect(takenOff(session).map(each => [each.id, each.closedAt, each.answer?.id])).toEqual([
    ['p1', T0 + MIN, 'r1'],
    ['p2', T0 + MIN, 'r2'],
  ])
})

test('a delivered pick-up marks a parked item picked up, and it leaves the parked list', () => {
  const session = fold({ logs: { [W1]: file(...POSTED, ...sent(T0 + MIN, 'r1', 'p1', 'pickup')) } })

  expect(session.items.get('p1')).toMatchObject({ state: 'picked' })
  expect(session.parked).toEqual([])
})

test('a delivered pick-up takes its item off Parked by the reply that picked it up, Lee’s note with it, and nothing is written down for it', () => {
  const logs = {
    [W1]: file(
      ...POSTED,
      [T0 + 2 * MIN, delivered('r1')],
      [T0 + 3 * MIN, park('p2', 'Thumbnails inline in the gallery')],
      ...sent(T0 + 4 * MIN, 'r2', 'p2', 'pickup'),
    ),
  }
  const session = fold({
    logs,
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'p1', 'pickup', { note: 'Before the release' })]),
    },
  })

  expect(
    takenOff(session).map(each => [each.id, each.state, each.closedAt, each.answer?.by]),
    'the newest taken off first',
  ).toEqual([
    ['p2', 'picked', T0 + 4 * MIN, W1],
    ['p1', 'picked', T0 + 2 * MIN, SENDER],
  ])
  expect(session.items.get('p1')).toMatchObject({ answer: { note: 'Before the release' } })
  expect(parseEntries(logs[W1]).map(entry => entry.type)).toEqual([
    ...POSTED.map(([, body]) => body.type),
    'delivered',
    'park',
    'reply',
    'delivered',
  ])
})

test('an undelivered pick-up takes nothing off Parked', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'p1', 'pickup')]) },
  })

  expect(takenOff(session)).toEqual([])
  expect(session.parked.map(each => each.id)).toEqual(['p1'])
})

test('a parked item picked up twice keeps its first pick-up: the second finds it picked', () => {
  const session = fold({
    logs: {
      [W1]: file(
        ...POSTED,
        ...sent(T0 + MIN, 'r1', 'p1', 'pickup'),
        ...sent(T0 + 2 * MIN, 'r2', 'p1', 'pickup'),
      ),
    },
  })

  expect(session.items.get('p1')).toMatchObject({
    state: 'picked',
    closedAt: T0 + MIN,
    answer: { id: 'r1' },
  })
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

test('a second mark for a delivered reply changes nothing: the first mark stands', () => {
  const session = fold({
    logs: {
      [W1]: file(...POSTED, [T0 + 3 * MIN, delivered('r1')], [T0 + 5 * MIN, delivered('r1')]),
    },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(session.replies[0]).toMatchObject({ delivery: 'delivered', deliveredAt: T0 + 3 * MIN })
  expect(session.asks[0]).toMatchObject({ state: 'closed', closedAt: T0 + 3 * MIN })
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
] as const) {
  test(`${why} fits nothing: it is void as it arrives, never sent, and a mark naming it settles nothing`, () => {
    const letters = { [SENDER]: file([T0 + MIN, body]) }
    const presence = { [W1]: seen(W1, NOW) }
    const arrived = fold({ logs: { [W1]: file(...POSTED) }, inbox: letters, presence })
    const marked = fold({
      logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r1')]) },
      inbox: letters,
      presence,
    })

    expect(arrived.replies).toMatchObject([{ delivery: 'void', voided: 'changed' }])
    expect(toDeliver(arrived, W1)).toEqual([])
    expect(marked.replies).toMatchObject([{ delivery: 'delivered', voided: 'changed' }])
    expect(marked.waiting).toBe(4)
    expect(marked.parked).toHaveLength(1)
  })
}

test('a reply to no item, or to a note as one was written before notes went, is never kept', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0, oldNote('n1', 'Drew it')]) },
    inbox: {
      [SENDER]: file([T0 + MIN, reply('r1', 'gone', 'yes')], [T0 + MIN, reply('r2', 'n1', 'yes')]),
    },
  })

  expect(session.replies).toEqual([])
})

test('a reply whose id an item already holds is never kept: the item keeps the id, unanswered', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: { [SENDER]: file([T0 + MIN, reply('p1', 'k1', 'yes')]) },
  })

  expect(session.replies).toEqual([])
  expect(session.asks[0]).toMatchObject({ id: 'k1', state: 'waiting', replies: [] })
  expect(session.items.get('p1')?.type).toBe('park')
})

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

/** Lee's comment on k3, the iPad sign-in, delivered: the ask stands replied, Claude's to act on. */
const COMMENTED_ON: Line[] = sent(T0 + MIN, 'r1', 'k3', 'comment', { note: 'What does this need?' })

/** An edit to k3 rewording its title. */
const RETITLED_TRY: Body = {
  type: 'edit',
  item: 'k3',
  changes: { title: 'Sign in on the iPad, then say' },
}

/** Every field Claude's edit can reword an ask by, each an edit to k3. */
const REWORDINGS: Array<[string, Body]> = [
  ['its title', RETITLED_TRY],
  ['where to look', { type: 'edit', item: 'k3', changes: { where: 'On the iPad mini' } }],
  ["its yes's words", { type: 'edit', item: 'k3', changes: { yes: 'Signed in' } }],
  [
    'what it wants, a choice',
    { type: 'edit', item: 'k3', changes: { wants: 'choice', options: ['Works', 'Fails'] } },
  ],
  [
    'what it wants, words, and what it needs',
    { type: 'edit', item: 'k3', changes: { wants: 'words', needs: 'what the screen says' } },
  ],
]

const k3Of = (session: Session) => session.asks.find(ask => ask.id === 'k3')

for (const [what, edit] of REWORDINGS) {
  test(`Claude's edit to ${what} of an ask Lee commented on hands it back: it waits on Lee again from the edit, the comment kept as what he said before`, () => {
    const session = fold({ logs: { [W1]: file(...POSTED, ...COMMENTED_ON, [T0 + 2 * MIN, edit]) } })
    const ask = k3Of(session)

    expect(ask).toMatchObject({ state: 'waiting', openedAt: T0 + 2 * MIN })
    expect(ask && waitsOnLee(ask)).toBe(true)
    expect(session.waiting).toBe(4)
    expect(ask && standingComment(ask)).toBe('What does this need?')
    expect(ask && replyState(ask)).toBeUndefined()
  })
}

test('an ask handed back takes a snooze of its own, refused while it stood replied', () => {
  const lines: Line[] = [...POSTED, ...COMMENTED_ON]
  const commented = fold({ logs: { [W1]: file(...lines) } })
  const handedBack = fold({ logs: { [W1]: file(...lines, [T0 + 2 * MIN, RETITLED_TRY]) } })
  const snoozed = fold({
    logs: {
      [W1]: file(...lines, [T0 + 2 * MIN, RETITLED_TRY], [T0 + 3 * MIN, snooze('k3', NOW + MIN)]),
    },
  })

  expect(checkSnoozeAsk(commented, 'k3', NOW + MIN, NOW).ok).toBe(false)
  expect(checkSnoozeAsk(handedBack, 'k3', NOW + MIN, NOW).ok).toBe(true)
  expect(k3Of(snoozed)?.snoozedUntil).toBe(NOW + MIN)
})

test("an ask handed back wakes Lee's snooze of the session, as one reopened does, and it stays woken once he comments again", () => {
  const snoozedThen: Line[] = [
    ...POSTED,
    ...COMMENTED_ON,
    [T0 + 2 * MIN, snoozeSession(NOW + 60 * MIN, 'k1', 'k2', 'k4')],
  ]
  const asleep = fold({ logs: { [W1]: file(...snoozedThen) } })
  const handedBack = fold({
    logs: {
      [W1]: file(
        ...snoozedThen,
        [T0 + 3 * MIN, RETITLED_TRY],
        ...sent(T0 + 4 * MIN, 'r2', 'k3', 'comment', { note: 'Still unclear' }),
      ),
    },
  })

  expect(asleep.snooze).toBeDefined()
  expect(handedBack.snooze).toBeUndefined()
  expect(k3Of(handedBack)?.state).toBe('replied')
})

test('an edit hands back only an ask standing replied: one waiting stays as it was, its time from its posting; one closed or ignored stays closed or ignored', () => {
  const session = fold({
    logs: {
      [W1]: file(
        ...POSTED,
        ...sent(T0 + MIN, 'r1', 'k2', 'choose', { option: 'Forever' }),
        ...sent(T0 + MIN, 'r2', 'k4', 'ignore'),
        ...sent(T0 + MIN, 'r3', 'k3', 'comment', { note: 'Fails after the code' }),
        [T0 + 2 * MIN, resolve('k3')],
        [T0 + 3 * MIN, { type: 'edit', item: 'k1', changes: { title: 'Review round 1' } }],
        [T0 + 3 * MIN, { type: 'edit', item: 'k2', changes: { title: 'Keep the ledger forever' } }],
        [T0 + 3 * MIN, { type: 'edit', item: 'k4', changes: { title: 'Run the apply' } }],
        [T0 + 3 * MIN, RETITLED_TRY],
      ),
    },
  })

  expect(session.asks.map(ask => [ask.id, ask.state, ask.openedAt])).toEqual([
    ['k1', 'waiting', T0],
    ['k2', 'closed', T0],
    ['k3', 'closed', T0],
    ['k4', 'ignored', T0],
  ])
})

test("Lee's comment still on its way as Claude edits the ask hands nothing back: the ask waits on the comment, and once delivered stands replied, Claude's to act on", () => {
  const letters = {
    [SENDER]: file([T0 + MIN, reply('r1', 'k3', 'comment', { note: 'What does this need?' })]),
  }
  const presence = { [W1]: seen(W1, NOW) }
  const lines: Line[] = [...POSTED, [T0 + 2 * MIN, RETITLED_TRY]]
  const edited = fold({ logs: { [W1]: file(...lines) }, inbox: letters, presence })
  const marked = fold({
    logs: { [W1]: file(...lines, [T0 + 3 * MIN, delivered('r1')]) },
    inbox: letters,
    presence,
  })
  const onItsWay = k3Of(edited)

  expect(onItsWay).toMatchObject({ state: 'waiting', openedAt: T0 })
  expect(onItsWay && waitsOnLee(onItsWay)).toBe(false)
  expect(edited.replies).toMatchObject([{ id: 'r1', delivery: 'waiting' }])
  expect(k3Of(marked)).toMatchObject({ state: 'replied', answer: { id: 'r1' } })
})

test("an ask handed back with Lee's second comment on its way waits on that comment, and stands replied again once it is delivered", () => {
  const letters = {
    [SENDER]: file([T0 + 2 * MIN, reply('r2', 'k3', 'comment', { note: 'Never mind' })]),
  }
  const presence = { [W1]: seen(W1, NOW) }
  const lines: Line[] = [...POSTED, ...COMMENTED_ON, [T0 + 3 * MIN, RETITLED_TRY]]
  const edited = fold({ logs: { [W1]: file(...lines) }, inbox: letters, presence })
  const marked = fold({
    logs: { [W1]: file(...lines, [T0 + 4 * MIN, delivered('r2')]) },
    inbox: letters,
    presence,
  })
  const onItsWay = k3Of(edited)

  expect(onItsWay).toMatchObject({ state: 'waiting', openedAt: T0 + 3 * MIN })
  expect(onItsWay && waitsOnLee(onItsWay)).toBe(false)
  expect(k3Of(marked)).toMatchObject({ state: 'replied', answer: { id: 'r2', note: 'Never mind' } })
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

test('a live window saying no version delivers as any window does: by when it attached', () => {
  const versioned = beat(W1, { attachedAt: T0, seenAt: NOW, version: '0.1.0' })
  const unversioned = beat(W2, { attachedAt: T0 + 30 * MIN, seenAt: NOW })

  expect(inboxed({ [W1]: versioned, [W2]: unversioned }).deliverer).toBe(W1)
  expect(inboxed({ [W2]: unversioned }).deliverer).toBe(W2)
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

test("Lee's message: one line per reply, in the spike's words, under From the board, and under each ask's last reply where the message leaves it", () => {
  const session = fold({ logs: { [W1]: file(...POSTED) } })
  const message = boardMessage(session, [
    { item: 'k1', verdict: 'yes' },
    { item: 'k1', verdict: 'yes', note: 'Tighten the gutters' },
    { item: 'k3', verdict: 'yes' },
    { item: 'k4', verdict: 'yes' },
    { item: 'k2', verdict: 'choose', option: 'Forever' },
    { item: 'k2', verdict: 'comment', note: 'Two years, then archive' },
    { item: 'k1', verdict: 'comment', note: 'The macros bar is too tall' },
    { item: 'k4', verdict: 'ignore' },
    { item: 'p1', verdict: 'pickup' },
    { item: 'p1', verdict: 'pickup', note: 'Before the release' },
  ])

  expect(message?.text).toBe(
    [
      FROM_THE_BOARD,
      '- Review Tickets & Replies, round 1 → Approve',
      '- Review Tickets & Replies, round 1 → Approve, with a comment: “Tighten the gutters”',
      '- Try signing in on the iPad → It works',
      '  This closes the ask: nothing more to do with it.',
      '- Run the production apply → Done',
      '- Keep the ledger 400 days, or forever? → Forever',
      '- Keep the ledger 400 days, or forever? → comment: “Two years, then archive”',
      '  This closes the ask: nothing more to do with it.',
      '- Review Tickets & Replies, round 1 → comment: “The macros bar is too tall”',
      '  This closes the ask: nothing more to do with it.',
      '- Run the production apply → ignored',
      '  This closes the ask: nothing more to do with it.',
      '- Pick up from parked: A priority badge across all tabs',
      '- Pick up from parked: A priority badge across all tabs. Before the release',
    ].join('\n'),
  )
  expect(message?.text).not.toMatch(/\b(k[1-4]|p1|r\d)\b/)
  expect(message?.replies).toHaveLength(10)
})

test("an answer and a comment to one ask in one message say once, under the last, that the message closes it, in either order", () => {
  const session = fold({ logs: { [W1]: file(...POSTED) } })
  const lines = (...replies: ReplyFields[]) => boardMessage(session, replies)?.text.split('\n')

  expect(
    lines(
      { item: 'k1', verdict: 'yes' },
      { item: 'k1', verdict: 'comment', note: 'Thinner bars' },
    ),
  ).toEqual([
    FROM_THE_BOARD,
    '- Review Tickets & Replies, round 1 → Approve',
    '- Review Tickets & Replies, round 1 → comment: “Thinner bars”',
    '  This closes the ask: nothing more to do with it.',
  ])
  expect(
    lines(
      { item: 'k1', verdict: 'comment', note: 'Thinner bars' },
      { item: 'k1', verdict: 'yes' },
    ),
  ).toEqual([
    FROM_THE_BOARD,
    '- Review Tickets & Replies, round 1 → comment: “Thinner bars”',
    '- Review Tickets & Replies, round 1 → Approve',
    '  This closes the ask: nothing more to do with it.',
  ])
})

test('in one message, each ask says where the message leaves it alone: a yes closing one, a comment leaving another open', () => {
  const session = fold({ logs: { [W1]: file(...POSTED) } })

  expect(
    boardMessage(session, [
      { item: 'k1', verdict: 'yes' },
      { item: 'k3', verdict: 'comment', note: 'It fails on the iPad mini' },
    ])?.text,
  ).toBe(
    [
      FROM_THE_BOARD,
      '- Review Tickets & Replies, round 1 → Approve',
      '  This closes the ask: nothing more to do with it.',
      '- Try signing in on the iPad → comment: “It fails on the iPad mini”',
      '  This leaves the ask open: act on it, then resolve it, or reword it with edit to hand it back to the user.',
    ].join('\n'),
  )
})

test("a comment on an ask whose answer is on its way apart from the message says that answer closes it, never that the ask is open; the answer's own message says it closes", () => {
  const session = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(session.items.get('k1')).toMatchObject({ answerOnItsWay: { id: 'r1' } })
  expect(
    boardMessage(session, [{ item: 'k1', verdict: 'comment', note: 'Thinner bars' }])?.text,
  ).toBe(
    [
      FROM_THE_BOARD,
      '- Review Tickets & Replies, round 1 → comment: “Thinner bars”',
      "  An answer from the user to this ask, sent apart from this message, closes it.",
    ].join('\n'),
  )
  expect(boardMessage(session, [{ item: 'k1', verdict: 'yes' }])?.text.split('\n').at(-1)).toBe(
    '  This closes the ask: nothing more to do with it.',
  )
})

test("a pick-up of an item another session of the project parked goes in the message read in that session, naming whose it was; one of the session's own names none", () => {
  const session = fold({ logs: { [W1]: file(...POSTED) } })
  const ledger = {
    ...fold({
      logs: {
        [W2]: file(
          [T0, status([], { name: 'Invoice ledger' })],
          [T0, park('p1', 'Export the ledger as CSV')],
        ),
      },
    }),
    id: 'sr-1edger',
  }
  const replies = [
    { session: session.id, item: 'p1', verdict: 'pickup' },
    { session: ledger.id, item: 'p1', verdict: 'pickup', note: 'With the totals' },
  ] as const
  const message = boardMessage(session, replies, reply =>
    reply.session === ledger.id ? ledger : session,
  )

  expect(message?.text).toBe(
    [
      FROM_THE_BOARD,
      '- Pick up from parked: A priority badge across all tabs',
      "- Pick up from parked, Invoice ledger's: Export the ledger as CSV. With the totals",
    ].join('\n'),
  )
  expect(message?.text).not.toMatch(/sr-1edger/)
  expect(message?.replies).toEqual(replies)
})

test("the message leaves out replies that fit no item, and says which it carries and each one's line in it, its text the lines under From the board; it is nothing when none fits", () => {
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
    text: [
      FROM_THE_BOARD,
      '- Review Tickets & Replies, round 1 → Approve',
      '  This closes the ask: nothing more to do with it.',
    ].join('\n'),
    lines: [
      '- Review Tickets & Replies, round 1 → Approve\n  This closes the ask: nothing more to do with it.',
    ],
    replies: [{ item: 'k1', verdict: 'yes' }],
  })
  expect(messageText(['- one', '- two'])).toBe(`${FROM_THE_BOARD}\n- one\n- two`)
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

/** An edit to k1, the review, that every reply to it still fits. */
const RETITLED: Body = { type: 'edit', item: 'k1', changes: { title: 'Review round 1, again' } }

/** An edit making k1 want a yes again, after DECIDED. */
const REVIEWED: Body = { type: 'edit', item: 'k1', changes: { wants: 'yes', yes: 'Approve' } }

/** An edit making k1 want words, which an ignore still answers. */
const WORDED: Body = { type: 'edit', item: 'k1', changes: { wants: 'words' } }

test('a reply an edit voided keeps when it went void, whatever later edits leave it', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED], [T0 + 3 * MIN, RETITLED]) },
    inbox: { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(session.replies[0]).toMatchObject({ voided: 'changed', voidedAt: T0 + 2 * MIN })
})

test('a reply on its way whose item an edit changed past fitting goes void; a mark naming it says Claude has it, but it settles nothing, and the item can be answered again', () => {
  const letters = { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) }
  const presence = { [W1]: seen(W1, NOW) }
  const edited = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED]) },
    inbox: letters,
    presence,
  })
  const marked = fold({
    logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED], [T0 + 3 * MIN, delivered('r1')]) },
    inbox: letters,
    presence,
  })

  expect(edited.replies).toMatchObject([
    { id: 'r1', delivery: 'void', voided: 'changed', voidedAt: T0 + 2 * MIN },
  ])
  expect(toDeliver(edited, W1)).toEqual([])
  expect(deliveryOf(edited, ['r1'])).toBe('void')
  expect(marked.replies).toMatchObject([
    { id: 'r1', delivery: 'delivered', deliveredAt: T0 + 3 * MIN, voided: 'changed' },
  ])
  expect(deliveryOf(marked, ['r1'])).toBe('delivered')
  expect(marked.asks[0]?.state).toBe('waiting')
  expect(marked.asks[0]?.answer).toBeUndefined()
  expect(marked.waiting).toBe(4)
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

  return ask === undefined ? undefined : replyState(ask)
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

test('an ask has no answer standing with none sent, one gone void, before Claude closed it too, a comment Claude has, or once Claude closed or reopened it', () => {
  const letters = { [SENDER]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) }
  const commented = sent(T0 + MIN, 'r1', 'k1', 'comment', { note: 'Tighten the gutters' })
  const cases: [string, Session][] = [
    ['none sent', fold({ logs: { [W1]: file(...POSTED) } })],
    ['void', fold({ logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED]) }, inbox: letters })],
    [
      'reopened, an older reply marked since',
      fold({
        logs: {
          [W1]: file(
            ...POSTED,
            [T0 + 3 * MIN, delivered('r1')],
            [T0 + 4 * MIN, reopen('k1')],
            [T0 + 5 * MIN, delivered('r2')],
          ),
        },
        inbox: {
          [SENDER]: file(
            [T0 + MIN, reply('r1', 'k1', 'yes')],
            [T0 + 2 * MIN, reply('r2', 'k1', 'ignore')],
          ),
        },
      }),
    ],
    [
      'void, then resolved',
      fold({
        logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, DECIDED], [T0 + 3 * MIN, resolve('k1')]) },
        inbox: letters,
      }),
    ],
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

test("on an ask Lee's answer or ignore closed, that is its standing: a comment still on its way to it says nothing", () => {
  for (const verdict of ['yes', 'ignore'] as const) {
    const session = fold({
      logs: { [W1]: file(...POSTED, [T0 + 2 * MIN, delivered('r2')]) },
      inbox: {
        [CLI]: file(
          [T0 + MIN, reply('r1', 'k1', 'comment', { note: 'Tighten the copy first' })],
          [T0 + MIN, reply('r2', 'k1', verdict)],
        ),
      },
    })

    expect(
      session.replies.map(each => [each.id, each.delivery]),
      verdict,
    ).toEqual([
      ['r1', 'closed'],
      ['r2', 'delivered'],
    ])
    expect(standing(session, 'k1'), verdict).toMatchObject({
      is: 'delivered',
      reply: { id: 'r2' },
      since: T0 + 2 * MIN,
    })
  }
})

test("an open ask with Lee's answer on its way, and a comment after it, reads the answer on its way", () => {
  const session = fold({
    logs: { [W1]: file(...POSTED) },
    inbox: {
      [CLI]: file(
        [T0 + MIN, reply('r1', 'k1', 'yes')],
        [T0 + 2 * MIN, reply('r2', 'k1', 'comment', { note: 'Tighten the copy first' })],
      ),
    },
  })

  expect(standing(session, 'k1')).toMatchObject({
    is: 'onItsWay',
    reply: { id: 'r1' },
    since: T0 + MIN,
  })
})

test('an open ask whose answer reached Claude after an edit it no longer fits reads delivered: Claude has it, and the ask waits on Lee in its new shape', () => {
  const session = fold({
    logs: { [W1]: file(...POSTED, [T0 + MIN, DECIDED], ...sent(T0 + 2 * MIN, 'r1', 'k1', 'yes')) },
  })

  expect(session.asks[0]?.state).toBe('waiting')
  expect(standing(session, 'k1')).toMatchObject({
    is: 'delivered',
    reply: { id: 'r1' },
    since: T0 + 2 * MIN,
  })
})

test("Lee's yes on its way as Claude reopens a replied ask is Lee's answer on its way until marked: it bars another, and the ask waits on Lee no more", () => {
  const logs: Line[] = [
    [T0, REVIEW],
    ...sent(T0 + MIN, 'c1', 'k1', 'comment', { note: 'Tighten the copy first' }),
    [T0 + 3 * MIN, reopen('k1')],
  ]
  const letters = { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k1', 'yes')]) }
  const before = fold({ logs: { [W1]: file(...logs) }, inbox: letters })
  const marked = fold({
    logs: { [W1]: file(...logs, [T0 + 4 * MIN, delivered('r1')]) },
    inbox: letters,
  })

  expect(before.asks[0]).toMatchObject({ state: 'waiting', answerOnItsWay: { id: 'r1' } })
  expect(standing(before, 'k1')).toMatchObject({
    is: 'onItsWay',
    isAnswer: true,
    reply: { id: 'r1' },
  })
  expect(barredBy(before.asks[0]!, 'yes')).toBe('answered')
  expect(before.waiting).toBe(0)
  expect(marked.asks[0]).toMatchObject({
    state: 'closed',
    closedBy: 'answer',
    answer: { id: 'r1' },
  })
  expect(standing(marked, 'k1')).toMatchObject({ is: 'delivered', reply: { id: 'r1' } })
})

test('an answer barred keeps when it went void while the answer that barred it stays on its way, whatever else goes void meanwhile', () => {
  const worded: Line = [
    T0 + 4 * MIN,
    { type: 'edit', item: 'k1', changes: { wants: 'words' } } as Body,
  ]
  const session = fold({
    logs: { [W1]: file(...POSTED, worded) },
    inbox: {
      [CLI]: file(
        [T0 + MIN, reply('r1', 'k1', 'ignore')],
        [T0 + 2 * MIN, reply('r2', 'k1', 'ignore')],
        [T0 + 3 * MIN, reply('r3', 'k1', 'comment', { note: 'Tighten the copy first' })],
      ),
    },
  })

  expect(session.asks[0]?.answerOnItsWay?.id).toBe('r1')
  expect(session.replies.map(each => [each.id, each.voided, each.voidedAt])).toEqual([
    ['r1', undefined, undefined],
    ['r2', 'answered', T0 + 2 * MIN],
    ['r3', 'changed', T0 + 4 * MIN],
  ])
})

test('a reply settled at the moment its closed ask reopens is history only if it settled first, in the order every reader reads', () => {
  const at = T0 + 2 * MIN
  const closed: Line[] = [[T0, REVIEW], ...sent(T0 + MIN, 'r0', 'k1', 'yes')]
  const later = { [CLI]: file([T0 + 3 * MIN, reply('r2', 'k1', 'yes')]) }
  const late = (sender: string) => ({ [sender]: file([at, reply('r1', 'k1', 'ignore')]) })
  const settledFirst = fold({
    logs: { [W1]: file(...closed, [T0 + 4 * MIN, DECIDED]), [W2]: file([at, reopen('k1')]) },
    inbox: { ...late(W1), ...later },
  })
  const reopenedFirst = fold({
    logs: { [W1]: file(...closed, [at, reopen('k1')], [T0 + 4 * MIN, DECIDED]) },
    inbox: { ...late(W2), ...later },
  })

  expect(settledFirst.replies.find(each => each.id === 'r1')).toMatchObject({
    voided: 'answered',
    isHistory: true,
  })
  expect(settledFirst.asks[0]?.answerOnItsWay).toBeUndefined()
  expect(reopenedFirst.replies.find(each => each.id === 'r1')?.isHistory).toBeUndefined()
  expect(reopenedFirst.asks[0]?.answerOnItsWay?.id).toBe('r1')
})

test("Lee's yes on its way across a reopen of a replied ask that Claude then resolves reads delivered once marked: Claude has it", () => {
  const session = fold({
    logs: {
      [W1]: file(
        [T0, REVIEW],
        ...sent(T0 + MIN, 'c1', 'k1', 'comment', { note: 'Tighten the copy first' }),
        [T0 + 3 * MIN, reopen('k1')],
        [T0 + 4 * MIN, resolve('k1')],
        [T0 + 5 * MIN, delivered('r1')],
      ),
    },
    inbox: { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(standing(session, 'k1')).toMatchObject({ is: 'delivered', reply: { id: 'r1' } })
})

/** An ask written by its kind, a decide, before asks said what they want back: its comment is its answer. */
const OLD_DECIDE: Line = [T0, kindAsk('k7', 'decide', 'Keep the ledger 400 days, or forever?')]

const COMMENTED = reply('r1', 'k7', 'comment', { note: 'Forever, but archive after a year' })

test("an edit making an old decide's comment on its way only a comment: it bars nothing, and the board says so as the bar does", () => {
  const letters = { [CLI]: file([T0 + MIN, COMMENTED]) }
  const before = fold({ logs: { [W1]: file(OLD_DECIDE) }, inbox: letters })

  expect(before.asks[0]?.answerOnItsWay?.id).toBe('r1')
  expect(standing(before, 'k7')).toMatchObject({ is: 'onItsWay', isAnswer: true })
  expect(barredBy(before.asks[0]!, 'ignore')).toBe('answered')

  const reshapings = [
    { wants: 'yes', yes: 'Keep it' },
    { wants: 'choice', options: ['400 days', 'Forever'] },
  ]

  for (const changes of reshapings) {
    const edited: Line = [T0 + 2 * MIN, { type: 'edit', item: 'k7', changes } as Body]
    const after = fold({ logs: { [W1]: file(OLD_DECIDE, edited) }, inbox: letters })
    const ask = after.asks[0]!

    expect(ask.answerOnItsWay, changes.wants).toBeUndefined()
    expect(standing(after, 'k7'), changes.wants).toMatchObject({ is: 'onItsWay', isAnswer: false })
    expect(barredBy(ask, 'ignore'), changes.wants).toBeUndefined()
    expect(waitsOnLee(ask), 'a comment on its way: Lee has responded').toBe(false)
  }
})

test("an ignore an old decide's comment barred comes back on its way once an edit makes the comment only a comment", () => {
  const letters = {
    [CLI]: file([T0 + MIN, COMMENTED], [T0 + 2 * MIN, reply('r2', 'k7', 'ignore')]),
  }
  const edited: Line = [
    T0 + 3 * MIN,
    { type: 'edit', item: 'k7', changes: { wants: 'yes' } } as Body,
  ]
  const before = fold({ logs: { [W1]: file(OLD_DECIDE) }, inbox: letters })
  const after = fold({ logs: { [W1]: file(OLD_DECIDE, edited) }, inbox: letters })

  expect(before.replies.map(each => [each.id, each.voided])).toEqual([
    ['r1', undefined],
    ['r2', 'answered'],
  ])
  expect(after.replies.map(each => [each.id, each.delivery, each.voided])).toEqual([
    ['r1', 'closed', undefined],
    ['r2', 'closed', undefined],
  ])
  expect(after.asks[0]?.answerOnItsWay?.id).toBe('r2')
  expect(standing(after, 'k7')).toMatchObject({
    is: 'onItsWay',
    isAnswer: true,
    reply: { id: 'r2' },
  })
})

test("an old edit making a comment on its way a decide's answer makes it Lee's answer on its way, barring another", () => {
  const review: Line = [T0, kindAsk('k8', 'review', 'Review round 1')]
  const decided: Line = [
    T0 + 2 * MIN,
    { type: 'edit', item: 'k8', changes: { kind: 'decide' } } as Body,
  ]
  const session = fold({
    logs: { [W1]: file(review, decided) },
    inbox: {
      [CLI]: file(
        [T0 + MIN, reply('r1', 'k8', 'comment', { note: 'Go ahead' })],
        [T0 + 3 * MIN, reply('r2', 'k8', 'ignore')],
      ),
    },
  })

  expect(session.asks[0]?.answerOnItsWay?.id).toBe('r1')
  expect(session.replies.map(each => [each.id, each.voided])).toEqual([
    ['r1', undefined],
    ['r2', 'answered'],
  ])
})

/** What bars an item of a session from taking a reply of Lee's with a verdict, as `barredBy` says. */
const barredIn = (files: Partial<SessionFiles>, id: string, verdict: Verdict) => {
  const item = fold(files).items.get(id)

  return item === undefined ? 'no ask or parked item' : barredBy(item, verdict)
}

test("an item open takes a reply of Lee's, but a second answer while one is on its way; one closed takes none, barred by Lee's answer or Claude's resolve", () => {
  const letter = (item: string, verdict: Verdict, extra = {}) => ({
    [SENDER]: file([T0 + MIN, reply('r1', item, verdict, extra)]),
  })
  const logs = (...more: Line[]) => ({ logs: { [W1]: file(...POSTED, ...more) } })
  const yes = logs(...sent(T0 + MIN, 'r1', 'k1', 'yes'))
  const ignoring = sent(T0 + MIN, 'r1', 'k1', 'ignore')
  const ignored = logs(...ignoring)
  const comment = sent(T0 + MIN, 'r1', 'k3', 'comment', { note: 'Fails after the code' })
  const answering = { ...logs(), inbox: letter('k1', 'yes') }
  const commenting = { ...logs(), inbox: letter('k1', 'comment', { note: 'Tighten the copy' }) }
  const picking = { ...logs(), inbox: letter('p1', 'pickup') }
  const picked = logs(...sent(T0 + MIN, 'r1', 'p1', 'pickup'))
  const reopened = logs(...sent(T0 + MIN, 'r1', 'k1', 'yes'), [T0 + 2 * MIN, reopen('k1')])
  const cases: [string, Partial<SessionFiles>, string, Verdict, Barred | undefined][] = [
    ['an open ask', logs(), 'k1', 'yes', undefined],
    ["Lee's yes on its way, to a yes", answering, 'k1', 'yes', 'answered'],
    ["Lee's yes on its way, to an ignore", answering, 'k1', 'ignore', 'answered'],
    ["Lee's yes on its way, to a comment", answering, 'k1', 'comment', undefined],
    ["Lee's comment on its way, to a yes", commenting, 'k1', 'yes', undefined],
    ["Lee's yes delivered", yes, 'k1', 'yes', 'answered'],
    ["Lee's yes delivered, to a comment", yes, 'k1', 'comment', 'answered'],
    ["Lee's ignore delivered", ignored, 'k1', 'yes', 'answered'],
    [
      "Lee's ignore, then Claude's resolve",
      logs(...ignoring, [T0 + 2 * MIN, resolve('k1')]),
      'k1',
      'yes',
      'answered',
    ],
    ["Lee's comment delivered, Claude's to act on", logs(...comment), 'k3', 'yes', undefined],
    ["Claude's resolve", logs([T0 + MIN, resolve('k1')]), 'k1', 'yes', 'resolved'],
    [
      "Claude's resolve after Lee's comment",
      logs(...comment, [T0 + 2 * MIN, resolve('k3')]),
      'k3',
      'comment',
      'resolved',
    ],
    ['reopened after its answer', reopened, 'k1', 'yes', undefined],
    ['a parked item', logs(), 'p1', 'pickup', undefined],
    ["Lee's pick-up on its way", picking, 'p1', 'pickup', 'answered'],
    ['picked up', picked, 'p1', 'pickup', 'answered'],
    ['a parked item Claude resolved', logs([T0 + MIN, resolve('p1')]), 'p1', 'pickup', 'resolved'],
  ]

  for (const [why, files, id, verdict, barred] of cases) {
    expect(barredIn(files, id, verdict), why).toBe(barred)
  }
})

/**
 * One rule of the fold's for Lee's replies, as a case: the window's lines
 * after POSTED, the CLI's letters, and where each reply stands then, in the
 * order the fold read them (`r1 void answered`); with k1's state, where the
 * rule is about it.
 */
type ReplyRule = {
  rule: string
  logs?: Line[]
  letters?: Line[]
  replies: string[]
  k1?: AskState
  /** How many of POSTED's four asks wait on Lee then. */
  waiting?: number
}

const at = (minutes: number) => T0 + minutes * MIN

/** A reply written `minutes` in. */
const to = (minutes: number, id: string, item: string, verdict: Verdict, extra = {}): Line => [
  at(minutes),
  reply(id, item, verdict, extra),
]

const TIGHTEN = { note: 'Tighten the copy first' }

/**
 * The fold's rules for Lee's replies, as DESIGN.md's "Delivery" states them:
 * one closing answer per item, the first not void; a comment barring
 * nothing; Claude's close, and the session's finish, voiding what is on its
 * way; an edit voiding what fits no more; a mark, Claude's record, taking in
 * any reply but one an edit voided; and a delivered answer voiding the
 * other answers on their way.
 */
const REPLY_RULES: ReplyRule[] = [
  {
    rule: 'of two answers on their way to an item, the first goes in; the second is void, answered',
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'yes')],
    replies: ['r1 waiting', 'r2 void answered'],
  },
  {
    rule: 'an ignore is an answer: a yes after it is void',
    letters: [to(1, 'r1', 'k1', 'ignore'), to(2, 'r2', 'k1', 'yes')],
    replies: ['r1 waiting', 'r2 void answered'],
  },
  {
    rule: "a pick-up is a parked item's answer: a second is void",
    letters: [to(1, 'r1', 'p1', 'pickup'), to(2, 'r2', 'p1', 'pickup', TIGHTEN)],
    replies: ['r1 waiting', 'r2 void answered'],
  },
  {
    rule: "an answer reaching an item Lee's answer closed is void, answered",
    logs: sent(at(1), 'r1', 'k1', 'yes'),
    letters: [to(2, 'r2', 'k1', 'yes')],
    replies: ['r1 delivered', 'r2 void answered'],
  },
  {
    rule: 'an answer reaching an item Claude closed is void, resolved',
    logs: [[at(1), resolve('k1')]],
    letters: [to(2, 'r1', 'k1', 'yes')],
    replies: ['r1 void resolved'],
  },
  {
    rule: 'a void answer bars nothing: the item reopened, the next answer goes in',
    logs: [
      [at(2), resolve('k1')],
      [at(3), reopen('k1')],
    ],
    letters: [to(1, 'r1', 'k1', 'yes'), to(4, 'r2', 'k1', 'yes')],
    replies: ['r1 void resolved', 'r2 waiting'],
  },
  {
    rule: 'a comment on its way bars no answer: both go in',
    letters: [to(1, 'r1', 'k1', 'comment', TIGHTEN), to(2, 'r2', 'k1', 'yes')],
    replies: ['r1 waiting', 'r2 waiting'],
  },
  {
    rule: "a comment on its way takes its ask off Lee's counts: Lee has replied",
    letters: [to(1, 'r1', 'k1', 'comment', TIGHTEN)],
    replies: ['r1 waiting'],
    k1: 'waiting',
    waiting: 3,
  },
  {
    rule: 'an answer on its way bars no comment',
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'comment', TIGHTEN)],
    replies: ['r1 waiting', 'r2 waiting'],
  },
  {
    rule: 'an ask Lee ignored stays ignored though Claude resolves it after, and an answer reaching it is void, answered',
    logs: [...sent(at(1), 'r1', 'k1', 'ignore'), [at(2), resolve('k1')]],
    letters: [to(3, 'r2', 'k1', 'yes')],
    replies: ['r1 delivered', 'r2 void answered'],
    k1: 'ignored',
  },
  {
    rule: 'a comment reaching an item closed is void',
    logs: sent(at(1), 'r1', 'k1', 'yes'),
    letters: [to(2, 'r2', 'k1', 'comment', TIGHTEN)],
    replies: ['r1 delivered', 'r2 void answered'],
  },
  {
    rule: "Claude's close voids every reply on its way to the item, a comment too, and none to another",
    logs: [[at(2), resolve('k1')]],
    letters: [
      to(1, 'r1', 'k1', 'comment', TIGHTEN),
      to(1, 'r2', 'k1', 'yes'),
      to(1, 'r3', 'k4', 'yes'),
    ],
    replies: ['r1 void resolved', 'r2 void resolved', 'r3 waiting'],
  },
  {
    rule: 'finishing the session voids every reply on its way',
    logs: [[at(2), finish('lee')]],
    letters: [to(1, 'r1', 'k1', 'yes'), to(1, 'r2', 'p1', 'pickup')],
    replies: ['r1 void finished', 'r2 void finished'],
  },
  {
    rule: 'a reply reaching a finished session is void',
    logs: [[at(1), finish('lee')]],
    letters: [to(2, 'r1', 'k1', 'yes')],
    replies: ['r1 void finished'],
  },
  {
    rule: 'an edit voids a reply on its way that fits its item no more, changed',
    logs: [[at(2), DECIDED]],
    letters: [to(1, 'r1', 'k1', 'yes')],
    replies: ['r1 void changed'],
  },
  {
    rule: 'an edit voids a void reply that fits its item no more again, changed',
    logs: [[at(2), DECIDED]],
    letters: [to(1, 'r1', 'k1', 'yes'), to(1, 'r2', 'k1', 'yes')],
    replies: ['r1 void changed', 'r2 void changed'],
  },
  {
    rule: 'an edit leaves every reply that still fits as it was',
    logs: [[at(2), RETITLED]],
    letters: [to(1, 'r1', 'k1', 'yes'), to(1, 'r2', 'k1', 'yes')],
    replies: ['r1 waiting', 'r2 void answered'],
  },
  {
    rule: 'a mark delivers a reply on its way',
    logs: [[at(2), delivered('r1')]],
    letters: [to(1, 'r1', 'k1', 'yes')],
    replies: ['r1 delivered'],
    k1: 'closed',
  },
  {
    rule: 'a mark delivers a reply void as answered, Claude having it, and that answer voids the one on its way',
    logs: sent(at(2), 'r2', 'k1', 'yes'),
    letters: [to(1, 'r1', 'k1', 'yes')],
    replies: ['r1 void answered', 'r2 delivered'],
    k1: 'closed',
  },
  {
    rule: "a mark delivers a reply void as resolved, its message having crossed Claude's close, which stands",
    logs: [
      [at(2), resolve('k1')],
      [at(3), delivered('r1')],
    ],
    letters: [to(1, 'r1', 'k1', 'yes')],
    replies: ['r1 delivered'],
    k1: 'closed',
  },
  {
    rule: 'a mark delivers a reply void as finished, its message having crossed the finish',
    logs: [
      [at(2), finish('lee')],
      [at(3), delivered('r1')],
    ],
    letters: [to(1, 'r1', 'k1', 'yes')],
    replies: ['r1 delivered'],
  },
  {
    rule: 'a mark delivers a reply an edit voided, Claude having it, but it settles nothing: the ask takes an answer again',
    logs: [
      [at(2), DECIDED],
      [at(3), delivered('r1')],
    ],
    letters: [to(1, 'r1', 'k1', 'yes')],
    replies: ['r1 delivered changed'],
    k1: 'waiting',
    waiting: 4,
  },
  {
    rule: 'nor one an edit voided again: a yes never closes the choice ask its ask became',
    logs: [
      [at(2), DECIDED],
      [at(3), delivered('r2')],
    ],
    letters: [to(1, 'r1', 'k1', 'yes'), to(1, 'r2', 'k1', 'yes')],
    replies: ['r1 void changed', 'r2 delivered changed'],
    k1: 'waiting',
  },
  {
    rule: 'a reply reaching an item changed under it since it was sent is void, changed; its mark says Claude has it, and the ask waits on Lee in its new shape',
    logs: [[at(1), DECIDED], ...sent(at(2), 'r1', 'k1', 'yes')],
    replies: ['r1 delivered changed'],
    k1: 'waiting',
    waiting: 4,
  },
  {
    rule: 'a delivered comment voids nothing: the answer on its way still goes in',
    logs: sent(at(2), 'r2', 'k1', 'comment', TIGHTEN),
    letters: [to(1, 'r1', 'k1', 'yes')],
    replies: ['r1 waiting', 'r2 delivered'],
    k1: 'replied',
  },
  {
    rule: 'a delivered answer leaves a comment on its way to go in',
    logs: [[at(2), delivered('r2')]],
    letters: [to(1, 'r1', 'k1', 'comment', TIGHTEN), to(1, 'r2', 'k1', 'yes')],
    replies: ['r1 waiting', 'r2 delivered'],
    k1: 'closed',
  },
  {
    rule: "a resolve after Lee's close voids the comments on their way by that close, answered",
    logs: [...sent(at(2), 'r2', 'k1', 'yes'), [at(3), resolve('k1')]],
    letters: [to(1, 'r1', 'k1', 'comment', TIGHTEN)],
    replies: ['r1 void answered', 'r2 delivered'],
    k1: 'closed',
  },
  {
    rule: 'an answer barred by one an edit then voided comes back on its way, where the ask still takes it',
    logs: [[at(3), DECIDED]],
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'ignore')],
    replies: ['r1 void changed', 'r2 waiting'],
    k1: 'waiting',
    waiting: 3,
  },
  {
    rule: 'and goes in once marked, in place of the answer the edit voided',
    logs: [
      [at(3), DECIDED],
      [at(4), delivered('r2')],
    ],
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'ignore')],
    replies: ['r1 void changed', 'r2 delivered'],
    k1: 'ignored',
  },
  {
    rule: 'of two answers so barred, the first comes back as the answer on its way, and bars the second again',
    logs: [[at(4), DECIDED]],
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'ignore'), to(3, 'r3', 'k1', 'ignore')],
    replies: ['r1 void changed', 'r2 waiting', 'r3 void answered'],
  },
  {
    rule: "an answer barred by one Claude's close then voided says so: resolved",
    logs: [[at(3), resolve('k1')]],
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'ignore')],
    replies: ['r1 void resolved', 'r2 void resolved'],
  },
  {
    rule: 'an answer barred by one the finish then voided says so: finished',
    logs: [[at(3), finish('lee')]],
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'ignore')],
    replies: ['r1 void finished', 'r2 void finished'],
  },
  {
    rule: 'a mark naming a reply void before its item last reopened makes it delivered and settles nothing: the reopened ask waits on Lee',
    logs: [
      [at(3), delivered('r1')],
      [at(4), reopen('k1')],
      [at(5), delivered('r2')],
    ],
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'ignore')],
    replies: ['r1 delivered', 'r2 delivered answered'],
    k1: 'waiting',
    waiting: 4,
  },
  {
    rule: 'a comment on its way as Lee closed the ask and Claude reopened it stays live, and once marked leaves the reopened ask replied',
    logs: [...sent(at(2), 'r2', 'k1', 'yes'), [at(3), reopen('k1')], [at(4), delivered('r1')]],
    letters: [to(1, 'r1', 'k1', 'comment', TIGHTEN)],
    replies: ['r1 delivered', 'r2 delivered'],
    k1: 'replied',
  },
  {
    rule: "Lee's yes on its way as Claude reopens a replied ask stays live, and once marked answers the reopened ask",
    logs: [
      ...sent(at(1), 'c1', 'k1', 'comment', TIGHTEN),
      [at(3), reopen('k1')],
      [at(4), delivered('r1')],
    ],
    letters: [to(2, 'r1', 'k1', 'yes')],
    replies: ['c1 delivered', 'r1 delivered'],
    k1: 'closed',
  },
  {
    rule: 'an edit that leaves the answer on its way an answer leaves it barring a second',
    logs: [[at(2), RETITLED]],
    letters: [to(1, 'r1', 'k1', 'yes'), to(3, 'r2', 'k1', 'yes')],
    replies: ['r1 waiting', 'r2 void answered'],
  },
  {
    rule: 'a barred answer an edit voided stays changed through a later close, though another edit made it fit again',
    logs: [
      [at(3), DECIDED],
      [at(4), REVIEWED],
      [at(5), resolve('k1')],
    ],
    letters: [to(1, 'r1', 'k1', 'ignore'), to(2, 'r2', 'k1', 'yes')],
    replies: ['r1 void resolved', 'r2 void changed'],
  },
  {
    rule: 'or through the finish',
    logs: [
      [at(3), DECIDED],
      [at(4), REVIEWED],
      [at(5), finish('lee')],
    ],
    letters: [to(1, 'r1', 'k1', 'ignore'), to(2, 'r2', 'k1', 'yes')],
    replies: ['r1 void finished', 'r2 void changed'],
  },
  {
    rule: 'an answer barred, history once its ask closed and reopened, stays as Claude has it when a later answer goes void: it is never sent again',
    logs: [
      [at(3), delivered('r1')],
      [at(4), reopen('k1')],
      [at(5), delivered('r2')],
      [at(7), DECIDED],
    ],
    letters: [to(1, 'r1', 'k1', 'yes'), to(2, 'r2', 'k1', 'ignore'), to(6, 'r3', 'k1', 'yes')],
    replies: ['r1 delivered', 'r2 delivered answered', 'r3 void changed'],
    k1: 'waiting',
  },
  {
    rule: "an edit to an ask Lee's answer closed leaves the comment that close left on its way to go in",
    logs: [...sent(at(2), 'r2', 'k1', 'yes'), [at(3), RETITLED]],
    letters: [to(1, 'c1', 'k1', 'comment', TIGHTEN)],
    replies: ['c1 waiting', 'r2 delivered'],
    k1: 'closed',
  },
  {
    rule: "and so does one to an ask Lee's ignore closed",
    logs: [...sent(at(2), 'r2', 'k1', 'ignore'), [at(3), RETITLED]],
    letters: [to(1, 'c1', 'k1', 'comment', TIGHTEN)],
    replies: ['c1 waiting', 'r2 delivered'],
    k1: 'ignored',
  },
  {
    rule: 'an answer barred on a replied ask Claude then reopens is no history: once the answer barring it goes void it comes back, and its mark answers the ask',
    logs: [
      [at(2), delivered('c0')],
      [at(5), reopen('k1')],
      [at(6), WORDED],
      [at(7), delivered('a2')],
    ],
    letters: [
      to(1, 'c0', 'k1', 'comment', TIGHTEN),
      to(3, 'a1', 'k1', 'yes'),
      to(4, 'a2', 'k1', 'ignore'),
    ],
    replies: ['c0 delivered', 'a1 void changed', 'a2 delivered'],
    k1: 'ignored',
  },
]

for (const { rule, logs = [], letters = [], replies, k1, waiting } of REPLY_RULES) {
  test(`a reply: ${rule}`, () => {
    const session = fold({
      logs: { [W1]: file(...POSTED, ...logs) },
      inbox: { [CLI]: file(...letters) },
      presence: { [W1]: seen(W1, NOW) },
    })
    const standing = session.replies.map(each =>
      [each.id, each.delivery, each.voided].filter(Boolean).join(' '),
    )

    expect(standing).toEqual(replies)
    expect(toDeliver(session, W1).map(each => each.id)).toEqual(
      session.replies.filter(each => each.delivery === 'waiting').map(each => each.id),
    )

    if (k1 !== undefined) {
      expect(session.asks[0]?.state).toBe(k1)
    }

    if (waiting !== undefined) {
      expect(session.waiting).toBe(waiting)
    }
  })
}

test("Lee's answer standing on an ask Claude closed: not delivered while Claude's closing left it; delivered once a mark says Claude had it after all", () => {
  const letters = { [CLI]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) }
  const presence = { [W1]: seen(W1, NOW) }
  const closed: Line = [T0 + 2 * MIN, resolve('k1', 'Approved in the chat')]
  const left = fold({ logs: { [W1]: file(...POSTED, closed) }, inbox: letters, presence })
  const crossed = fold({
    logs: { [W1]: file(...POSTED, closed, [T0 + 3 * MIN, delivered('r1')]) },
    inbox: letters,
    presence,
  })

  expect(standing(left, 'k1')).toMatchObject({
    is: 'notDelivered',
    reply: { id: 'r1' },
    since: T0 + 2 * MIN,
  })
  expect(crossed.asks[0]).toMatchObject({
    state: 'closed',
    closedAt: T0 + 2 * MIN,
    reason: 'Approved in the chat',
  })
  expect(standing(crossed, 'k1')).toMatchObject({
    is: 'delivered',
    reply: { id: 'r1' },
    since: T0 + 3 * MIN,
  })
})

test("an ask Lee's answer closed, resolved by Claude after, keeps when it closed and carries Claude's reason", () => {
  const reworded: Body = { ...RETITLED, reason: 'Reworded' }
  const answered: Line[] = [
    ...POSTED,
    [T0 + MIN, reworded],
    ...sent(T0 + 2 * MIN, 'r1', 'k1', 'yes'),
  ]
  const resolved = fold({
    logs: { [W1]: file(...answered, [T0 + 3 * MIN, resolve('k1', 'Shipped')]) },
  })

  expect(
    fold({ logs: { [W1]: file(...answered) } }).asks[0],
    "no reason of Claude's for Lee's answer",
  ).toMatchObject({
    state: 'closed',
    reason: undefined,
  })
  expect(resolved.asks[0]).toMatchObject({
    state: 'closed',
    closedAt: T0 + 2 * MIN,
    reason: 'Shipped',
  })
})

test("an answer Claude's closing left counts only on the ask as it closed then: reopened and closed again, it says nothing of it", () => {
  const session = fold({
    logs: {
      [W1]: file(
        ...POSTED,
        [T0 + 2 * MIN, resolve('k1')],
        [T0 + 3 * MIN, reopen('k1')],
        [T0 + 4 * MIN, resolve('k1')],
      ),
    },
    inbox: { [CLI]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(standing(session, 'k1')).toBeUndefined()
})
