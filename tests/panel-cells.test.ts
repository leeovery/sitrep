import { expect, test } from './kit'
import { cut, widthOf, wrap, wrapIn } from '../cli/panel/cells'

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

test('words wrapped in rows: past them, the last kept carries the rest, cut with `…`, a broken word whole again', () => {
  const text = "Shift schedules can't be opened here: its terminal has no tmux or zmx."
  const path = "EACCES: open '/Users/me/.local/state/sitrep/sessions/sr-nw0001.json'"

  expect(wrapIn(text, 20, 4)).toEqual(wrap(text, 20))
  expect(wrapIn(text, 20, 3)).toEqual(['Shift schedules', "can't be opened", 'here: its terminal…'])
  expect(wrap(path, 20)).toEqual(['EACCES: open', "'/Users/me/.local/st", 'ate/sitrep/sessions/', "sr-nw0001.json'"])
  expect(wrapIn(path, 20, 2)).toEqual(['EACCES: open', "'/Users/me/.local/s…"])
  expect(wrapIn(path, 20, 3)).toEqual(['EACCES: open', "'/Users/me/.local/st", 'ate/sitrep/sessions…'])
  expect(wrapIn(text, 20, 0)).toEqual([])
})
