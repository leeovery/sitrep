/**
 * A line of the log: its mark, what happened, and its age. A click opens
 * the detail behind it as a tree, and where Claude's own record of it is.
 * A project's log names the session each line came from.
 */
import type { LogLine } from '../../core'
import { C, GLYPH } from '../look'
import { drawRow, seeRef, shown, type Drawing, type Mark } from './kit'

/** How each kind of line is marked: a note Claude wrote, a change of status, a pick-up. */
const MARK: Record<LogLine['kind'], Mark> = {
  note: { glyph: GLYPH.now, color: C.log },
  status: { glyph: GLYPH.now, color: C.now },
  pickup: { glyph: GLYPH.parked, color: C.parked },
}

/** What a log line is opened by: a note's id; a line the board derived, its kind and time. */
export const logKey = (line: LogLine) => line.id ?? `${line.kind}-${line.at}`

/** What a line opens to: its detail, then the pointer to Claude's own record; or that there is none. */
const detailOf = (line: LogLine) => {
  const detail = shown(...line.detail, seeRef(line.ref))

  return detail.length > 0 ? detail : [{ text: 'nothing more was recorded', color: C.grey }]
}

/** The session a line of a project's log came from: its id, and its name. */
type From = { work: string; name: string }

export const drawLogLine = (d: Drawing, line: LogLine, from?: From) => {
  const key = from === undefined ? logKey(line) : `${from.work}:${logKey(line)}`
  const isOpen = d.scene.pane.selected === key

  return drawRow(d, {
    key: `line:${key}`,
    mark: MARK[line.kind],
    title: from === undefined ? line.text : `${from.name}: ${line.text}`,
    at: line.at,
    isOpen,
    press: { key: `log:${key}`, onPress: () => d.act.select(key) },
    branches: isOpen ? detailOf(line) : [],
  })
}
