import { expect, test } from './kit'
import { C } from '../hooks/look'
import { ACCENT, cellsOf, charsOf, type Cell } from '../screens/cells'
import { BOARD_COLUMNS, claudeScreen, COLUMNS, TALK_COLUMNS } from '../screens/claude'
import { faint, inkOf, NORD_WAVE, runsOf, terminalOf } from '../screens/ghostty'
import { rowsOf } from './drawn'
import { FRAMES, heldItem, PROJECT, REVIEW, T0 } from './data'
import { askOf, park, status } from './lines'
import type { Element } from './matching'
import { pane, sceneFrom, type Desk } from './render'
import { DOCKED } from './world/panes'

const box = (props: Record<string, unknown>, ...children: (Element | string)[]): Element => ({
  type: 'Box',
  props,
  children,
})

const text = (props: Record<string, unknown>, ...children: (Element | string)[]): Element => ({
  type: 'Text',
  props,
  children,
})

const button = (props: Record<string, unknown>, ...children: (Element | string)[]): Element => ({
  type: 'Button',
  props,
  ...(children.length === 0 ? {} : { children }),
})

const rows = (element: Element, columns: number) => cellsOf(element, columns).map(charsOf)

/** The cells showing `char`, in reading order. */
const showing = (cells: readonly Cell[][], char: string) =>
  cells.flat().filter(cell => cell.char === char)

/** A desk with a choice and a review asked, something parked and a status, the board where `pane` says. */
const desk = (pane: Desk['pane']): Desk => ({
  lines: [
    [T0, askOf('k1', { ...FRAMES, recommended: 'Redraw' })],
    [T0, askOf('k2', REVIEW)],
    [T0, park('p1', 'Tidy the fixtures')],
    [T0 + 1, status(['Drawing the badge'])],
  ],
  pane,
})

const drawnAt = async (at: Desk) => (await pane(sceneFrom(at)).drawn()) as unknown as Element

test("the board's cells read as its rows, laid out as the tests read them, then blank to its height", async () => {
  const drawn = await drawnAt(desk({ place: { level: 'project', project: PROJECT.key } }))
  const expected = rowsOf(drawn, DOCKED.bodyColumns)
  const laid = cellsOf(drawn, DOCKED.bodyColumns).map(row => charsOf(row).trimEnd())

  expect(laid.slice(0, expected.length)).toEqual(expected)
  expect(laid.slice(expected.length).every(row => row === '')).toBe(true)
  expect(laid).toHaveLength(DOCKED.scroll.bodyRows - 1)
  expect(cellsOf(drawn, DOCKED.bodyColumns).every(row => row.length === DOCKED.bodyColumns)).toBe(
    true,
  )
})

test("the board's cells carry its palette: a heading in its colour and bold, the recommended option's button in the accent and its word in the board's lilac", async () => {
  const cells = cellsOf(await drawnAt(desk({ selected: heldItem('k1') })), DOCKED.bodyColumns)
  const heading = cells.find(row => charsOf(row).trim().startsWith('ASKS'))
  const option = cells.find(row => charsOf(row).includes('Redraw'))
  const at = (row: Cell[] | undefined, words: string) => row?.[charsOf(row).indexOf(words)]?.paint

  expect(at(heading, 'ASKS')).toEqual({ color: C.ask, bold: true })
  expect(at(option, 'Redraw')).toEqual({ color: ACCENT })
  expect(at(option, 'recommended')).toEqual({ color: C.recommended })
  expect(at(option, 'Ship it')).toEqual({})
  expect(showing(cells, '●').map(cell => cell.paint.color)).toEqual([C.ask, C.ask, C.now, C.parked])
})

test('a row hands what it has spare to the child that grows, so the one after it sits at the right edge', () => {
  const row = box({ flexDirection: 'row' }, box({ flexGrow: 1 }, text({}, 'title')), text({}, '2h'))

  expect(rows(row, 12)).toEqual(['title     2h'])
})

test('a row short of room takes it from the children that shrink, by their widths, and never from one that does not', () => {
  const row = box(
    { flexDirection: 'row' },
    text({ wrap: 'truncate-end' }, 'a long title'),
    box({ flexShrink: 0 }, text({}, ' 12m')),
  )

  expect(rows(row, 10)).toEqual(['a lon… 12m'])
})

test('a row with nothing growing sets its children by justifyContent', () => {
  const two = (justify: string) =>
    rows(box({ justifyContent: justify }, text({}, 'ab'), text({}, 'cd')), 8)

  expect(two('flex-end')).toEqual(['    abcd'])
  expect(two('space-between')).toEqual(['ab    cd'])
  expect(two('flex-start')).toEqual(['abcd    '])
})

test('a Text wraps at its spaces where it lacks the room, and one that truncates is cut with an ellipsis', () => {
  const words = 'Ignore tells Claude you have seen it'

  expect(rows(box({ flexDirection: 'column' }, text({ wrap: 'wrap' }, words)), 14)).toEqual([
    'Ignore tells  ',
    'Claude you    ',
    'have seen it  ',
  ])
  expect(rows(box({ flexDirection: 'column' }, text({ wrap: 'truncate-end' }, words)), 14)).toEqual(
    ['Ignore tells …'],
  )
})

test('a Text paints its words over the Text round it, which paints the rest', () => {
  const cells = cellsOf(
    text({ color: C.soft, italic: true }, 'see ', text({ color: C.parked, bold: true }, 'notes')),
    9,
  )

  expect(cells[0]?.[0]?.paint).toEqual({ color: C.soft, italic: true })
  expect(cells[0]?.[4]?.paint).toEqual({ color: C.parked, italic: true, bold: true })
})

test("a Button is its label in brackets, plain bare, its children's words in its label's place, primary in the accent, and dim when told", () => {
  const cells = cellsOf(
    box(
      { gap: 1 },
      button({ label: '✓ Approve', variant: 'primary' }),
      button({ label: 'show all', plain: true, dimColor: true }),
      button({ label: 'Redraw' }, 'Redraw', text({ color: C.recommended }, ' · recommended')),
    ),
    60,
  )

  expect(charsOf(cells[0] ?? []).trimEnd()).toBe('[ ✓ Approve ] show all [ Redraw · recommended ]')
  expect(cells[0]?.[0]?.paint).toEqual({ color: ACCENT })
  expect(cells[0]?.[14]?.paint).toEqual({ dim: true })
  expect(showing(cells, 'm').at(-1)?.paint).toEqual({ color: C.recommended })
})

test('a Box paints its background behind all its cells, padding too, and draws its round border in its colour', () => {
  const lit = cellsOf(box({ backgroundColor: C.tab, paddingX: 1, width: 6 }, text({}, 'ab')), 6)
  const framed = box({ borderStyle: 'round', borderColor: C.ok, paddingX: 1 }, text({}, 'ok'))

  expect(lit[0]?.map(cell => cell.paint.background)).toEqual(Array(6).fill(C.tab))
  expect(rows(framed, 6)).toEqual(['╭────╮', '│ ok │', '╰────╯'])
  expect(cellsOf(framed, 6)[0]?.[0]?.paint).toEqual({ color: C.ok })
})

test('a column stretches its children across it, pads out to its height, its spare rows to the child that grows, and leaves out what is placed absolutely', () => {
  const column = box(
    { flexDirection: 'column', height: 4 },
    text({}, 'top'),
    box({ flexGrow: 1 }),
    box({ position: 'absolute', width: 1 }, text({}, 'x')),
    text({}, 'end'),
  )

  expect(rows(column, 5)).toEqual(['top  ', '     ', '     ', 'end  '])
})


/** Words in cells, unpainted. */
const plain = (words: string): Cell[] => [...words].map(char => ({ char, paint: {} }))

/** Claude Code's screen round a board of `height` rows and a band, read as characters. */
const screenOf = (height: number) => {
  const board = Array.from({ length: height }, (_, i) => plain(`board ${i}`.padEnd(BOARD_COLUMNS)))
  const band = plain('● 2 asks'.padStart(TALK_COLUMNS))
  const screen = claudeScreen(board, band)

  return { screen, chars: screen.rows.map(charsOf) }
}

test("Claude Code's screen docks the board at its right, as the board drew it, under its ✕ and beyond a rule", () => {
  const { chars } = screenOf(3)
  const docked = (row: string) => row.slice(COLUMNS - BOARD_COLUMNS)

  expect(chars.every(row => [...row].length === COLUMNS)).toBe(true)
  expect(docked(chars[0] ?? '').trimEnd()).toMatch(/^ +✕$/)
  expect(chars.slice(1, 4).map(row => docked(row).trimEnd())).toEqual([
    'board 0',
    'board 1',
    'board 2',
  ])
  expect(chars.slice(0, 4).map(row => row[COLUMNS - BOARD_COLUMNS - 1])).toEqual(
    Array(4).fill('│'),
  )
})

test("the conversation is cut from its top to the board's height, the band at its foot, at its right, on the prompt's rule", () => {
  const { chars } = screenOf(3)
  const talk = (row: string) => row.slice(0, TALK_COLUMNS)

  expect(talk(chars[3] ?? '')).toBe('● 2 asks'.padStart(TALK_COLUMNS))
  expect(talk(chars[2] ?? '').trim()).toBe('')
  expect(talk(chars[1] ?? '').trim()).toBe('changes. Press shift+tab twice to enable.')
  expect(chars[4]).toMatch(/^─+ northwind ─$/)
})

test('the prompt spans the screen, its cursor after the ❯, a rule under it, then the status line and the mode line', () => {
  const { screen, chars } = screenOf(3)
  const { row, column } = screen.cursor

  expect(chars[row]?.trimEnd()).toBe('❯')
  expect(column).toBe(2)
  expect(chars[row + 1]).toBe('─'.repeat(COLUMNS))
  expect(chars[row + 2]).toContain('northwind · ')
  expect(chars[row + 3]?.trim()).toMatch(/^⏵⏵ auto mode on/)
})

test("Ghostty paints a cell as Nord Wave does: no colour its foreground, dim at half strength over its background", () => {
  expect(inkOf({})).toBe(NORD_WAVE.foreground)
  expect(inkOf({ color: C.grey, dim: true })).toBe(faint(C.grey, NORD_WAVE.background))
  expect(inkOf({ dim: true, background: '#000000' })).toBe(faint(NORD_WAVE.foreground, '#000000'))
  expect(faint('#ffffff', '#000000')).toBe('#808080')
})

test('a row is drawn as runs of cells painted alike, each from the column it starts at, a background its ground', () => {
  const row = [
    ...plain('ab'),
    { char: '●', paint: { color: C.ask } },
    { char: 'x', paint: { color: C.ask, bold: true, background: C.tab } },
  ]

  expect(runsOf(row)).toEqual([
    { column: 0, text: 'ab', ink: NORD_WAVE.foreground },
    { column: 2, text: '●', ink: C.ask },
    { column: 3, text: 'x', ink: C.ask, ground: C.tab, bold: true },
  ])
})

test("the terminal the app draws is the screen's runs, as wide as its widest row, on Nord Wave, its cursor in Nord Wave's", () => {
  const terminal = terminalOf({ rows: [plain('ab'), plain('abcd')], cursor: { row: 1, column: 2 } })

  expect(terminal.columns).toBe(4)
  expect(terminal.background).toBe(NORD_WAVE.background)
  expect(terminal.rows[1]).toEqual([{ column: 0, text: 'abcd', ink: NORD_WAVE.foreground }])
  expect(terminal.cursor).toEqual({ row: 1, column: 2, color: NORD_WAVE.cursor })
})
