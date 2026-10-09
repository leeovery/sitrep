/**
 * A session's view: the work's name and summary, what waits on Lee, where
 * it stands, what happened, what it put off, and the asks done with. This
 * session's is the board's home; another's draws the same, its asks
 * answered the same way, and with no window on it, a way to mark it done.
 */
import { agoWords, C, GLYPH } from '../look'
import { askedOf, parkedOf } from '../places'
import type { Filed } from '../scene'
import { drawForYou } from './ask'
import { drawDone } from './earlier'
import { drawFinish } from './finish'
import { context, heading, marked, type Drawing } from './kit'
import { drawLogLine } from './log'
import { drawParked } from './parked'

/** How many log lines the view shows, docked and inline. */
const LOG_LINES = { dock: 8, inline: 3 }

/** The line under the tabs naming the work, and its summary under that. */
const drawContext = (d: Drawing, { work }: Filed) =>
  context(
    d,
    work.status.name,
    `${work.project}${work.isOpen ? '' : ' · closed'}`,
    work.status.summary,
  )

const drawStatus = (d: Drawing, { work }: Filed) => {
  const { Box, Text } = d.els
  const { now, next, at } = work.status

  return (
    <Box flexDirection="column">
      {heading(d, 'STATUS', C.now, `updated ${agoWords(d.scene.now, at)}`)}
      {now.length === 0 && next === undefined && <Text color={C.grey}>Nothing under way yet.</Text>}
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

const drawLog = (d: Drawing, { work }: Filed) => {
  const { Box, Text } = d.els
  const lines = work.log.slice(0, d.isDock ? LOG_LINES.dock : LOG_LINES.inline)

  return (
    <Box flexDirection="column">
      {heading(d, 'LOG', C.log, 'what happened')}
      {lines.length === 0 && <Text color={C.grey}>Nothing yet.</Text>}
      {lines.map(line => drawLogLine(d, line))}
    </Box>
  )
}

export const drawSessionView = (d: Drawing, filed: Filed) => {
  const { Box } = d.els

  return (
    <Box flexDirection="column" gap={1}>
      {drawContext(d, filed)}
      {drawForYou(d, askedOf(d.scene, filed), {
        waiting: filed.work.waiting,
        isHome: filed.work === d.scene.work,
        isNamed: false,
      })}
      {drawStatus(d, filed)}
      {drawLog(d, filed)}
      {drawParked(d, parkedOf(filed), false)}
      {drawDone(d, filed)}
      {drawFinish(d, filed)}
    </Box>
  )
}
