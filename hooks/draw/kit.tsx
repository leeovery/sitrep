/**
 * What every part of the board draws with, and the pieces they share: the
 * line naming what a view is of, a section's heading, a glyph before a
 * line, an item's title and mark with its tree hanging from the mark, a
 * line hung from a `└`, and a reply waiting in Ready to send or on its way.
 *
 * Drawing is pure: a surface's element table and plain data in, a tree
 * out; what a button does is the actions' (hooks/actions.ts).
 */
import type { ElementTable, RenderElement, RenderSurface } from 'claude-code'
import {
  answerOf,
  isPending,
  type Ask,
  type AskKind,
  type Parked,
  type ReplyFields,
} from '../../core'
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

/** A yes, by the kind of ask it answers: its button's words, on the ask and on the field taking what it needs back. A decide ask offers no yes, so its words are never drawn. */
export const YES: Record<AskKind, string> = {
  review: '✓ approve',
  decide: '✓ approve',
  try: '✓ it works',
  do: '✓ done',
}

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

/** What a title's line gives up to the row around it: the glyph before it and the age after. */
const TITLE_GUTTER = 8

/** An item's title as the lines it is drawn on: clipped to one, or opened, the whole of it. */
export const titleLines = (d: Drawing, title: string, isOpen: boolean) => {
  const width = d.width - TITLE_GUTTER

  return isOpen ? wrapped(title, width) : [clip(title, width)]
}

/**
 * An item's title as the press that opens and closes it. A Button's label
 * never wraps, so each line of an opened title is a Button of its own,
 * pressing the same.
 */
export const drawTitle = (
  { els }: Drawing,
  key: string,
  lines: readonly string[],
  onPress: () => void,
) => {
  const { Box, Button } = els

  return (
    <Box flexDirection="column">
      {lines.map((line, i) => (
        <Button key={i === 0 ? key : `${key}:${i}`} plain label={line} onPress={onPress} />
      ))}
    </Box>
  )
}

/** How an item is marked: its glyph, in its colour. */
export type Mark = { glyph: string; color: string }

/** An item's mark beside a title of `rows` lines; over a tree, a stem beside each further line joins the two. */
export const drawMark = (
  { els }: Drawing,
  { glyph, color }: Mark,
  rows: number,
  isHung: boolean,
) => {
  const { Box, Text } = els
  const stems = isHung ? rows - 1 : 0

  return (
    <Box flexDirection="column">
      <Text color={color}>{glyph}</Text>
      {Array.from({ length: stems }, (_, i) => (
        <Text key={`stem:${i}`} color={C.rule}>
          {GLYPH.stem}
        </Text>
      ))}
    </Box>
  )
}

/** Where an item's own record is, as an opened item's tree points to it. */
export const seeRef = (ref: string | undefined) => ref !== undefined && `see ${ref}`

/** A line on a tree in a colour of its own, rather than soft. */
export type Tinted = { text: string; color: string }

/** A branch of an item's tree: soft text, a line in a colour of its own, or a node drawn as it is. */
export type Branch = string | Tinted | RenderElement

/** The branches a tree is shown with: those given, less any not shown in their place. */
export const shown = (...each: readonly (Branch | false | undefined)[]) =>
  each.filter((branch): branch is Branch => Boolean(branch))

const isNode = (branch: Branch): branch is RenderElement =>
  typeof branch !== 'string' && 'type' in branch

const tinted = (branch: string | Tinted): Tinted =>
  typeof branch === 'string' ? { text: branch, color: C.soft } : branch

/** Text broken into the rows it takes `width` across, a line it was given keeping to rows of its own. */
const textRows = (text: string, width: number) =>
  text.split('\n').flatMap(line => wrapped(line, width))

/** The tree's glyph beside a branch's row: the branch's own on its first, then the stem running on, or none under the last. */
const glyphOf = (isLast: boolean, row: number) => {
  const [first, after] = isLast ? [GLYPH.last, ' '] : [GLYPH.branch, GLYPH.stem]

  return row === 0 ? first : after
}

/** A branch's rows: a node on one, or its text on as many as it takes. */
const rowsOfBranch = ({ els }: Drawing, branch: Branch, width: number): RenderElement[] => {
  const { Text } = els

  if (isNode(branch)) {
    return [branch]
  }

  const { text, color } = tinted(branch)

  return textRows(text, width).map(line => <Text color={color}>{line}</Text>)
}

/**
 * What hangs from an item's mark, `column` cells in: `├` on each branch but
 * the last, `└` on the last. A branch's text is broken into rows here, not
 * by the surface, so the stem runs on beside every row of it.
 */
export const tree = (d: Drawing, key: string, branches: readonly Branch[], column = 0) => {
  const { Box, Text } = d.els
  const width = d.width - column - 2

  return (
    <Box flexDirection="column" paddingLeft={column}>
      {branches.flatMap((branch, i) =>
        rowsOfBranch(d, branch, width).map((row, j) => (
          <Box key={`${key}:${i}:${j}`} flexDirection="row" gap={1}>
            <Text color={C.rule}>{glyphOf(i === branches.length - 1, j)}</Text>
            <Box flexGrow={1} flexShrink={1}>
              {row}
            </Box>
          </Box>
        )),
      )}
    </Box>
  )
}

/** Soft words hung under an item, a reply or how it closed, and what goes after them on the line. */
export const replyLine = ({ els }: Drawing, text: string, after?: RenderElement) => {
  const { Box, Text } = els

  return (
    <Box flexGrow={1} flexShrink={1} flexDirection="row" columnGap={1} flexWrap="wrap">
      <Text color={C.soft} wrap="wrap">
        {text}
      </Text>
      {after}
    </Box>
  )
}

/** A line hanging from what it describes by a `└`, and what goes after it on the line. */
export const hung = (d: Drawing, key: string, text: string, after?: RenderElement) => {
  const { Box, Text } = d.els

  return (
    <Box key={key} flexDirection="row" gap={1}>
      <Text color={C.rule}>{GLYPH.last}</Text>
      {replyLine(d, text, after)}
    </Box>
  )
}

/** The reply an item waits on Claude with: sent from a board into its work's inbox, not delivered yet. */
export const onItsWay = (item: Ask | Parked) => item.replies.findLast(isPending)

/** A reply sent but not delivered yet, as a branch under what it answers. */
export const drawOnItsWay = (d: Drawing, item: Ask | Parked, reply: ReplyFields) => {
  const { Text } = d.els

  return replyLine(d, answerOf(item, reply), <Text color={C.grey}>· on its way</Text>)
}

/** A reply in Ready to send, as a branch under what it answers: undone from there until a send carries it. */
export const drawQueued = (d: Drawing, item: Ask | Parked, queued: SitrepQueued) => {
  const { Box, Text, Button } = d.els
  const isOnItsWay = isCarried(d.scene.inFlight, queued)

  return replyLine(
    d,
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
