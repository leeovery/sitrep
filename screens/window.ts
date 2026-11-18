/**
 * The README's picture of Claude Code (app/screens), as cells: the board and
 * the band drawn by the mod (board.ts) in Claude Code's screen (claude.ts),
 * painted as Ghostty paints them (ghostty.ts), written as JSON for the app's
 * tests to draw as a Ghostty window. Run on Bun from the repository's root,
 * `bun screens/window.ts <file>`.
 */
import { bandCells, boardCells } from './board'
import { BOARD_COLUMNS, claudeScreen, TALK_COLUMNS } from './claude'
import { terminalOf } from './ghostty'

declare const Bun: {
  readonly argv: readonly string[]
  write(path: string, text: string): Promise<number>
}

const file = Bun.argv[2]

if (file === undefined) {
  throw new Error('Usage: bun screens/window.ts <file>')
}

const screen = claudeScreen(await boardCells(BOARD_COLUMNS), (await bandCells(TALK_COLUMNS))[0] ?? [])

await Bun.write(file, `${JSON.stringify(terminalOf(screen))}\n`)
