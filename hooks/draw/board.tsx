/**
 * The board pane: the tabs and the view they show, or the glance, with
 * Ready to send at the foot; one line when the window holds no work.
 *
 * Lee's own path is tabs: this session, then (slice 4) its project and
 * every project. Each tab is a row of `TABS`, so another is one more row.
 */
import type { RenderPropsOf, RenderSurface } from 'claude-code'
import type { Actions } from '../actions'
import { C, clip, GLYPH } from '../look'
import type { Scene } from '../scene'
import { drawGlance } from './glance'
import type { Drawing, Els } from './kit'
import { drawParkedView } from './parked'
import { drawReady } from './ready'
import { drawSessionView } from './session'

const NO_WORK =
  'This window holds no piece of work. Ask Claude to start one on the sitrep board, or to join one by its id.'

type Tab = {
  key: string
  glyph: string
  label: string
  /** Its label where the tabs' full labels will not fit. */
  short: string
  color: string
  count: (d: Drawing) => number
  /** Whether the board shows the tab's view. */
  shows: (d: Drawing) => boolean
  press: (d: Drawing) => void
}

const TABS: readonly Tab[] = [
  {
    key: 'tab:session',
    glyph: GLYPH.home,
    label: 'This session',
    short: 'Session',
    color: C.now,
    count: d => d.scene.work.waiting,
    shows: () => true,
    press: d => d.act.show('session'),
  },
]

/** A tab's cells: its padding, glyph and label, and its count where it has one. */
const tabWidth = (count: number, label: string) =>
  4 + label.length + (count > 0 ? 1 + String(count).length : 0)

const drawTabs = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const tabs = TABS.map(tab => ({ ...tab, isOn: tab.shows(d), waiting: tab.count(d) }))
  const isNarrow = tabs.reduce((sum, tab) => sum + tabWidth(tab.waiting, tab.label), 0) > d.width
  const labelled = tabs.map(tab => {
    const label = isNarrow ? clip(tab.short, 10) : tab.label

    return { ...tab, label, cells: tabWidth(tab.waiting, label) }
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
              label={tab.label}
              onPress={() => tab.press(d)}
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

/** What sits above the tabs: the way to parked, and, docked, the collapse. */
const drawToolbar = (d: Drawing) => {
  const { Box, Button } = d.els

  return (
    <Box flexDirection="row" justifyContent="space-between">
      <Button
        key="parked"
        plain
        dimColor
        label={`${GLYPH.parked} ${d.scene.work.parked.length} parked`}
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

const drawBoardView = (d: Drawing) => {
  const { Box } = d.els

  return (
    <Box flexDirection="column" gap={1}>
      {drawToolbar(d)}
      {/* The view's first line sits right under the tabs' rule, with no blank row between. */}
      <Box flexDirection="column">
        {drawTabs(d)}
        {drawSessionView(d)}
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
