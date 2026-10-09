/**
 * The board pane: where it is looking and its view there, with Ready to
 * send at the foot; one line when the window holds no work. The view is a
 * list of blocks. Docked, the list is clipped above Ready to send, which
 * never moves, and a `Client` measures each block (hooks/clip.ts); inline,
 * Ready to send follows the view.
 *
 * On Lee's own path the board shows a tab for each step of it, each a row
 * of `TABS`: this session, by its glyph alone, and every project. Anywhere
 * else the tabs give way to a step back up and the way home.
 */
import type { ElementTable, RenderElement, RenderPropsOf, RenderSurface } from 'claude-code'
import type { SitrepPlace } from '../../types'
import type { Actions } from '../actions'
import type { Clip } from '../clip'
import { C, GLYPH } from '../look'
import {
  EVERY_PROJECT,
  everyProject,
  filedAt,
  homeOf,
  isOnPath,
  projectName,
  samePlace,
  up,
} from '../places'
import type { Scene } from '../scene'
import { drawAllView } from './every'
import type { Block, Drawing, Els } from './kit'
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
  /** Its words after the glyph; with none, the glyph is the press. */
  label?: string
  color: string
  count: (scene: Scene) => number
  /** Where the tab takes the board. */
  to: (scene: Scene) => SitrepPlace
}

const TABS: readonly Tab[] = [
  {
    key: 'tab:session',
    glyph: GLYPH.home,
    color: C.now,
    count: scene => scene.work.waiting,
    to: homeOf,
  },
  {
    key: 'tab:all',
    glyph: GLYPH.every,
    label: 'All projects',
    color: C.parked,
    count: scene => everyProject(scene).projects.reduce((sum, project) => sum + project.waiting, 0),
    to: () => EVERY_PROJECT,
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

/** A row's ways around the board: the buttons, the cells they take, and the rule under them. */
type Ways = { row: RenderElement; used: number; rule: RenderElement }

/** A row of ways around the board over its rule, the rule running on to the edge. */
const drawWays = (d: Drawing, { row, used, rule }: Ways) => {
  const { Box } = d.els

  return (
    <Box flexDirection="column">
      {row}
      <Box flexDirection="row">
        {rule}
        {ruleUnder(d, 'ways:rule', Math.max(0, d.width - used))}
      </Box>
    </Box>
  )
}

/** A tab's words: its glyph, its label where it has one, and its count where anything waits. */
const wordsOf = (tab: Tab, waiting: number) => [
  tab.glyph,
  ...(tab.label === undefined ? [] : [tab.label]),
  ...(waiting > 0 ? [String(waiting)] : []),
]

/** A tab's cells: its padding each side, and its words a cell apart. */
const tabWidth = (words: readonly string[]) => 2 + words.join(' ').length

/** A tab's glyph and label: the glyph in its colour, the label the press; or, with no label, the glyph the press. */
const drawTabName = (d: Drawing, tab: Tab, isOn: boolean) => {
  const { Text, Button } = d.els
  const go = () => d.act.go(tab.to(d.scene))
  const press = (label: string) => (
    <Button key={tab.key} plain dimColor={!isOn} label={label} onPress={go} />
  )

  return tab.label === undefined
    ? [press(tab.glyph)]
    : [
        <Text key={`${tab.key}:glyph`} color={isOn ? tab.color : C.grey}>
          {tab.glyph}
        </Text>,
        press(tab.label),
      ]
}

/** The tabs, the current one lit, each with what waits there. */
const drawTabs = (d: Drawing) => {
  const { Box, Text } = d.els
  const { scene } = d
  const tabs = TABS.map(tab => {
    const waiting = tab.count(scene)

    return {
      tab,
      waiting,
      isOn: samePlace(scene.place, tab.to(scene)),
      cells: tabWidth(wordsOf(tab, waiting)),
    }
  })

  const row = (
    <Box flexDirection="row">
      {tabs.map(({ tab, waiting, isOn, cells }) => (
        <Box
          key={`${tab.key}:box`}
          width={cells}
          flexShrink={0}
          paddingX={1}
          flexDirection="row"
          gap={1}
          backgroundColor={isOn ? C.tab : undefined}
        >
          {drawTabName(d, tab, isOn)}
          {waiting > 0 && <Text color={isOn ? C.ask : C.grey}>{waiting}</Text>}
        </Box>
      ))}
    </Box>
  )

  const rule = (
    <Box flexDirection="row">
      {tabs.map(({ tab, isOn, cells }) =>
        ruleUnder(d, `${tab.key}:rule`, cells, isOn ? tab.color : undefined),
      )}
    </Box>
  )

  return drawWays(d, { row, used: tabs.reduce((sum, tab) => sum + tab.cells, 0), rule })
}

/** The gap between the step back up and the way home. */
const BACK_GAP = 2

/** Off Lee's own path: one step back up the tree, and the way home. */
const drawBackRow = (d: Drawing) => {
  const { Box, Button } = d.els
  const above = up(d.scene.place)
  const upLabel = `${GLYPH.up} ${above.level === 'project' ? projectName(d.scene, above.project) : 'All projects'}`
  const used = upLabel.length + BACK_GAP + GLYPH.home.length
  const row = (
    <Box flexDirection="row" gap={BACK_GAP}>
      <Button key="up" plain label={upLabel} onPress={() => d.act.go(above)} />
      <Button
        key="home"
        plain
        dimColor
        label={GLYPH.home}
        onPress={() => d.act.go(homeOf(d.scene))}
      />
    </Box>
  )

  return drawWays(d, { row, used, rule: ruleUnder(d, 'back:rule', used) })
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

/** The tabs, or the back row, over the view of where the board is looking; the view's first line right under their rule. */
const drawView = (d: Drawing): Block[] => [
  { key: 'ways', element: isOnPath(d.scene) ? drawTabs(d) : drawBackRow(d) },
  ...drawPlace(d),
]

type PaneProps = Pick<RenderPropsOf['Pane'], 'bodyColumns' | 'placement' | 'scroll'>

/** The cells across the board's lines: the body, less the column kept free each side. */
const widthOf = (props: PaneProps) => props.bodyColumns - 2

/** The blank row between parts of the board, and between the view and Ready to send inline. */
const GAP_ROWS = 1

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
 * nothing to scroll and never moves it; the list in the rows above Ready to
 * send, clipped, and shifted up by how far down it stands; Ready to send
 * under it, still. Its last row runs past the tree, and still shows.
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
  const listRows = bodyRows - (ready === undefined ? SPARE_ROWS : readyRows(ready))
  const list = [...blocks, { key: 'end', element: <Box height={END_ROWS} /> }]
  const top = clip({ place: d.scene.place, listRows, blocks: list })

  return (
    <Box flexDirection="column" height={bodyRows - SPARE_ROWS}>
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

/** A board inline, or docked where nothing can measure it: Ready to send after the view, at the foot of a docked window the view leaves short. */
const drawFlowing = (d: Drawing, blocks: readonly Block[], props: PaneProps) => {
  const { Box } = d.els
  const ready = readyOf(d.scene, d.width)

  return (
    <Box
      flexDirection="column"
      paddingX={1}
      minHeight={d.isDock ? props.scroll.bodyRows : undefined}
    >
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
  }
  const blocks = drawView(d)

  return d.isDock && 'Client' in els
    ? drawClipped(d, els.Client, blocks, props, clip)
    : drawFlowing(d, blocks, props)
}
