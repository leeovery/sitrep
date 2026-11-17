/**
 * A session's view: the session's name and summary, its project's a press
 * to its view, what waits on Lee, where it stands and how that changed, what
 * its project put off, its own first, and the asks done with. This
 * session's is the board's home; another's draws the same, its asks
 * answered the same way, and with no window on it, a way to finish it. A
 * finished one says so, and when, and why where its finish says, and, but
 * for this session's, its asks left open offer no reply.
 */
import { snoozedAsks, type Session } from '../../core'
import { agoWords, C, GLYPH } from '../look'
import { askedOf, parkedAt, projectPlace, takenOffIn, waitingAt } from '../places'
import type { Filed } from '../scene'
import { drawAsks } from './ask'
import { drawResolved } from './earlier'
import { drawFinish } from './finish'
import { drawHistory } from './history'
import { context, emptyLine, heading, marked, spaced, type Block, type Drawing } from './kit'
import { drawParked } from './parked'

/** How a session stands, beside its project's name: finished, and how long ago, as STATUS says when it was updated; else closed, with no window; else nothing. */
const standingWords = (d: Drawing, { finished, isOpen }: Session) => {
  if (finished !== undefined) {
    return [`finished ${agoWords(d.scene.now, finished.at)}`]
  }

  return isOpen ? [] : ['closed']
}

/** The line under the tabs naming the session, its project's name the press that opens the project, how it stands, and its summary under that. */
const drawContext = (d: Drawing, { project, session }: Filed) =>
  context(
    d,
    session.status.name,
    {
      lead: { words: session.project, key: `proj:${project}`, to: projectPlace(project) },
      parts: standingWords(d, session),
    },
    session.status.summary,
  )

/** STATUS: when it was updated, what is under way, what is next, and why the session was finished, where its finish says. */
const drawStatus = (d: Drawing, { session }: Filed) => {
  const { Box, Text } = d.els
  const { now, next, at } = session.status
  const why = session.finished?.reason

  return (
    <Box flexDirection="column">
      {heading(d, 'STATUS', C.now, `updated ${agoWords(d.scene.now, at)}`)}
      {now.length === 0 &&
        next === undefined &&
        why === undefined &&
        emptyLine(d, 'Nothing under way yet.')}
      {now.map((line, i) =>
        marked(d, `now:${i}`, GLYPH.now, C.now, <Text wrap="wrap">{line}</Text>),
      )}
      {next !== undefined &&
        marked(
          d,
          'next',
          GLYPH.next,
          C.grey,
          <Text color={C.soft} wrap="wrap">
            next: {next}
          </Text>,
        )}
      {why !== undefined &&
        marked(
          d,
          'finished',
          GLYPH.done,
          C.grey,
          <Text color={C.soft} wrap="wrap">
            finished: {why}
          </Text>,
        )}
    </Box>
  )
}

/** The view's sections, a blank row between each and the next. */
export const drawSessionView = (d: Drawing, filed: Filed): Block[] =>
  spaced(
    [{ key: 'context', element: drawContext(d, filed) }],
    drawAsks(d, askedOf(d.scene, filed), {
      waiting: waitingAt(d.scene, filed.session),
      snoozed: snoozedAsks(filed.session).length,
      isHome: filed.session === d.scene.session,
      isNamed: false,
    }),
    [{ key: 'status', element: drawStatus(d, filed) }, ...drawHistory(d, filed.session)],
    drawParked(
      d,
      filed.project,
      { parked: parkedAt(d.scene, filed), taken: takenOffIn(d.scene, filed.project) },
      filed.session.id,
    ),
    drawResolved(d, filed),
    drawFinish(d, filed),
  )
