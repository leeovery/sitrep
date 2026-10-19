/**
 * The CLI's help, drawn from the commands' own grammar so it never drifts
 * from what they take: every command's usage in brief, and one command's
 * words in full.
 */
import type { Flag } from './args'
import { COMMANDS, SESSION_FLAG, type Command } from './commands'

const GAP = 2

const flagWord = (name: string, flag: Flag) =>
  flag.form === 'switch' ? `--${name}` : `--${name} ${flag.value}`

const flagUsage = ([name, flag]: [string, Flag]) => {
  const word = flagWord(name, flag)

  return `${flag.isNeeded ? word : `[${word}]`}${flag.form === 'many' ? '...' : ''}`
}

/** A command's usage line; in the brief, without the flag every command on a session takes. */
const usageOf = ({ name, grammar }: Command, isBrief = false) =>
  [
    `sitrep ${name}`,
    ...grammar.args.map(arg => `<${arg.field}>`),
    ...Object.entries(grammar.flags)
      .filter(([flag]) => !isBrief || flag !== SESSION_FLAG)
      .map(flagUsage),
  ].join(' ')

/** Rows of a word and what it is, the words padded to one column. */
const table = (rows: readonly [word: string, about: string][]) => {
  const width = Math.max(...rows.map(([word]) => word.length)) + GAP

  return rows.map(([word, about]) => `  ${word.padEnd(width)}${about}`)
}

export const HELP = [
  'sitrep: post to the sitrep board from scripts and other tools.',
  '',
  ...COMMANDS.map(command => `  ${usageOf(command, true)}`),
  '',
  'A command on a session names it: --session sr-xxxxxx, else $SITREP_SESSION.',
  "A post prints its item's id. Exit codes: 0 done; 1 a usage error, a refused",
  'input or a failure; 2 no such session.',
  'Answering an ask from here: not yet. Answer it on the board.',
  '',
  'sitrep <command> --help says more.',
].join('\n')

/** One command's help: its usage, what it does, and each of its words. */
export const commandHelp = (command: Command) =>
  [
    `Usage: ${usageOf(command)}`,
    '',
    command.about,
    '',
    ...table([
      ...command.grammar.args.map((arg): [string, string] => [`<${arg.field}>`, arg.about]),
      ...Object.entries(command.grammar.flags).map(([name, flag]): [string, string] => [
        flagWord(name, flag),
        flag.about,
      ]),
    ]),
  ].join('\n')
