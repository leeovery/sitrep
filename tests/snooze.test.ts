/**
 * Lee's snooze of a session: when it wakes, as the fold reads the lines at a
 * moment, what wakes it sooner and what leaves it, where its asks count, how
 * the lines from before a snooze was the session's read, and Snooze's times
 * as they are worded (as they are worked out, in wakes.test.ts).
 */
import { expect, test } from './kit'
import {
  isSnoozed,
  isUntilItMoves,
  parseEntries,
  serialise,
  snoozedAsks,
  snoozedUntilOf,
  summarise,
  UNTIL_IT_MOVES,
  VERSION,
  waitingOnLee,
  wakeWords,
  wholeTime,
  type Body,
  type Sending,
  type Session,
  type SessionFiles,
} from '../core'
import {
  beat,
  CLI,
  file,
  finish,
  fold,
  MIN,
  note,
  park,
  reopen,
  reply,
  resolve,
  snooze,
  snoozeSession,
  status,
  T0,
  unfinish,
  W1,
  W2,
  wake,
  wakeSession,
  yesAsk,
  type Line,
} from './support'
import { inZone } from './zoned'

const HOUR = 60 * MIN

/** When the session is folded, unless a test says otherwise. */
const NOW = T0 + HOUR

/** When the snooze under test wakes: two hours after NOW. */
const UNTIL = NOW + 2 * HOUR

const REVIEW: Line = [T0, yesAsk('k1', 'Review round 1')]

const SHIP: Line = [T0, yesAsk('k2', 'Ship it', 'Go')]

const SNOOZED: Line = [T0 + MIN, snoozeSession(UNTIL, 'k1', 'k2')]

/** Where the session's asks stand under its snooze, by id, and what it counts of them. */
const standing = (session: Session) => ({
  asks: session.asks.map(ask => [ask.id, ask.snoozedUntil, ask.wokeAt]),
  waiting: session.waiting,
  snoozed: snoozedAsks(session).length,
})

/** Both asks put off until UNTIL. */
const ASLEEP = {
  asks: [
    ['k1', UNTIL, undefined],
    ['k2', UNTIL, undefined],
  ],
  waiting: 0,
  snoozed: 2,
}

/** Both asks waiting on Lee, never woken by the time. */
const AWAKE = {
  asks: [
    ['k1', undefined, undefined],
    ['k2', undefined, undefined],
  ],
  waiting: 2,
  snoozed: 0,
}

/** Both asks back, woken by the time. */
const WOKE = {
  asks: [
    ['k1', undefined, UNTIL],
    ['k2', undefined, UNTIL],
  ],
  waiting: 2,
  snoozed: 0,
}

/** The session folded at `now` from the window's lines, with any other files. */
const foldAt = (now: number, lines: Line[], files: Partial<SessionFiles> = {}) =>
  fold({ ...files, logs: { [W1]: file(...lines), ...files.logs } }, now)

/** The session with its two asks, snoozed, then the lines given, folded at `now`. */
const asleepThen = (lines: Line[], now = NOW, files: Partial<SessionFiles> = {}) =>
  foldAt(now, [REVIEW, SHIP, SNOOZED, ...lines], files)

test("Lee's snooze of a session puts off every ask waiting as posted until its time, none waiting on Lee; at its time it has run out, and each carries when it woke", () => {
  expect(standing(asleepThen([]))).toEqual(ASLEEP)
  expect(standing(asleepThen([], UNTIL - 1))).toEqual(ASLEEP)
  expect(standing(asleepThen([], UNTIL))).toEqual(WOKE)
  expect(standing(asleepThen([], UNTIL + 9 * HOUR)), 'however long after').toEqual(WOKE)
  expect(asleepThen([]).snooze).toEqual({ until: UNTIL, at: T0 + MIN, asks: ['k1', 'k2'] })
  expect([
    snoozedUntilOf(asleepThen([]), NOW),
    snoozedUntilOf(asleepThen([], UNTIL), UNTIL),
  ]).toEqual([UNTIL, undefined])
})

test('snoozing again moves the time, sooner or later, and snoozes afresh a session whose snooze ran out', () => {
  const again = (until: number, at = T0 + 2 * MIN) =>
    asleepThen([[at, snoozeSession(until, 'k1', 'k2')]])

  expect(standing(again(UNTIL + HOUR)).asks[0]).toEqual(['k1', UNTIL + HOUR, undefined])
  expect(standing(again(NOW + MIN)).asks[0]).toEqual(['k1', NOW + MIN, undefined])
  expect(
    standing(
      foldAt(NOW, [
        REVIEW,
        SHIP,
        [T0 + MIN, snoozeSession(T0 + 10 * MIN, 'k1', 'k2')],
        [T0 + 20 * MIN, snoozeSession(UNTIL, 'k1', 'k2')],
      ]),
    ),
  ).toEqual(ASLEEP)
})

test("Lee's wake ends it, before its time or after: every ask waits on Lee again, with no time it woke at", () => {
  const woken = { logs: { [CLI]: file([T0 + 2 * MIN, wakeSession()]) } }

  expect(standing(asleepThen([], NOW, woken))).toEqual(AWAKE)
  expect(standing(asleepThen([], UNTIL + HOUR, woken))).toEqual(AWAKE)
  expect(asleepThen([], NOW, woken).snooze).toBeUndefined()
})

test('a new ask posted after the snooze wakes the session, the asks it put off back with it; one posted before it is put off too', () => {
  const posted = asleepThen([[T0 + 2 * MIN, yesAsk('k3', 'Tag the release', 'Done')]])

  expect(standing(posted)).toEqual({
    asks: [...AWAKE.asks, ['k3', undefined, undefined]],
    waiting: 3,
    snoozed: 0,
  })
  expect(posted.snooze).toBeUndefined()
  expect(
    standing(
      foldAt(NOW, [
        REVIEW,
        SHIP,
        [T0, yesAsk('k3', 'Tag the release')],
        [T0 + MIN, snoozeSession(UNTIL, 'k1', 'k2', 'k3')],
      ]),
    ).snoozed,
  ).toBe(3)
})

test('a reopen of an ask wakes the session, Claude raising it again: it waits on Lee since its reopening', () => {
  const session = foldAt(NOW, [
    REVIEW,
    SHIP,
    [T0, yesAsk('k3', 'Tag the release')],
    [T0, resolve('k3')],
    SNOOZED,
    [T0 + 2 * MIN, reopen('k3', 'Asked again')],
  ])

  expect([session.waiting, session.snooze, session.asks[2]?.openedAt]).toEqual([
    3,
    undefined,
    T0 + 2 * MIN,
  ])
})

test("Lee's reply to one of the asks it holds wakes the session, the rest back with it: he has dealt with it; a pick-up of something it parked does not", () => {
  const answered = asleepThen([], NOW, {
    inbox: { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k1', 'comment', { note: 'Tighten it' })]) },
  })
  const pickedUp = foldAt(NOW, [REVIEW, SHIP, [T0, park('p1', 'Later')], SNOOZED], {
    inbox: { [CLI]: file([T0 + 2 * MIN, reply('r1', 'p1', 'pickup')]) },
  })

  expect([answered.snooze, answered.waiting, snoozedAsks(answered)]).toEqual([undefined, 1, []])
  expect(standing(pickedUp)).toEqual(ASLEEP)
})

test("its turn ending alone, Claude's other lines and a window joining wake nothing: a status, a note, an edit, a resolve, a park, a heartbeat", () => {
  const session = asleepThen(
    [
      [T0 + 2 * MIN, status(['Waiting on the agents'])],
      [T0 + 2 * MIN, note('n1', 'Agents done')],
      [T0 + 2 * MIN, { type: 'edit', item: 'k2', changes: { title: 'Ship it now' } }],
      [T0 + 2 * MIN, resolve('k1')],
      [T0 + 2 * MIN, park('p1', 'Later')],
    ],
    NOW,
    {
      presence: {
        [W2]: beat(W2, {
          attachedAt: T0 + 3 * MIN,
          seenAt: NOW,
          state: { is: 'yourTurn', since: T0 + 30 * MIN },
        }),
      },
    },
  )

  expect(standing(session)).toEqual({
    asks: [
      ['k1', undefined, undefined],
      ['k2', UNTIL, undefined],
    ],
    waiting: 0,
    snoozed: 1,
  })
  expect(session.asks.map(ask => [ask.title, ask.state])).toEqual([
    ['Review round 1', 'closed'],
    ['Ship it now', 'waiting'],
  ])
})

test('a finish leaves the snooze: nothing of a finished session counts, its snooze among them, and a join before its time finds it still snoozed, after it woken', () => {
  const finished: Line[] = [[T0 + 2 * MIN, finish('lee')]]
  const joined: Line[] = [...finished, [T0 + 3 * MIN, unfinish()]]
  const session = asleepThen(finished)

  expect([session.waiting, snoozedAsks(session), summarise(session).snoozed]).toEqual([0, [], 0])
  expect(snoozedUntilOf(session, NOW)).toBeUndefined()
  expect(standing(asleepThen(joined))).toEqual(ASLEEP)
  expect(standing(asleepThen(joined, UNTIL))).toEqual(WOKE)
})

/** Lee's yes to k1, as a window's send claims it a minute before `now`. */
const sendingYes = (now: number): Sending => ({
  at: now - MIN,
  replies: [{ id: 'r1', item: 'k1', verdict: 'yes' }],
})

/** A window live at `now`, sending what it is given. */
const windowAt = (now: number, sending?: Sending) => ({
  [W2]: beat(W2, { attachedAt: T0, seenAt: now, sending: sending && [sending] }),
})

test("Lee's reply in a window's message takes its ask out of Snoozed as out of Needs you from its claim, the snooze standing over the rest until it is written down; taken back, it is snoozed again while its time is to come, else woken", () => {
  const onItsWay = asleepThen([], NOW, { presence: windowAt(NOW, sendingYes(NOW)) })

  expect(standing(onItsWay)).toEqual({ ...ASLEEP, snoozed: 1 })
  expect(isSnoozed(onItsWay.asks[0]!)).toBe(false)
  expect(standing(asleepThen([], NOW, { presence: windowAt(NOW) })), 'taken back').toEqual(ASLEEP)
  expect(
    standing(asleepThen([], UNTIL, { presence: windowAt(UNTIL) })),
    'taken back after its time',
  ).toEqual(WOKE)
})

test("of two writers' lines at one moment the later in the fold's order wins, by writer, the same in every reader", () => {
  const at = T0 + 2 * MIN
  const raced = (logs: Record<string, Body[]>) =>
    standing(
      fold({
        logs: Object.fromEntries(
          Object.entries(logs).map(([writer, bodies]) => [
            writer,
            file(
              ...(writer === W1 ? [REVIEW, SHIP] : []),
              ...bodies.map((body): Line => [at, body]),
            ),
          ]),
        ),
      }),
    )

  const snoozed = (until: number) => snoozeSession(until, 'k1', 'k2')

  expect(raced({ [W1]: [snoozed(UNTIL)], [W2]: [wakeSession()] })).toEqual(AWAKE)
  expect(raced({ [W1]: [wakeSession()], [W2]: [snoozed(UNTIL)] })).toEqual(ASLEEP)
  expect(
    raced({ [W1]: [snoozed(UNTIL)], [CLI]: [wakeSession()] }),
    "a window's, then the CLI's",
  ).toEqual(AWAKE)
  expect(raced({ [W1]: [snoozed(UNTIL + HOUR)], [W2]: [snoozed(UNTIL)] }), 'two snoozes').toEqual(
    ASLEEP,
  )
})

test('a session waits on Lee for what is not snoozed; every ask waiting as posted, snoozed or on its way, still counts as asked, which keeps the session current', () => {
  const session = asleepThen([], NOW, { presence: windowAt(NOW, sendingYes(NOW)) })

  expect(waitingOnLee(session)).toEqual([])
  expect(snoozedAsks(session).map(ask => ask.id)).toEqual(['k2'])
  expect(summarise(session)).toMatchObject({ waiting: 0, snoozed: 1, asked: 2 })
})

/** Lee's answers to k1 in the inbox: his yes, at `at`, then any more. */
const answeredAt = (at: number, ...more: Line[]) => ({
  inbox: { [CLI]: file([at, reply('r1', 'k1', 'yes')], ...more) },
})

/** The snooze, written while Lee's answer to k1 was on its way, holding k2 alone. */
const HOLDS_K2: Line = [T0 + MIN, snoozeSession(UNTIL, 'k2')]

/** Where the asks stand with k1's answer on its way and k2 asleep. */
const K2_ASLEEP = {
  asks: [
    ['k1', undefined, undefined],
    ['k2', UNTIL, undefined],
  ],
  waiting: 0,
  snoozed: 1,
}

test('a snooze holds the asks waiting on Lee as it was written, named on its line: his answer to another on its way then, written down after it, wakes nothing', () => {
  const claimed = foldAt(NOW, [REVIEW, SHIP, HOLDS_K2], {
    presence: windowAt(NOW, { ...sendingYes(NOW), at: T0 + MIN / 2 }),
  })
  const written = foldAt(NOW, [REVIEW, SHIP, HOLDS_K2], {
    logs: { [W2]: file([T0 + 3 * MIN, reply('r1', 'k1', 'yes')]) },
  })

  expect(standing(claimed)).toEqual(K2_ASLEEP)
  expect(standing(written)).toEqual(K2_ASLEEP)
  expect(written.snooze?.asks).toEqual(['k2'])
})

test('an ask it does not hold waiting on Lee again, its answer on its way then voided or taken back, wakes the session while it waits; answered again, the snooze holds the rest', () => {
  const edited: Line = [T0 + 2 * MIN, { type: 'edit', item: 'k1', changes: { wants: 'words' } }]
  const voided = foldAt(NOW, [REVIEW, SHIP, HOLDS_K2, edited], answeredAt(T0 + MIN / 2))
  const takenBack = foldAt(NOW, [REVIEW, SHIP, HOLDS_K2], { presence: windowAt(NOW) })
  const again = foldAt(
    NOW,
    [REVIEW, SHIP, HOLDS_K2, edited],
    answeredAt(T0 + MIN / 2, [T0 + 3 * MIN, reply('r2', 'k1', 'answer', { note: 'Done' })]),
  )

  expect(standing(voided)).toEqual(AWAKE)
  expect(voided.snooze).toBeUndefined()
  expect(standing(takenBack), 'taken back, never written').toEqual(AWAKE)
  expect(standing(again)).toEqual(K2_ASLEEP)
})

test('a snooze with no time holds until it moves: no time wakes it, its asks sleeping after every time, until a line wakes it', () => {
  const MOVES: Line = [T0 + MIN, snoozeSession(undefined, 'k1', 'k2')]
  const later = UNTIL + 9 * HOUR
  const moves = foldAt(later, [REVIEW, SHIP, MOVES])

  expect(standing(moves).asks).toEqual([
    ['k1', UNTIL_IT_MOVES, undefined],
    ['k2', UNTIL_IT_MOVES, undefined],
  ])
  expect([snoozedUntilOf(moves, later), isUntilItMoves(moves)]).toEqual([UNTIL_IT_MOVES, true])
  expect(isUntilItMoves(asleepThen([])), 'one with a time').toBe(false)
  expect(standing(foldAt(later, [REVIEW, SHIP, MOVES, [T0 + 2 * MIN, wakeSession()]]))).toEqual(
    AWAKE,
  )
  expect(
    standing(foldAt(later, [REVIEW, SHIP, MOVES, [T0 + 2 * MIN, yesAsk('k3', 'Tag it')]])).snoozed,
    'a new ask',
  ).toBe(0)
})

/** k1 put off by an old line until UNTIL. */
const OLD_K1: Line = [T0 + MIN, snooze('k1', UNTIL)]

/** Harness's case: both asks put off by old lines, written together, k2 an hour later than k1. */
const OLD_ROW: Line[] = [REVIEW, SHIP, OLD_K1, [T0 + MIN, snooze('k2', UNTIL + HOUR)]]

test("an old line's snooze of an ask keeps its own time, ended as its ask closes, reopens or is woken; one naming anything else is passed over", () => {
  const passedOver = foldAt(NOW, [
    [T0, snooze('k4', UNTIL)],
    REVIEW,
    SHIP,
    [T0, yesAsk('k3', 'Keep it', 'Keep')],
    [T0, note('n1', 'Merged')],
    [T0, park('p1', 'Later')],
    [T0 + MIN, resolve('k3')],
    [T0 + MIN, yesAsk('k4', 'Tag the release', 'Done')],
    ...['k3', 'n1', 'p1', 'zzzz'].map((id): Line => [T0 + 2 * MIN, snooze(id, UNTIL)]),
  ])
  const k1Asleep = {
    asks: [
      ['k1', UNTIL, undefined],
      ['k2', undefined, undefined],
    ],
    waiting: 1,
    snoozed: 1,
  }

  expect(standing(foldAt(NOW, [REVIEW, SHIP, OLD_K1]))).toEqual(k1Asleep)
  expect(foldAt(NOW, [REVIEW, SHIP, OLD_K1]).snooze).toBeUndefined()
  expect(standing(foldAt(UNTIL, [REVIEW, SHIP, OLD_K1])).asks[0]).toEqual(['k1', undefined, UNTIL])
  expect(standing(foldAt(NOW, OLD_ROW)).asks).toEqual([
    ['k1', UNTIL, undefined],
    ['k2', UNTIL + HOUR, undefined],
  ])
  expect([passedOver.waiting, snoozedAsks(passedOver)]).toEqual([3, []])
  expect(standing(foldAt(NOW, [REVIEW, SHIP, OLD_K1, [T0 + 2 * MIN, wake('k1')]]))).toEqual(AWAKE)
  expect(
    standing(foldAt(NOW, [REVIEW, SHIP, OLD_K1, [T0 + 2 * MIN, resolve('k1')]])).snoozed,
    'resolved',
  ).toBe(0)
  expect(
    standing(foldAt(NOW, [...OLD_ROW, [T0 + 2 * MIN, wakeSession()]])),
    "Lee's wake of the session",
  ).toEqual(AWAKE)
})

test("old lines' snoozes holding every ask waiting on Lee put its turn off with them, until the first wakes or closes; an ask left showing leaves the turn as it was", () => {
  const then = (now: number, ...lines: Line[]) => foldAt(now, [...OLD_ROW, ...lines]).turnWithAsks

  expect(then(NOW)).toBe(UNTIL)
  expect(then(UNTIL), 'the first woken').toBeUndefined()
  expect(then(NOW, [T0 + 2 * MIN, resolve('k1')]), 'the first resolved').toBeUndefined()
  expect(then(NOW, [T0 + 2 * MIN, yesAsk('k3', 'Tag it')]), 'a new ask').toBeUndefined()
  expect(foldAt(NOW, [REVIEW, SHIP, OLD_K1]).turnWithAsks, 'k2 left showing').toBeUndefined()
  expect(
    foldAt(NOW, [REVIEW, SHIP, OLD_K1, [T0 + 2 * MIN, snooze('k2', UNTIL)]]).turnWithAsks,
    'the pane snoozing one, then the other',
  ).toBe(UNTIL)
})

test("Lee's snooze of the session stands in place of the old lines' snoozes of its asks, and of their turn", () => {
  const replaced = foldAt(NOW, [
    ...OLD_ROW,
    [T0 + 2 * MIN, snoozeSession(UNTIL + 2 * HOUR, 'k1', 'k2')],
  ])

  expect(standing(replaced).asks).toEqual([
    ['k1', UNTIL + 2 * HOUR, undefined],
    ['k2', UNTIL + 2 * HOUR, undefined],
  ])
  expect(replaced.turnWithAsks).toBeUndefined()
})

test("an old reader skips the session's lines: kinds at the format's version 1 it does not know, the rest of the file standing and its asks waiting", () => {
  const text = file(
    REVIEW,
    SHIP,
    SNOOZED,
    [T0 + 2 * MIN, wakeSession()],
    [T0 + 3 * MIN, note('n1', 'Merged')],
  )
  const unknown = text.replace(/"type":"(snoozeSession|wakeSession)"/g, '"type":"later-kind"')

  expect(serialise({ v: VERSION, at: T0, seq: 9, ...snoozeSession(UNTIL, 'k1', 'k2') })).toBe(
    `{"v":1,"at":${T0},"seq":9,"type":"snoozeSession","until":${UNTIL},"asks":["k1","k2"]}\n`,
  )
  expect(serialise({ v: VERSION, at: T0, seq: 9, ...snoozeSession(undefined) })).toBe(
    `{"v":1,"at":${T0},"seq":9,"type":"snoozeSession","asks":[]}\n`,
  )
  expect(serialise({ v: VERSION, at: T0, seq: 10, ...wakeSession() })).toBe(
    `{"v":1,"at":${T0},"seq":10,"type":"wakeSession"}\n`,
  )
  expect(parseEntries(unknown).map(entry => entry.type)).toEqual(['ask', 'ask', 'note'])
  expect(standing(fold({ logs: { [W1]: unknown } }))).toEqual(AWAKE)
})

test("Lee's snooze and wake of a session are never told to Claude by its time: they leave it as recently updated as it was", () => {
  const plain = foldAt(NOW, [REVIEW, SHIP])

  expect(asleepThen([]).updatedAt).toBe(plain.updatedAt)
  expect(asleepThen([[T0 + 2 * MIN, wakeSession()]]).updatedAt).toBe(plain.updatedAt)
})

/** A time in local time, as the pane words it. */
const local = (year: number, month: number, day: number, hour: number, minute = 0) =>
  new Date(year, month - 1, day, hour, minute).getTime()

test("the pane counts calendar days, never hours, across Europe/London's changes of the clocks in 2026, wherever the Mac is", () => {
  const words = (until: Parameters<typeof local>, now: Parameters<typeof local>) =>
    inZone('Europe/London', () => wakeWords(local(...until), local(...now)))

  expect(words([2026, 10, 26, 9], [2026, 10, 25, 0, 30]), 'going back, a day of 25 hours is one').toBe(
    'tomorrow 09:00',
  )
  expect(words([2026, 3, 30, 9], [2026, 3, 28, 12]), 'going forward, a day of 23 hours is one').toBe(
    'Mon 09:00',
  )
})

/** Friday 23 October 2026, 14:00, local time. */
const FRIDAY = local(2026, 10, 23, 14)

test("the pane words a snooze's time at its now: today's time alone, tomorrow, a weekday within the week, else its date", () => {
  for (const [until, words] of [
    [local(2026, 10, 23, 15, 42), '15:42'],
    [local(2026, 10, 23, 9, 5), '09:05'],
    [local(2026, 10, 24, 9), 'tomorrow 09:00'],
    [local(2026, 10, 26, 9), 'Mon 09:00'],
    [local(2026, 10, 29, 9), 'Thu 09:00'],
    [local(2026, 10, 30, 9), '30 Oct 09:00'],
    [local(2026, 11, 3, 9), '3 Nov 09:00'],
  ] as const) {
    expect(wakeWords(until, FRIDAY), words).toBe(words)
  }

  expect(wakeWords(local(2026, 10, 24, 1, 30), local(2026, 10, 23, 23, 30))).toBe('tomorrow 01:30')
})

test('Claude is told the time whole and local, never relative: its weekday, date and time', () => {
  expect(wholeTime(local(2026, 10, 26, 9))).toBe('Mon 26 Oct 09:00')
  expect(wholeTime(local(2026, 11, 3, 7, 5))).toBe('Tue 3 Nov 07:05')
})
