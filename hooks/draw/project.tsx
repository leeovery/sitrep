/**
 * A project's view: its sessions, this one first, each with what it is
 * doing and what waits on Lee there, and under them how their status
 * changed; every session's asks, answered from here; and what its sessions
 * put off, and what was taken off that. Each ask, change and parked item
 * names its session. A session opens its own view.
 */
import type { SessionSummary } from '../../core'
import { C, clip, GLYPH } from '../look'
import { askedIn, hereFirst, parkedIn, projectAt, takenOffIn } from '../places'
import { drawAsks } from './ask'
import { drawHistory, type Changed } from './history'
import { context, heading, NONE_OPEN, spaced, waitingWords, type Block, type Drawing } from './kit'
import { drawParked } from './parked'

/** What a session is doing, in a line: what is under way, else what is next, else what it is for. */
const doingOf = ({ now, next, summary }: SessionSummary) => {
  if (now.length > 0) {
    return now.join(' · ')
  }

  return next === undefined ? summary : `next: ${next}`
}

const drawSession = (d: Drawing, project: string, session: SessionSummary) => {
  const { Box, Text, Button } = d.els
  const isHere = session.id === d.scene.session.id

  return (
    <Box key={`sess:${session.id}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Box flexGrow={1} flexShrink={1} flexDirection="row" gap={1}>
          <Button
            key={`go:${session.id}`}
            plain
            dimColor={!session.isOpen}
            label={clip(session.name, d.width - 14)}
            onPress={() => d.act.go({ level: 'session', project, session: session.id })}
          />
          {isHere && <Text color={C.now}>{GLYPH.home}</Text>}
        </Box>
        {session.waiting > 0 ? (
          <Text color={C.ask}>{session.waiting} waiting</Text>
        ) : (
          !session.isOpen && <Text color={C.faint}>closed</Text>
        )}
      </Box>
      <Box flexDirection="row" gap={1}>
        <Text color={C.faint}>{GLYPH.last}</Text>
        <Box flexGrow={1} flexShrink={1}>
          <Text color={session.isOpen ? C.soft : C.faint} wrap="truncate-end">
            {doingOf(session)}
          </Text>
        </Box>
      </Box>
    </Box>
  )
}

/** How many of a project's sessions are open, as SESSIONS' heading says it: none open where it lists none, a project holding only what is parked. */
const openWords = (open: number, count: number) =>
  count === 0 ? NONE_OPEN : `${open} of ${count} open`

/** SESSIONS' heading, then each session, then the history of their status, a blank row between each and the next. */
const drawSessions = (
  d: Drawing,
  key: string,
  sessions: readonly SessionSummary[],
  open: number,
  history: readonly Changed[],
) => [
  {
    key: 'sessions',
    element: heading(d, 'SESSIONS', C.sessions, openWords(open, sessions.length)),
  },
  ...spaced(
    ...sessions.map(session => [
      { key: `sess:${session.id}`, element: drawSession(d, key, session) },
    ]),
    drawHistory(d, `project:${key}`, history),
  ),
]

/** The view's sections, a blank row between each and the next. */
export const drawProjectView = (d: Drawing, key: string): Block[] => {
  const { summary, history, sessions } = projectAt(d.scene, key)
  const names = new Map(sessions.map(session => [session.id, session.name]))
  const changes = history.map(({ session, ...line }) => ({
    line,
    session,
    name: names.get(session) ?? session,
  }))

  return spaced(
    [{ key: 'context', element: context(d, summary.name, waitingWords(summary.waiting)) }],
    drawSessions(d, key, hereFirst(d.scene, summary.sessions), summary.open, changes),
    drawAsks(d, askedIn(d.scene, key), {
      waiting: summary.waiting,
      snoozed: summary.snoozed,
      isHome: key === d.scene.here,
      isNamed: true,
    }),
    drawParked(
      d,
      `project:${key}`,
      { parked: parkedIn(d.scene, key), taken: takenOffIn(d.scene, key) },
      true,
    ),
  )
}
