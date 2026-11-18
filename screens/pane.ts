/**
 * The README's screens of the board in Claude Code (app/screens), each an
 * SVG of the board docked as the mod draws it, with no engine beneath
 * (tests/render.ts), from a made-up desk filed as the tests file theirs:
 * this session at home, an ask opened, and a project's view. Run on Bun
 * from the repository's root, `bun screens/pane.ts <folder>`, which writes
 * them into the folder.
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
  PROJECT,
  REVIEW,
  SHIFTS,
  T0,
  W3,
} from '../tests/data'
import { askOf, park, resolve, status, yesAsk, type Line } from '../tests/lines'
import { pane, sceneFrom, type Desk } from '../tests/render'
import { DOCKED } from '../tests/world/panes'
import { cellsOf, charsOf } from './cells'
import { svgOf } from './svg'

declare const Bun: {
  readonly argv: readonly string[]
  write(path: string, text: string): Promise<number>
}

/** The board docked as Claude Code measured it beside a terminal, with rows enough for all it shows. */
const PROPS: RenderPropsOf['Pane'] = { ...DOCKED, scroll: { offset: 0, bodyRows: 60 } }

/** A session of Fabrikam's, which names itself in its project's file. */
const SUPPLIERS = meta('sr-5upp1y', 'Supplier portal', W3, { project: 'fabrikam' })

/** An ask Claude closed itself. */
const closed = (id: string, title: string): Line[] => [
  [T0, yesAsk(id, title, 'Done')],
  [T0 + MIN, resolve(id, 'Done in the chat')],
]

/** Help desk redesign, held here: a choice and a review asked, its status, two items parked and an ask closed; beside it the ledger, the rota and the supplier portal. */
const DESK: Desk = {
  lines: [
    ...closed('k0', 'Approve the colour palette'),
    [T0 + 2 * MIN, park('p1', 'Saved replies for common tickets')],
    [T0 + 3 * MIN, park('p2', 'Keyboard shortcuts in the inbox')],
    [
      T0 + 20 * MIN,
      status(['Drawing the Replies page'], {
        name: HELD.name,
        summary: 'Redesign the help desk, page by page',
        next: 'Tickets, round 2',
      }),
    ],
    [T0 + 26 * MIN, askOf('k2', REVIEW)],
    [
      T0 + 34 * MIN,
      askOf('k1', {
        wants: 'choice',
        title: 'Which editor should replies use?',
        where: 'In Paper: the help desk file, page "Replies"',
        options: ['Rich text', 'Markdown', 'Plain text'],
        recommended: 'Markdown',
      }),
    ],
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
}

/** Each screen: its file, its accessible name, and where the board stands. */
const SCREENS: readonly { name: string; label: string; desk: Desk }[] = [
  {
    name: 'pane-home',
    label:
      "The board in Claude Code: this session's two asks, a choice opened with Markdown recommended, its status and what it parked",
    desk: { ...DESK, pane: { selected: heldItem('k1') } },
  },
  {
    name: 'pane-project',
    label:
      "The board in Claude Code: Northwind's view, its sessions, their asks and what they parked",
    desk: { ...DESK, pane: { place: { level: 'project', project: PROJECT.key } } },
  },
]

/** The rows the board draws, down to one blank row past the last it fills. */
const shown = (rows: ReturnType<typeof cellsOf>) => {
  const last = rows.findLastIndex(row => charsOf(row).trim() !== '')

  return rows.slice(0, last + 2)
}

const folder = Bun.argv[2]

if (folder === undefined) {
  throw new Error('Usage: bun screens/pane.ts <folder>')
}

for (const { name, label, desk } of SCREENS) {
  const drawn = (await pane(sceneFrom(desk), PROPS).drawn()) as unknown as Element

  // Started anywhere else, Bun compiles the board's JSX for React, not for `h`.
  if (typeof drawn.type !== 'string') {
    throw new Error('The board drew no elements: run it from the repository root')
  }

  const rows = shown(cellsOf(drawn, PROPS.bodyColumns))

  await Bun.write(`${folder}/${name}.svg`, svgOf(rows, 'sitrep', label))
}
