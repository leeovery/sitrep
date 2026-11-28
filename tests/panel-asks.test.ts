import { expect, test } from './kit'
import type { Size } from '../cli/panel/cells'
import { draw, text } from '../cli/panel/draw'
import type { Key, Press } from '../cli/panel/keys'
import { layoutOf } from '../cli/panel/layout'
import { snoozeTimes } from '../cli/panel/menu'
import { BEAT_MS, opening, step, type PanelEvent, type PanelState, type Write } from '../cli/panel/state'
import { askKey, SEND_MS, viewOf } from '../cli/panel/view'
import { wordsOf } from '../cli/panel/writes'
import { SNOOZE_DEFAULTS, snoozeSettingsOf, type Ask, type Feed, type Row, type RowKind } from '../core'
import { boardAsk, boardRow, feedOfRows, MIN, snoozedRow, T0 } from './data'
import { inZone, LONDON } from './zoned'

/**
 * A row's asks, opened under it: Help desk redesign asking a choice and a
 * words ask beside a permission prompt, Shift schedules asking a yes, Data
 * import at a prompt alone, Release notes at your turn, Mobile app working,
 * and Onboarding flow in Snoozed.
 */
const NOW = T0 + 60 * MIN

const SIZE: Size = { width: 39, height: 30 }

const [ASKING, YES, PROMPT, TURN, WORKING, ASLEEP] = ['sr-nw0001', 'sr-co0002', 'sr-lw0003', 'sr-ts0004', 'sr-wg0005', 'sr-fa0006'] as const

const THREAD = boardAsk('k1', 'Thread replies, or keep them flat?', { wants: 'choice', options: ['Flat', 'Threaded'], recommended: 'Threaded' }, NOW - 4 * MIN)

const OFFICE = boardAsk('k2', 'Which office moves first?', { wants: 'words' }, NOW - 12 * MIN)

const ROTA = boardAsk('k1', 'Approve the rota', { wants: 'yes', yes: 'Approve' }, NOW - 26 * MIN)

/** A row's line: an ask's naming its id and timed as it was asked, a window's stop timed at `since`. */
const lineOf = (session: string, is: RowKind, index: number, ask?: Ask, since = NOW - 30 * MIN): Row['lines'][number] => ({
  key: `${is}:${session}:${ask?.id ?? index}`,
  is,
  ...(ask === undefined ? {} : { ask: ask.id }),
  first: { lead: ask?.title ?? 'Allow Bash' },
  since: ask?.openedAt ?? since,
})

/** Help desk redesign's row of these asks, the newest first, and its window's permission prompt. */
const askingRow = (asks: readonly Ask[]): Row => ({
  ...boardRow(ASKING, 'ask', { name: 'Help desk redesign', since: asks[0]?.openedAt ?? NOW }),
  lines: [...asks.map((ask, at) => lineOf(ASKING, 'ask', at, ask)), lineOf(ASKING, 'permission', asks.length)],
})

const OTHERS: Row[] = [
  { ...boardRow(YES, 'ask', { name: 'Shift schedules', since: ROTA.openedAt }), lines: [lineOf(YES, 'ask', 0, ROTA)] },
  boardRow(PROMPT, 'permission', { name: 'Data import', since: NOW - 30 * MIN }),
  boardRow(TURN, 'yourTurn', { name: 'Release notes', since: NOW - 31 * MIN }),
  boardRow(WORKING, 'working', { name: 'Mobile app', since: NOW - 6 * MIN }),
]

/** The board with Help desk redesign asking these, or its row as given, and every other row. */
const board = (asks: readonly Ask[] = [THREAD, OFFICE], row: Row | undefined = askingRow(asks)): Feed =>
  feedOfRows(
    [...(row === undefined ? [] : [row]), ...OTHERS],
    [snoozedRow(ASLEEP, ['ask'], { name: 'Onboarding flow' })],
    { [ASKING]: asks, [YES]: [ROTA] },
  )

const press = (kind: Press): Key => ({ kind }) as Key

const [DOWN, UP, LEFT, RIGHT, ENTER, ESC, Z, S, O] = (['down', 'up', 'left', 'right', 'enter', 'esc', 'snooze', 'snoozed', 'open'] as const).map(press) as [
  Key,
  Key,
  Key,
  Key,
  Key,
  Key,
  Key,
  Key,
  Key,
]

const tap = (y: number, x = 5): Key => ({ kind: 'tap', x, y })

const read = (feed: Feed = board(), size: Size = SIZE): PanelState => step(opening(size, NOW), { board: feed, news: [], now: NOW }).state

const stepped = (state: PanelState, ...events: PanelEvent[]) => events.reduce<PanelState>((sofar, event) => step(sofar, event).state, state)

const pressed = (state: PanelState, ...keys: Key[]) => stepped(state, ...keys.map(key => ({ key })))

/** The band on the row at `index` among the open rows, from none. */
const onRow = (state: PanelState, index: number) => pressed(state, ...Array.from({ length: index + 1 }, () => DOWN))

/** The board read, the band on Help desk redesign, and its asks open. */
const open = (feed: Feed = board(), size: Size = SIZE) => pressed(onRow(read(feed, size), 0), ENTER)

const boarded = (state: PanelState, feed: Feed) => stepped(state, { board: feed, news: [], now: NOW })

const viewIn = (state: PanelState) => viewOf(state.feed, state, state.now, state.notHere)

const layoutIn = (state: PanelState) => layoutOf(viewIn(state), state.size)

/** The frame's glyphs, a string a row, as the state draws it without colour. */
const frameOf = (state: PanelState) => text(draw(viewIn(state), state.size, { level: 'none' })).split('\n').slice(0, -1)

/** Where the band is, and the asks open, if any. */
const shown = (state: PanelState) => [state.band, state.asking]

/** The terminal row of the first line of the row `key`. */
const yOf = (state: PanelState, key: string) => layoutIn(state).rows.find(each => each.key === key)?.y ?? -1

/** The terminal row of the frame's first line holding `words`. */
const lineWith = (state: PanelState, words: string) => frameOf(state).findIndex(line => line.includes(words))

test("⏎ on a row with asks the view answers opens them under it, at the first, the band staying on the row; ⏎ again closes them", () => {
  const opened = open()

  expect([opened.band, opened.asking, opened.expanded]).toEqual([ASKING, { row: ASKING, ask: 'k1' }, undefined])
  expect(pressed(opened, ENTER).asking).toBeUndefined()
  expect(pressed(opened, ENTER).band).toBe(ASKING)
})

test("a tap on the band's row opens its asks as ⏎ does; a tap on another row puts the band there and opens nothing", () => {
  const banded = onRow(read(), 0)

  expect(pressed(banded, tap(yOf(banded, ASKING))).asking).toEqual({ row: ASKING, ask: 'k1' })
  expect(shown(pressed(banded, tap(yOf(banded, YES))))).toEqual([YES, undefined])
})

test('⏎ on a row with no asks the view answers expands it, as before: a prompt alone, a row at your turn, a working row; a row of asks and a prompt opens only its asks', () => {
  for (const index of [2, 3, 4]) {
    const state = pressed(onRow(read(), index), ENTER)

    expect([state.expanded, state.asking], String(index)).toEqual([state.band, undefined])
  }

  expect(frameOf(open()).slice(3, 7)).toEqual(['   Northwind', '   Thread replies, or keep them flat?', '   Asked 4m ago                   ━━ ━', '   1 Threaded · Recommended'])
})

test('⏎ on an expanded row that has come to hold asks opens them, folding it', () => {
  const expanded = pressed(onRow(read(board([], askingRow([]))), 0), ENTER)
  const asked = boarded(expanded, board())

  expect(asked.expanded).toBe(ASKING)
  expect([pressed(asked, ENTER).asking, pressed(asked, ENTER).expanded]).toEqual([{ row: ASKING, ask: 'k1' }, undefined])
})

test('→ shows the ask after, ← the one before, at once, in the row\'s order, newest first; nothing wraps', () => {
  const opened = open()

  expect(pressed(opened, RIGHT).asking?.ask).toBe('k2')
  expect(pressed(opened, RIGHT, RIGHT).asking?.ask).toBe('k2')
  expect(pressed(opened, RIGHT, LEFT).asking?.ask).toBe('k1')
  expect(pressed(opened, LEFT).asking?.ask).toBe('k1')
  expect(frameOf(pressed(opened, RIGHT))[5]).toBe('   Asked 12m ago                  ━ ━━')
})

test('a tap on a page dot shows its ask, each dot taking its own cells and the space before it', () => {
  const opened = open()
  const y = lineWith(opened, 'Asked')
  const line = frameOf(opened)[y] ?? ''
  const first = line.indexOf('━')
  const second = line.lastIndexOf('━')

  expect(pressed(opened, tap(y, second)).asking?.ask).toBe('k2')
  expect(pressed(opened, tap(y, second - 1)).asking?.ask).toBe('k2')
  expect(pressed(opened, tap(y, second), tap(y, first)).asking?.ask).toBe('k1')
  expect(pressed(opened, tap(y, first - 1)).asking, 'left of the dots, on the ask: nothing').toEqual({ row: ASKING, ask: 'k1' })
})

test('esc closes the asks, the band kept; ↑ and ↓ close them and move the band, a row a press; at the first row ↑ closes them alone', () => {
  const opened = open()

  expect(shown(pressed(opened, ESC))).toEqual([ASKING, undefined])
  expect(shown(pressed(opened, DOWN))).toEqual([YES, undefined])
  expect(shown(pressed(opened, UP))).toEqual([ASKING, undefined])
})

test('a tap anywhere but the ask closes the asks and does nothing more: on the row\'s head, on another row or off the rows; a tap on the ask, off a dot, does nothing yet', () => {
  const opened = open()
  const head = yOf(opened, ASKING)

  expect(shown(pressed(opened, tap(head)))).toEqual([ASKING, undefined])
  expect(shown(pressed(opened, tap(head + 1)))).toEqual([ASKING, undefined])
  expect(shown(pressed(opened, tap(yOf(opened, YES))))).toEqual([ASKING, undefined])
  expect(shown(pressed(opened, tap(SIZE.height - 3)))).toEqual([ASKING, undefined])
  expect(pressed(opened, tap(lineWith(opened, 'Thread replies'))).asking).toEqual({ row: ASKING, ask: 'k1' })
  expect(pressed(opened, tap(lineWith(opened, 'Threaded'))).asking).toEqual({ row: ASKING, ask: 'k1' })
})

test("with the asks open, s does nothing, and z and the digits reach none of the row's own keys: no row menu, no snooze of the session; o asks to open the session", () => {
  const opened = open()

  expect(pressed(opened, S)).toEqual(opened)
  expect(step(opened, { key: Z }).write).toBeUndefined()
  expect(step(opened, { key: Z }).state.menu).not.toHaveProperty('asks')
  expect(step(opened, { key: { kind: 'digit', n: 1 } }).write).toBeUndefined()
  expect(step(opened, { key: O })).toEqual({ state: opened, open: ASKING })
})

test("the key line names the asks' keys while they are open: the digits of the answers, `1` for a yes and none for a words ask, `←→` where the row has more than one, and `esc close`", () => {
  const keyLine = (state: PanelState) => frameOf(state).at(-1)

  expect(keyLine(onRow(read(), 0))).toBe(' ↑↓ move  ⏎ asks  o open  q quit')
  expect(keyLine(onRow(read(), 2))).toBe(' ↑↓ move  ⏎ expand  o open  q quit')
  expect(keyLine(open())).toBe(' 1–2 answer  ←→ ask  esc close')
  expect(keyLine(pressed(open(), RIGHT))).toBe(' ←→ ask  esc close')
  expect(keyLine(pressed(onRow(read(), 1), ENTER))).toBe(' 1 answer  esc close')
})

test('an ask that leaves the board passes the asks to the next still on it, else to the one before; with none left they close', () => {
  const third = boardAsk('k3', 'Which week first?', { wants: 'words' }, NOW - 20 * MIN)
  const three = open(board([THREAD, OFFICE, third]))

  expect(boarded(three, board([OFFICE, third])).asking?.ask).toBe('k2')
  expect(boarded(three, board([third])).asking?.ask).toBe('k3')
  expect(boarded(pressed(three, RIGHT, RIGHT), board([THREAD, OFFICE])).asking?.ask).toBe('k2')
  expect(boarded(pressed(three, RIGHT), board([THREAD])).asking?.ask).toBe('k1')
  expect(shown(boarded(three, board([])))).toEqual([ASKING, undefined])
})

test('an ask new to the board leaves the one shown in its place; an ask edited while shown is drawn as it now reads', () => {
  const newer = boardAsk('k3', 'Ship it?', { wants: 'yes', yes: 'Ship' }, NOW - MIN)
  const edited = { ...THREAD, title: 'Thread the replies?' }

  expect(boarded(open(), board([newer, THREAD, OFFICE])).asking?.ask).toBe('k1')
  expect(frameOf(boarded(open(), board([edited, OFFICE])))[4]).toBe('   Thread the replies?')
})

test("the row leaving Needs you closes its asks: its asks gone to a prompt alone, the session working, snoozed or gone, the band passed on", () => {
  const working = boardRow(ASKING, 'working', { name: 'Help desk redesign' })
  const asleep = feedOfRows(OTHERS, [snoozedRow(ASKING, ['ask'], { name: 'Help desk redesign' })], { [ASKING]: [THREAD] })

  expect(shown(boarded(open(), board([])))).toEqual([ASKING, undefined])
  expect(shown(boarded(open(), board([THREAD], working)))).toEqual([ASKING, undefined])
  expect(shown(boarded(open(), asleep))).toEqual([YES, undefined])
  expect(shown(boarded(open(), feedOfRows(OTHERS, [], { [YES]: [ROTA] })))).toEqual([YES, undefined])
})

test('the asks are kept whole in sight with their row as they open and as they page, the view scrolled the least that shows them', () => {
  const prompts = Array.from({ length: 6 }, (_, at) => boardRow(`sr-lw00${10 + at}`, 'permission', { name: `Import ${at + 1}`, since: NOW - (40 + at) * MIN }))
  const feed = feedOfRows([...prompts, askingRow([THREAD, OFFICE]), ...OTHERS], [], { [ASKING]: [THREAD, OFFICE] })
  const opened = pressed(onRow(read(feed, { width: 39, height: 12 }), 6), ENTER)
  const heightOf = (state: PanelState) => layoutIn(state).rows.find(each => each.key === ASKING)?.height

  expect([heightOf(opened), heightOf({ ...opened, top: opened.top - 1 })]).toEqual([7, undefined])
  expect(heightOf(pressed(opened, RIGHT))).toBe(5)
  expect(frameOf(opened)[yOf(opened, ASKING)]).toBe(' ● Help desk redesign 3              ▿')
})

// ---------------------------------------------------------------- answering

const [X, U, Q] = (['ignore', 'undo', 'quit'] as const).map(press) as [Key, Key, Key]

const digit = (n: number): Key => ({ kind: 'digit', n })

/** The keys pressed `ms` after NOW, each a step of its own. */
const pressedAt = (state: PanelState, ms: number, ...keys: Key[]) => stepped(state, ...keys.map(key => ({ key, at: NOW + ms })))

/** The clock `ms` after NOW, as the panel's ticks step it: the state, and the line it asks to write. */
const tickedAt = (state: PanelState, ms: number) => step(state, { tick: NOW + ms })

/** Help desk redesign's second answer, Flat, held at NOW. */
const holdingFlat = (feed: Feed = board()) => pressed(open(feed), digit(2))

/** Flat, as `sitrep answer` takes it, with what its ask wanted as shown. */
const FLAT: Write = { command: 'answer', session: ASKING, ask: 'k1', wants: 'choice', answer: 'Flat' }

/** A yes of Help desk redesign's, asked after its choice. */
const SHIP = boardAsk('k3', 'Ship it?', { wants: 'yes', yes: 'Ship' }, NOW - 8 * MIN)

/** The frame's line holding `words`. */
const lineHolding = (state: PanelState, words: string) => frameOf(state)[lineWith(state, words)] ?? ''

/** A tap on the frame's first line holding `words`, at the column they start at. */
const tapOn = (state: PanelState, words: string) => tap(lineWith(state, words), lineHolding(state, words).indexOf(words))

const inLondon = (body: () => void) => () => inZone(LONDON, body)

test("a digit holds the answer of its number, Claude's pick first, the band and the asks staying: its line ink on white with its check, the foot's place `Sending Flat  ◔  u undo`, the key line `u undo  esc close`", () => {
  const held = holdingFlat()

  expect(held.sending).toEqual({ row: ASKING, session: ASKING, ask: 'k1', wants: 'choice', answer: { index: 1, words: 'Flat', sends: 'Flat' }, at: NOW })
  expect(shown(held)).toEqual([ASKING, { row: ASKING, ask: 'k1' }])
  expect(frameOf(held).slice(lineWith(held, '1 Threaded'), lineWith(held, 'Sending') + 1)).toEqual([
    '   1 Threaded · Recommended',
    '   2 Flat                            ✓',
    '   Sending Flat  ◔  u undo',
  ])
  expect(frameOf(held).at(-1)).toBe(' u undo  esc close')
  expect(pressed(open(), digit(1)).sending?.answer).toEqual({ index: 0, words: 'Threaded', sends: 'Threaded' })
})

test('a tap on an answer holds it as its digit does, on any line of it', () => {
  const long = boardAsk('k1', 'Which layout?', { wants: 'choice', options: ['Flat, with a quote of the one it answers', 'Threaded'] }, NOW - 4 * MIN)
  const opened = open(board([long, OFFICE]))
  const first = lineWith(opened, 'Flat, with')

  expect(frameOf(opened).slice(first, first + 2)).toEqual(['   1 Flat, with a quote of the one it', '     answers'])
  expect(pressed(opened, tap(first + 1)).sending?.answer?.index).toBe(0)
  expect(pressed(opened, tap(first, 36)).sending?.answer?.index).toBe(0)
  expect(pressed(opened, tapOn(opened, 'Threaded')).sending?.answer).toEqual({ index: 1, words: 'Threaded', sends: 'Threaded' })
})

test("an answer held keeps its lines: its first, where its words would run under the check, cut to leave the check its room", () => {
  const long = boardAsk('k1', 'Which layout?', { wants: 'choice', options: ['Flat, with a quote of the one it answers', 'Threaded'] }, NOW - 4 * MIN)
  const held = pressed(open(board([long, OFFICE])), digit(1))
  const first = lineWith(held, '✓')

  expect(frameOf(held).slice(first, first + 2)).toEqual(['   1 Flat, with a quote of the one…  ✓', '     answers'])
})

test("x holds the ask's ignore the same way: no answer held, the foot's place `Ignoring  ◔  u undo`", () => {
  const ignoring = pressed(open(), X)

  expect(ignoring.sending).toEqual({ row: ASKING, session: ASKING, ask: 'k1', wants: 'choice', at: NOW })
  expect(lineHolding(ignoring, 'Ignoring')).toBe('   Ignoring  ◔  u undo')
  expect(frameOf(ignoring).some(line => line.includes('✓'))).toBe(false)
  expect(pressed(pressed(open(), RIGHT), X).sending).toMatchObject({ ask: 'k2', wants: 'words' })
})

test('a digit past the answers does nothing, nor any on a words ask; short of rows, a digit past the answers drawn does nothing, one drawn holds', () => {
  const said = 'Something else waits on you now, in another session of this project, and in one more beside it.'
  const short = stepped(open(board(), { width: 39, height: 8 }), { written: said })

  expect(pressed(open(), digit(3)).sending).toBeUndefined()
  expect(pressed(pressed(open(), RIGHT), digit(1)).sending).toBeUndefined()
  expect([lineWith(short, '1 Threaded') >= 0, lineWith(short, '2 Flat')]).toEqual([true, -1])
  expect(pressed(short, digit(2)).sending).toBeUndefined()
  expect(pressed(short, digit(1)).sending?.answer?.index).toBe(0)
})

test('u, or a tap on undo, takes the answer back within its two seconds, nothing going when they pass, and the foot back; a tap on the sending line off undo does nothing', () => {
  const held = holdingFlat()
  const undone = pressedAt(held, 1_500, U)

  for (const back of [undone, pressedAt(held, 1_500, tapOn(held, 'undo')), pressedAt(held, 1_500, tapOn(held, 'u undo'))]) {
    expect(back.sending).toBeUndefined()
    expect(tickedAt(back, SEND_MS).write).toBeUndefined()
    expect(lineHolding(back, 'Ignore')).toBe('   x Ignore  z Snooze  o Open')
    expect(frameOf(back).at(-1)).toBe(' 1–2 answer  ←→ ask  esc close')
  }

  expect(pressedAt(held, 1_500, tapOn(held, 'Sending')).sending).toEqual(held.sending)
  expect(pressed(held, ESC, U).sending, 'u takes it back with the asks closed too').toBeUndefined()
})

test('while an answer is held, digits and x do nothing, on any ask; every other key acts as ever, and the answer still goes: esc closes the asks, ↓ moves the band, → pages', () => {
  const held = holdingFlat()

  expect(pressed(held, digit(1)).sending).toEqual(held.sending)
  expect(pressed(held, X).sending).toEqual(held.sending)
  expect(pressed(held, RIGHT, X).sending).toEqual(held.sending)
  expect(shown(pressed(held, ESC))).toEqual([ASKING, undefined])
  expect(shown(pressed(held, DOWN))).toEqual([YES, undefined])
  expect(pressed(held, RIGHT).asking?.ask).toBe('k2')
  expect(lineHolding(pressed(held, RIGHT), 'Ignore'), "another ask's foot is its own").toBe('   x Ignore  z Snooze  o Open')
  expect(frameOf(pressed(held, RIGHT)).at(-1)).toBe(' u undo  esc close')

  for (const keys of [[ESC], [DOWN], [RIGHT], [S], [O]]) {
    expect(tickedAt(pressed(held, ...keys), SEND_MS).write, keys[0]?.kind).toEqual(FLAT)
  }
})

test("the ring fills a quarter each half second of the two, and at two seconds the answer goes as `sitrep answer` takes it, with what its ask wanted as shown", () => {
  const held = holdingFlat()
  const sendingAt = (ms: number) => lineHolding(tickedAt(held, ms).state, 'Sending')

  expect([0, 499, 500, 1_000, 1_500, 1_999].map(sendingAt)).toEqual(
    ['◔', '◔', '◑', '◕', '●', '●'].map(ring => `   Sending Flat  ${ring}  u undo`),
  )
  expect(tickedAt(held, SEND_MS - 1).write).toBeUndefined()
  expect(tickedAt(held, SEND_MS).write).toEqual(FLAT)
  expect(tickedAt(tickedAt(held, SEND_MS).state, SEND_MS + 500).write, 'once').toBeUndefined()
})

test('what goes says what its ask wanted as shown: a yes its yes, a choice its option, and x the ignore of any, a words ask among them', () => {
  const yes = pressed(onRow(read(), 1), ENTER, digit(1))

  expect(tickedAt(yes, SEND_MS).write).toEqual({ command: 'answer', session: YES, ask: 'k1', wants: 'yes', answer: 'Approve' })
  expect(tickedAt(pressed(open(), RIGHT, X), SEND_MS).write).toEqual({ command: 'ignore', session: ASKING, ask: 'k2', wants: 'words' })
  expect(tickedAt(pressed(open(), X), SEND_MS).write).toEqual({ command: 'ignore', session: ASKING, ask: 'k1', wants: 'choice' })
})

test("each write runs its command on the words the app gives it: an answer and its ask after `--`, so its words arrive whole; one ask's snooze by `--ask`", () => {
  expect(wordsOf({ ...FLAT, answer: '--force' })).toEqual(['--session', ASKING, '--wants', 'choice', '--', 'k1', '--force'])
  expect(wordsOf({ command: 'ignore', session: ASKING, ask: 'k2', wants: 'words' })).toEqual(['--session', ASKING, '--wants', 'words', '--ignore', '--', 'k2'])
  expect(wordsOf({ command: 'snoozeAsk', session: ASKING, ask: 'k1', until: NOW })).toEqual(['--ask', 'k1', '--until', String(NOW), '--session', ASKING])
})

test("once it goes, its ask leaves the asks at once, the asks stepping to the session's next; after its last, they close, the row then expanding as any other", () => {
  const gone = tickedAt(holdingFlat(), SEND_MS).state
  const last = tickedAt(pressedAt(gone, SEND_MS + BEAT_MS, X), 2 * SEND_MS + BEAT_MS)

  expect(gone.asking).toEqual({ row: ASKING, ask: 'k2' })
  expect(frameOf(gone)[lineWith(gone, 'Asked')]).toBe('   Asked 12m ago')
  expect(last.write).toEqual({ command: 'ignore', session: ASKING, ask: 'k2', wants: 'words' })
  expect(shown(last.state)).toEqual([ASKING, undefined])
  expect(frameOf(last.state).at(-1)).toBe(' ↑↓ move  ⏎ expand  o open  q quit')
  expect(pressed(last.state, ENTER).expanded).toBe(ASKING)
})

test("a send stepping on starts the beat: a digit, x or a tap on the ask within 300ms of it does nothing; a page dot shows its ask at once", () => {
  const gone = tickedAt(holdingFlat(board([THREAD, SHIP, OFFICE])), SEND_MS).state
  const early = SEND_MS + BEAT_MS - 1
  const dots = lineHolding(gone, 'Asked')

  expect(gone.asking?.ask).toBe('k3')

  for (const key of [digit(1), X, tapOn(gone, '1 Ship'), tapOn(gone, 'Ignore')]) {
    expect(pressedAt(gone, early, key).sending, key.kind).toBeUndefined()
  }

  expect(pressedAt(gone, SEND_MS + BEAT_MS, digit(1)).sending?.answer?.words).toBe('Ship')
  expect(pressedAt(gone, SEND_MS + BEAT_MS, tapOn(gone, '1 Ship')).sending?.answer?.words).toBe('Ship')
  expect(pressedAt(gone, early, tap(lineWith(gone, 'Asked'), dots.lastIndexOf('━'))).asking?.ask).toBe('k2')
})

test("the keys' own paging starts no beat: a digit pressed at once after → lands", () => {
  const paged = pressed(open(board([THREAD, SHIP])), RIGHT)

  expect(pressedAt(paged, 0, digit(1)).sending?.answer?.words).toBe('Ship')
  expect(pressedAt(pressed(paged, LEFT), 0, digit(1)).sending?.answer?.words).toBe('Threaded')
})

test('the board changing the ask shown starts the beat, an ask leaving or an edit; a tap on undo waits on it too, u not; a board that leaves the ask shown as it reads starts none', () => {
  const opened = open(board([THREAD, SHIP]))
  const at = (feed: Feed) => stepped(opened, { board: feed, news: [], now: NOW + 1_000 })
  const edited = at(board([{ ...THREAD, title: 'Thread the replies?' }, SHIP]))
  const left = at(board([SHIP]))
  const newer = boardAsk('k4', 'Tag it?', { wants: 'yes', yes: 'Tag' }, NOW - MIN)

  expect(pressedAt(edited, 1_000 + BEAT_MS - 1, digit(1)).sending).toBeUndefined()
  expect(pressedAt(edited, 1_000 + BEAT_MS, digit(1)).sending?.answer?.words).toBe('Threaded')
  expect([left.asking?.ask, pressedAt(left, 1_200, X).sending]).toEqual(['k3', undefined])
  expect(pressedAt(at(board([THREAD, SHIP])), 1_000, digit(1)).sending).toBeDefined()
  expect(pressedAt(at(board([newer, THREAD, SHIP])), 1_000, digit(1)).sending, 'an ask new beside it').toBeDefined()

  const held = holdingFlat(board([THREAD, SHIP]))
  const reworded = stepped(held, { board: board([{ ...THREAD, title: 'Thread the replies?' }, SHIP]), news: [], now: NOW + 1_000 })

  expect(pressedAt(reworded, 1_100, tapOn(reworded, 'undo')).sending).toEqual(held.sending)
  expect(pressedAt(reworded, 1_100, U).sending).toBeUndefined()
})

test('the board changing while an answer is held still sends it, the command to refuse what it must: its ask leaving the board, edited, or its row the band', () => {
  const held = holdingFlat()
  const at = (feed: Feed) => stepped(held, { board: feed, news: [], now: NOW + 1_000 })
  const left = at(board([OFFICE]))
  const passed = at(feedOfRows(OTHERS, [], { [YES]: [ROTA] }))

  expect(left.asking?.ask).toBe('k2')
  expect(shown(passed)).toEqual([YES, undefined])

  for (const changed of [left, passed, at(board([{ ...THREAD, wants: 'words' }, OFFICE]))]) {
    expect(tickedAt(changed, SEND_MS).write).toEqual(FLAT)
  }
})

test("a refusal says the command's words in the answer line and brings the ask back to its row's asks; a write done says nothing", () => {
  const { state: gone, write } = tickedAt(holdingFlat(), SEND_MS)
  const words = 'k1 now wants words, not a choice: look at it again.'
  const refused = stepped(gone, { written: words, write })

  expect(gone.sent).toEqual(new Set([askKey(ASKING, 'k1')]))
  expect([refused.answer, refused.sent]).toEqual([words, undefined])
  expect(viewIn(refused).sections[0]?.rows[0]?.answerable?.map(ask => ask.id)).toEqual(['k1', 'k2'])
  expect(frameOf(refused).slice(-3)).toEqual([' ! k1 now wants words, not a choice:', '   look at it again.', ' ←→ ask  esc close'])
  expect(stepped(gone, { written: undefined, write })).toEqual(gone)
})

test('the asks gone are left out until the board no longer lists them', () => {
  const gone = tickedAt(holdingFlat(), SEND_MS).state

  expect(boarded(gone, board()).sent).toEqual(new Set([askKey(ASKING, 'k1')]))
  expect(boarded(gone, board([OFFICE])).sent).toBeUndefined()
})

test(
  "z on the asks opens the ask shown's snooze menu in the foot's place: Snooze's times, and no Until it moves; a choice asks to snooze that ask alone, back to the ask; esc or z closes it, writing nothing",
  inLondon(() => {
    const menu = pressed(open(), Z)
    const times = snoozeTimes(NOW, SNOOZE_DEFAULTS)
    const until = (at: number) => times[at]?.until ?? -1

    expect(times.length).toBeGreaterThan(1)
    expect(menu.menu).toEqual({ row: ASKING, session: ASKING, ask: 'k1', options: times, at: 0, top: 0 })
    expect(frameOf(menu).slice(lineWith(menu, '2 Flat') + 1, lineWith(menu, '2 Flat') + 2)).toEqual([`   1 ${times[0]?.title}`.padEnd(38 - (times[0]?.time.length ?? 0)) + times[0]?.time])
    expect(frameOf(menu).some(line => line.includes('x Ignore'))).toBe(false)
    expect(frameOf(menu).at(-1)).toBe(' ↑↓ pick  ⏎ snooze  esc cancel')
    expect(step(menu, { key: ENTER })).toEqual({ state: { ...menu, menu: undefined, top: menu.top }, write: { command: 'snoozeAsk', session: ASKING, ask: 'k1', until: until(0) } })
    expect(step(pressed(menu, DOWN), { key: ENTER }).write).toEqual({ command: 'snoozeAsk', session: ASKING, ask: 'k1', until: until(1) })
    expect(step(menu, { key: digit(2) }).write).toEqual({ command: 'snoozeAsk', session: ASKING, ask: 'k1', until: until(1) })

    for (const key of [ESC, Z]) {
      const closed = step(menu, { key })

      expect([closed.write, closed.state.menu, closed.state.asking], key.kind).toEqual([undefined, undefined, { row: ASKING, ask: 'k1' }])
    }
  }),
)

test(
  "z on the asks does nothing on the ask sending, whose foot is the sending line, nor where Snooze offers no time; on another ask paged to meanwhile, it opens that ask's menu",
  inLondon(() => {
    const allOff = snoozeSettingsOf('{"v":1,"hour":{"on":false},"later":{"on":false},"tonight":{"on":false},"tomorrow":{"on":false},"weekend":{"on":false},"week":{"on":false}}')

    expect(pressed(holdingFlat(), Z).menu).toBeUndefined()
    expect(pressed(stepped(open(), { snoozeSettings: allOff }), Z).menu).toBeUndefined()
    expect(pressed(holdingFlat(), RIGHT, Z).menu).toMatchObject({ ask: 'k2' })
  }),
)

test(
  "the ask's snooze menu closes as the ask shown changes: its ask leaving the board, the asks closing as the band moves on",
  inLondon(() => {
    const menu = pressed(open(), Z)

    expect(boarded(menu, board([OFFICE])).menu).toBeUndefined()
    expect(boarded(menu, board([OFFICE])).asking?.ask).toBe('k2')
    expect(boarded(menu, feedOfRows(OTHERS, [], { [YES]: [ROTA] })).menu).toBeUndefined()
    expect(boarded(menu, board()).menu).toEqual(menu.menu)
  }),
)

test("taps on the foot's Ignore, Snooze and Open act as their keys, each on its key or its word; between them, nothing", () => {
  const opened = open()
  const foot = lineHolding(opened, 'x Ignore')

  expect(pressed(opened, tapOn(opened, 'Ignore')).sending).toEqual({ row: ASKING, session: ASKING, ask: 'k1', wants: 'choice', at: NOW })
  expect(pressed(opened, tapOn(opened, 'x Ignore')).sending).toMatchObject({ ask: 'k1' })
  expect(pressed(opened, tapOn(opened, 'Snooze')).menu).toMatchObject({ ask: 'k1' })
  expect(step(opened, { key: tapOn(opened, 'Open') }).open).toBe(ASKING)
  expect(pressed(opened, tap(lineWith(opened, 'x Ignore'), foot.indexOf('Ignore') + 'Ignore'.length + 1))).toEqual(opened)
})

test('q or Ctrl-C while an answer is held sends it at once, its hold cut short; with none held, nothing', () => {
  expect(step(holdingFlat(), { key: Q, at: NOW + 500 }).write).toEqual(FLAT)
  expect(step(pressed(holdingFlat(), ESC, DOWN), { key: Q, at: NOW + 500 }).write).toEqual(FLAT)
  expect(step(open(), { key: Q }).write).toBeUndefined()
})
