/**
 * A project's view: its sessions, this one first, each with what it is
 * doing and what waits on Lee there; and the project's log, each line
 * naming its session. A session opens its own view.
 */
import type { WorkSummary } from '../../core'
import { C, clip, GLYPH } from '../look'
import { hereFirst, projectAt } from '../places'
import { context, heading, waitingWords, type Drawing } from './kit'
import { drawLogLine } from './log'

/** How many log lines the view shows, docked and inline. */
const LOG_LINES = { dock: 6, inline: 3 }

/** What a session is doing, in a line: what is under way, else what is next, else what it is for. */
const doingOf = ({ now, next, summary }: WorkSummary) => {
  if (now.length > 0) {
    return now.join(' · ')
  }

  return next === undefined ? summary : `next: ${next}`
}

const drawSession = (d: Drawing, project: string, work: WorkSummary) => {
  const { Box, Text, Button } = d.els
  const isHere = work.id === d.scene.work.id

  return (
    <Box key={`sess:${work.id}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1} flexDirection="row" gap={1}>
          <Button
            key={`go:${work.id}`}
            plain
            dimColor={!work.isOpen}
            label={clip(work.name, d.width - 14)}
            onPress={() => d.act.go({ level: 'session', project, work: work.id })}
          />
          {isHere && <Text color={C.now}>{GLYPH.home}</Text>}
        </Box>
        {work.waiting > 0 ? (
          <Text color={C.ask}>{work.waiting} waiting</Text>
        ) : (
          !work.isOpen && <Text color={C.faint}>closed</Text>
        )}
      </Box>
      <Box flexDirection="row" gap={1}>
        <Text color={C.faint}>{GLYPH.last}</Text>
        <Box flexGrow={1} flexShrink={1}>
          <Text color={work.isOpen ? C.soft : C.faint} wrap="truncate-end">
            {doingOf(work)}
          </Text>
        </Box>
      </Box>
    </Box>
  )
}

export const drawProjectView = (d: Drawing, key: string) => {
  const { Box, Text } = d.els
  const { summary, log, works } = projectAt(d.scene, key)
  const sessions = hereFirst(d.scene, summary.works)
  const names = new Map(works.map(work => [work.id, work.name]))
  const lines = log.slice(0, d.isDock ? LOG_LINES.dock : LOG_LINES.inline)

  return (
    <Box flexDirection="column" gap={1}>
      {context(d, summary.name, waitingWords(summary.waiting))}
      <Box flexDirection="column">
        {heading(d, 'SESSIONS', C.log, `${summary.open} of ${sessions.length} open`)}
        <Box flexDirection="column" rowGap={1}>
          {sessions.map(work => drawSession(d, key, work))}
        </Box>
      </Box>
      <Box flexDirection="column">
        {heading(d, 'LOG', C.log, 'what happened')}
        {lines.length === 0 && <Text color={C.grey}>Nothing yet.</Text>}
        {lines.map(line =>
          drawLogLine(d, line, { work: line.work, name: names.get(line.work) ?? line.work }),
        )}
      </Box>
    </Box>
  )
}
