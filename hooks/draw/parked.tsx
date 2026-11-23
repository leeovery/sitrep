/**
 * PARKED: everything parked in a project, finished and idle sessions'
 * included, in its view and in each of its sessions', a session's own
 * first, each to pick up from a window holding a session of its project,
 * and to drop from any; and at its foot, folded away until Lee opens it,
 * what was taken off it, picked up or dropped by Lee or closed by Claude.
 * Drawn while something is parked or was taken off. A pick-up queues in
 * Ready to send like any reply, to this session whichever session of the
 * project parked the item, a comment written in the prompt box added to it
 * as its note once it is queued (DESIGN.md, "Answering an ask"). A drop asks
 * first, in place, and is written at once, nothing sent to Claude
 * (DESIGN.md, "Dropping a parked item").
 */
import { replyOnItsWay, shownWords, type Listing, type ProjectKey } from '../../core'
import type { SitrepItemRef } from '../../types'
import { pickedUpList, projectScope } from '../lists'
import { C, GLYPH } from '../look'
import { itemKey, type ParkedAt, type TakenAt } from '../places'
import { queuedOn } from '../queue'
import {
  ANSWERING,
  drawOnItsWay,
  drawQuestion,
  drawQueued,
  drawRow,
  heading,
  isBeingAnswered,
  seeRef,
  shown,
  type Block,
  type Drawing,
} from './kit'
import { drawPast } from './past'

/** The mark every parked item is drawn with. */
const MARK = { glyph: GLYPH.parked, color: C.parked }

/** Lee's pick-up of a parked item, as the branch it hangs on: waiting to be sent, or on its way. */
const drawPickUp = (d: Drawing, { at, parked }: ParkedAt) => {
  const queued = queuedOn(d.scene.queue, at.session, parked.id)
  const sent = replyOnItsWay(parked)

  if (queued !== undefined) {
    return drawQueued(d, parked, queued)
  }

  return sent === undefined ? undefined : drawOnItsWay(d, parked, sent)
}

/** A parked item's address, since a project's view lists every session's. */
const keyOf = ({ at, parked }: ParkedAt) => itemKey(at.session, parked.id)

/** The parked item as the item a pick-up answers, and a drop drops. */
const refOf = ({ at, parked }: ParkedAt): SitrepItemRef<ProjectKey> => ({ ...at, item: parked.id })

/** What opens a parked item's question of whether to drop it, in place of its buttons: this, then its address. */
const dropKey = (key: string) => `drop:${key}`

/** What dropping a parked item asks in place. */
const DROP_QUESTION = 'Drop it? It leaves Parked, and Claude no longer sees it.'

/** Whether the window can pick a parked item up: it holds a session of the item's project, whose Claude a pick-up goes to. */
const isPickable = (d: Drawing, { at }: ParkedAt) => at.project === d.scene.here

/** The pick-up, where the window can pick the item up: a comment is added once it is queued, as a yes's is. */
const drawPickUps = (d: Drawing, entry: ParkedAt) => {
  const { Button } = d.els
  const at = refOf(entry)

  return isPickable(d, entry)
    ? [
        <Button
          key={`pickup:${keyOf(entry)}`}
          label="pick it up"
          onPress={() => d.act.reply({ ...at, verdict: 'pickup' })}
        />,
      ]
    : []
}

/** An opened parked item's buttons, under its tree: the pick-up where the window can, and the drop, which asks first: dim after it, as an ask's ignore is, and drawn as any press where it is the only one. */
const drawButtons = (d: Drawing, entry: ParkedAt) => {
  const { Box, Button } = d.els
  const key = keyOf(entry)
  const pickUps = drawPickUps(d, entry)

  return (
    <Box paddingLeft={2} flexDirection="row" columnGap={1} flexWrap="wrap">
      {pickUps}
      <Button
        key={dropKey(key)}
        dimColor={pickUps.length > 0}
        label="✕ drop"
        onPress={() => d.act.select(dropKey(key))}
      />
    </Box>
  )
}

/** The drop's question, in place of the item's buttons: yes, written at once, or cancel, back to the buttons. */
const drawDropping = (d: Drawing, entry: ParkedAt) => {
  const { Box } = d.els
  const key = keyOf(entry)

  return (
    <Box paddingLeft={2} flexDirection="column">
      {drawQuestion(
        d,
        DROP_QUESTION,
        [
          {
            key: `drop-yes:${key}`,
            label: 'yes, drop it',
            variant: 'primary',
            onPress: () => d.act.drop(refOf(entry)),
          },
        ],
        { key: `drop-no:${key}`, onPress: () => d.act.select(key) },
      )}
    </Box>
  )
}

/** A row's title after the name of its item's session, but in that session's own view, `own` naming it. */
const titled = ({ at, name }: ParkedAt, title: string, own: string | undefined) =>
  at.session === own ? title : `${name}: ${title}`

/**
 * A parked item: its row, its title named as `titled` names it, and,
 * opened, its buttons under its tree, or the drop's question in their
 * place, while nothing of Lee's waits on it or is on its way to it.
 */
const drawItem = (d: Drawing, entry: ParkedAt, own: string | undefined) => {
  const { parked } = entry
  const key = keyOf(entry)
  const at = refOf(entry)
  const { selected } = d.scene.pane
  const isDropping = selected === dropKey(key)
  const isOpen = selected === key || isDropping
  const pickUp = drawPickUp(d, entry)
  const isAnswering = isBeingAnswered(d, at)
  const hasButtons = isOpen && pickUp === undefined && !isAnswering

  return drawRow(d, {
    key: `parked:${key}`,
    mark: MARK,
    title: titled(entry, parked.title, own),
    at: parked.at,
    isOpen,
    // `select` toggles the key it is given, so the title gives the one the pane holds: one press closes the item from the drop's question too.
    press: { key: `ppick:${key}`, onPress: () => d.act.select(isDropping ? dropKey(key) : key) },
    branches: shown(
      isOpen && parked.where,
      isOpen && seeRef(parked.ref, MARK.color),
      pickUp,
      isAnswering && ANSWERING,
    ),
    after: hasButtons && (isDropping ? drawDropping(d, entry) : drawButtons(d, entry)),
  })
}

/** The mark every item taken off Parked is drawn with: done with. */
const TAKEN_MARK = { glyph: GLYPH.closed, color: C.ok }

/** How an item left Parked, by the session a pick-up went to where that is known. */
const howTaken = ({ parked, pickedUpBy }: TakenAt) => {
  switch (parked.state) {
    case 'closed':
      return 'closed by Claude'
    case 'dropped':
      return 'dropped by you'
    default:
      return pickedUpBy === undefined ? 'picked up' : `picked up by ${pickedUpBy}`
  }
}

/** What was said as an item left Parked: Claude's reason for the close, else Lee's note on the pick-up, as Lee sees it. */
const saidOf = ({ parked }: TakenAt) => {
  if (parked.state === 'closed') {
    return parked.reason
  }

  const note = parked.answer?.note

  return note === undefined ? undefined : shownWords(note)
}

/** What an item taken off Parked opens to: Lee's note on the pick-up, or Claude's reason for the close, and where Claude's own record of it is; a dropped item, that alone. */
const takenDetail = (entry: TakenAt) => {
  const detail = shown(saidOf(entry), seeRef(entry.parked.ref, TAKEN_MARK.color))

  return detail.length > 0 ? detail : ['nothing more was recorded']
}

const takenOpens = (entry: TakenAt) => `picked:${keyOf(entry)}`

/** An item taken off Parked, as a block of its own: its title, named as `titled` names it, and how it left. */
const drawTaken = (d: Drawing, entry: TakenAt, own: string | undefined): Block => {
  const { parked } = entry
  const key = takenOpens(entry)
  const isOpen = d.scene.pane.selected === key
  const row = `taken:${keyOf(entry)}`

  return {
    key: row,
    element: drawRow(d, {
      key: row,
      mark: TAKEN_MARK,
      title: titled(entry, `${parked.title} · ${howTaken(entry)}`, own),
      at: parked.closedAt ?? parked.at,
      isOpen,
      press: { key, onPress: () => d.act.select(key) },
      branches: isOpen ? takenDetail(entry) : [],
    }),
  }
}

/** What heads the items other sessions parked, in a session's view. */
const OTHERS = 'from other sessions'

/**
 * Each parked item as a block of its own; in a session's view, `own`
 * naming it, a faint line before the first another session parked, so its
 * own and theirs read apart, even where it has none of its own. A project's
 * view names every row, and needs none.
 */
const drawItems = (d: Drawing, parked: readonly ParkedAt[], own: string | undefined) => {
  const { Text } = d.els
  const blocks = parked.map(each => ({
    key: `parked:${keyOf(each)}`,
    element: drawItem(d, each, own),
  }))
  const first = own === undefined ? -1 : parked.findIndex(({ at }) => at.session !== own)
  const label = {
    key: 'parked:others',
    element: (
      <Text color={C.faint} wrap="truncate-end">
        {OTHERS}
      </Text>
    ),
  }

  return first < 0 ? blocks : [...blocks.slice(0, first), label, ...blocks.slice(first)]
}

/** How much is parked, as PARKED's heading says it. */
const parkedWords = (count: number) =>
  count === 0 ? 'nothing to come back to' : `${count} to come back to`

/** What Parked lists: what is parked, and what was taken off it, none while a project's is not carried yet. */
export type ParkedList = { parked: readonly ParkedAt[]; taken: Listing<TakenAt> | undefined }

/**
 * PARKED's heading, then each item parked in `project`, and what was taken
 * off its Parked, each naming its session but in that session's own view,
 * `own` naming it; none while nothing is parked and nothing was taken off.
 * What was taken off draws only once it is carried, so no count shows
 * short.
 */
export const drawParked = (
  d: Drawing,
  project: string,
  { parked, taken }: ParkedList,
  own?: string,
): Block[] =>
  parked.length === 0 && (taken?.count ?? 0) === 0
    ? []
    : [
        { key: 'parked', element: heading(d, 'PARKED', C.parked, parkedWords(parked.length)) },
        ...drawItems(d, parked, own),
        ...(taken === undefined
          ? []
          : drawPast(d, {
              list: pickedUpList(projectScope(project)),
              listing: taken,
              draw: entry => drawTaken(d, entry, own),
              opens: takenOpens,
              folding: { show: 'show picked up', hide: 'hide picked up' },
            })),
      ]
