/**
 * PARKED: what a session raised and put off, or every session's in a
 * project's view, each to pick up. Drawn only while something is parked. A
 * pick-up queues in Ready to send like any reply, with a comment written in
 * the prompt box as its note where Lee wants one (DESIGN.md, "Answering an
 * ask").
 */
import { onItsWay } from '../../core'
import type { SitrepItemRef } from '../../types'
import { C, GLYPH } from '../look'
import { itemKey, type ParkedAt } from '../places'
import { queuedOn } from '../queue'
import {
  ANSWERING,
  answeringOf,
  drawOnItsWay,
  drawQueued,
  drawRow,
  drawWrite,
  heading,
  isBeingAnswered,
  seeRef,
  shown,
  type Block,
  type Drawing,
} from './kit'

/** The mark every parked item is drawn with. */
const MARK = { glyph: GLYPH.parked, color: C.parked }

/** Lee's pick-up of a parked item, as the branch it hangs on: waiting to be sent, or on its way. */
const drawPickUp = (d: Drawing, { at, parked }: ParkedAt) => {
  const queued = queuedOn(d.scene.queue, at.session, parked.id)
  const sent = onItsWay(parked)

  if (queued !== undefined) {
    return drawQueued(d, parked, queued)
  }

  return sent === undefined ? undefined : drawOnItsWay(d, parked, sent)
}

/** A parked item's address, since a project's view lists every session's. */
const keyOf = ({ at, parked }: ParkedAt) => itemKey(at.session, parked.id)

/** The parked item as the item a pick-up answers. */
const refOf = ({ at, parked }: ParkedAt): SitrepItemRef => ({ ...at, item: parked.id })

/** An opened parked item's buttons, under its tree: the pick-up, and the pick-up with a comment written in the prompt. */
const drawButtons = (d: Drawing, entry: ParkedAt) => {
  const { Box, Button } = d.els
  const key = keyOf(entry)
  const at = refOf(entry)
  const answering = answeringOf(d, at, entry.parked, 'pickup')

  return (
    <Box paddingLeft={2} flexDirection="row" columnGap={1} flexWrap="wrap">
      <Button
        key={`pickup:${key}`}
        label="pick it up"
        onPress={() => d.act.reply({ ...at, verdict: 'pickup' })}
      />
      {drawWrite(d, `comment:${key}`, '✎ with a comment', answering)}
    </Box>
  )
}

/** A parked item: its row, its title after its session's name where the list names them, and, opened, the buttons that pick it up under its tree. */
const drawItem = (d: Drawing, entry: ParkedAt, isNamed: boolean) => {
  const { name, parked } = entry
  const key = keyOf(entry)
  const at = refOf(entry)
  const isOpen = d.scene.pane.selected === key
  const pickUp = drawPickUp(d, entry)
  const isAnswering = isBeingAnswered(d, at)

  return drawRow(d, {
    key: `parked:${key}`,
    mark: MARK,
    title: isNamed ? `${name}: ${parked.title}` : parked.title,
    at: parked.at,
    isOpen,
    press: { key: `ppick:${key}`, onPress: () => d.act.select(key) },
    branches: shown(
      isOpen && parked.where,
      isOpen && seeRef(parked.ref, MARK.color),
      pickUp,
      isAnswering && ANSWERING,
    ),
    after: isOpen && pickUp === undefined && !isAnswering && drawButtons(d, entry),
  })
}

/** PARKED's heading, then each item; none while nothing is parked. */
export const drawParked = (d: Drawing, parked: readonly ParkedAt[], isNamed: boolean): Block[] =>
  parked.length === 0
    ? []
    : [
        {
          key: 'parked',
          element: heading(d, 'PARKED', C.parked, `${parked.length} to come back to`),
        },
        ...parked.map(each => ({
          key: `parked:${keyOf(each)}`,
          element: drawItem(d, each, isNamed),
        })),
      ]
