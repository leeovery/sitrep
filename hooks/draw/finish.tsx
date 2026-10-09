/**
 * The foot of another session's view while no window has it: the press
 * that marks the work done, asking first in place. A work with a window is
 * still being worked, and Lee finishes it there by telling Claude.
 */
import type { Filed } from '../scene'
import type { Block, Drawing } from './kit'

const LABEL = '✓ mark this work done'

/** Whether Lee can mark a work done from its view: another session's, with no window and not done already. */
const canFinish = (d: Drawing, { work }: Filed) =>
  work.id !== d.scene.work.id && !work.isOpen && work.finished === undefined

/** The press, or, once pressed, the question in its place. */
const drawPress = (d: Drawing, { work, project }: Filed) => {
  const { Box, Text, Button } = d.els
  const key = `finish:${work.id}`

  if (d.scene.pane.selected !== key) {
    return <Button key={key} plain label={LABEL} onPress={() => d.act.select(key)} />
  }

  return (
    <Box flexDirection="column">
      <Text wrap="wrap">{`Mark ${work.status.name} done? Its open asks stop counting.`}</Text>
      <Box flexDirection="row" columnGap={1} flexWrap="wrap">
        <Button
          key={`finish-yes:${work.id}`}
          variant="primary"
          label="yes, mark it done"
          onPress={() => d.act.finish({ project, work: work.id })}
        />
        <Button
          key={`finish-no:${work.id}`}
          dimColor
          label="cancel"
          onPress={() => d.act.select(key)}
        />
      </Box>
    </Box>
  )
}

/** The foot, as a block of its own; none where Lee cannot mark the work done. */
export const drawFinish = (d: Drawing, filed: Filed): Block[] =>
  canFinish(d, filed) ? [{ key: 'finish', element: drawPress(d, filed) }] : []
