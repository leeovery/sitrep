/**
 * Lee's replies a window sends its own session as Lee's message, published
 * in its heartbeat from the claim: on their way to every reader from then,
 * as an inbox reply is, until the session's lines carry them or the message
 * is let go, or the window is gone.
 */
import { expect, test } from 'claude-code/testing'
import { boardJson, listing } from '../cli/output'
import { leftOut, sendable } from '../hooks/queue'
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
  replyState,
  rowOf,
  STALE_MS,
  summarise,
  toDeliver,
  toldSummary,
  waitsOnLee,
  type Presence,
  type Project,
  type Sending,
  type Session,
} from '../core'
import {
  beat,
  choiceAsk,
  CLI,
  delivered,
  file,
  finish,
  META,
  MIN,
  reply,
  resolve,
  T0,
  W1,
  W2,
  yesAsk,
  type Line,
} from './support'

const NOW = T0 + 60 * MIN

const CLAIMED = NOW - MIN

const SWITCHBOARD: Project = {
  key: 'switchboard',
  name: 'Switchboard',
  directory: '/Users/lee/Code/switchboard',
}

const REVIEW: Line = [T0, yesAsk('k1', 'Review round 1')]
const SIDEBAR: Line = [T0, choiceAsk('k2', 'Keep the sidebar?', ['Keep it', 'Drop it'])]

/** Lee's yes to the review, and a comment on the sidebar, as a send claims them. */
const YES = { id: 'r1', item: 'k1', verdict: 'yes' } as const
const COMMENT = { id: 'r2', item: 'k2', verdict: 'comment', note: 'Narrower first' } as const

const sending = (...replies: Sending['replies']): Sending => ({ at: CLAIMED, replies })

/** A window's heartbeat, live at NOW unless the times say otherwise, sending what it is given. */
const windowOn = (writer: string, what?: Sending, times: Partial<Presence> = {}) => ({
  [writer]: beat(writer, {
    attachedAt: T0,
    seenAt: NOW,
    version: '0.2.0',
    state: { is: 'working', since: CLAIMED },
    sending: what,
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
  const listed = listing([{ project: SWITCHBOARD, sessions: [summarise(session)] }], '/', NOW)
  const board = JSON.parse(boardJson(SWITCHBOARD.key, session)) as {
    work: { waiting: number }
    asks: { id: string; reply: { is: string; isAnswer: boolean; words: string } | null }[]
  }

  return {
    waiting: session.waiting,
    rows: (rowOf(SWITCHBOARD, session, NOW)?.lines ?? [])
      .filter(line => line.is === 'ask')
      .map(line => line.ask),
    head: feedOf([{ project: SWITCHBOARD, sessions: [session] }], NOW).head.needYou,
    list: listed.projects.map(project => [project.waiting, project.sessions[0]?.waiting]),
    board: board.work.waiting,
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
  const board = JSON.parse(boardJson(SWITCHBOARD.key, session)) as { asks: { reply: unknown }[] }

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

test('an inbox answer reaching the ask after the claim is barred by it as the fold reads them, and the ask still needs Lee no more', () => {
  const session = sessionOf([REVIEW], windowOn(W1, sending(YES)), {
    [CLI]: file([NOW - MIN / 2, reply('r9', 'k1', 'yes')]),
  })

  expect(waitsOnLee(askIn(session, 'k1'))).toBe(false)
  expect(askIn(session, 'k1').answerOnItsWay?.id, 'the inbox line is read before the claim').toBe(
    'r9',
  )
  expect(
    askIn(session, 'k1').replies.map(each => each.id),
    'the claim, barred, is left out',
  ).toEqual(['r9'])
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
      rowOf(SWITCHBOARD, session, NOW)?.lines.map(line => line.ask),
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

test('a reply in flight its item takes no more is left out: the ask closed by Claude, or the session finished', () => {
  const resolved = sessionOf([REVIEW, [CLAIMED - MIN, resolve('k1')]], windowOn(W1, sending(YES)))
  const finished = sessionOf(
    [REVIEW, [CLAIMED - MIN, finish('claude')]],
    windowOn(W1, sending(YES)),
  )

  expect(askIn(resolved, 'k1').replies).toEqual([])
  expect(replyState(askIn(resolved, 'k1'))).toBeUndefined()
  expect(askIn(finished, 'k1').replies).toEqual([])
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

test("two windows' messages each count, the first answer read barring the other's", () => {
  const session = sessionOf([REVIEW, SIDEBAR], {
    ...windowOn(W1, sending(YES)),
    ...windowOn(W2, sending({ id: 'r3', item: 'k1', verdict: 'ignore' }, COMMENT)),
  })

  expect(needingLee(session)).toEqual(NONE)
  expect(askIn(session, 'k1').answerOnItsWay?.id).toBe('r1')
  expect(askIn(session, 'k1').replies.map(each => each.id)).toEqual(['r1'])
})

test('a heartbeat says what its window sends field by field: a bad reply is dropped, one without its time or any reply that reads says nothing, and the heartbeat stands', () => {
  const read = (value: unknown) =>
    parsePresence(JSON.stringify({ attachedAt: T0, seenAt: NOW, sending: value }), W1)

  expect(read({ at: CLAIMED, replies: [YES, { id: 'r2', item: 'k2' }, 'yes'] })?.sending).toEqual(
    sending(YES),
  )
  expect(read({ replies: [YES] })).toMatchObject({ writer: W1, sending: undefined })
  expect(
    read({ at: CLAIMED, replies: [{ verdict: 'shrug', id: 'r1', item: 'k1' }] })?.sending,
  ).toBe(undefined)
  expect(read({ at: CLAIMED, replies: [{ ...COMMENT, extra: 1 }] })?.sending).toEqual(
    sending(COMMENT),
  )
})

test('a send in flight never holds back the replies it carries for its own answer, on its way from the claim: a send pressed meanwhile finds them going, not answered', () => {
  const session = sessionOf([REVIEW, SIDEBAR], windowOn(W1, sending(YES)))
  const carried = {
    project: SWITCHBOARD.key,
    session: META.id,
    item: 'k1',
    verdict: 'yes',
  } as const
  const other = { ...carried, item: 'k2', verdict: 'choose', option: 'Keep it' } as const
  const inFlight: SitrepInFlight = {
    source: 'send',
    project: SWITCHBOARD.key,
    session: META.id,
    writer: W1,
    text: 'From the board:\n- Review round 1 → Approve',
    replies: [{ type: 'reply', ...YES }],
    claimedAt: CLAIMED,
    isTaken: false,
  }

  expect(sendable(session, [carried, other], inFlight)).toEqual([carried, other])
  expect(leftOut(session, [carried, other], inFlight)).toEqual([])
  expect(leftOut(session, [carried], null), "another's answer bars it").toEqual(['answered'])
})

test('a window that lets go sends nothing', () => {
  const sent = attach(W1, T0, { sending: sending(YES) })

  expect(JSON.parse(presenceText(sent))).toMatchObject({ sending: sending(YES) })
  expect(JSON.parse(presenceText(leave(sent, NOW)))).not.toHaveProperty('sending')
})
