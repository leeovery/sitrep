/**
 * The board drawn with no engine beneath: the mod's own drawing, which is
 * pure, run on a stand-in for a surface's element table, from the scene the
 * window's own look and fold make of a desk's files, and read back as a
 * mounted drawing is (matching.ts). For a test whose subject is what the
 * board draws from a scene; what a press does, or how the window's state
 * reaches the scene, stays an engine test's.
 *
 * render.test.tsx holds the scene, and the tree but for what a surface
 * stamps on it, a Button's press among them, to the engine's. What this
 * path cannot draw: a docked board scrolled down its list, which it always
 * shows from the top; and a look after the window's first, one that folds
 * a session off the board from the files it last read.
 */
import type { ElementTable, RenderPropsOf, RenderSurface } from 'claude-code'
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
import type { Host } from '../hooks/host'
import { createReader } from '../hooks/reader'
import { sceneOf, type Scene } from '../hooks/scene'
import { HELD, HOME, PROJECT, ROOT, STATE_HOME, T0, W1 } from './data'
import { filing, type DeskFiles } from './filing'
import type { File } from './fs'
import { fsOn, slot } from './host'
import { reading, type Drawn, type Element } from './matching'
import { DOCKED } from './world/panes'

export type { Drawn } from './matching'

type Props = Record<string, unknown>

/** What JSX hands an element as children: nodes, strings, numbers, nested lists, and the falsy values a condition leaves; a number shown as its digits, as a surface shows it. */
const nodesOf = (children: unknown): (Element | string)[] =>
  [children]
    .flat(Infinity)
    .filter(child => child !== undefined && child !== null && typeof child !== 'boolean')
    .map(child => (typeof child === 'number' ? String(child) : (child as Element | string)))

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
 * reads each one's text from a prop of its own, which matching.ts does not.
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

/** What the board's buttons do, none of which a drawing alone runs; not a promise, so nothing awaiting it waits. */
const NO_ACTIONS = new Proxy({} as Actions, {
  get: (_, name) => (name === 'then' ? undefined : () => undefined),
})

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

/** Where the window holds its session. */
const ATTACHMENT: SitrepAttachment = {
  project: PROJECT.key,
  session: HELD.id,
  writer: W1,
  attachedAt: T0,
}

/** The board open, home, nothing opened: the mod's first pane (register.tsx), opened. */
const OPEN: SitrepPane = {
  isOpen: true,
  place: null,
  selected: null,
  shown: {},
  heldShown: null,
  placement: {},
}

/**
 * What the scene is made of: the desk's files, or the disk as an engine
 * test's window left it; the window's values in `$.state`, each as the mod
 * starts it unless told, the board open at home; and the time.
 */
export type Desk = DeskFiles & {
  files?: ReadonlyMap<string, File>
  pane?: Partial<SitrepPane>
  queue?: readonly SitrepQueued[]
  sent?: readonly SitrepSent[]
  inFlight?: readonly SitrepInFlight[]
  stopped?: boolean
  answering?: SitrepAnswering | null
  pulse?: SitrepPulse
  flash?: number
  now?: number
}

/**
 * What the window's look and its scene ask of its host, answered with no
 * engine beneath: `files`, the clock stopped at `now`, and `$.state` holding
 * the window's values, its session held; what it logs, a look's failure,
 * kept in `logged`. The values the mod starts with restate the atoms
 * register.tsx keeps them in, the hooks module the engine loads, which a
 * pure test does not import.
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
      sent: slot([...(desk.sent ?? [])]),
      inFlight: slot([...(desk.inFlight ?? [])]),
      stopped: slot(desk.stopped ?? false),
      pane: slot<SitrepPane>({ ...OPEN, ...desk.pane }),
      scroll: slot<SitrepScroll | null>(null),
      answering: slot(desk.answering ?? null),
      pulse: slot(desk.pulse ?? { asks: [], frames: 0 }),
      flash: slot(desk.flash ?? 0),
      tick: slot(0),
    },
  }) as unknown as Host

/** The files a scene reads: the disk given, as it stands, else the desk's written as the world writes them, at `now`. */
const filesOf = (desk: Desk, now: number) => {
  const files = new Map(desk.files)

  if (desk.files === undefined) {
    filing((path, text) => files.set(path, { text, mtimeMs: now })).desk(desk, now)
  }

  return files
}

/**
 * The scene the window makes of a desk at `now`: the held session folded
 * from what the watch's reader reads of its files, the sessions around it
 * read by the window's own look, its first, and the scene read from
 * `$.state` as the board's render hook reads it.
 */
const sceneOver = async (desk: Desk) => {
  const now = desk.now ?? T0
  const logged: string[] = []
  const host = hostOver(filesOf(desk, now), now, desk, logged)
  const read = await createReader()(host, sessionPaths(ROOT, PROJECT.key, HELD.id))
  const session = foldSession(read, now)

  if (session === undefined) {
    throw new Error('the held session did not fold')
  }

  await host.state.board.write(boardOf(session))
  await forgetLooks()
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
