/**
 * Makes tests/reader-cases.ts, the commands both readers of the resume
 * command are held to, each with what the panel's reader gives it:
 *
 *     bun tests/make-reader-cases.ts > tests/reader-cases.ts
 *
 * Run it again after any change to the rules, read the difference, and
 * bring the app's `TypedCommand` to the same. The commands come from the
 * seeded generator (tests/commands.ts), plain ones and ones holding a part
 * refused, more than half then mutated by a few shell characters put in or
 * taken out, so the cases reach the edges of each rule; the first 2,000 of
 * 80 characters or fewer are kept.
 */
import { lineOf, type ResumeFacts } from '../cli/panel/command'
import { commandsOf, randomOf } from './commands'

/** Bun's, which the engine's types, read for the tests, leave out. */
declare const console: { log(text: string): void }

const COUNT = 2_000

const SEED = 20_261_121

/** The longest command kept, so each case turns on a few rules, and the file stays small enough to read. */
const LONGEST = 80

/** What a mutation puts in: shell characters, and the parts the rules turn on. */
const MUTATIONS = [
  '"', "'", '`', '$', '(', ')', '{', '}', '[', ']', '\\', ';', '#', ':', ' ', '$(', '${', "$'", '&', '|', '<', '>',
  '!', '*', '?', '~', '=', '^', '%', '$((', '2>&', '{dir}', '"{dir}"', '{x}', '$$', '$?', '$1', 'é', '́', '\t',
  '.', '@', ',', '+', '-', '/', '0', '1', 'a', '_', '=~', ':~',
]

const NAME = 'Help desk redesign'

const FACTS: ResumeFacts = {
  claude: 'b1c2d3e4-0000-4000-8000-0000000000aa',
  dir: '/Users/me/Code/Northwind\'s "notes" $(x) `y`',
  tty: '/dev/ttys004',
  isHeld: false,
}

const random = randomOf(SEED ^ 0xd1ff)

const pick = <T>(things: readonly T[]): T => things[Math.floor(random() * things.length)] as T

/** The command with one to four characters or parts put in, or characters taken out, at random places. */
const mutated = (command: string) => {
  let text = command

  for (let step = 0, steps = 1 + Math.floor(random() * 4); step < steps; step++) {
    const at = Math.floor(random() * (text.length + 1))

    text = random() < 0.7 ? text.slice(0, at) + pick(MUTATIONS) + text.slice(at) : text.slice(0, at) + text.slice(at + 1)
  }

  return text
}

const rows = commandsOf(COUNT * 10, SEED)
  .map(({ command }) => (random() < 0.6 ? mutated(command) : command))
  .filter(command => command.length <= LONGEST)
  .slice(0, COUNT)
  .map(command => {
    const line = lineOf(command, FACTS, NAME)

    return line.ok ? { command, line: line.value } : { command, refusal: line.error }
  })

console.log(`/**
 * The commands both readers of the resume command are held to, the panel's
 * (tests/panel-command.test.ts) and the app's (TypedCommandTests.swift),
 * each with what the panel's reader gave it, filled with the facts here:
 * its line, or its refusal. Made, and made again after any change to the
 * rules, by:
 *
 *     bun tests/make-reader-cases.ts > tests/reader-cases.ts
 *
 * The Swift tests read this file as JSON from the \`= {\` that ends a line,
 * so nothing but the object follows.
 */
import type { ResumeFacts } from '../cli/panel/command'

export type ReaderCase = { command: string; line: string } | { command: string; refusal: string }

export const READER_CASES: { name: string; facts: ResumeFacts; rows: readonly ReaderCase[] } = {
  "name": ${JSON.stringify(NAME)},
  "facts": ${JSON.stringify(FACTS)},
  "rows": [
${rows.map(row => `    ${JSON.stringify(row)}`).join(',\n')}
  ]
}`)
