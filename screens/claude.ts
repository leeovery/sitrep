/**
 * Claude Code's screen round the board, for the README's picture of a
 * Ghostty window: a made-up session of Northwind's, drawn as Claude Code's
 * dark theme draws one, its colours read from Claude Code's own build. The
 * board docks at the right, beyond a rule, under its ✕, with the
 * conversation on its left ending on the band; under both the prompt with
 * its cursor, Lee's status line, the mode line and the background agents.
 * Only the board and the band are the mod's own drawing (board.ts); the rest
 * is a mock of Claude Code, laid out in cells as the board is (cells.ts).
 */
import type { Element } from '../tests/matching'
import { cellsOf, type Cell, type Paint } from './cells'

/** Claude Code's dark theme, as its 2.1.327 build has it. */
export const THEME = {
  claude: '#d77757',
  success: '#4eba65',
  error: '#ff6b80',
  warning: '#ffc107',
  inactive: '#999999',
  subtle: '#505050',
  promptBorder: '#888888',
  userMessageBackground: '#373737',
} as const

/** Lee's status line's colours, a segment each: Nord's, as his Ghostty theme is. */
const STATUS = {
  folder: '#88c0d0',
  branch: '#a3be8c',
  label: '#d08770',
  account: '#b48ead',
  context: '#ebcb8b',
  model: '#81a1c1',
} as const

/** The terminal's columns, and how many of them the docked board takes at its right. */
export const COLUMNS = 124
export const BOARD_COLUMNS = 50

/** The conversation's columns: what the board leaves, less the rule and a column either side of it. */
export const TALK_COLUMNS = COLUMNS - BOARD_COLUMNS - 2

/** The terminal's cells, and where its cursor stands. */
export type Screen = { rows: Cell[][]; cursor: { row: number; column: number } }

type Props = Record<string, unknown>

type Node = Element | string

const element =
  (type: string) =>
  (props: Props, ...children: Node[]): Element => ({ type, props, children })

const box = element('Box')
const text = element('Text')

const column = (props: Props, ...children: Node[]) =>
  box({ flexDirection: 'column', ...props }, ...children)

/** Words that wrap, painted as `paint` says. */
const words = (paint: Props, ...children: Node[]) => text({ wrap: 'wrap', ...paint }, ...children)

const dim = (...children: Node[]) => words({ dimColor: true }, ...children)

/** A lead that never shrinks, and what follows it wrapping under itself. */
const hanging = (lead: Element, ...rest: Element[]) =>
  box({ flexDirection: 'row' }, box({ flexShrink: 0 }, lead), column({ flexGrow: 1 }, ...rest))

/** A tool's result under its `⎿`. */
const result = (...lines: Element[]) => hanging(dim('  ⎿  '), ...lines)

/** A tool call: its dot, in the colour of how it stands, and its words. */
const call = (dot: string, ...children: Node[]) =>
  hanging(text({ color: dot }, '● '), words({}, ...children))

/** A file a tool changed, and its lines added and taken out. */
const updated = (path: string, added: number, removed: number) =>
  result(
    words(
      {},
      'Updated ',
      text({ bold: true }, path),
      ' ',
      text({ color: THEME.success }, `+${added}`),
      ' ',
      text({ color: THEME.error }, `-${removed}`),
    ),
  )

/** The end of Claude's last message, Lee's answer from the board, Claude at work on it, and its spinner. */
const CONVERSATION = column(
  { rowGap: 1 },
  column(
    { paddingLeft: 2 },
    words(
      {},
      "Round 1 of the Replies page is in Paper. Once the editor is settled I'll switch the composer over and draw round 2:",
    ),
    hanging(words({}, '- '), words({}, 'The composer keeps a slim toolbar: bold, italic, link and code.')),
    hanging(words({}, '- '), words({}, 'Saved replies stay parked until the Tickets page is done.')),
  ),
  dim('✻ Waiting for 2 background agents to finish'),
  column(
    {},
    dim('› Prompt from the sitrep plugin'),
    box(
      { flexDirection: 'row', backgroundColor: THEME.userMessageBackground },
      box({ flexShrink: 0 }, words({}, '❯ ')),
      column(
        { flexGrow: 1 },
        words({}, 'From the board:'),
        words({}, '- Which editor should replies use? → Markdown'),
        words({}, '  This closes the ask: nothing more to do with it.'),
      ),
    ),
  ),
  column(
    {},
    call(
      THEME.success,
      text({ bold: true }, 'Bash'),
      '(git switch -c replies-markdown && npm run codemod -- --editor=markdown src/replies)',
    ),
    result(dim('[replies-markdown 4e1a9c2] Replies use the Markdown editor')),
    updated('src/replies/Composer.tsx', 3, 1),
    updated('src/replies/Toolbar.tsx', 12, 30),
    updated('src/replies/Preview.tsx', 8, 2),
    result(
      words({}, '… +4 files changed'),
      dim('src/replies/Reply.test.tsx, src/replies/Draft.ts, src/tickets/Thread.tsx, docs/replies.md'),
    ),
    result(dim('Allowed by auto mode')),
  ),
  column(
    {},
    call(THEME.inactive, 'Running the reply tests and the Storybook build', text({ dimColor: true }, ' · 48s')),
    result(
      words({}, '$ npm test -- src/replies && npm run storybook:build -- --quiet --output-dir dist/storybook'),
      dim('(ctrl+b to run in background)'),
    ),
  ),
  column(
    {},
    hanging(
      text({ color: THEME.claude }, '✻ '),
      words({ color: THEME.claude }, 'Percolating… ', text({ dimColor: true }, '(1m 12s · ↓ 2.4k tokens)')),
    ),
    result(
      dim(
        'Tip: Use Plan Mode to prepare for a complex request before making changes. Press shift+tab twice to enable.',
      ),
    ),
  ),
)

const blank = (count: number): Cell[] => Array.from({ length: count }, () => ({ char: ' ', paint: {} }))

/** Words in cells, each painted `paint`. */
const run = (words: string, paint: Paint = {}): Cell[] => [...words].map(char => ({ char, paint }))

/** Runs one after another, padded out to `width`. */
const line = (width: number, ...runs: Cell[][]) => {
  const cells = runs.flat()

  return [...cells, ...blank(width - cells.length)]
}

/** Runs set at the right of `width`. */
const right = (width: number, ...runs: Cell[][]) => {
  const cells = runs.flat()

  return [...blank(width - cells.length), ...cells]
}

const faint = (words: string) => run(words, { dim: true })

/** The prompt's rule, the session's folder named at its right. */
const promptRule = (label: string) => {
  const end = [...run(` ${label} `, { color: THEME.inactive }), ...run('─', { color: THEME.promptBorder })]

  return line(COLUMNS, run('─'.repeat(COLUMNS - end.length), { color: THEME.promptBorder }), end)
}

const SEPARATOR = faint(' · ')

/** Lee's status line: the folder, the branch, the session's label, the account, the context used and the model. */
const statusLine = () =>
  line(
    COLUMNS,
    run('  '),
    run(' northwind', { color: STATUS.folder }),
    SEPARATOR,
    run(' replies-markdown', { color: STATUS.branch }),
    SEPARATOR,
    run('help desk', { color: STATUS.label }),
    SEPARATOR,
    run(' me@example.com', { color: STATUS.account }),
    SEPARATOR,
    run('118k/400k', { color: STATUS.context }),
    SEPARATOR,
    run('Opus 5.5', { color: STATUS.model }),
  )

const modeLine = () =>
  line(
    COLUMNS,
    run('  '),
    run('⏵⏵ auto mode on', { color: THEME.warning }),
    faint(' (shift+tab to cycle) · esc to interrupt · ↓ to manage'),
  )

/** The background agents: the main thread, and each agent at its work, how long it has run and what it has read. */
const AGENTS = [
  ['reviewer', 'Checking the Replies page against the design', '4m 12s · ↓ 38.1k tokens'],
  ['test-writer', 'Writing tests for the Markdown preview', '2m 40s · ↓ 21.7k tokens'],
] as const

/** The agents' names' column. */
const NAMES = 14

const agentLines = () => [
  line(COLUMNS, run('  '), run('● main', { bold: true })),
  ...AGENTS.map(([name, doing, spent]) => [
    ...line(COLUMNS - spent.length - 2, run('  ○ '), line(NAMES, run(name)), faint(doing)),
    ...faint(spent),
    ...blank(2),
  ]),
]

/** The board's ✕, at the right of the row over it, inside the column the board keeps free. */
const closeRow = () => right(BOARD_COLUMNS, run('✕', { color: THEME.inactive }), blank(1))

/** `rows` of `width`, padded with blank rows at the top or the bottom to `height`, or cut from the top. */
const fitted = (rows: readonly Cell[][], width: number, height: number, at: 'top' | 'bottom') => {
  const kept = rows.slice(Math.max(0, rows.length - height))
  const pad = Array.from({ length: height - kept.length }, () => blank(width))

  return at === 'top' ? [...kept, ...pad] : [...pad, ...kept]
}

/**
 * The terminal: the board's rows at the right, under its ✕, and the band's
 * row at the conversation's foot, which is cut from its top to the board's
 * height; under both, the prompt, its cursor after the `❯`, and the lines
 * beneath it.
 */
export const claudeScreen = (board: readonly Cell[][], band: readonly Cell[]): Screen => {
  const height = board.length + 1
  const talk = fitted(
    [...cellsOf(CONVERSATION, TALK_COLUMNS), blank(TALK_COLUMNS), [...band]],
    TALK_COLUMNS,
    height,
    'bottom',
  )
  const docked = fitted([closeRow(), ...board], BOARD_COLUMNS, height, 'top')
  const rule = run('│', { color: THEME.subtle })
  const body = talk.map((row, i) => [...row, ...blank(1), ...rule, ...(docked[i] ?? [])])
  const prompt = [
    promptRule('northwind'),
    line(COLUMNS, run('❯ ')),
    line(COLUMNS, run('─'.repeat(COLUMNS), { color: THEME.promptBorder })),
  ]

  return {
    rows: [...body, ...prompt, statusLine(), modeLine(), blank(COLUMNS), ...agentLines()],
    cursor: { row: body.length + 1, column: 2 },
  }
}
