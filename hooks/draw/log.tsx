/**
 * A line of the log: its age, its mark, and what happened. A click opens
 * the detail behind it as a tree, and where Claude's own record of it is.
 * A project's log names the session each line came from.
 */
import type { LogLine } from '../../core'
import { ago, C, GLYPH } from '../look'
import {
  drawMark,
  drawTitle,
  seeRef,
  shown,
  titleLines,
  tree,
  type Drawing,
  type Mark,
} from './kit'

/** How each kind of line is marked: a note Claude wrote, a change of status, a pick-up. */
const MARK: Record<LogLine['kind'], Mark> = {
  note: { glyph: GLYPH.now, color: C.log },
  status: { glyph: GLYPH.now, color: C.now },
  pickup: { glyph: GLYPH.parked, color: C.parked },
}

/** What a log line is opened by: a note's id; a line the board derived, its kind and time. */
export const logKey = (line: LogLine) => line.id ?? `${line.kind}-${line.at}`

/** The cells a line's age takes before its mark; the tree hangs from the mark, a cell past them. */
const AGE_CELLS = 4

/** What a line opens to: its detail, then the pointer to Claude's own record; or that there is none. */
const detailOf = (line: LogLine) => {
  const detail = shown(...line.detail, seeRef(line.ref))

  return detail.length > 0 ? detail : [{ text: 'nothing more was recorded', color: C.grey }]
}

/** The session a line of a project's log came from: its id, and its name. */
type From = { work: string; name: string }

export const drawLogLine = (d: Drawing, line: LogLine, from?: From) => {
  const { Box, Text } = d.els
  const key = from === undefined ? logKey(line) : `${from.work}:${logKey(line)}`
  const text = from === undefined ? line.text : `${from.name}: ${line.text}`
  const isOpen = d.scene.pane.selected === key
  const lines = titleLines(d, text, isOpen)

  return (
    <Box key={`line:${key}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Box width={AGE_CELLS} flexShrink={0}>
          <Text color={C.grey}>{ago(d.scene.now, line.at)}</Text>
        </Box>
        {drawMark(d, MARK[line.kind], lines.length, isOpen)}
        <Box flexGrow={1} flexShrink={1}>
          {drawTitle(d, `log:${key}`, lines, () => d.act.select(key))}
        </Box>
      </Box>
      {isOpen && tree(d, `detail:${key}`, detailOf(line), AGE_CELLS + 1)}
    </Box>
  )
}
