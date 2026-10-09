import type { On, RenderPropsOf, UiScrollInput } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import type { WorkMeta } from '../core'
import { drewBoard, followFocus } from '../hooks/float'
import type { Host } from '../hooks/host'
import { C } from '../hooks/look'
import { PANE } from '../hooks/pane'
import { rowsOf } from './drawn'
import { ask, MIN, SLOW, T0, W2 } from './support'
import { DOCKED, INLINE, postedId, world } from './world'

tier('user')

/** For a test that posts and answers many asks: past the default 5s on a loaded machine. */

type World = ReturnType<typeof world>
type Pane = Awaited<ReturnType<World['pane']>>
type Drawn = { type?: string; props?: Record<string, unknown>; children?: unknown[] }

const BODY_ROWS = DOCKED.scroll.bodyRows

/** The rows Ready to send takes besides its lines: its border. */
const BORDER = 2

/** The board docked, its window `offset` rows down, over a body of `bodyRows`. */
const at = (offset: number, bodyRows = BODY_ROWS): RenderPropsOf['Pane'] => ({
  ...DOCKED,
  scroll: { offset, bodyRows },
})

/** The work begun, Claude asking `count` reviews, and the board drawn: their ids, as asked. */
const asking = async (w: World, count: number, props = DOCKED) => {
  await w.begin()

  const ids: string[] = []

  for (let n = 1; n <= count; n += 1) {
    ids.push(postedId(await w.call('ask', { kind: 'review', title: `Review round ${n}` })))
  }

  return { ids, ui: await w.pane('terminal', props) }
}

/** Lee approves an ask, opening it first where it is not open. */
const approve = async (ui: Pane, id: string) => {
  if ((await ui.find({ key: `yes:${id}` })) === undefined) {
    await ui.press({ key: `pick:${id}` })
  }

  await ui.press({ key: `yes:${id}` })
}

const root = async (ui: Pane) => (await ui.findAll({ type: 'Box' }))[0]

const floating = async (ui: Pane) =>
  (await ui.findAll({ type: 'Box' })).find(box => box.props.position === 'absolute')

/** The rows the floating box covers, by where it sits: the window's foot less its top. */
const coveredRows = async (ui: Pane, { scroll } = DOCKED) =>
  scroll.offset + scroll.bodyRows - Number((await floating(ui))?.props.top)

/** The rows Ready to send draws: each of its lines, as tests/drawn lays them out, and its border. */
const drawnRows = async (ui: Pane) => rowsOf(await ui.find({ key: 'ready' })).length + BORDER

const textsIn = (element: Drawn): Drawn[] =>
  (element.children ?? []).flatMap(child =>
    typeof child === 'object' && child !== null
      ? [...((child as Drawn).type === 'Text' ? [child as Drawn] : []), ...textsIn(child as Drawn)]
      : [],
  )

/** A Text that could take more than its row: one of more than a cell, not cut short. */
const isWrapping = (text: Drawn) =>
  text.props?.wrap !== 'truncate-end' && [...String(text.children?.join('') ?? '')].length > 1

/** Ready to send is as tall as `coveredRows` says: each line it draws takes a row, cut short at the edge, never wrapped. */
const expectHeightKept = async (ui: Pane, scene: string) => {
  const ready = await ui.find({ key: 'ready' })

  expect(await coveredRows(ui), scene).toBe(await drawnRows(ui))
  expect(textsIn(ready ?? {}).filter(isWrapping), scene).toEqual([])
}

/** The engine beneath the mod's scroll hook: each move it is asked to make. */
const beneath = (on: On) => {
  const moved: UiScrollInput[] = []

  on('ui.scroll', ($, e) => (moved.push(e), {}))

  return moved
}

/** A person's move over the board's window, as the engine raises it. */
const scrolled = (fields: Pick<UiScrollInput, 'by' | 'offset'> & Partial<UiScrollInput>) =>
  ({
    component: 'Pane',
    requestId: PANE,
    bodyRows: BODY_ROWS,
    contentRows: 100,
    origin: { kind: 'person' },
    ...fields,
  }) satisfies UiScrollInput as never

const WHEEL = { pointer: { column: 10, row: 12 } }

test('Ready to send floats over the foot of a docked board wherever the engine has scrolled it', async ($, on) => {
  const w = world($, on)
  const {
    ids: [id = ''],
    ui,
  } = await asking(w, 1)

  await approve(ui, id)

  const rows = await drawnRows(ui)

  for (const offset of [0, 7, 20]) {
    await ui.redraw(at(offset))

    const [, spacer] = ((await root(ui))?.children ?? []) as Drawn[]

    expect((await floating(ui))?.props.top, `offset ${offset}`).toBe(offset + BODY_ROWS - rows)
    expect((await root(ui))?.props.minHeight, `offset ${offset}`).toBe(offset + BODY_ROWS)
    expect(spacer?.props?.height, `the last line clears it, offset ${offset}`).toBe(rows + 1)
  }

  expect((await ui.find({ key: 'ready' }))?.props.backgroundColor).toBe(C.pane)
})

test(
  'the floating box is as tall as Ready to send draws: a row for each line, cut short, and its border',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const {
      ids: [first = '', second = '', third = ''],
      ui,
    } = await asking(w, 3)

    await approve(ui, first)
    await expectHeightKept(ui, 'one reply')

    await approve(ui, second)
    await ui.press({ key: `pick:${third}` })
    await ui.press({ key: `comment:${third}` })
    await ui.key({
      key: 'a comment long enough to run past the edge of the box',
      in: `area:${third}`,
    })
    await ui.key({ key: 'return', shift: true, in: `area:${third}` })
    await ui.key({ key: 'and a second line', in: `area:${third}` })
    await ui.press({ key: `save:${third}` })
    await expectHeightKept(ui, 'three replies, a comment of two lines among them')

    const turn = w.holdPrompts()
    const pressed = ui.press({ key: 'send' })

    await turn.arrived
    expect(await ui.find({ type: 'Text', text: /⧗ Sending/ })).toBeDefined()
    await expectHeightKept(ui, 'a send on its way')

    turn.end()
    await pressed
  },
)

const LEDGER: WorkMeta = {
  id: 'sr-1edger',
  name: 'Request ledger',
  summary: 'Request ledger, area by area',
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created: T0,
  by: W2,
}

test('replies sent into another work keep the box as tall as it draws, where they stand on its lines', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(ask('k3', 'review', 'Review the ledger schema'))

  await w.begin()
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()

  await ui.press({ key: 'tab:project' })
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: 'pick:k3' })
  await ui.press({ key: 'yes:k3' })
  await ui.press({ key: 'home' })
  await ui.press({ key: 'send' })

  expect(await ui.find({ type: 'Text', text: '⧗ waiting for its turn to end' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()
  await expectHeightKept(ui, 'sent, on its way')
})

test('with nothing in Ready to send nothing floats, and the board is laid out as it was', async ($, on) => {
  const w = world($, on)
  const { ui } = await asking(w, 1)

  expect(await floating(ui)).toBeUndefined()
  expect(await ui.find({ key: 'ready' })).toBeUndefined()
  expect((await root(ui))?.props.minHeight).toBe(BODY_ROWS)
  expect((await ui.findAll({ type: 'Box' })).some(box => box.props.flexGrow === 1)).toBe(true)
})

test('inline, Ready to send sits at the end of the view, never floating', async ($, on) => {
  const w = world($, on)
  const {
    ids: [id = ''],
    ui,
  } = await asking(w, 1, INLINE)

  await approve(ui, id)

  const ready = await ui.find({ key: 'ready' })

  expect(ready).toBeDefined()
  expect(await floating(ui)).toBeUndefined()
  expect((await root(ui))?.props.minHeight).toBeUndefined()
  expect(ready?.props.backgroundColor).toBeUndefined()
})

test(
  'a queue too long for under half the window is cut short: the box lists what fits, then how many more',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { ids, ui } = await asking(w, 6)

    for (const id of ids) {
      await approve(ui, id)
    }

    const listed = async () =>
      (await ui.findAll({ type: 'Text', text: /^Review round \d$/ }))
        .filter(text => text.props.wrap === 'truncate-end')
        .map(text => text.text)

    expect(await listed()).toEqual(['Review round 1', 'Review round 2', 'Review round 3'])
    expect(await ui.find({ type: 'Text', text: '… 3 more' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '6 replies' })).toBeDefined()
    expect(await ui.find({ key: 'send' })).toBeDefined()
    expect(await drawnRows(ui)).toBeLessThanOrEqual(Math.floor((BODY_ROWS - 1) / 2))
    await expectHeightKept(ui, 'cut short')

    const tall = at(0, 60)

    await ui.redraw(tall)
    expect(await listed()).toHaveLength(6)
    expect(await ui.find({ type: 'Text', text: /more$/ })).toBeUndefined()
    expect(await coveredRows(ui, tall)).toBe(await drawnRows(ui))
  },
)

test('while a field is open, Ready to send keeps to the foot of the view rather than float over it', async ($, on) => {
  const w = world($, on)
  const {
    ids: [first = '', second = ''],
    ui,
  } = await asking(w, 2)

  await approve(ui, first)
  expect(await floating(ui)).toBeDefined()

  await ui.press({ key: `pick:${second}` })
  await ui.press({ key: `comment:${second}` })
  expect(await floating(ui)).toBeUndefined()
  expect(await ui.find({ key: 'ready' })).toBeDefined()

  await ui.press({ key: `cancel:${second}` })
  expect(await floating(ui)).toBeDefined()
})

test('a page key moves by the rows above the box while it floats; the wheel, the arrows, Home and End as asked', async ($, on) => {
  const w = world($, on)
  const moved = beneath(on)
  const {
    ids: [id = ''],
    ui,
  } = await asking(w, 1)

  await approve(ui, id)
  await ui.redraw(at(8))

  const above = BODY_ROWS - (await coveredRows(ui, at(8)))

  await $.ui.scroll(scrolled({ by: BODY_ROWS, offset: 8 + BODY_ROWS }))
  await $.ui.scroll(scrolled({ by: -BODY_ROWS, offset: 0 }))
  await $.ui.scroll(scrolled({ by: 2, offset: 10, ...WHEEL }))
  await $.ui.scroll(scrolled({ by: 1, offset: 9 }))
  await $.ui.scroll(scrolled({ by: 100, offset: 70 }))
  await $.ui.scroll(
    scrolled({ by: BODY_ROWS, offset: 38, origin: { kind: 'plugin', name: 'other' } }),
  )

  expect(moved.map(e => e.offset)).toEqual([8 + above, Math.max(0, 8 - above), 10, 9, 70, 38])

  await ui.press({ key: 'cancel-all' })
  await $.ui.scroll(scrolled({ by: BODY_ROWS, offset: 8 + BODY_ROWS }))
  expect(moved.at(-1)?.offset, 'nothing floats').toBe(8 + BODY_ROWS)
})

/** A host whose display records what the board asks of it as the focus moves. */
const display = () => {
  const revealed: string[][] = []
  const drawn = { again: 0 }
  const host = {
    ui: {
      reveal: async (pane: string, key: string) => (revealed.push([pane, key]), {}),
      redraw: () => {
        drawn.again += 1
      },
    },
  } as unknown as Host

  return { host, revealed, drawn }
}

test("the focus landing on a board button brings it to the window's middle while the box floats, and the board is drawn again", async () => {
  const { host, revealed, drawn } = display()

  drewBoard({ offset: 0, bodyRows: BODY_ROWS }, 0)
  await followFocus(host, 'pick:k1')
  expect(revealed, 'nothing floats').toEqual([])
  expect(drawn.again, 'nothing floats').toBe(0)

  drewBoard({ offset: 6, bodyRows: BODY_ROWS }, 9)

  for (const element of ['pick:k1', 'send', 'cancel-all', 'unready:k1', undefined]) {
    await followFocus(host, element)
  }

  expect(revealed, "the box's own always show").toEqual([[PANE, 'pick:k1']])
  expect(drawn.again, 'the engine may have moved the window itself, unasked').toBe(5)
})

test('opening the board, queuing a reply and sending never scroll it', async ($, on) => {
  const w = world($, on)

  await w.begin()

  const id = postedId(await w.call('ask', { kind: 'review', title: 'Review round 1' }))
  const ui = await w.opened()

  await approve(ui, id)
  await ui.redraw(at(5))
  await ui.press({ key: 'send' })

  // The kit has no window for a plugin's scroll to move: one the board asked for fails, and the log says so.
  expect(w.logs.filter(line => line.includes('scroll'))).toEqual([])
})
