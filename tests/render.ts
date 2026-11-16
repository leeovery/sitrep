/**
 * The board drawn with no engine beneath: the mod's own drawing, which is
 * pure, run on a stand-in for a surface's element table, from the scene the
 * window's own look and fold make of a desk's files, and read back as a
 * mounted drawing is. For a test whose subject is what the board draws from
 * a scene; what a press does, or how the window's state reaches the scene,
 * stays an engine test's.
 *
 * render.test.tsx holds all three to the engine: the scene and the tree, but
 * for what a surface stamps on it, a Button's press among them, and the
 * reading, to the kit's `find` and `findAll`.
 */
import type { ElementTable, RenderPropsOf, RenderSurface } from 'claude-code'
import type { ElementQuery, FoundElement, Mounted } from 'claude-code/testing'
import { foldSession, sessionPaths } from '../core'
import type {
  SitrepAnswering,
  SitrepAttachment,
  SitrepBoard,
  SitrepInFlight,
  SitrepOther,
  SitrepPane,
  SitrepProject,
  SitrepPulse,
  SitrepQueued,
  SitrepScroll,
  SitrepSent,
} from '../types'
import type { Actions } from '../hooks/actions'
import { forgetLooks, lookAround } from '../hooks/around'
import { boardOf } from '../hooks/board'
import { drawPane } from '../hooks/draw/board'
import type { Host, Slot } from '../hooks/host'
import { itemKey } from '../hooks/places'
import { createReader } from '../hooks/reader'
import { sceneOf, type Scene } from '../hooks/scene'
import { HOME, PROJECT, ROOT, STATE_HOME, T0, W1 } from './data'
import { filing, HELD, type DeskFiles } from './filing'
import { fsOn, type File } from './fs'
import { DOCKED } from './world/panes'

type Props = Record<string, unknown>

/** An element as a surface's table builds it, as `drawn()` has it: a Button's press and a hover out of its props, a Text's key, which a surface never keeps, and no children where it draws none. */
type Element = { type: string; props: Props; hover?: unknown; children?: (Element | string)[] }

/** What JSX hands an element as children, numbers already strings: nodes, strings, nested lists, and the falsy values a condition leaves. */
const nodesOf = (children: unknown) =>
  [children]
    .flat(Infinity)
    .filter(
      (child): child is Element | string =>
        child !== undefined && child !== null && typeof child !== 'boolean',
    )

/** Children as a surface hands them on: none at all where it draws none. */
const childrenOf = (nodes: (Element | string)[]) => (nodes.length === 0 ? {} : { children: nodes })

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
    ...childrenOf(nodesOf(children)),
  })

/** What a surface draws for an element its table lacks: a column Box around the children, none among them. */
const fragment = ({ children }: Props): Element => ({
  ...element('Box')({ flexDirection: 'column', children }),
  children: nodesOf(children),
})

/**
 * The elements the board draws with, as each surface's table has them: a
 * `Client`, as a fragment where the surface draws none. Any other is
 * refused, a Link, Markdown, Code, Input or Progress among them: the kit
 * reads each one's text from a prop of its own, which this reading does not.
 */
const tableOf = (surface: RenderSurface) => {
  const drawn: Props = {
    Box: element('Box'),
    Text: element('Text'),
    Button: element('Button'),
    Client: surface === 'terminal' || surface === 'desktop' ? element('Client') : fragment,
  }

  return new Proxy(drawn, {
    get: (table, name) => {
      if (typeof name === 'string' && !(name in table)) {
        throw new Error(`the stand-in table draws no ${name}`)
      }

      return Reflect.get(table, name)
    },
  }) as unknown as ElementTable
}

/** What the board's buttons do, none of which a drawing alone runs. */
const NO_ACTIONS = new Proxy({} as Actions, { get: () => () => undefined })

/** The words an element shows: a Button's label, then its children's. */
const textOf = (node: Element | string): string =>
  typeof node === 'string'
    ? node
    : `${node.type === 'Button' ? String(node.props.label ?? '') : ''}${(node.children ?? []).map(textOf).join('')}`

const found = (node: Element): FoundElement => ({
  type: node.type,
  key: node.props.key as string | undefined,
  props: node.props,
  text: textOf(node),
  children: node.children ?? [],
})

const matches = (node: Element, { type, key, text }: ElementQuery) =>
  (type === undefined || node.type === type) &&
  (key === undefined || node.props.key === key) &&
  (text === undefined ||
    (typeof text === 'string' ? textOf(node).includes(text) : text.test(textOf(node))))

/** Every element of a tree, outermost first in document order. */
const elementsOf = (node: Element | string): Element[] =>
  typeof node === 'string' ? [] : [node, ...(node.children ?? []).flatMap(elementsOf)]

/** A drawing read as a mounted one is: its tree, and `find` and `findAll` matching as the kit's do. */
export type Drawn = Pick<Mounted, 'drawn' | 'find' | 'findAll'>

/** Refuses a read in a `Client`'s module: the board's own tree is all a drawing here holds. */
const inTree = (scope?: { in?: string }) => {
  if (scope?.in !== undefined) {
    throw new Error(`no Client's module is drawn here to read in: ${scope.in}`)
  }
}

/** The tree `drawing` makes, read as a mounted drawing is. */
const reading = (drawing: Promise<Element>): Drawn => {
  const matching = async (query: ElementQuery) => {
    inTree(query)

    return elementsOf(await drawing).filter(node => matches(node, query))
  }

  return {
    drawn: async scope => {
      inTree(scope)

      return (await drawing) as never
    },
    find: async query => {
      const [first] = await matching(query)

      return first === undefined ? undefined : found(first)
    },
    findAll: async query => (await matching(query)).map(found),
  }
}

/**
 * The board pane as a surface draws it from the scene, or the scene once
 * made, docked on the terminal unless told otherwise; no scene, as with no
 * session held. A docked board shows its list from the top, however far
 * down the scene's scroll stands.
 */
export const pane = (
  scene: Scene | undefined | Promise<Scene | undefined>,
  props: RenderPropsOf['Pane'] = DOCKED,
  surface: RenderSurface = 'terminal',
): Drawn =>
  reading(
    Promise.resolve(scene).then(
      made => drawPane(tableOf(surface), surface, NO_ACTIONS, props, made, () => 0) as Element,
    ),
  )

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

/** What the scene is made of: the desk's files, the board's pane, Ready to send, and the time. */
export type Desk = DeskFiles & {
  pane?: Partial<SitrepPane>
  queue?: readonly SitrepQueued[]
  now?: number
}

/** A value in `$.state`, held in memory. */
const slot = <T>(value: T): Slot<T> => {
  let held = value

  return {
    read: async () => held,
    write: async next => {
      held = next
    },
    update: async change => {
      held = change(held)
    },
  }
}

/**
 * What the window's look and its scene ask of its host, answered with no
 * engine beneath: `files`, the clock stopped at `now`, and `$.state` holding
 * the window's values, its session held; what it logs, a look's failure,
 * kept in `logged`.
 */
const hostOver = (files: Map<string, File>, now: number, desk: Desk, logged: string[]) =>
  ({
    fs: fsOn(files, now),
    clock: { now: async () => now },
    env: async () => ({ XDG_STATE_HOME: STATE_HOME, HOME }),
    log: (text: string) => logged.push(text),
    state: {
      attachment: slot<SitrepAttachment | null>(ATTACHMENT),
      board: slot<SitrepBoard | null>(null),
      projects: slot<SitrepProject[]>([]),
      others: slot<SitrepOther[]>([]),
      queue: slot([...(desk.queue ?? [])]),
      sent: slot<SitrepSent[]>([]),
      inFlight: slot<SitrepInFlight[]>([]),
      stopped: slot(false),
      pane: slot<SitrepPane>({ ...OPEN, ...desk.pane }),
      scroll: slot<SitrepScroll | null>(null),
      answering: slot<SitrepAnswering | null>(null),
      pulse: slot<SitrepPulse>({ asks: [], frames: 0 }),
      flash: slot(0),
      tick: slot(0),
    },
  }) as unknown as Host

/**
 * The scene the window makes of a desk at `now`: its files written as the
 * world writes them, the held session folded from what the watch's reader
 * reads of them, the sessions around it read by the window's own look, its
 * first, and the scene read from `$.state` as the board's render hook reads
 * it.
 */
const sceneOver = async (desk: Desk) => {
  const now = desk.now ?? T0
  const files = new Map<string, File>()
  const logged: string[] = []

  filing((path, text) => files.set(path, { text, mtimeMs: now })).desk(desk, now)

  const host = hostOver(files, now, desk, logged)
  const read = await createReader()(host, sessionPaths(ROOT, PROJECT.key, HELD.id))
  const session = foldSession(read, now)

  if (session === undefined) {
    throw new Error('the held session did not fold')
  }

  await host.state.board.write(boardOf(session))
  forgetLooks()
  await lookAround(host)

  if (logged.length > 0) {
    throw new Error(logged.join('\n'))
  }

  return sceneOf(host)
}

/** Scenes made so far, one at a time: each look starts by forgetting what the one before it read. */
let making: Promise<unknown> = Promise.resolve()

/** The scene the held window draws from at `now`, T0 unless told: the board open at home unless the desk's pane says otherwise. */
export const sceneFrom = (desk: Desk = {}): Promise<Scene | undefined> => {
  const made = making.then(() => sceneOver(desk))

  making = made.catch(() => undefined)

  return made
}
