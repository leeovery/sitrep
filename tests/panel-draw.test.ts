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
const SHIFTS = row('sr-ct0001', 'turn', 'Shift schedules', 'Contoso', 'Approve the rota', '26m')
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

const scrolled = (top: number, more: Partial<PanelView> = {}): PanelView => ({
  sections: [
    { kind: 'needsYou', rows: ASKS, counts: [{ value: 6, need: 'ask' }], isOpen: true },
    { kind: 'working', rows: [MOBILE], counts: [{ value: 1 }], isOpen: true },
    { kind: 'snoozed', rows: [ONBOARDING], counts: [{ value: 1 }], isOpen: false },
  ],
  top,
  board: 'read',
  ...more,
})

/** The frame's glyphs, a string a terminal row, its trailing blanks trimmed. */
const frame = (view: PanelView, width: number, height: number, paint = NONE) =>
  text(draw(view, { width, height }, paint)).split('\n').slice(0, -1)

/** Terminal rows `from` up to `to` of the frame, as a terminal draws them at the paint's level. */
const drawn = (view: PanelView, width: number, height: number, paint: Paint, from: number, to: number) =>
  ansi(draw(view, { width, height }, paint).slice(from, to), paint.level).split('\n')

test('the board: the title, each heading with its counts, rule and chevron, each row on two lines, and the key line', () => {
  expect(frame(board(), 39, 20)).toEqual([
    ' sitrep',
    '',
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesign 2             4m',
    '   Northwind · Thread replies, or… +1',
    ' ○ Data import                      1m',
    '   Litware · Allow Bash: psql -f impo…',
    ' ● Shift schedules                 26m',
    '   Contoso · Approve the rota',
    '',
    ' WORKING 2 ───────────────────────── ▿',
    ' ✻ Mobile app                       6m',
    '   Woodgrove · Running npm test',
    ' ◌ Invoice ledger                  15m',
    '   Fabrikam · Waiting on 2 agents',
    '',
    ' SNOOZED 1 ───────────────────────── ▹',
    '',
    '',
    ' ↑↓ pick  s snoozed  q quit',
  ])
})

test('a row at every width: the status line cut, then dropped at 24; past 120 columns the layout stays 120 wide, at the left', () => {
  const one: PanelView = {
    sections: [{ kind: 'needsYou', rows: [HELP_DESK], counts: [{ value: 2, need: 'ask' }], isOpen: true }],
    top: 0,
    board: 'read',
  }
  const rows = (width: number) => frame(one, width, 8).slice(2, 5)

  expect(rows(24)).toEqual([' NEEDS YOU ●2 ─────── ▿', ' ● Help desk red… 2  4m', '   Northwind'])
  expect(rows(39)).toEqual([
    ' NEEDS YOU ●2 ────────────────────── ▿',
    ' ● Help desk redesign 2             4m',
    '   Northwind · Thread replies, or… +1',
  ])
  expect(rows(69)).toEqual([
    ' NEEDS YOU ●2 ──────────────────────────────────────────────────── ▿',
    ' ● Help desk redesign 2                                           4m',
    '   Northwind · Thread replies, or keep them flat? +1',
  ])
  expect(rows(73)).toEqual([
    ' NEEDS YOU ●2 ──────────────────────────────────────────────────────── ▿',
    ' ● Help desk redesign 2                                               4m',
    '   Northwind · Thread replies, or keep them flat? +1',
  ])
  expect(rows(114)).toEqual([
    ' NEEDS YOU ●2 ───────────────────────────────────────────────────────────────────────────────────────────────── ▿',
    ' ● Help desk redesign 2                                                                                        4m',
    '   Northwind · Thread replies, or keep them flat? +1',
  ])
  expect(rows(173)).toEqual([
    ' NEEDS YOU ●2 ─────────────────────────────────────────────────────────────────────────────────────────────────────── ▿',
    ' ● Help desk redesign 2                                                                                              4m',
    '   Northwind · Thread replies, or keep them flat? +1',
  ])
})

test('giving way at 24 columns: the project cut once the status line has gone, a wake losing its clock, then the time going', () => {
  const ledger = row('sr-nw0002', 'turn', 'Invoice ledger', 'Northwind Fabrikam Litware', 'Exported the ledger', '2h')
  const untilMoves = row('sr-ts0002', 'turn', 'Onboarding flow', 'Tailspin', 'Drafted the steps', 'until it moves', {
    isSnoozed: true,
  })
  const atTwo = row('sr-ts0003', 'turn', 'Mobile app', 'Woodgrove', 'Drafted the screens', '14:00', { isSnoozed: true })
  const view: PanelView = {
    sections: [
      {
        kind: 'needsYou',
        rows: [HELP_DESK, ledger],
        counts: [
          { value: 2, need: 'ask' },
          { value: 1, need: 'turn' },
        ],
        isOpen: true,
      },
      { kind: 'snoozed', rows: [ONBOARDING, untilMoves, atTwo], counts: [{ value: 3 }], isOpen: true },
    ],
    top: 0,
    board: 'read',
  }

  expect(frame(view, 24, 16)).toEqual([
    ' sitrep',
    '',
    ' NEEDS YOU ●2 ●1 ──── ▿',
    ' ● Help desk red… 2  4m',
    '   Northwind',
    ' ● Invoice ledger    2h',
    '   Northwind Fabrikam…',
    '',
    ' SNOOZED 3 ────────── ▿',
    ' ● Onboardin…  tomorrow',
    '   Tailspin · Pick the…',
    ' ● Onboarding flow',
    '   Tailspin · Drafted…',
    ' ● Mobile app     14:00',
    '   Woodgrove · Drafted…',
    ' ↑↓ pick  q quit',
  ])
})

test('a cut never splits a wide glyph, and the name is cut before its count, never the count', () => {
  const wide = row('sr-nw0003', 'turn', '漢字漢字漢字漢字漢字漢字', 'Northwind', 'Approve the rota', '4m', { count: 12 })

  expect(frame(only('needsYou', [wide]), 24, 8).slice(3, 5)).toEqual([' ● 漢字漢字漢字… 12  4m', '   Northwind · Approve…'])
})

test('scrolled from `top`, the rows above said by `▲ N more` under their section heading, kept at the top, and those below by `▼ N more`', () => {
  expect(frame(scrolled(0), 39, 12)).toEqual([
    ' sitrep',
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ● Help desk redesign               1m',
    '   Northwind · Approve the rota',
    ' ● Shift schedules                  2m',
    '   Northwind · Approve the rota',
    ' ● Invoice ledger                   3m',
    '   Northwind · Approve the rota',
    ' ● Onboarding flow                  4m',
    '   Northwind · Approve the rota',
    ' ▼ 3 more',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(frame(scrolled(3), 39, 12)).toEqual([
    ' sitrep',
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ▲ 3 more',
    ' ● Onboarding flow                  4m',
    '   Northwind · Approve the rota',
    ' ● Mobile app                       5m',
    '   Northwind · Approve the rota',
    ' ● Data import                      6m',
    '   Northwind · Approve the rota',
    ' WORKING 1 ───────────────────────── ▿',
    ' ▼ 1 more',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(frame(scrolled(2), 24, 8)).toEqual([
    ' sitrep',
    ' NEEDS YOU ●6 ─────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger    3m',
    '   Northwind · Approve…',
    ' ▼ 4 more',
    '',
    ' ↑↓ pick  q quit',
  ])
})

test('below 15 rows, short of room, the blank row under the title goes first, then the blank rows between sections, then the body scrolls', () => {
  const two: PanelView = {
    sections: [
      { kind: 'needsYou', rows: [SHIFTS], counts: [{ value: 1, need: 'turn' }], isOpen: true },
      { kind: 'working', rows: [MOBILE], counts: [{ value: 1 }], isOpen: true },
    ],
    top: 0,
    board: 'read',
  }

  expect(frame(two, 39, 10)).toEqual([
    ' sitrep',
    '',
    ' NEEDS YOU ●1 ────────────────────── ▿',
    ' ● Shift schedules                 26m',
    '   Contoso · Approve the rota',
    '',
    ' WORKING 1 ───────────────────────── ▿',
    ' ✻ Mobile app                       6m',
    '   Woodgrove · Running npm test',
    ' ↑↓ pick  q quit',
  ])
  expect(frame(board(), 39, 14)).toEqual([
    ' sitrep',
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesign 2             4m',
    '   Northwind · Thread replies, or… +1',
    ' ○ Data import                      1m',
    '   Litware · Allow Bash: psql -f impo…',
    ' ● Shift schedules                 26m',
    '   Contoso · Approve the rota',
    ' WORKING 2 ───────────────────────── ▿',
    ' ✻ Mobile app                       6m',
    '   Woodgrove · Running npm test',
    ' ▼ 1 more',
    '',
    ' ↑↓ pick  s snoozed  q quit',
  ])
})

test('a quiet board reads `All clear` and what it means, wrapped at 24 columns, centred a little above the middle', () => {
  expect(frame(only('needsYou', []), 39, 14)).toEqual([
    ' sitrep',
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
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 24, 12).slice(2, 7)).toEqual([
    '       All clear',
    '',
    '   Nothing needs you,',
    '     and nothing is',
    '        running.',
  ])
})

test("a pick's answer sits above the key line, `!` then its words, wrapped at W−4 and hung; its rows come from the body", () => {
  const answer = "Shift schedules can't be opened here: its terminal has no tmux or zmx."

  expect(frame(board({ band: 'sr-ct0001', answer }), 39, 16)).toEqual([
    ' sitrep',
    '',
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesign 2             4m',
    '   Northwind · Thread replies, or… +1',
    ' ○ Data import                      1m',
    '   Litware · Allow Bash: psql -f impo…',
    ' ● Shift schedules                 26m',
    '   Contoso · Approve the rota',
    ' ▼ 2 more',
    '',
    '',
    " ! Shift schedules can't be opened",
    '   here: its terminal has no tmux or',
    '   zmx.',
    ' ↑↓ move  ⏎ open  s snoozed  q quit',
  ])
  expect(drawn(board({ answer }), 39, 16, NORDFOX, 12, 13)).toEqual([
    ` ${ESC}[0;1m!${ESC}[0m Shift schedules can't be opened`,
  ])
})

test('the key line names the keys that work now, `s` only while Snoozed holds rows, dropping whole hints from the right, `q quit` last', () => {
  const keys = (view: PanelView, width: number) => frame(view, width, 10).at(-1)

  expect(keys(board(), 39)).toBe(' ↑↓ pick  s snoozed  q quit')
  expect(keys(board({ band: 'sr-ct0001' }), 39)).toBe(' ↑↓ move  ⏎ open  s snoozed  q quit')
  expect(keys(board({ band: 'sr-ct0001' }), 24)).toBe(' ↑↓ move  q quit')
  expect(keys(only('working', [MOBILE]), 39)).toBe(' ↑↓ pick  q quit')
  expect(keys(only('working', []), 39)).toBe(' q quit')
  expect(drawn(only('working', [MOBILE]), 39, 10, NORDFOX, 9, 10)).toEqual([
    ` ${ESC}[0;1m↑↓${ESC}[0;38;2;122;130;171m pick${ESC}[0m  ${ESC}[0;1mq${ESC}[0;38;2;122;130;171m quit${ESC}[0m`,
  ])
})

test('the band lies over both lines of the chosen row, from column 1 to W−2: a ground in colour, reverse video without', () => {
  expect(drawn(board({ band: 'sr-ct0001' }), 39, 20, NORDFOX, 7, 9)).toEqual([
    ` ${ESC}[0;38;2;122;162;247;48;2;62;74;91m●${ESC}[0;48;2;62;74;91m Shift schedules                 ${ESC}[0;38;2;122;130;171;48;2;62;74;91m26m${ESC}[0m`,
    ` ${ESC}[0;48;2;62;74;91m  ${ESC}[0;38;2;122;130;171;48;2;62;74;91mContoso · ${ESC}[0;38;2;169;177;214;48;2;62;74;91mApprove the rota${ESC}[0;48;2;62;74;91m         ${ESC}[0m`,
  ])
  expect(drawn(board({ band: 'sr-ct0001' }), 39, 20, NONE, 7, 9)).toEqual([
    ` ${ESC}[0;7m● Shift schedules                 ${ESC}[0;2;7m26m${ESC}[0m`,
    ` ${ESC}[0;7m  ${ESC}[0;2;7mContoso · ${ESC}[0;7mApprove the rota         ${ESC}[0m`,
  ])
})

test("the band names a row by its key: a session's Snoozed row is its own", () => {
  const view = board({ isOpen: true, band: 'snoozed:sr-ts0001' })
  const snoozed = drawn(view, 39, 22, NONE, 17, 18)

  expect(snoozed[0]?.startsWith(` ${ESC}[0;2;7m●`)).toBe(true)
  expect(drawn(board({ isOpen: true, band: 'sr-ts0001' }), 39, 22, NONE, 17, 18)[0]).not.toContain(';7m●')
})

test("an away row's words dim as one, its mark kept full and hollow; without colour a bold name stays bold, never faint", () => {
  expect(drawn(board(), 39, 20, NORDFOX, 5, 7)).toEqual([
    ` ${ESC}[0;38;2;215;119;87m○${ESC}[0m ${ESC}[0;1;38;2;143;146;151mData import${ESC}[0m                      ${ESC}[0;38;2;92;100;129m1m${ESC}[0m`,
    `   ${ESC}[0;38;2;92;100;129mLitware · ${ESC}[0;38;2;121;128;156mAllow Bash: psql -f impo…${ESC}[0m`,
  ])
  expect(drawn(board(), 39, 20, NONE, 5, 7)).toEqual([
    ` ○ ${ESC}[0;1mData import${ESC}[0m                      ${ESC}[0;2m1m${ESC}[0m`,
    `   ${ESC}[0;2mLitware · Allow Bash: psql -f impo…${ESC}[0m`,
  ])
})

test('a Snoozed row dims its mark alone, filled even away; its name grey, an ask bold, and its line two as any row', () => {
  const away = row('sr-wg0002', 'turn', 'Mobile app', 'Woodgrove', 'Drafted the screens', 'next week', {
    isSnoozed: true,
    isAway: true,
  })

  expect(drawn(only('snoozed', [ONBOARDING, away]), 39, 10, NORDFOX, 3, 7)).toEqual([
    ` ${ESC}[0;38;2;149;93;78m●${ESC}[0m ${ESC}[0;1;38;2;122;130;171mOnboarding flow${ESC}[0m      ${ESC}[0;38;2;122;130;171mtomorrow 09:00${ESC}[0m`,
    `   ${ESC}[0;38;2;122;130;171mTailspin · ${ESC}[0;38;2;169;177;214mPick the onboarding ste…${ESC}[0m`,
    ` ${ESC}[0;38;2;92;119;176m●${ESC}[0m ${ESC}[0;38;2;122;130;171mMobile app${ESC}[0m                ${ESC}[0;38;2;122;130;171mnext week${ESC}[0m`,
    `   ${ESC}[0;38;2;122;130;171mWoodgrove · ${ESC}[0;38;2;169;177;214mDrafted the screens${ESC}[0m`,
  ])
})

test("a new ask's mark is `◉`, bold orange, its row washed at 24-bit where the mix can be made; the band wins over the wash", () => {
  const arriving = row('sr-ct0002', 'ask', 'Data import', 'Contoso', 'Approve the rota', 'now', { isNew: true })
  const view = (band?: string): PanelView => ({ ...only('needsYou', [arriving]), ...(band === undefined ? {} : { band }) })
  const wash = `48;2;83;67;69`

  expect(drawn(view(), 39, 8, NORDFOX, 3, 4)).toEqual([
    ` ${ESC}[0;1;38;2;215;119;87;${wash}m◉${ESC}[0;${wash}m ${ESC}[0;1;${wash}mData import${ESC}[0;${wash}m                     ${ESC}[0;38;2;122;130;171;${wash}mnow${ESC}[0m`,
  ])
  expect(drawn(view(), 39, 8, { level: 'truecolor' }, 3, 4)).toEqual([
    ` ${ESC}[0;1;38;2;215;119;87m◉${ESC}[0m ${ESC}[0;1mData import${ESC}[0m                     ${ESC}[0;38;2;122;130;171mnow${ESC}[0m`,
  ])
  expect(drawn(view(), 39, 8, NONE, 3, 4)).toEqual([
    ` ${ESC}[0;1m◉${ESC}[0m ${ESC}[0;1mData import${ESC}[0m                     ${ESC}[0;2mnow${ESC}[0m`,
  ])
  expect(drawn(view('sr-ct0002'), 39, 8, NORDFOX, 3, 4)[0]).toContain('48;2;62;74;91m')
  expect(drawn(view('sr-ct0002'), 39, 8, NORDFOX, 3, 4)[0]).not.toContain(wash)
})

test('the headings: grey words, the needs-you counts in bold orange and blue, the rule and chevron faint', () => {
  expect(drawn(board(), 39, 20, NORDFOX, 2, 3)).toEqual([
    ` ${ESC}[0;38;2;122;130;171mNEEDS YOU${ESC}[0m ${ESC}[0;38;2;215;119;87m●${ESC}[0;1;38;2;215;119;87m3${ESC}[0m ${ESC}[0;38;2;122;162;247m●${ESC}[0;1;38;2;122;162;247m1${ESC}[0m ${ESC}[0;38;2;86;95;137m───────────────────${ESC}[0m ${ESC}[0;38;2;86;95;137m▿${ESC}[0m`,
  ])
  expect(drawn(board(), 39, 20, NONE, 10, 11)).toEqual([
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

  expect(frame(many, 24, 8)[2]).toBe(' NEEDS YOU ●123 ●45   ▿')
})

test("a stale board says when it was read at the title's right; before any board, the body says it's looking, or why it can't read one", () => {
  const empty = { sections: [], top: 0 }

  expect(frame({ ...empty, board: 'stale', asOf: '12:04' }, 39, 10)[0]).toBe(' sitrep                    as of 12:04')
  expect(frame({ ...empty, board: 'read', asOf: '12:04' }, 39, 10)[0]).toBe(' sitrep')
  expect(frame({ ...empty, board: 'looking' }, 39, 12)).toEqual([
    ' sitrep',
    '',
    '',
    '',
    '         Looking for sessions…',
    '',
    '',
    '',
    '',
    '',
    '',
    ' q quit',
  ])
  expect(
    frame({ ...empty, board: 'looking', reason: "EACCES: permission denied, scandir '/Users/me/.local/state'" }, 39, 14).slice(
      4,
      8,
    ),
  ).toEqual([
    "         Can't read the board",
    '',
    '  EACCES: permission denied, scandir',
    "       '/Users/me/.local/state'",
  ])
})

test('below 24 columns or 8 rows only `Too small`, at the margin, cut to the width', () => {
  const tooSmall = (width: number, height: number) => frame(board(), width, height)

  expect(tooSmall(23, 10)).toEqual([' Too small', ...Array<string>(9).fill('')])
  expect(tooSmall(24, 7)).toEqual([' Too small', ...Array<string>(6).fill('')])
  expect(tooSmall(8, 8)[0]).toBe(' Too s…')
  expect(tooSmall(24, 8)[0]).toBe(' sitrep')
})

test('the lines as text: each its glyphs, trimmed, a newline after each; as escapes: a reset where a line ends styled, a newline between', () => {
  const lines = draw(only('working', [MOBILE]), { width: 24, height: 8 }, NONE)

  expect(text(lines)).toBe(
    [' sitrep', '', ' WORKING 1 ────────── ▿', ' ✻ Mobile app        6m', '   Woodgrove · Running…', '', '', ' ↑↓ pick  q quit', ''].join(
      '\n',
    ),
  )
  expect(ansi(lines, 'none').split('\n')).toEqual([
    ` ${ESC}[0;1msitrep${ESC}[0m`,
    '',
    ` WORKING ${ESC}[0;2m1${ESC}[0m ${ESC}[0;2m──────────${ESC}[0m ${ESC}[0;2m▿${ESC}[0m`,
    ` ✻ Mobile app        ${ESC}[0;2m6m${ESC}[0m`,
    `   ${ESC}[0;2mWoodgrove · ${ESC}[0mRunning…`,
    '',
    '',
    ` ${ESC}[0;1m↑↓${ESC}[0;2m pick${ESC}[0m  ${ESC}[0;1mq${ESC}[0;2m quit${ESC}[0m`,
  ])
})

const PICKED = "Shift schedules can't be opened here: its terminal has no tmux or zmx."

const NO_FOLDER =
  "Shift schedules's last window did not say which folder it ran in, as a window on an older sitrep does not, so sitrep has nothing to put for {dir}."

test('every element at every width: the stale title, the pinned heading and its counts, `▲`, `▼`, the band, the answer and the key line', () => {
  const view = scrolled(2, { band: 'sr-nw0003', answer: PICKED, board: 'stale', asOf: '12:04' })

  expect(frame(view, 24, 12)).toEqual([
    ' sitrep     as of 12:04',
    ' NEEDS YOU ●6 ─────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger    3m',
    '   Northwind · Approve…',
    ' ▼ 4 more',
    '',
    ' ! Shift schedules',
    "   can't be opened",
    '   here: its terminal',
    '   has no tmux or zmx.',
    ' ↑↓ move  q quit',
  ])
  expect(frame(view, 39, 12)).toEqual([
    ' sitrep                    as of 12:04',
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                   3m',
    '   Northwind · Approve the rota',
    ' ▼ 4 more',
    '',
    '',
    " ! Shift schedules can't be opened",
    '   here: its terminal has no tmux or',
    '   zmx.',
    ' ↑↓ move  ⏎ open  s snoozed  q quit',
  ])
  expect(frame(view, 69, 12)).toEqual([
    ' sitrep                                                  as of 12:04',
    ' NEEDS YOU ●6 ──────────────────────────────────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                                                 3m',
    '   Northwind · Approve the rota',
    ' ● Onboarding flow                                                4m',
    '   Northwind · Approve the rota',
    ' ▼ 3 more',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or",
    '   zmx.',
    ' ↑↓ move  ⏎ open  s snoozed  q quit',
  ])
  expect(frame(view, 73, 12)).toEqual([
    ' sitrep                                                      as of 12:04',
    ' NEEDS YOU ●6 ──────────────────────────────────────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                                                     3m',
    '   Northwind · Approve the rota',
    ' ● Onboarding flow                                                    4m',
    '   Northwind · Approve the rota',
    ' ▼ 3 more',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or",
    '   zmx.',
    ' ↑↓ move  ⏎ open  s snoozed  q quit',
  ])
  expect(frame(view, 114, 12)).toEqual([
    ' sitrep                                                                                               as of 12:04',
    ' NEEDS YOU ●6 ───────────────────────────────────────────────────────────────────────────────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                                                                                              3m',
    '   Northwind · Approve the rota',
    ' ● Onboarding flow                                                                                             4m',
    '   Northwind · Approve the rota',
    ' ▼ 3 more',
    '',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or zmx.",
    ' ↑↓ move  ⏎ open  s snoozed  q quit',
  ])
  expect(frame(view, 173, 12)).toEqual([
    ' sitrep                                                                                                     as of 12:04',
    ' NEEDS YOU ●6 ─────────────────────────────────────────────────────────────────────────────────────────────────────── ▿',
    ' ▲ 2 more',
    ' ● Invoice ledger                                                                                                    3m',
    '   Northwind · Approve the rota',
    ' ● Onboarding flow                                                                                                   4m',
    '   Northwind · Approve the rota',
    ' ▼ 3 more',
    '',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or zmx.",
    ' ↑↓ move  ⏎ open  s snoozed  q quit',
  ])
})

test("the quiet board at every width, centred in the body's place", () => {
  expect(frame(only('needsYou', []), 24, 10)).toEqual([
    ' sitrep',
    '       All clear',
    '',
    '   Nothing needs you,',
    '     and nothing is',
    '        running.',
    '',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 39, 10)).toEqual([
    ' sitrep',
    '',
    '               All clear',
    '',
    '        Nothing needs you, and',
    '          nothing is running.',
    '',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 69, 10)).toEqual([
    ' sitrep',
    '',
    '                              All clear',
    '',
    '                       Nothing needs you, and',
    '                         nothing is running.',
    '',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 73, 10)).toEqual([
    ' sitrep',
    '',
    '                                All clear',
    '',
    '                         Nothing needs you, and',
    '                           nothing is running.',
    '',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 114, 10)).toEqual([
    ' sitrep',
    '',
    '                                                    All clear',
    '',
    '                                              Nothing needs you, and',
    '                                               nothing is running.',
    '',
    '',
    '',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 173, 10)).toEqual([
    ' sitrep',
    '',
    '                                                       All clear',
    '',
    '                                                 Nothing needs you, and',
    '                                                  nothing is running.',
    '',
    '',
    '',
    ' q quit',
  ])
})

test('scrolled with the blank rows between sections kept, at 15 rows and more', () => {
  expect(frame(scrolled(3), 39, 16)).toEqual([
    ' sitrep',
    '',
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ▲ 3 more',
    ' ● Onboarding flow                  4m',
    '   Northwind · Approve the rota',
    ' ● Mobile app                       5m',
    '   Northwind · Approve the rota',
    ' ● Data import                      6m',
    '   Northwind · Approve the rota',
    '',
    ' WORKING 1 ───────────────────────── ▿',
    ' ✻ Mobile app                       6m',
    '   Woodgrove · Running npm test',
    '',
    ' ↑↓ pick  s snoozed  q quit',
  ])
})

test('`top` past the end goes no further than the greatest that still fills the body', () => {
  expect(layoutOf(scrolled(99), { width: 39, height: 12 }).lastTop).toBe(4)
  expect(frame(scrolled(99), 39, 12)).toEqual(frame(scrolled(4), 39, 12))
  expect(frame(scrolled(99), 39, 12)).toEqual([
    ' sitrep',
    ' NEEDS YOU ●6 ────────────────────── ▿',
    ' ▲ 4 more',
    ' ● Mobile app                       5m',
    '   Northwind · Approve the rota',
    ' ● Data import                      6m',
    '   Northwind · Approve the rota',
    ' WORKING 1 ───────────────────────── ▿',
    ' ✻ Mobile app                       6m',
    '   Woodgrove · Running npm test',
    ' SNOOZED 1 ───────────────────────── ▹',
    ' ↑↓ pick  s snoozed  q quit',
  ])
  expect(layoutOf(scrolled(99), { width: 39, height: 40 }).top).toBe(0)
})

test("the layout gives the body's rows, where each row in view stands by its key, and the greatest `top`", () => {
  const layout = layoutOf(scrolled(3, { band: 'sr-nw0003', answer: PICKED }), { width: 39, height: 16 })

  expect(layout.body).toEqual({ from: 2, to: 11 })
  expect(layout.words).toEqual({ from: 1, to: 11 })
  expect(layout.answer).toEqual({
    from: 12,
    lines: ["Shift schedules can't be opened", 'here: its terminal has no tmux or', 'zmx.'],
  })
  expect(layout.rows).toEqual([
    { key: 'sr-nw0003', y: 4 },
    { key: 'sr-nw0004', y: 6 },
    { key: 'sr-nw0005', y: 8 },
  ])
  expect(layout.lastTop).toBe(6)
})

test('an answer taller than the body keeps the title and the key line, takes the rows between, less its blank row, and cuts its last line', () => {
  expect(frame(board({ band: 'sr-ct0001', answer: NO_FOLDER }), 24, 8)).toEqual([
    ' sitrep',
    '',
    " ! Shift schedules's",
    '   last window did not',
    '   say which folder it',
    '   ran in, as a window',
    '   on an older sitrep…',
    ' ⏎ open  q quit',
  ])
  expect(frame(board({ band: 'sr-ct0001', answer: NO_FOLDER }), 24, 14)).toEqual([
    ' sitrep',
    ' ● Help desk red… 2  4m',
    '   Northwind',
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
  const reason = "EACCES: permission denied, open '/Users/me/.local/state/sitrep/sessions/sr-nw0001.json'"

  expect(frame(only('needsYou', [], { answer: PICKED }), 24, 8)).toEqual([
    ' sitrep',
    '       All clear',
    '',
    ' ! Shift schedules',
    "   can't be opened",
    '   here: its terminal',
    '   has no tmux or zmx.',
    ' q quit',
  ])
  expect(frame(only('needsYou', [], { answer: PICKED }), 39, 10)).toEqual([
    ' sitrep',
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
    ' sitrep',
    "  Can't read the board",
    '',
    '   EACCES: permission',
    '      denied, open',
    "  '/Users/me/.local/st",
    '  ate/sitrep/sessions…',
    ' q quit',
  ])
  expect(frame(only('needsYou', []), 24, 8)).toEqual([
    ' sitrep',
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
  expect(drawn(board(), 39, 20, NONE, 2, 3)).toEqual([
    ` NEEDS YOU ●${ESC}[0;1m3${ESC}[0m ●1 ${ESC}[0;2m───────────────────${ESC}[0m ${ESC}[0;2m▿${ESC}[0m`,
  ])
})

test("at 256 colours: the palette's nearest, the dims mixed, the band a ground, and no wash", () => {
  const arriving: PanelRow = { ...DATA_IMPORT, session: 'sr-lw0002', isAway: false, isNew: true }
  const view = board({ band: 'sr-ct0001' })
  const [needsYou, ...rest] = view.sections

  expect(
    drawn({ ...view, sections: [{ ...needsYou!, rows: [arriving, ...needsYou!.rows] }, ...rest] }, 39, 20, { ...NORDFOX, level: '256' }, 0, 20),
  ).toEqual([
    ` ${ESC}[0;1msitrep${ESC}[0m`,
    '',
    ` ${ESC}[0;38;5;103mNEEDS YOU${ESC}[0m ${ESC}[0;38;5;173m●${ESC}[0;1;38;5;173m3${ESC}[0m ${ESC}[0;38;5;111m●${ESC}[0;1;38;5;111m1${ESC}[0m ${ESC}[0;38;5;60m───────────────────${ESC}[0m ${ESC}[0;38;5;60m▿${ESC}[0m`,
    ` ${ESC}[0;1;38;5;173m◉${ESC}[0m ${ESC}[0;1mData import${ESC}[0m                      ${ESC}[0;38;5;103m1m${ESC}[0m`,
    `   ${ESC}[0;38;5;103mLitware · ${ESC}[0;38;5;146mAllow Bash: psql -f impo…${ESC}[0m`,
    ` ${ESC}[0;38;5;173m●${ESC}[0m ${ESC}[0;1mHelp desk redesign${ESC}[0;38;5;103m 2${ESC}[0m             ${ESC}[0;38;5;103m4m${ESC}[0m`,
    `   ${ESC}[0;38;5;103mNorthwind · ${ESC}[0;38;5;146mThread replies, or…${ESC}[0;38;5;103m +1${ESC}[0m`,
    ` ${ESC}[0;38;5;173m○${ESC}[0m ${ESC}[0;1;38;5;246mData import${ESC}[0m                      ${ESC}[0;38;5;60m1m${ESC}[0m`,
    `   ${ESC}[0;38;5;60mLitware · ${ESC}[0;38;5;103mAllow Bash: psql -f impo…${ESC}[0m`,
    ` ${ESC}[0;38;5;111;48;5;239m●${ESC}[0;48;5;239m Shift schedules                 ${ESC}[0;38;5;103;48;5;239m26m${ESC}[0m`,
    ` ${ESC}[0;48;5;239m  ${ESC}[0;38;5;103;48;5;239mContoso · ${ESC}[0;38;5;146;48;5;239mApprove the rota${ESC}[0;48;5;239m         ${ESC}[0m`,
    '',
    ` ${ESC}[0;38;5;103mWORKING${ESC}[0m ${ESC}[0;38;5;103m2${ESC}[0m ${ESC}[0;38;5;60m─────────────────────────${ESC}[0m ${ESC}[0;38;5;60m▿${ESC}[0m`,
    ` ${ESC}[0;38;5;146m✻${ESC}[0m ${ESC}[0;38;5;146mMobile app${ESC}[0m                       ${ESC}[0;38;5;103m6m${ESC}[0m`,
    `   ${ESC}[0;38;5;103mWoodgrove · ${ESC}[0;38;5;146mRunning npm test${ESC}[0m`,
    ` ${ESC}[0;38;5;103m◌${ESC}[0m ${ESC}[0;38;5;146mInvoice ledger${ESC}[0m                  ${ESC}[0;38;5;103m15m${ESC}[0m`,
    `   ${ESC}[0;38;5;103mFabrikam · ${ESC}[0;38;5;146mWaiting on 2 agents${ESC}[0m`,
    '',
    ` ${ESC}[0;38;5;103mSNOOZED${ESC}[0m ${ESC}[0;38;5;103m1${ESC}[0m ${ESC}[0;38;5;60m─────────────────────────${ESC}[0m ${ESC}[0;38;5;60m▹${ESC}[0m`,
    ` ${ESC}[0;1m↑↓${ESC}[0;38;5;103m move${ESC}[0m  ${ESC}[0;1m⏎${ESC}[0;38;5;103m open${ESC}[0m  ${ESC}[0;1ms${ESC}[0;38;5;103m snoozed${ESC}[0m  ${ESC}[0;1mq${ESC}[0;38;5;103m quit${ESC}[0m`,
  ])
})

test("at 16 colours: the terminal's own, the rule faint, the dims faint, the band reverse video", () => {
  expect(drawn(board({ band: 'sr-ct0001' }), 39, 20, { ...NORDFOX, level: '16' }, 0, 20)).toEqual([
    ` ${ESC}[0;1msitrep${ESC}[0m`,
    '',
    ` ${ESC}[0;90mNEEDS YOU${ESC}[0m ${ESC}[0;33m●${ESC}[0;1;33m3${ESC}[0m ${ESC}[0;34m●${ESC}[0;1;34m1${ESC}[0m ${ESC}[0;2;90m───────────────────${ESC}[0m ${ESC}[0;2;90m▿${ESC}[0m`,
    ` ${ESC}[0;33m●${ESC}[0m ${ESC}[0;1mHelp desk redesign${ESC}[0;90m 2${ESC}[0m             ${ESC}[0;90m4m${ESC}[0m`,
    `   ${ESC}[0;90mNorthwind · ${ESC}[0mThread replies, or…${ESC}[0;90m +1${ESC}[0m`,
    ` ${ESC}[0;33m○${ESC}[0m ${ESC}[0;1mData import${ESC}[0m                      ${ESC}[0;2;90m1m${ESC}[0m`,
    `   ${ESC}[0;2;90mLitware · ${ESC}[0;2mAllow Bash: psql -f impo…${ESC}[0m`,
    ` ${ESC}[0;7;34m●${ESC}[0;7m Shift schedules                 ${ESC}[0;7;90m26m${ESC}[0m`,
    ` ${ESC}[0;7m  ${ESC}[0;7;90mContoso · ${ESC}[0;7mApprove the rota         ${ESC}[0m`,
    '',
    ` ${ESC}[0;90mWORKING${ESC}[0m ${ESC}[0;90m2${ESC}[0m ${ESC}[0;2;90m─────────────────────────${ESC}[0m ${ESC}[0;2;90m▿${ESC}[0m`,
    ` ✻ Mobile app                       ${ESC}[0;90m6m${ESC}[0m`,
    `   ${ESC}[0;90mWoodgrove · ${ESC}[0mRunning npm test`,
    ` ${ESC}[0;90m◌${ESC}[0m Invoice ledger                  ${ESC}[0;90m15m${ESC}[0m`,
    `   ${ESC}[0;90mFabrikam · ${ESC}[0mWaiting on 2 agents`,
    '',
    ` ${ESC}[0;90mSNOOZED${ESC}[0m ${ESC}[0;90m1${ESC}[0m ${ESC}[0;2;90m─────────────────────────${ESC}[0m ${ESC}[0;2;90m▹${ESC}[0m`,
    '',
    '',
    ` ${ESC}[0;1m↑↓${ESC}[0;90m move${ESC}[0m  ${ESC}[0;1m⏎${ESC}[0;90m open${ESC}[0m  ${ESC}[0;1ms${ESC}[0;90m snoozed${ESC}[0m  ${ESC}[0;1mq${ESC}[0;90m quit${ESC}[0m`,
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

test('with 4 body rows a scrolled body shows `▲` alone over its row, `▼` under it; with 3, the row and `▼` alone', () => {
  expect(frame({ ...SEVEN, top: 1, answer: 'Short.' }, 33, 8)).toEqual([
    ' sitrep',
    ' ▲ 1 more',
    ' ● Shift schedules            2m',
    '   Northwind · Approve the rota',
    ' ▼ 5 more',
    '',
    ' ! Short.',
    ' ↑↓ pick  q quit',
  ])
  expect(layoutOf({ ...SEVEN, top: 1, answer: 'Short.' }, { width: 33, height: 8 }).rows).toEqual([
    { key: 'sr-nw0001', y: 2 },
  ])
  expect(frame({ ...SEVEN, top: 1, answer: 'Short. And a second line of words, to wrap.' }, 33, 8)).toEqual([
    ' sitrep',
    ' ● Shift schedules            2m',
    '   Northwind · Approve the rota',
    ' ▼ 5 more',
    '',
    ' ! Short. And a second line of',
    '   words, to wrap.',
    ' ↑↓ pick  q quit',
  ])
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

  expect(frame(view, 24, 16)).toEqual([
    ' sitrep',
    '',
    ' ▲ 4 more',
    ' ✻ Invoice ledger    2m',
    '   Woodgrove · Running…',
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
  expect(layoutOf(view, { width: 24, height: 16 }).rows).toEqual([
    { key: 'sr-wg0101', y: 3 },
  ])
})

test('every row can be brought into view, whole, at every room the body has from 2 rows up', () => {
  const view = scrolled(0, { sections: scrolled(0).sections.map(section => ({ ...section, isOpen: true })) })
  const keys = view.sections.flatMap(section => section.rows.map(rowKey))
  const rooms = new Set<number>()

  for (let height = 8; height <= 22; height++) {
    for (let words = 0; words <= 40; words += 4) {
      const answered = { ...view, ...(words === 0 ? {} : { answer: 'word '.repeat(words) }) }
      const size = { width: 30, height }
      const room = layoutOf(answered, size).body.to - layoutOf(answered, size).body.from

      rooms.add(room)

      if (room >= 2) {
        for (const key of keys) {
          const top = topFor(answered, size, key)
          const shown = layoutOf({ ...answered, top: top ?? 0 }, size).rows.map(each => each.key)

          expect(shown).toContain(key)
        }
      }
    }
  }

  expect([2, 3, 4, 5, 6, 7, 8, 9, 10].every(room => rooms.has(room))).toBe(true)
})

test('`topFor` gives the `top` nearest the view\'s that shows the row whole: the band at the start, the middle and the end, and under an answer', () => {
  const size = { width: 39, height: 12 }

  expect(topFor(scrolled(3), size, 'sr-nw0000')).toBe(0)
  expect(topFor(scrolled(0), size, 'sr-nw0003')).toBe(0)
  expect(topFor(scrolled(0), size, 'sr-nw0005')).toBe(3)
  expect(topFor(scrolled(4), size, 'sr-nw0002')).toBe(2)
  expect(topFor(scrolled(0), size, 'sr-wg0001')).toBe(4)
  expect(topFor(scrolled(0, { answer: PICKED }), size, 'sr-nw0002')).toBe(2)
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

  expect(frame(five, 30, 15)).toEqual([
    ' sitrep',
    '',
    ' NEEDS YOU ●5 ───────────── ▿',
    ' ▲ 1 more',
    ' ● Shift schedules         2m',
    '   Northwind · Approve the r…',
    ' ● Invoice ledger          3m',
    '   Northwind · Approve the r…',
    ' ● Onboarding flow         4m',
    '   Northwind · Approve the r…',
    ' ● Mobile app              5m',
    '   Northwind · Approve the r…',
    ' ▼ 1 more',
    '',
    ' ↑↓ pick  q quit',
  ])
})

test('`↑↓` is offered only while a row is in view: not over a folded Snoozed alone, nor while an answer fills the body', () => {
  const folded: PanelView = { ...only('snoozed', [ONBOARDING]), sections: [{ ...only('snoozed', [ONBOARDING]).sections[0]!, isOpen: false }] }

  expect(frame(folded, 39, 10).at(-1)).toBe(' s snoozed  q quit')
  expect(frame(only('working', [MOBILE], { answer: NO_FOLDER }), 24, 8).at(-1)).toBe(' q quit')
})

test('a squeezed quiet board cuts its words at 24 columns, as it wraps them', () => {
  expect(frame(only('needsYou', [], { answer: PICKED }), 69, 8)).toEqual([
    ' sitrep',
    '                              All clear',
    '',
    '                       Nothing needs you, and…',
    '',
    " ! Shift schedules can't be opened here: its terminal has no tmux or",
    '   zmx.',
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

  expect(frame(many, 24, 8)[2]).toBe(' NEEDS YOU ●12345 ●567')
})

test('a wide glyph or an emoji at the right edge is cut whole, nothing drawn past W−2', () => {
  const wide = row('sr-nw0011', 'turn', 'Data 漢字漢字漢字 import 👍👍', 'Northwind', '漢字漢字漢字漢字漢字漢字漢字', '4m')
  const emoji = row('sr-nw0012', 'ask', '👍 Help desk redesign 👍👍', 'Contoso', 'Approve 👍👍👍👍👍👍', '1m')
  const lines = frame(only('needsYou', [wide, emoji]), 26, 10)

  expect(lines).toEqual([
    ' sitrep',
    '',
    ' NEEDS YOU 2 ────────── ▿',
    ' ● Data 漢字漢字漢字…  4m',
    '   Northwind · 漢字漢字…',
    ' ● 👍 Help desk rede…  1m',
    '   Contoso · Approve 👍…',
    '',
    '',
    ' ↑↓ pick  q quit',
  ])
  expect(lines.every(line => widthOf(line) <= 25)).toBe(true)
})
