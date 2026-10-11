/**
 * What every part of the board draws with, and the pieces they share: the
 * line naming what a view is of, a section's heading, a glyph before a
 * line, an item's title and mark with its tree hanging from the mark, the
 * row every list's entries share, and a reply on one row, waiting in Ready
 * to send or on its way.
 *
 * Drawing is pure: a surface's element table and plain data in, a tree
 * out; what a button does is the actions' (hooks/actions.ts).
 */
import type { ElementTable, RenderElement, RenderSurface } from 'claude-code'
import { answerOf, isPending, moreLines, type Ask, type Parked, type ReplyFields } from '../../core'
import type { SitrepAnswering, SitrepItemRef, SitrepQueued } from '../../types'
import type { Actions } from '../actions'
import { ago, C, clip, counted, GLYPH, wrapped } from '../look'
import { itemKey } from '../places'
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
 * A piece of the board's list, one under another: a section's heading, an
 * entry of a list, a section with no buttons in it. The docked board
 * measures each, to know how tall the list is and where each piece sits in
 * it (DESIGN.md, "One engine, two front ends").
 */
export type Block = {
  /** Unique across the board, and kept from one drawing to the next. */
  key: string
  element: RenderElement
  /** Whether a blank row comes before it. */
  isSpaced?: boolean
}

/** The blocks of several parts of the board, a blank row before each part but the first; a part with no blocks takes no row. */
export const spaced = (...parts: readonly (readonly Block[])[]): Block[] =>
  parts
    .filter(part => part.length > 0)
    .flatMap((part, i) =>
      part.map((block, j) => (i > 0 && j === 0 ? { ...block, isSpaced: true } : block)),
    )

/** Where Lee writes back from: the surface the answering mode is begun on, and whether the mod can fill its prompt box. */
type Writing = { surface: SitrepAnswering['surface']; canFill: boolean }

/**
 * How Lee writes back to an ask from a surface: in the terminal's prompt
 * box, which the mod reads and fills and whose Enter it hears; in Claude's
 * app, whose Enter it hears (the Remote Control bridge) but whose box it
 * cannot reach; or not at all, where how a prompt arrives is unproven
 * (Desktop, VS Code).
 */
const WRITING: Partial<Record<RenderSurface, Writing>> = {
  terminal: { surface: 'terminal', canFill: true },
  mobile: { surface: 'mobile', canFill: false },
}

/** Whether the surface's prompt box can be filled with words already queued, to write them again. */
const canRewrite = (d: Drawing) => WRITING[d.surface]?.canFill === true

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
  const fill = Math.max(2, width - label.length - note.length - 2)

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

/** The line a section with nothing in it shows under its heading, soft as a line describing it. */
export const emptyLine = ({ els }: Drawing, words: string) => {
  const { Text } = els

  return <Text color={C.soft}>{words}</Text>
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

/** The most characters the engine takes in a hover group's name. */
const SCOPE_CHARS = 64

/** A short fingerprint of text: FNV-1a over its code points, in base 36. */
const fingerprint = (text: string) =>
  Array.from(text, ch => ch.codePointAt(0) ?? 0)
    .reduce((hash, point) => Math.imul(hash ^ point, 0x01000193) >>> 0, 0x811c9dc5)
    .toString(36)

/** The hover group of the title a press key opens: the key itself where the engine takes it as a name, else its fingerprint. */
export const hoverScope = (key: string) =>
  key.length <= SCOPE_CHARS && !/\p{Cc}/u.test(key) ? key : `#${fingerprint(key)}`

/**
 * An item's title as the press that opens and closes it. A Button's label
 * never wraps, so each line of an opened title is a Button of its own,
 * pressing the same, and all of them one hover group, so the whole title
 * lights whichever line the pointer is on.
 */
export const drawTitle = (
  { els }: Drawing,
  key: string,
  lines: readonly string[],
  onPress: () => void,
) => {
  const { Box, Button } = els
  const hover = { scope: hoverScope(key), inverse: true }

  return (
    <Box flexDirection="column">
      {lines.map((line, i) => (
        <Button
          key={i === 0 ? key : `${key}:${i}`}
          plain
          label={line}
          hover={hover}
          onPress={onPress}
        />
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
        <Text key={`stem:${i}`} color={C.faint}>
          {GLYPH.stem}
        </Text>
      ))}
    </Box>
  )
}

/** A line on a tree in a colour of its own, rather than soft. */
export type Tinted = { text: string; color: string }

/** A line on a tree opening with a label in a colour of its own, the text after it soft. */
export type Labelled = { label: string; text: string; color: string }

/** A branch of an item's tree: soft text, a line in a colour of its own, a labelled line, or a node drawn as it is. */
export type Branch = string | Tinted | Labelled | RenderElement

/** Where an item's own record is, as an opened item's tree points to it, labelled in the item's colour. */
export const seeRef = (ref: string | undefined, color: string): Labelled | false =>
  ref !== undefined && { label: 'see', text: ref, color }

/** The branches a tree is shown with: those given, less any not shown in their place. */
export const shown = (...each: readonly (Branch | false | undefined)[]) =>
  each.filter((branch): branch is Branch => Boolean(branch))

const isNode = (branch: Branch): branch is RenderElement =>
  typeof branch !== 'string' && 'type' in branch

const isLabelled = (branch: Branch): branch is Labelled =>
  typeof branch !== 'string' && 'label' in branch

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

/** A labelled line's rows: the label in its colour on the first, the text soft after it and on as many rows as it takes. */
const labelledRows = ({ els }: Drawing, { label, text, color }: Labelled, width: number) => {
  const { Text } = els
  const [first = label, ...rest] = textRows(`${label} ${text}`, width)

  return [
    <Text color={C.soft}>
      <Text color={color}>{label}</Text>
      {first.slice(label.length)}
    </Text>,
    ...rest.map(line => <Text color={C.soft}>{line}</Text>),
  ]
}

/** A branch's rows: a node on one, or its text on as many as it takes. */
const rowsOfBranch = (d: Drawing, branch: Branch, width: number): RenderElement[] => {
  const { Text } = d.els

  if (isNode(branch)) {
    return [branch]
  }

  if (isLabelled(branch)) {
    return labelledRows(d, branch, width)
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
            <Text color={C.faint}>{glyphOf(i === branches.length - 1, j)}</Text>
            <Box flexGrow={1} flexShrink={1}>
              {row}
            </Box>
          </Box>
        )),
      )}
    </Box>
  )
}

/** An entry of a list (a log line, a parked item, an ask), as its row draws it. */
export type Row = {
  /** The row's own key; its tree's are made from it. */
  key: string
  mark: Mark
  title: string
  /** When it happened, as the age on the right says. */
  at: number
  isOpen: boolean
  /** The title's press: its key, and what it does. None for a row closed for good, its title faint. */
  press?: { key: string; onPress: () => void }
  branches: readonly Branch[]
  /** What comes after the tree, under the title. */
  after?: RenderElement | false
}

/** A row's title: the press that opens it, or, with none, faint text. */
const drawRowTitle = (d: Drawing, lines: readonly string[], press: Row['press']) => {
  const { Text } = d.els

  return press === undefined ? (
    <Text color={C.faint} wrap="truncate-end">
      {lines.join(' ')}
    </Text>
  ) : (
    drawTitle(d, press.key, lines, press.onPress)
  )
}

/**
 * The row every list draws its entries with: the mark, the title as the
 * press that opens it, clipped to a line until it is opened, and the age on
 * the right; the tree hanging from the mark, a stem beside the title's
 * further lines.
 */
export const drawRow = (
  d: Drawing,
  { key, mark, title, at, isOpen, press, branches, after }: Row,
) => {
  const { Box, Text } = d.els
  const lines = titleLines(d, title, isOpen)

  return (
    <Box key={key} flexDirection="column">
      <Box flexDirection="row" gap={1}>
        {drawMark(d, mark, lines.length, branches.length > 0)}
        <Box flexGrow={1} flexShrink={1}>
          {drawRowTitle(d, lines, press)}
        </Box>
        <Text color={C.grey}>{ago(d.scene.now, at)}</Text>
      </Box>
      {tree(d, `tree:${key}`, branches)}
      {after}
    </Box>
  )
}

/** The reply an item waits on Claude with: sent from a board into its work's inbox, not delivered yet. */
export const onItsWay = (item: Ask | Parked) => item.replies.findLast(isPending)

/**
 * A reply on one row, as the board shows it under its item and in Ready to
 * send: its words cut short at the edge, how many lines they run to past
 * the first, and what goes after them, kept whole.
 */
export const drawReplyRow = (
  { els }: Drawing,
  item: Ask | Parked,
  reply: ReplyFields,
  after?: RenderElement | false,
) => {
  const { Box, Text } = els
  const more = moreLines(reply)

  return (
    <Box flexGrow={1} flexShrink={1} flexDirection="row" columnGap={1}>
      <Box flexShrink={1}>
        <Text color={C.soft} wrap="truncate-end">
          {answerOf(item, reply)}
        </Text>
      </Box>
      {more > 0 && (
        <Box flexShrink={0}>
          <Text color={C.grey} wrap="truncate-end">
            {`+${counted(more, 'line', 'lines')}`}
          </Text>
        </Box>
      )}
      {after !== undefined && after !== false && <Box flexShrink={0}>{after}</Box>}
    </Box>
  )
}

/** A reply sent but not delivered yet, as a branch under what it answers. */
export const drawOnItsWay = (d: Drawing, item: Ask | Parked, reply: ReplyFields) => {
  const { Text } = d.els

  return drawReplyRow(d, item, reply, <Text color={C.grey}>· on its way</Text>)
}

/** Answering an ask in the prompt box, with its answer or a comment on it, from the surface drawn on; none where Lee cannot write back. */
export const answeringOf = (
  d: Drawing,
  at: SitrepItemRef,
  ask: Pick<Ask, 'title'>,
  as: SitrepAnswering['as'],
): SitrepAnswering | undefined => {
  const writing = WRITING[d.surface]

  return writing === undefined
    ? undefined
    : {
        project: at.project,
        work: at.work,
        item: at.item,
        as,
        title: ask.title,
        surface: writing.surface,
      }
}

/**
 * The way to write a queued reply's words in the prompt box, under `key`: a
 * bare yes's or choice's comment; or, where the box can be filled with
 * them, the words of an answer, a comment, or a yes's or choice's comment,
 * written again. None for an ignore or a pick-up.
 */
export const drawRewrite = (d: Drawing, key: string, item: Ask | Parked, queued: SitrepQueued) => {
  const { Button } = d.els
  const words = queued.note
  const answering = answeringOf(d, queued, item, queued.verdict === 'answer' ? 'answer' : 'comment')

  if (item.type === 'park' || queued.verdict === 'ignore' || answering === undefined) {
    return undefined
  }

  if (words !== undefined && !canRewrite(d)) {
    return undefined
  }

  return (
    <Button
      key={key}
      plain
      dimColor
      label={words === undefined ? '✎ comment' : '✎ edit'}
      onPress={() => d.act.answer(answering, words)}
    />
  )
}

/**
 * A reply in Ready to send, as a branch under what it answers: undone from
 * there until a send carries it, its words written again from there.
 */
export const drawQueued = (d: Drawing, item: Ask | Parked, queued: SitrepQueued) => {
  const { Box, Text, Button } = d.els
  const isOnItsWay = isCarried(d.scene.inFlight, queued)
  const key = itemKey(queued.work, queued.item)

  return drawReplyRow(
    d,
    item,
    queued,
    <Box flexDirection="row" columnGap={1}>
      <Text color={C.grey}>{isOnItsWay ? '· on its way' : '· not sent yet'}</Text>
      {!isOnItsWay && (
        <Button
          key={`undo:${key}`}
          plain
          dimColor
          label="↺ undo"
          onPress={() => d.act.unqueue(queued.work, queued.item)}
        />
      )}
      {!isOnItsWay && drawRewrite(d, `rewrite:${key}`, item, queued)}
    </Box>,
  )
}
