import { expect, test } from './kit'
import { cut, fitted, widthOf, wrap } from '../cli/panel/cells'

test("a grapheme's cells: wide and fullwidth two, an emoji two, a combining mark none of its own, an ambiguous glyph one", () => {
  const texts = ['Northwind', '漢字', 'ｈｉ', 'é', '👍', '❤️', '👩‍💻', '🇬🇧', '●○◌◉✻─▿▹▲▼…']

  expect(texts.map(widthOf)).toEqual([9, 4, 4, 1, 2, 2, 2, 2, 11])
})

test('a cut leaves text that fits whole as it is, and ends any other in `…` within the cells, no space before it', () => {
  expect(cut('Help desk redesign', 18)).toBe('Help desk redesign')
  expect(cut('Help desk redesign', 17)).toBe('Help desk redesi…')
  expect(cut('Help desk redesign', 11)).toBe('Help desk…')
  expect(cut('Help desk redesign', 6)).toBe('Help…')
  expect(cut('Help desk redesign', 1)).toBe('…')
  expect(cut('Help desk redesign', 0)).toBe('')
})

test('a cut never splits a grapheme: a wide glyph that would cross the edge goes whole, a combining mark stays with its letter', () => {
  expect(cut('漢字漢字', 4)).toBe('漢…')
  expect(widthOf(cut('漢字漢字', 4))).toBe(3)
  expect(cut('éééé', 3)).toBe('éé…')
  expect(cut('👩‍💻👩‍💻', 3)).toBe('👩‍💻…')
})

test('words wrap between words at the width, and a word wider than a line goes in pieces', () => {
  expect(wrap("Shift schedules can't be opened here: its terminal has no tmux or zmx.", 20)).toEqual([
    "Shift schedules",
    "can't be opened",
    'here: its terminal',
    'has no tmux or zmx.',
  ])
  expect(wrap('Northwind Fabrikam', 4)).toEqual(['Nort', 'hwin', 'd', 'Fabr', 'ikam'])
  expect(wrap('', 10)).toEqual([])
})

test('lines fitted to rows: past them, the last kept carries the rest of the words, cut with `…`', () => {
  const lines = ['Shift schedules', "can't be opened", 'here: its terminal', 'has no tmux or zmx.']

  expect(fitted(lines, 4, 20)).toEqual(lines)
  expect(fitted(lines, 3, 20)).toEqual(['Shift schedules', "can't be opened", 'here: its terminal…'])
  expect(fitted(['All clear', '', 'Nothing needs you,', 'and nothing is', 'running.'], 4, 30)).toEqual([
    'All clear',
    '',
    'Nothing needs you,',
    'and nothing is running.',
  ])
  expect(fitted(['All clear', '', 'Nothing needs you,'], 2, 12)).toEqual(['All clear', 'Nothing nee…'])
  expect(fitted(lines, 0, 20)).toEqual([])
})
