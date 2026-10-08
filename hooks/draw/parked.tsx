/**
 * The parked view, scoped to where the board is looking: what a session,
 * a project's sessions or every project raised and put off, each to pick
 * up. A pick-up queues in Ready to send like any reply.
 */
import { ago, C, clip, GLYPH } from '../look'
import { filedAt, homeOf, parkedAt, projectName, samePlace, type ParkedAt } from '../places'
import { queuedOn } from '../queue'
import type { Scene } from '../scene'
import { drawOnItsWay, drawQueued, heading, onItsWay, type Drawing } from './kit'

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

/** Where to look, the session that raised it where the view spans several, and the button that picks it up. */
const drawOpened = (d: Drawing, { at, name, parked }: ParkedAt) => {
  const { Box, Text, Button } = d.els

  return (
    <Box flexDirection="column">
      {parked.where !== undefined && (
        <Text color={C.soft} wrap="wrap">
          {parked.where}
        </Text>
      )}
      <Box flexDirection="row" columnGap={2} flexWrap="wrap">
        {d.scene.place.level !== 'session' && <Text color={C.grey}>raised in {name}</Text>}
        <Button
          key={`pickup:${parked.id}`}
          label="pick it up"
          onPress={() => d.act.reply({ ...at, item: parked.id, verdict: 'pickup' })}
        />
      </Box>
    </Box>
  )
}

/** What hangs under a parked item: the pick-up waiting to be sent, or on its way, or, opened, its button. */
const drawUnder = (d: Drawing, entry: ParkedAt) => {
  const { at, parked } = entry
  const queued = queuedOn(d.scene.queue, at.work, parked.id)
  const sent = onItsWay(parked)

  if (queued !== undefined) {
    return drawQueued(d, parked, queued)
  }

  if (sent !== undefined) {
    return drawOnItsWay(d, parked, sent)
  }

  return d.scene.pane.selected === parked.id && drawOpened(d, entry)
}

const drawItem = (d: Drawing, entry: ParkedAt) => {
  const { Box, Text, Button } = d.els
  const { at, parked } = entry

  return (
    <Box key={`parked:${at.work}:${parked.id}`} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Text color={C.parked}>{GLYPH.parked}</Text>
        <Box flexGrow={1} flexShrink={1}>
          <Button
            key={`ppick:${parked.id}`}
            plain
            label={clip(parked.title, d.width - 8)}
            onPress={() => d.act.select(parked.id)}
          />
        </Box>
        <Text color={C.grey}>{ago(d.scene.now, parked.at)}</Text>
      </Box>
      <Box paddingLeft={2} flexDirection="column">
        {drawUnder(d, entry)}
      </Box>
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
