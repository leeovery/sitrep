/**
 * The board's look (DESIGN.md, "Look"): Tokyo Night's palette, the glyphs,
 * and how ages and long lines read.
 *
 * Text drawn with no colour is white: what is clickable, and the main
 * content. Colour goes on glyphs, headings and amber waiting counts alone.
 */

export const C = {
  ask: '#e0af68',
  /** A new ask's pulse. */
  pulse: '#ff9e64',
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
  rule: '#3b4261',
  tab: '#292e42',
} as const

export const GLYPH = {
  ask: '◆',
  parked: '◇',
  now: '•',
  next: '◦',
  home: '⌂',
  every: '≡',
  up: '←',
  branch: '├',
  last: '└',
  /** A tree's line running on past a row. */
  stem: '│',
  done: '✓',
  /** Replies just taken in from the board. */
  news: '✦',
} as const

/** The board's close where its frame's ✕ is one cell: not plain, so bracketed, a target wide enough to tap. */
export const CLOSE = { label: '✕ close' } as const

/** The ◆ of a new ask, frame by frame as it pulses. */
const PULSE = ['◆', '◈', '◇', '◈']

const MIN = 60_000
const HOUR = 60 * MIN
const DAY = 24 * HOUR

/** How long ago `at` was, in the fewest characters: `now`, `12m`, `2h`, `3d`. */
export const ago = (now: number, at: number) => {
  const elapsed = now - at

  if (elapsed < MIN) {
    return 'now'
  }

  if (elapsed < HOUR) {
    return `${Math.round(elapsed / MIN)}m`
  }

  return elapsed < DAY ? `${Math.round(elapsed / HOUR)}h` : `${Math.round(elapsed / DAY)}d`
}

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

/** The ask glyph and its colour at a frame of the pulse: amber at rest, flashing while it runs. */
export const pulseOf = (frames: number) =>
  frames > 0
    ? {
        glyph: PULSE[frames % PULSE.length] ?? GLYPH.ask,
        color: frames % 2 === 1 ? C.pulse : C.ask,
      }
    : { glyph: GLYPH.ask, color: C.ask }
