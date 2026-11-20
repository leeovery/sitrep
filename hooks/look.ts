/**
 * The board's look (DESIGN.md, "Look"): Tokyo Night's palette, the glyphs,
 * and how ages and long lines read.
 *
 * Text drawn with no colour is white: what is clickable, and the main
 * content. Colour goes on glyphs, headings and orange waiting counts alone.
 */
import { ago } from '../core'

export const C = {
  /** Claude Code's own orange, the notch's ask circle. */
  ask: '#d77757',
  /** A new ask's flash: the ask's hue and chroma, its OKLCH lightness raised from 0.67 to 0.79, the old pulse's. */
  pulse: '#ff9c7b',
  sessions: '#7aa2f7',
  parked: '#bb9af7',
  ok: '#9ece6a',
  now: '#73daca',
  /** Lines describing the item above them. */
  soft: '#a9b1d6',
  /** Ages, counts and heading notes. */
  grey: '#7a82ab',
  /** Closed things, and every tree's glyphs. */
  faint: '#565f89',
  /**
   * The word ending the recommended option's button: the primary's lilac,
   * Claude Code's dark `suggestion` #b1b9f9, at 75% of its OKLCH lightness
   * and its hue, its chroma raised from 0.09 to 0.12 to stay apart from grey.
   */
  recommended: '#7178c7',
  rule: '#3b4261',
  tab: '#292e42',
} as const

export const GLYPH = {
  ask: '●',
  /** Filled, as an ask's: on the notch a hollow circle means away. */
  parked: '●',
  now: '●',
  next: '●',
  home: '⌂',
  every: '≡',
  up: '←',
  branch: '├',
  last: '└',
  /** A tree's line running on past a row. */
  stem: '│',
  done: '✓',
  /** A closed thing's mark in a list: resolved, taken off Parked, finished; a circle, as every other row's. */
  closed: '●',
  /** Replies just taken in from the board. */
  news: '✦',
} as const

/** The board's close where its frame's ✕ is one cell: not plain, so bracketed, a target wide enough to tap. */
export const CLOSE = { label: '✕ close' } as const

/** A new ask's pulse at its peak, every other frame: its ● ringed, in the brighter orange. */
const PEAK = { glyph: '◉', color: C.pulse }

/** An ask's mark at rest. */
const REST = { glyph: GLYPH.ask, color: C.ask }

/** How long ago `at` was, as a heading's note says it: `just now`, `12m ago`. */
export const agoWords = (now: number, at: number) => {
  const age = ago(now, at)

  return age === 'now' ? 'just now' : `${age} ago`
}

/** A line cut to `width` characters, an ellipsis where it was cut. */
export const clip = (text: string, width: number) =>
  text.length <= width ? text : `${text.slice(0, Math.max(1, width - 1))}…`

const pieces = (word: string, width: number) =>
  Array.from({ length: Math.ceil(word.length / width) }, (_, i) =>
    word.slice(i * width, (i + 1) * width),
  )

/** Text broken into lines of at most `width`, between words where it can be; a word longer than a line is cut. */
export const wrapped = (text: string, width: number) => {
  const size = Math.max(1, width)

  return text
    .split(/\s+/)
    .filter(Boolean)
    .reduce<string[]>((lines, word) => {
      const last = lines.at(-1)

      return last !== undefined && last.length + 1 + word.length <= size
        ? [...lines.slice(0, -1), `${last} ${word}`]
        : [...lines, ...pieces(word, size)]
    }, [])
}

/** A count and its noun, singular or plural. */
export const counted = (count: number, one: string, many: string) =>
  `${count} ${count === 1 ? one : many}`

/** The ask glyph and its colour at a frame of the pulse: at rest, but at its peak on every odd frame while it runs. */
export const pulseOf = (frames: number) => (frames % 2 === 1 ? PEAK : REST)
