/**
 * A project's view: its sessions, this one first, each with what it is
 * doing and what waits on Lee there, and under them its old sessions,
 * folded away until Lee opens them; every session's asks, answered from
 * here; and what its sessions put off, and what was taken off that. Each
 * ask and parked item names its session. A session, old or not, opens its
 * own view.
 */
import type { RenderElement } from 'claude-code'
import type { Carried, EndedSession, SessionSummary } from '../../core'
import { oldList, projectScope } from '../lists'
import { ago, C, clip, GLYPH } from '../look'
import { askedIn, hereFirst, parkedIn, projectAt, takenOffIn } from '../places'
import { drawAsks } from './ask'
import { context, heading, NONE_OPEN, spaced, waitingWords, type Block, type Drawing } from './kit'
import { drawParked } from './parked'
import { drawPast } from './past'

/** What a session is doing, in a line: what is under way, else what is next, else what it is for. */
const doingOf = ({ now, next, summary }: SessionSummary) => {
  if (now.length > 0) {
    return now.join(' · ')
  }

  return next === undefined ? summary : `next: ${next}`
}

/** A session's row, as a block of its own keyed `key`: its name, the press that opens its view, dim once closed; what goes on its right; and what it is doing under it, faint once closed. */
const drawSession = (
  d: Drawing,
  key: string,
  project: string,
  session: SessionSummary,
  right: RenderElement | false,
): Block => {
  const { Box, Text, Button } = d.els
  const isHere = session.id === d.scene.session.id

  return {
    key,
    element: (
      <Box key={key} flexDirection="column">
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
          {right}
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
    ),
  }
}

/** A current session's row: what waits on Lee there on its right, else that it is closed. */
const drawCurrent = (d: Drawing, project: string, session: SessionSummary) => {
  const { Text } = d.els
  const right =
    session.waiting > 0 ? (
      <Text color={C.ask}>{session.waiting} waiting</Text>
    ) : (
      !session.isOpen && <Text color={C.faint}>closed</Text>
    )

  return drawSession(d, `sess:${session.id}`, project, session, right)
}

/** An old session's row: how long ago it ended on its right, as a list's age is. */
const drawOld = (d: Drawing, project: string, session: EndedSession) => {
  const { Text } = d.els
  const ended = <Text color={C.grey}>{ago(d.scene.now, session.endedAt)}</Text>

  return drawSession(d, `ended:${session.id}`, project, session, ended)
}

/** A project's old sessions: their press, and those it shows once opened; nothing while they are not carried yet, so no count shows short. */
const drawOldSessions = (d: Drawing, key: string, old: Carried<EndedSession> | undefined) =>
  old === undefined
    ? []
    : drawPast(d, {
        list: oldList(projectScope(key)),
        carried: old,
        draw: session => drawOld(d, key, session),
        folding: { show: 'show old sessions', hide: 'hide old sessions' },
      })

/** How many of a project's sessions are open, as SESSIONS' heading says it: none open where it lists none, a project holding only what is parked. */
const openWords = (open: number, count: number) =>
  count === 0 ? NONE_OPEN : `${open} of ${count} open`

/** SESSIONS' heading, then each session, then its old sessions, a blank row between each and the next. */
const drawSessions = (
  d: Drawing,
  key: string,
  sessions: readonly SessionSummary[],
  open: number,
  old: Carried<EndedSession> | undefined,
) => [
  {
    key: 'sessions',
    element: heading(d, 'SESSIONS', C.sessions, openWords(open, sessions.length)),
  },
  ...spaced(
    ...sessions.map(session => [drawCurrent(d, key, session)]),
    drawOldSessions(d, key, old),
  ),
]

/** The view's sections, a blank row between each and the next. */
export const drawProjectView = (d: Drawing, key: string): Block[] => {
  const { summary, old } = projectAt(d.scene, key)

  return spaced(
    [{ key: 'context', element: context(d, summary.name, waitingWords(summary.waiting)) }],
    drawSessions(d, key, hereFirst(d.scene, summary.sessions), summary.open, old),
    drawAsks(d, askedIn(d.scene, key), {
      waiting: summary.waiting,
      snoozed: summary.snoozed,
      isHome: key === d.scene.here,
      isNamed: true,
    }),
    drawParked(d, key, { parked: parkedIn(d.scene, key), taken: takenOffIn(d.scene, key) }),
  )
}
