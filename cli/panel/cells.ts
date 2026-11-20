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

/** Printable ASCII: a grapheme a character, a cell each, with no segmenting. */
const ASCII = /^[\x20-\x7e]*$/

/** The text's graphemes, each a cell's glyph, or two cells' for a wide one. */
export const graphemesOf = (text: string): string[] =>
  ASCII.test(text) ? [...text] : Array.from(graphemes.segment(text), each => each.segment)

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
  [0x1b000, 0x1b2ff],
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
  ASCII.test(text) ? text.length : graphemesOf(text).reduce((width, grapheme) => width + cellsOf(grapheme), 0)

/** The text in at most `cells`, its end cut to `…` where it doesn't fit whole, with no space left before the `…`. */
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

  return kept.trimEnd() + ELLIPSIS
}

/** A word too wide for a line, in pieces, the nth `cellsAt(n)` wide at most. */
const pieces = (word: string, cellsAt: (piece: number) => number): string[] => {
  const out: string[] = []
  let piece = ''

  for (const grapheme of graphemesOf(word)) {
    if (piece !== '' && widthOf(piece + grapheme) > Math.max(cellsAt(out.length), 1)) {
      out.push(piece)
      piece = ''
    }

    piece += grapheme
  }

  return [...out, piece]
}

/** A word with what it is, which says how it is drawn. */
export type Tagged<T> = { text: string; tag: T }

/** A wrapped line's words, and whether it ends inside a word too wide for a line, its next piece on the line after. */
type Wrapped<T> = { words: Tagged<T>[]; isBroken: boolean }

/**
 * Words in lines, each as wide as `cellsAt` gives for it at most, a space
 * between each two, broken between words, and a word wider than its line in
 * pieces, each the width of the line it stands on, its tag kept on each.
 */
const wrappedOver = <T>(words: readonly Tagged<T>[], cellsAt: (line: number) => number): Wrapped<T>[] => {
  const lines: Wrapped<T>[] = []
  let line: Tagged<T>[] = []
  let width = 0

  for (const word of words) {
    const joined = width + (line.length === 0 ? 0 : 1) + widthOf(word.text)

    if (joined <= cellsAt(lines.length)) {
      line.push(word)
      width = joined
      continue
    }

    if (line.length > 0) {
      lines.push({ words: line, isBroken: false })
    }

    const from = lines.length
    const parts = pieces(word.text, piece => cellsAt(from + piece))

    lines.push(...parts.slice(0, -1).map(piece => ({ words: [{ text: piece, tag: word.tag }], isBroken: true })))

    const last = parts.at(-1) ?? ''

    line = [{ text: last, tag: word.tag }]
    width = widthOf(last)
  }

  return line.length === 0 ? lines : [...lines, { words: line, isBroken: false }]
}

/** The text's words, each tagged `tag`. */
export const wordsOf = <T>(text: string, tag: T): Tagged<T>[] =>
  text
    .split(' ')
    .filter(each => each !== '')
    .map(each => ({ text: each, tag }))

/** Tagged words in lines, the first `first` cells wide at most and each after it `rest`, broken as `wrap` breaks them. */
export const wrapTagged = <T>(words: readonly Tagged<T>[], first: number, rest: number): Tagged<T>[][] =>
  wrappedOver(words, line => (line === 0 ? first : rest)).map(line => line.words)

/** A wrapped line's text, and whether it ends inside a word too wide for a line. */
type Line = { text: string; isBroken: boolean }

const wrapped = (text: string, cells: number): Line[] =>
  wrappedOver(wordsOf(text, undefined), () => cells).map(line => ({
    text: line.words.map(word => word.text).join(' '),
    isBroken: line.isBroken,
  }))

/** The text's words in lines `cells` wide at most, broken between words, and a word wider than a line in pieces. */
export const wrap = (text: string, cells: number): string[] => wrapped(text, cells).map(line => line.text)

/** The text wrapped at `cells` in at most `rows` lines: past them, the last kept carries the rest, a broken word whole again, cut with `…`. */
export const wrapIn = (text: string, cells: number, rows: number): string[] => {
  const lines = wrapped(text, cells)

  if (lines.length <= rows) {
    return lines.map(line => line.text)
  }

  if (rows < 1) {
    return []
  }

  const rest = lines
    .slice(rows - 1)
    .map(line => line.text + (line.isBroken ? '' : ' '))
    .join('')

  return [...lines.slice(0, rows - 1).map(line => line.text), cut(rest.trimEnd(), cells)]
}
