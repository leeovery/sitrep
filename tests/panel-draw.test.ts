import { expect, test } from './kit'
import { ansi, draw, text } from '../cli/panel/draw'
import { rgbOf, type Paint } from '../cli/panel/paint'
import type { PanelRow, PanelView } from '../cli/panel/view'

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
    '   Northwind · Thread replies, or … +1',
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
  const rows = (width: number) => frame(one, width, 8).slice(1, 4)

  expect(rows(24)).toEqual([' NEEDS YOU ●2 ─────── ▿', ' ● Help desk red… 2  4m', '   Northwind'])
  expect(rows(39)).toEqual([
    ' NEEDS YOU ●2 ────────────────────── ▿',
    ' ● Help desk redesign 2             4m',
    '   Northwind · Thread replies, or … +1',
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
    '   Northwind Fabrikam …',
    '',
    ' SNOOZED 3 ────────── ▿',
    ' ● Onboardin…  tomorrow',
    '   Tailspin · Pick the…',
    ' ● Onboarding flow',
    '   Tailspin · Drafted …',
    ' ● Mobile app     14:00',
    '   Woodgrove · Drafted…',
    ' ↑↓ pick  s snoozed',
  ])
})

test('a cut never splits a wide glyph, and the name is cut before its count, never the count', () => {
  const wide = row('sr-nw0003', 'turn', '漢字漢字漢字漢字漢字漢字', 'Northwind', 'Approve the rota', '4m', { count: 12 })

  expect(frame(only('needsYou', [wide]), 24, 8).slice(2, 4)).toEqual([' ● 漢字漢字漢字… 12  4m', '   Northwind · Approve…'])
})

test('scrolled from `top`, the rows above said by `▲ N more` under their section heading, kept at the top, and those below by `▼ N more`', () => {
  const names = ['Help desk redesign', 'Shift schedules', 'Invoice ledger', 'Onboarding flow', 'Mobile app', 'Data import']
  const asks = names.map((name, at) =>
    row(`sr-nw000${at}`, 'ask', name, 'Northwind', 'Approve the rota', `${at + 1}m`),
  )
  const scrolled = (top: number): PanelView => ({
    sections: [
      { kind: 'needsYou', rows: asks, counts: [{ value: 6, need: 'ask' }], isOpen: true },
      { kind: 'working', rows: [MOBILE], counts: [{ value: 1 }], isOpen: true },
    ],
    top,
    board: 'read',
  })

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
    ' ↑↓ pick  q quit',
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
    ' ↑↓ pick  q quit',
  ])
  expect(frame(scrolled(6), 39, 12).slice(0, 5)).toEqual([
    ' sitrep',
    ' WORKING 1 ───────────────────────── ▿',
    ' ▲ 6 more',
    ' ✻ Mobile app                       6m',
    '   Woodgrove · Running npm test',
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

test('below 15 rows the blank row under the title goes, then the blank rows between sections, then the body scrolls', () => {
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
    ' NEEDS YOU ●1 ────────────────────── ▿',
    ' ● Shift schedules                 26m',
    '   Contoso · Approve the rota',
    '',
    ' WORKING 1 ───────────────────────── ▿',
    ' ✻ Mobile app                       6m',
    '   Woodgrove · Running npm test',
    '',
    ' ↑↓ pick  q quit',
  ])
  expect(frame(board(), 39, 14)).toEqual([
    ' sitrep',
    ' NEEDS YOU ●3 ●1 ─────────────────── ▿',
    ' ● Help desk redesign 2             4m',
    '   Northwind · Thread replies, or … +1',
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
    '   Northwind · Thread replies, or … +1',
    ' ○ Data import                      1m',
    '   Litware · Allow Bash: psql -f impo…',
    ' ● Shift schedules                 26m',
    '   Contoso · Approve the rota',
    '',
    ' ▼ 2 more',
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

test('the key line names the keys that work now, `s` only while Snoozed holds rows, dropping whole hints from the right', () => {
  const keys = (view: PanelView, width: number) => frame(view, width, 10).at(-1)

  expect(keys(board(), 39)).toBe(' ↑↓ pick  s snoozed  q quit')
  expect(keys(board({ band: 'sr-ct0001' }), 39)).toBe(' ↑↓ move  ⏎ open  s snoozed  q quit')
  expect(keys(board({ band: 'sr-ct0001' }), 24)).toBe(' ↑↓ move  ⏎ open')
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
  expect(drawn(board({ isOpen: true, band: 'sr-ts0001' }), 39, 22, NONE, 17, 18)[0]).not.toContain('7m')
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

  expect(drawn(only('snoozed', [ONBOARDING, away]), 39, 10, NORDFOX, 2, 6)).toEqual([
    ` ${ESC}[0;38;2;149;93;78m●${ESC}[0m ${ESC}[0;1;38;2;122;130;171mOnboarding flow${ESC}[0m      ${ESC}[0;38;2;122;130;171mtomorrow 09:00${ESC}[0m`,
    `   ${ESC}[0;38;2;122;130;171mTailspin · ${ESC}[0;38;2;169;177;214mPick the onboarding ste…${ESC}[0m`,
    ` ${ESC}[0;38;2;92;119;176m●${ESC}[0m ${ESC}[0;38;2;122;130;171mMobile app${ESC}[0m                ${ESC}[0;38;2;122;130;171mnext week${ESC}[0m`,
    `   ${ESC}[0;38;2;122;130;171mWoodgrove · ${ESC}[0;38;2;169;177;214mDrafted the screens${ESC}[0m`,
  ])
})

test("a new ask's mark is `◉`, bold orange, its row washed where the mix can be made; the band wins over the wash", () => {
  const arriving = row('sr-ct0002', 'ask', 'Data import', 'Contoso', 'Approve the rota', 'now', { isNew: true })
  const view = (band?: string): PanelView => ({ ...only('needsYou', [arriving]), ...(band === undefined ? {} : { band }) })
  const wash = `48;2;83;67;69`

  expect(drawn(view(), 39, 8, NORDFOX, 2, 3)).toEqual([
    ` ${ESC}[0;1;38;2;215;119;87;${wash}m◉${ESC}[0;${wash}m ${ESC}[0;1;${wash}mData import${ESC}[0;${wash}m                     ${ESC}[0;38;2;122;130;171;${wash}mnow${ESC}[0m`,
  ])
  expect(drawn(view(), 39, 8, { level: 'truecolor' }, 2, 3)).toEqual([
    ` ${ESC}[0;1;38;2;215;119;87m◉${ESC}[0m ${ESC}[0;1mData import${ESC}[0m                     ${ESC}[0;38;2;122;130;171mnow${ESC}[0m`,
  ])
  expect(drawn(view(), 39, 8, NONE, 2, 3)).toEqual([
    ` ${ESC}[0;1m◉${ESC}[0m ${ESC}[0;1mData import${ESC}[0m                     ${ESC}[0;2mnow${ESC}[0m`,
  ])
  expect(drawn(view('sr-ct0002'), 39, 8, NORDFOX, 2, 3)[0]).toContain('48;2;62;74;91m')
  expect(drawn(view('sr-ct0002'), 39, 8, NORDFOX, 2, 3)[0]).not.toContain(wash)
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

  expect(frame(many, 24, 8)[1]).toBe(' NEEDS YOU ●123 ●45   ▿')
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
    [' sitrep', ' WORKING 1 ────────── ▿', ' ✻ Mobile app        6m', '   Woodgrove · Running…', '', '', '', ' ↑↓ pick  q quit', ''].join(
      '\n',
    ),
  )
  expect(ansi(lines, 'none').split('\n')).toEqual([
    ` ${ESC}[0;1msitrep${ESC}[0m`,
    ` WORKING ${ESC}[0;2m1${ESC}[0m ${ESC}[0;2m──────────${ESC}[0m ${ESC}[0;2m▿${ESC}[0m`,
    ` ✻ Mobile app        ${ESC}[0;2m6m${ESC}[0m`,
    `   ${ESC}[0;2mWoodgrove · ${ESC}[0mRunning…`,
    '',
    '',
    '',
    ` ${ESC}[0;1m↑↓${ESC}[0;2m pick${ESC}[0m  ${ESC}[0;1mq${ESC}[0;2m quit${ESC}[0m`,
  ])
})
