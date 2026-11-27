import { expect, test } from './kit'
import { countdown, NEW_MS, rowKey, viewOf, type PanelRow, type ViewState } from '../cli/panel/view'
import {
  feedOf as boardOf,
  foldSession,
  metaText,
  SNOOZE_DEFAULTS,
  snoozeSettingsOf,
  type Feed,
  type Project,
  type Row,
  type RowKind,
  type RowLine,
  type Session,
  type SessionFiles,
  type SnoozedKind,
  type SnoozedRow,
} from '../core'
import {
  boardRow,
  CLI,
  DAY,
  feedOfRows as feedOf,
  HOUR,
  META,
  MIN,
  snoozedRow,
  T0,
  W1,
  type RowMade,
} from './data'
import { beat, choiceAsk, file, reply, snooze, wordsAsk, yesAsk, type Line } from './lines'
import { inZone, LONDON, wallClock } from './zoned'

const NOW = T0 + DAY

const HELP_DESK = 'sr-nw0001'

const SHIFTS = 'sr-co0002'

/** Help desk redesign's row in Northwind, saying `first`, its newest line 12 minutes old unless told. */
const row = (
  is: RowKind,
  first: RowLine = { lead: 'Review the help desk' },
  made: RowMade & { since?: number; lines?: number } = {},
): Row => boardRow(HELP_DESK, is, { name: 'Help desk redesign', since: NOW - 12 * MIN, first, ...made })

/** Shift schedules' row in Snoozed, in Contoso, of lines of the kinds given, waking at `wakesAt`. */
const snoozed = (kinds: SnoozedKind[], made: RowMade & { wakesAt?: number } = {}): SnoozedRow =>
  snoozedRow(SHIFTS, kinds, {
    name: 'Shift schedules',
    project: 'Contoso',
    first: { lead: 'Approve the rota' },
    ...made,
  })

const STATE: ViewState = { top: 0, isSnoozedOpen: false, board: 'read', arrivals: new Map() }

const NONE: ReadonlySet<string> = new Set()

type Viewed = { state?: ViewState; now?: number; notHere?: ReadonlySet<string> }

/** The rows of a view of these, in its order. */
const rowsOf = (feed: Feed, { state = STATE, now = NOW, notHere = NONE }: Viewed = {}): PanelRow[] =>
  viewOf(feed, state, now, notHere).sections.flatMap(each => each.rows)

/** The one row a view of this one shows. */
const only = (made: Row | SnoozedRow, viewed: Viewed = {}) => {
  const [shown] = rowsOf('section' in made ? feedOf([made]) : feedOf([], [made]), viewed)

  return shown
}

test('a status line joins its lead and what it acts on with a space, a permission prompt with a colon', () => {
  expect(only(row('working', { lead: 'Running', mono: 'npm test' }))?.status).toEqual({
    text: 'Running npm test',
  })
  expect(only(row('onItsWork', { lead: 'Waiting on', subject: '3 agents' }))?.status).toEqual({
    text: 'Waiting on 3 agents',
  })
  expect(only(row('permission', { lead: 'Allow Bash', mono: 'psql -f import.sql' }))?.status).toEqual({
    text: 'Allow Bash: psql -f import.sql',
  })
  expect(only(row('permission', { lead: 'A permission prompt' }))?.status).toEqual({
    text: 'A permission prompt',
  })
})

test("a question's +2 comes apart from its words, as a number", () => {
  expect(only(row('question', { lead: 'Which layout?', more: '+2' }))?.status).toEqual({
    text: 'Which layout?',
    more: 2,
  })
})

test("a row in Snoozed says its first line: an ask put off by its title, a turn put off by what Claude left", () => {
  const ask = snoozed(['ask'], { first: { lead: 'Approve the rota' } })
  const turn = snoozed(['yourTurn'], { first: { lead: 'Rota drafted for review' } })
  const open = { state: { ...STATE, isSnoozedOpen: true } }

  expect([only(ask, open)?.status, only(turn, open)?.status]).toEqual([
    { text: 'Approve the rota' },
    { text: 'Rota drafted for review' },
  ])
})

test('a wake counts down to its time: Wakes in 12m, Wakes now once due, Wakes alone with no time', () => {
  const wake = (until?: number) =>
    only(row('onItsWork', { lead: 'Wakes', ...(until === undefined ? {} : { until }) }))?.status.text

  expect([wake(NOW + 12 * MIN), wake(NOW), wake()]).toEqual(['Wakes in 12m', 'Wakes now', 'Wakes'])
})

test("a countdown reads as the app's: up to the whole minute, then in whole units, now once due", () => {
  const left = [720_000, 690_000, 660_001, 660_000, 30_000, 1, 0, -5_000, 5_400_000, 90_000_000]

  expect(left.map(each => countdown(NOW + each, NOW))).toEqual([
    'in 12m',
    'in 12m',
    'in 12m',
    'in 11m',
    'in 1m',
    'in 1m',
    'now',
    'now',
    'in 1h',
    'in 1d',
  ])
})

test("a row in Needs you or Working reads how long its newest line has stood, in whole units rounded down, as the notch's do", () => {
  const times = [
    row('ask', undefined, { since: NOW - 59_999 }),
    row('yourTurn', undefined, { since: NOW - 12 * MIN - 59_999 }),
    row('working', undefined, { since: NOW - 90 * MIN }),
    row('working', undefined, { since: NOW - 2 * HOUR }),
    row('onItsWork', undefined, { since: NOW - 3 * DAY - 23 * HOUR }),
  ]

  expect(times.map(each => only(each)?.time)).toEqual(['now', '12m', '1h', '2h', '3d'])
  expect(only(row('ask', undefined, { lines: 3, since: NOW - 5 * MIN }))?.time).toBe('5m')
})

test('a row in Snoozed reads when it wakes, as wakeWords says it, or until it moves', () => {
  const local = wallClock(LONDON)
  const now = local(2026, 11, 19, 10)
  const open = { ...STATE, isSnoozedOpen: true }
  const at = (wakesAt?: number) =>
    inZone(LONDON, () => only(snoozed(['ask'], wakesAt === undefined ? {} : { wakesAt }), { state: open, now })?.time)

  expect([at(local(2026, 11, 19, 14)), at(local(2026, 11, 20, 9)), at(local(2026, 11, 21, 9)), at()]).toEqual([
    '14:00',
    'tomorrow 09:00',
    'Sat 09:00',
    'until it moves',
  ])
})

test("each row's mark says what it is: an ask, a permission prompt or a question, Stopped, working or on its own work; in Snoozed, its state's", () => {
  const marks = rowsOf(
    feedOf(
      [row('ask'), row('permission'), row('question'), row('yourTurn'), row('working'), row('onItsWork')],
      [snoozed(['ask', 'yourTurn']), snoozed(['yourTurn'])],
    ),
  ).map(each => [each.mark, each.isSnoozed])

  expect(marks).toEqual([
    ['ask', false],
    ['ask', false],
    ['ask', false],
    ['turn', false],
    ['working', false],
    ['onItsWork', false],
    ['ask', true],
    ['turn', true],
  ])
})

test("a row is away where no window holds its session or this Mac doesn't show it, here otherwise, keeping its mark", () => {
  const notHere = { notHere: new Set([HELP_DESK, SHIFTS]) }

  expect(only(row('ask'))).toMatchObject({ isAway: false, mark: 'ask' })
  expect(only(row('ask', undefined, { isAway: true }))).toMatchObject({ isAway: true, mark: 'ask' })
  expect(only(row('question'), notHere)).toMatchObject({ isAway: true, mark: 'ask' })
  expect(only(row('yourTurn'), notHere)).toMatchObject({ isAway: true, mark: 'turn' })
  expect(only(snoozed(['ask']), notHere)).toMatchObject({ isAway: true, mark: 'ask' })
})

test('a row with more than one line counts them beside its name; one of one line has no count', () => {
  expect(only(row('ask', undefined, { lines: 3 }))).toMatchObject({ name: 'Help desk redesign', count: 3 })
  expect(only(row('ask'))).not.toHaveProperty('count')
  expect(only(snoozed(['ask', 'ask']))?.count).toBe(2)
})

test("a row carries each of its lines' words, its status line first, for the row expanded", () => {
  const asks: Row = {
    ...row('ask'),
    lines: [
      { key: 'ask:a', is: 'ask', ask: 'k1', first: { lead: 'Approve the rota' }, since: NOW },
      { key: 'stop:b', is: 'permission', first: { lead: 'Allow Bash', mono: 'psql -f import.sql' }, since: NOW },
      { key: 'stop:c', is: 'question', first: { lead: 'Which week first?', more: '2' }, since: NOW },
    ],
  }

  expect(only(asks)?.lines).toEqual([
    { text: 'Approve the rota' },
    { text: 'Allow Bash: psql -f import.sql' },
    { text: 'Which week first?', more: 2 },
  ])
  expect(only(row('working'))?.lines).toEqual([{ text: 'Review the help desk' }])
})

test('a row that can be snoozed carries the asks a snooze names, those it shows, none on a turn; a row of stops alone, a working one or one in Snoozed carries none', () => {
  const asking: Row = {
    ...row('ask'),
    lines: [
      { key: 'ask:a', is: 'ask', ask: 'k1', first: { lead: 'Approve the rota' }, since: NOW },
      { key: 'stop:b', is: 'permission', first: { lead: 'Allow Bash' }, since: NOW },
      { key: 'ask:c', is: 'ask', ask: 'k3', first: { lead: 'Ship it' }, since: NOW },
    ],
  }

  expect(only(asking)?.asks).toEqual(['k1', 'k3'])
  expect(only(row('yourTurn'))?.asks).toEqual([])
  expect(only(row('permission'))).not.toHaveProperty('asks')
  expect(only(row('working'))).not.toHaveProperty('asks')
  expect(only(snoozed(['ask']))).not.toHaveProperty('asks')
})

test("a row shows its session's name and its project's", () => {
  expect(only(row('working', undefined, { name: 'Invoice ledger', project: 'Fabrikam' }))).toMatchObject({
    session: HELP_DESK,
    name: 'Invoice ledger',
    project: 'Fabrikam',
  })
})

test("a session's row in Snoozed has a key apart from its row in another section", () => {
  const both = snoozedRow(HELP_DESK, ['ask'], { name: 'Help desk redesign' })
  const keys = rowsOf(feedOf([row('working')], [both])).map(rowKey)

  expect(keys).toEqual([HELP_DESK, `snoozed:${HELP_DESK}`])
})

test('a line new to Needs you makes its row new for two seconds from the first view that showed it', () => {
  const arrived = { ...STATE, arrivals: new Map([[`ask:${HELP_DESK}:1`, NOW]]) }
  const isNew = (now: number) => only(row('ask', undefined, { lines: 2 }), { state: arrived, now })?.isNew

  expect([isNew(NOW), isNew(NOW + NEW_MS - 1), isNew(NOW + NEW_MS)]).toEqual([true, true, false])
  expect(only(row('ask', undefined, { lines: 2 }))?.isNew).toBe(false)
  expect(NEW_MS).toBe(2_000)
})

test("a row in Snoozed is never new, though it shares an ask's key", () => {
  const state = { ...STATE, isSnoozedOpen: true, arrivals: new Map([[`ask:${SHIFTS}:0`, NOW]]) }

  expect(only(snoozed(['ask']), { state })?.isNew).toBe(false)
})

test('text from the board has its control characters dropped and comes on one line', () => {
  const cleaned = only(
    row(
      'permission',
      { lead: 'Allow\u0007 Bash', mono: 'psql\u001b[2J -f\nimport.sql\u009b' },
      { name: 'Help\u001b[31m desk\r\nredesign\u007f', project: '\tNorthwind\u0085' },
    ),
  )

  expect(cleaned).toMatchObject({
    name: 'Help[31m desk redesign',
    project: 'Northwind',
    status: { text: 'Allow Bash: psql[2J -f import.sql' },
  })
})

test("a pick's answer is cleaned as the board's words are, since it carries a session's name", () => {
  const answer = "Help\u001b[2J desk\r\nredesign can't be opened here:\u0007 its terminal has no tmux or zmx."

  expect(viewOf(feedOf([row('ask')]), { ...STATE, answer }, NOW, NONE).answer).toBe(
    "Help[2J desk redesign can't be opened here: its terminal has no tmux or zmx.",
  )
})

test('Snoozed is open as the state says, Needs you and Working always', () => {
  const feed = feedOf([row('ask'), row('working')], [snoozed(['ask'])])
  const opened = (isSnoozedOpen: boolean) =>
    viewOf(feed, { ...STATE, isSnoozedOpen }, NOW, NONE).sections.map(each => [each.kind, each.isOpen])

  expect(opened(false)).toEqual([
    ['needsYou', true],
    ['working', true],
    ['snoozed', false],
  ])
  expect(opened(true).at(-1)).toEqual(['snoozed', true])
})

test("the view carries the state's band, expanded row, scroll and answer, and the sections' counts", () => {
  const state: ViewState = { ...STATE, band: `snoozed:${SHIFTS}`, expanded: `snoozed:${SHIFTS}`, top: 3, answer: 'Opened' }
  const view = viewOf(feedOf([row('ask', undefined, { lines: 2 })]), state, NOW, NONE)

  expect(view).toMatchObject({ band: `snoozed:${SHIFTS}`, expanded: `snoozed:${SHIFTS}`, top: 3, answer: 'Opened', board: 'read' })
  expect(view.sections[0]?.counts).toEqual([{ value: 2, need: 'ask' }])
  expect(viewOf(feedOf([]), STATE, NOW, NONE)).toEqual({ sections: [], top: 0, board: 'read' })
})

test('before any board there are no sections, and a board that could not be read says why', () => {
  const looking: ViewState = { ...STATE, board: 'looking' }

  expect(viewOf(undefined, looking, NOW, NONE)).toEqual({ sections: [], top: 0, board: 'looking' })
  expect(viewOf(undefined, { ...looking, reason: 'No state folder' }, NOW, NONE)).toMatchObject({
    sections: [],
    reason: 'No state folder',
  })
})

test('a stale board says when it was last read, in local 24-hour time; a current one says nothing of it', () => {
  const readAt = wallClock(LONDON)(2026, 11, 19, 12, 4)
  const asOf = (board: ViewState['board']) =>
    inZone(LONDON, () => viewOf(feedOf([row('ask')]), { ...STATE, board, readAt }, readAt + HOUR, NONE).asOf)

  expect([asOf('stale'), asOf('read')]).toEqual(['12:04', undefined])
})

// ---------------------------------------------------------------- the asks the view answers

/** When the sessions below are folded and viewed. */
const ASKED_NOW = T0 + HOUR

const NORTHWIND: Project = { key: 'northwind', name: 'Northwind' }

/** Help desk redesign, folded at ASKED_NOW from the lines its window wrote, the letters in its inbox, and its heartbeats. */
const helpDesk = (lines: Line[], { inbox = {}, presence = {} }: Partial<Pick<SessionFiles, 'inbox' | 'presence'>> = {}): Session => {
  const session = foldSession({ meta: metaText(META), logs: { [W1]: file(...lines) }, inbox, presence }, ASKED_NOW)

  if (session === undefined) {
    throw new Error('the session did not fold')
  }

  return session
}

const boardWith = (session: Session) => boardOf([{ project: NORTHWIND, sessions: [session] }], ASKED_NOW)

/** The asks the view answers on the session's row, as the board folds it. */
const answerableOf = (session: Session) => rowsOf(boardWith(session), { now: ASKED_NOW })[0]?.answerable

/** A window held on the session, stopped on a permission prompt since `since`. */
const prompting = (since: number) => ({
  [W1]: beat(W1, { attachedAt: T0, seenAt: ASKED_NOW, version: '0.2.0', state: { is: 'permission', since, tool: { name: 'Bash', subject: 'ls' } } }),
})

test("a row's asks the view answers are its board asks waiting on you, a yes, a choice or a words ask, in the row's order, newest first, each aged as its line", () => {
  const session = helpDesk([
    [T0, wordsAsk('k1', 'Which office moves first?')],
    [ASKED_NOW - 12 * MIN, yesAsk('k2', 'Approve the rota', 'Approve')],
    [ASKED_NOW - 4 * MIN, choiceAsk('k3', 'Thread replies, or keep them flat?', ['Flat', 'Threaded', 'Flat, with a quote'], 'Threaded')],
  ])

  expect(answerableOf(session)).toEqual([
    { id: 'k3', title: 'Thread replies, or keep them flat?', wants: 'choice', answers: ['Threaded', 'Flat', 'Flat, with a quote'], pick: 'Threaded', age: '4m' },
    { id: 'k2', title: 'Approve the rota', wants: 'yes', answers: ['Approve'], age: '12m' },
    { id: 'k1', title: 'Which office moves first?', wants: 'words', answers: [], age: '1h' },
  ])
})

test('an ask snoozed, and one whose answer is on its way, are not among them; with none left the row has none', () => {
  const asks: Line[] = [
    [T0, yesAsk('k1', 'Ship it')],
    [T0, yesAsk('k2', 'Tag it')],
    [T0, yesAsk('k3', 'Review it')],
    [T0 + MIN, snooze('k2', ASKED_NOW + HOUR)],
  ]
  const answered = { inbox: { [CLI]: file([T0 + 2 * MIN, reply('r1', 'k3', 'yes')]) } }
  const alone = { inbox: { [CLI]: file([T0 + MIN, reply('r1', 'k1', 'yes')]) } }

  expect(answerableOf(helpDesk(asks, answered))?.map(ask => ask.id)).toEqual(['k1'])
  expect(answerableOf(helpDesk([[T0, yesAsk('k1', 'Ship it')], [T0, yesAsk('k2', 'Tag it')]], alone))?.map(ask => ask.id)).toEqual(['k2'])
  expect(answerableOf(helpDesk(asks.slice(0, 1), alone))).toBeUndefined()
})

test("Claude Code's own permission prompts are never among them: a row of a prompt alone has none, and a row of both only its board asks", () => {
  const alone = helpDesk([], { presence: prompting(ASKED_NOW - MIN) })
  const both = helpDesk([[T0, yesAsk('k1', 'Ship it')]], { presence: prompting(ASKED_NOW - MIN) })

  expect(rowsOf(boardWith(alone), { now: ASKED_NOW })[0]).toMatchObject({ mark: 'ask', status: { text: 'Allow Bash: ls' } })
  expect(answerableOf(alone)).toBeUndefined()
  expect(answerableOf(both)?.map(ask => ask.id)).toEqual(['k1'])
})

test('a Stopped or Snoozed row has none, whatever the board holds of its session', () => {
  const stopped = { ...row('yourTurn'), session: META.id }
  const asleep = { ...snoozed(['ask']), session: META.id }
  const feed: Feed = { ...feedOf([stopped], [asleep]), projects: boardWith(helpDesk([[T0, yesAsk('k1', 'Ship it')]])).projects }

  expect(rowsOf(feed, { state: { ...STATE, isSnoozedOpen: true } }).map(each => [each.mark, each.answerable])).toEqual([
    ['turn', undefined],
    ['ask', undefined],
  ])
})

test("a yes with no words of its own answers `yes`; a choice with no options has none; a pick none of its options is no pick", () => {
  const session = helpDesk([
    [T0, { type: 'ask', id: 'k1', wants: 'yes', title: 'Ship it' }],
    [T0 + MIN, choiceAsk('k2', 'Which layout?', [])],
    [T0 + 2 * MIN, choiceAsk('k3', 'Which colour?', ['Red', 'Blue'], 'Green')],
  ])

  expect(answerableOf(session)?.map(({ id, answers, pick }) => ({ id, answers, pick }))).toEqual([
    { id: 'k3', answers: ['Red', 'Blue'], pick: undefined },
    { id: 'k2', answers: [], pick: undefined },
    { id: 'k1', answers: ['yes'], pick: undefined },
  ])
})

test("an ask's title and answers are cleaned of control characters, as the board's words are", () => {
  const session = helpDesk([[T0, choiceAsk('k1', 'Ship\x1b[31m it?', ['Now\x07', 'Later'], 'Now\x07')]])

  expect(answerableOf(session)?.[0]).toMatchObject({ title: 'Ship[31m it?', answers: ['Now', 'Later'], pick: 'Now' })
})

test("the view says the band's asks open, by the ask shown's place, and whether Snooze offers a time; none where the ask is not the row's", () => {
  const feed = boardWith(helpDesk([[T0, yesAsk('k1', 'Ship it')], [T0 + MIN, yesAsk('k2', 'Tag it')]]))
  const allOff = snoozeSettingsOf('{"v":1,"hour":{"on":false},"later":{"on":false},"tonight":{"on":false},"tomorrow":{"on":false},"weekend":{"on":false},"week":{"on":false}}')
  const opened = (ask: string, snoozeSettings = SNOOZE_DEFAULTS) =>
    viewOf(feed, { ...STATE, band: META.id, opened: { row: META.id, ask }, snoozeSettings }, ASKED_NOW, NONE).opened

  expect(opened('k1')).toEqual({ row: META.id, at: 1, offersSnooze: true })
  expect(opened('k2')).toEqual({ row: META.id, at: 0, offersSnooze: true })
  expect(opened('k2', allOff)).toEqual({ row: META.id, at: 0, offersSnooze: false })
  expect(opened('k9')).toBeUndefined()
})
