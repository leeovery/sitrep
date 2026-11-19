/**
 * The width checks on a drawn frame: termgrid's `sweep`
 * (design/paper/termgrid.py), in TypeScript. Each finds a frame that wastes
 * the room it has, which a frame held to its golden can't show.
 *
 * - A cut name with room: one of the names cut, as `Invoi…`, on a row with
 *   more blank cells at its end than the cut took.
 * - A fold with rows spare: a row saying rows are out of view while 3 or
 *   more rows are blank at the foot.
 * - Nothing drawn: 6 rows or more, and none drawing what the frame is for.
 * - A wasted third: content, the rules left out, short of two thirds of the
 *   width, or of the widest the layout grows where that is less.
 */
import { widthOf } from '../panel/cells'
import { textOf, type Grid } from './cells'

export type Rule = 'a cut name with room' | 'a fold with rows spare' | 'nothing drawn' | 'a wasted third'

/** A rule a frame breaks, and what shows it. */
export type Break = { rule: Rule; shown: string }

export type Sweeping = {
  /** The names a frame may cut. */
  names: readonly string[]
  /** A row saying rows are out of view: `▼ 3 more`. */
  outOfView?: RegExp
  /** Whether the rows draw what the frame is for; none for a frame with nothing to draw. */
  draws?: (rows: readonly string[]) => boolean
  /** The widest the layout grows: past it, the width is the cap's. */
  most?: number
}

/** The blank rows at the foot that make a fold one with rows spare. */
const FOLD_SPARE = 3

/** The fewest rows of view in which a frame must draw something. */
const LEAST_VIEW = 6

const RULE_GLYPHS = new Set('─━┄┅┈┉╌╍═│┃┆┊╎┬┴┼├┤╵╷╴╶')

/** A cell content doesn't reach by: a blank or a rule. termgrid's counts a wide glyph's second cell too, a cell short. */
const isUndrawn = (glyph: string) => glyph === ' ' || RULE_GLYPHS.has(glyph)

/** A word cut: its letters, then `…`. */
const CUT = /([\p{L}\p{N}_./-]{2,})…/gu

/** How far across the rows content runs, the rules left out: the column after the last cell drawn on. */
export const reach = (grid: Grid): number =>
  Math.max(
    0,
    ...grid.rows.map(row => {
      let end = row.length

      while (end > 0 && isUndrawn(row[end - 1]?.glyph ?? ' ')) {
        end--
      }

      return end
    }),
  )

/** The cells a name lost to its cut, the most of any name the cut word starts; 0 for a word no name starts. */
const tookFrom = (word: string, names: readonly string[]) =>
  Math.max(0, ...names.filter(name => name.startsWith(word) && name.length > word.length).map(name => widthOf(name) - widthOf(word)))

const cutsWithRoom = (grid: Grid, texts: readonly string[], names: readonly string[]): Break[] =>
  texts.flatMap(text => {
    const spare = grid.width - widthOf(text)

    return [...text.matchAll(CUT)].flatMap(([shown, word]): Break[] => {
      const took = tookFrom(word ?? '', names)

      return took > 0 && spare > took
        ? [{ rule: 'a cut name with room', shown: `${JSON.stringify(shown)}: ${took} cells cut, ${spare} blank at its row's end` }]
        : []
    })
  })

const blankAtFoot = (texts: readonly string[]) => {
  const last = texts.findLastIndex(text => text.trim() !== '')

  return texts.length - 1 - last
}

const foldWithRowsSpare = (texts: readonly string[], outOfView: RegExp | undefined): Break[] => {
  const foot = blankAtFoot(texts)
  const hit = outOfView === undefined || foot < FOLD_SPARE ? undefined : texts.find(text => outOfView.test(text))

  return hit === undefined ? [] : [{ rule: 'a fold with rows spare', shown: `${JSON.stringify(hit.trim())} over ${foot} blank rows` }]
}

/** The rules the frame breaks. */
export const sweep = (grid: Grid, { names, outOfView, draws, most }: Sweeping): Break[] => {
  const texts = grid.rows.map((_, y) => textOf(grid, y))
  const isBlank = draws !== undefined && texts.length >= LEAST_VIEW && !draws(texts)
  const reached = reach(grid)
  const room = Math.min(grid.width, most ?? grid.width)

  return [
    ...cutsWithRoom(grid, texts, names),
    ...foldWithRowsSpare(texts, outOfView),
    ...(isBlank ? [{ rule: 'nothing drawn', shown: `none in ${texts.length} rows of view` } as const] : []),
    ...(reached * 3 < room * 2 ? [{ rule: 'a wasted third', shown: `content reaches ${reached} of ${room} columns` } as const] : []),
  ]
}
