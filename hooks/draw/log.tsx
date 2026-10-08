/**
 * A line of the log: its age, its mark, and what happened. A click opens
 * the detail behind it as a tree, and where Claude's own record of it is.
 * A project's log names the session each line came from.
 */
import type { LogLine } from '../../core'
import { ago, C, GLYPH } from '../look'
import { drawTitle, tree, type Drawing } from './kit'

/** How each kind of line is marked: a note Claude wrote, a change of status, a pick-up. */
const MARK: Record<LogLine['kind'], { glyph: string; color: string }> = {
  note: { glyph: GLYPH.now, color: C.log },
  status: { glyph: GLYPH.now, color: C.now },
  pickup: { glyph: GLYPH.parked, color: C.parked },
}

/** What a log line is opened by: a note's id; a line the board derived, its kind and time. */
export const logKey = (line: LogLine) => line.id ?? `${line.kind}-${line.at}`

/** What a line opens to: its detail, then the pointer to Claude's own record. */
const detailOf = (line: LogLine) => [
  ...line.detail,
  ...(line.ref === undefined ? [] : [`see ${line.ref}`]),
]

/** The session a line of a project's log came from: its id, and its name. */
type From = { work: string; name: string }

export const drawLogLine = (d: Drawing, line: LogLine, from?: From) => {
  const { Box, Text } = d.els
  const key = from === undefined ? logKey(line) : `${from.work}:${logKey(line)}`
  const text = from === undefined ? line.text : `${from.name}: ${line.text}`
  const mark = MARK[line.kind]

  return (
    <Box key={`line:${key}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Box width={4} flexShrink={0}>
          <Text color={C.grey}>{ago(d.scene.now, line.at)}</Text>
        </Box>
        <Text color={mark.color}>{mark.glyph}</Text>
        <Box flexGrow={1} flexShrink={1}>
          {drawTitle(d, `log:${key}`, text, d.scene.pane.selected === key, () => d.act.select(key))}
        </Box>
      </Box>
      {d.scene.pane.selected === key && (
        <Box flexDirection="column" paddingLeft={5}>
          {tree(d, `detail:${key}`, detailOf(line), 'nothing more was recorded')}
        </Box>
      )}
    </Box>
  )
}
