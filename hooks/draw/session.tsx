/**
 * This session's view, the board's home: the work's name and summary,
 * where it stands, what waits on Lee, and what happened.
 */
import { agoWords, C, GLYPH, titled } from '../look'
import { askMark, doneEarlier, forYou, isPulsing } from '../scene'
import { drawAsk } from './ask'
import { heading, marked, type Drawing } from './kit'
import { drawLogLine } from './log'

/** How many log lines the view shows, docked and inline. */
const LOG_LINES = { dock: 8, inline: 3 }

/** The line under the tabs naming the work, and its summary under that. */
const drawContext = (d: Drawing) => {
  const { Box, Text } = d.els
  const { status, project } = d.scene.work

  return (
    <Box flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Text bold>{status.name}</Text>
        <Box flexGrow={1} flexShrink={1}>
          <Text color={C.grey} wrap="truncate-end">
            · {titled(project)}
          </Text>
        </Box>
      </Box>
      <Text color={C.soft} wrap="wrap">
        {status.summary}
      </Text>
    </Box>
  )
}

const drawStatus = (d: Drawing) => {
  const { Box, Text } = d.els
  const { now, next, at } = d.scene.work.status

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

/** For you's few words: new while an ask pulses, else how many wait. */
const forYouNote = (d: Drawing) => {
  const { work } = d.scene

  if (isPulsing(d.scene)) {
    return { note: '✦ new', color: askMark(d.scene).color }
  }

  return { note: work.waiting > 0 ? `${work.waiting} waiting` : 'nothing waiting', color: C.grey }
}

const drawForYou = (d: Drawing) => {
  const { Box, Text } = d.els
  const asks = forYou(d.scene)
  const earlier = doneEarlier(d.scene)
  const { note, color } = forYouNote(d)

  return (
    <Box flexDirection="column">
      {heading(d, 'FOR YOU', C.ask, note, color)}
      {asks.length === 0 && <Text color={C.grey}>Nothing waiting on you.</Text>}
      <Box flexDirection="column" rowGap={1}>
        {asks.map(ask => drawAsk(d, ask))}
      </Box>
      {earlier > 0 && (
        <Text color={C.grey}>
          {GLYPH.done} {earlier} done earlier
        </Text>
      )}
    </Box>
  )
}

const drawLog = (d: Drawing) => {
  const { Box, Text } = d.els
  const lines = d.scene.work.log.slice(0, d.isDock ? LOG_LINES.dock : LOG_LINES.inline)

  return (
    <Box flexDirection="column">
      {heading(d, 'LOG', C.log, 'what happened')}
      {lines.length === 0 && <Text color={C.grey}>Nothing yet.</Text>}
      {lines.map(line => drawLogLine(d, line))}
    </Box>
  )
}

export const drawSessionView = (d: Drawing) => {
  const { Box } = d.els

  return (
    <Box flexDirection="column" gap={1}>
      {drawContext(d)}
      {drawStatus(d)}
      {drawForYou(d)}
      {drawLog(d)}
    </Box>
  )
}
