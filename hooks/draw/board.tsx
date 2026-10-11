/**
 * The board pane: where it is looking and its view there, under a header,
 * with Ready to send at the foot; one line when the window holds no work.
 * The view is a list of blocks. Docked, the header and Ready to send never
 * move, and the list between them is clipped, a `Client` measuring each
 * block (hooks/clip.ts); inline, the header leads the view and Ready to send
 * follows it.
 *
 * The header is the same two tabs everywhere, each a row of `TABS`: this
 * session, by its name, and every project, over a blank row. Off home and
 * All projects, the way back up sits at the end of the view's title line.
 */
import type { ElementTable, RenderPropsOf, RenderSurface } from 'claude-code'
import type { SitrepPlace, SitrepPlacement } from '../../types'
import type { Actions } from '../actions'
import type { Clip } from '../clip'
import { C, clip as clipText, GLYPH } from '../look'
import { EVERY_PROJECT, everyProject, filedAt, homeOf, isHome, projectLabel, up } from '../places'
import type { Scene } from '../scene'
import { drawAllView } from './every'
import type { Back, Block, Drawing, Els } from './kit'
import { drawProjectView } from './project'
import { drawReady, readyOf, readyRows } from './ready'
import { drawSessionView } from './session'

const NO_WORK =
  'This window holds no piece of work. Ask Claude to start one on the sitrep board, or to join one by its id.'

/** A session the board has not read yet: it reads it as it opens there. */
const READING = 'Reading the board…'

type Tab = {
  key: string
  glyph: string
  /** Its words after the glyph, the press. */
  label: (scene: Scene) => string
  /** Whether its label is cut short to leave the other tabs their full width. */
  isFitted?: boolean
  color: string
  count: (scene: Scene) => number
  /** Where the tab takes the board. */
  to: (scene: Scene) => SitrepPlace
  isLit: (scene: Scene) => boolean
}

const TABS: readonly Tab[] = [
  {
    key: 'tab:session',
    glyph: GLYPH.home,
    label: scene => scene.work.status.name,
    isFitted: true,
    color: C.now,
    count: scene => scene.work.waiting,
    to: homeOf,
    isLit: isHome,
  },
  {
    key: 'tab:all',
    glyph: GLYPH.every,
    label: () => 'All projects',
    color: C.parked,
    count: scene => everyProject(scene).projects.reduce((sum, project) => sum + project.waiting, 0),
    to: () => EVERY_PROJECT,
    isLit: scene => !isHome(scene),
  },
]

/** The rule under a way around the board, `cells` across: heavy, in its colour, under the one that is current. */
const ruleUnder = (d: Drawing, key: string, cells: number, lit?: string) => {
  const { Text } = d.els

  return (
    <Text key={key} color={lit ?? C.rule}>
      {(lit === undefined ? '─' : '━').repeat(cells)}
    </Text>
  )
}

/** A tab's words: its glyph, its label, and its count where anything waits. */
const wordsOf = (tab: Tab, label: string, waiting: number) => [
  tab.glyph,
  label,
  ...(waiting > 0 ? [String(waiting)] : []),
]

/** A tab's cells: its padding each side, and its words a cell apart. */
const tabWidth = (words: readonly string[]) => 2 + words.join(' ').length

/** A tab as drawn: its label, cut short where it gives way, what waits there, whether it is lit, and its cells. */
type LaidTab = { tab: Tab; label: string; waiting: number; isOn: boolean; cells: number }

const layTab = (scene: Scene, tab: Tab, label = tab.label(scene)): LaidTab => {
  const waiting = tab.count(scene)

  return {
    tab,
    label,
    waiting,
    isOn: tab.isLit(scene),
    cells: tabWidth(wordsOf(tab, label, waiting)),
  }
}

/** A fitted tab, its label cut short to the cells the other tabs leave it. */
const fitTab = (d: Drawing, { tab, label, waiting }: LaidTab, others: number) =>
  layTab(d.scene, tab, clipText(label, d.width - others - tabWidth(wordsOf(tab, '', waiting))))

/** The tabs across the board, a fitted one taking what the others leave. */
const layTabs = (d: Drawing): LaidTab[] => {
  const laid = TABS.map(tab => layTab(d.scene, tab))
  const others = laid.reduce((sum, each) => sum + (each.tab.isFitted ? 0 : each.cells), 0)

  return laid.map(each => (each.tab.isFitted ? fitTab(d, each, others) : each))
}

/** The tabs, the current one lit, each with what waits there, over their rule running on to the edge. */
const drawTabs = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const tabs = layTabs(d)
  const used = tabs.reduce((sum, tab) => sum + tab.cells, 0)

  return (
    <Box flexDirection="column">
      <Box flexDirection="row">
        {tabs.map(({ tab, label, waiting, isOn, cells }) => (
          <Box
            key={`${tab.key}:box`}
            width={cells}
            flexShrink={0}
            paddingX={1}
            flexDirection="row"
            gap={1}
            backgroundColor={isOn ? C.tab : undefined}
          >
            <Text color={isOn ? tab.color : C.grey}>{tab.glyph}</Text>
            <Button
              key={tab.key}
              plain
              dimColor={!isOn}
              label={label}
              onPress={() => d.act.go(tab.to(d.scene))}
            />
            {waiting > 0 && <Text color={isOn ? C.ask : C.grey}>{waiting}</Text>}
          </Box>
        ))}
      </Box>
      <Box flexDirection="row">
        {tabs.map(({ tab, isOn, cells }) =>
          ruleUnder(d, `${tab.key}:rule`, cells, isOn ? tab.color : undefined),
        )}
        {ruleUnder(d, 'tabs:rule', Math.max(0, d.width - used))}
      </Box>
    </Box>
  )
}

const placeName = (scene: Scene, place: SitrepPlace) =>
  place.level === 'project' ? projectLabel(scene, place.project) : 'All projects'

/** The way back, one level up: anywhere but home and All projects, which have none. */
const backOf = (scene: Scene): Back | undefined => {
  if (isHome(scene) || scene.place.level === 'all') {
    return undefined
  }

  const above = up(scene.place)

  return { label: `${GLYPH.up} ${placeName(scene, above)}`, to: above }
}

/** The blank row between parts of the board, and between the view and Ready to send inline. */
const GAP_ROWS = 1

/** The tabs' row and their rule. */
const TAB_ROWS = 2

/** The rows the header takes, the same everywhere: the tabs, their rule, and a blank row. */
const HEADER_ROWS = TAB_ROWS + GAP_ROWS

/**
 * What tells the band where Claude Code seated the board
 * (hooks/draw/placement.tsx), in a cell of the column the board keeps free
 * beside the tabs, where it takes no room and covers nothing to press; none
 * where the surface draws no `Client`. Named `Client` for the engine to find
 * it, as in `drawBlock`.
 */
const drawPlacement = (d: Drawing, placement: SitrepPlacement) => {
  if (!('Client' in d.els)) {
    return undefined
  }

  const { Box, Client } = d.els

  return (
    <Box key="placement:box" position="absolute" top={0} left={-1} width={1} height={1}>
      <Client key="placement" module="./placement.tsx" width={1} height={1} props={{ placement }} />
    </Box>
  )
}

/** The tabs over their rule, a blank row under it. */
const drawHeader = (d: Drawing, placement: SitrepPlacement) => {
  const { Box } = d.els

  return (
    <Box key="header" flexDirection="column" flexShrink={0} paddingBottom={GAP_ROWS}>
      {drawTabs(d)}
      {drawPlacement(d, placement)}
    </Box>
  )
}

/** The view of where the board is looking. */
const drawPlace = (d: Drawing): Block[] => {
  const { Text } = d.els
  const { place } = d.scene

  switch (place.level) {
    case 'session': {
      const filed = filedAt(d.scene, place.work)

      return filed === undefined
        ? [{ key: 'reading', element: <Text color={C.grey}>{READING}</Text> }]
        : drawSessionView(d, filed)
    }
    case 'project':
      return drawProjectView(d, place.project)
    case 'all':
      return drawAllView(d)
  }
}

type PaneProps = Pick<RenderPropsOf['Pane'], 'bodyColumns' | 'placement' | 'scroll'>

/** The cells across the board's lines: the body, less the column kept free each side. */
const widthOf = (props: PaneProps) => props.bodyColumns - 2

/** The rows a docked board's tree is short of its window: the engine has nothing to scroll. */
const SPARE_ROWS = 1

/** The blank row closing a docked board's list, so its last line never meets Ready to send. */
const END_ROWS = 1

/** The most rows of a docked board's window Ready to send takes: under half, so the list keeps the most of it. */
const readyCap = (bodyRows: number) => Math.floor((bodyRows - 1) / 2)

type ClientTag = ElementTable<'terminal'>['Client']

/**
 * A block of the list, a blank row before it where it says, and what
 * measures it where the list is clipped. The tag is named `Client`: the
 * engine finds the module it draws by that tag in this file's source, and
 * misses it under any other name (checked with `claude plugin validate`).
 */
const drawBlock = (d: Drawing, { key, element, isSpaced }: Block, Client?: ClientTag) => {
  const { Box } = d.els

  return (
    <Box
      key={`block:${key}`}
      flexDirection="column"
      flexShrink={0}
      paddingTop={isSpaced ? GAP_ROWS : undefined}
    >
      {element}
      {Client !== undefined && (
        // In the column the board keeps free beside its lines, where it covers nothing to press.
        <Box position="absolute" top={0} bottom={0} left={-1} width={1}>
          <Client
            key={`measure:${key}`}
            module="./measure.tsx"
            width={1}
            height="100%"
            props={{ id: key }}
          />
        </Box>
      )}
    </Box>
  )
}

/**
 * A docked board: a tree a row shorter than the window, so the engine has
 * nothing to scroll and never moves it; the header, still; the list in the
 * rows between it and Ready to send, clipped, and shifted up by how far
 * down it stands; Ready to send under it, still. Its last row runs past the
 * tree, and still shows.
 */
const drawClipped = (
  d: Drawing,
  Client: ClientTag,
  blocks: readonly Block[],
  props: PaneProps,
  clip: Clip,
) => {
  const { Box } = d.els
  const { bodyRows } = props.scroll
  const ready = readyOf(d.scene, d.width, readyCap(bodyRows))
  const footRows = ready === undefined ? SPARE_ROWS : readyRows(ready)
  const listRows = bodyRows - HEADER_ROWS - footRows
  const list = [...blocks, { key: 'end', element: <Box height={END_ROWS} /> }]
  const top = clip({ place: d.scene.place, listRows, blocks: list })

  return (
    <Box flexDirection="column" height={bodyRows - SPARE_ROWS}>
      <Box flexShrink={0} paddingX={1}>
        {drawHeader(d, props.placement)}
      </Box>
      <Box flexDirection="column" flexShrink={0} height={listRows} overflow="hidden">
        <Box flexDirection="column" flexShrink={0} marginTop={-top} paddingX={1}>
          {list.map(block => drawBlock(d, block, Client))}
        </Box>
      </Box>
      {ready !== undefined && (
        <Box flexShrink={0} paddingX={1}>
          {drawReady(d, ready)}
        </Box>
      )}
    </Box>
  )
}

/** A board inline, or docked where nothing can measure it: the header and the view, then Ready to send, at the foot of a docked window the view leaves short. */
const drawFlowing = (d: Drawing, blocks: readonly Block[], props: PaneProps) => {
  const { Box } = d.els
  const ready = readyOf(d.scene, d.width)

  return (
    <Box
      flexDirection="column"
      paddingX={1}
      minHeight={d.isDock ? props.scroll.bodyRows : undefined}
    >
      {drawHeader(d, props.placement)}
      {blocks.map(block => drawBlock(d, block))}
      <Box flexGrow={1} minHeight={GAP_ROWS} />
      {ready !== undefined && drawReady(d, ready)}
    </Box>
  )
}

export const drawPane = (
  els: Els,
  surface: RenderSurface,
  act: Actions,
  props: PaneProps,
  scene: Scene | undefined,
  clip: Clip,
) => {
  const { Box, Text } = els

  if (scene === undefined) {
    return (
      <Box paddingX={1}>
        <Text color={C.soft} wrap="wrap">
          {NO_WORK}
        </Text>
      </Box>
    )
  }

  const d: Drawing = {
    els,
    surface,
    act,
    scene,
    width: widthOf(props),
    isDock: props.placement === 'dock',
    back: backOf(scene),
  }
  const blocks = drawPlace(d)

  return d.isDock && 'Client' in els
    ? drawClipped(d, els.Client, blocks, props, clip)
    : drawFlowing(d, blocks, props)
}
