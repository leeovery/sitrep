/**
 * A session's view: the work's name and summary, what waits on Lee, where
 * it stands, what happened, and the asks done with. This session's is the board's home;
 * another's draws the same, its asks answered the same way, and with no
 * window on it, a way to mark it done.
 */
import { agoWords, C, GLYPH } from '../look'
import { askMark, forYou, isPulsing, type Filed } from '../scene'
import { drawAsk } from './ask'
import { drawDone } from './earlier'
import { drawFinish } from './finish'
import { context, heading, marked, type Drawing } from './kit'
import { drawLogLine } from './log'

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

/** For you's few words: new while one of this session's asks pulses, else how many wait. */
const forYouNote = (d: Drawing, { work }: Filed) => {
  if (work === d.scene.work && isPulsing(d.scene)) {
    return { note: '✦ new', color: askMark(d.scene).color }
  }

  return { note: work.waiting > 0 ? `${work.waiting} waiting` : 'nothing waiting', color: C.grey }
}

const drawForYou = (d: Drawing, filed: Filed) => {
  const { Box, Text } = d.els
  const asks = forYou(filed.work, d.scene.now)
  const { note, color } = forYouNote(d, filed)

  return (
    <Box flexDirection="column">
      {heading(d, 'FOR YOU', C.ask, note, color)}
      {asks.length === 0 && <Text color={C.grey}>Nothing waiting on you.</Text>}
      {asks.map((ask, i) => drawAsk(d, filed, ask, i === asks.length - 1))}
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
      {drawForYou(d, filed)}
      {drawStatus(d, filed)}
      {drawLog(d, filed)}
      {drawDone(d, filed)}
      {drawFinish(d, filed)}
    </Box>
  )
}
