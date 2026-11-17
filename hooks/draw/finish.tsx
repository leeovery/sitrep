/**
 * The foot of another session's view while no window has it: the press that
 * finishes the session, asking first in place. A session with a window is
 * still being worked, and Lee finishes it there by telling Claude.
 */
import type { Filed } from '../../core'
import type { Block, Drawing } from './kit'

const LABEL = '✓ finish this session'

/** Whether Lee can finish a session from its view: another session's, with no window and not finished already. */
const canFinish = (d: Drawing, { session }: Filed) =>
  session.id !== d.scene.session.id && !session.isOpen && session.finished === undefined

/** The press, or, once pressed, the question in its place. */
const drawPress = (d: Drawing, { session, project }: Filed) => {
  const { Box, Text, Button } = d.els
  const key = `finish:${session.id}`

  if (d.scene.pane.selected !== key) {
    return <Button key={key} plain label={LABEL} onPress={() => d.act.select(key)} />
  }

  return (
    <Box flexDirection="column">
      <Text wrap="wrap">{`Finish ${session.status.name}? Its open asks stop counting.`}</Text>
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        <Button
          key={`finish-yes:${session.id}`}
          variant="primary"
          label="yes, finish it"
          onPress={() => d.act.finish({ project, session: session.id })}
        />
        <Button
          key={`finish-no:${session.id}`}
          dimColor
          label="cancel"
          onPress={() => d.act.select(key)}
        />
      </Box>
    </Box>
  )
}

/** The foot, as a block of its own; none where Lee cannot finish the session. */
export const drawFinish = (d: Drawing, filed: Filed): Block[] =>
  canFinish(d, filed) ? [{ key: 'finish', element: drawPress(d, filed) }] : []
