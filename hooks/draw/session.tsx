/**
 * A session's view: the session's name and summary, its project's a press
 * to its view, what waits on Lee, where it stands and how that changed, what
 * its project put off, its own first, and the asks done with. This
 * session's is the board's home; another's draws the same, its asks
 * answered the same way, and with no window on it, a way to finish it.
 */
import { snoozedAsks } from '../../core'
import { agoWords, C, GLYPH } from '../look'
import { askedOf, parkedAt, projectPlace, takenOffIn } from '../places'
import type { Filed } from '../scene'
import { drawAsks } from './ask'
import { drawResolved } from './earlier'
import { drawFinish } from './finish'
import { drawHistory } from './history'
import { context, emptyLine, heading, marked, spaced, type Block, type Drawing } from './kit'
import { drawParked } from './parked'

/** The line under the tabs naming the session, its project's name the press that opens the project, and its summary under that. */
const drawContext = (d: Drawing, { project, session }: Filed) =>
  context(
    d,
    session.status.name,
    `${session.project}${session.isOpen ? '' : ' · closed'}`,
    session.status.summary,
    { words: session.project, key: `proj:${project}`, to: projectPlace(project) },
  )

const drawStatus = (d: Drawing, { session }: Filed) => {
  const { Box, Text } = d.els
  const { now, next, at } = session.status

  return (
    <Box flexDirection="column">
      {heading(d, 'STATUS', C.now, `updated ${agoWords(d.scene.now, at)}`)}
      {now.length === 0 && next === undefined && emptyLine(d, 'Nothing under way yet.')}
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
    </Box>
  )
}

/** The view's sections, a blank row between each and the next. */
export const drawSessionView = (d: Drawing, filed: Filed): Block[] =>
  spaced(
    [{ key: 'context', element: drawContext(d, filed) }],
    drawAsks(d, askedOf(d.scene, filed), {
      waiting: filed.session.waiting,
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
