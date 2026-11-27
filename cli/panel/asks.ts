/**
 * The chosen row's asks, opened under it, one at a time, as the notch's asks
 * panel shows them: the lines of its head and of the ask shown, and how
 * they give way short of rows. Layout counts the lines, draw.ts draws them,
 * and a tap is read from them.
 *
 * - The head: the name and count wrapped whole under the names' column,
 *   room kept on its first line for `▿` in the time's place; then the
 *   project alone.
 * - The ask: its title wrapped whole; `Asked 4m ago`, the page dots at its
 *   right, ending at column W−2, where the row has more than one ask and
 *   they leave the words whole, else none, the asks still paged by `←→`;
 *   its answers, a row each; then the foot, the keys it takes.
 * - An answer: its number in the names' column, the first nine numbered,
 *   as the snooze menu's choices are; its words from column 5, wrapped to
 *   two lines at most, the second cut with `…`. Claude's pick's
 *   ` · Recommended` follows its words, or stands on a line of its own
 *   within the two where they leave no room, the words cut before it past
 *   two lines, so it always shows.
 * - The foot: `x Ignore  z Snooze  o Open`, `z Snooze` only while Snooze
 *   offers a time. Short of columns whole hints go, `z Snooze` first, then
 *   `x Ignore`; `o Open` always stays.
 * - Short of rows: the head gives way first, to the row's one line, which
 *   says whose they are; then the title, to its first line cut with `…`;
 *   then the `Asked` line, the dots with it; then the foot; then the
 *   answers, whole ones from the last.
 */
import { cut, widthOf, wordsOf, wrap, wrapIn, wrapTagged, type Tagged } from './cells'
import { nameLines, type Tag } from './expand'
import { DIGITS } from './keys'
import { NAME, type Lane } from './line'
import { rowKey, type PanelAsk, type PanelRow, type PanelView } from './view'

/** A key and the word for what it does, as the key line and the foot show them. */
export type Hint = [key: string, word: string]

/** What an answer's words are: any answer's, Claude's pick's, or the pick's ` · Recommended`. */
export type AnswerTag = 'answer' | 'pick' | 'tag'

/** A page dot: the column it starts at, its glyphs, and whether its ask is the one shown. */
export type Dot = { x: number; text: string; isShown: boolean }

/** A line of the opened row, as draw.ts draws it; the first line, `head` or `folded`, carries `▿`. */
export type AsksLine =
  | { part: 'head'; words: Tagged<Tag>[] }
  | { part: 'folded' }
  | { part: 'project'; words: Tagged<Tag>[] }
  | { part: 'title'; text: string }
  | { part: 'asked'; text: string; dots: Dot[] }
  | { part: 'answer'; number: string; runs: Tagged<AnswerTag>[] }
  | { part: 'foot'; hints: Hint[] }

/** The asks open under a row: the row, its asks, the one shown and its place among them, and whether Snooze offers a time. */
export type Asking = { row: PanelRow; asks: readonly PanelAsk[]; ask: PanelAsk; at: number; offersSnooze: boolean }

/** Where an answer's words start: past its number and a space. */
export const ANSWER = NAME + 2

const TAG = ' · Recommended'

const SHOWN_DOT = '━━'

const OTHER_DOT = '━'

const FOLDED: AsksLine = { part: 'folded' }

const IGNORE: Hint = ['x', 'Ignore']

const SNOOZE: Hint = ['z', 'Snooze']

const OPEN: Hint = ['o', 'Open']

/** The cells hints take, two between each two. */
export const hintsWidth = (hints: readonly Hint[]) =>
  hints.reduce((sum, [key, word], at) => sum + (at === 0 ? 0 : 2) + widthOf(key) + 1 + widthOf(word), 0)

/** The asks open under the row, where the view has them open under it. */
export const askingIn = (view: PanelView, row: PanelRow): Asking | undefined => {
  const asks = row.answerable ?? []
  const ask = view.asking === undefined ? undefined : asks[view.asking.at]

  return view.asking === undefined || ask === undefined || rowKey(row) !== view.asking.row
    ? undefined
    : { row, asks, ask, at: view.asking.at, offersSnooze: view.asking.offersSnooze }
}

/** The page dots, ending at column `end`, exclusive, a space between each two: none for a row of one ask. */
const dotsOf = ({ asks, at }: Asking, end: number): Dot[] => {
  if (asks.length < 2) {
    return []
  }

  const texts = asks.map((_, index) => (index === at ? SHOWN_DOT : OTHER_DOT))
  const start = end - texts.reduce((sum, text) => sum + widthOf(text), texts.length - 1)

  return texts.reduce<Dot[]>((dots, text, index) => {
    const last = dots.at(-1)
    const x = last === undefined ? start : last.x + widthOf(last.text) + 1

    return [...dots, { x, text, isShown: index === at }]
  }, [])
}

/** The ask whose dot a tap at column `x` lands on, by its place: each dot takes its own cells and the space before it. */
export const dotAt = (dots: readonly Dot[], x: number): number | undefined => {
  const at = dots.findIndex((dot, index) => x >= dot.x - (index === 0 ? 0 : 1) && x < dot.x + widthOf(dot.text))

  return at === -1 ? undefined : at
}

/** `Asked 4m ago`, as its line on the row ages it; `Asked just now` within its first minute, as the notch's asks panel says it. */
const askedOf = (age: string) => (age === 'now' ? 'Asked just now' : `Asked ${age} ago`)

/** An answer's words in `cells`: wrapped to two lines, the second cut; a pick's with its tag after them, or alone on the next line within the two. */
const answerRuns = (words: string, isPick: boolean, cells: number): Tagged<AnswerTag>[][] => {
  const [first = '', ...rest] = wrapIn(words, cells, 2)
  const lines = [first, ...rest]

  if (!isPick) {
    return lines.map(text => [{ text, tag: 'answer' }])
  }

  const last = lines.at(-1) ?? ''
  const before = lines.slice(0, -1).map((text): Tagged<AnswerTag>[] => [{ text, tag: 'pick' }])

  if (widthOf(last + TAG) <= cells) {
    return [...before, [{ text: last, tag: 'pick' }, { text: TAG, tag: 'tag' }]]
  }

  if (lines.length < 2) {
    return [[{ text: last, tag: 'pick' }], [{ text: TAG.trimStart(), tag: 'tag' }]]
  }

  return [...before, [{ text: cut(last, cells - widthOf(TAG)), tag: 'pick' }, { text: TAG, tag: 'tag' }]]
}

/** The foot's hints in `cells`: whole ones given way to fit, `z Snooze` first, then `x Ignore`; `o Open` always stays. */
const footOf = (offersSnooze: boolean, cells: number): Hint[] =>
  [[IGNORE, ...(offersSnooze ? [SNOOZE] : []), OPEN], [IGNORE, OPEN]].find(hints => hintsWidth(hints) <= cells) ?? [OPEN]

/** The lines of the answer at `index`, its number on the first, for the first nine. */
const answerLines = (words: string, isPick: boolean, index: number, cells: number): AsksLine[] =>
  answerRuns(words, isPick, cells).map((runs, line) => ({
    part: 'answer',
    number: line === 0 && index < DIGITS ? String(index + 1) : '',
    runs,
  }))

/** Every line the opened row can show, in its parts, at the layout's width, in its section's lane. */
const partsOf = (asking: Asking, width: number, lane: Lane) => {
  const { row, ask, offersSnooze } = asking
  const cells = width - 1 - NAME
  const asked = askedOf(ask.age)
  const dots = dotsOf(asking, width - 1)
  const isRoomForDots = (dots[0]?.x ?? width) - 1 - NAME >= widthOf(asked)

  return {
    head: [
      ...nameLines(row, cells - Math.max(lane.cells, 1) - 2, cells).map((words): AsksLine => ({ part: 'head', words })),
      ...wrapTagged(wordsOf(row.project, 'meta' as const), cells, cells).map((words): AsksLine => ({ part: 'project', words })),
    ],
    title: wrap(ask.title, cells).map((text): AsksLine => ({ part: 'title', text })),
    titleFirst: { part: 'title', text: wrapIn(ask.title, cells, 1)[0] ?? '' } satisfies AsksLine,
    asked: { part: 'asked', text: asked, dots: isRoomForDots ? dots : [] } satisfies AsksLine,
    answers: ask.answers.map((words, index) => answerLines(words, index === 0 && ask.pick !== undefined, index, width - 1 - ANSWER)),
    foot: { part: 'foot', hints: footOf(offersSnooze, cells) } satisfies AsksLine,
  }
}

type Parts = ReturnType<typeof partsOf>

/** What of the opened row shows: its head whole or as the row's one line, its title whole or its first line, and whether its `Asked` line and foot stand. */
type Stage = { isHeadWhole: boolean; isTitleWhole: boolean; hasAsked: boolean; hasFoot: boolean }

/** The stages short of rows, whole first, each giving up one more part. */
const STAGES: readonly Stage[] = [
  { isHeadWhole: true, isTitleWhole: true, hasAsked: true, hasFoot: true },
  { isHeadWhole: false, isTitleWhole: true, hasAsked: true, hasFoot: true },
  { isHeadWhole: false, isTitleWhole: false, hasAsked: true, hasFoot: true },
  { isHeadWhole: false, isTitleWhole: false, hasAsked: false, hasFoot: true },
  { isHeadWhole: false, isTitleWhole: false, hasAsked: false, hasFoot: false },
]

const LEAST = STAGES.at(-1) as Stage

/** The lines at a stage, with the first `answers` answers. */
const linesAt = (parts: Parts, stage: Stage, answers = parts.answers.length): AsksLine[] => [
  ...(stage.isHeadWhole ? parts.head : [FOLDED]),
  ...(stage.isTitleWhole ? parts.title : [parts.titleFirst]),
  ...(stage.hasAsked ? [parts.asked] : []),
  ...parts.answers.slice(0, answers).flat(),
  ...(stage.hasFoot ? [parts.foot] : []),
]

/**
 * The opened row's lines at the layout's width, in its section's lane, in
 * `room` rows at most: the first stage that fits, then the answers given
 * way from the last; in fewer rows than the head's first line and the
 * title's, as many of those as fit.
 */
export const asksLinesOf = (asking: Asking, width: number, lane: Lane, room = Number.MAX_SAFE_INTEGER): AsksLine[] => {
  const parts = partsOf(asking, width, lane)
  const staged = STAGES.find(stage => linesAt(parts, stage).length <= room)

  if (staged !== undefined) {
    return linesAt(parts, staged)
  }

  const answers = parts.answers.findLastIndex((_, at) => linesAt(parts, LEAST, at).length <= room)

  return linesAt(parts, LEAST, Math.max(answers, 0)).slice(0, room)
}

/** Whether a line is the opened row's head, not its ask: a tap there closes the asks. */
export const isHeadLine = (line: AsksLine) => line.part === 'head' || line.part === 'folded' || line.part === 'project'
