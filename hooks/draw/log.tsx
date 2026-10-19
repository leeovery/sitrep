/**
 * NOTES: its heading, then a line for each thing that happened, its mark,
 * what happened, and its age. A click opens the detail behind it as a
 * tree, and where Claude's own record of it is. A project's NOTES names
 * the session each line came from.
 */
import { labelOf, type LogLine } from '../../core'
import { C, GLYPH } from '../look'
import { itemKey } from '../places'
import {
  drawRow,
  emptyLine,
  heading,
  seeRef,
  shown,
  type Block,
  type Branch,
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

/** A line of a log line's detail as its branch: a status change's opens with its label, in the line's colour; any other is soft. */
const branchOf = (line: LogLine, text: string): Branch => {
  const labelled = line.kind === 'status' ? labelOf(text) : undefined

  return labelled === undefined ? text : { ...labelled, color: MARK[line.kind].color }
}

/** What a line opens to: its detail, then the pointer to Claude's own record; or that there is none. */
const detailOf = (line: LogLine) => {
  const detail = shown(
    ...line.detail.map(text => branchOf(line, text)),
    seeRef(line.ref, MARK[line.kind].color),
  )

  return detail.length > 0 ? detail : ['nothing more was recorded']
}

/** A line as a log lists it: the session it came from, and in a project's, that session's name. */
export type Logged = { line: LogLine; session: string; name?: string }

/** A line of the log, as a block of its own. */
const drawLogLine = (d: Drawing, { line, session, name }: Logged): Block => {
  const key = itemKey(session, logKey(line))
  const isOpen = d.scene.pane.selected === key
  const row = `line:${key}`

  return {
    key: row,
    element: drawRow(d, {
      key: row,
      mark: MARK[line.kind],
      title: name === undefined ? line.text : `${name}: ${line.text}`,
      at: line.at,
      isOpen,
      press: { key: `log:${key}`, onPress: () => d.act.select(key) },
      branches: isOpen ? detailOf(line) : [],
    }),
  }
}

/** NOTES' heading, then each line it lists. */
export const drawLog = (d: Drawing, lines: readonly Logged[]): Block[] => {
  const { Box } = d.els

  return [
    {
      key: 'log',
      element: (
        <Box flexDirection="column">
          {heading(d, 'NOTES', C.log, 'what happened')}
          {lines.length === 0 && emptyLine(d, 'Nothing yet.')}
        </Box>
      ),
    },
    ...lines.map(logged => drawLogLine(d, logged)),
  ]
}
