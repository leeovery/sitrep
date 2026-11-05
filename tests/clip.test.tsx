import type {
  ClientSurface,
  JsonValue,
  On,
  RenderPropsOf,
  UiFocusInput,
  UiFocusOrigin,
  UiScrollInput,
} from 'claude-code'
import { expect, test, tier } from 'claude-code/testing'
import type { SessionMeta } from '../core'
import { stepOf, topShowing } from '../hooks/clip'
import Measure from '../hooks/draw/measure'
import { STEP_HELD } from '../hooks/draw/ready'
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

/** The rows the header takes in every view: the tabs, their rule, and the way back's row. */
const HEADER = 3

/** The rows each block is measured at, unless a test says otherwise. */
const ROWS = 3

/** Another session of the project, started in another window. */
const LEDGER: SessionMeta = {
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

/** The session begun, and Claude asking `count` reviews: their ids, as asked. */
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

/** The session begun, Claude asking `count` reviews, and the board drawn: their ids, as asked. */
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

/** Lee approves an ask, by its address, opening it first where it is not open. */
const approve = async (ui: Pane, item: string) => {
  if ((await ui.find({ key: `yes:${item}` })) === undefined) {
    await ui.press({ key: `pick:${item}` })
  }

  await ui.press({ key: `yes:${item}` })
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

/** The Clients measuring the list's blocks, in order: not the header's, which says where the board sits. */
const measuring = async (ui: Pane) =>
  (await ui.findAll({ type: 'Client' })).filter(
    client => client.props.module === 'hooks/draw/measure.tsx',
  )

/**
 * Each block of the list, in order, posting the rows it takes as its
 * `Client` does once laid out: the kit lays a `Client` out with no rows,
 * so a measuring one never posts there. The blocks' keys and rows, in order.
 */
const measure = async (ui: Pane, rows: (key: string) => number = () => ROWS) => {
  const blocks = (await measuring(ui)).map(client => ({
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

/** The rows of the list showing between the header and Ready to send, as drawn. */
const listRows = async (ui: Pane) => Number((await clipping(ui)).clip?.height)

/** The rows the header draws: the tabs, their rule, and the way back's row under it. */
const headerRows = async (ui: Pane) => rowsOf(await ui.find({ key: 'header' })).length

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

  expect(bodyRows - (await headerRows(ui)) - (await listRows(ui)), scene).toBe(await drawnRows(ui))
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

/** The focus moved onto one of the board's buttons: by Lee's Tab or an arrow, unless a plugin moved it. */
const focused = (element: string, origin: UiFocusOrigin = { kind: 'person' }) =>
  ({
    component: 'Pane',
    requestId: PANE,
    plugin: 'sitrep',
    element,
    origin,
  }) satisfies UiFocusInput as never

test('docked, the tree is a row short of the window; the list is clipped between the header and Ready to send, which sit still', async ($, on) => {
  const w = world($, on)
  const {
    ids: [id = ''],
    ui,
  } = await asking(w, 1)

  await approve(ui, w.item(id))

  const { tree, clip, list } = await clipping(ui)
  const [head, , foot] = ((await ui.findAll({ type: 'Box' }))[0]?.children ?? []) as Drawn[]
  const lit = '━'.repeat(' ⌂ Dashboard redesign 1 '.length)

  expect(tree?.height).toBe(BODY_ROWS - 1)
  expect(rowsOf(head as never), 'the header, over the list').toEqual([
    '  ⌂ Dashboard redesign 1  ≡ All projects 1',
    ` ${lit}${'─'.repeat(DOCKED.bodyColumns - 2 - lit.length)}`,
    '',
  ])
  expect(clip).toMatchObject({
    height: BODY_ROWS - HEADER - (await drawnRows(ui)),
    overflow: 'hidden',
  })
  expect(list?.marginTop, 'at its top').toBe(-0)
  expect(rowsOf(foot as never)[0], 'Ready to send, under the list').toMatch(/READY TO SEND/)

  await ui.press({ key: 'cancel-all' })

  expect(await ui.find({ key: 'ready' })).toBeUndefined()
  expect(
    (await clipping(ui)).clip?.height,
    'with nothing in it, the list takes the tree under the header',
  ).toBe(BODY_ROWS - 1 - HEADER)
})

test(
  "docked, the header is the same in every view, the way back in its last row; every view's list holds Ready to send still and reaches its end",
  SLOW,
  async ($, on) => {
    const w = world($, on)

    beneath(on)
    w.elsewhere(LEDGER).write(yesAsk('k3', 'Review the ledger schema'))

    const {
      ids: [id = ''],
      ui,
    } = await long(w, () => w.opened())

    await approve(ui, w.item(id))

    const places = [
      { name: 'home', reach: async () => undefined },
      { name: 'All projects', reach: () => ui.press({ key: 'tab:all' }) },
      { name: 'the project', reach: () => toProject(ui), back: '← All projects' },
      {
        name: 'another session',
        reach: () => ui.press({ key: `go:${LEDGER.id}` }),
        back: '← Switchboard',
      },
    ]
    let tabs: string | undefined

    for (const { name, reach, back } of places) {
      await reach()

      // Blocks tall enough that every view, All projects' few among them, runs past the window.
      const blocks = await measure(ui, () => 10)
      const [row, rule, ...rest] = rowsOf(await ui.find({ key: 'header' }))

      tabs ??= row
      expect([row, rest], `${name}: the tabs as at home, then the rule and the way back`).toEqual([
        tabs,
        [back ?? ''],
      ])
      expect(rule, name).toMatch(/^[━─]+$/)
      expect(
        rowsOf(await ui.find({ key: 'block:context' })).join('\n'),
        `${name}: none on the title line`,
      ).not.toContain('←')
      await expectHeightKept(ui, name)

      await $.ui.scroll(scrolled({ by: 500, ...WHEEL }))
      expect(await topOf(ui), `${name}: at the list's end`).toBe(sum(blocks) - (await listRows(ui)))
      expect(rowsOf(await ui.find({ key: 'ready' }))[0], `${name}: Ready to send, still`).toMatch(
        /READY TO SEND/,
      )
    }

    expect(await ui.find({ type: 'Client', key: 'measure:header' })).toBeUndefined()
  },
)

test('docked, each block of the list is measured by a Client spanning it, keyed by the block', async ($, on) => {
  const w = world($, on)
  const { ids, ui } = await long(w)
  const clients = await measuring(ui)
  const keys = clients.map(client => client.key)

  expect(new Set(keys).size).toBe(keys.length)
  expect(keys.slice(0, 3), 'the header unmeasured, the newest ask first').toEqual([
    'measure:context',
    'measure:asks',
    `measure:ask:${w.item(ids.at(-1) ?? '')}`,
  ])
  expect(keys.at(-1)).toBe('measure:end')
  expect(clients[0]?.props).toMatchObject({
    module: 'hooks/draw/measure.tsx',
    width: 1,
    height: '100%',
  })
})

test("the header's placement Client takes a cell of the column kept free beside the tabs, and no rows, docked and inline", async ($, on) => {
  const w = world($, on)

  await w.begin()

  for (const props of [DOCKED, INLINE]) {
    const ui = await w.pane('terminal', props)

    expect((await ui.find({ key: 'placement:box' }))?.props, props.placement).toMatchObject({
      position: 'absolute',
      top: 0,
      left: -1,
      width: 1,
      height: 1,
    })
    expect((await ui.find({ type: 'Client', key: 'placement' }))?.props).toMatchObject({
      module: 'hooks/draw/placement.tsx',
      width: 1,
      height: 1,
      props: { placement: props.placement },
    })
    expect(await ui.drawn({ in: 'placement' }), 'drawing nothing').toMatchObject({
      type: 'Box',
      props: { width: 1 },
    })
    expect(await headerRows(ui), props.placement).toBe(HEADER)
    await ui.unmount()
  }
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
    place: { level: 'session', project: PROJECT.key, session: w.state.attachment?.session },
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

  await approve(ui, w.item(id))

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

test("Tab onto a button below the fold brings its block into view, moving the least; one above, to its top; the header's never move it", async ($, on) => {
  const w = world($, on)

  beneath(on)
  const {
    ids: [first = '', , , last = ''],
    ui,
  } = await long(w)

  await approve(ui, w.item(first))

  const parked = String(
    (await ui.findAll({ type: 'Button' })).findLast(button => button.key?.startsWith('ppick:'))
      ?.key,
  ).slice('ppick:'.length)
  const blocks = await measure(ui)
  const showing = await listRows(ui)
  const below = spanOf(blocks, `parked:${parked}`)

  expect(below.to).toBeGreaterThan(showing)

  await $.ui.focus(focused(`ppick:${parked}`))
  expect(await topOf(ui)).toBe(below.to - showing)

  await $.ui.focus(focused(`pick:${w.item(last)}`))

  const above = spanOf(blocks, `ask:${w.item(last)}`).from

  expect(above).toBeGreaterThan(0)
  expect(await topOf(ui)).toBe(above)

  for (const element of ['tab:session', 'tab:all', 'send']) {
    await $.ui.focus(focused(element))
    expect(await topOf(ui), `${element}: the header's and Ready to send's always show`).toBe(above)
  }
})

test("only Lee's own focus moves bring a button into view: a plugin's never moves the list", async ($, on) => {
  const w = world($, on)

  beneath(on)
  const { ui } = await long(w)
  const parked = String(
    (await ui.findAll({ type: 'Button' })).findLast(button => button.key?.startsWith('ppick:'))
      ?.key,
  )

  await measure(ui)
  await $.ui.focus(focused(parked, { kind: 'plugin', name: 'sitrep' }))
  expect(await topOf(ui), "a plugin's").toBe(0)

  await $.ui.focus(focused(parked))
  expect(await topOf(ui), "Lee's").toBeGreaterThan(0)
})

test('a click on a button whose item starts above the fold leaves the list where it is', async ($, on) => {
  const w = world($, on)

  beneath(on)
  const {
    ids: [, , , last = ''],
    ui,
  } = await long(w)
  const blocks = await measure(ui, () => 10)
  const opened = spanOf(blocks, `ask:${w.item(last)}`)

  await $.ui.scroll(scrolled({ by: opened.from + 4, ...WHEEL }))
  expect(await ui.find({ key: `ignore:${w.item(last)}` }), 'its button drawn').toBeDefined()

  await ui.press({ key: `ignore:${w.item(last)}` })
  expect(await topOf(ui)).toBe(opened.from + 4)
})

test('docked, a header button the focus reaches never moves the list: the lit tab, the lit All projects, the way back', async ($, on) => {
  const w = world($, on)

  beneath(on)
  w.elsewhere(LEDGER).write(yesAsk('k3', 'Review the ledger schema'))

  const { ui } = await long(w, () => w.opened())

  await measure(ui, () => 10)
  await $.ui.scroll(scrolled({ by: 5, ...WHEEL }))
  await $.ui.focus(focused('tab:session'))
  expect(await topOf(ui), 'the lit tab, reached').toBe(5)

  await toProject(ui)
  await measure(ui, () => 10)
  await $.ui.scroll(scrolled({ by: 4, ...WHEEL }))
  await $.ui.focus(focused('tab:all'))
  expect(await topOf(ui), 'the lit All projects, reached').toBe(4)
  await $.ui.focus(focused('up'))
  expect(await topOf(ui), 'the way back, reached').toBe(4)
})

test(
  'each place starts at its top, every time: by a tab, the way back, a session or a project, a band count though it lands where the board is; an item opened keeps it',
  SLOW,
  async ($, on) => {
    const w = world($, on)

    beneath(on)
    w.elsewhere(LEDGER).write(yesAsk('k3', 'Review the ledger schema'))

    const { ids, ui } = await long(w, () => w.opened())
    const band = await w.band()
    // Blocks tall enough that every view, All projects' few among them, runs past the window.
    const down = async () => {
      await measure(ui, () => 10)
      await $.ui.scroll(scrolled({ by: 5, ...WHEEL }))
      expect(await topOf(ui)).toBe(5)
    }
    /** How far down the list stands once its blocks have posted their rows, as their Clients do as it draws. */
    const settled = async () => {
      await measure(ui, () => 10)

      return topOf(ui)
    }

    await down()
    await ui.press({ key: 'tab:all' })
    expect(await settled(), 'All projects').toBe(0)
    await ui.press({ key: 'tab:session' })
    expect(await settled(), 'home again, not where it was left').toBe(0)

    await down()
    await ui.press({ key: 'tab:session' })
    expect(await settled(), 'home, its tab pressed there').toBe(0)

    await ui.press({ key: 'tab:all' })
    await down()
    await ui.press({ key: `proj:${PROJECT.key}` })
    expect(await settled(), 'the project').toBe(0)

    await down()
    await ui.press({ key: `go:${LEDGER.id}` })
    expect(await ui.find({ key: `pick:${LEDGER.id}:k3` }), 'the other session drawn').toBeDefined()
    expect(await settled(), 'another session').toBe(0)
    await ui.press({ key: 'up' })
    expect(await settled(), 'the project again, by the way back').toBe(0)

    await ui.press({ key: 'tab:all' })
    await down()
    await ui.press({ key: 'tab:session' })
    await band.press({ key: 'band:elsewhere' })
    expect(await settled(), 'All projects again, by its count on the band').toBe(0)

    await ui.press({ key: 'tab:session' })
    await down()
    await band.press({ key: 'band:asks' })
    expect(w.state.pane?.place ?? null, 'home already').toBeNull()
    expect(await settled(), 'home, by its count on the band, though the board was home').toBe(0)

    await down()
    await ui.press({ key: `pick:${w.item(ids[0] ?? '')}` })
    expect(await settled(), 'an item opened in place keeps it').toBe(5)

    await band.press({ key: 'band:board' })
    expect(w.state.scroll, 'closed').toBeNull()
  },
)

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

    await approve(ui, w.item(first))
    expect(await topOf(ui), 'queued').toBe(6)

    await ui.press({ key: `pick:${w.item(second)}` })
    await ui.press({ key: `ignore:${w.item(second)}` })
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

  await approve(ui, w.item(id))

  const [root] = await boxes(ui)

  expect(root?.height).toBeUndefined()
  expect(root?.minHeight).toBeUndefined()
  expect((await clipping(ui)).clip).toBeUndefined()
  expect(await measuring(ui)).toEqual([])
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

    await approve(ui, w.item(first))
    await expectHeightKept(ui, 'one reply')

    await approve(ui, w.item(second))
    await ui.press({ key: `pick:${w.item(third)}` })
    await ui.press({ key: `comment:${w.item(third)}` })
    await $.prompt.submit({
      text: 'a comment long enough to run past the edge of the box\nand a second line',
      wait: false,
      origin: { kind: 'composer' },
    })
    await expectHeightKept(ui, 'three replies, a comment of two lines among them')

    await w.turnStarts('Carry on.')
    await ui.press({ key: 'send' })
    expect(await ui.find({ key: w.takeBack() })).toBeDefined()
    await expectHeightKept(ui, 'a send held for the turn to end, its take-back beside it')

    const turn = w.holdPrompts()
    const ended = w.turnEnds()

    await turn.arrived
    expect(await ui.find({ type: 'Text', text: /⧗ Sending/ })).toBeDefined()
    await expectHeightKept(ui, 'a send on its way')

    turn.end()
    await ended
  },
)

test('replies sent into another session keep the box as tall as it draws, where they stand on its lines', async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))

  await w.begin()
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()

  await toProject(ui)
  await ui.press({ key: `go:${LEDGER.id}` })
  await ui.press({ key: `pick:${LEDGER.id}:k3` })
  await ui.press({ key: `yes:${LEDGER.id}:k3` })
  await ui.press({ key: 'tab:session' })
  await ui.press({ key: 'send' })

  expect(await ui.find({ type: 'Text', text: '⧗ waiting for its turn to end' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: '· on its way' })).toBeDefined()
  await expectHeightKept(ui, 'sent, on its way')
})

test("a project's view keys each ask by its session too, so two sessions' asks of one id never share a Client, a selection or a button", async ($, on) => {
  const w = world($, on)
  const ledger = w.elsewhere(LEDGER)

  ledger.write(yesAsk('k3', 'Review the ledger schema'))

  const { paths } = await w.begin()

  w.writer(paths)(yesAsk('k3', 'Review the dashboard'))
  await w.clock.advance(MIN)
  ledger.beat()

  const ui = await w.opened()
  const here = w.item('k3')
  const there = w.item('k3', LEDGER.id)

  await toProject(ui)

  const keys = (await ui.findAll({ type: 'Client' })).map(client => client.key)

  expect(keys).toContain(`measure:ask:${there}`)
  expect(keys).toContain(`measure:ask:${here}`)
  expect(new Set(keys).size).toBe(keys.length)

  await ui.press({ key: `pick:${here}` })
  expect(await ui.find({ key: `yes:${here}` }), 'this session’s opened').toBeDefined()
  expect(await ui.find({ key: `yes:${there}` }), 'the ledger’s left closed').toBeUndefined()

  await ui.press({ key: `yes:${here}` })
  await ui.press({ key: `pick:${there}` })
  expect(await ui.find({ key: `yes:${here}` }), 'only one opened at a time').toBeUndefined()
  await ui.press({ key: `yes:${there}` })
  expect(w.state.queue).toEqual([
    { project: PROJECT.key, session: w.state.attachment?.session, item: 'k3', verdict: 'yes' },
    { project: PROJECT.key, session: LEDGER.id, item: 'k3', verdict: 'yes' },
  ])

  await ui.press({ key: `undo:${there}` })
  expect(w.state.queue, 'the ledger’s undone, this session’s kept').toEqual([
    { project: PROJECT.key, session: w.state.attachment?.session, item: 'k3', verdict: 'yes' },
  ])

  await ui.press({ key: `yes:${there}` })
  await ui.press({ key: `unready:${here}` })
  expect(w.state.queue, 'out of Ready to send: this session’s, the ledger’s kept').toEqual([
    { project: PROJECT.key, session: LEDGER.id, item: 'k3', verdict: 'yes' },
  ])
})

test(
  'a queue too long for under half the window is cut short: the box lists what fits, then how many more',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { ids, ui } = await asking(w, 6)

    for (const id of ids) {
      await approve(ui, w.item(id))
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

test(
  'a send held and the queue under it keep the box as tall as it draws; too long for under half the window, the send keeps its heading, its line and its take-back, what fits is listed, then how many more; a second send is one row under it, with its own take-back',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { ids, ui } = await asking(w, 6)
    const cap = Math.floor((BODY_ROWS - 1) / 2)

    for (const id of ids.slice(0, 3)) {
      await approve(ui, w.item(id))
    }

    await w.turnStarts('Carry on.')
    await ui.press({ key: 'send' })

    for (const id of ids.slice(3)) {
      await approve(ui, w.item(id))
    }

    expect(await ui.find({ key: w.takeBack() })).toBeDefined()
    expect(await ui.find({ key: 'send' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '… 4 more' })).toBeDefined()
    expect(await drawnRows(ui)).toBeLessThanOrEqual(cap)
    await expectHeightKept(ui, 'a send held, and the queue under it, cut short')

    await ui.press({ key: 'send' })

    expect(await ui.find({ key: w.takeBack(0) })).toBeDefined()
    expect(await ui.find({ key: w.takeBack(1) })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '⧗ Then: Review round 4 +2' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /more$/ }), 'the brief row names them').toBeUndefined()
    expect(await drawnRows(ui)).toBeLessThanOrEqual(cap)
    await expectHeightKept(ui, 'two sends held, cut short')

    await ui.redraw(docked(60))
    expect(await ui.find({ type: 'Text', text: /more$/ })).toBeUndefined()
    await expectHeightKept(ui, 'two sends held, room for both', 60)
  },
)

test(
  'three sends held and a reply under them, too long for under half the window: the first send in full as far as it fits, each after it one row with its own take-back, then how many more; a take-back of one of those puts its replies back',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const { ids, ui } = await asking(w, 10)
    const cap = Math.floor((BODY_ROWS - 1) / 2)
    const approveAll = async (from: number, to: number) => {
      for (const id of ids.slice(from, to)) {
        await approve(ui, w.item(id))
      }
    }

    await approveAll(0, 3)
    await w.turnStarts('Carry on.')
    await ui.press({ key: 'send' })
    await approveAll(3, 6)
    await ui.press({ key: 'send' })
    await approveAll(6, 9)
    await ui.press({ key: 'send' })
    await approveAll(9, 10)

    expect(w.flights()).toHaveLength(3)

    for (const at of [0, 1, 2]) {
      expect(await ui.find({ key: w.takeBack(at) }), `the take-back of send ${at + 1}`).toBeDefined()
    }

    expect(await ui.find({ type: 'Text', text: "⧗ Waiting for Claude's turn to end." })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '⧗ Then: Review round 4 +2' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '⧗ Then: Review round 7 +2' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: '… 3 more' })).toBeDefined()
    expect(await ui.find({ key: 'send' })).toBeDefined()
    expect(await drawnRows(ui)).toBeLessThanOrEqual(cap)
    await expectHeightKept(ui, 'three sends held and a reply, cut short')

    await ui.press({ key: w.takeBack(2) })

    expect(w.flights()).toHaveLength(2)
    expect(await ui.find({ type: 'Text', text: /^⧗ Then: Review round 7/ })).toBeUndefined()
    expect(await drawnRows(ui)).toBeLessThanOrEqual(cap)
    await expectHeightKept(ui, 'two sends held and four replies, cut short')

    await ui.redraw(docked(80))
    expect(await ui.find({ type: 'Text', text: /^⧗ Then/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: /more$/ })).toBeUndefined()
    await expectHeightKept(ui, 'room for every send', 80)
  },
)

test(
  'five sends held in a window too short for a row each: the first in full, a row for each after it that fits but one, then one row standing for the rest, stepping through them, so every take-back is in reach; a take-back from it puts that send back',
  SLOW,
  async ($, on) => {
    const w = world($, on)
    const short = docked(22)
    const { ids, ui } = await asking(w, 5, short)
    const cap = Math.floor((22 - 1) / 2)
    const [first = '', ...later] = ids
    const then = (text: string) => ui.find({ type: 'Text', text: `⧗ Then: ${text}` })

    await approve(ui, w.item(first))
    await w.turnStarts('Carry on.')
    await ui.press({ key: 'send' })

    for (const id of later) {
      await approve(ui, w.item(id))
      await ui.press({ key: 'send' })
    }

    expect(w.flights()).toHaveLength(5)
    expect(await ui.find({ key: w.takeBack(0) }), 'the first, in full').toBeDefined()
    expect(await then('Review round 2')).toBeDefined()
    expect(await then('Review round 3')).toBeDefined()
    expect(await then('Review round 4 · 1 of 2')).toBeDefined()
    expect(await ui.find({ key: w.takeBack(3) })).toBeDefined()
    expect(await ui.find({ key: w.takeBack(4) }), 'behind the step').toBeUndefined()
    expect(await ui.find({ type: 'Text', text: '… 2 more' })).toBeDefined()
    expect(await drawnRows(ui)).toBeLessThanOrEqual(cap)
    await expectHeightKept(ui, 'five sends held, cut short', 22)

    await ui.press({ key: STEP_HELD })

    expect(await then('Review round 5 · 2 of 2')).toBeDefined()
    expect(await ui.find({ key: w.takeBack(4) })).toBeDefined()
    expect(await ui.find({ key: w.takeBack(3) })).toBeUndefined()
    await expectHeightKept(ui, 'stepped to the last', 22)

    await ui.press({ key: STEP_HELD })
    expect(await then('Review round 4 · 1 of 2'), 'round again').toBeDefined()

    await ui.press({ key: w.takeBack(3) })

    expect(w.flights()).toHaveLength(4)
    expect(await ui.find({ key: 'send' }), 'its reply still to send').toBeDefined()
    expect(await then('Review round 2 · 1 of 3')).toBeDefined()
    expect(await drawnRows(ui)).toBeLessThanOrEqual(cap)
    await expectHeightKept(ui, 'four sends held and a reply, cut short', 22)
  },
)
