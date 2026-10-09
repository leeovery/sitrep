/**
 * The band: one line above the prompt, counts alone, kept to the right,
 * each a way into the board, and the board's own show or hide. Below 64
 * columns the words drop and the counts stay. For a few seconds after the
 * window takes in replies sent from another work's board, it says so.
 *
 * While Lee answers an ask in the prompt, the band says only that, the
 * whole time, with the way out of it: the next Enter answers that ask.
 */
import { answeringIn, type Answering } from '../answering'
import { C, clip, counted, GLYPH } from '../look'
import { BAND } from '../pane'
import { waitingElsewhere } from '../places'
import { countMark, type Scene } from '../scene'
import type { Els } from './kit'

/** Narrower than this, the band keeps its counts and drops their words. */
const NARROW = 64

/** Every press on the band is answered by the `ui.press` hook, inside the press itself. */
const answeredByTheHook = () => undefined

/** What the next Enter does, by what Lee is writing. */
const NEXT_ENTER = { answer: 'answers', comment: 'comments on' } as const

const CANCEL = 'cancel'

/** The cells the answering line keeps beside the ask's title: its words around it, the arrow down to the prompt, the gap, and cancel. */
const answeringCells = (verb: string) =>
  `✎ Your next Enter ${verb} ""  ↓`.length + 2 + CANCEL.length

/** While Lee answers an ask in the prompt: what the next Enter does, pointing down at the prompt, and cancel at the right. */
const drawAnswering = (els: Els, width: number, { answering }: Answering) => {
  const { Box, Text, Button } = els
  const verb = NEXT_ENTER[answering.as]
  const title = clip(answering.title, Math.max(8, width - answeringCells(verb)))

  return (
    <Box flexDirection="row" columnGap={2} width={width}>
      <Box flexGrow={1} flexShrink={1}>
        <Text wrap="truncate-end">
          <Text color={C.ask}>✎</Text>
          {` Your next Enter ${verb} "${title}"  ↓`}
        </Text>
      </Box>
      <Button key={BAND.cancelAnswer} plain label={CANCEL} onPress={answeredByTheHook} />
    </Box>
  )
}

/** The counts, each a way into the board, and the board's own show or hide. */
const drawCounts = (els: Els, width: number, scene: Scene) => {
  const { Box, Text, Button } = els
  const { work, pane, flash } = scene
  const isNarrow = width < NARROW
  const waiting = work.waiting
  const elsewhere = waitingElsewhere(scene)
  const mark = countMark(scene)

  return (
    <Box flexDirection="row" justifyContent="flex-end" columnGap={2} width={width}>
      {flash > 0 && (
        <Box flexDirection="row" gap={1}>
          <Text color={C.ok}>{GLYPH.news}</Text>
          <Text>
            {isNarrow ? `${flash}` : `${counted(flash, 'reply', 'replies')} from the board`}
          </Text>
        </Box>
      )}
      <Box flexDirection="row" gap={1}>
        <Text color={mark.color}>{mark.glyph}</Text>
        <Button
          key={BAND.forYou}
          plain
          dimColor={waiting === 0}
          label={isNarrow ? `${waiting}` : `${waiting} for you`}
          onPress={answeredByTheHook}
        />
      </Box>
      {elsewhere > 0 && (
        <Button
          key={BAND.elsewhere}
          plain
          dimColor
          label={isNarrow ? `+${elsewhere}` : `${elsewhere} elsewhere`}
          onPress={answeredByTheHook}
        />
      )}
      <Button
        key={BAND.board}
        plain
        dimColor={pane.isOpen}
        label={pane.isOpen ? 'hide board' : '▸ show board'}
        onPress={answeredByTheHook}
      />
    </Box>
  )
}

export const drawBand = (els: Els, width: number, scene: Scene) => {
  const answering = answeringIn(scene)

  return answering === undefined
    ? drawCounts(els, width, scene)
    : drawAnswering(els, width, answering)
}
