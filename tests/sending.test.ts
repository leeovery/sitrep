/**
 * Lee's replies a window sends its own session as Lee's message, published
 * in its heartbeat from the claim: on their way to every reader from then,
 * as an inbox reply is, until the session's lines carry them or the message
 * is let go, or the window is gone.
 */
import { expect, test } from './kit'
import { boardJson, listing } from '../cli/output'
import { leftOut, replyBodies, sendable, unsentTo } from '../hooks/queue'
import type { SitrepInFlight } from '../types'
import {
  attach,
  barredBy,
  boardText,
  checkAnswer,
  feedOf,
  foldSession,
  leave,
  metaText,
  parsePresence,
  presenceText,
  replyOnItsWay,
  replyState,
  rowOf,
  STALE_MS,
  summarise,
  toDeliver,
  toldSummary,
  waitingOnLee,
  waitsOnLee,
  type Body,
  type Presence,
  type Project,
  type ReplyBody,
  type Sending,
  type Session,
} from '../core'
import { CLI, CLOSES, META, MIN, T0, W1, W2 } from './data'
import {
  beat,
  choiceAsk,
  delivered,
  file,
  finish,
  park,
  reopen,
  reply,
  resolve,
  scripted,
  unfinish,
  yesAsk,
  type Line,
} from './lines'

const NOW = T0 + 60 * MIN

const CLAIMED = NOW - MIN

const NORTHWIND: Project = {
  key: 'northwind',
  name: 'Northwind',
  directory: '/Users/me/Code/northwind',
}

const REVIEW: Line = [T0, yesAsk('k1', 'Review round 1')]
const SIDEBAR: Line = [T0, choiceAsk('k2', 'Keep the sidebar?', ['Keep it', 'Drop it'])]

/** Lee's yes to the review, and a comment on the sidebar, as a send claims them. */
const YES = { id: 'r1', item: 'k1', verdict: 'yes' } as const
const COMMENT = { id: 'r2', item: 'k2', verdict: 'comment', note: 'Narrower first' } as const

/** A message claimed at `at`, carrying these replies. */
const claimed = (at: number, ...replies: Sending['replies']): Sending => ({ at, replies })

const sending = (...replies: Sending['replies']) => claimed(CLAIMED, ...replies)

/** A send of this window's to the session, held for Claude's turn, carrying these replies. */
const inFlight = (...replies: ReplyBody[]): SitrepInFlight => ({
  source: 'send',
  project: NORTHWIND.key,
  session: META.id,
  writer: W1,
  text: `From the board:\n- Review round 1 → Approve${CLOSES}`,
  replies,
  claimedAt: CLAIMED,
  isHeld: true,
  isTaken: false,
})

/** Lee's choice on the sidebar: "Keep it" as a send claims it, "Drop it" in the inbox. */
const KEEP = { id: 'r1', item: 'k2', verdict: 'choose', option: 'Keep it' } as const
const DROP: Body = reply('r9', 'k2', 'choose', { option: 'Drop it' })

/** The words `board --json` gives the sidebar's reply. */
const sidebarWords = (session: Session) => {
  const board = JSON.parse(boardJson(NORTHWIND.key, session)) as {
    asks: { id: string; reply: { words: string } | null }[]
  }

  return board.asks.find(ask => ask.id === 'k2')?.reply?.words
}

/** A window's heartbeat, live at NOW unless the times say otherwise, sending what it is given: one message, or several. */
const windowOn = (writer: string, what?: Sending | Sending[], times: Partial<Presence> = {}) => ({
  [writer]: beat(writer, {
    attachedAt: T0,
    seenAt: NOW,
    version: '0.2.0',
    state: { is: 'working', since: CLAIMED },
    sending: what === undefined ? undefined : [what].flat(),
    ...times,
  }),
})

/** The session at NOW, from the window's own lines, the inbox's letters and the heartbeats given. */
const sessionOf = (
  lines: Line[],
  presence: Record<string, string>,
  inbox: Record<string, string> = {},
): Session => {
  const session = foldSession(
    { meta: metaText(META), logs: { [W1]: file(...lines) }, inbox, presence },
    NOW,
  )

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

const askIn = (session: Session, id: string) => {
  const ask = session.asks.find(each => each.id === id)

  if (ask === undefined) {
    throw new Error(`no ask ${id}`)
  }

  return ask
}

/** What every reader of Lee's says waits on Lee: the session's count, its row's ask lines, the head, `list` and `board --json`. */
const needingLee = (session: Session) => {
  const listed = listing([{ project: NORTHWIND, sessions: [summarise(session)] }], '/', NOW)
  const board = JSON.parse(boardJson(NORTHWIND.key, session)) as {
    session: { waiting: number }
    asks: { id: string; reply: { is: string; isAnswer: boolean; words: string } | null }[]
  }

  return {
    waiting: session.waiting,
    rows: (rowOf(NORTHWIND, session, NOW)?.lines ?? [])
      .filter(line => line.is === 'ask')
      .map(line => line.ask),
    head: feedOf([{ project: NORTHWIND, sessions: [session] }], NOW).head.needYou,
    list: listed.projects.map(project => [project.waiting, project.sessions[0]?.waiting]),
    board: board.session.waiting,
  }
}

const NONE = { waiting: 0, rows: [], head: 0, list: [[0, 0]], board: 0 }

test("an answer and a comment in a live window's message are on their way from the claim: neither ask needs Lee in the rows, the head, `list` or `board --json`", () => {
  const before = sessionOf([REVIEW, SIDEBAR], windowOn(W1))
  const claimed = sessionOf([REVIEW, SIDEBAR], windowOn(W1, sending(YES, COMMENT)))

  expect(needingLee(before)).toEqual({
    waiting: 2,
    rows: ['k1', 'k2'],
    head: 2,
    list: [[2, 2]],
    board: 2,
  })
  expect(needingLee(claimed)).toEqual(NONE)
  expect(claimed.asks.map(waitsOnLee)).toEqual([false, false])
})

test("each still shows among its session's asks, saying its reply is on its way since the claim, in its words", () => {
  const session = sessionOf([REVIEW, SIDEBAR], windowOn(W1, sending(YES, COMMENT)))
  const board = JSON.parse(boardJson(NORTHWIND.key, session)) as { asks: { reply: unknown }[] }

  expect(board.asks.map(ask => ask.reply)).toEqual([
    { is: 'onItsWay', isAnswer: true, words: '→ Approve', since: CLAIMED },
    { is: 'onItsWay', isAnswer: false, words: 'comment: “Narrower first”', since: CLAIMED },
  ])
  expect(replyState(askIn(session, 'k1'))).toMatchObject({ reply: { by: W1, delivery: 'waiting' } })
})

test('an answer in flight bars a second answer, from anywhere; a comment in flight bars none', () => {
  const session = sessionOf([REVIEW, SIDEBAR], windowOn(W1, sending(YES, COMMENT)))

  expect(barredBy(askIn(session, 'k1'), 'yes')).toBe('answered')
  expect(barredBy(askIn(session, 'k1'), 'comment')).toBeUndefined()
  expect(barredBy(askIn(session, 'k2'), 'choose')).toBeUndefined()
  expect(checkAnswer(session, { ask: 'k1', answer: 'Approve' })).toEqual({
    ok: false,
    error: 'An answer to k1 is on its way already.',
  })
  expect(checkAnswer(session, { ask: 'k2', answer: 'Drop it' })).toMatchObject({ ok: true })
})

test("an answer in flight takes its place in the fold's order at its claim: an inbox answer written after it is barred by it, one written before bars it", () => {
  const withInbox = (at: number) =>
    sessionOf([SIDEBAR], windowOn(W1, sending(KEEP)), { [CLI]: file([at, DROP]) })
  const after = withInbox(CLAIMED + MIN / 2)
  const before = withInbox(CLAIMED - MIN / 2)

  expect(askIn(after, 'k2').answerOnItsWay?.id).toBe('r1')
  expect(sidebarWords(after)).toBe('→ Keep it')
  expect(after.replies.find(each => each.id === 'r9')).toMatchObject({
    delivery: 'void',
    voided: 'answered',
  })

  expect(askIn(before, 'k2').answerOnItsWay?.id).toBe('r9')
  expect(sidebarWords(before)).toBe('→ Drop it')
  expect(
    askIn(before, 'k2').replies.map(each => each.id),
    'the claim, barred, is left out',
  ).toEqual(['r9'])

  expect([after.waiting, before.waiting]).toEqual([0, 0])
})

test("one window's messages each take their place at their own claim: an inbox answer written between them bars the later's answer, and the earlier's bars the inbox's", () => {
  const keep = { ...KEEP, id: 'r5' }
  const between = CLAIMED - MIN / 2
  const session = sessionOf(
    [REVIEW, SIDEBAR],
    windowOn(W1, [claimed(CLAIMED - MIN, YES), claimed(CLAIMED, keep)]),
    { [CLI]: file([between, DROP], [between, reply('r8', 'k1', 'ignore')]) },
  )

  expect(askIn(session, 'k1').answerOnItsWay?.id, 'the earlier claim first').toBe('r1')
  expect(session.replies.find(each => each.id === 'r8')).toMatchObject({
    delivery: 'void',
    voided: 'answered',
  })
  expect(askIn(session, 'k2').answerOnItsWay?.id, 'the inbox before the later claim').toBe('r9')
  expect(askIn(session, 'k2').replies.map(each => each.id), 'the later, barred').toEqual(['r9'])
})

test('the ask needs Lee again once the heartbeat drops the claim, goes stale, or says its window let go', () => {
  const lines = [REVIEW]
  const cases = {
    dropped: windowOn(W1),
    stale: windowOn(W1, sending(YES), { seenAt: NOW - STALE_MS - 1 }),
    left: windowOn(W1, sending(YES), { leftAt: NOW - MIN }),
  }

  for (const [why, presence] of Object.entries(cases)) {
    const session = sessionOf(lines, presence)

    expect(session.waiting, why).toBe(1)
    expect(
      rowOf(NORTHWIND, session, NOW)?.lines.map(line => line.ask),
      why,
    ).toEqual(['k1'])
    expect(replyState(askIn(session, 'k1')), why).toBeUndefined()
  }
})

test('once written down, its lines carry it: the claim still published reads as those lines, with no gap and nothing twice', () => {
  const written: Line[] = [REVIEW, [NOW - 10_000, reply('r1', 'k1', 'yes')]]
  const marked: Line[] = [...written, [NOW - 10_000, delivered('r1')]]
  const taken = sessionOf(written, windowOn(W1, sending(YES)))
  const done = sessionOf(marked, windowOn(W1, sending(YES)))

  expect(askIn(taken, 'k1').replies.map(each => [each.id, each.at])).toEqual([['r1', NOW - 10_000]])
  expect(taken.waiting).toBe(0)
  expect(askIn(done, 'k1').state).toBe('closed')
  expect(askIn(done, 'k1').replies).toHaveLength(1)
})

test('a reply in flight its item takes no more is left out, Claude closing the ask before the claim or while the send waits', () => {
  for (const at of [CLAIMED - MIN, CLAIMED + MIN / 2]) {
    const resolved = sessionOf([REVIEW, [at, resolve('k1')]], windowOn(W1, sending(YES)))
    const when = at < CLAIMED ? 'before the claim' : 'after it'

    expect(askIn(resolved, 'k1').state, when).toBe('closed')
    expect(askIn(resolved, 'k1').replies, when).toEqual([])
    expect(replyState(askIn(resolved, 'k1')), `${when}: no "not delivered"`).toBeUndefined()
    expect(needingLee(resolved), when).toEqual(NONE)
  }
})

/** The send's lines as the window writes them down, after everything else: its reply and the mark naming it. */
const writtenDown = (body: Body): Line[] => [
  [NOW - 5_000, body],
  [NOW - 5_000, delivered('r1')],
]

/** Lines while the send waits out Claude's turn: the claim at CLAIMED, then these, a few seconds apart. */
const whileWaiting = (...bodies: Body[]): Line[] =>
  bodies.map((body, i): Line => [CLAIMED + (i + 1) * 10_000, body])

test('a reply in flight is on its way though the session finishes before the claim or while the send waits: the window carrying it holds the session, which a reply there reaches, and its lines settle the ask once written', () => {
  for (const at of [CLAIMED - MIN, CLAIMED + MIN / 2]) {
    const finished = sessionOf([REVIEW, [at, finish('claude')]], windowOn(W1, sending(YES)))
    const written = sessionOf(
      [REVIEW, [at, finish('claude')], ...writtenDown(reply('r1', 'k1', 'yes'))],
      windowOn(W1, sending(YES)),
    )
    const when = at < CLAIMED ? 'before the claim' : 'after it'

    expect(askIn(finished, 'k1').answerOnItsWay?.id, when).toBe('r1')
    expect(waitsOnLee(askIn(finished, 'k1')), when).toBe(false)
    expect(askIn(written, 'k1').state, when).toBe('closed')
  }
})

test('a close or a finish undone while the send waits leaves its reply on its way: the ask waits on Lee no more and takes no second answer, and its lines settle it once written', () => {
  const cases = {
    'resolved, then reopened': whileWaiting(resolve('k1'), reopen('k1')),
    'finished, then taken up again': whileWaiting(finish('claude'), unfinish()),
  }

  for (const [what, during] of Object.entries(cases)) {
    const waiting = sessionOf([REVIEW, ...during], windowOn(W1, sending(YES)))
    const written = sessionOf(
      [REVIEW, ...during, ...writtenDown(reply('r1', 'k1', 'yes'))],
      windowOn(W1, sending(YES)),
    )

    expect(askIn(waiting, 'k1').answerOnItsWay?.id, what).toBe('r1')
    expect(needingLee(waiting), what).toEqual(NONE)
    expect(checkAnswer(waiting, { ask: 'k1', answer: 'Approve' }), what).toEqual({
      ok: false,
      error: 'An answer to k1 is on its way already.',
    })
    expect(askIn(written, 'k1').state, what).toBe('closed')
    expect(
      askIn(written, 'k1').replies.map(each => [each.id, each.delivery]),
      what,
    ).toEqual([['r1', 'delivered']])
  }
})

test('an edit leaving the reply in flight unfit leaves it out, the ask waiting on Lee; one making it fit again has it on its way, and its lines settle the ask once written', () => {
  const toChoice: Body = {
    type: 'edit',
    item: 'k1',
    changes: { wants: 'choice', options: ['A', 'B'] },
  }
  const toYes: Body = { type: 'edit', item: 'k1', changes: { wants: 'yes', yes: 'Approve' } }
  const unfit = sessionOf([REVIEW, ...whileWaiting(toChoice)], windowOn(W1, sending(YES)))
  const fitAgain = sessionOf([REVIEW, ...whileWaiting(toChoice, toYes)], windowOn(W1, sending(YES)))
  const written = sessionOf(
    [REVIEW, ...whileWaiting(toChoice, toYes), ...writtenDown(reply('r1', 'k1', 'yes'))],
    windowOn(W1, sending(YES)),
  )

  expect(askIn(unfit, 'k1').replies).toEqual([])
  expect(unfit.waiting).toBe(1)
  expect(askIn(fitAgain, 'k1').answerOnItsWay?.id).toBe('r1')
  expect(needingLee(fitAgain)).toEqual(NONE)
  expect(askIn(written, 'k1').state).toBe('closed')
})

test('an answer in flight barred by an inbox answer delivered while the send waits comes back once Claude reopens the ask: the bar is judged as the ask stands, and its lines settle the ask once written', () => {
  const inbox = { [CLI]: file([CLAIMED - 30_000, reply('r9', 'k1', 'yes')]) }
  const during = whileWaiting(delivered('r9'), reopen('k1'))
  const waiting = sessionOf([REVIEW, ...during], windowOn(W1, sending(YES)), inbox)
  const written = sessionOf(
    [REVIEW, ...during, ...writtenDown(reply('r1', 'k1', 'yes'))],
    windowOn(W1, sending(YES)),
    inbox,
  )

  expect(askIn(waiting, 'k1').answerOnItsWay?.id).toBe('r1')
  expect(needingLee(waiting)).toEqual(NONE)
  expect(checkAnswer(waiting, { ask: 'k1', answer: 'Approve' })).toEqual({
    ok: false,
    error: 'An answer to k1 is on its way already.',
  })
  expect(askIn(written, 'k1')).toMatchObject({ state: 'closed', answer: { id: 'r1' } })
})

test('what a left-out answer in flight barred reaches its item again as of what left it out: an ignore after it ends void as Claude resolved the ask', () => {
  const inbox = { [CLI]: file([CLAIMED + 10_000, reply('r9', 'k1', 'ignore')]) }
  const resolvedAt = CLAIMED + 20_000
  const session = sessionOf(
    [REVIEW, [resolvedAt, resolve('k1')]],
    windowOn(W1, sending(YES)),
    inbox,
  )

  expect(session.replies.find(each => each.id === 'r9')).toMatchObject({
    delivery: 'void',
    voided: 'resolved',
    voidedAt: resolvedAt,
  })
  expect(askIn(session, 'k1').replies.map(each => each.id)).toEqual(['r9'])
})

test('what an answer in flight barred reaches its item again through an edit that leaves the answer unfit: the ignore after it is on its way', () => {
  const inbox = { [CLI]: file([CLAIMED + 10_000, reply('r9', 'k1', 'ignore')]) }
  const toWords: Body = { type: 'edit', item: 'k1', changes: { wants: 'words' } }
  const session = sessionOf(
    [REVIEW, [CLAIMED + 20_000, toWords]],
    windowOn(W1, sending(YES)),
    inbox,
  )

  expect(askIn(session, 'k1').answerOnItsWay?.id).toBe('r9')
  expect(askIn(session, 'k1').replies.map(each => [each.id, each.delivery])).toEqual([
    ['r9', 'waiting'],
  ])
  expect(needingLee(session)).toEqual(NONE)
})

test('an answer in flight barred by an inbox answer comes back on its way once that answer goes void, and its lines settle the ask once written', () => {
  const IGNORE = { id: 'r1', item: 'k1', verdict: 'ignore' } as const
  const toWords: Body = { type: 'edit', item: 'k1', changes: { wants: 'words' } }
  const inbox = { [CLI]: file([CLAIMED - 30_000, reply('r9', 'k1', 'yes')]) }
  const barred = sessionOf([REVIEW], windowOn(W1, sending(IGNORE)), inbox)
  const unbarred = sessionOf(
    [REVIEW, ...whileWaiting(toWords)],
    windowOn(W1, sending(IGNORE)),
    inbox,
  )
  const written = sessionOf(
    [REVIEW, ...whileWaiting(toWords), ...writtenDown(reply('r1', 'k1', 'ignore'))],
    windowOn(W1, sending(IGNORE)),
    inbox,
  )

  expect(askIn(barred, 'k1').answerOnItsWay?.id).toBe('r9')
  expect(askIn(barred, 'k1').replies.map(each => each.id)).toEqual(['r9'])
  expect(unbarred.replies.find(each => each.id === 'r9')?.voided).toBe('changed')
  expect(askIn(unbarred, 'k1').answerOnItsWay?.id).toBe('r1')
  expect(needingLee(unbarred)).toEqual(NONE)
  expect(askIn(written, 'k1').state).toBe('ignored')
})

test("a parked item's pick-up in flight is on its way from the claim, and bars a second", () => {
  const parked = sessionOf(
    [[T0, park('p1', 'A priority badge across all tabs')]],
    windowOn(W1, sending({ id: 'r4', item: 'p1', verdict: 'pickup' })),
  )
  const [item] = parked.parked

  expect(item === undefined ? undefined : replyOnItsWay(item)).toMatchObject({
    id: 'r4',
    verdict: 'pickup',
    delivery: 'waiting',
  })
  expect(item === undefined ? undefined : barredBy(item, 'pickup')).toBe('answered')
  expect(parked.replies).toEqual([])
})

test("a reply in flight is no reply of the session's: no inbox delivers it, and Claude, not given it yet, still reads its ask waiting on Lee", () => {
  const session = sessionOf([REVIEW], {
    ...windowOn(W1, sending(YES)),
    ...windowOn(W2, undefined, { attachedAt: T0 - MIN }),
  })

  expect(session.replies).toEqual([])
  expect(session.ids.has('r1')).toBe(false)
  expect(toDeliver(session, W2)).toEqual([])
  expect(toldSummary(session).waiting).toBe(1)
  expect(boardText(session)).toContain('k1 wants a yes (Approve), waiting on Lee')
})

test("two windows' messages each count, the earlier claim's answer barring the later's, whichever window it is", () => {
  const IGNORE = { id: 'r3', item: 'k1', verdict: 'ignore' } as const
  const claims = (yesAt: number, ignoreAt: number) =>
    sessionOf([REVIEW, SIDEBAR], {
      ...windowOn(W1, claimed(yesAt, YES)),
      ...windowOn(W2, claimed(ignoreAt, IGNORE, COMMENT)),
    })
  const yesFirst = claims(CLAIMED - MIN, CLAIMED)
  const ignoreFirst = claims(CLAIMED, CLAIMED - MIN)

  expect(needingLee(yesFirst)).toEqual(NONE)
  expect(askIn(yesFirst, 'k1').replies.map(each => each.id)).toEqual(['r1'])
  expect(needingLee(ignoreFirst)).toEqual(NONE)
  expect(askIn(ignoreFirst, 'k1').replies.map(each => each.id)).toEqual(['r3'])
})

test('a heartbeat says what its window sends field by field: a bad reply is dropped, one without its time or any reply that reads says nothing, and the heartbeat stands', () => {
  const read = (value: unknown) =>
    parsePresence(JSON.stringify({ attachedAt: T0, seenAt: NOW, sending: value }), W1)

  expect(read({ at: CLAIMED, replies: [YES, { id: 'r2', item: 'k2' }, 'yes'] })?.sending).toEqual([
    sending(YES),
  ])
  expect(read({ replies: [YES] })).toMatchObject({ writer: W1, sending: undefined })
  expect(
    read({ at: CLAIMED, replies: [{ verdict: 'shrug', id: 'r1', item: 'k1' }] })?.sending,
  ).toBe(undefined)
  expect(read({ at: CLAIMED, replies: [{ ...COMMENT, extra: 1 }] })?.sending).toEqual([
    sending(COMMENT),
  ])
  expect(read([{ replies: [YES] }, sending(COMMENT)])?.sending, 'of several, each').toEqual([
    sending(COMMENT),
  ])
  expect(read([{ replies: [YES] }])).toMatchObject({ writer: W1, sending: undefined })
})

test('a window sending one message says it alone, as builds before several messages said it; several go as a list, in the order claimed, and both read back', () => {
  const earlier = claimed(CLAIMED - MIN, YES)
  const one = attach(W1, T0, { sending: [sending(YES)] })
  const two = attach(W1, T0, { sending: [earlier, sending(COMMENT)] })

  expect(JSON.parse(presenceText(one)).sending).toEqual(sending(YES))
  expect(JSON.parse(presenceText(two)).sending).toEqual([earlier, sending(COMMENT)])
  expect(parsePresence(presenceText(one), W1)?.sending).toEqual([sending(YES)])
  expect(parsePresence(presenceText(two), W1)?.sending).toEqual([earlier, sending(COMMENT)])
})

test('a send in flight never holds back the replies it carries for its own answer, on its way from the claim, nor carries them again: a send pressed meanwhile finds them going, not answered, and carries the rest', () => {
  const session = sessionOf([REVIEW, SIDEBAR], windowOn(W1, sending(YES)))
  const carried = {
    project: NORTHWIND.key,
    session: META.id,
    item: 'k1',
    verdict: 'yes',
  } as const
  const other = { ...carried, item: 'k2', verdict: 'choose', option: 'Keep it' } as const
  const folded = new Map([[session.id, session]])
  const held = { project: NORTHWIND.key, session: META.id }
  const unsent = unsentTo([carried, other], [inFlight({ type: 'reply', ...YES })], held, META.id)

  expect(sendable(META.id, folded, unsent)).toEqual([other])
  expect(leftOut(META.id, folded, unsent)).toEqual([])
  expect(
    leftOut(META.id, folded, unsentTo([carried], [], held, META.id)),
    "another's answer bars it",
  ).toEqual(['answered'])
})

test('a send leaves out a reply to an ask of a session finished, which no reply reaches; from the window holding that session, it carries it', () => {
  const session = sessionOf([REVIEW, [T0 + MIN, finish('claude')]], {})
  const yes = { project: NORTHWIND.key, session: META.id, item: 'k1', verdict: 'yes' } as const
  const folded = new Map([[session.id, session]])

  expect(sendable('sr-other1', folded, [yes]), 'from another window').toEqual([])
  expect(leftOut('sr-other1', folded, [yes])).toEqual(['finished'])
  expect(sendable(META.id, folded, [yes]), 'from the window holding it').toEqual([yes])
  expect(leftOut(META.id, folded, [yes])).toEqual([])
})

test("a message's replies take ids unlike any its session uses, and any a message in flight carries, not written down yet", () => {
  const session = sessionOf([[T0, yesAsk('0000', 'Review round 1')], SIDEBAR], {})
  const keep = {
    project: NORTHWIND.key,
    session: META.id,
    item: 'k2',
    verdict: 'choose',
    option: 'Keep it',
  } as const
  const flight = inFlight({ type: 'reply', id: '1111', item: '0000', verdict: 'yes' })
  const draws = () => scripted([0], [1], [2])

  expect(replyBodies(session, [keep], {}, draws())).toMatchObject([{ id: '1111', item: 'k2' }])
  expect(replyBodies(session, [keep], { flights: [flight] }, draws())).toMatchObject([
    { id: '2222', item: 'k2' },
  ])
})

test('a window that lets go sends nothing', () => {
  const sent = attach(W1, T0, { sending: [sending(YES)] })

  expect(JSON.parse(presenceText(sent))).toMatchObject({ sending: sending(YES) })
  expect(JSON.parse(presenceText(leave(sent, NOW)))).not.toHaveProperty('sending')
})
