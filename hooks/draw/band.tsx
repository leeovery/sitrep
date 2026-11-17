/**
 * The band: one line above the prompt, counts alone, kept to the right,
 * each a way into the board, and the board's own show or hide. Below 64
 * columns the words drop and the counts stay, and the answering line says
 * Enter alone, to leave the title room. Where the board said it sits
 * inline the hide is a bracketed `✕ close`, wide enough to tap where the
 * frame's own ✕ is one cell. For a few seconds after the window takes in
 * replies sent from another session's board, it says so.
 *
 * While Lee writes to an item in the prompt, the band on the surface Lee
 * began on says only that, the whole time, with the way out of it: the next
 * Enter answers that ask, comments on it, or picks up that parked item.
 *
 * What another plugin draws above the prompt stays, stacked above the band in
 * the rows the band leaves it, so the band keeps the row on the prompt that
 * the answering line's ↓ points at. From Claude Code 2.1.323 each plugin
 * draws a row of its own, which the engine stacks; before, the band's own
 * drawing stacked what it found beneath it.
 */
import type { RenderElement, RenderPropsOf, RenderSurface } from 'claude-code'
import type { SitrepPane } from '../../types'
import { answeringIn, writtenAs, type Answering } from '../answering'
import { C, clip, CLOSE, counted, GLYPH } from '../look'
import { BAND, placementOn } from '../pane'
import { waitingElsewhere, waitingHere } from '../places'
import { countMark, type Scene } from '../scene'
import { answeredByTheHook, type Els } from './kit'

/** The band's own rows: one line. */
export const BAND_ROWS = 1

/** Narrower than this, the band keeps its counts and drops their words, and the answering line its "Your next". */
const NARROW = 64

/** What the next Enter does, by what Lee is writing: an answer where it closes the ask. */
const NEXT_ENTER = { answer: 'answers', comment: 'comments on', pickup: 'picks up' } as const

const CANCEL = 'cancel'

const SHOW_BOARD = { plain: true, label: '▸ show board' } as const
const HIDE_BOARD = { plain: true, dimColor: true, label: 'hide board' } as const

/** The board's own button: show while it is closed; open, close where the board said it sits inline, and hide anywhere else. */
const boardButton = (pane: SitrepPane, surface: RenderSurface) => {
  if (!pane.isOpen) {
    return SHOW_BOARD
  }

  return placementOn(pane, surface) === 'inline' ? CLOSE : HIDE_BOARD
}

/** What the answering line says acts: the next Enter, or, narrow, Enter alone. */
const enterOf = (width: number) => (width < NARROW ? 'Enter' : 'Your next Enter')

/** The cells the answering line keeps beside the item's title: its words around it, the arrow down to the prompt, the gap, and cancel. */
const answeringCells = (enter: string, verb: string) =>
  `✎ ${enter} ${verb} ""  ↓`.length + 2 + CANCEL.length

/** While Lee writes to an item in the prompt: what the next Enter does, pointing down at the prompt, and cancel at the right. */
const drawAnswering = (els: Els, width: number, standing: Answering, scene: Scene) => {
  const { Box, Text, Button } = els
  const enter = enterOf(width)
  const verb = NEXT_ENTER[writtenAs(standing, scene.queue)]
  const title = clip(standing.answering.title, Math.max(8, width - answeringCells(enter, verb)))

  return (
    <Box flexDirection="row" columnGap={2} width={width}>
      <Box flexGrow={1} flexShrink={1}>
        <Text wrap="truncate-end">
          <Text color={C.ask}>✎</Text>
          {` ${enter} ${verb} "${title}"  ↓`}
        </Text>
      </Box>
      <Button key={BAND.cancelAnswer} plain label={CANCEL} onPress={answeredByTheHook} />
    </Box>
  )
}

/** The counts, each a way into the board, and the board's own show or hide. */
const drawCounts = (els: Els, surface: RenderSurface, width: number, scene: Scene) => {
  const { Box, Text, Button } = els
  const { pane, flash } = scene
  const isNarrow = width < NARROW
  const waiting = waitingHere(scene)
  const elsewhere = waitingElsewhere(scene)
  const mark = countMark(scene, waiting)

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
          key={BAND.asks}
          plain
          dimColor={waiting === 0}
          label={isNarrow ? `${waiting}` : counted(waiting, 'ask', 'asks')}
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
      <Button key={BAND.board} {...boardButton(pane, surface)} onPress={answeredByTheHook} />
    </Box>
  )
}

export const drawBand = (
  els: Els,
  surface: RenderSurface,
  width: number,
  scene: Scene,
  beneath: RenderElement,
) => {
  const { Box } = els
  const standing = answeringIn(scene, surface)
  const band =
    standing === undefined
      ? drawCounts(els, surface, width, scene)
      : drawAnswering(els, width, standing, scene)

  // Claude Code draws nothing here outside a survey, so its own drawing is left out.
  return beneath.type === 'engine' ? (
    band
  ) : (
    <Box flexDirection="column">
      {beneath}
      {band}
    </Box>
  )
}

type BandProps = RenderPropsOf['AbovePrompt']

/**
 * What a row above the prompt is drawn with: another plugin's, while the band
 * shows, the rows the band leaves it; the band's own, a row no plugin is
 * named for, and every row while a survey holds the band or no session is
 * held, as Claude Code gave them.
 */
export const besideBand = (plugin: string | undefined, props: BandProps, isHeld: boolean) => {
  const isAnothers = plugin !== undefined && plugin !== 'sitrep'

  return isAnothers && isHeld && !props.hasSurvey
    ? { ...props, maxRows: props.maxRows - BAND_ROWS }
    : props
}

type Row = RenderPropsOf['AbovePromptList']['rows'][number]

const isBand = (row: Row) => row.plugin === 'sitrep'

/** The rows above the prompt as Claude Code stacks them, the band's moved to the foot, on the prompt, and the others kept in their order. */
export const bandLast = (rows: readonly Row[]) => [
  ...rows.filter(row => !isBand(row)),
  ...rows.filter(isBand),
]
