/**
 * A project's view: its sessions, this one first, each with what it is
 * doing and what waits on Lee there; every session's asks, answered from
 * here; the project's log; and what its sessions put off. Each ask, log
 * line and parked item names its session. A session opens its own view.
 */
import type { WorkSummary } from '../../core'
import { C, clip, GLYPH } from '../look'
import { askedIn, hereFirst, parkedIn, projectAt } from '../places'
import { drawForYou } from './ask'
import { context, heading, spaced, waitingWords, type Block, type Drawing } from './kit'
import { drawLog } from './log'
import { drawParked } from './parked'

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

/** SESSIONS' heading, then each session, a blank row between each and the next. */
const drawSessions = (d: Drawing, key: string, sessions: readonly WorkSummary[], open: number) => [
  { key: 'sessions', element: heading(d, 'SESSIONS', C.log, `${open} of ${sessions.length} open`) },
  ...spaced(
    ...sessions.map(work => [{ key: `sess:${work.id}`, element: drawSession(d, key, work) }]),
  ),
]

/** The view's sections, a blank row between each and the next. */
export const drawProjectView = (d: Drawing, key: string): Block[] => {
  const { summary, log, works } = projectAt(d.scene, key)
  const names = new Map(works.map(work => [work.id, work.name]))
  const lines = log.slice(0, d.isDock ? LOG_LINES.dock : LOG_LINES.inline)

  return spaced(
    [{ key: 'context', element: context(d, summary.name, waitingWords(summary.waiting)) }],
    drawSessions(d, key, hereFirst(d.scene, summary.works), summary.open),
    drawForYou(d, askedIn(d.scene, key), {
      waiting: summary.waiting,
      isHome: key === d.scene.here,
      isNamed: true,
    }),
    drawLog(
      d,
      lines.map(line => ({
        line,
        from: { work: line.work, name: names.get(line.work) ?? line.work },
      })),
    ),
    drawParked(d, parkedIn(d.scene, key), true),
  )
}
