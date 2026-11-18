/**
 * The foot of another session's view while no window has it: the press that
 * finishes the session, asking first in place. A session with a window is
 * still being worked, and Lee finishes it there by telling Claude.
 */
import type { Filed } from '../../core'
import { drawQuestion, type Block, type Drawing } from './kit'

const LABEL = '✓ finish this session'

/** Whether Lee can finish a session from its view: another session's, with no window and not finished already. */
const canFinish = (d: Drawing, { session }: Filed) =>
  session.id !== d.scene.session.id && !session.isOpen && session.finished === undefined

/** The press, or, once pressed, the question in its place. */
const drawPress = (d: Drawing, { session, project }: Filed) => {
  const { Button } = d.els
  const key = `finish:${session.id}`

  if (d.scene.pane.selected !== key) {
    return <Button key={key} plain label={LABEL} onPress={() => d.act.select(key)} />
  }

  return drawQuestion(
    d,
    `Finish ${session.status.name}? Its open asks stop counting.`,
    [
      {
        key: `finish-yes:${session.id}`,
        label: 'yes, finish it',
        variant: 'primary',
        onPress: () => d.act.finish({ project, session: session.id }),
      },
    ],
    { key: `finish-no:${session.id}`, onPress: () => d.act.select(key) },
  )
}

/** The foot, as a block of its own; none where Lee cannot finish the session. */
export const drawFinish = (d: Drawing, filed: Filed): Block[] =>
  canFinish(d, filed) ? [{ key: 'finish', element: drawPress(d, filed) }] : []
