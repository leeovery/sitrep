/**
 * The glance: the board collapsed to a narrow column. Its counts on one
 * row, what is under way, what waits, the last few log lines; every line
 * opens the full board on what was clicked. `⇤ expand` sits where the
 * board's `⇥ collapse` does.
 */
import { isOpen } from '../../core'
import { ago, C, clip, counted, GLYPH } from '../look'
import type { Focus } from '../pane'
import { askMark, countMark } from '../scene'
import { heading, type Drawing } from './kit'
import { logKey } from './log'

/** How many of the latest log lines the glance shows. */
const LATELY = 3

const drawCounts = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const { work } = d.scene
  const mark = countMark(d.scene)

  return (
    <Box flexDirection="row" justifyContent="space-between">
      <Box flexDirection="row" columnGap={2}>
        <Box flexDirection="row" gap={1}>
          <Text color={mark.color}>{mark.glyph}</Text>
          <Button
            key="glance:for-you"
            plain
            dimColor={work.waiting === 0}
            label={`${work.waiting}`}
            onPress={() => d.act.open('full', { view: 'session' })}
          />
        </Box>
        <Box flexDirection="row" gap={1}>
          <Text color={C.parked}>{GLYPH.parked}</Text>
          <Button
            key="glance:parked"
            plain
            dimColor
            label={`${work.parked.length}`}
            onPress={() => d.act.open('full', { view: 'parked' })}
          />
        </Box>
      </Box>
      <Button key="expand" plain dimColor label="⇤ expand" onPress={() => d.act.open('full')} />
    </Box>
  )
}

/** A line of the glance: its mark, and a button opening the full board on it, the item it names opened. */
const drawLine = (
  d: Drawing,
  key: string,
  mark: { glyph: string; color: string },
  label: string,
  selected?: string,
) => {
  const { Box, Text, Button } = d.els
  const focus: Focus = selected === undefined ? { view: 'session' } : { view: 'session', selected }

  return (
    <Box key={key} flexDirection="row" gap={1}>
      <Text color={mark.color}>{mark.glyph}</Text>
      <Box flexGrow={1} flexShrink={1}>
        <Button
          key={`open:${key}`}
          plain
          label={clip(label, d.width - 2)}
          onPress={() => d.act.open('full', focus)}
        />
      </Box>
    </Box>
  )
}

const drawNow = (d: Drawing) => {
  const { Box } = d.els
  const { now, next } = d.scene.work.status

  return (
    <Box flexDirection="column">
      {heading(d, 'NOW', C.now, '')}
      {now.map((line, i) => drawLine(d, `gnow:${i}`, { glyph: GLYPH.now, color: C.now }, line))}
      {next !== undefined &&
        drawLine(d, 'gnext', { glyph: GLYPH.next, color: C.grey }, `next: ${next}`)}
    </Box>
  )
}

const drawWaiting = (d: Drawing) => {
  const { Box, Text } = d.els
  const asks = d.scene.work.asks.filter(isOpen).reverse()

  return (
    <Box flexDirection="column">
      {heading(d, 'FOR YOU', C.ask, '')}
      {asks.length === 0 && <Text color={C.grey}>Nothing waiting.</Text>}
      {asks.map(ask => drawLine(d, `gask:${ask.id}`, askMark(d.scene, ask), ask.title, ask.id))}
    </Box>
  )
}

const drawLately = (d: Drawing) => {
  const { Box, Text } = d.els
  const { log } = d.scene.work

  return (
    <Box flexDirection="column">
      {heading(d, 'LATELY', C.log, '')}
      {log.length === 0 && <Text color={C.grey}>Nothing yet.</Text>}
      {log
        .slice(0, LATELY)
        .map(line =>
          drawLine(
            d,
            `glog:${logKey(line)}`,
            { glyph: ago(d.scene.now, line.at), color: C.grey },
            line.text,
            logKey(line),
          ),
        )}
    </Box>
  )
}

export const drawGlance = (d: Drawing) => {
  const { Box, Button } = d.els
  const waiting = d.scene.queue.length

  return (
    <Box flexDirection="column" gap={1} paddingX={1}>
      {drawCounts(d)}
      {drawNow(d)}
      {drawWaiting(d)}
      {drawLately(d)}
      {waiting > 0 && (
        <Button
          key="glance:ready"
          plain
          label={`${GLYPH.done} ${counted(waiting, 'reply', 'replies')} ready to send`}
          onPress={() => d.act.open('full')}
        />
      )}
    </Box>
  )
}
