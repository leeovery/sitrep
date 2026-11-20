import { expect, test } from './kit'
import { widthOf, type Size } from '../cli/panel/cells'
import { draw, text } from '../cli/panel/draw'
import { layoutOf, topFor, type Layout, type Placed } from '../cli/panel/layout'
import type { Paint } from '../cli/panel/paint'
import { rowKey, type PanelRow, type PanelView } from '../cli/panel/view'

/**
 * The layout's rules held over boards drawn at random from a fixed seed:
 * every kind of board, every section, Snoozed open and folded, wide names,
 * answers from none to taller than the frame, `top` from 0 past the last
 * (0, 1, one at random, the last, and two past it), and the band anywhere,
 * at heights 8 to 24 and widths 24 to 45. Each frame is held to every rule,
 * and the first frame breaking each is named. Sized to run in a second or
 * two under the kit; it caught each of the layout's last three bugs.
 */

const SEED = 20261119
const BOARDS = 100
const SIZES_A_BOARD = 2

/** Mulberry32, seeded: the same boards on every run. A plain linear congruential generator taken modulo a small number repeats in its low bits, and draws too few kinds of board. */
const randomFrom = (seed: number) => {
  let state = seed

  return (below: number) => {
    state = (state + 0x6d2b79f5) | 0
    let mixed = Math.imul(state ^ (state >>> 15), 1 | state)
    mixed = (mixed + Math.imul(mixed ^ (mixed >>> 7), 61 | mixed)) ^ mixed

    return ((mixed ^ (mixed >>> 14)) >>> 0) % below
  }
}

const NAMES = [
  'Help desk redesign',
  'Shift schedules',
  'Invoice ledger',
  'Onboarding flow',
  'Mobile app',
  'Data import',
  'Data 漢字漢字 import',
  'Mobile 👍 app',
  'Ｍｏｂｉｌｅ ａｐｐ',
  'Help desk redesign, the onboarding flow and the data import',
]
const PROJECTS = ['Northwind', 'Contoso', 'Fabrikam', 'Tailspin', 'Woodgrove', 'Litware', 'Northwind Fabrikam Litware Contoso', '漢字']
const STATUSES = ['Running npm test', '', 'Allow Bash: psql -f import.sql', '漢字漢字漢字漢字漢字漢字漢字', 'x']
const ANSWERS = [
  undefined,
  undefined,
  'Short.',
  "Shift schedules can't be opened here: its terminal has no tmux or zmx.",
  "EACCES: open '/Users/me/.local/state/sitrep/sessions/sr-nw0001.json'",
  'word '.repeat(60),
]
const WAKES = ['tomorrow 09:00', 'until it moves', 'Sat 09:00', '14:00']
/** A row's first line: a mark at the margin. */
const MARKED = /^ [●○✻◌◉]/u

type Random = ReturnType<typeof randomFrom>

const pick = <T>(random: Random, things: readonly T[]) => things[random(things.length)] as T

const rowsOf = (random: Random, count: number, marks: readonly PanelRow['mark'][], isSnoozed: boolean, id: { next: number }) =>
  Array.from({ length: count }, (): PanelRow => {
    const mark = pick(random, marks)
    const more = random(4) === 0 ? { more: 2 } : {}
    const row = {
      session: `sr-nw${String(id.next++).padStart(4, '0')}`,
      mark,
      isAway: random(3) === 0,
      isSnoozed,
      isNew: !isSnoozed && mark === 'ask' && random(5) === 0,
      name: pick(random, NAMES),
      ...(random(3) === 0 ? { count: 2 + random(30) } : {}),
      project: pick(random, PROJECTS),
      status: { text: pick(random, STATUSES), ...more },
      time: isSnoozed ? pick(random, WAKES) : pick(random, ['now', '12m', '3d']),
    }

    return { ...row, lines: [row.status] }
  })

const boardOf = (random: Random, id: { next: number }): PanelView => {
  const sections: PanelView['sections'] = []
  const [needs, working, snoozed] = [random(6), random(7), random(4)]

  if (needs > 0) {
    sections.push({ kind: 'needsYou', rows: rowsOf(random, needs, ['ask', 'turn'], false, id), counts: [{ value: needs, need: 'ask' }], isOpen: true })
  }

  if (working > 0) {
    sections.push({ kind: 'working', rows: rowsOf(random, working, ['working', 'onItsWork'], false, id), counts: [{ value: working }], isOpen: true })
  }

  if (snoozed > 0) {
    sections.push({ kind: 'snoozed', rows: rowsOf(random, snoozed, ['ask', 'turn'], true, id), counts: [{ value: snoozed }], isOpen: random(2) === 0 })
  }

  const answer = pick(random, ANSWERS)
  const board = pick(random, ['read', 'read', 'read', 'stale', 'looking', 'unreadable'] as const)
  const told = answer === undefined ? {} : { answer }

  if (board === 'looking' || board === 'unreadable') {
    return { sections: [], top: 0, board: 'looking', ...(board === 'unreadable' ? { reason: pick(random, ANSWERS.slice(2)) as string } : {}), ...told }
  }

  return { sections: random(8) === 0 ? [] : sections, top: 0, board, ...(board === 'stale' ? { asOf: '12:04' } : {}), ...told }
}

/** The rows the body can show, in order, by key. */
const keysOf = (view: PanelView) => view.sections.filter(section => section.isOpen).flatMap(section => section.rows.map(rowKey))

const bottomOf = (placed: Placed) => placed.y + (placed.kind === 'row' ? 2 : 1)

/** Whether every block shows, with its blank rows between sections, under a blank top row: the rows shown, every heading among them, nothing scrolled. */
const fitsUnderTop = (view: PanelView, layout: Layout, shown: readonly number[]) => {
  const { placed, body } = layout
  const headings = placed.filter(each => each.kind === 'heading').length
  const lines = placed.reduce((sum, each) => sum + (each.kind === 'row' ? each.height + each.menu : 1), 0)
  const isWhole = shown.length === keysOf(view).length && headings === layout.sections.length && placed.every(each => each.kind === 'row' || each.kind === 'heading')

  return isWhole && lines + Math.max(headings - 1, 0) < body.to
}

/** Each rule a frame breaks, by its name. */
const brokenIn = (view: PanelView, size: Size, layout: Layout, lines: string[]): string[] => {
  const keys = keysOf(view)
  const broken: string[] = []
  const breaks = (rule: string, isBroken: boolean) => isBroken && broken.push(rule)
  const { placed, body } = layout
  const shown = placed.flatMap(each => (each.kind === 'row' ? [keys.indexOf(each.key)] : []))
  const above = placed.find(each => each.kind === 'above')
  const below = placed.find(each => each.kind === 'below')
  const ys = placed.flatMap(each => (each.kind === 'row' ? [each.y, each.y + 1] : [each.y]))
  const markYs = lines.flatMap((line, y) => (y >= body.from && y < body.to && MARKED.test(line) ? [y] : []))

  breaks('exactly H lines', lines.length !== size.height)
  breaks('no title: row 0 blank while rows start on row 1', body.from > 1 || (body.from === 1 && layout.sections.length > 0 && lines[0] !== '') || lines.some(line => line.startsWith(' sitrep')))
  breaks('the top row kept exactly while every block fits under it', view.board !== 'looking' && (body.from === 1) !== fitsUnderTop(view, layout, shown))
  breaks('the key line kept', !/q quit( +as of 12:04)?$/.test(lines.at(-1) ?? ''))
  breaks("a stale board's notice at the key line's right end", (view.board === 'stale') !== (lines.at(-1) ?? '').endsWith('  as of 12:04'))
  breaks('nothing past W−2', lines.some(line => widthOf(line) > Math.min(size.width, 120) - 1))
  breaks('no overlaps', new Set(ys).size !== ys.length)
  breaks('the body kept to its rows', ys.some(y => y < body.from || y >= body.to) || body.to < body.from)
  breaks('the body clear of the answer', layout.answer.lines.length > 0 && body.to > layout.answer.from - 1)
  breaks('the rows where draw marks them', layout.sections.length > 0 && view.board !== 'looking' && markYs.join() !== layout.rows.map(row => row.y).join())
  breaks('the rows contiguous from top', shown.some((at, index) => at !== layout.top + index))
  breaks('`▲` counting the rows above', above !== undefined && (above.kind !== 'above' || shown.length === 0 || above.count !== layout.top))
  breaks('`▼` counting the rows below', below !== undefined && below.kind === 'below' && below.count !== keys.length - (shown.length > 0 ? layout.top + shown.length : layout.top))
  breaks('`top` kept within `lastTop`', layout.top !== Math.min(view.top, layout.lastTop))
  breaks('`top` at 0 while the body shows no row', keys.length > 0 && shown.length === 0 && layout.top !== 0)
  breaks('the body starting at its first row', placed.length > 0 && placed[0]?.y !== body.from)
  breaks(
    'no blank row but one before a heading',
    placed.some((each, index) => {
      const blank = index === 0 ? 0 : each.y - bottomOf(placed[index - 1] as Placed)

      return blank !== 0 && !(blank === 1 && each.kind === 'heading')
    }),
  )
  breaks(
    'no open heading without a row under it',
    placed.some((each, index) => {
      const [next, after] = [placed[index + 1], placed[index + 2]]

      return each.kind === 'heading' && each.section.isOpen && !(next?.kind === 'row' || (next?.kind === 'above' && after?.kind === 'row'))
    }),
  )
  breaks('a row shown where the body has room for one', keys.length > 0 && view.board !== 'looking' && body.to - body.from >= 2 && shown.length === 0)

  return broken
}

/** Each row a `top` from `topFor` can't show whole, from the first and the last `top`. */
const unreachedIn = (view: PanelView, size: Size, layout: Layout) =>
  keysOf(view).flatMap(key =>
    [0, layout.lastTop].flatMap(from => {
      const top = topFor({ ...view, top: from }, size, key)
      const row = top === undefined ? undefined : layoutOf({ ...view, top }, size).rows.find(each => each.key === key)
      const { to } = layout.body

      return row === undefined || row.y + 1 >= to ? ['every row reachable through `topFor`'] : []
    }),
  )

test('every frame of boards drawn at random keeps the layout rules', () => {
  const random = randomFrom(SEED)
  const id = { next: 0 }
  const firsts = new Map<string, string>()
  const paints: Paint[] = [{ level: 'none' }, { level: 'truecolor', fg: [205, 206, 207], bg: [46, 52, 64] }]

  for (let at = 0; at < BOARDS; at++) {
    const board = boardOf(random, id)
    const keys = keysOf(board)

    for (let each = 0; each < SIZES_A_BOARD; each++) {
      const size = { width: 24 + random(22), height: 8 + random(17) }
      const { lastTop, body } = layoutOf(board, size)
      const named = (top: number) => `${size.width}×${size.height}, top ${top}, ${keys.length} rows, board ${at}`
      const tops = new Set([0, 1, random(lastTop + 1), lastTop, lastTop + 2])

      for (const top of tops) {
        const band = random(3) === 0 || keys.length === 0 ? {} : { band: pick(random, keys) }
        const view = { ...board, top, ...band }
        const layout = layoutOf(view, size)

        for (const paint of top === 0 ? paints : paints.slice(0, 1)) {
          const lines = text(draw(view, size, paint)).split('\n').slice(0, -1)

          for (const rule of brokenIn(view, size, layout, lines)) {
            firsts.set(rule, firsts.get(rule) ?? named(top))
          }
        }
      }

      if (body.to - body.from >= 2 && board.board !== 'looking') {
        for (const rule of unreachedIn(board, size, layoutOf(board, size))) {
          firsts.set(rule, firsts.get(rule) ?? named(0))
        }
      }
    }
  }

  expect(Object.fromEntries(firsts)).toEqual({})
})
