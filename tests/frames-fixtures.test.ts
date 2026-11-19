import { expect, test } from './kit'
import { drawn, FIXTURES, frameName, misfitsOf, viewAt } from '../cli/frames/fixtures'
import { layoutOf } from '../cli/panel/layout'
import type { Line } from '../cli/panel/draw'
import { rowKey, type PanelView } from '../cli/panel/view'

/** The sizes the checker's sweep draws at, and a short one. */
const SIZES = [
  { width: 39, height: 27 },
  { width: 69, height: 46 },
  { width: 73, height: 36 },
  { width: 114, height: 45 },
  { width: 173, height: 53 },
  { width: 73, height: 15 },
  { width: 24, height: 8 },
]

const lineOf = (text: string): Line => [{ text, pen: {} }]

test('lines fit a size only one a row, each no wider than its columns, a wide glyph counted two', () => {
  const size = { width: 6, height: 2 }

  expect(misfitsOf([lineOf('sitrep'), lineOf('')], size)).toEqual([])
  expect(misfitsOf([lineOf('sitrep')], size)).toEqual(['1 lines drawn for 2 rows'])
  expect(misfitsOf([lineOf('sitrep'), lineOf(''), lineOf('')], size)).toEqual(['3 lines drawn for 2 rows'])
  expect(misfitsOf([lineOf('sitrep!'), lineOf('漢字漢字')], size)).toEqual([
    'line 1 drawn 7 cells wide for 6 columns',
    'line 2 drawn 8 cells wide for 6 columns',
  ])
})

test('every fixture draws to fit its size, and at every size the sweep draws at', () => {
  const misfits = FIXTURES.flatMap(fixture =>
    [fixture.size, ...SIZES].flatMap(size => misfitsOf(drawn(fixture, size), size).map(misfit => `${frameName(fixture)} at ${size.width}×${size.height}: ${misfit}`)),
  )

  expect(misfits).toEqual([])
})

/** The row a fixture's view keeps whole in sight: the band's, or, with none, Snoozed's last once opened. */
const keptOf = (view: PanelView) => {
  const last = view.sections.find(section => section.kind === 'snoozed' && section.isOpen)?.rows.at(-1)

  return view.band ?? (last === undefined ? undefined : rowKey(last))
}

test("a fixture's keys leave its row whole in view at every size with room for a row: the band, or Snoozed's last once opened", () => {
  const atSizes = FIXTURES.flatMap(fixture => [fixture.size, ...SIZES].map(size => ({ fixture, size, view: viewAt(fixture, size) })))
  const kept = atSizes.filter(({ view }) => keptOf(view) !== undefined)
  const unseen = kept.flatMap(({ fixture, size, view }) => {
    const { rows, body } = layoutOf(view, size)
    const hasRoom = body.to - body.from >= 2

    return hasRoom && !rows.some(each => each.key === keptOf(view)) ? [`${frameName(fixture)} at ${size.width}×${size.height}`] : []
  })

  expect(kept.map(({ fixture }) => frameName(fixture))).toContain('panel-unfolded-39x27')
  expect(kept.map(({ fixture }) => frameName(fixture))).toContain('panel-busy-73x15')
  expect(unseen).toEqual([])
})
