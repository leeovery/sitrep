/**
 * A session's view: the session's name and summary, what waits on Lee, where
 * it stands and how that changed, what it put off, and the asks done with. This
 * session's is the board's home; another's draws the same, its asks
 * answered the same way, and with no window on it, a way to finish it.
 */
import { snoozedAsks } from '../../core'
import { agoWords, C, GLYPH } from '../look'
import { askedOf, parkedOf, takenOffOf } from '../places'
import type { Filed } from '../scene'
import { drawAsks } from './ask'
import { drawResolved } from './earlier'
import { drawFinish } from './finish'
import { drawHistory } from './history'
import { context, emptyLine, heading, marked, spaced, type Block, type Drawing } from './kit'
import { drawParked } from './parked'

/** The line under the tabs naming the session, and its summary under that. */
const drawContext = (d: Drawing, { session }: Filed) =>
  context(
    d,
    session.status.name,
    `${session.project}${session.isOpen ? '' : ' · closed'}`,
    session.status.summary,
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
    [
      { key: 'status', element: drawStatus(d, filed) },
      ...drawHistory(
        d,
        filed.session.id,
        filed.session.history.map(line => ({ line, session: filed.session.id })),
      ),
    ],
    drawParked(
      d,
      filed.session.id,
      { parked: parkedOf(filed), taken: takenOffOf(d.scene, filed) },
      false,
    ),
    drawResolved(d, filed),
    drawFinish(d, filed),
  )
