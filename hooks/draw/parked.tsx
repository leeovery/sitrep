/**
 * The parked view, scoped to where the board is looking: what a session,
 * a project's sessions or every project raised and put off, each to pick
 * up. A pick-up queues in Ready to send like any reply. It sits under the
 * tabs, or the back row, as the board's views do, its first line the way
 * back to the board.
 */
import { C, GLYPH } from '../look'
import { filedAt, homeOf, parkedAt, projectName, samePlace, type ParkedAt } from '../places'
import { queuedOn } from '../queue'
import type { Scene } from '../scene'
import {
  drawOnItsWay,
  drawQueued,
  drawRow,
  heading,
  onItsWay,
  seeRef,
  shown,
  type Drawing,
} from './kit'

const ABOUT = "What we said we'd come back to. Each stays until you pick it up and Claude has it."

/** Where the parked items came from, as the view's heading names it. */
const whereOf = (scene: Scene) => {
  const { place } = scene

  switch (place.level) {
    case 'session':
      return samePlace(place, homeOf(scene))
        ? 'THIS SESSION'
        : (filedAt(scene, place.work)?.work.status.name ?? place.work).toUpperCase()
    case 'project':
      return projectName(scene, place.project).toUpperCase()
    case 'all':
      return 'ALL PROJECTS'
  }
}

/** The mark every parked item is drawn with. */
const MARK = { glyph: GLYPH.parked, color: C.parked }

/** Lee's pick-up of a parked item, as the branch it hangs on: waiting to be sent, or on its way. */
const drawPickUp = (d: Drawing, { at, parked }: ParkedAt) => {
  const queued = queuedOn(d.scene.queue, at.work, parked.id)
  const sent = onItsWay(parked)

  if (queued !== undefined) {
    return drawQueued(d, parked, queued)
  }

  return sent === undefined ? undefined : drawOnItsWay(d, parked, sent)
}

/** A parked item: its row, and, opened, the button that picks it up under its tree. */
const drawItem = (d: Drawing, entry: ParkedAt) => {
  const { Box, Button } = d.els
  const { at, name, parked } = entry
  const isOpen = d.scene.pane.selected === parked.id
  const pickUp = drawPickUp(d, entry)

  return drawRow(d, {
    key: `parked:${at.work}:${parked.id}`,
    mark: MARK,
    title: parked.title,
    at: parked.at,
    isOpen,
    press: { key: `ppick:${parked.id}`, onPress: () => d.act.select(parked.id) },
    branches: shown(
      isOpen && parked.where,
      isOpen && d.scene.place.level !== 'session' && { text: `raised in ${name}`, color: C.grey },
      isOpen && seeRef(parked.ref, MARK.color),
      pickUp,
    ),
    after: isOpen && pickUp === undefined && (
      <Box paddingLeft={2}>
        <Button
          key={`pickup:${parked.id}`}
          label="pick it up"
          onPress={() => d.act.reply({ ...at, item: parked.id, verdict: 'pickup' })}
        />
      </Box>
    ),
  })
}

export const drawParkedView = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const parked = parkedAt(d.scene)

  return (
    <Box flexDirection="column" gap={1}>
      <Box flexDirection="column">
        <Button
          key="back"
          plain
          dimColor
          label="← back to the board"
          onPress={() => d.act.show('board')}
        />
        {heading(d, `PARKED IN ${whereOf(d.scene)}`, C.parked, `${parked.length}`)}
        <Text color={C.grey} italic wrap="wrap">
          {ABOUT}
        </Text>
      </Box>
      <Box flexDirection="column">
        {parked.length === 0 && <Text color={C.grey}>Nothing parked.</Text>}
        {parked.map(each => drawItem(d, each))}
      </Box>
    </Box>
  )
}
