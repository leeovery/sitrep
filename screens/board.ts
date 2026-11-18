/**
 * The board and the band in the README's picture of Claude Code (app/screens),
 * each drawn by the mod with no engine beneath (tests/render.ts), from a
 * made-up desk filed as the tests file theirs: Help desk redesign at home,
 * its choice opened, Lee's answer to the one before it delivered. Run on Bun
 * from the repository's root, which compiles the board's JSX for `h`.
 */
import './jsx'
import type { Element } from '../tests/matching'
import type { RenderPropsOf } from 'claude-code'
import {
  ELSEWHERE,
  HELD,
  heldItem,
  LEDGER,
  meta,
  MIN,
  REVIEW,
  SHIFTS,
  T0,
  W3,
} from '../tests/data'
import {
  askOf,
  delivered,
  park,
  reply,
  resolve,
  status,
  yesAsk,
  type Line,
} from '../tests/lines'
import { band, pane, sceneFrom, type Desk, type Drawn } from '../tests/render'
import { DOCKED } from '../tests/world/panes'
import { cellsOf, charsOf, type Cell } from './cells'

/** A session of Fabrikam's, which names itself in its project's file. */
const SUPPLIERS = meta('sr-5upp1y', 'Supplier portal', W3, { project: 'fabrikam' })

/** The held session's status, as Claude sets it. */
const helpDesk = (now: string, next: string) =>
  status([now], { name: HELD.name, summary: 'Redesign the help desk, page by page', next })

/** An ask Claude closed itself. */
const closed = (id: string, title: string): Line[] => [
  [T0, yesAsk(id, title, 'Done')],
  [T0 + MIN, resolve(id, 'Done in the chat')],
]

/**
 * Help desk redesign, held here: the editor chosen from the board, Markdown,
 * and delivered; a choice and a review asked; two items parked and an ask
 * closed. Beside it the ledger, the rota and the supplier portal.
 */
const DESK: Desk = {
  lines: [
    ...closed('k0', 'Approve the colour palette'),
    [T0 + 2 * MIN, park('p1', 'Saved replies for common tickets')],
    [T0 + 3 * MIN, park('p2', 'Keyboard shortcuts in the inbox')],
    [
      T0 + 10 * MIN,
      askOf('k1', {
        wants: 'choice',
        title: 'Which editor should replies use?',
        where: 'In Paper: the help desk file, page "Replies"',
        options: ['Rich text', 'Markdown', 'Plain text'],
        recommended: 'Markdown',
      }),
    ],
    [T0 + 20 * MIN, helpDesk('Drawing the Replies page', 'Tickets, round 2')],
    [T0 + 26 * MIN, askOf('k2', REVIEW)],
    [
      T0 + 34 * MIN,
      askOf('k3', {
        wants: 'choice',
        title: 'Thread replies, or keep them flat?',
        options: ['Threaded', 'Flat'],
        recommended: 'Threaded',
      }),
    ],
    [T0 + 36 * MIN, reply('r1', 'k1', 'choose', { option: 'Markdown' })],
    [T0 + 37 * MIN, delivered('r1')],
    [T0 + 38 * MIN, helpDesk('Switching the reply editor to Markdown', 'Replies, round 2')],
  ],
  around: [
    {
      meta: LEDGER,
      lines: [
        [T0, park('p1', 'Export the ledger as CSV')],
        [T0 + 10 * MIN, status(['Matching payments to invoices'], LEDGER)],
        [T0 + 30 * MIN, yesAsk('k1', 'Review the ledger schema')],
      ],
      seenAt: T0 + 40 * MIN,
    },
    {
      meta: SHIFTS,
      project: ELSEWHERE.key,
      lines: [[T0 + 15 * MIN, yesAsk('k1', 'Approve the rota')]],
      seenAt: T0 + 40 * MIN,
    },
    {
      meta: SUPPLIERS,
      project: 'fabrikam',
      projectFile: { name: 'Fabrikam', created: T0, by: W3 },
      lines: [[T0 + 5 * MIN, status(['Importing the supplier list'], SUPPLIERS)]],
      seenAt: T0 + 40 * MIN,
    },
  ],
  now: T0 + 40 * MIN,
  pane: { selected: heldItem('k3') },
}

/** A drawing's elements, refused where Bun compiled the board's JSX for React rather than for `h`. */
const elementsOf = async (drawn: Drawn) => {
  const element = (await drawn.drawn()) as unknown as Element

  if (typeof element.type !== 'string') {
    throw new Error('The board drew no elements: run it from the repository root')
  }

  return element
}

/** The rows a drawing fills, cut after its last. */
const filled = (rows: Cell[][]) => rows.slice(0, rows.findLastIndex(row => charsOf(row).trim() !== '') + 1)

/** The board docked `columns` across, with rows enough for all it shows: the rows it fills. */
export const boardCells = async (columns: number) => {
  const props: RenderPropsOf['Pane'] = {
    ...DOCKED,
    bodyColumns: columns,
    scroll: { offset: 0, bodyRows: 60 },
  }

  return filled(cellsOf(await elementsOf(pane(sceneFrom(DESK), props)), columns))
}

/** The band above the prompt, `columns` across: its one row. */
export const bandCells = async (columns: number) =>
  cellsOf(await elementsOf(band(sceneFrom(DESK), columns)), columns)
