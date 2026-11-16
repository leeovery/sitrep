import type { RenderPropsOf, RenderSurface } from 'claude-code'
import type { ElementQuery, FoundElement } from 'claude-code/testing'
import { expect, test, tier, type Engine } from './kit'
import { PANE } from '../hooks/pane'
import { ELSEWHERE, LEDGER, meta, REVIEW, SHIFTS, T0, THEMES, W3 } from './data'
import { HELD } from './filing'
import { askOf, note, park, resolve, yesAsk, type Line } from './lines'
import { heldItem, pane, sceneFrom, type Desk, type Drawn } from './render'
import { ACROSS, CONVERSATION, DOCKED, INLINE, toProject, WIDE, world, type World } from './world'

tier('user')

/** A drawn element, with what a surface stamps on it beyond what the mod drew. */
type Stamped = { type: string; props: Record<string, unknown>; children?: unknown[] } & Record<
  string,
  unknown
>

/** Whether a surface stamped a bold Text's weight: every surface but the terminal, which has one weight of bold, reads bold as semibold. */
const isWeighed = (surface: RenderSurface, { type, props }: Stamped) =>
  surface !== 'terminal' && type === 'Text' && props.bold === true && props.weight === 'semibold'

/** What a surface stamps on an element where it stamps it: a Button's press, a `Client`'s handle and resolved module, the plugin on the root, a bold Text's weight. */
const stampsOn = (surface: RenderSurface, stamped: Stamped, isRoot: boolean) => ({
  element: [
    ...(stamped.type === 'Button' ? ['press'] : []),
    ...(stamped.type === 'Client' ? ['client'] : []),
    ...(isRoot ? ['part'] : []),
  ],
  props: [
    ...(stamped.type === 'Client' ? ['module'] : []),
    ...(isWeighed(surface, stamped) ? ['weight'] : []),
  ],
})

const without = (record: Record<string, unknown>, names: readonly string[]) =>
  Object.fromEntries(Object.entries(record).filter(([name]) => !names.includes(name)))

/** A drawing on `surface` less what the surface stamps on it. */
const unstamped = (surface: RenderSurface, node: unknown, isRoot = true): unknown => {
  if (typeof node !== 'object' || node === null) {
    return node
  }

  const stamped = node as Stamped
  const stamps = stampsOn(surface, stamped, isRoot)
  const { children } = stamped

  return {
    ...without(stamped, stamps.element),
    props: without(stamped.props, stamps.props),
    ...(children === undefined
      ? {}
      : { children: children.map(child => unstamped(surface, child, false)) }),
  }
}

/** A session of a third project, Fabrikam, which names itself in its project's file. */
const SUPPLIERS = meta('sr-5upp1y', 'Supplier portal', W3, { project: 'fabrikam' })

/** An ask Claude closed itself. */
const closed = (id: string, title: string): Line[] => [
  [T0, askOf(id, { wants: 'yes', yes: 'Done', title })],
  [T0, resolve(id, 'Ran it in the chat')],
]

/**
 * This session with something parked, four asks closed, one open and a
 * note; beside it, two more sessions of Northwind's, one of Contoso's and
 * one of Fabrikam's, each asking or parking or noting.
 */
const DESK: Desk = {
  lines: [
    [T0, park('p1', 'A priority badge across all tabs', { ref: 'notes: badge.md' })],
    ...closed('k1', 'Run the production apply'),
    ...closed('k3', 'Rotate the keys'),
    ...closed('k4', 'Purge the cache'),
    ...closed('k5', 'Tag the release'),
    [T0, askOf('k2', REVIEW)],
    [T0, note('n1', 'PR #82 merged', ['6 files'])],
  ],
  around: [
    {
      meta: LEDGER,
      lines: [
        [T0, park('p1', 'Export the ledger as CSV')],
        [T0, yesAsk('k3', 'Review the ledger schema')],
      ],
      seenAt: T0,
    },
    { meta: THEMES, lines: [[T0, note('n1', 'Drew the dark theme')]], seenAt: T0 },
    {
      meta: SHIFTS,
      project: ELSEWHERE.key,
      lines: [[T0, yesAsk('k1', 'Approve the rota')]],
      seenAt: T0,
    },
    {
      meta: SUPPLIERS,
      project: 'fabrikam',
      projectFile: { name: 'Fabrikam', created: T0, by: W3 },
      lines: [[T0, park('p1', 'Import the supplier list')]],
      seenAt: T0,
    },
  ],
}

/** The desk's files written, and this window joining the session held there: begun, it would hold one of an id no desk can name. */
async function joined($: Engine, w: World) {
  w.lay(DESK)
  await $.session.start(CONVERSATION)
  await w.call('join', { session: HELD.id })
}

/** The board drawn with no engine from the desk, the window's pane and Ready to send as the engine holds them now. */
const pureOf = (
  w: World,
  props: RenderPropsOf['Pane'] = DOCKED,
  surface: RenderSurface = 'terminal',
) =>
  pane(
    sceneFrom({ ...DESK, pane: w.state.pane, queue: w.state.queue, now: w.clock.now() }),
    props,
    surface,
  )

/** Each surface's board, docked and inline, and the terminal's at each width a test draws it: every way the board lays itself out, a `Client` measuring it or not. */
const DRAWN: readonly (readonly [RenderSurface, RenderPropsOf['Pane']])[] = [
  ...(['terminal', 'desktop', 'mobile', 'vscode'] as const).flatMap(surface => [
    [surface, DOCKED] as const,
    [surface, INLINE] as const,
  ]),
  ...[WIDE.bodyColumns, 42, 46, 60, ACROSS].flatMap(bodyColumns => [
    ['terminal', { ...DOCKED, bodyColumns }] as const,
    ['terminal', { ...INLINE, bodyColumns }] as const,
  ]),
]

test("the board drawn with no engine from a desk's files is the engine's on every surface, docked and inline, at every width", async ($, on) => {
  const w = world($, on)

  await joined($, w)

  for (const [surface, props] of DRAWN) {
    const ui = await $.ui.mount({
      plugin: 'sitrep',
      surface,
      component: 'Pane',
      requestId: PANE,
      props,
    })
    const said = `${surface}, ${props.placement}, ${props.bodyColumns}`

    expect(unstamped(surface, await pureOf(w, props, surface).drawn()), said).toEqual(
      unstamped(surface, await ui.drawn()),
    )
    await ui.unmount()
  }
})

test("the board drawn with no engine is the engine's wherever Lee takes it: an ask opened, a reply ready to send, RESOLVED in full, every project, another project and its session", async ($, on) => {
  const w = world($, on)

  await joined($, w)

  const ui = await w.opened()

  for (const [where, go] of [
    ['home', async () => {}],
    ['an ask opened', () => ui.press({ key: `pick:${heldItem('k2')}` })],
    ['a reply ready to send', () => ui.press({ key: `yes:${heldItem('k2')}` })],
    ['RESOLVED in full', () => ui.press({ key: `earlier:${HELD.id}` })],
    ['the project', () => toProject(ui)],
    ["the ledger's view", () => ui.press({ key: `go:${LEDGER.id}` })],
    ['All projects', () => ui.press({ key: 'tab:all' })],
    ["Contoso's view", () => ui.press({ key: `proj:${ELSEWHERE.key}` })],
    ["Contoso's session", () => ui.press({ key: `go:${SHIFTS.id}` })],
  ] as const) {
    await go()
    expect(unstamped('terminal', await pureOf(w).drawn()), where).toEqual(
      unstamped('terminal', await ui.drawn()),
    )
  }

  expect(w.state.queue, 'the reply waits in Ready to send').toHaveLength(1)
})

/** What a query finds, as a test reads it. */
const seen = (each: FoundElement | undefined) =>
  each === undefined ? undefined : { type: each.type, key: each.key, text: each.text }

/** Queries the tests make of the board, an ask opened: by type, by text, by a pattern, by key and text, and by a Button's label. */
const FINDING: readonly ElementQuery[] = [
  { type: 'Box' },
  { type: 'Text', text: 'RESOLVED' },
  { type: 'Text', text: /^ASKS/ },
  { key: 'tab:all', text: 'All projects' },
  { type: 'Button', text: '✓ Approve' },
  { key: `ask:${heldItem('k2')}` },
  { key: `earlier:${HELD.id}`, text: 'show all 4' },
]

/** Queries the tests make of it to find nothing: a Button's label sought as Text, a key with words it does not show, keys and words not drawn there. */
const MISSING: readonly ElementQuery[] = [
  { type: 'Text', text: '✓ Approve' },
  { type: 'Text', text: 'show all 4' },
  { key: 'tab:all', text: 'Help desk' },
  { key: `yes:${heldItem('k9')}` },
  { key: 'tab:project' },
  { key: 'up' },
  { text: /Invoice ledger/ },
]

test("a drawing with no engine finds what the kit's find and findAll find, and finds nothing where they find nothing", async ($, on) => {
  const w = world($, on)

  await joined($, w)

  const ui = await w.opened()

  await ui.press({ key: `pick:${heldItem('k2')}` })

  const drawn: Drawn = pureOf(w)

  for (const [query, isFound] of [
    ...FINDING.map(query => [query, true] as const),
    ...MISSING.map(query => [query, false] as const),
  ]) {
    const said = JSON.stringify(query, (key, value) =>
      value instanceof RegExp ? `${value}` : value,
    )
    const all = (await drawn.findAll(query)).map(seen)

    expect(all.length > 0, said).toBe(isFound)
    expect(all, said).toEqual((await ui.findAll(query)).map(seen))
    expect(seen(await drawn.find(query)), said).toEqual(seen(await ui.find(query)))
  }
})

test("a drawing with no engine refuses a read in a Client's module, which it never draws", async () => {
  const ui = pane(sceneFrom())

  await expect(ui.drawn({ in: 'board' })).rejects.toThrow(/no Client's module/)
  await expect(ui.find({ key: 'tab:all', in: 'board' })).rejects.toThrow(/no Client's module/)
  await expect(ui.findAll({ type: 'Box', in: 'board' })).rejects.toThrow(/no Client's module/)
})
