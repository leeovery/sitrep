/**
 * The CLI's help, drawn from the commands' own grammar so it never drifts
 * from what they take: every command's usage in brief, and one command's
 * words in full.
 */
import type { Arg, Flag, Grammar } from './args'
import { COMMANDS, SESSION_FLAG, type Command } from './commands'

const GAP = 2

const flagWord = (name: string, flag: Flag) =>
  flag.form === 'switch' ? `--${name}` : `--${name} ${flag.value}`

const flagUsage = ([name, flag]: [string, Flag]) => {
  const word = flagWord(name, flag)

  return `${flag.isNeeded ? word : `[${word}]`}${flag.form === 'many' ? '...' : ''}`
}

/** An argument as its usage gives it: itself, one or more of it, or it or the flag given in its place, with its value. */
const argUsage = ({ field, or, isMany }: Arg, flags: Grammar['flags']) => {
  const word = `<${field}>${isMany ? '...' : ''}`

  if (or === undefined) {
    return word
  }

  const instead = flags[or]

  return `(${word} | ${instead === undefined ? `--${or}` : flagWord(or, instead)})`
}

/** A command's usage line, each flag an argument may stand in for beside it; in the brief, without the flag every command on a session takes. */
const usageOf = ({ name, grammar }: Command, isBrief = false) => {
  const besideArgs = grammar.args.flatMap(arg => (arg.or === undefined ? [] : [arg.or]))

  return [
    `sitrep ${name}`,
    ...grammar.args.map(arg => argUsage(arg, grammar.flags)),
    ...Object.entries(grammar.flags)
      .filter(([flag]) => !besideArgs.includes(flag) && (!isBrief || flag !== SESSION_FLAG))
      .map(flagUsage),
  ].join(' ')
}

/** Rows of a word and what it is, the words padded to one column. */
const table = (rows: readonly [word: string, about: string][]) => {
  const width = Math.max(...rows.map(([word]) => word.length)) + GAP

  return rows.map(([word, about]) => `  ${word.padEnd(width)}${about}`)
}

export const HELP = [
  'sitrep: post to the sitrep board from scripts and other tools.',
  '',
  '  sitrep [--no-notify]  opens the board in this terminal',
  ...COMMANDS.map(command => `  ${usageOf(command, true)}`),
  '',
  'A command on a session names it: --session sr-xxxxxx, else $SITREP_SESSION.',
  "A post prints its item's id. Exit codes: 0 done; 1 a usage error, a refused",
  'input or a failure; 2 no such session.',
  '',
  'sitrep <command> --help says more.',
].join('\n')

/** One command's help: its usage, what it does, and each of its words, where it takes any. */
export const commandHelp = (command: Command) => {
  const words = [
    ...command.grammar.args.map((arg): [string, string] => [`<${arg.field}>`, arg.about]),
    ...Object.entries(command.grammar.flags).map(([name, flag]): [string, string] => [
      flagWord(name, flag),
      flag.about,
    ]),
  ]

  return [
    `Usage: ${usageOf(command)}`,
    '',
    command.about,
    ...(words.length === 0 ? [] : ['', ...table(words)]),
  ].join('\n')
}
