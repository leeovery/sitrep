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
 * - An answer sending, found among the ask's by the words it sends, so an
 *   edit that reorders them leaves the check on it, and none where no
 *   answer has them now: its lines held, the check at column W−2 on its
 *   first, which is cut where its words would reach the check, so its
 *   lines stay as they were; in the foot's place the sending line,
 *   `Sending` and the answer's words cut to fit, or `Ignoring`, then the
 *   ring and `u undo`.
 * - With the ask's snooze menu open, the menu takes the foot's place.
 * - Short of rows: the head gives way first, to the row's one line, which
 *   says whose they are; then the title, to its first line cut with `…`;
 *   then the `Asked` line, the dots with it; then the foot; then the
 *   answers, whole ones from the last.
 * - A tap lands on an answer anywhere on its lines, on a page dot, on a
 *   foot's hint or on `u undo`; on nothing else of the ask.
 */
import { cut, widthOf, wordsOf, wrap, wrapIn, wrapTagged, type Tagged } from './cells'
import { nameLines, type Tag } from './expand'
import { NAME, type Lane } from './line'
import { rowKey, type PanelAsk, type PanelRow, type PanelView } from './view'

/** A key and the word for what it does, as the key line and the foot show them. */
export type Hint = [key: string, word: string]

/** What an answer's words are: any answer's, Claude's pick's, or the pick's ` · Recommended`. */
export type AnswerTag = 'answer' | 'pick' | 'tag'

/** A page dot: the column it starts at, its glyphs, and whether its ask is the one shown. */
export type Dot = { x: number; text: string; isShown: boolean }

/** The sending line: `Sending` and the answer's words, cut to fit, or `Ignoring` with none, and the ring as it stands. */
export type SendingLine = { part: 'sending'; lead: string; words: string; ring: string }

/** A line of the opened row, as draw.ts draws it; the first line, `head` or `folded`, carries `▿`. An answer's line says which answer it is, by its place, whether it is its first, and whether it is the one sending. */
export type AsksLine =
  | { part: 'head'; words: Tagged<Tag>[] }
  | { part: 'folded' }
  | { part: 'project'; words: Tagged<Tag>[] }
  | { part: 'title'; text: string }
  | { part: 'asked'; text: string; dots: Dot[] }
  | { part: 'answer'; index: number; isFirst: boolean; isHeld: boolean; runs: Tagged<AnswerTag>[] }
  | { part: 'foot'; hints: Hint[] }
  | SendingLine

/** The answer sending on the ask shown, as the asks draw it: the answer, none for an ignore, and its ring. */
type ShownSending = Omit<NonNullable<PanelView['sending']>, 'row' | 'ask'>

/** The asks open under a row: the row, its asks, the one shown and its place among them, whether Snooze offers a time, whether the ask's snooze menu is open, and the answer sending, where it is the ask shown's. */
export type Asking = { row: PanelRow; asks: readonly PanelAsk[]; ask: PanelAsk; at: number; offersSnooze: boolean; hasMenu: boolean; sending?: ShownSending }

/** What a tap on a line of the ask lands on: an answer, by its place; a page dot's ask, by its place; or a hint, by its key. */
export type AsksTap = { answer: number } | { dot: number } | { key: string }

/** A stretch of a line of the ask a tap lands on, from its first column up to `to`, and what it lands on there. */
type TapSpan = { from: number; to: number; tap: AsksTap }

/** Where an answer's words start: past its number and a space. */
export const ANSWER = NAME + 2

const TAG = ' · Recommended'

const SHOWN_DOT = '━━'

const OTHER_DOT = '━'

const FOLDED: AsksLine = { part: 'folded' }

const IGNORE: Hint = ['x', 'Ignore']

const SNOOZE: Hint = ['z', 'Snooze']

const OPEN: Hint = ['o', 'Open']

export const UNDO: Hint = ['u', 'undo']

/** The check at a held answer's first line's right. */
export const CHECK = '✓'

/** The cells a held answer's first line leaves its check: the check, and a space before it. */
const CHECK_ROOM = 1 + widthOf(CHECK)

/** The spaces either side of the sending line's ring. */
const RING_GAP = 2

/** The cells a hint takes: its key, a space, and its word. */
const hintWidth = ([key, word]: Hint) => widthOf(key) + 1 + widthOf(word)

/** The cells hints take, two between each two. */
export const hintsWidth = (hints: readonly Hint[]) => hints.reduce((sum, hint, at) => sum + (at === 0 ? 0 : 2) + hintWidth(hint), 0)

/** Each hint with the column it starts at, from `x`, two spaces between each two. */
export const hintColumns = (hints: readonly Hint[], x: number): { hint: Hint; x: number }[] =>
  hints.reduce<{ hint: Hint; x: number }[]>((placed, hint) => {
    const last = placed.at(-1)

    return [...placed, { hint, x: last === undefined ? x : last.x + hintWidth(last.hint) + 2 }]
  }, [])

/** Each hint's cells, the hints laid from `from`, a tap there acting as its key; none between them. */
const hintSpans = (hints: readonly Hint[], from: number): TapSpan[] =>
  hintColumns(hints, from).map(({ hint, x }) => ({ from: x, to: x + hintWidth(hint), tap: { key: hint[0] } }))

/** The answer sending, where it is the ask shown's. */
const sendingOn = (view: PanelView, row: PanelRow, ask: PanelAsk): Pick<Asking, 'sending'> => {
  const { sending } = view

  if (sending?.row !== rowKey(row) || sending.ask !== ask.id) {
    return {}
  }

  return { sending: { ring: sending.ring, ...(sending.answer === undefined ? {} : { answer: sending.answer }) } }
}

/** The asks open under the row, where the view has them open under it. */
export const askingIn = (view: PanelView, row: PanelRow): Asking | undefined => {
  const asks = row.answerable ?? []
  const ask = view.asking === undefined ? undefined : asks[view.asking.at]

  return view.asking === undefined || ask === undefined || rowKey(row) !== view.asking.row
    ? undefined
    : {
        row,
        asks,
        ask,
        at: view.asking.at,
        offersSnooze: view.asking.offersSnooze,
        hasMenu: view.menu?.row === rowKey(row),
        ...sendingOn(view, row, ask),
      }
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

/** Runs cut to `cells`, the one that runs past them cut with `…`, those after it dropped. */
const cutRuns = (runs: readonly Tagged<AnswerTag>[], cells: number): Tagged<AnswerTag>[] =>
  runs.reduce<{ kept: Tagged<AnswerTag>[]; room: number }>(
    ({ kept, room }, run) => (room <= 0 ? { kept, room } : { kept: [...kept, { ...run, text: cut(run.text, room) }], room: room - widthOf(run.text) }),
    { kept: [], room: cells },
  ).kept

/** The lines of the answer at `index`; held, its first cut where it would reach the check, so it keeps the lines it had. */
const answerLines = (words: string, isPick: boolean, index: number, cells: number, isHeld: boolean): AsksLine[] =>
  answerRuns(words, isPick, cells).map((runs, line) => ({
    part: 'answer',
    index,
    isFirst: line === 0,
    isHeld,
    runs: isHeld && line === 0 ? cutRuns(runs, cells - CHECK_ROOM) : runs,
  }))

/** Where the sending line's parts start: the answer's words, the ring, and `u undo`. */
export const sendingColumns = ({ lead, words, ring }: SendingLine) => {
  const after = NAME + widthOf(lead) + (words === '' ? 0 : 1 + widthOf(words))

  return { words: NAME + widthOf(lead) + 1, ring: after + RING_GAP, undo: after + RING_GAP + widthOf(ring) + RING_GAP }
}

/** The sending line at the layout's width: `Sending` and the answer's words, cut to leave the ring and `u undo` whole; or `Ignoring`. */
const sendingLine = ({ answer, ring }: ShownSending, width: number): SendingLine => {
  const lead = answer === undefined ? 'Ignoring' : 'Sending'
  const room = width - 1 - NAME - widthOf(lead) - 1 - (RING_GAP + widthOf(ring) + RING_GAP + hintWidth(UNDO))

  return { part: 'sending', lead, words: answer === undefined ? '' : cut(answer.words, room), ring }
}

/** What stands in the foot's place: nothing while the ask's snooze menu takes it; the sending line while the ask shown sends; else the foot. */
const footLineOf = ({ hasMenu, sending, offersSnooze }: Asking, width: number): AsksLine | undefined => {
  if (hasMenu) {
    return undefined
  }

  return sending === undefined ? { part: 'foot', hints: footOf(offersSnooze, width - 1 - NAME) } : sendingLine(sending, width)
}

/** Every line the opened row can show, in its parts, at the layout's width, in its section's lane. */
const partsOf = (asking: Asking, width: number, lane: Lane) => {
  const { row, ask, sending } = asking
  const cells = width - 1 - NAME
  const asked = askedOf(ask.age)
  const dots = dotsOf(asking, width - 1)
  const isRoomForDots = (dots[0]?.x ?? width) - 1 - NAME >= widthOf(asked)
  const heldAt = sending?.answer === undefined ? -1 : ask.sends.indexOf(sending.answer.sends)

  return {
    head: [
      ...nameLines(row, cells - Math.max(lane.cells, 1) - 2, cells).map((words): AsksLine => ({ part: 'head', words })),
      ...wrapTagged(wordsOf(row.project, 'meta' as const), cells, cells).map((words): AsksLine => ({ part: 'project', words })),
    ],
    title: wrap(ask.title, cells).map((text): AsksLine => ({ part: 'title', text })),
    titleFirst: { part: 'title', text: wrapIn(ask.title, cells, 1)[0] ?? '' } satisfies AsksLine,
    asked: { part: 'asked', text: asked, dots: isRoomForDots ? dots : [] } satisfies AsksLine,
    answers: ask.answers.map((words, index) =>
      answerLines(words, index === 0 && ask.pick !== undefined, index, width - 1 - ANSWER, index === heldAt),
    ),
    foot: footLineOf(asking, width),
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
  ...(stage.hasFoot && parts.foot !== undefined ? [parts.foot] : []),
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

/**
 * Where a tap on a line of the ask lands: on an answer anywhere on its
 * lines; on a page dot's ask on the dot's cells and the space before it; on
 * a hint, as its key, on its key and its word, `u undo` on the sending line
 * among them; nowhere else.
 */
const tapsOn = (line: AsksLine): TapSpan[] => {
  switch (line.part) {
    case 'answer':
      return [{ from: 0, to: Number.POSITIVE_INFINITY, tap: { answer: line.index } }]
    case 'asked':
      return line.dots.map((dot, at) => ({ from: dot.x - (at === 0 ? 0 : 1), to: dot.x + widthOf(dot.text), tap: { dot: at } }))
    case 'foot':
      return hintSpans(line.hints, NAME)
    case 'sending':
      return hintSpans([UNDO], sendingColumns(line).undo)
    default:
      return []
  }
}

/** What a tap at column `x` on a line of the ask lands on, if anything. */
export const tapOn = (line: AsksLine, x: number): AsksTap | undefined => tapsOn(line).find(span => x >= span.from && x < span.to)?.tap

/** Whether the lines draw the answer at `index`: its first line among them, its number with it. */
export const isAnswerDrawn = (lines: readonly AsksLine[], index: number) =>
  lines.some(line => line.part === 'answer' && line.index === index && line.isFirst)
