/**
 * A line of the log: its age, its mark, and what happened. A click opens
 * the detail behind it as a tree, and where Claude's own record of it is.
 */
import type { LogLine } from '../../core'
import { ago, C, clip, GLYPH } from '../look'
import { tree, type Drawing } from './kit'

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

export const drawLogLine = (d: Drawing, line: LogLine) => {
  const { Box, Text, Button } = d.els
  const key = logKey(line)
  const mark = MARK[line.kind]

  return (
    <Box key={`line:${key}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Box width={4} flexShrink={0}>
          <Text color={C.grey}>{ago(d.scene.now, line.at)}</Text>
        </Box>
        <Text color={mark.color}>{mark.glyph}</Text>
        <Box flexGrow={1} flexShrink={1}>
          <Button
            key={`log:${key}`}
            plain
            label={clip(line.text, d.width - 8)}
            onPress={() => d.act.select(key)}
          />
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
