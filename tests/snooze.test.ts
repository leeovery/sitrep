/**
 * Lee's snooze of an ask: when it wakes, as the fold reads the lines at a
 * moment, what ends it and what leaves it, where a snoozed ask counts, and
 * Snooze's times as they are worked out and worded.
 */
import { expect, test } from 'claude-code/testing'
import {
  isSnoozed,
  LATER_MS,
  parseEntries,
  serialise,
  snoozeAt,
  snoozedAsks,
  summarise,
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
  choiceAsk,
  CLI,
  delivered,
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
  T0,
  unfinish,
  W1,
  W2,
  wake,
  yesAsk,
  type Line,
} from './support'

const HOUR = 60 * MIN

/** When the session is folded, unless a test says otherwise. */
const NOW = T0 + HOUR

/** When the snooze under test wakes: two hours after NOW. */
const UNTIL = NOW + 2 * HOUR

const REVIEW: Line = [T0, yesAsk('k1', 'Review round 1')]

const SNOOZED: Line = [T0 + MIN, snooze('k1', UNTIL)]

/** Where k1 stands under its snooze, and what the session counts of it. */
const standing = (session: Session) => {
  const ask = session.asks.find(each => each.id === 'k1')

  return {
    snoozedUntil: ask?.snoozedUntil,
    wokeAt: ask?.wokeAt,
    waiting: session.waiting,
    snoozed: snoozedAsks(session).length,
  }
}

const ASLEEP = { snoozedUntil: UNTIL, wokeAt: undefined, waiting: 0, snoozed: 1 }

const AWAKE = { snoozedUntil: undefined, wokeAt: undefined, waiting: 1, snoozed: 0 }

/** The session folded at `now` from the window's lines, with any other files. */
const foldAt = (now: number, lines: Line[], files: Partial<SessionFiles> = {}) =>
  fold({ ...files, logs: { [W1]: file(...lines), ...files.logs } }, now)

test('a snooze holds while its time is to come, the ask waiting on Lee nowhere; at its time it has run out, and the ask carries when it woke', () => {
  const lines = [REVIEW, SNOOZED]

  expect(standing(foldAt(NOW, lines))).toEqual(ASLEEP)
  expect(standing(foldAt(UNTIL - 1, lines))).toEqual(ASLEEP)
  expect(standing(foldAt(UNTIL, lines))).toEqual({ ...AWAKE, wokeAt: UNTIL })
  expect(
    standing(foldAt(UNTIL + 9 * HOUR, lines)),
    'woken at its time, however long after',
  ).toEqual({ ...AWAKE, wokeAt: UNTIL })
})

test('snoozing again moves the time, sooner or later, and snoozes afresh an ask whose snooze ran out', () => {
  expect(
    standing(foldAt(NOW, [REVIEW, SNOOZED, [T0 + 2 * MIN, snooze('k1', UNTIL + HOUR)]])),
  ).toEqual({ ...ASLEEP, snoozedUntil: UNTIL + HOUR })
  expect(standing(foldAt(NOW, [REVIEW, SNOOZED, [T0 + 2 * MIN, snooze('k1', NOW + MIN)]]))).toEqual(
    {
      ...ASLEEP,
      snoozedUntil: NOW + MIN,
    },
  )
  expect(
    standing(
      foldAt(NOW, [
        REVIEW,
        [T0 + MIN, snooze('k1', T0 + 10 * MIN)],
        [T0 + 20 * MIN, snooze('k1', UNTIL)],
      ]),
    ),
  ).toEqual(ASLEEP)
})

test('a wake ends the snooze: the ask waits on Lee again, with no time it woke at, before its time or after', () => {
  const lines = [REVIEW, SNOOZED]
  const woken = { logs: { [CLI]: file([T0 + 2 * MIN, wake('k1')]) } }

  expect(standing(foldAt(NOW, lines, woken))).toEqual(AWAKE)
  expect(standing(foldAt(UNTIL + HOUR, lines, woken))).toEqual(AWAKE)
})

test('a wake on an ask not snoozed does nothing: the ask stands as it would, and a snooze after it holds', () => {
  expect(foldAt(NOW, [REVIEW, [T0 + MIN, wake('k1')]]).asks).toEqual(foldAt(NOW, [REVIEW]).asks)
  expect(
    standing(foldAt(NOW, [REVIEW, [T0 + MIN, wake('k1')], [T0 + 2 * MIN, snooze('k1', UNTIL)]])),
  ).toEqual(ASLEEP)
})

test("what settles the ask ends its snooze: Lee's answer or ignore delivered, closing it, or a comment delivered, leaving it replied", () => {
  for (const [verdict, extra, state] of [
    ['yes', {}, 'closed'],
    ['ignore', {}, 'ignored'],
    ['comment', { note: 'Tighten the copy' }, 'replied'],
  ] as const) {
    for (const now of [NOW, UNTIL]) {
      const session = foldAt(now, [REVIEW, SNOOZED, [T0 + 3 * MIN, delivered('r1')]], {
        inbox: { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k1', verdict, extra)]) },
      })

      expect([session.asks[0]?.state, standing(session)], `${verdict}, folded at ${now}`).toEqual([
        state,
        { snoozedUntil: undefined, wokeAt: undefined, waiting: 0, snoozed: 0 },
      ])
    }
  }
})

test("Claude's resolve ends the snooze: reopened after, the ask waits on Lee afresh", () => {
  const resolved = [REVIEW, SNOOZED, [T0 + 2 * MIN, resolve('k1')]] satisfies Line[]

  expect(standing(foldAt(NOW, resolved))).toEqual({ ...AWAKE, waiting: 0 })
  expect(standing(foldAt(NOW, [...resolved, [T0 + 3 * MIN, reopen('k1')]]))).toEqual(AWAKE)
})

test('a reopen opens the ask afresh, ending its snooze: it waits on Lee since its reopening', () => {
  const session = foldAt(NOW, [REVIEW, SNOOZED, [T0 + 2 * MIN, reopen('k1', 'Asked again')]])

  expect(standing(session)).toEqual(AWAKE)
  expect(session.asks[0]?.openedAt).toBe(T0 + 2 * MIN)
})

test('an edit leaves the snooze standing: the ask sleeps on, as edited', () => {
  const session = foldAt(NOW, [
    REVIEW,
    SNOOZED,
    [T0 + 2 * MIN, { type: 'edit', item: 'k1', changes: { title: 'Review round 2' } }],
  ])

  expect(standing(session)).toEqual(ASLEEP)
  expect(session.asks[0]?.title).toBe('Review round 2')
})

test('a finish leaves the snooze: nothing of a finished session counts, its snoozes among them, and a join before its time finds the ask still snoozed, after it woken', () => {
  const finished = [REVIEW, SNOOZED, [T0 + 2 * MIN, finish('lee')]] satisfies Line[]
  const joined = [...finished, [T0 + 3 * MIN, unfinish()]] satisfies Line[]
  const session = foldAt(NOW, finished)

  expect([standing(session), summarise(session).snoozed]).toEqual([
    { snoozedUntil: UNTIL, wokeAt: undefined, waiting: 0, snoozed: 0 },
    0,
  ])
  expect(standing(foldAt(NOW, joined))).toEqual(ASLEEP)
  expect(standing(foldAt(UNTIL, joined))).toEqual({ ...AWAKE, wokeAt: UNTIL })
})

/** Lee's yes to k1, as a window's send claims it a minute before `now`. */
const sendingYes = (now: number): Sending => ({
  at: now - MIN,
  replies: [{ id: 'r1', item: 'k1', verdict: 'yes' }],
})

/** A window live at `now`, sending what it is given. */
const windowAt = (now: number, sending?: Sending) => ({
  [W2]: beat(W2, { attachedAt: T0, seenAt: now, sending }),
})

test("Lee's reply on its way takes the ask out of Snoozed as out of Needs you, its snooze standing; taken back or void, it is snoozed again while its time is to come, else woken", () => {
  const lines = [REVIEW, SNOOZED]
  const answered = { inbox: { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k1', 'yes')]) } }
  const unfit: Line = [
    T0 + 3 * MIN,
    { type: 'edit', item: 'k1', changes: { wants: 'choice', options: ['Now', 'Later'] } },
  ]
  const onItsWay = { snoozedUntil: UNTIL, wokeAt: undefined, waiting: 0, snoozed: 0 }

  expect(standing(foldAt(NOW, lines, answered)), 'in the inbox').toEqual(onItsWay)
  expect(isSnoozed(foldAt(NOW, lines, answered).asks[0]!)).toBe(false)
  expect(
    standing(foldAt(NOW, lines, { presence: windowAt(NOW, sendingYes(NOW)) })),
    "in a window's message, from its claim",
  ).toEqual(onItsWay)
  expect(standing(foldAt(NOW, lines, { presence: windowAt(NOW) })), 'taken back').toEqual(ASLEEP)
  expect(
    standing(foldAt(NOW, [...lines, unfit], answered)),
    'void, its ask edited under it',
  ).toEqual(ASLEEP)
  expect(
    standing(foldAt(UNTIL, lines, { presence: windowAt(UNTIL) })),
    'taken back after its time',
  ).toEqual({
    ...AWAKE,
    wokeAt: UNTIL,
  })
})

test('a snooze naming anything but an ask waiting as posted is passed over: an ask closed, ignored or replied, one not posted yet, a note, a parked item, an id that is none', () => {
  const session = foldAt(NOW, [
    [T0, snooze('k4', UNTIL)],
    [T0, yesAsk('k1', 'Run the apply', 'Done')],
    [T0, yesAsk('k2', 'Try it on the iPad', 'It works')],
    [T0, choiceAsk('k3', 'Keep it, or drop it?', ['Keep it', 'Drop it'])],
    [T0, note('n1', 'Merged')],
    [T0, park('p1', 'Later')],
    [T0 + MIN, resolve('k1')],
    [T0 + MIN, reply('r1', 'k2', 'comment', { note: 'It fails' })],
    [T0 + MIN, reply('r2', 'k3', 'ignore')],
    [T0 + MIN, delivered('r1', 'r2')],
    [T0 + MIN, yesAsk('k4', 'Tag the release', 'Done')],
    ...['k1', 'k2', 'k3', 'n1', 'p1', 'zzzz'].map((id): Line => [T0 + 2 * MIN, snooze(id, UNTIL)]),
  ])

  expect(session.asks.map(ask => [ask.id, ask.state, ask.snoozedUntil])).toEqual([
    ['k1', 'closed', undefined],
    ['k2', 'replied', undefined],
    ['k3', 'ignored', undefined],
    ['k4', 'waiting', undefined],
  ])
  expect([snoozedAsks(session), session.waiting]).toEqual([[], 1])
})

test("of two writers' lines at one moment the later in the fold's order wins, by writer, the same in every reader", () => {
  const at = T0 + 2 * MIN
  const raced = (logs: Record<string, Body[]>) =>
    standing(
      fold({
        logs: Object.fromEntries(
          Object.entries(logs).map(([writer, bodies]) => [
            writer,
            file(...(writer === W1 ? [REVIEW] : []), ...bodies.map((body): Line => [at, body])),
          ]),
        ),
      }),
    )

  expect(raced({ [W1]: [snooze('k1', UNTIL)], [W2]: [wake('k1')] })).toEqual(AWAKE)
  expect(raced({ [W1]: [wake('k1')], [W2]: [snooze('k1', UNTIL)] })).toEqual(ASLEEP)
  expect(
    raced({ [W1]: [snooze('k1', UNTIL)], [CLI]: [wake('k1')] }),
    "a window's, then the CLI's",
  ).toEqual(AWAKE)
  expect(
    raced({ [W1]: [snooze('k1', UNTIL + HOUR)], [W2]: [snooze('k1', UNTIL)] }),
    'two snoozes',
  ).toEqual(ASLEEP)
})

test('a session waits on Lee for what is not snoozed; every ask waiting as posted, snoozed or on its way, still counts as asked, which keeps the session current', () => {
  const session = foldAt(
    NOW,
    [
      REVIEW,
      [T0, yesAsk('k2', 'Ship it', 'Go')],
      [T0, yesAsk('k3', 'Tag it', 'Done')],
      [T0 + MIN, snooze('k2', UNTIL)],
    ],
    { inbox: { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k3', 'yes')]) } },
  )

  expect(waitingOnLee(session).map(ask => ask.id)).toEqual(['k1'])
  expect(snoozedAsks(session).map(ask => ask.id)).toEqual(['k2'])
  expect(summarise(session)).toMatchObject({ waiting: 1, snoozed: 1, asked: 3 })
})

test("an old reader skips both kinds: lines at the format's version 1, of kinds it does not know, the rest of the file standing and the ask waiting", () => {
  const text = file(
    REVIEW,
    SNOOZED,
    [T0 + 2 * MIN, wake('k1')],
    [T0 + 3 * MIN, note('n1', 'Merged')],
  )
  const unknown = text.replace(/"type":"(snooze|wake)"/g, '"type":"later-kind"')

  expect(serialise({ v: VERSION, at: T0, seq: 9, ...snooze('k3f9', UNTIL) })).toBe(
    `{"v":1,"at":${T0},"seq":9,"type":"snooze","item":"k3f9","until":${UNTIL}}\n`,
  )
  expect(serialise({ v: VERSION, at: T0, seq: 10, ...wake('k3f9') })).toBe(
    `{"v":1,"at":${T0},"seq":10,"type":"wake","item":"k3f9"}\n`,
  )
  expect(parseEntries(unknown).map(entry => entry.type)).toEqual(['ask', 'note'])
  expect(standing(fold({ logs: { [W1]: unknown } }))).toEqual(AWAKE)
})

/** A time in local time, as Snooze works it out. */
const local = (year: number, month: number, day: number, hour: number, minute = 0) =>
  new Date(year, month - 1, day, hour, minute).getTime()

test('Later today is three hours on, on the wall clock', () => {
  const at = local(2026, 10, 26, 14, 20)

  expect(snoozeAt('later', at)).toBe(at + 3 * HOUR)
  expect(LATER_MS).toBe(3 * HOUR)
})

test('Tomorrow is 09:00 the next calendar day: pressed after midnight, it wakes 32 hours on', () => {
  expect(snoozeAt('tomorrow', local(2026, 10, 26, 14, 20))).toBe(local(2026, 10, 27, 9))
  expect(snoozeAt('tomorrow', local(2026, 10, 26, 23, 59))).toBe(local(2026, 10, 27, 9))
  expect(snoozeAt('tomorrow', local(2026, 10, 27, 1))).toBe(local(2026, 10, 28, 9))
  expect(snoozeAt('tomorrow', local(2026, 10, 27, 1)) - local(2026, 10, 27, 1)).toBe(32 * HOUR)
  expect(snoozeAt('tomorrow', local(2026, 10, 31, 12)), 'into the next month').toBe(
    local(2026, 11, 1, 9),
  )
})

test('Next week is 09:00 the Monday after today: from a Monday, a week on; from a Sunday, the next day', () => {
  expect(snoozeAt('week', local(2026, 10, 26, 8)), 'a Monday, before 09:00').toBe(
    local(2026, 11, 2, 9),
  )
  expect(snoozeAt('week', local(2026, 10, 26, 14, 20)), 'a Monday').toBe(local(2026, 11, 2, 9))
  expect(snoozeAt('week', local(2026, 10, 28, 14)), 'a Wednesday').toBe(local(2026, 11, 2, 9))
  expect(snoozeAt('week', local(2026, 10, 31, 22)), 'a Saturday').toBe(local(2026, 11, 2, 9))
  expect(snoozeAt('week', local(2026, 11, 1, 20)), 'a Sunday').toBe(local(2026, 11, 2, 9))
  expect(snoozeAt('week', local(2026, 11, 2, 0, 30)), 'a Monday, after midnight').toBe(
    local(2026, 11, 9, 9),
  )
})

/** Whether the local zone changes its clocks between noon on a day and noon the next. */
const isChangeAfter = (year: number, month: number, day: number) =>
  new Date(year, month - 1, day, 12).getTimezoneOffset() !==
  new Date(year, month - 1, day + 1, 12).getTimezoneOffset()

/**
 * A case that tells the calendar from adding hours only across a change of
 * the clocks, assuming Europe/London's, the Mac's own: the kit can set no
 * time zone, so where the local zone changes none that night it is skipped,
 * and says so, rather than passing for nothing.
 */
const acrossTheChange = (
  name: string,
  night: readonly [year: number, month: number, day: number],
  body: () => void,
) =>
  isChangeAfter(...night)
    ? test(name, body)
    : test(`${name} (skipped: the local zone changes no clock that night)`, () => {})

acrossTheChange(
  "09:00 holds as Europe/London's clocks go back on 25 October 2026: Snooze's times are worked out on the calendar, and the pane counts calendar days, never hours",
  [2026, 10, 24],
  () => {
    const lateNight = local(2026, 10, 25, 0, 30)

    expect(snoozeAt('tomorrow', local(2026, 10, 24, 10))).toBe(local(2026, 10, 25, 9))
    expect(snoozeAt('tomorrow', lateNight), 'pressed after midnight, before the change').toBe(
      local(2026, 10, 26, 9),
    )
    expect(snoozeAt('week', local(2026, 10, 24, 23))).toBe(local(2026, 10, 26, 9))
    expect(snoozeAt('later', lateNight) - lateNight, 'three hours of the wall clock').toBe(3 * HOUR)
    expect(wakeWords(local(2026, 10, 26, 9), lateNight), 'a day of 25 hours is one').toBe(
      'tomorrow 09:00',
    )
  },
)

acrossTheChange(
  "09:00 holds as Europe/London's clocks go forward on 29 March 2026: Snooze's times are worked out on the calendar, and the pane counts calendar days, never hours",
  [2026, 3, 28],
  () => {
    expect(snoozeAt('tomorrow', local(2026, 3, 28, 10))).toBe(local(2026, 3, 29, 9))
    expect(snoozeAt('tomorrow', local(2026, 3, 29, 0, 30)), 'pressed after midnight').toBe(
      local(2026, 3, 30, 9),
    )
    expect(snoozeAt('week', local(2026, 3, 28, 22))).toBe(local(2026, 3, 30, 9))
    expect(
      wakeWords(local(2026, 3, 30, 9), local(2026, 3, 28, 12)),
      'a day of 23 hours is one',
    ).toBe('Mon 09:00')
  },
)

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
