/**
 * The board pane: where it is looking and its view there, or what was
 * parked there, with Ready to send at the foot; one line when the window
 * holds no work. Docked, Ready to send floats over the foot of the window
 * as the board scrolls; inline, it follows the view.
 *
 * On Lee's own path up the tree the board shows a tab for each step of it,
 * each a row of `TABS`: this session, its project, every project. Anywhere
 * else the tabs give way to a step back up and the way home. Either row
 * ends in the way to what was parked where the board looks, lit as a tab
 * is while that is open.
 */
import type { RenderElement, RenderPropsOf, RenderSurface, SiteScroll } from 'claude-code'
import type { SitrepPlace } from '../../types'
import type { Actions } from '../actions'
import { C, clip, GLYPH } from '../look'
import {
  EVERY_PROJECT,
  everyProject,
  filedAt,
  homeOf,
  isAllRead,
  isOnPath,
  parkedAt,
  projectAt,
  projectName,
  projectPlace,
  samePlace,
  up,
} from '../places'
import type { Scene } from '../scene'
import { drawAllView } from './every'
import type { Drawing, Els } from './kit'
import { drawParkedView } from './parked'
import { drawProjectView } from './project'
import { drawReady, readyOf, readyRows, type Ready } from './ready'
import { drawSessionView } from './session'

const NO_WORK =
  'This window holds no piece of work. Ask Claude to start one on the sitrep board, or to join one by its id.'

/** A session the board has not read yet: it reads it as it opens there. */
const READING = 'Reading the board…'

type Tab = {
  key: string
  glyph: string
  label: (scene: Scene) => string
  /** Its label where the tabs' full labels will not fit. */
  short: (scene: Scene) => string
  color: string
  count: (scene: Scene) => number
  /** Where the tab takes the board. */
  to: (scene: Scene) => SitrepPlace
}

const TABS: readonly Tab[] = [
  {
    key: 'tab:session',
    glyph: GLYPH.home,
    label: () => 'This session',
    short: () => 'Session',
    color: C.now,
    count: scene => scene.work.waiting,
    to: homeOf,
  },
  {
    key: 'tab:project',
    glyph: GLYPH.project,
    label: scene => projectName(scene, scene.here),
    short: scene => projectName(scene, scene.here),
    color: C.log,
    count: scene => projectAt(scene, scene.here).summary.waiting,
    to: scene => projectPlace(scene.here),
  },
  {
    key: 'tab:all',
    glyph: GLYPH.every,
    label: () => 'All projects',
    short: () => 'All',
    color: C.parked,
    // Every project is read only while the board looks at all of them, so only then is there a count.
    count: scene =>
      isAllRead(scene)
        ? everyProject(scene).projects.reduce((sum, project) => sum + project.waiting, 0)
        : 0,
    to: () => EVERY_PROJECT,
  },
]

/** The least room kept between a row's ways around the board and the parked count ending it: the count's own first cell, lit with it. */
const PARKED_GAP = 1

/** The parked count's label with `room` cells left on its row: in full, or only the count where the word will not fit. */
const parkedLabel = (scene: Scene, room: number) => {
  const count = `${GLYPH.parked} ${parkedAt(scene).length}`
  const full = `${count} parked`

  return room >= PARKED_GAP + full.length ? full : count
}

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

/**
 * A row of ways around the board and the rule under it, the parked count
 * right-aligned at its end: lit as a tab is while the parked view is open,
 * where pressing it goes back to the board.
 */
const withParked = (d: Drawing, { row, used, rule }: Ways, label: string) => {
  const { Box, Button } = d.els
  const isOn = d.scene.pane.view === 'parked'
  const cells = PARKED_GAP + label.length
  const gap = Math.max(0, d.width - used - cells)

  return (
    <Box flexDirection="column">
      <Box flexDirection="row">
        {row}
        <Box width={gap} flexShrink={0} />
        <Box
          key="parked:box"
          width={cells}
          flexShrink={0}
          paddingLeft={PARKED_GAP}
          backgroundColor={isOn ? C.tab : undefined}
        >
          <Button
            key="parked"
            plain
            dimColor={!isOn}
            label={label}
            onPress={() => d.act.show(isOn ? 'board' : 'parked')}
          />
        </Box>
      </Box>
      <Box flexDirection="row">
        {rule}
        {ruleUnder(d, 'gap:rule', gap)}
        {ruleUnder(d, 'parked:rule', cells, isOn ? C.parked : undefined)}
      </Box>
    </Box>
  )
}

/** A tab's cells: its padding, glyph and label, and its count where it has one. */
const tabWidth = (count: number, label: string) =>
  4 + label.length + (count > 0 ? 1 + String(count).length : 0)

/** The tabs, their full labels giving way to short ones where those and the parked count will not fit; none is current while the parked view is. */
const drawTabs = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const { scene } = d
  const tabs = TABS.map(tab => ({
    ...tab,
    isOn: scene.pane.view === 'board' && samePlace(scene.place, tab.to(scene)),
    waiting: tab.count(scene),
  }))
  const room = d.width - tabs.reduce((sum, tab) => sum + tabWidth(tab.waiting, tab.label(scene)), 0)
  const parked = parkedLabel(scene, room)
  const isNarrow = room < PARKED_GAP + parked.length
  const labelled = tabs.map(tab => {
    const text = isNarrow ? clip(tab.short(scene), 10) : tab.label(scene)

    return { ...tab, text, cells: tabWidth(tab.waiting, text) }
  })
  const used = labelled.reduce((sum, tab) => sum + tab.cells, 0)

  const row = (
    <Box flexDirection="row">
      {labelled.map(tab => (
        <Box
          key={`${tab.key}:box`}
          width={tab.cells}
          flexShrink={0}
          paddingX={1}
          flexDirection="row"
          gap={1}
          backgroundColor={tab.isOn ? C.tab : undefined}
        >
          <Text color={tab.isOn ? tab.color : C.grey}>{tab.glyph}</Text>
          <Button
            key={tab.key}
            plain
            dimColor={!tab.isOn}
            label={tab.text}
            onPress={() => d.act.go(tab.to(scene))}
          />
          {tab.waiting > 0 && <Text color={tab.isOn ? C.ask : C.grey}>{tab.waiting}</Text>}
        </Box>
      ))}
    </Box>
  )

  const rule = (
    <Box flexDirection="row">
      {labelled.map(tab =>
        ruleUnder(d, `${tab.key}:rule`, tab.cells, tab.isOn ? tab.color : undefined),
      )}
    </Box>
  )

  return withParked(d, { row, used, rule }, parked)
}

/** The gap between the step back up and the way home. */
const BACK_GAP = 2

const HOME_LABEL = `${GLYPH.home} this session`

/** Off Lee's own path: one step back up the tree and the way home, the parked count where the tabs keep it. */
const drawBackRow = (d: Drawing) => {
  const { Box, Button } = d.els
  const above = up(d.scene.place)
  const upLabel = `${GLYPH.up} ${above.level === 'project' ? projectName(d.scene, above.project) : 'All projects'}`
  const used = upLabel.length + BACK_GAP + HOME_LABEL.length
  const row = (
    <Box flexDirection="row" gap={BACK_GAP}>
      <Button key="up" plain label={upLabel} onPress={() => d.act.go(above)} />
      <Button
        key="home"
        plain
        dimColor
        label={HOME_LABEL}
        onPress={() => d.act.go(homeOf(d.scene))}
      />
    </Box>
  )

  const rule = ruleUnder(d, 'back:rule', used)

  return withParked(d, { row, used, rule }, parkedLabel(d.scene, d.width - used))
}

/** The view of where the board is looking. */
const drawPlace = (d: Drawing) => {
  const { Text } = d.els
  const { place } = d.scene

  switch (place.level) {
    case 'session': {
      const filed = filedAt(d.scene, place.work)

      return filed === undefined ? <Text color={C.grey}>{READING}</Text> : drawSessionView(d, filed)
    }
    case 'project':
      return drawProjectView(d, place.project)
    case 'all':
      return drawAllView(d)
  }
}

/** The tabs, or the back row, over the view of where the board is looking or what was parked there; the view's first line right under their rule. */
const drawView = (d: Drawing) => {
  const { Box } = d.els

  return (
    <Box flexDirection="column">
      {isOnPath(d.scene) ? drawTabs(d) : drawBackRow(d)}
      {d.scene.pane.view === 'parked' ? drawParkedView(d) : drawPlace(d)}
    </Box>
  )
}

type PaneProps = Pick<RenderPropsOf['Pane'], 'bodyColumns' | 'placement' | 'scroll'>

/** The cells across the board's lines: the body, less the column kept free each side. */
const widthOf = (props: PaneProps) => props.bodyColumns - 2

/** The most rows of a docked board's window Ready to send floats over: under half, so a button the focus brings to the middle shows above it. */
const readyCap = (bodyRows: number) => Math.floor((bodyRows - 1) / 2)

/** The blank row between the board's last line and Ready to send. */
const READY_GAP = 1

/**
 * Whether Ready to send floats: on a docked board, while no field is open.
 * A click gives the field's text area the keys without raising `ui.focus`,
 * so nothing would bring one the box covered clear of it: while a field is
 * open, the box keeps to the foot of the view.
 */
const floats = (props: PaneProps, scene: Scene) =>
  props.placement === 'dock' && scene.pane.commenting === null

/** Ready to send as a docked board floats it; undefined where it does not float, or with nothing in it. */
const floatingOf = (props: PaneProps, scene: Scene | undefined): Ready | undefined =>
  scene !== undefined && floats(props, scene)
    ? readyOf(scene, widthOf(props), readyCap(props.scroll.bodyRows))
    : undefined

/** The rows at the foot of the board's window Ready to send floats over; none where it does not float. */
export const floatingRows = (props: PaneProps, scene: Scene | undefined) => {
  const floating = floatingOf(props, scene)

  return floating === undefined ? 0 : readyRows(floating)
}

/**
 * A docked board, Ready to send floating over the foot of its window: the
 * engine scrolls the whole tree, and every drawing places the box again
 * from where the window stands. Rows as tall as the box close the tree, so
 * its last line scrolls clear of it. The tree is never shorter than the
 * window as it stands: one shrinking under a scrolled window would have the
 * engine pull the window up without drawing again, leaving the box mid-pane.
 */
const drawFloating = (d: Drawing, view: RenderElement, ready: Ready, scroll: SiteScroll) => {
  const { Box } = d.els
  const rows = readyRows(ready)
  const foot = scroll.offset + scroll.bodyRows

  return (
    <Box flexDirection="column" minHeight={foot}>
      <Box flexDirection="column" paddingX={1}>
        {view}
      </Box>
      <Box height={READY_GAP + rows} flexShrink={0} />
      <Box position="absolute" top={foot - rows} left={0} right={0} paddingX={1}>
        {drawReady(d, ready, C.pane)}
      </Box>
    </Box>
  )
}

export const drawPane = (
  els: Els,
  surface: RenderSurface,
  act: Actions,
  props: PaneProps,
  scene: Scene | undefined,
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

  const view = drawView(d)
  const floating = floatingOf(props, scene)

  if (floating !== undefined) {
    return drawFloating(d, view, floating, props.scroll)
  }

  const ready = readyOf(scene, d.width)

  return (
    <Box
      flexDirection="column"
      paddingX={1}
      minHeight={d.isDock ? props.scroll.bodyRows : undefined}
    >
      {view}
      <Box flexGrow={1} minHeight={1} />
      {ready !== undefined && drawReady(d, ready)}
    </Box>
  )
}
