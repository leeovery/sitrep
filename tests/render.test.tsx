import type { RenderPropsOf, RenderSurface } from 'claude-code'
import type { ElementQuery, FoundElement } from 'claude-code/testing'
import { expect, test, tier, type Engine } from './kit'
import { STALE_MS } from '../core'
import { PANE } from '../hooks/pane'
import { itemKey } from '../hooks/places'
import { TICK_MS } from '../hooks/scene'
import {
  ELSEWHERE,
  HELD,
  heldItem,
  LEDGER,
  meta,
  PROJECT,
  REVIEW,
  SHIFTS,
  T0,
  THEMES,
  W3,
} from './data'
import {
  askOf,
  delivered,
  park,
  reply,
  resolve,
  status,
  wordsAsk,
  yesAsk,
  type Line,
} from './lines'
import { pane, sceneFrom, type Desk, type Drawn } from './render'
import {
  ACROSS,
  CONVERSATION,
  DOCKED,
  INLINE,
  toProject,
  turnEnded,
  WIDE,
  world,
  type World,
} from './world'

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
 * This session with something parked and something picked up, four asks
 * closed, two open, one wanting words, and its status changed four times;
 * beside it, two more sessions of Northwind's, one of Contoso's and one of
 * Fabrikam's, each asking, parking or changing its status.
 */
const DESK: Desk = {
  lines: [
    [T0, park('p1', 'A priority badge across all tabs', { ref: 'notes: badge.md' })],
    [T0, park('p2', 'Tidy the old fixtures')],
    ...closed('k1', 'Run the production apply'),
    ...closed('k3', 'Rotate the keys'),
    ...closed('k4', 'Purge the cache'),
    ...closed('k5', 'Tag the release'),
    [T0, askOf('k2', REVIEW)],
    [T0, wordsAsk('k6', 'Paste the build log', 'the log')],
    [T0 + 1, status(['Drawing the badge'])],
    [T0 + 2, status(['Reviewing the badge'], { next: 'Ship the badge' })],
    [T0 + 3, status(['Reviewing the badge', 'Writing the notes'])],
    [T0 + 4, status(['Writing the notes'], { name: 'Help desk, round 2' })],
    [T0 + 5, reply('r1', 'p2', 'pickup', { note: 'Before the release' })],
    [T0 + 5, delivered('r1')],
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
    { meta: THEMES, lines: [[T0, status(['Drawing the dark theme'])]], seenAt: T0 },
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

/** The window's values in `$.state` as the engine holds them now, and its time. */
const windowOf = (w: World): Desk => ({
  pane: w.state.pane,
  queue: w.state.queue,
  sent: w.state.sent,
  inFlight: w.flights(),
  stopped: w.state.stopped,
  answering: w.state.answering,
  pulse: w.state.pulse,
  flash: w.state.flash,
  now: w.clock.now(),
})

/** The board drawn with no engine from the desk's files, the window's state as the engine holds it now. */
const fromDesk = (
  w: World,
  props: RenderPropsOf['Pane'] = DOCKED,
  surface: RenderSurface = 'terminal',
) => pane(sceneFrom({ ...DESK, ...windowOf(w) }), props, surface)

/** The board drawn with no engine from the disk as the engine's window has left it, and its state as it holds it now. */
const fromDisk = (w: World) => pane(sceneFrom({ files: w.files, ...windowOf(w) }))

/**
 * What Lee did, then a tick's time: the watch, the look and the board's tick
 * all come round as it ends, so the engine's board is drawn from reads made
 * at the moment the scene drawn with no engine reads the files.
 */
const settled = async (w: World, done: Promise<unknown>) => {
  await done
  await w.clock.advance(TICK_MS)
}

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

/** The presses that show this session's history in full, a change opened, and its picked up, an item opened. */
const PAST_SHOWN = [
  `history:${HELD.id}`,
  `all:history:${HELD.id}`,
  `status:${itemKey(HELD.id, String(T0 + 3))}`,
  `pickedup:${HELD.id}`,
]

test("the board drawn with no engine from a desk's files is the engine's on every surface, docked and inline, and on the terminal at every width a test draws it, its past folded and shown", async ($, on) => {
  const w = world($, on)
  const mounted = (surface: RenderSurface, props: RenderPropsOf['Pane']) =>
    $.ui.mount({ plugin: 'sitrep', surface, component: 'Pane', requestId: PANE, props })

  await joined($, w)

  for (const isShown of [false, true]) {
    if (isShown) {
      const ui = await mounted('terminal', DOCKED)

      for (const key of PAST_SHOWN) {
        await ui.press({ key })
      }

      await ui.unmount()
    }

    for (const [surface, props] of DRAWN) {
      const ui = await mounted(surface, props)
      const said = `${surface}, ${props.placement}, ${props.bodyColumns}, past shown: ${isShown}`

      expect(unstamped(surface, await fromDesk(w, props, surface).drawn()), said).toEqual(
        unstamped(surface, await ui.drawn()),
      )
      await ui.unmount()
    }
  }
})

test("the board drawn with no engine is the engine's wherever Lee takes it and whatever he does there: home, an ask opened and its yes queued, RESOLVED in full, its history and picked up shown and opened, the project and its history and picked up, the ledger's view and its ask answered, a turn under way, both replies sent while it works, gone in once it ends and taken, All projects, Contoso's view and its session, an ask being answered, and the sessions around gone stale", async ($, on) => {
  const w = world($, on)

  await joined($, w)

  const ui = await w.opened()
  const ledgers = itemKey(LEDGER.id, 'k3')

  for (const [where, go] of [
    ['home', async () => {}],
    ['an ask opened', () => ui.press({ key: `pick:${heldItem('k2')}` })],
    ['its yes ready to send', () => ui.press({ key: `yes:${heldItem('k2')}` })],
    ['RESOLVED in full', () => ui.press({ key: `all:resolved:${HELD.id}` })],
    ['its history shown', () => ui.press({ key: `history:${HELD.id}` })],
    ['its history in full', () => ui.press({ key: `all:history:${HELD.id}` })],
    ['a change opened', () => ui.press({ key: `status:${itemKey(HELD.id, String(T0 + 3))}` })],
    ['its picked up shown', () => ui.press({ key: `pickedup:${HELD.id}` })],
    ['an item picked up opened', () => ui.press({ key: `picked:${heldItem('p2')}` })],
    ['the project', () => toProject(ui)],
    ["the project's history shown", () => ui.press({ key: `history:project:${PROJECT.key}` })],
    [
      "the project's picked up shown",
      () => ui.press({ key: `pickedup:project:${PROJECT.key}` }),
    ],
    ["the ledger's view", () => ui.press({ key: `go:${LEDGER.id}` })],
    [
      "the ledger's ask answered",
      async () => {
        await ui.press({ key: `pick:${ledgers}` })
        await ui.press({ key: `yes:${ledgers}` })
      },
    ],
    ['a turn under way', () => w.turnStarts('Carry on.')],
    ['both replies sent, held while Claude works', () => settled(w, ui.press({ key: 'send' }))],
    ['the turn ended, the replies gone in', () => settled(w, turnEnded(w))],
    ['the message taken', () => settled(w, w.turnStarts(w.prompts.at(-1)?.text ?? 'no prompt'))],
    ['All projects', () => ui.press({ key: 'tab:all' })],
    ["Contoso's view", () => ui.press({ key: `proj:${ELSEWHERE.key}` })],
    ["Contoso's session", () => ui.press({ key: `go:${SHIFTS.id}` })],
    [
      'an ask being answered',
      async () => {
        await ui.press({ key: 'tab:session' })
        await ui.press({ key: `pick:${heldItem('k6')}` })
        await ui.press({ key: `answer:${heldItem('k6')}` })
      },
    ],
    ['the sessions around gone stale', () => settled(w, w.clock.advance(STALE_MS))],
  ] as const) {
    await go()
    expect(unstamped('terminal', await fromDisk(w).drawn()), where).toEqual(
      unstamped('terminal', await ui.drawn()),
    )
  }

  expect(w.state.sent, 'a reply on its way to the ledger').toHaveLength(1)
  expect(w.state.answering, 'an ask being answered').not.toBeNull()
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
  { key: `all:resolved:${HELD.id}`, text: 'show all 4' },
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

  const drawn: Drawn = fromDesk(w)

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
