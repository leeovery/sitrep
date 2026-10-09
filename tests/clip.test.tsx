import type { ClientSurface, JsonValue, On, RenderPropsOf, UiScrollInput } from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import type { WorkMeta } from '../core'
import { stepOf, topShowing } from '../hooks/clip'
import Measure from '../hooks/draw/measure'
import { PANE } from '../hooks/pane'
import { rowsOf } from './drawn'
import { MIN, SLOW, T0, W2, yesAsk } from './support'
import { DOCKED, INLINE, postedId, PROJECT, toProject, world } from './world'

tier('user')

type World = ReturnType<typeof world>
type Pane = Awaited<ReturnType<World['pane']>>
type Drawn = { type?: string; props?: Record<string, unknown>; children?: unknown[] }

const BODY_ROWS = DOCKED.scroll.bodyRows

/** The rows Ready to send takes besides its lines: its border. */
const BORDER = 2

/** The rows each block is measured at, unless a test says otherwise. */
const ROWS = 3

/** Another session of the project, started in another window. */
const LEDGER: WorkMeta = {
  id: 'sr-1edger',
  name: 'Request ledger',
  summary: 'Request ledger, area by area',
  project: 'switchboard',
  root: '/Users/lee/Code/switchboard',
  created: T0,
  by: W2,
}

/** The board docked over a window of `bodyRows`. */
const docked = (bodyRows: number): RenderPropsOf['Pane'] => ({
  ...DOCKED,
  scroll: { offset: 0, bodyRows },
})

/** The work begun, and Claude asking `count` reviews: their ids, as asked. */
const asked = async (w: World, count: number) => {
  await w.begin()

  const ids: string[] = []

  for (let n = 1; n <= count; n += 1) {
    ids.push(
      postedId(await w.call('ask', { wants: 'yes', yes: 'Approve', title: `Review round ${n}` })),
    )
  }

  return ids
}

/** The work begun, Claude asking `count` reviews, and the board drawn: their ids, as asked. */
const asking = async (w: World, count: number, props = DOCKED) => ({
  ids: await asked(w, count),
  ui: await w.pane('terminal', props),
})

/** A board long enough to scroll (asks, a log, and things parked, as Claude posts them), drawn as `open` draws it. */
const long = async (w: World, open: () => Promise<Pane> = () => w.pane()) => {
  const ids = await asked(w, 4)

  for (let n = 1; n <= 6; n += 1) {
    await w.call('note', { text: `Step ${n} landed` })
  }

  for (let n = 1; n <= 3; n += 1) {
    await w.call('park', { title: `An idea to come back to, ${n}` })
  }

  return { ids, ui: await open() }
}

/** Lee approves an ask, opening it first where it is not open. */
const approve = async (ui: Pane, id: string) => {
  if ((await ui.find({ key: `yes:${id}` })) === undefined) {
    await ui.press({ key: `pick:${id}` })
  }

  await ui.press({ key: `yes:${id}` })
}

const boxes = async (ui: Pane) => (await ui.findAll({ type: 'Box' })).map(box => box.props)

/** The docked board's tree, the box its list is clipped in, and the list itself, shifted up. */
const clipping = async (ui: Pane) => {
  const all = await boxes(ui)

  return {
    tree: all[0],
    clip: all.find(props => props.overflow === 'hidden'),
    list: all.find(props => typeof props.marginTop === 'number'),
  }
}

/** How far down the list stands, as drawn. */
const topOf = async (ui: Pane) => 0 - Number((await clipping(ui)).list?.marginTop)

/**
 * Each block of the list, in order, posting the rows it takes as its
 * `Client` does once laid out: the kit lays a `Client` out but never hands
 * the plugin what it posts. The blocks' keys and rows, in order.
 */
const measure = async (ui: Pane, rows: (key: string) => number = () => ROWS) => {
  const blocks = (await ui.findAll({ type: 'Client' })).map(client => ({
    client: String(client.key),
    key: String((client.props.props as { id: string }).id),
  }))

  for (const { client, key } of blocks) {
    await ui.post({ id: key, rows: rows(key) }, { in: client })
  }

  return blocks.map(({ key }) => ({ key, rows: rows(key) }))
}

type Measured = Awaited<ReturnType<typeof measure>>

const sum = (blocks: Measured) => blocks.reduce((total, block) => total + block.rows, 0)

/** The rows above a block, and its own. */
const spanOf = (blocks: Measured, key: string) => {
  const at = blocks.findIndex(block => block.key === key)

  return { from: sum(blocks.slice(0, at)), to: sum(blocks.slice(0, at + 1)) }
}

/** The rows of the list showing above Ready to send, as drawn. */
const listRows = async (ui: Pane) => Number((await clipping(ui)).clip?.height)

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

/** Ready to send takes the rows of the window the list leaves it: each line it draws a row, cut short at the edge, never wrapped. */
const expectHeightKept = async (ui: Pane, scene: string, bodyRows = BODY_ROWS) => {
  const ready = await ui.find({ key: 'ready' })

  expect(bodyRows - (await listRows(ui)), scene).toBe(await drawnRows(ui))
  expect(textsIn(ready ?? {}).filter(isWrapping), scene).toEqual([])
}

/** The engine beneath the mod's scroll hook: each move it is asked to make. */
const beneath = (on: On) => {
  const moved: UiScrollInput[] = []

  on('ui.scroll', ($, e) => (moved.push(e), {}))
  on('ui.focus', () => ({}))

  return moved
}

/** Lee's move over the docked board's window, as the engine raises it over a tree a row short of it. */
const scrolled = (
  fields: Pick<UiScrollInput, 'by'> & Partial<UiScrollInput>,
  bodyRows = BODY_ROWS,
) =>
  ({
    component: 'Pane',
    requestId: PANE,
    offset: 0,
    bodyRows,
    contentRows: bodyRows - 1,
    origin: { kind: 'person' },
    ...fields,
  }) satisfies UiScrollInput as never

const WHEEL = { pointer: { column: 10, row: 12 } }

/** Lee's Tab, or an arrow, onto one of the board's buttons. */
const focused = (element: string) =>
  ({
    component: 'Pane',
    requestId: PANE,
    plugin: 'sitrep',
    element,
    origin: { kind: 'person' },
  }) as never

test('docked, the tree is a row short of the window; the list is clipped above Ready to send, which sits under it', async ($, on) => {
  const w = world($, on)
  const {
    ids: [id = ''],
    ui,
  } = await asking(w, 1)

  await approve(ui, id)

  const { tree, clip, list } = await clipping(ui)
  const [, foot] = ((await ui.findAll({ type: 'Box' }))[0]?.children ?? []) as Drawn[]

  expect(tree?.height).toBe(BODY_ROWS - 1)
  expect(clip).toMatchObject({ height: BODY_ROWS - (await drawnRows(ui)), overflow: 'hidden' })
  expect(list?.marginTop, 'at its top').toBe(-0)
  expect(rowsOf(foot as never)[0], 'Ready to send, under the list').toMatch(/READY TO SEND/)

  await ui.press({ key: 'cancel-all' })

  expect(await ui.find({ key: 'ready' })).toBeUndefined()
  expect((await clipping(ui)).clip?.height, 'with nothing in it, the list takes the tree').toBe(
    BODY_ROWS - 1,
  )
})

test('docked, each block of the list is measured by a Client spanning it, keyed by the block', async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await long(w)
  const clients = await ui.findAll({ type: 'Client' })
  const keys = clients.map(client => client.key)

  expect(new Set(keys).size).toBe(keys.length)
  expect(keys.slice(0, 4), 'the newest ask first').toEqual([
    'measure:ways',
    'measure:context',
    'measure:foryou',
    `measure:ask:${w.state.attachment?.work}:${ids.at(-1)}`,
  ])
  expect(keys.at(-1)).toBe('measure:end')
  expect(clients[0]?.props).toMatchObject({
    module: 'hooks/draw/measure.tsx',
    width: 1,
    height: '100%',
  })
})

/** The measuring module as a surface calls it, laid out at `rows`: what it posts, its state kept from call to call. */
const laidOut = () => {
  const posts: JsonValue[] = []
  let state: { rows: number } | undefined

  return {
    posts,
    at: (rows: number) =>
      Measure({ id: 'ways' }, {
        rows,
        get state() {
          return state
        },
        setState: (next: { rows: number }) => {
          state = next
        },
        post: (data: JsonValue) => posts.push(data),
        elements: { Box: () => ({ type: 'Box' }) },
      } as unknown as ClientSurface<{ rows: number }>),
  }
}

test("the measuring module posts its block's rows once laid out, and again only when they change", () => {
  const { posts, at } = laidOut()

  at(0)
  expect(posts, 'not laid out yet').toEqual([])

  at(2)
  at(2)
  at(3)
  expect(posts).toEqual([
    { id: 'ways', rows: 2 },
    { id: 'ways', rows: 3 },
  ])
})

test("the wheel moves the list and holds the engine's window at the top", async ($, on) => {
  const w = world($, on)
  const moved = beneath(on)
  const { ui } = await long(w)

  await measure(ui)
  await $.ui.scroll(scrolled({ by: 2, ...WHEEL }))
  await $.ui.scroll(scrolled({ by: 3, ...WHEEL }))
  await $.ui.scroll(scrolled({ by: -1, ...WHEEL }))

  expect(await topOf(ui)).toBe(4)
  expect(w.state.scroll).toEqual({
    place: { level: 'session', project: PROJECT.key, work: w.state.attachment?.work },
    top: 4,
  })
  expect(moved.map(e => e.offset)).toEqual([0, 0, 0])
})

test('the list stops at its end and its top, as its blocks measured it', async ($, on) => {
  const w = world($, on)

  beneath(on)
  const { ui } = await long(w)
  const blocks = await measure(ui)
  const end = sum(blocks) - (await listRows(ui))

  expect(end).toBeGreaterThan(0)

  await $.ui.scroll(scrolled({ by: 500, ...WHEEL }))
  expect(await topOf(ui)).toBe(end)
  expect(w.state.scroll?.top, 'kept at the end, not past it').toBe(end)

  await $.ui.scroll(scrolled({ by: -500, ...WHEEL }))
  expect(await topOf(ui)).toBe(0)
})

test('a page key moves by the rows showing above Ready to send; Home and End go to the ends; an arrow by its row', async ($, on) => {
  const w = world($, on)

  beneath(on)
  const {
    ids: [id = ''],
    ui,
  } = await long(w)

  await approve(ui, id)

  const blocks = await measure(ui)
  const showing = await listRows(ui)
  const end = sum(blocks) - showing

  await $.ui.scroll(scrolled({ by: BODY_ROWS }))
  expect(await topOf(ui), 'a page').toBe(showing)

  await $.ui.scroll(scrolled({ by: BODY_ROWS - 1 }))
  expect(await topOf(ui), 'End').toBe(end)

  await $.ui.scroll(scrolled({ by: -BODY_ROWS }))
  expect(await topOf(ui), 'a page back').toBe(end - showing)

  await $.ui.scroll(scrolled({ by: -(BODY_ROWS - 1) }))
  expect(await topOf(ui), 'Home').toBe(0)

  await $.ui.scroll(scrolled({ by: 1 }))
  expect(await topOf(ui), 'an arrow').toBe(1)
})

test('stepOf: the wheel as it turns; a page by the rows showing; Home and End to the ends', () => {
  const step = (fields: Partial<UiScrollInput> & Pick<UiScrollInput, 'by'>) =>
    stepOf(scrolled(fields) as UiScrollInput, 20)

  expect(step({ by: BODY_ROWS })).toBe(20)
  expect(step({ by: -BODY_ROWS })).toBe(-20)
  expect(step({ by: BODY_ROWS - 1 })).toBe(Infinity)
  expect(step({ by: -(BODY_ROWS - 1) })).toBe(-Infinity)
  expect(step({ by: BODY_ROWS, ...WHEEL }), 'a wheel crowded as far as a page').toBe(BODY_ROWS)
  expect(step({ by: -2 })).toBe(-2)
})

test('topShowing: the least move that shows the rows whole; rows more than show, from their first', () => {
  expect(topShowing(10, 14, 0, 20), 'showing already').toBe(0)
  expect(topShowing(30, 35, 0, 20), 'below').toBe(15)
  expect(topShowing(3, 6, 8, 20), 'above').toBe(3)
  expect(topShowing(40, 70, 0, 20), 'taller than the rows showing').toBe(40)
})

test('Tab onto a button below the fold brings its block into view, moving the least; one above, to its top', async ($, on) => {
  const w = world($, on)

  beneath(on)
  const {
    ids: [first = '', , , last = ''],
    ui,
  } = await long(w)

  await approve(ui, first)

  const parked = String(
    (await ui.findAll({ type: 'Button' })).findLast(button => button.key?.startsWith('ppick:'))
      ?.key,
  ).slice('ppick:'.length)
  const blocks = await measure(ui)
  const showing = await listRows(ui)
  const below = spanOf(blocks, `parked:${w.state.attachment?.work}:${parked}`)

  expect(below.to).toBeGreaterThan(showing)

  await $.ui.focus(focused(`ppick:${parked}`))
  expect(await topOf(ui)).toBe(below.to - showing)

  await $.ui.focus(focused(`pick:${last}`))
  expect(await topOf(ui)).toBe(spanOf(blocks, `ask:${w.state.attachment?.work}:${last}`).from)

  await $.ui.focus(focused('tab:all'))
  expect(await topOf(ui), 'the tabs').toBe(0)

  await $.ui.scroll(scrolled({ by: 7, ...WHEEL }))
  await $.ui.focus(focused('send'))
  expect(await topOf(ui), "Ready to send's own always show").toBe(7)
})

test('a new place starts at its top: All projects, a project, another session and home again; the board closed forgets it', async ($, on) => {
  const w = world($, on)

  beneath(on)
  w.elsewhere(LEDGER).write(yesAsk('k3', 'Review the ledger schema'))

  const { ids, ui } = await long(w, () => w.opened())
  // Blocks tall enough that every view, All projects' few among them, runs past the window.
  const down = async () => {
    await measure(ui, () => 10)
    await $.ui.scroll(scrolled({ by: 5, ...WHEEL }))
    expect(await topOf(ui)).toBe(5)
  }

  await down()
  await ui.press({ key: 'tab:all' })
  expect(await topOf(ui), 'All projects').toBe(0)

  await down()
  await ui.press({ key: `proj:${PROJECT.key}` })
  expect(await topOf(ui), 'the project').toBe(0)

  await down()
  await ui.press({ key: `go:${LEDGER.id}` })
  expect(await ui.find({ key: 'pick:k3' }), 'the other session drawn').toBeDefined()
  expect(await topOf(ui), 'another session').toBe(0)

  await down()
  await ui.press({ key: 'home' })
  expect(await topOf(ui), 'home').toBe(0)

  await down()
  await ui.press({ key: `pick:${ids[0]}` })
  expect(await topOf(ui), 'an item opened in place keeps it').toBe(5)

  await (await w.band()).press({ key: 'band:board' })
  expect(w.state.scroll, 'closed').toBeNull()
})

test(
  'queuing a reply, sending, a new ask arriving and the watch drawing again leave the list where Lee had it',
  SLOW,
  async ($, on) => {
    const w = world($, on)

    beneath(on)
    const {
      ids: [first = '', second = ''],
      ui,
    } = await long(w)

    await measure(ui)
    await $.ui.scroll(scrolled({ by: 6, ...WHEEL }))

    const kept = w.state.scroll

    await approve(ui, first)
    expect(await topOf(ui), 'queued').toBe(6)

    await ui.press({ key: `pick:${second}` })
    await ui.press({ key: `ignore:${second}` })
    await ui.press({ key: 'send' })
    expect(await topOf(ui), 'sent').toBe(6)

    await w.call('ask', { wants: 'yes', yes: 'Go', title: 'Give the go for stage 3' })
    expect(await topOf(ui), 'a new ask').toBe(6)

    await w.clock.advance(MIN)
    expect(await topOf(ui), 'the watch').toBe(6)
    expect(w.state.scroll).toEqual(kept)
  },
)

test('a list that shrinks under where it stands is stopped short at its new end', async ($, on) => {
  const w = world($, on)

  beneath(on)
  const { ui } = await long(w)
  const blocks = await measure(ui)

  await $.ui.scroll(scrolled({ by: 500, ...WHEEL }))
  await measure(ui, () => ROWS - 1)

  expect(await topOf(ui)).toBe(sum(blocks) - blocks.length - (await listRows(ui)))
})

test("inline, nothing is clipped or measured: Ready to send follows the view, and the engine's moves are its own", async ($, on) => {
  const w = world($, on)
  const moved = beneath(on)
  const {
    ids: [id = ''],
    ui,
  } = await asking(w, 1, INLINE)

  await approve(ui, id)

  const [root] = await boxes(ui)

  expect(root?.height).toBeUndefined()
  expect(root?.minHeight).toBeUndefined()
  expect((await clipping(ui)).clip).toBeUndefined()
  expect(await ui.findAll({ type: 'Client' })).toEqual([])
  expect(await ui.find({ key: 'ready' })).toBeDefined()

  await $.ui.scroll(scrolled({ by: 3, offset: 3, ...WHEEL }))
  expect(moved.map(e => e.offset)).toEqual([3])
  expect(w.writes.scroll).toBeUndefined()
})

test(
  'Ready to send takes the rows it draws under the list: a row for each line, cut short, and its border',
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
    await $.prompt.submit({
      text: 'a comment long enough to run past the edge of the box\nand a second line',
      wait: false,
      origin: { kind: 'composer' },
    })
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

test('replies sent into another work keep the box as tall as it draws, where they stand on its lines', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))

  await w.begin()
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: 'pick:k3' })
  await ui.press({ key: 'yes:k3' })
  await ui.press({ key: 'home' })
  await ui.press({ key: 'send' })

  expect(await ui.find({ type: 'Text', text: '⧗ waiting for its turn to end' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()
  await expectHeightKept(ui, 'sent, on its way')
})

test("a project's view keys each ask's block by its work too, so two works' asks of one id never share a Client", async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))

  const { paths } = await w.begin()

  w.writer(paths)(yesAsk('k3', 'Review the dashboard'))
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()

  await toProject(ui)

  const keys = (await ui.findAll({ type: 'Client' })).map(client => client.key)

  expect(keys).toContain(`measure:ask:${LEDGER.id}:k3`)
  expect(keys).toContain(`measure:ask:${w.state.attachment?.work}:k3`)
  expect(new Set(keys).size).toBe(keys.length)
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

    await ui.redraw(docked(60))
    expect(await listed()).toHaveLength(6)
    expect(await ui.find({ type: 'Text', text: /more$/ })).toBeUndefined()
    await expectHeightKept(ui, 'room for every one', 60)
  },
)
