/**
 * What every part of the board draws with, and the pieces they share: the
 * line naming what a view is of, a section's heading, a glyph before a
 * line, a line hung from a tree, and a reply waiting in Ready to send or
 * on its way.
 *
 * Drawing is pure: a surface's element table and plain data in, a tree
 * out; what a button does is the actions' (hooks/actions.ts).
 */
import type { ElementTable, RenderElement, RenderSurface } from 'claude-code'
import { answerOf, isPending, type Ask, type Parked, type ReplyFields } from '../../core'
import type { SitrepQueued } from '../../types'
import type { Actions } from '../actions'
import { C, clip, GLYPH, wrapped } from '../look'
import { isCarried } from '../queue'
import type { Scene } from '../scene'

export type Els = ElementTable

/** What a part of the board is drawn with: the surface's elements, what its buttons do, what it shows, and its room. */
export type Drawing = {
  els: Els
  surface: RenderSurface
  act: Actions
  scene: Scene
  /** Cells across, inside the column kept free each side. */
  width: number
  /** Docked beside the transcript, rather than inline above the prompt. */
  isDock: boolean
}

/**
 * How Lee types on each surface: in the mod's own text area, in the
 * surface's one-line field, or not at all. Read off the surface, since its
 * element table names every element, one it lacks drawing nothing.
 */
const TYPING: Record<RenderSurface, 'area' | 'field' | 'none'> = {
  terminal: 'area',
  desktop: 'area',
  vscode: 'field',
  mobile: 'none',
}

export const typingOn = (d: Drawing) => TYPING[d.surface]

export const canType = (d: Drawing) => typingOn(d) !== 'none'

/** The line under the tabs naming what the view is of, with a few words on it, and a summary under it. */
export const context = ({ els }: Drawing, title: string, aside: string, summary?: string) => {
  const { Box, Text } = els

  return (
    <Box flexDirection="column">
      <Box flexDirection="row" gap={1}>
        <Text bold>{title}</Text>
        <Box flexGrow={1} flexShrink={1}>
          <Text color={C.grey} wrap="truncate-end">
            {`· ${aside}`}
          </Text>
        </Box>
      </Box>
      {summary !== undefined && (
        <Text color={C.soft} wrap="wrap">
          {summary}
        </Text>
      )}
    </Box>
  )
}

/** How much waits on Lee, as a view's line under the tabs says it. */
export const waitingWords = (count: number) =>
  count > 0 ? `${count} waiting on you` : 'nothing waiting on you'

/** A section's title, a rule to the edge, and its few words at the end. */
export const heading = (
  { els, width }: Drawing,
  label: string,
  color: string,
  note: string,
  noteColor: string = C.grey,
) => {
  const { Box, Text } = els
  const fill = Math.max(2, width - label.length - note.length - 3)

  return (
    <Box flexDirection="row" gap={1}>
      <Text color={color} bold>
        {label}
      </Text>
      <Text color={C.rule}>{'─'.repeat(fill)}</Text>
      <Text color={noteColor}>{note}</Text>
    </Box>
  )
}

/** A glyph and the line it marks, the line wrapping beside it. */
export const marked = (
  { els }: Drawing,
  key: string,
  glyph: string,
  color: string,
  line: RenderElement,
) => {
  const { Box, Text } = els

  return (
    <Box key={key} flexDirection="row" gap={1}>
      <Text color={color}>{glyph}</Text>
      <Box flexGrow={1} flexShrink={1}>
        {line}
      </Box>
    </Box>
  )
}

/** A line hanging from what it describes by a `└`, and what goes after it on the line. */
/** What a title's line gives up to the row around it: the glyph before it and the age after. */
const TITLE_GUTTER = 8

/**
 * An item's title as the press that opens and closes it: clipped to a line,
 * or opened, the whole of it. A Button's label never wraps, so each line of
 * an opened title is a Button of its own, pressing the same.
 */
export const drawTitle = (
  d: Drawing,
  key: string,
  title: string,
  isOpen: boolean,
  onPress: () => void,
) => {
  const { Box, Button } = d.els
  const width = d.width - TITLE_GUTTER
  const lines = isOpen ? wrapped(title, width) : [clip(title, width)]

  return (
    <Box flexDirection="column">
      {lines.map((line, i) => (
        <Button key={i === 0 ? key : `${key}:${i}`} plain label={line} onPress={onPress} />
      ))}
    </Box>
  )
}

/** Where an item's own record is, as an opened item shows it. */
export const drawRef = ({ els }: Drawing, ref: string | undefined) => {
  const { Text } = els

  return (
    ref !== undefined && (
      <Text color={C.soft} wrap="wrap">
        see {ref}
      </Text>
    )
  )
}

export const hung = ({ els }: Drawing, key: string, text: string, after?: RenderElement) => {
  const { Box, Text } = els

  return (
    <Box key={key} flexDirection="row" gap={1}>
      <Text color={C.rule}>{GLYPH.last}</Text>
      <Box flexGrow={1} flexShrink={1} flexDirection="row" columnGap={1} flexWrap="wrap">
        <Text color={C.soft} wrap="wrap">
          {text}
        </Text>
        {after}
      </Box>
    </Box>
  )
}

/** The reply an item waits on Claude with: sent from a board into its work's inbox, not delivered yet. */
export const onItsWay = (item: Ask | Parked) => item.replies.findLast(isPending)

/** A reply sent but not delivered yet, hung under what it answers. */
export const drawOnItsWay = (d: Drawing, item: Ask | Parked, reply: ReplyFields) => {
  const { Text } = d.els

  return hung(
    d,
    `onitsway:${item.id}`,
    answerOf(item, reply),
    <Text color={C.grey}>· on its way</Text>,
  )
}

/** A reply in Ready to send, hung under what it answers: undone from there until a send carries it. */
export const drawQueued = (d: Drawing, item: Ask | Parked, queued: SitrepQueued) => {
  const { Box, Text, Button } = d.els
  const isOnItsWay = isCarried(d.scene.inFlight, queued)

  return hung(
    d,
    `queued:${item.id}`,
    answerOf(item, queued),
    <Box flexDirection="row" columnGap={1}>
      <Text color={C.grey}>{isOnItsWay ? '· on its way' : '· not sent yet'}</Text>
      {!isOnItsWay && (
        <Button
          key={`undo:${item.id}`}
          plain
          dimColor
          label="↺ undo"
          onPress={() => d.act.unqueue(queued.work, queued.item)}
        />
      )}
    </Box>,
  )
}

/** Lines opened under an item, as a tree; `none` in their place when there are none. */
export const tree = ({ els }: Drawing, key: string, lines: readonly string[], none: string) => {
  const { Box, Text } = els

  if (lines.length === 0) {
    return (
      <Box key={`${key}:none`} flexDirection="row" gap={1}>
        <Text color={C.rule}>{GLYPH.last}</Text>
        <Text color={C.grey}>{none}</Text>
      </Box>
    )
  }

  return lines.map((line, i) => (
    <Box key={`${key}:${i}`} flexDirection="row" gap={1}>
      <Text color={C.rule}>{i === lines.length - 1 ? GLYPH.last : GLYPH.branch}</Text>
      <Box flexGrow={1} flexShrink={1}>
        <Text color={C.soft} wrap="wrap">
          {line}
        </Text>
      </Box>
    </Box>
  ))
}
