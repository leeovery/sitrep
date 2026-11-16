/**
 * The board drawn with no engine beneath: the mod's own drawing, which is
 * pure, run on a stand-in for a surface's element table, from a scene built
 * as the window's look and watch would leave it, and read back as a mounted
 * drawing is. For a test whose subject is what the board draws from a
 * scene; what a press does, or how the window's state reaches the scene,
 * stays an engine test's.
 *
 * Drawn on each surface and each placement, its tree is the engine's but
 * for what a surface stamps on it, a Button's press among them:
 * render.test.tsx holds it to that.
 */
import type { ElementTable, RenderPropsOf, RenderSurface } from 'claude-code'
import type { ElementQuery, FoundElement, Mounted } from 'claude-code/testing'
import { metaText, type SessionMeta } from '../core'
import type { SitrepAttachment, SitrepPane, SitrepQueued } from '../types'
import type { Actions } from '../hooks/actions'
import { fullOf, othersOf, projectsOf } from '../hooks/around'
import { boardOf } from '../hooks/board'
import { drawPane } from '../hooks/draw/board'
import { itemKey } from '../hooks/places'
import { sceneAt, type Filed, type Scene } from '../hooks/scene'
import { HELP_DESK, PROJECT, REPO, T0, W1 } from './data'
import { aroundFiles, beat, file, fold, type Around, type Line } from './lines'
import { DOCKED } from './world/panes'

type Props = Record<string, unknown>

/** An element as a surface's table builds it, as `drawn()` has it: a Button's press and a hover out of its props, and a Text's key, which a surface never keeps. */
type Element = { type: string; props: Props; hover?: unknown; children: (Element | string)[] }

/** What JSX hands an element as children: nodes, strings, numbers, nested lists, and the falsy values a condition leaves. */
const nodesOf = (children: unknown): unknown[] =>
  [children]
    .flat(Infinity)
    .filter(child => child !== undefined && child !== null && typeof child !== 'boolean')
    .map(child => (typeof child === 'number' ? String(child) : child))

const element =
  (type: string) =>
  ({ children, hover, onPress, ...props }: Props): Element => ({
    type,
    props: Object.fromEntries(
      Object.entries(props).filter(
        ([name, value]) => value !== undefined && !(type === 'Text' && name === 'key'),
      ),
    ),
    ...(hover === undefined ? {} : { hover }),
    children: nodesOf(children) as (Element | string)[],
  })

/** What a surface draws for an element its table lacks: a column Box around the children. */
const fragment = ({ children }: Props) => element('Box')({ flexDirection: 'column', children })

/** The elements the board draws with, as each surface's table has them: a `Client`, as a fragment where the surface draws none. */
const tableOf = (surface: RenderSurface) =>
  ({
    Box: element('Box'),
    Text: element('Text'),
    Button: element('Button'),
    Client: surface === 'terminal' || surface === 'desktop' ? element('Client') : fragment,
  }) as unknown as ElementTable

/** What the board's buttons do, none of which a drawing alone runs. */
const NO_ACTIONS = new Proxy({} as Actions, { get: () => () => undefined })

/** The words an element shows: a Button's label, then its children's. */
const textOf = (node: Element | string): string =>
  typeof node === 'string'
    ? node
    : `${node.type === 'Button' ? String(node.props.label ?? '') : ''}${node.children.map(textOf).join('')}`

const found = (node: Element): FoundElement => ({
  type: node.type,
  key: node.props.key as string | undefined,
  props: node.props,
  text: textOf(node),
  children: node.children,
})

const matches = (node: Element, { type, key, text }: ElementQuery) =>
  (type === undefined || node.type === type) &&
  (key === undefined || node.props.key === key) &&
  (text === undefined ||
    (typeof text === 'string' ? textOf(node).includes(text) : text.test(textOf(node))))

/** Every element of a tree, outermost first in document order. */
const elementsOf = (node: Element | string): Element[] =>
  typeof node === 'string' ? [] : [node, ...node.children.flatMap(elementsOf)]

/** A drawing read as a mounted one is: its tree, and `find` and `findAll` matching as the kit's do. */
export type Drawn = Pick<Mounted, 'drawn' | 'find' | 'findAll'>

const reading = (tree: Element): Drawn => {
  const all = elementsOf(tree)

  return {
    drawn: async () => tree as never,
    find: async query => {
      const first = all.find(node => matches(node, query))

      return first === undefined ? undefined : found(first)
    },
    findAll: async query => all.filter(node => matches(node, query)).map(found),
  }
}

/** The board pane as a surface draws it from the scene, docked on the terminal unless told otherwise; no scene, as with no session held. */
export const pane = (
  scene: Scene | undefined,
  props: RenderPropsOf['Pane'] = DOCKED,
  surface: RenderSurface = 'terminal',
): Drawn =>
  reading(drawPane(tableOf(surface), surface, NO_ACTIONS, props, scene, () => 0) as Element)

/** The held session's meta, as the world's `begin` starts it: Help desk redesign, filed under Northwind. */
export const HELD: SessionMeta = {
  id: 'sr-he1d00',
  ...HELP_DESK,
  root: REPO,
  created: T0,
  by: W1,
}

/** An item of the held session by its address, as its buttons' keys and the pane name it. */
export const heldItem = (id: string) => itemKey(HELD.id, id)

/** Where the window holds its session. */
const ATTACHMENT: SitrepAttachment = {
  project: PROJECT.key,
  session: HELD.id,
  writer: W1,
  attachedAt: T0,
}

/** The board open, home, nothing opened. */
const OPEN: SitrepPane = {
  isOpen: true,
  place: null,
  selected: null,
  resolvedInFull: null,
  heldShown: null,
  placement: {},
}

/**
 * What the scene is made of: the held session's lines and the window whose
 * file holds them, this one's unless told; the sessions around it; the
 * board's pane; Ready to send; and the time.
 */
export type Desk = {
  lines?: readonly Line[]
  writer?: string
  around?: readonly Around[]
  pane?: Partial<SitrepPane>
  queue?: readonly SitrepQueued[]
  now?: number
}

/** A session around the held one, as the look reads it at `now`. */
const filedAround = (around: Around, now: number): Filed => ({
  project: around.project ?? PROJECT.key,
  session: fold(aroundFiles(around), now),
})

/**
 * The scene the held window draws from at `now`: its session folded from
 * `lines`, its window beating; the sessions around it read as the look
 * reads them, those the board draws in full among them; the pane open at
 * home unless told.
 */
export const sceneFrom = (desk: Desk = {}) => {
  const { lines = [], writer = W1, around = [], pane: shown, queue = [], now = T0 } = desk
  const held = fold(
    {
      meta: metaText(HELD),
      logs: { [writer]: file(...lines) },
      presence: { [W1]: beat(W1, { attachedAt: T0, seenAt: now }) },
    },
    now,
  )
  const read = new Map(around.map(each => [each.meta.id, filedAround(each, now)]))
  const keys = [...new Set([PROJECT.key, ...[...read.values()].map(each => each.project)])]
  const opened = { ...OPEN, ...shown }
  const full = fullOf(ATTACHMENT, opened, { queue, sent: [], answering: null })

  return sceneAt(
    {
      board: boardOf(held),
      attachment: ATTACHMENT,
      projects: projectsOf(ATTACHMENT, keys, read, now),
      others: othersOf(full, read),
      queue,
      inFlight: [],
      stopped: false,
      sent: [],
      pane: opened,
      scroll: null,
      answering: null,
      pulse: { asks: [], frames: 0 },
      flash: 0,
    },
    now,
  )
}
