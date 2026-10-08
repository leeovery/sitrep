/**
 * The parked view, scoped to where the board is looking: what a session,
 * a project's sessions or every project raised and put off, each to pick
 * up. A pick-up queues in Ready to send like any reply.
 */
import { ago, C, GLYPH } from '../look'
import { filedAt, homeOf, parkedAt, projectName, samePlace, type ParkedAt } from '../places'
import { queuedOn } from '../queue'
import type { Scene } from '../scene'
import {
  drawMark,
  drawOnItsWay,
  drawQueued,
  drawTitle,
  heading,
  onItsWay,
  seeRef,
  shown,
  titleLines,
  tree,
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

/** A parked item: its mark and title, the tree hanging from the mark, and, opened, the button that picks it up. */
const drawItem = (d: Drawing, entry: ParkedAt) => {
  const { Box, Text, Button } = d.els
  const { at, name, parked } = entry
  const isOpen = d.scene.pane.selected === parked.id
  const lines = titleLines(d, parked.title, isOpen)
  const pickUp = drawPickUp(d, entry)
  const branches = shown(
    isOpen && parked.where,
    isOpen && d.scene.place.level !== 'session' && { text: `raised in ${name}`, color: C.grey },
    isOpen && seeRef(parked.ref),
    pickUp,
  )

  return (
    <Box key={`parked:${at.work}:${parked.id}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        {drawMark(d, MARK, lines.length, branches.length > 0)}
        <Box flexGrow={1} flexShrink={1}>
          {drawTitle(d, `ppick:${parked.id}`, lines, () => d.act.select(parked.id))}
        </Box>
        <Text color={C.grey}>{ago(d.scene.now, parked.at)}</Text>
      </Box>
      {tree(d, `under:${parked.id}`, branches)}
      {isOpen && pickUp === undefined && (
        <Box paddingLeft={2}>
          <Button
            key={`pickup:${parked.id}`}
            label="pick it up"
            onPress={() => d.act.reply({ ...at, item: parked.id, verdict: 'pickup' })}
          />
        </Box>
      )}
    </Box>
  )
}

export const drawParkedView = (d: Drawing) => {
  const { Box, Text, Button } = d.els
  const parked = parkedAt(d.scene)

  return (
    <Box flexDirection="column" gap={1}>
      <Button
        key="back"
        plain
        dimColor
        label="← back to the board"
        onPress={() => d.act.show('board')}
      />
      <Box flexDirection="column">
        {heading(d, `PARKED IN ${whereOf(d.scene)}`, C.parked, `${parked.length}`)}
        <Text color={C.grey} italic wrap="wrap">
          {ABOUT}
        </Text>
      </Box>
      <Box flexDirection="column" rowGap={1}>
        {parked.length === 0 && <Text color={C.grey}>Nothing parked.</Text>}
        {parked.map(each => drawItem(d, each))}
      </Box>
    </Box>
  )
}
