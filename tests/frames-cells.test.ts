import { expect, test } from './kit'
import { compare, describe, PLAIN, read, textOf, type Cell, type Grid, type Pen } from '../cli/frames/cells'

const ESC = '\x1b'

const pen = (set: Partial<Pen> = {}): Pen => ({ ...PLAIN, ...set })

const cell = (glyph: string, set: Partial<Pen> = {}): Cell => ({ glyph, pen: pen(set) })

/** Each row's glyphs, the second cell of a wide glyph left out, trailing blanks trimmed. */
const textsOf = (grid: Grid) => grid.rows.map((_, y) => textOf(grid, y))

const at = (grid: Grid, x: number, y: number) => grid.rows[y]?.[x]

test('plain text reads a row a line, as wide as its widest row with no width, the blank rows at its foot left off', () => {
  const grid = read('sitrep\n\n NEEDS YOU\n\n\n')

  expect([grid.width, grid.height]).toEqual([10, 3])
  expect(textsOf(grid)).toEqual(['sitrep', '', ' NEEDS YOU'])
  expect(at(grid, 0, 0)).toEqual(cell('s'))
})

test('SGR sets each part of the pen: bold, faint and reverse, 16, 256 and 24-bit colours, foreground and background', () => {
  const grid = read(
    `${ESC}[1ma${ESC}[0;2mb${ESC}[0;7mc${ESC}[0;33md${ESC}[0;93me${ESC}[0;44mf${ESC}[0;104mg` +
      `${ESC}[0;38;5;214mh${ESC}[0;48;2;62;74;91mi${ESC}[0;1;38;2;215;119;87mj`,
  )

  expect(grid.rows[0]).toEqual([
    cell('a', { bold: true }),
    cell('b', { faint: true }),
    cell('c', { reverse: true }),
    cell('d', { fg: 'ansi:3' }),
    cell('e', { fg: 'ansi:11' }),
    cell('f', { bg: 'ansi:4' }),
    cell('g', { bg: 'ansi:12' }),
    cell('h', { fg: '256:214' }),
    cell('i', { bg: '#3E4A5B' }),
    cell('j', { bold: true, fg: '#D77757' }),
  ])
})

test('SGR 0 and an empty SGR reset the pen; 22, 27, 39 and 49 each undo their part alone', () => {
  const set = `${ESC}[1;2;7;31;41m`
  const grid = read(`${set}a${ESC}[0mb${set}c${ESC}[md${set}${ESC}[22me${ESC}[27mf${ESC}[39mg${ESC}[49mh`)

  expect(grid.rows[0]?.map(each => each.pen)).toEqual([
    pen({ bold: true, faint: true, reverse: true, fg: 'ansi:1', bg: 'ansi:1' }),
    PLAIN,
    pen({ bold: true, faint: true, reverse: true, fg: 'ansi:1', bg: 'ansi:1' }),
    PLAIN,
    pen({ reverse: true, fg: 'ansi:1', bg: 'ansi:1' }),
    pen({ fg: 'ansi:1', bg: 'ansi:1' }),
    pen({ bg: 'ansi:1' }),
    PLAIN,
  ])
})

test("a wide glyph takes two cells, the second holding '', and a combining mark joins the glyph before it, across an SGR too", () => {
  const grid = read(`漢x${ESC}[1ḿ é`)

  expect(grid.rows[0]?.map(each => each.glyph)).toEqual(['漢', '', 'x́', ' ', 'é'])
  expect(at(grid, 2, 0)?.pen).toEqual(PLAIN)
})

test('a line wraps at the width, a wide glyph whole onto the next row where it would cross the edge', () => {
  expect(textsOf(read('abcdef', { width: 4 }))).toEqual(['abcd', 'ef'])
  expect(textsOf(read('abc漢', { width: 4 }))).toEqual(['abc', '漢'])
})

test('a carriage return, a tab and a backspace move the cursor; a newline returns it too', () => {
  expect(textsOf(read('abcd\rx\ty\bz\nw', { width: 20 }))).toEqual(['xbcd    z', 'w'])
})

test('the cursor moves a live region makes: up, down, forward, back, to a column and to a place', () => {
  expect(textsOf(read(`one\ntwo\n${ESC}[2Ax${ESC}[Cy${ESC}[3Dz${ESC}[5Gq${ESC}[Bw`, { width: 10 }))).toEqual([
    'zny q',
    'two  w',
  ])
  expect(textsOf(read(`aaaa\nbbbb${ESC}[1;3Hc${ESC}[2;1fd`, { width: 10 }))).toEqual(['aaca', 'dbbb'])
})

test('an erase clears to the line end, its start or all of it, and below the cursor; a ground set paints what it clears', () => {
  expect(textsOf(read(`abcdef${ESC}[3G${ESC}[K`, { width: 10 }))).toEqual(['ab'])
  expect(textsOf(read(`abcdef${ESC}[3G${ESC}[1K`, { width: 10 }))).toEqual(['   def'])
  expect(textsOf(read(`abcdef${ESC}[2K\nx`, { width: 10 }))).toEqual(['', 'x'])
  expect(textsOf(read(`one\ntwo\nthree${ESC}[2;2H${ESC}[J`, { width: 10 }))).toEqual(['one', 't'])
  expect(textsOf(read(`one\ntwo${ESC}[2J`, { width: 10 }))).toEqual([])

  const painted = read(`ab${ESC}[44m${ESC}[K`, { width: 4 })

  expect(painted.rows[0]?.slice(2)).toEqual([cell(' ', { bg: 'ansi:4' }), cell(' ', { bg: 'ansi:4' })])
})

test('OSC draws nothing, ended by BEL or ST, and the cursor shown or hidden and synchronised output are passed over', () => {
  const grid = read(`${ESC}]9;Help desk redesign asks\x07${ESC}[?25l${ESC}[?2026ha${ESC}]0;title${ESC}\\b${ESC}[?2026l${ESC}[?25h`)

  expect(textsOf(grid)).toEqual(['ab'])
})

test('with a height and no scrollback, only the screen: the rows scrolled off left out, the rows unwritten blank', () => {
  expect(textsOf(read('one\ntwo\nthree', { width: 5, height: 2 }, false))).toEqual(['two', 'three'])
  expect(textsOf(read('one', { width: 5, height: 3 }, false))).toEqual(['one', '', ''])
  expect(textsOf(read('one\ntwo\nthree', { width: 5, height: 2 }))).toEqual(['one', 'two', 'three'])
})

test('any escape the reader does not model is refused, never guessed', () => {
  const refused = [
    `${ESC}[5n`,
    `${ESC}[?7l`,
    `${ESC}[?1049h`,
    `${ESC}[4m`,
    `${ESC}[38;3;1m`,
    `${ESC}[38;2;1;2m`,
    `${ESC}[38;2;300;0;0m`,
    `${ESC}[38;5;256m`,
    `${ESC}[3J`,
    `${ESC}[ q`,
    `${ESC}M`,
    `${ESC}]9;never ended`,
  ]

  for (const each of refused) {
    expect(() => read(each)).toThrow()
  }

  expect(() => read('a\x07b')).toThrow('control character')
  expect(() => read('a\x9bb')).toThrow('control character')
  expect(() => read(`one${ESC}[A`, { width: 5, height: 2 })).toThrow("past the screen's top")
  expect(() => read('́')).toThrow('joins no glyph')
})

/** A grid from rows of cells. */
const gridOf = (rows: Cell[][], width = Math.max(...rows.map(row => row.length))): Grid => ({
  width,
  height: rows.length,
  rows: rows.map(row => Array.from({ length: width }, (_, x) => row[x] ?? cell(' '))),
})

test('two grids alike compare with no difference', () => {
  const frame = read(`${ESC}[1msitrep${ESC}[0m\n ${ESC}[38;2;122;130;171mNEEDS YOU`)

  expect(compare(frame, frame)).toEqual([])
})

test('the comparer holds glyph, foreground, background, bold, faint and reverse, each cell counted from 1', () => {
  const frame = gridOf([[cell('a'), cell('b'), cell('c'), cell('d'), cell('e'), cell('f')]])
  const drawn = gridOf([
    [cell('x'), cell('b', { fg: 'ansi:3' }), cell('c', { bg: '#3E4A5B' }), cell('d', { bold: true }), cell('e', { faint: true }), cell('f', { reverse: true })],
  ])

  expect(compare(frame, drawn)).toEqual([
    { row: 1, col: 1, frame: cell('a'), drawn: cell('x') },
    { row: 1, col: 2, frame: cell('b'), drawn: cell('b', { fg: 'ansi:3' }) },
    { row: 1, col: 3, frame: cell('c'), drawn: cell('c', { bg: '#3E4A5B' }) },
    { row: 1, col: 4, frame: cell('d'), drawn: cell('d', { bold: true }) },
    { row: 1, col: 5, frame: cell('e'), drawn: cell('e', { faint: true }) },
    { row: 1, col: 6, frame: cell('f'), drawn: cell('f', { reverse: true }) },
  ])
})

test("a blank's ink and weight aren't compared, as nothing shows them; its ground and reverse are", () => {
  const frame = gridOf([[cell(' '), cell(' '), cell(' ')]])
  const drawn = gridOf([[cell(' ', { fg: 'ansi:3', bold: true, faint: true }), cell(' ', { bg: 'ansi:4' }), cell(' ', { reverse: true })]])

  expect(compare(frame, drawn).map(each => each.col)).toEqual([2, 3])
})

test("a drawn row shorter than the frame's reads as blank; one drawn past the frame's columns, or a height otherwise, is an error", () => {
  const frame = gridOf([[cell('a'), cell(' ')]])

  expect(compare(frame, gridOf([[cell('a')]]))).toEqual([])
  expect(() => compare(frame, gridOf([[cell('a'), cell(' '), cell('b')]]))).toThrow("row 1 drawn past the frame's 2 columns")
  expect(() => compare(frame, gridOf([[cell('a')], [cell('b')]]))).toThrow('drawn 2 rows, where the frame has 1')
})

test('a failure names each cell drawn otherwise, its pens whole, for the first 20, then how many more', () => {
  const frame = gridOf([Array.from({ length: 23 }, () => cell('a'))])
  const drawn = gridOf([Array.from({ length: 23 }, () => cell('b', { fg: '#D77757', bold: true, reverse: true }))])
  const lines = describe('panel-rest-39x27.ansi', compare(frame, drawn)).split('\n')

  expect(lines).toHaveLength(22)
  expect(lines[0]).toBe('panel-rest-39x27.ansi draws 23 cells otherwise than its frame:')
  expect(lines[1]).toBe(`  row 1, column 1: the frame's "a" default on default, drawn "b" #D77757 on default bold reverse`)
  expect(lines[20]).toContain('row 1, column 20:')
  expect(lines[21]).toBe('  and 3 more')
  expect(describe('x', compare(frame, drawn).slice(0, 20)).split('\n')).toHaveLength(21)
})
