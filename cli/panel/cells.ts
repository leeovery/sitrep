/**
 * Text in a terminal's cells: how wide each grapheme draws, a cut that ends
 * in `…` and never splits a grapheme, and words wrapped at a width. The
 * words come cleaned: the view's `cleaned` makes them harmless first.
 *
 * Ambiguous-width glyphs count one cell, as Western terminals draw them.
 */

/** A terminal's size, in cells. */
export type Size = { width: number; height: number }

const ELLIPSIS = '…'

const graphemes = new Intl.Segmenter('en', { granularity: 'grapheme' })

/** The text's graphemes, each a cell's glyph, or two cells' for a wide one. */
export const graphemesOf = (text: string): string[] =>
  Array.from(graphemes.segment(text), each => each.segment)

/** East Asian Wide and Fullwidth: the blocks that hold them. */
const WIDE: readonly (readonly [number, number])[] = [
  [0x1100, 0x115f],
  [0x2e80, 0x303e],
  [0x3041, 0x33ff],
  [0x3400, 0x4dbf],
  [0x4e00, 0x9fff],
  [0xa000, 0xa4cf],
  [0xa960, 0xa97f],
  [0xac00, 0xd7a3],
  [0xf900, 0xfaff],
  [0xfe10, 0xfe19],
  [0xfe30, 0xfe6f],
  [0xff00, 0xff60],
  [0xffe0, 0xffe6],
  [0x20000, 0x2fffd],
  [0x30000, 0x3fffd],
]

const EMOJI_PRESENTATION = /^\p{Emoji_Presentation}/u
const EMOJI_BY_SELECTOR = /^\p{Emoji}.*️/u
const JOINS_BEFORE = /^[\p{M}\p{Cf}]/u

const isWide = (point: number) => WIDE.some(([from, to]) => point >= from && point <= to)

/** The cells a grapheme takes: none for a mark with nothing to join, two for a wide one or an emoji, else one. */
export const cellsOf = (grapheme: string): number => {
  if (grapheme === '' || JOINS_BEFORE.test(grapheme)) {
    return 0
  }

  const isDouble =
    isWide(grapheme.codePointAt(0) ?? 0) ||
    EMOJI_PRESENTATION.test(grapheme) ||
    EMOJI_BY_SELECTOR.test(grapheme)

  return isDouble ? 2 : 1
}

export const widthOf = (text: string): number =>
  graphemesOf(text).reduce((width, grapheme) => width + cellsOf(grapheme), 0)

/** The text in at most `cells`, its end cut to `…` where it doesn't fit whole. */
export const cut = (text: string, cells: number): string => {
  if (widthOf(text) <= cells) {
    return text
  }

  if (cells < 1) {
    return ''
  }

  let kept = ''
  let width = 0

  for (const grapheme of graphemesOf(text)) {
    const next = width + cellsOf(grapheme)

    if (next > cells - 1) {
      break
    }

    kept += grapheme
    width = next
  }

  return kept + ELLIPSIS
}

/** A word too wide for a line, in pieces each `cells` wide at most. */
const pieces = (word: string, cells: number): string[] => {
  const out: string[] = []
  let piece = ''

  for (const grapheme of graphemesOf(word)) {
    if (piece !== '' && widthOf(piece + grapheme) > cells) {
      out.push(piece)
      piece = ''
    }

    piece += grapheme
  }

  return [...out, piece]
}

/** The text's words in lines `cells` wide at most, broken between words, and a word wider than a line in pieces. */
export const wrap = (text: string, cells: number): string[] => {
  const lines: string[] = []
  let line = ''

  for (const word of text.split(' ').filter(each => each !== '')) {
    const joined = line === '' ? word : `${line} ${word}`

    if (widthOf(joined) <= cells) {
      line = joined
      continue
    }

    if (line !== '') {
      lines.push(line)
    }

    const parts = pieces(word, Math.max(cells, 1))

    lines.push(...parts.slice(0, -1))
    line = parts.at(-1) ?? ''
  }

  return line === '' ? lines : [...lines, line]
}
