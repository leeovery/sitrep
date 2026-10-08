/**
 * The board pane: where it is looking and its view there, or the glance,
 * with Ready to send at the foot; one line when the window holds no work.
 *
 * On Lee's own path up the tree the board shows a tab for each step of it,
 * each a row of `TABS`: this session, its project, every project. Anywhere
 * else the tabs give way to a step back up and the way home.
 */
import type { RenderPropsOf, RenderSurface } from 'claude-code'
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
import { drawGlance } from './glance'
import type { Drawing, Els } from './kit'
import { drawParkedView } from './parked'
import { drawProjectView } from './project'
import { drawReady } from './ready'
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

/** A tab's cells: its padding, glyph and label, and its count where it has one. */
const tabWidth = (count: number, label: string) =>
  4 + label.length + (count > 0 ? 1 + String(count).length : 0)

const drawTabs = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const { scene } = d
  const tabs = TABS.map(tab => ({
    ...tab,
    isOn: samePlace(scene.place, tab.to(scene)),
    waiting: tab.count(scene),
  }))
  const isNarrow =
    tabs.reduce((sum, tab) => sum + tabWidth(tab.waiting, tab.label(scene)), 0) > d.width
  const labelled = tabs.map(tab => {
    const text = isNarrow ? clip(tab.short(scene), 10) : tab.label(scene)

    return { ...tab, text, cells: tabWidth(tab.waiting, text) }
  })
  const used = labelled.reduce((sum, tab) => sum + tab.cells, 0)

  return (
    <Box flexDirection="column">
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
      <Box flexDirection="row">
        {labelled.map(tab => (
          <Text key={`${tab.key}:rule`} color={tab.isOn ? tab.color : C.rule}>
            {(tab.isOn ? '━' : '─').repeat(tab.cells)}
          </Text>
        ))}
        <Text color={C.rule}>{'─'.repeat(Math.max(0, d.width - used))}</Text>
      </Box>
    </Box>
  )
}

/** Off Lee's own path: one step back up the tree, and the way home. */
const drawBackRow = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const above = up(d.scene.place)
  const label = above.level === 'project' ? projectName(d.scene, above.project) : 'All projects'

  return (
    <Box flexDirection="column">
      <Box flexDirection="row" justifyContent="space-between">
        <Button key="up" plain label={`${GLYPH.up} ${label}`} onPress={() => d.act.go(above)} />
        <Button
          key="home"
          plain
          dimColor
          label={`${GLYPH.home} this session`}
          onPress={() => d.act.go(homeOf(d.scene))}
        />
      </Box>
      <Text color={C.rule}>{'─'.repeat(d.width)}</Text>
    </Box>
  )
}

/** What sits above the tabs: the way to what was parked here, and, docked, the collapse. */
const drawToolbar = (d: Drawing) => {
  const { Box, Button } = d.els

  return (
    <Box flexDirection="row" justifyContent="space-between">
      <Button
        key="parked"
        plain
        dimColor
        label={`${GLYPH.parked} ${parkedAt(d.scene).length} parked`}
        onPress={() => d.act.show('parked')}
      />
      {d.isDock && (
        <Button
          key="collapse"
          plain
          dimColor
          label="⇥ collapse"
          onPress={() => d.act.open('glance')}
        />
      )}
    </Box>
  )
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

const drawBoardView = (d: Drawing) => {
  const { Box } = d.els

  return (
    <Box flexDirection="column" gap={1}>
      {drawToolbar(d)}
      {/* The view's first line sits right under the tabs' rule, with no blank row between. */}
      <Box flexDirection="column">
        {isOnPath(d.scene) ? drawTabs(d) : drawBackRow(d)}
        {drawPlace(d)}
      </Box>
    </Box>
  )
}

type PaneProps = Pick<RenderPropsOf['Pane'], 'bodyColumns' | 'placement' | 'scroll'>

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
    width: props.bodyColumns - 2,
    isDock: props.placement === 'dock',
  }

  if (scene.pane.mode === 'glance') {
    return drawGlance(d)
  }

  return (
    <Box
      flexDirection="column"
      paddingX={1}
      minHeight={d.isDock ? props.scroll.bodyRows : undefined}
    >
      {scene.pane.view === 'parked' ? drawParkedView(d) : drawBoardView(d)}
      {/* Ready to send keeps to the foot of a docked board, however short the view. */}
      <Box flexGrow={1} minHeight={1} />
      {drawReady(d)}
    </Box>
  )
}
