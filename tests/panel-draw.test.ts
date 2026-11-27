import { expect, test } from './kit'
import { ansi, draw, text } from '../cli/panel/draw'
import { widthOf } from '../cli/panel/cells'
import { layoutOf, topFor } from '../cli/panel/layout'
import { rgbOf, type Paint } from '../cli/panel/paint'
import { rowKey, type PanelRow, type PanelView } from '../cli/panel/view'

/** No colour at all, as with NO_COLOR: the frames below hold glyphs alone. */
const NONE: Paint = { level: 'none' }

/** 24-bit, with the terminal's answers: Nordfox's ink on its background. */
const NORDFOX: Paint = { level: 'truecolor', fg: rgbOf('#CDCECF'), bg: rgbOf('#2E3440') }

const ESC = '\u001b'

const row = (
  session: string,
  mark: PanelRow['mark'],
  name: string,
  project: string,
  status: string,
  time: string,
  more: Partial<PanelRow> = {},
): PanelRow => ({
  session,
  mark,
  isAway: false,
  isSnoozed: false,
  isNew: false,
  name,
  project,
  status: { text: status },
  lines: [more.status ?? { text: status }],
  time,
  ...more,
})

const HELP_DESK = row('sr-nw0001', 'ask', 'Help desk redesign', 'Northwind', '', '4m', {
  count: 2,
  status: { text: 'Thread replies, or keep them flat?', more: 1 },
})
const DATA_IMPORT = row('sr-lw0001', 'ask', 'Data import', 'Litware', 'Allow Bash: psql -f import.sql', '1m', {
  isAway: true,
})
const SHIFTS = row('sr-ct0001', 'turn', 'Shift schedules', 'Contoso', 'Approve the rota', '26m', { asks: [] })
const MOBILE = row('sr-wg0001', 'working', 'Mobile app', 'Woodgrove', 'Running npm test', '6m')
const LEDGER = row('sr-fb0001', 'onItsWork', 'Invoice ledger', 'Fabrikam', 'Waiting on 2 agents', '15m')
const ONBOARDING = row('sr-ts0001', 'ask', 'Onboarding flow', 'Tailspin', 'Pick the onboarding steps', 'tomorrow 09:00', {
  isSnoozed: true,
})

/** A board of every kind of row: Needs you's asks, one away, and a turn; Working's two; Snoozed's one, folded unless `isOpen`. */
const board = (more: Partial<PanelView> & { isOpen?: boolean } = {}): PanelView => {
  const { isOpen = false, ...view } = more

  return {
    sections: [
      {
        kind: 'needsYou',
        rows: [HELP_DESK, DATA_IMPORT, SHIFTS],
        counts: [
          { value: 3, need: 'ask' },
          { value: 1, need: 'turn' },
        ],
        isOpen: true,
      },
      { kind: 'working', rows: [MOBILE, LEDGER], counts: [{ value: 2 }], isOpen: true },
      { kind: 'snoozed', rows: [ONBOARDING], counts: [{ value: 1 }], isOpen },
    ],
    top: 0,
    board: 'read',
    ...view,
  }
}

/** A board of one section. */
const only = (kind: PanelView['sections'][number]['kind'], rows: PanelRow[], more: Partial<PanelView> = {}): PanelView => ({
  sections: [{ kind, rows, counts: [{ value: rows.length }], isOpen: true }],
  top: 0,
  board: 'read',
  ...more,
})

/** Six asks in Northwind, the newest first, then Mobile app working: more than a short terminal holds. */
const ASKS = ['Help desk redesign', 'Shift schedules', 'Invoice ledger', 'Onboarding flow', 'Mobile app', 'Data import'].map(
  (name, at) => row(`sr-nw000${at}`, 'ask', name, 'Northwind', 'Approve the rota', `${at + 1}m`),
)

/** The six asks, then Mobile app working, then Snoozed's one, folded unless `isOpen`, scrolled to `top`. */
const scrolled = (top: number, more: Partial<PanelView> & { isOpen?: boolean } = {}): PanelView => {
  const { isOpen = false, ...view } = more

  return {
    sections: [
      { kind: 'needsYou', rows: ASKS, counts: [{ value: 6, need: 'ask' }], isOpen: true },
      { kind: 'working', rows: [MOBILE], counts: [{ value: 1 }], isOpen: true },
      { kind: 'snoozed', rows: [ONBOARDING], counts: [{ value: 1 }], isOpen },
    ],
    top,
    board: 'read',
    ...view,
  }
}

/** The frame's glyphs, a string a terminal row, its trailing blanks trimmed. */
const frame = (view: PanelView, width: number, height: number, paint = NONE) =>
  text(draw(view, { width, height }, paint)).split('\n').slice(0, -1)

/** Terminal rows `from` up to `to` of the frame, as a terminal draws them at the paint's level. */
const drawn = (view: PanelView, width: number, height: number, paint: Paint, from: number, to: number) =>
  ansi(draw(view, { width, height }, paint).slice(from, to), paint.level).split('\n')

test('the board from row 1, under a blank top row: each heading with its counts, rule and chevron, each row on one line, and the key line', () => {
  expect(frame(board(), 39, 14)).toEqual([
    '',
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesi… 2  Northwind   4m',
    ' ○ Data import            Litware   1m',
    ' ● Approve the rota       Contoso  26m',
    '',
    ' WORKING 2 ───────────────────────── ▿',
    ' ✻ Running npm test     Woodgrove   6m',
    ' ◌ Waiting on 2 agents   Fabrikam  15m',
    '',
    ' SNOOZED 1 ───────────────────────── ▹',
    '',
    '',
    ' ↑↓ pick  s snoozed  q quit',
  ])
})

test("a row's words as the notch's: a row of asks its name and count, a Stopped row and a working one their status line, a Snoozed row its name and count", () => {
  const snoozedTurn = row('sr-wg0002', 'turn', 'Mobile app', 'Woodgrove', 'Drafted the screens', 'next week', {
    isSnoozed: true,
    count: 2,
  })

  expect(frame(only('needsYou', [HELP_DESK, SHIFTS]), 52, 8).slice(2, 4)).toEqual([
    ' ● Help desk redesign 2              Northwind   4m',
    ' ● Approve the rota                    Contoso  26m',
  ])
  expect(frame(only('working', [MOBILE, LEDGER]), 52, 8).slice(2, 4)).toEqual([
    ' ✻ Running npm test                  Woodgrove   6m',
    ' ◌ Waiting on 2 agents                Fabrikam  15m',
  ])
  expect(frame(only('snoozed', [ONBOARDING, snoozedTurn]), 52, 8).slice(2, 4)).toEqual([
    ' ● Onboarding flow         Tailspin  tomorrow 09:00',
    ' ● Mobile app 2           Woodgrove       next week',
  ])
})

test("a row's words in their looks: an ask's name bold in the terminal's ink, a Stopped row's status line regular in it, a working row's soft; the count, the project and the time grey", () => {
  const line = (view: PanelView) => drawn(view, 39, 8, NORDFOX, 2, 3)
  const grey = '38;2;122;130;171'

  expect(line(only('needsYou', [HELP_DESK]))).toEqual([
    ` ${ESC}[0;38;2;215;119;87m●${ESC}[0m ${ESC}[0;1mHelp desk redesi…${ESC}[0;${grey}m 2${ESC}[0m  ${ESC}[0;${grey}mNorthwind${ESC}[0m   ${ESC}[0;${grey}m4m${ESC}[0m`,
  ])
  expect(line(only('needsYou', [SHIFTS]))).toEqual([
    ` ${ESC}[0;38;2;122;162;247m●${ESC}[0m Approve the rota       ${ESC}[0;${grey}mContoso${ESC}[0m  ${ESC}[0;${grey}m26m${ESC}[0m`,
  ])
  expect(line(only('working', [MOBILE]))).toEqual([
    ` ${ESC}[0;38;2;169;177;214m✻${ESC}[0m ${ESC}[0;38;2;169;177;214mRunning npm test${ESC}[0m     ${ESC}[0;${grey}mWoodgrove${ESC}[0m   ${ESC}[0;${grey}m6m${ESC}[0m`,
  ])
})

test("a section's projects stand right-aligned in a column, ending 2 columns before its time's lane, and its lane is its widest time, 3 columns at the least", () => {
  const long = row('sr-nw0004', 'ask', 'Tax rates', 'Northwind', '', '12h')
  const later = row('sr-ct0003', 'turn', 'Mobile app', 'Contoso', 'Drafted the screens', 'Sat 09:00', { isSnoozed: true })
  const view: PanelView = {
    sections: [
      { kind: 'needsYou', rows: [DATA_IMPORT, long], counts: [{ value: 2, need: 'ask' }], isOpen: true },
      { kind: 'snoozed', rows: [later, ONBOARDING], counts: [{ value: 2 }], isOpen: true },
    ],
    top: 0,
    board: 'read',
  }

  expect(frame(view, 52, 10).slice(1, 8)).toEqual([
    ' NEEDS YOU ●2 ─────────────────────────────────── ▿',
    ' ○ Data import                         Litware   1m',
    ' ● Tax rates                         Northwind  12h',
    '',
    ' SNOOZED 2 ────────────────────────────────────── ▿',
    ' ● Mobile app               Contoso       Sat 09:00',
    ' ● Onboarding flow         Tailspin  tomorrow 09:00',
  ])
})

test('a row at every width, on one line at each; past 120 columns the layout stays 120 wide, at the left', () => {
  const rowAt = (width: number) => frame(only('needsYou', [HELP_DESK]), width, 8)[2]

  expect(rowAt(24)).toBe(' ● Help desk re… 2   4m')
  expect(rowAt(39)).toBe(' ● Help desk redesi… 2  Northwind   4m')
  expect(rowAt(69)).toBe(` ● Help desk redesign 2${' '.repeat(31)}Northwind   4m`)
  expect(rowAt(73)).toBe(` ● Help desk redesign 2${' '.repeat(35)}Northwind   4m`)
  expect(rowAt(114)).toBe(` ● Help desk redesign 2${' '.repeat(76)}Northwind   4m`)
  expect(rowAt(173)).toBe(` ● Help desk redesign 2${' '.repeat(82)}Northwind   4m`)
})

test('giving way as the width falls: the words cut to 12 cells, then the project cut to 4 cells, then gone', () => {
  const rowAt = (width: number) => frame(only('needsYou', [HELP_DESK]), width, 8)[2]

  expect(rowAt(40), 'whole').toBe(' ● Help desk redesign 2  Northwind   4m')
  expect(rowAt(39), 'the words cut').toBe(' ● Help desk redesi… 2  Northwind   4m')
  expect(rowAt(32), 'the words at 12 cells').toBe(' ● Help desk… 2  Northwind   4m')
  expect(rowAt(31), 'then the project cut').toBe(' ● Help desk… 2  Northwi…   4m')
  expect(rowAt(27), 'to 4 cells').toBe(' ● Help desk… 2  Nor…   4m')
  expect(rowAt(26), 'then gone, its room the words’').toBe(' ● Help desk rede… 2   4m')
})

test("giving way, past the project: a Snoozed wake loses its clock where that narrows the lane, then the words are cut to 6, then a section's times go", () => {
  const untilMoves = row('sr-wg0003', 'turn', 'Mobile app', 'Woodgrove', 'Drafted the screens', 'until it moves', {
    isSnoozed: true,
  })
  const rowsAt = (width: number) => frame(only('snoozed', [ONBOARDING, untilMoves]), width, 8).slice(2, 4)

  expect(rowsAt(45), 'whole').toEqual([' ● Onboarding flow  Tailspin  tomorrow 09:00', ' ● Mobile app      Woodgrove  until it moves'])
  expect(rowsAt(41), 'the words at 12 cells, the projects cut').toEqual([
    ' ● Onboarding…   Tailsp…  tomorrow 09:00',
    ' ● Mobile app  Woodgrove  until it moves',
  ])
  expect(rowsAt(37), 'a project gone, its room the words’').toEqual([
    ' ● Onboarding flow    tomorrow 09:00',
    ' ● Mobile app  Wood…  until it moves',
  ])
  expect(rowsAt(31), 'the words short of 12, in a lane no clock narrows, as `until it moves` sets it: the clocks kept').toEqual([
    ' ● Onboarding…  tomorrow 09:00',
    ' ● Mobile app   until it moves',
  ])
  expect(rowsAt(26), 'the words at 6').toEqual([' ● Onboa…  tomorrow 09:00', ' ● Mobil…  until it moves'])
  expect(rowsAt(25), 'then the times go').toEqual([' ● Onboarding flow', ' ● Mobile app'])

  const aloneAt = (width: number) => frame(only('snoozed', [ONBOARDING]), width, 8)[2]

  expect(aloneAt(32), 'the words at 12, the clock kept').toBe(' ● Onboarding…   tomorrow 09:00')
  expect(aloneAt(31), 'the words short of 12, in a lane the clock narrows: the clock goes').toBe(' ● Onboarding flow    tomorrow')
})

test('the times go by section: a section whose words keep their least keeps its times, though another loses them', () => {
  const untilMoves = row('sr-wg0003', 'turn', 'Mobile app', 'Woodgrove', 'Drafted the screens', 'until it moves', {
    isSnoozed: true,
  })
  const view: PanelView = {
    sections: [
      { kind: 'needsYou', rows: [HELP_DESK], counts: [{ value: 2, need: 'ask' }], isOpen: true },
      { kind: 'snoozed', rows: [ONBOARDING, untilMoves], counts: [{ value: 2 }], isOpen: true },
    ],
    top: 0,
    board: 'read',
  }

  expect(frame(view, 24, 10).slice(2, 7)).toEqual([' ● Help desk re… 2   4m', '', ' SNOOZED 2 ────────── ▿', ' ● Onboarding flow', ' ● Mobile app'])
})

test('a cut never splits a wide glyph, never leaves a space before its `…`, and the name is cut before its count, never the count', () => {
  const wide = row('sr-nw0003', 'ask', '漢字漢字漢字漢字漢字漢字', 'Northwind', '', '4m', { count: 12 })
  const spaced = row('sr-nw0005', 'ask', 'Onboarding flow', 'Tailspin', '', '4m')

  expect(frame(only('needsYou', [wide]), 24, 8)[2]).toBe(' ● 漢字漢字漢… 12    4m')
  expect(frame(only('needsYou', [spaced]), 31, 8)[2]).toBe(' ● Onboarding…   Tailspin   4m')
})

test('scrolled from `top`, the rows above said by `▲ N more` under their section heading, kept at the top, and those below by `▼ N more`', () => {
  expect(frame(scrolled(0), 39, 8)).toEqual([
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ● Help desk redesign   Northwind   1m',
    ' ● Shift schedules      Northwind   2m',
    ' ● Invoice ledger       Northwind   3m',
    ' ● Onboarding flow      Northwind   4m',
    ' ● Mobile app           Northwind   5m',
    ' ▼ 2 more',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(frame(scrolled(3), 39, 8)).toEqual([
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ▲ 3 more',
    ' ● Onboarding flow      Northwind   4m',
    ' ● Mobile app           Northwind   5m',
    ' ● Data import          Northwind   6m',
    ' ▼ 1 more',
    '',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(frame(scrolled(2), 24, 8)).toEqual([
    ' NEEDS YOU ●6 ─────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger    3m',
    ' ● Onboarding flow   4m',
    ' ● Mobile app        5m',
    ' ● Data import       6m',
    ' ▼ 1 more',
    ' ↑↓ pick  q quit',
  ])
})

test('below 13 rows, short of room, the blank rows between sections give way, then the body scrolls; from 13 they stay', () => {
  expect(frame(board(), 39, 9)).toEqual([
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesi… 2  Northwind   4m',
    ' ○ Data import            Litware   1m',
    ' ● Approve the rota       Contoso  26m',
    ' WORKING 2 ───────────────────────── ▿',
    ' ✻ Running npm test     Woodgrove   6m',
    ' ◌ Waiting on 2 agents   Fabrikam  15m',
    ' SNOOZED 1 ───────────────────────── ▹',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(frame(board(), 39, 8)).toEqual([
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesi… 2  Northwind   4m',
    ' ○ Data import            Litware   1m',
    ' ● Approve the rota       Contoso  26m',
    ' WORKING 2 ───────────────────────── ▿',
    ' ✻ Running npm test     Woodgrove   6m',
    ' ▼ 1 more',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(frame(scrolled(0), 39, 13).slice(6, 9)).toEqual([' ● Data import          Northwind   6m', '', ' WORKING 1 ───────────────────────── ▿'])
})

test('the blank top row gives way first, short of room: it stays only while every block fits under it, before the blank rows between sections', () => {
  expect(frame(board(), 39, 12).slice(0, 6)).toEqual([
    '',
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesi… 2  Northwind   4m',
    ' ○ Data import            Litware   1m',
    ' ● Approve the rota       Contoso  26m',
    '',
  ])
  expect(frame(board(), 39, 11), 'a row short: the top row goes, the blank rows between sections stay').toEqual([
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesi… 2  Northwind   4m',
    ' ○ Data import            Litware   1m',
    ' ● Approve the rota       Contoso  26m',
    '',
    ' WORKING 2 ───────────────────────── ▿',
    ' ✻ Running npm test     Woodgrove   6m',
    ' ◌ Waiting on 2 agents   Fabrikam  15m',
    '',
    ' SNOOZED 1 ───────────────────────── ▹',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(frame(scrolled(0), 39, 14).slice(0, 2)).toEqual(['', ' NEEDS YOU ●6 ────────────────────── ▿'])
  expect(frame(scrolled(0), 39, 13)[0], 'however tall the terminal, never at the cost of a row').toBe(' NEEDS YOU ●6 ────────────────────── ▿')
  expect(frame(board({ answer: PICKED }), 39, 15)[0], "an answer's rows take the top row's room too").toBe(' NEEDS YOU ●3 ●1 ─────────────────── ▿')
  expect(frame(board({ answer: PICKED }), 39, 16)[0]).toBe('')
})

test('a quiet board reads `All clear` and what it means, wrapped at 24 columns, centred a little above the middle', () => {
  expect(frame(only('needsYou', []), 39, 12)).toEqual([
    '',
    '',
    '',
    '               All clear',
    '',
    '        Nothing needs you, and',
    '          nothing is running.',
    '',
    '',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 24, 11).slice(2, 7)).toEqual([
    '       All clear',
    '',
    '   Nothing needs you,',
    '     and nothing is',
    '        running.',
  ])
})

test("a pick's answer sits above the key line, `!` then its words, wrapped at W−4 and hung; its rows come from the body", () => {
  const answer = "Shift schedules can't be opened here: its terminal has no tmux or zmx."

  expect(frame(board({ band: 'sr-ct0001', answer }), 39, 12)).toEqual([
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesi… 2  Northwind   4m',
    ' ○ Data import            Litware   1m',
    ' ● Approve the rota       Contoso  26m',
    ' WORKING 2 ───────────────────────── ▿',
    ' ✻ Running npm test     Woodgrove   6m',
    ' ▼ 1 more',
    '',
    " ! Shift schedules can't be opened",
    '   here: its terminal has no tmux or',
    '   zmx.',
    ' ↑↓ move  ⏎ expand  o open  q quit',
  ])
  expect(drawn(board({ answer }), 39, 12, NORDFOX, 8, 9)).toEqual([
    ` ${ESC}[0;1m!${ESC}[0m Shift schedules can't be opened`,
  ])
})

test('the key line names the keys that work now, `s` only while Snoozed holds rows, dropping whole hints from the right, `q quit` last', () => {
  const keys = (view: PanelView, width: number) => frame(view, width, 10).at(-1)

  expect(keys(board(), 39)).toBe(' ↑↓ pick  s snoozed  q quit')
  expect(keys(board({ band: 'sr-ct0001' }), 39)).toBe(' ↑↓ move  ⏎ expand  o open  q quit')
  expect(keys(board({ band: 'sr-ct0001' }), 24)).toBe(' ↑↓ move  q quit')
  expect(keys(only('working', [MOBILE]), 39)).toBe(' ↑↓ pick  q quit')
  expect(keys(only('working', []), 39)).toBe(' q quit')
  expect(drawn(only('working', [MOBILE]), 39, 8, NORDFOX, 7, 8)).toEqual([
    ` ${ESC}[0;1m↑↓${ESC}[0;38;2;122;130;171m pick${ESC}[0m  ${ESC}[0;1mq${ESC}[0;38;2;122;130;171m quit${ESC}[0m`,
  ])
})

test("the band lies over the chosen row's line, from column 1 to W−2: a ground in colour, reverse video without", () => {
  const ground = '48;2;52;61;75'

  expect(drawn(board({ band: 'sr-ct0001' }), 39, 18, NORDFOX, 4, 5)).toEqual([
    ` ${ESC}[0;38;2;122;162;247;${ground}m●${ESC}[0;${ground}m Approve the rota       ${ESC}[0;38;2;122;130;171;${ground}mContoso${ESC}[0;${ground}m  ${ESC}[0;38;2;122;130;171;${ground}m26m${ESC}[0m`,
  ])
  expect(drawn(board({ band: 'sr-ct0001' }), 39, 18, NONE, 4, 5)).toEqual([
    ` ${ESC}[0;7m● Approve the rota       ${ESC}[0;2;7mContoso${ESC}[0;7m  ${ESC}[0;2;7m26m${ESC}[0m`,
  ])
  expect(drawn(board({ band: 'sr-ct0001' }), 39, 18, NONE, 3, 6).map(line => line.includes(';7m')), 'the band on its row alone').toEqual([
    false,
    true,
    false,
  ])
})

/** A session whose name and status line a narrow row cuts short. */
const LONG = row('sr-nw0009', 'turn', 'Help desk redesign for every regional support office', 'Northwind', 'Drafted the reply templates for the billing queue', '31m')

/** A session with three lines waiting: two asks and a question with more to it. */
const SEVERAL = row('sr-nw0010', 'ask', 'Shift schedules', 'Contoso', 'Approve the rota', '4m', {
  count: 3,
  lines: [{ text: 'Approve the rota' }, { text: 'Keep the night shift at four people, or move to five?' }, { text: 'Which week first?', more: 2 }],
})

test("the chosen row expanded cuts nothing: its name, then its project and status line, wrap under the names' column, the time at the first line's right", () => {
  const view = only('needsYou', [LONG, SHIFTS], { band: 'sr-nw0009', expanded: 'sr-nw0009' })

  expect(frame(view, 39, 10)).toEqual([
    '',
    ' NEEDS YOU 2 ─────────────────────── ▿',
    ' ● Help desk redesign for every    31m',
    '   regional support office',
    '   Northwind · Drafted the reply',
    '   templates for the billing queue',
    ' ● Approve the rota       Contoso  26m',
    '',
    '',
    ' ↑↓ move  ⏎ fold  o open  q quit',
  ])
  expect(frame(view, 114, 10).slice(2, 4)).toEqual([
    ' ● Help desk redesign for every regional support office                                                       31m',
    '   Northwind · Drafted the reply templates for the billing queue',
  ])
})

test("a row of several lines expanded shows its project alone, then each line's words on a line of its own, a question's `+2` after it", () => {
  const view = only('needsYou', [SEVERAL], { band: 'sr-nw0010', expanded: 'sr-nw0010' })

  expect(frame(view, 39, 10).slice(1, 8)).toEqual([
    ' NEEDS YOU 1 ─────────────────────── ▿',
    ' ● Shift schedules 3                4m',
    '   Contoso',
    '   Approve the rota',
    '   Keep the night shift at four',
    '   people, or move to five?',
    '   Which week first? +2',
  ])
})

test('the band lies over every line of an expanded row, from column 1 to W−2', () => {
  const view = only('needsYou', [SEVERAL], { band: 'sr-nw0010', expanded: 'sr-nw0010' })

  expect(drawn(view, 39, 10, NONE, 2, 8).every(line => line.startsWith(` ${ESC}[0;7m`) || line.startsWith(` ${ESC}[0;1;7m`))).toBe(true)
  expect(drawn(view, 39, 10, NONE, 3, 4)).toEqual([` ${ESC}[0;7m  ${ESC}[0;2;7mContoso${ESC}[0;7m                            ${ESC}[0m`])
})

test('an expanded row taller than the body is cut to it, its last line kept saying `…`', () => {
  const view = only('needsYou', [SEVERAL], { band: 'sr-nw0010', expanded: 'sr-nw0010' })

  expect(frame(view, 24, 8)).toEqual([
    ' ● Shift schedules   4m',
    '   3',
    '   Contoso',
    '   Approve the rota',
    '   Keep the night shift',
    '   at four people, or',
    '   …',
    ' ↑↓ move  q quit',
  ])
})

test("an expanded band row in a body of one row, an answer taking the others, falls to its one line and stays in view", () => {
  const view = only('needsYou', [SEVERAL], { band: 'sr-nw0010', expanded: 'sr-nw0010', answer: 'word '.repeat(30) })

  expect(layoutOf(view, { width: 39, height: 8 }).rows).toEqual([{ key: 'sr-nw0010', y: 0, height: 1 }])
  expect(frame(view, 39, 8)[0]).toBe(' ● Shift schedules 3      Contoso   4m')
  expect(drawn(view, 39, 8, NONE, 0, 1)[0]?.startsWith(` ${ESC}[0;7m●`)).toBe(true)
})

/** The snooze menu open under Shift schedules, Later today picked. */
const MENU: NonNullable<PanelView['menu']> = {
  row: 'sr-ct0001',
  at: 1,
  top: 0,
  options: [
    { title: 'In an hour', time: '15:00', until: 1 },
    { title: 'Later today', time: '17:00', until: 2 },
    { title: 'Tonight', time: '18:00', until: 3 },
    { title: 'Tomorrow', time: '09:00', until: 4 },
    { title: 'This weekend', time: 'Sat 09:00', until: 5 },
    { title: 'Next week', time: 'Mon 09:00', until: 6 },
    { title: 'Until it moves', time: '' },
  ],
}

test("the snooze menu stands under the chosen row, a choice a line after its number in grey, its time at the right in grey, the band on the choice picked; the key line is the menu's own", () => {
  const view = board({ band: 'sr-ct0001', menu: MENU })

  expect(frame(view, 39, 18).slice(0, 14)).toEqual([
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesi… 2  Northwind   4m',
    ' ○ Data import            Litware   1m',
    ' ● Approve the rota       Contoso  26m',
    '   1 In an hour                  15:00',
    '   2 Later today                 17:00',
    '   3 Tonight                     18:00',
    '   4 Tomorrow                    09:00',
    '   5 This weekend            Sat 09:00',
    '   6 Next week               Mon 09:00',
    '   7 Until it moves',
    '',
    ' WORKING 2 ───────────────────────── ▿',
    ' ✻ Running npm test     Woodgrove   6m',
  ])
  expect(frame(view, 39, 20).at(-1)).toBe(' ↑↓ pick  ⏎ snooze  esc cancel')
  expect(drawn(view, 39, 18, NONE, 3, 6)).toEqual([
    ` ● Approve the rota       ${ESC}[0;2mContoso${ESC}[0m  ${ESC}[0;2m26m${ESC}[0m`,
    `   ${ESC}[0;2m1${ESC}[0m In an hour                  ${ESC}[0;2m15:00${ESC}[0m`,
    ` ${ESC}[0;7m  ${ESC}[0;2;7m2${ESC}[0;7m ${ESC}[0;1;7mLater today${ESC}[0;7m                 ${ESC}[0;2;7m17:00${ESC}[0m`,
  ])
})

test('a choice and its time fit as they can: past the width the time goes, then the name is cut', () => {
  const view = board({ band: 'sr-ct0001', menu: MENU })

  expect(frame(view, 24, 18).slice(4, 11)).toEqual([
    '   1 In an hour   15:00',
    '   2 Later today  17:00',
    '   3 Tonight      18:00',
    '   4 Tomorrow     09:00',
    '   5 This weekend',
    '   6 Next week',
    '   7 Until it moves',
  ])
})

test('the first nine choices are numbered, in grey, and those past them are not, their words in line with the numbered; a name is cut, never its number', () => {
  const titles = ['One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Until the whole of it has moved']
  const options = titles.map((title, at) => ({ title, time: '', until: at }))
  const view = board({ band: 'sr-ct0001', menu: { row: 'sr-ct0001', at: 0, top: 0, options } })

  expect(frame(view, 24, 24).slice(5, 16)).toEqual([
    '   1 One',
    '   2 Two',
    '   3 Three',
    '   4 Four',
    '   5 Five',
    '   6 Six',
    '   7 Seven',
    '   8 Eight',
    '   9 Nine',
    '     Ten',
    '     Until the whole o…',
  ])
  expect(drawn(view, 39, 24, NORDFOX, 6, 7)).toEqual([`   ${ESC}[0;38;2;122;130;171m2${ESC}[0m Two`])
})

test('the key line names z for the band\'s row: snooze on one that needs you, wake in Snoozed, nothing on a working row', () => {
  const keys = (view: PanelView) => frame(view, 69, 22).at(-1)

  expect(keys(board({ band: 'sr-ct0001' }))).toBe(' ↑↓ move  ⏎ expand  o open  z snooze  s snoozed  q quit')
  expect(keys(board({ band: 'snoozed:sr-ts0001', isOpen: true }))).toBe(' ↑↓ move  ⏎ expand  o open  z wake  s snoozed  q quit')
  expect(keys(board({ band: 'sr-wg0001' }))).toBe(' ↑↓ move  ⏎ expand  o open  s snoozed  q quit')
  expect(keys(board({ band: 'sr-ct0001', menu: MENU }))).toBe(' ↑↓ pick  ⏎ snooze  esc cancel')
  expect(frame(board({ band: 'sr-ct0001', menu: MENU }), 24, 22).at(-1)).toBe(' ↑↓ pick  esc cancel')
})

test("the band names a row by its key: a session's Snoozed row is its own", () => {
  const view = board({ isOpen: true, band: 'snoozed:sr-ts0001' })
  const snoozed = drawn(view, 39, 20, NONE, 11, 12)

  expect(snoozed[0]?.startsWith(` ${ESC}[0;2;7m●`)).toBe(true)
  expect(drawn(board({ isOpen: true, band: 'sr-ts0001' }), 39, 20, NONE, 11, 12)[0]).not.toContain(';7m●')
})

test("an away row's words dim as one, its mark kept full and hollow; without colour a bold name stays bold, never faint", () => {
  expect(drawn(board(), 39, 18, NORDFOX, 3, 4)).toEqual([
    ` ${ESC}[0;38;2;215;119;87m○${ESC}[0m ${ESC}[0;1;38;2;143;146;151mData import${ESC}[0m            ${ESC}[0;38;2;92;100;129mLitware${ESC}[0m   ${ESC}[0;38;2;92;100;129m1m${ESC}[0m`,
  ])
  expect(drawn(board(), 39, 18, NONE, 3, 4)).toEqual([
    ` ○ ${ESC}[0;1mData import${ESC}[0m            ${ESC}[0;2mLitware${ESC}[0m   ${ESC}[0;2m1m${ESC}[0m`,
  ])
})

test("on the band, an away row's words dim toward the band's ground, not the terminal's background", () => {
  const ground = '48;2;52;61;75'

  expect(drawn(board({ band: 'sr-lw0001' }), 39, 18, NORDFOX, 3, 4)).toEqual([
    ` ${ESC}[0;38;2;215;119;87;${ground}m○${ESC}[0;${ground}m ${ESC}[0;1;38;2;145;149;156;${ground}mData import${ESC}[0;${ground}m            ${ESC}[0;38;2;95;103;134;${ground}mLitware${ESC}[0;${ground}m   ${ESC}[0;38;2;95;103;134;${ground}m1m${ESC}[0m`,
  ])
})

test("a Snoozed row dims its mark alone, filled even away; its name grey, an ask bold, and its project as any row's", () => {
  const away = row('sr-wg0002', 'turn', 'Mobile app', 'Woodgrove', 'Drafted the screens', 'next week', {
    isSnoozed: true,
    isAway: true,
  })
  const grey = '38;2;122;130;171'

  expect(drawn(only('snoozed', [ONBOARDING, away]), 39, 8, NORDFOX, 2, 4)).toEqual([
    ` ${ESC}[0;38;2;149;93;78m●${ESC}[0m ${ESC}[0;1;${grey}mOnboarding…${ESC}[0m   ${ESC}[0;${grey}mTail…${ESC}[0m  ${ESC}[0;${grey}mtomorrow 09:00${ESC}[0m`,
    ` ${ESC}[0;38;2;92;119;176m●${ESC}[0m ${ESC}[0;${grey}mMobile app${ESC}[0m  ${ESC}[0;${grey}mWoodgr…${ESC}[0m       ${ESC}[0;${grey}mnext week${ESC}[0m`,
  ])
})

test("a new ask's mark is `◉`, bold orange, its row washed at 24-bit where the mix can be made; the band wins over the wash", () => {
  const arriving = row('sr-ct0002', 'ask', 'Data import', 'Contoso', 'Approve the rota', 'now', { isNew: true })
  const view = (band?: string): PanelView => ({ ...only('needsYou', [arriving]), ...(band === undefined ? {} : { band }) })
  const wash = `48;2;83;67;69`
  const grey = '38;2;122;130;171'

  expect(drawn(view(), 39, 8, NORDFOX, 2, 3)).toEqual([
    ` ${ESC}[0;1;38;2;215;119;87;${wash}m◉${ESC}[0;${wash}m ${ESC}[0;1;${wash}mData import${ESC}[0;${wash}m            ${ESC}[0;${grey};${wash}mContoso${ESC}[0;${wash}m  ${ESC}[0;${grey};${wash}mnow${ESC}[0m`,
  ])
  expect(drawn(view(), 39, 8, { level: 'truecolor' }, 2, 3)).toEqual([
    ` ${ESC}[0;1;38;2;215;119;87m◉${ESC}[0m ${ESC}[0;1mData import${ESC}[0m            ${ESC}[0;${grey}mContoso${ESC}[0m  ${ESC}[0;${grey}mnow${ESC}[0m`,
  ])
  expect(drawn(view(), 39, 8, NONE, 2, 3)).toEqual([
    ` ${ESC}[0;1m◉${ESC}[0m ${ESC}[0;1mData import${ESC}[0m            ${ESC}[0;2mContoso${ESC}[0m  ${ESC}[0;2mnow${ESC}[0m`,
  ])
  expect(drawn(view('sr-ct0002'), 39, 8, NORDFOX, 2, 3)[0]).toContain('48;2;52;61;75m')
  expect(drawn(view('sr-ct0002'), 39, 8, NORDFOX, 2, 3)[0]).not.toContain(wash)
})

test('the headings: grey words, the needs-you counts in bold orange and blue, the rule and chevron faint', () => {
  expect(drawn(board(), 39, 18, NORDFOX, 1, 2)).toEqual([
    ` ${ESC}[0;38;2;122;130;171mNEEDS YOU${ESC}[0m ${ESC}[0;38;2;215;119;87m●${ESC}[0;1;38;2;215;119;87m3${ESC}[0m ${ESC}[0;38;2;122;162;247m●${ESC}[0;1;38;2;122;162;247m1${ESC}[0m ${ESC}[0;38;2;86;95;137m───────────────────${ESC}[0m ${ESC}[0;38;2;86;95;137m▿${ESC}[0m`,
  ])
  expect(drawn(board(), 39, 18, NONE, 6, 7)).toEqual([
    ` WORKING ${ESC}[0;2m2${ESC}[0m ${ESC}[0;2m─────────────────────────${ESC}[0m ${ESC}[0;2m▿${ESC}[0m`,
  ])
})

test('the rule goes below 3 cells, its counts and chevron kept', () => {
  const many: PanelView = {
    sections: [
      {
        kind: 'needsYou',
        rows: [SHIFTS],
        counts: [
          { value: 123, need: 'ask' },
          { value: 45, need: 'turn' },
        ],
        isOpen: true,
      },
    ],
    top: 0,
    board: 'read',
  }

  expect(frame(many, 24, 8)[1]).toBe(' NEEDS YOU ●123 ●45   ▿')
})

test("there is no title: row 0 stays blank, a stale board's too, and a stale board says when it was read at the key line's right end, the keys cut to the room left of it", () => {
  const empty = { sections: [], top: 0 }

  expect(frame({ ...empty, board: 'stale', asOf: '12:04' }, 39, 10).at(-1)).toBe(' q quit                    as of 12:04')
  expect(frame({ ...empty, board: 'read', asOf: '12:04' }, 39, 10).at(-1)).toBe(' q quit')
  expect(frame(board({ board: 'stale', asOf: '12:04' }), 39, 18).at(-1)).toBe(' ↑↓ pick  q quit           as of 12:04')
  expect(frame(board({ board: 'stale', asOf: '12:04', band: 'sr-ct0001' }), 52, 18).at(-1)).toBe(' ↑↓ move  ⏎ expand  o open  q quit      as of 12:04')
  expect(frame(board({ board: 'stale', asOf: '12:04', band: 'sr-ct0001' }), 24, 18).at(-1)).toBe(' q quit     as of 12:04')
  expect(frame(board({ board: 'stale', asOf: '12:04' }), 39, 18).slice(0, 2)).toEqual(['', ' NEEDS YOU ●3 ●1 ─────────────────── ▿'])
})

test("before any board, the body says it's looking, or why it can't read one, centred under the top row while they fit under it", () => {
  const empty = { sections: [], top: 0 }

  expect(frame({ ...empty, board: 'looking' }, 39, 10)).toEqual([
    '',
    '',
    '',
    '         Looking for sessions…',
    '',
    '',
    '',
    '',
    '',
    ' q quit',
  ])
  expect(
    frame({ ...empty, board: 'looking', reason: "EACCES: permission denied, scandir '/Users/me/.local/state'" }, 39, 13).slice(
      3,
      7,
    ),
  ).toEqual([
    "         Can't read the board",
    '',
    '  EACCES: permission denied, scandir',
    "       '/Users/me/.local/state'",
  ])
  expect(frame({ ...empty, board: 'looking', reason: 'EACCES: permission denied, scandir' }, 24, 8).slice(0, 5)).toEqual([
    '',
    "  Can't read the board",
    '',
    '   EACCES: permission',
    '    denied, scandir',
  ])
})

test('below 24 columns or 8 rows only `Too small`, at the margin, cut to the width, under the blank top row while there is one', () => {
  const tooSmall = (width: number, height: number) => frame(board(), width, height)

  expect(tooSmall(23, 10)).toEqual(['', ' Too small', ...Array<string>(8).fill('')])
  expect(tooSmall(24, 7)).toEqual(['', ' Too small', ...Array<string>(5).fill('')])
  expect(tooSmall(24, 2)).toEqual(['', ' Too small'])
  expect(tooSmall(24, 1)).toEqual([' Too small'])
  expect(tooSmall(8, 8)[1]).toBe(' Too s…')
  expect(tooSmall(24, 8)[0]).toBe(' NEEDS YOU ●3 ●1 ──── ▿')
})

test('the lines as text: each its glyphs, trimmed, a newline after each; as escapes: a reset where a line ends styled, a newline between', () => {
  const lines = draw(only('working', [MOBILE]), { width: 24, height: 8 }, NONE)

  expect(text(lines)).toBe(['', ' WORKING 1 ────────── ▿', ' ✻ Running npm te…   6m', '', '', '', '', ' ↑↓ pick  q quit', ''].join('\n'))
  expect(ansi(lines, 'none').split('\n')).toEqual([
    '',
    ` WORKING ${ESC}[0;2m1${ESC}[0m ${ESC}[0;2m──────────${ESC}[0m ${ESC}[0;2m▿${ESC}[0m`,
    ` ✻ Running npm te…   ${ESC}[0;2m6m${ESC}[0m`,
    '',
    '',
    '',
    '',
    ` ${ESC}[0;1m↑↓${ESC}[0;2m pick${ESC}[0m  ${ESC}[0;1mq${ESC}[0;2m quit${ESC}[0m`,
  ])
})

const PICKED = "Shift schedules can't be opened here: its terminal has no tmux or zmx."

const NO_FOLDER =
  "Shift schedules's last window did not say which folder it ran in, as a window on an older sitrep does not, so sitrep has nothing to put for {dir}."

test('every element at every width: the stale notice, the pinned heading and its counts, `▲`, `▼`, the band, the answer and the key line', () => {
  const view = scrolled(2, { band: 'sr-nw0003', answer: PICKED, board: 'stale', asOf: '12:04' })

  expect(frame(view, 24, 12)).toEqual([
    ' NEEDS YOU ●6 ─────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger    3m',
    ' ● Onboarding flow   4m',
    ' ● Mobile app        5m',
    ' ▼ 2 more',
    '',
    ' ! Shift schedules',
    "   can't be opened",
    '   here: its terminal',
    '   has no tmux or zmx.',
    ' q quit     as of 12:04',
  ])
  expect(frame(view, 39, 12)).toEqual([
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger       Northwind   3m',
    ' ● Onboarding flow      Northwind   4m',
    ' ● Mobile app           Northwind   5m',
    ' ● Data import          Northwind   6m',
    ' ▼ 1 more',
    '',
    " ! Shift schedules can't be opened",
    '   here: its terminal has no tmux or',
    '   zmx.',
    ' ↑↓ move  q quit           as of 12:04',
  ])
  expect(frame(view, 69, 12)).toEqual([
    ' NEEDS YOU ●6 ──────────────────────────────────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                                     Northwind   3m',
    ' ● Onboarding flow                                    Northwind   4m',
    ' ● Mobile app                                         Northwind   5m',
    ' ● Data import                                        Northwind   6m',
    ' ▼ 1 more',
    '',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or",
    '   zmx.',
    ' ↑↓ move  ⏎ expand  o open  s snoozed  q quit            as of 12:04',
  ])
  expect(frame(view, 73, 12)).toEqual([
    ' NEEDS YOU ●6 ──────────────────────────────────────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                                         Northwind   3m',
    ' ● Onboarding flow                                        Northwind   4m',
    ' ● Mobile app                                             Northwind   5m',
    ' ● Data import                                            Northwind   6m',
    ' ▼ 1 more',
    '',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or",
    '   zmx.',
    ' ↑↓ move  ⏎ expand  o open  s snoozed  q quit                as of 12:04',
  ])
  expect(frame(view, 114, 12)).toEqual([
    ' NEEDS YOU ●6 ───────────────────────────────────────────────────────────────────────────────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                                                                                  Northwind   3m',
    ' ● Onboarding flow                                                                                 Northwind   4m',
    ' ● Mobile app                                                                                      Northwind   5m',
    ' ● Data import                                                                                     Northwind   6m',
    ' WORKING 1 ──────────────────────────────────────────────────────────────────────────────────────────────────── ▿',
    ' ✻ Running npm test                                                                                Woodgrove   6m',
    ' SNOOZED 1 ──────────────────────────────────────────────────────────────────────────────────────────────────── ▹',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or zmx.",
    ' ↑↓ move  ⏎ expand  o open  s snoozed  q quit                                                         as of 12:04',
  ])
  expect(frame(view, 173, 12)).toEqual([
    ' NEEDS YOU ●6 ─────────────────────────────────────────────────────────────────────────────────────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                                                                                        Northwind   3m',
    ' ● Onboarding flow                                                                                       Northwind   4m',
    ' ● Mobile app                                                                                            Northwind   5m',
    ' ● Data import                                                                                           Northwind   6m',
    ' WORKING 1 ────────────────────────────────────────────────────────────────────────────────────────────────────────── ▿',
    ' ✻ Running npm test                                                                                      Woodgrove   6m',
    ' SNOOZED 1 ────────────────────────────────────────────────────────────────────────────────────────────────────────── ▹',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or zmx.",
    ' ↑↓ move  ⏎ expand  o open  s snoozed  q quit                                                               as of 12:04',
  ])
})

test("the quiet board at every width, centred in the body's place", () => {
  expect(frame(only('needsYou', []), 24, 9)).toEqual([
    '',
    '       All clear',
    '',
    '   Nothing needs you,',
    '     and nothing is',
    '        running.',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 39, 8)).toEqual([
    '',
    '               All clear',
    '',
    '        Nothing needs you, and',
    '          nothing is running.',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 69, 8)).toEqual([
    '',
    '                              All clear',
    '',
    '                       Nothing needs you, and',
    '                         nothing is running.',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 73, 8)).toEqual([
    '',
    '                                All clear',
    '',
    '                         Nothing needs you, and',
    '                           nothing is running.',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 114, 8)).toEqual([
    '',
    '                                                    All clear',
    '',
    '                                              Nothing needs you, and',
    '                                               nothing is running.',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 173, 8)).toEqual([
    '',
    '                                                       All clear',
    '',
    '                                                 Nothing needs you, and',
    '                                                  nothing is running.',
    '',
    '',
    ' q quit',
  ])
})

test('scrolled with the blank rows between sections kept, at 13 rows and more', () => {
  expect(frame(scrolled(2, { isOpen: true }), 39, 13)).toEqual([
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger       Northwind   3m',
    ' ● Onboarding flow      Northwind   4m',
    ' ● Mobile app           Northwind   5m',
    ' ● Data import          Northwind   6m',
    '',
    ' WORKING 1 ───────────────────────── ▿',
    ' ✻ Running npm test     Woodgrove   6m',
    '',
    ' SNOOZED 1 ───────────────────────── ▿',
    ' ● Onboarding…   Tail…  tomorrow 09:00',
    ' ↑↓ pick  s snoozed  q quit',
  ])
})

test('`top` past the end goes no further than the greatest that still fills the body', () => {
  expect(layoutOf(scrolled(99, { isOpen: true }), { width: 39, height: 8 }).lastTop).toBe(5)
  expect(frame(scrolled(99, { isOpen: true }), 39, 8)).toEqual(frame(scrolled(5, { isOpen: true }), 39, 8))
  expect(frame(scrolled(99, { isOpen: true }), 39, 8)).toEqual([
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ▲ 5 more',
    ' ● Data import          Northwind   6m',
    ' WORKING 1 ───────────────────────── ▿',
    ' ✻ Running npm test     Woodgrove   6m',
    ' SNOOZED 1 ───────────────────────── ▿',
    ' ● Onboarding…   Tail…  tomorrow 09:00',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(layoutOf(scrolled(99, { isOpen: true }), { width: 39, height: 40 }).top).toBe(0)
})

test("the layout gives the body's rows, where each row in view stands by its key, and the greatest `top`", () => {
  const layout = layoutOf(scrolled(3, { band: 'sr-nw0003', answer: PICKED }), { width: 39, height: 11 })

  expect(layout.body).toEqual({ from: 0, to: 6 })
  expect(layout.words).toEqual({ from: 0, to: 6 })
  expect(layout.answer).toEqual({
    from: 7,
    lines: ["Shift schedules can't be opened", 'here: its terminal has no tmux or', 'zmx.'],
  })
  expect(layout.rows).toEqual([
    { key: 'sr-nw0003', y: 2, height: 1 },
    { key: 'sr-nw0004', y: 3, height: 1 },
    { key: 'sr-nw0005', y: 4, height: 1 },
  ])
  expect(layout.lastTop).toBe(5)
})

test('an answer taller than the body keeps the key line, takes the rows above it, less its blank row, and cuts its last line', () => {
  expect(frame(board({ band: 'sr-ct0001', answer: NO_FOLDER }), 24, 8)).toEqual([
    '',
    " ! Shift schedules's",
    '   last window did not',
    '   say which folder it',
    '   ran in, as a window',
    '   on an older sitrep',
    '   does not, so sitrep…',
    ' ⏎ expand  q quit',
  ])
  expect(frame(board({ band: 'sr-ct0001', answer: NO_FOLDER }), 24, 12)).toEqual([
    ' ● Help desk re… 2   4m',
    ' ▼ 4 more',
    '',
    " ! Shift schedules's",
    '   last window did not',
    '   say which folder it',
    '   ran in, as a window',
    '   on an older sitrep',
    '   does not, so sitrep',
    '   has nothing to put',
    '   for {dir}.',
    ' ↑↓ move  q quit',
  ])
})

test('centred words stand in the rows the body leaves, above the answer and the key line, their last line cut where they run over', () => {
  const reason = "EACCES: permission denied, open '/Users/me/.local/state/sitrep/projects/northwind/sessions/sr-nw0001.json'"

  expect(frame(only('needsYou', [], { answer: PICKED }), 24, 8)).toEqual([
    '',
    '       All clear',
    '',
    ' ! Shift schedules',
    "   can't be opened",
    '   here: its terminal',
    '   has no tmux or zmx.',
    ' q quit',
  ])
  expect(frame(only('needsYou', [], { answer: PICKED }), 39, 9)).toEqual([
    '               All clear',
    '',
    '        Nothing needs you, and',
    '          nothing is running.',
    '',
    " ! Shift schedules can't be opened",
    '   here: its terminal has no tmux or',
    '   zmx.',
    ' q quit',
  ])
  expect(frame({ sections: [], top: 0, board: 'looking', reason }, 24, 8)).toEqual([
    "  Can't read the board",
    '',
    '   EACCES: permission',
    '      denied, open',
    "  '/Users/me/.local/st",
    '  ate/sitrep/projects/',
    '  northwind/sessions/…',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 24, 8)).toEqual([
    '',
    '       All clear',
    '',
    '   Nothing needs you,',
    '     and nothing is',
    '        running.',
    '',
    ' q quit',
  ])
})

test("without colour an ask's count is bold and a turn's regular, as their names are", () => {
  expect(drawn(board(), 39, 18, NONE, 1, 2)).toEqual([
    ` NEEDS YOU ●${ESC}[0;1m3${ESC}[0m ●1 ${ESC}[0;2m───────────────────${ESC}[0m ${ESC}[0;2m▿${ESC}[0m`,
  ])
})

test("at 256 colours: the palette's nearest, the dims mixed, the band a ground, and no wash", () => {
  const arriving: PanelRow = { ...DATA_IMPORT, session: 'sr-lw0002', isAway: false, isNew: true }
  const view = board({ band: 'sr-ct0001' })
  const [needsYou, ...rest] = view.sections

  expect(
    drawn({ ...view, sections: [{ ...needsYou!, rows: [arriving, ...needsYou!.rows] }, ...rest] }, 39, 14, { ...NORDFOX, level: '256' }, 0, 14),
  ).toEqual([
    '',
    ` ${ESC}[0;38;5;103mNEEDS YOU${ESC}[0m ${ESC}[0;38;5;173m●${ESC}[0;1;38;5;173m3${ESC}[0m ${ESC}[0;38;5;111m●${ESC}[0;1;38;5;111m1${ESC}[0m ${ESC}[0;38;5;60m───────────────────${ESC}[0m ${ESC}[0;38;5;60m▿${ESC}[0m`,
    ` ${ESC}[0;1;38;5;173m◉${ESC}[0m ${ESC}[0;1mData import${ESC}[0m            ${ESC}[0;38;5;103mLitware${ESC}[0m   ${ESC}[0;38;5;103m1m${ESC}[0m`,
    ` ${ESC}[0;38;5;173m●${ESC}[0m ${ESC}[0;1mHelp desk redesi…${ESC}[0;38;5;103m 2${ESC}[0m  ${ESC}[0;38;5;103mNorthwind${ESC}[0m   ${ESC}[0;38;5;103m4m${ESC}[0m`,
    ` ${ESC}[0;38;5;173m○${ESC}[0m ${ESC}[0;1;38;5;246mData import${ESC}[0m            ${ESC}[0;38;5;60mLitware${ESC}[0m   ${ESC}[0;38;5;60m1m${ESC}[0m`,
    ` ${ESC}[0;38;5;111;48;5;237m●${ESC}[0;48;5;237m Approve the rota       ${ESC}[0;38;5;103;48;5;237mContoso${ESC}[0;48;5;237m  ${ESC}[0;38;5;103;48;5;237m26m${ESC}[0m`,
    '',
    ` ${ESC}[0;38;5;103mWORKING${ESC}[0m ${ESC}[0;38;5;103m2${ESC}[0m ${ESC}[0;38;5;60m─────────────────────────${ESC}[0m ${ESC}[0;38;5;60m▿${ESC}[0m`,
    ` ${ESC}[0;38;5;146m✻${ESC}[0m ${ESC}[0;38;5;146mRunning npm test${ESC}[0m     ${ESC}[0;38;5;103mWoodgrove${ESC}[0m   ${ESC}[0;38;5;103m6m${ESC}[0m`,
    ` ${ESC}[0;38;5;103m◌${ESC}[0m ${ESC}[0;38;5;146mWaiting on 2 agents${ESC}[0m   ${ESC}[0;38;5;103mFabrikam${ESC}[0m  ${ESC}[0;38;5;103m15m${ESC}[0m`,
    '',
    ` ${ESC}[0;38;5;103mSNOOZED${ESC}[0m ${ESC}[0;38;5;103m1${ESC}[0m ${ESC}[0;38;5;60m─────────────────────────${ESC}[0m ${ESC}[0;38;5;60m▹${ESC}[0m`,
    '',
    ` ${ESC}[0;1m↑↓${ESC}[0;38;5;103m move${ESC}[0m  ${ESC}[0;1m⏎${ESC}[0;38;5;103m expand${ESC}[0m  ${ESC}[0;1mo${ESC}[0;38;5;103m open${ESC}[0m  ${ESC}[0;1mq${ESC}[0;38;5;103m quit${ESC}[0m`,
  ])
})

test("at 16 colours: the terminal's own, the rule faint, the dims faint, the band reverse video", () => {
  expect(drawn(board({ band: 'sr-ct0001' }), 39, 14, { ...NORDFOX, level: '16' }, 0, 14)).toEqual([
    '',
    ` ${ESC}[0;90mNEEDS YOU${ESC}[0m ${ESC}[0;33m●${ESC}[0;1;33m3${ESC}[0m ${ESC}[0;34m●${ESC}[0;1;34m1${ESC}[0m ${ESC}[0;2;90m───────────────────${ESC}[0m ${ESC}[0;2;90m▿${ESC}[0m`,
    ` ${ESC}[0;33m●${ESC}[0m ${ESC}[0;1mHelp desk redesi…${ESC}[0;90m 2${ESC}[0m  ${ESC}[0;90mNorthwind${ESC}[0m   ${ESC}[0;90m4m${ESC}[0m`,
    ` ${ESC}[0;33m○${ESC}[0m ${ESC}[0;1mData import${ESC}[0m            ${ESC}[0;2;90mLitware${ESC}[0m   ${ESC}[0;2;90m1m${ESC}[0m`,
    ` ${ESC}[0;7;34m●${ESC}[0;7m Approve the rota       ${ESC}[0;7;90mContoso${ESC}[0;7m  ${ESC}[0;7;90m26m${ESC}[0m`,
    '',
    ` ${ESC}[0;90mWORKING${ESC}[0m ${ESC}[0;90m2${ESC}[0m ${ESC}[0;2;90m─────────────────────────${ESC}[0m ${ESC}[0;2;90m▿${ESC}[0m`,
    ` ✻ Running npm test     ${ESC}[0;90mWoodgrove${ESC}[0m   ${ESC}[0;90m6m${ESC}[0m`,
    ` ${ESC}[0;90m◌${ESC}[0m Waiting on 2 agents   ${ESC}[0;90mFabrikam${ESC}[0m  ${ESC}[0;90m15m${ESC}[0m`,
    '',
    ` ${ESC}[0;90mSNOOZED${ESC}[0m ${ESC}[0;90m1${ESC}[0m ${ESC}[0;2;90m─────────────────────────${ESC}[0m ${ESC}[0;2;90m▹${ESC}[0m`,
    '',
    '',
    ` ${ESC}[0;1m↑↓${ESC}[0;90m move${ESC}[0m  ${ESC}[0;1m⏎${ESC}[0;90m expand${ESC}[0m  ${ESC}[0;1mo${ESC}[0;90m open${ESC}[0m  ${ESC}[0;1mq${ESC}[0;90m quit${ESC}[0m`,
  ])
})

/** Seven asks: the six, and one more in Contoso. */
const SEVEN: PanelView = {
  sections: [
    {
      kind: 'needsYou',
      rows: [...ASKS, row('sr-ct0006', 'ask', 'Help desk redesign', 'Contoso', 'Approve the rota', '7m')],
      counts: [{ value: 7, need: 'ask' }],
      isOpen: true,
    },
  ],
  top: 0,
  board: 'read',
}

test('with 4 body rows a scrolled body shows its pinned heading and `▲` over its row, `▼` under it; with 3, `▲` alone over it; with 2, the row and `▼` alone', () => {
  const seven = (answer: string): PanelView => ({ ...SEVEN, top: 1, answer })

  expect(frame(seven('Short. And a second line of words, to wrap.'), 33, 8)).toEqual([
    ' NEEDS YOU ●7 ──────────────── ▿',
    ' ▲ 1 more',
    ' ● Shift schedu…  Northwind   2m',
    ' ▼ 5 more',
    '',
    ' ! Short. And a second line of',
    '   words, to wrap.',
    ' ↑↓ pick  q quit',
  ])
  expect(layoutOf(seven('Short. And a second line of words, to wrap.'), { width: 33, height: 8 }).rows).toEqual([
    { key: 'sr-nw0001', y: 2, height: 1 },
  ])
  expect(frame(seven('Short. And a second line of words, to wrap, and then a third line of them.'), 33, 8).slice(0, 3)).toEqual([
    ' ▲ 1 more',
    ' ● Shift schedu…  Northwind   2m',
    ' ▼ 5 more',
  ])
  expect(
    frame(seven('Short. And a second line of words, to wrap, and then a third line of them, and a fourth line too.'), 33, 8).slice(0, 3),
  ).toEqual([' ● Shift schedu…  Northwind   2m', ' ▼ 5 more', ''])
})

test('a band low in Working, scrolled, with an answer that leaves the body little room, stays in sight', () => {
  const needs = ['Help desk redesign', 'Shift schedules', 'Data import'].map((name, at) =>
    row(`sr-nw010${at}`, 'ask', name, 'Northwind', 'Approve the rota', `${at + 1}m`),
  )
  const working = ['Mobile app', 'Invoice ledger', 'Onboarding flow', 'Data import'].map((name, at) =>
    row(`sr-wg010${at}`, 'working', name, 'Woodgrove', 'Running npm test', `${at + 1}m`),
  )
  const view: PanelView = {
    sections: [
      { kind: 'needsYou', rows: needs, counts: [{ value: 3, need: 'ask' }], isOpen: true },
      { kind: 'working', rows: working, counts: [{ value: 4 }], isOpen: true },
    ],
    band: 'sr-wg0101',
    top: 4,
    answer: NO_FOLDER,
    board: 'read',
  }

  expect(frame(view, 24, 14)).toEqual([
    ' WORKING 4 ────────── ▿',
    ' ▲ 4 more',
    ' ✻ Running npm te…   2m',
    ' ▼ 2 more',
    '',
    " ! Shift schedules's",
    '   last window did not',
    '   say which folder it',
    '   ran in, as a window',
    '   on an older sitrep',
    '   does not, so sitrep',
    '   has nothing to put',
    '   for {dir}.',
    ' ↑↓ move  q quit',
  ])
  expect(layoutOf(view, { width: 24, height: 14 }).rows).toEqual([{ key: 'sr-wg0101', y: 2, height: 1 }])
})

test('every row can be brought into view, whole, at every room the body has from 1 row up', () => {
  const view = scrolled(0, { isOpen: true })
  const keys = view.sections.flatMap(section => section.rows.map(rowKey))
  const rooms = new Set<number>()

  for (let height = 8; height <= 22; height++) {
    for (let words = 0; words <= 40; words += 4) {
      const answered = { ...view, ...(words === 0 ? {} : { answer: 'word '.repeat(words) }) }
      const size = { width: 30, height }
      const { body } = layoutOf(answered, size)
      const room = body.to - body.from

      rooms.add(room)

      if (room >= 1) {
        for (const key of keys) {
          const top = topFor(answered, size, key)

          expect(top).not.toBeUndefined()
          expect(layoutOf({ ...answered, top: top ?? 0 }, size).rows.map(each => each.key)).toContain(key)
        }
      }
    }
  }

  expect([1, 2, 3, 4, 5, 6, 7, 8, 9, 10].every(room => rooms.has(room))).toBe(true)
})

test('`topFor` gives the `top` nearest the view\'s that shows the row whole: the band at the start, the middle and the end, and under an answer', () => {
  const size = { width: 39, height: 8 }

  expect(topFor(scrolled(3), size, 'sr-nw0000')).toBe(0)
  expect(topFor(scrolled(0), size, 'sr-nw0003')).toBe(0)
  expect(topFor(scrolled(0), size, 'sr-nw0005')).toBe(2)
  expect(topFor(scrolled(4), size, 'sr-nw0002')).toBe(2)
  expect(topFor(scrolled(0), size, 'sr-wg0001')).toBe(4)
  expect(topFor(scrolled(0, { answer: PICKED }), size, 'sr-nw0001')).toBe(1)
  expect(topFor(scrolled(0, { answer: PICKED }), size, 'sr-nw0004')).toBe(4)
  expect(topFor(scrolled(0), size, 'snoozed:sr-ts0001')).toBeUndefined()
  expect(topFor(scrolled(0), size, 'sr-nw9999')).toBeUndefined()
})

test('`▼` stands under the rows it counts, never under a blank row', () => {
  const five: PanelView = {
    sections: [
      { kind: 'needsYou', rows: ASKS.slice(0, 5), counts: [{ value: 5, need: 'ask' }], isOpen: true },
      { kind: 'working', rows: [MOBILE], counts: [{ value: 1 }], isOpen: true },
    ],
    top: 1,
    board: 'read',
  }

  expect(frame(five, 30, 8)).toEqual([
    ' NEEDS YOU ●5 ───────────── ▿',
    ' ▲ 1 more',
    ' ● Shift sched…  Northw…   2m',
    ' ● Invoice led…  Northw…   3m',
    ' ● Onboarding…   Northw…   4m',
    ' ● Mobile app  Northwind   5m',
    ' ▼ 1 more',
    ' ↑↓ pick  q quit',
  ])
})

test('`↑↓` is offered only while a row is in view: not over a folded Snoozed alone, nor while an answer fills the body', () => {
  const folded: PanelView = { ...only('snoozed', [ONBOARDING]), sections: [{ ...only('snoozed', [ONBOARDING]).sections[0]!, isOpen: false }] }

  expect(frame(folded, 39, 10).at(-1)).toBe(' s snoozed  q quit')
  expect(frame(only('working', [MOBILE], { answer: NO_FOLDER }), 24, 8).at(-1)).toBe(' q quit')
})

test('a squeezed quiet board cuts its words at 24 columns, as it wraps them', () => {
  expect(frame(only('needsYou', [], { answer: NO_FOLDER }), 69, 8)).toEqual([
    '                              All clear',
    '',
    '                       Nothing needs you, and…',
    '',
    " ! Shift schedules's last window did not say which folder it ran in,",
    '   as a window on an older sitrep does not, so sitrep has nothing to',
    '   put for {dir}.',
    ' q quit',
  ])
})

test('the chevron never overwrites a count: past W−3 it goes', () => {
  const many: PanelView = {
    sections: [
      {
        kind: 'needsYou',
        rows: [SHIFTS],
        counts: [
          { value: 12345, need: 'ask' },
          { value: 567, need: 'turn' },
        ],
        isOpen: true,
      },
    ],
    top: 0,
    board: 'read',
  }

  expect(frame(many, 24, 8)[1]).toBe(' NEEDS YOU ●12345 ●567')
})

test('a wide glyph or an emoji at the right edge is cut whole, nothing drawn past W−2', () => {
  const wide = row('sr-nw0011', 'ask', 'Data 漢字漢字漢字 import 👍👍', 'Northwind', '', '4m')
  const emoji = row('sr-nw0012', 'turn', 'Help desk redesign', 'Contoso', 'Approve 👍👍👍👍👍👍', '1m')
  const lines = (width: number) => frame(only('needsYou', [wide, emoji]), width, 8)

  expect(lines(25).slice(2, 4)).toEqual([' ● Data 漢字漢字漢…   4m', ' ● Approve 👍👍👍…    1m'])
  expect(lines(27).slice(2, 4)).toEqual([' ● Data 漢字漢…  Nor…   4m', ' ● Approve 👍…   Con…   1m'])
  expect([24, 25, 26, 27, 28].every(width => lines(width).every(line => widthOf(line) <= width - 1))).toBe(true)
})

test('a body never ends on an open heading: a section that has no room for a row under its heading leaves it for `▼`', () => {
  const view: PanelView = {
    sections: [
      { kind: 'needsYou', rows: ASKS.slice(0, 5), counts: [{ value: 5, need: 'ask' }], isOpen: true },
      { kind: 'working', rows: [MOBILE, LEDGER], counts: [{ value: 2 }], isOpen: true },
    ],
    top: 0,
    board: 'read',
  }

  expect(frame(view, 30, 8)).toEqual([
    ' NEEDS YOU ●5 ───────────── ▿',
    ' ● Help desk r…  Northw…   1m',
    ' ● Shift sched…  Northw…   2m',
    ' ● Invoice led…  Northw…   3m',
    ' ● Onboarding…   Northw…   4m',
    ' ● Mobile app  Northwind   5m',
    ' ▼ 2 more',
    ' ↑↓ pick  q quit',
  ])
})

test('with no room for a row, `top` goes back to 0 and the answer stands alone; with room for one, the row at `top` stands alone, its `▼` given way', () => {
  const view: PanelView = {
    sections: [
      { kind: 'needsYou', rows: ASKS.slice(0, 4), counts: [{ value: 4, need: 'ask' }], isOpen: true },
      { kind: 'working', rows: [MOBILE, LEDGER, { ...MOBILE, session: 'sr-wg0002' }], counts: [{ value: 3 }], isOpen: true },
    ],
    top: 3,
    answer: 'word '.repeat(40),
    board: 'read',
  }
  const words = Array<string>(8).fill('word word word word word').map((line, at) => (at === 0 ? ` ! ${line}` : `   ${line}`))

  expect(layoutOf(view, { width: 30, height: 10 }).top).toBe(0)
  expect(frame(view, 30, 10)).toEqual(['', ...words, ' q quit'])
  expect(frame(view, 30, 11)).toEqual([' ● Onboarding…   Northw…   4m', '', ...words, ' ↑↓ pick  q quit'])
})

test('an answer of all the rows there are leaves the body empty, never running backwards, at 13 rows and more', () => {
  const layout = layoutOf(board({ answer: 'word '.repeat(80) }), { width: 24, height: 16 })

  expect(layout.answer.lines.length).toBe(14)
  expect(layout.body).toEqual({ from: 0, to: 0 })
  expect(layout.placed.length).toBe(0)
})

test('short of room, the menu draws the choices around the pick, scrolled as the layout keeps them: the last picked, the first gone', () => {
  const view = only('needsYou', [SHIFTS], { band: 'sr-ct0001', menu: { ...MENU, at: 6, top: 0 } })

  expect(frame(view, 39, 8)).toEqual([
    ' ● Approve the rota       Contoso  26m',
    '   2 Later today                 17:00',
    '   3 Tonight                     18:00',
    '   4 Tomorrow                    09:00',
    '   5 This weekend            Sat 09:00',
    '   6 Next week               Mon 09:00',
    '   7 Until it moves',
    ' ↑↓ pick  ⏎ snooze  esc cancel',
  ])
  expect(drawn(view, 39, 8, NONE, 6, 7)).toEqual([` ${ESC}[0;7m  ${ESC}[0;2;7m7${ESC}[0;7m ${ESC}[0;1;7mUntil it moves${ESC}[0;7m                   ${ESC}[0m`])
})

test('an expanded row the menu leaves one line draws its folded first line, never `…`, so the menu says whose it is', () => {
  const view = only('needsYou', [SEVERAL], { band: 'sr-nw0010', expanded: 'sr-nw0010', menu: { ...MENU, row: 'sr-nw0010' } })

  expect(frame(view, 39, 8).slice(0, 2)).toEqual([' ● Shift schedules 3      Contoso   4m', '   1 In an hour                  15:00'])
})
