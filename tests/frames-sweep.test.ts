import { expect, test } from './kit'
import { read } from '../cli/frames/cells'
import { reach, sweep, type Sweeping } from '../cli/frames/sweep'

const NAMES = ['Invoice ledger', 'Northwind', 'Help desk redesign']

const OUT_OF_VIEW = /▼ \d+ more/u

const MARKED = (rows: readonly string[]) => rows.some(row => /[●○✻◌◉]/u.test(row))

/** The rows as a frame `width` wide, as many rows high as given. */
const frame = (width: number, rows: readonly string[]) => read(rows.join('\n'), { width, height: rows.length }, false)

const rulesOf = (width: number, rows: readonly string[], sweeping: Partial<Sweeping> = {}) =>
  sweep(frame(width, rows), { names: NAMES, ...sweeping }).map(each => each.rule)

/** A row reaching the whole of a frame `width` wide, so no third is wasted. */
const full = (width: number) => ` ● ${'x'.repeat(width - 4)}`

test('a name cut with more blank cells at its row end than the cut took is a break; one cut for want of room is not', () => {
  const cut = ' ✻ Invoi…'

  expect(sweep(frame(24, [cut, full(24)]), { names: NAMES })).toEqual([
    { rule: 'a cut name with room', shown: '"Invoi…": 9 cells cut, 15 blank at its row\'s end' },
  ])
  expect(rulesOf(12, [cut, full(12)])).toEqual([])
  expect(rulesOf(24, [' ✻ Exporting the le…', full(24)])).toEqual([])
})

test('rows out of view over 3 blank rows at the foot is a fold with rows spare; over 2, it is not', () => {
  const body = [full(30), ' ▼ 6 more']

  expect(rulesOf(30, [...body, '', '', ''], { outOfView: OUT_OF_VIEW })).toEqual(['a fold with rows spare'])
  expect(rulesOf(30, [...body, '', ''], { outOfView: OUT_OF_VIEW })).toEqual([])
  expect(rulesOf(30, [...body, '', '', ''])).toEqual([])
})

test('6 rows of view or more, none drawing what the frame is for, is nothing drawn; fewer, or with nothing to draw, is not', () => {
  const rows = [' sitrep ' + '-'.repeat(20), '', '', '', '', '']

  expect(rulesOf(30, rows, { draws: MARKED })).toEqual(['nothing drawn'])
  expect(rulesOf(30, rows.slice(0, 5), { draws: MARKED })).toEqual([])
  expect(rulesOf(30, rows)).toEqual([])
  expect(rulesOf(30, [...rows.slice(1), full(30)], { draws: MARKED })).toEqual([])
})

test('content short of two thirds of the width is a wasted third, the rules left out, the width capped at the widest the layout grows', () => {
  expect(rulesOf(30, [' ● Invoice ledger'])).toEqual(['a wasted third'])
  expect(rulesOf(30, [' ● Invoice ledger ' + '─'.repeat(10) + ' ▿'])).toEqual([])
  expect(rulesOf(30, [' WORKING 3 ' + '─'.repeat(18)])).toEqual(['a wasted third'])
  expect(rulesOf(173, [full(100)], { most: 120 })).toEqual([])
  expect(rulesOf(173, [full(100)])).toEqual(['a wasted third'])
})

test("the reach is the column after the last cell drawn on, a wide glyph's second cell drawn on, past blanks and rules", () => {
  expect(reach(frame(20, [' 漢字 ──── ', ' ab']))).toBe(5)
  expect(reach(frame(20, ['', '']))).toBe(0)
})
