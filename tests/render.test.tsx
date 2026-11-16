import type { RenderPropsOf, RenderSurface } from 'claude-code'
import { expect, test, tier } from './kit'
import { PANE } from '../hooks/pane'
import { sceneAt } from '../hooks/scene'
import { LEDGER, REVIEW, T0 } from './data'
import { note, park, yesAsk } from './lines'
import { pane } from './render'
import { asked, DOCKED, INLINE, toProject, world, type World } from './world'

tier('user')

/** A drawn element, with what a surface stamps on it beyond what the mod drew. */
type Stamped = {
  props: Record<string, unknown>
  press?: unknown
  client?: unknown
  part?: unknown
  children?: unknown[]
}

/** A drawing less a surface's stamps: a Button's press, a `Client`'s resolved module and handle, the plugin's stamp, the desktop's weight for bold. */
const unstamped = (node: unknown): unknown => {
  if (typeof node !== 'object' || node === null) {
    return node
  }

  const { press, client, part, children = [], ...rest } = node as Stamped
  const { weight, module, ...props } = rest.props

  return { ...rest, props, children: children.map(unstamped) }
}

/** The scene the window's state holds now, as the board's render hook reads it. */
const heldScene = (w: World) => {
  const { board, attachment, pane: shown } = w.state

  if (board == null || attachment == null || shown === undefined) {
    throw new Error('no session held')
  }

  return sceneAt(
    {
      board,
      attachment,
      projects: w.state.projects ?? [],
      others: w.state.others ?? [],
      queue: w.state.queue ?? [],
      inFlight: w.flights(),
      stopped: w.state.stopped ?? false,
      sent: w.state.sent ?? [],
      pane: shown,
      scroll: w.state.scroll ?? null,
      answering: w.state.answering ?? null,
      pulse: w.state.pulse ?? { asks: [], frames: 0 },
      flash: w.state.flash ?? 0,
    },
    w.clock.now(),
  )
}

/** Each surface's board, docked, and the terminal's inline: every way the board lays itself out, a `Client` measuring it or not. */
const DRAWN: readonly (readonly [RenderSurface, RenderPropsOf['Pane']])[] = [
  ['terminal', DOCKED],
  ['terminal', INLINE],
  ['desktop', DOCKED],
  ['mobile', DOCKED],
  ['vscode', DOCKED],
]

test("the board a surface draws is the drawing of the scene the window's state holds, drawn with no engine: on every surface, docked and inline, home and around", async ($, on) => {
  const w = world($, on)

  w.surround([
    {
      meta: LEDGER,
      lines: [
        [T0, park('p1', 'Export the ledger as CSV')],
        [T0, yesAsk('k3', 'Review the ledger schema')],
      ],
      seenAt: T0,
    },
  ])
  await w.begin()
  await w.call('park', { title: 'A priority badge across all tabs', ref: 'notes: badge.md' })

  const done = await asked(w, { wants: 'yes', yes: 'Done', title: 'Run the production apply' })

  await w.call('resolve', { item: done, reason: 'Ran it in the chat' })
  await asked(w, REVIEW)
  await w.call('note', { text: 'PR #82 merged', detail: ['6 files'] })

  for (const [surface, props] of DRAWN) {
    const ui = await $.ui.mount({
      plugin: 'sitrep',
      surface,
      component: 'Pane',
      requestId: PANE,
      props,
    })

    expect(
      unstamped(await pane(heldScene(w), props, surface).drawn()),
      `${surface}, ${props.placement}`,
    ).toEqual(unstamped(await ui.drawn()))
    await ui.unmount()
  }

  const ui = await w.pane()

  for (const [where, go] of [
    ['the project', () => toProject(ui)],
    ["the ledger's view", () => ui.press({ key: `go:${LEDGER.id}` })],
    ['All projects', () => ui.press({ key: 'tab:all' })],
  ] as const) {
    await go()
    expect(unstamped(await pane(heldScene(w)).drawn()), where).toEqual(unstamped(await ui.drawn()))
  }
})
