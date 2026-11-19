/**
 * The width checks on a drawn frame: termgrid's `sweep`
 * (design/paper/termgrid.py), in TypeScript. Each finds a frame that wastes
 * the room it has, which a frame held to its golden can't show.
 *
 * - A cut name with room: one of the names cut, as `Help desk re…`, on a
 *   row with more blank cells at its end than the cut took.
 * - A fold with rows spare: a row saying rows are out of view while 3 or
 *   more rows are blank at the foot.
 * - Nothing drawn: 6 rows or more, and none drawing what the frame is for.
 * - A wasted third: content, the rules left out, short of two thirds of the
 *   width, or of the widest the layout grows where that is less.
 */
import { graphemesOf, widthOf } from '../panel/cells'
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

/** A cell content doesn't reach by: a blank or a rule. termgrid's skips a wide glyph's second cell, so its reach falls a cell short. */
const isUndrawn = (glyph: string) => glyph === ' ' || RULE_GLYPHS.has(glyph)

const ELLIPSIS = '…'

/** The fewest characters a cut keeps of a name for the check to take it as one. */
const LEAST_KEPT = 2

/** A letter or a digit: what joins a name to the text before it. */
const JOINING = /[\p{L}\p{N}]/u

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

/** Whether the text holds `part` where a word starts. */
const holdsAtWordStart = (text: string, part: string) => {
  for (let at = text.indexOf(part); at !== -1; at = text.indexOf(part, at + 1)) {
    if (!JOINING.test(text[at - 1] ?? '')) {
      return true
    }
  }

  return false
}

/** The name as the text holds it cut: its longest prefix there, followed by `…`, and the cells the cut took; none for a name not cut there. */
const cutOf = (text: string, name: string): { shown: string; took: number } | undefined => {
  const graphemes = graphemesOf(name)

  for (let kept = graphemes.length - 1; kept > 0; kept--) {
    const prefix = graphemes.slice(0, kept).join('').trimEnd()
    const shown = prefix + ELLIPSIS

    if (prefix.length >= LEAST_KEPT && holdsAtWordStart(text, shown)) {
      return { shown, took: widthOf(name) - widthOf(prefix) }
    }
  }

  return undefined
}

/** Each name a row holds cut with more blank cells at its end than the cut took, the most any name sharing the cut took. */
const cutsWithRoom = (grid: Grid, texts: readonly string[], names: readonly string[]): Break[] =>
  texts.flatMap(text => {
    const spare = grid.width - widthOf(text)
    const took = new Map<string, number>()

    for (const cut of names.flatMap(name => cutOf(text, name) ?? [])) {
      took.set(cut.shown, Math.max(took.get(cut.shown) ?? 0, cut.took))
    }

    return [...took]
      .filter(([, cells]) => spare > cells)
      .map(([shown, cells]): Break => ({
        rule: 'a cut name with room',
        shown: `${JSON.stringify(shown)}: ${cells} cells cut, ${spare} blank at its row's end`,
      }))
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
