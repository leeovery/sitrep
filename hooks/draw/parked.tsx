/**
 * PARKED: what a session raised and put off, or every session's in a
 * project's view, each to pick up. Drawn only while something is parked. A
 * pick-up queues in Ready to send like any reply.
 */
import { C, GLYPH } from '../look'
import type { ParkedAt } from '../places'
import { queuedOn } from '../queue'
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

/** A parked item: its row, its title after its session's name where the list names them, and, opened, the button that picks it up under its tree. */
const drawItem = (d: Drawing, entry: ParkedAt, isNamed: boolean) => {
  const { Box, Button } = d.els
  const { at, name, parked } = entry
  const isOpen = d.scene.pane.selected === parked.id
  const pickUp = drawPickUp(d, entry)

  return drawRow(d, {
    key: `parked:${at.work}:${parked.id}`,
    mark: MARK,
    title: isNamed ? `${name}: ${parked.title}` : parked.title,
    at: parked.at,
    isOpen,
    press: { key: `ppick:${parked.id}`, onPress: () => d.act.select(parked.id) },
    branches: shown(isOpen && parked.where, isOpen && seeRef(parked.ref, MARK.color), pickUp),
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

export const drawParked = (d: Drawing, parked: readonly ParkedAt[], isNamed: boolean) => {
  const { Box } = d.els

  if (parked.length === 0) {
    return null
  }

  return (
    <Box flexDirection="column">
      {heading(d, 'PARKED', C.parked, `${parked.length} to come back to`)}
      {parked.map(each => drawItem(d, each, isNamed))}
    </Box>
  )
}
