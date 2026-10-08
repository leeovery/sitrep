/**
 * The band: one line above the prompt, counts alone, kept to the right,
 * each a way into the board, and the board's own show or hide. Below 64
 * columns the words drop and the counts stay. For a few seconds after the
 * window takes in replies sent from another work's board, it says so.
 */
import { C, counted, GLYPH } from '../look'
import { BAND } from '../pane'
import { waitingElsewhere } from '../places'
import { countMark, type Scene } from '../scene'
import type { Els } from './kit'

/** Narrower than this, the band keeps its counts and drops their words. */
const NARROW = 64

/** Every press on the band is answered by the `ui.press` hook, inside the press itself. */
const answeredByTheHook = () => undefined

export const drawBand = (els: Els, width: number, scene: Scene) => {
  const { Box, Text, Button } = els
  const { work, pane, flash } = scene
  const isNarrow = width < NARROW
  const waiting = work.waiting
  const elsewhere = waitingElsewhere(scene)
  const parked = work.parked.length
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
          label={isNarrow ? `+${elsewhere}` : `${elsewhere} in other sessions`}
          onPress={answeredByTheHook}
        />
      )}
      {parked > 0 && (
        <Box flexDirection="row" gap={1}>
          <Text color={C.parked}>{GLYPH.parked}</Text>
          <Button
            key={BAND.parked}
            plain
            dimColor
            label={isNarrow ? `${parked}` : `${parked} parked`}
            onPress={answeredByTheHook}
          />
        </Box>
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
