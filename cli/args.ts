/**
 * A command's words read as the fields core's checks take: its arguments in
 * order, the last taking every word left so a title needs no quotes, and
 * its flags, `--name value` or `--name=value`, a list's flag given once for
 * each line. `--` ends the flags. Whether the fields will do is for the
 * checks to say; this says only whether the words read.
 */
import type { Checked } from '../core'

/** An argument, by the field a check reads it as, and the switch given in its place, if one may be. */
export type Arg = { field: string; about: string; or?: string }

/**
 * A flag: the field a check reads it as, and its form: one value, a value
 * each time it is given (a list), or a switch, there or not. One the check
 * needs is `isNeeded`, for the help to say so.
 */
export type Flag = { field: string; about: string; isNeeded?: true } & (
  { form: 'switch' } | { form: 'one' | 'many'; value: string }
)

export type Grammar = {
  /** In order; the last takes every word left. */
  args: readonly Arg[]
  /** By name, without the dashes. */
  flags: Readonly<Record<string, Flag>>
}

/** What a command's words came to, by field: a text, a list of texts, or a switch that is on. */
export type Fields = { [field: string]: string | string[] | true }

const ENDS_FLAGS = '--'

const HELP = ['--help', '-h']

/** A flag is two dashes and a name; a lone dash, or one before a number, is a word. */
const isFlag = (word: string) => word.startsWith('--') && word.length > 2

/** The words before `--`: the only ones that can be flags. */
const flagsPart = (words: readonly string[]) => {
  const end = words.indexOf(ENDS_FLAGS)

  return end === -1 ? words : words.slice(0, end)
}

/** Whether the words ask for help, wherever among the flags they do. */
export const wantsHelp = (words: readonly string[]) =>
  flagsPart(words).some(word => HELP.includes(word))

/** `--name=value` as its name and value; `--name` as its name alone. */
const split = (word: string): [name: string, value?: string] => {
  const at = word.indexOf('=')

  return at === -1 ? [word.slice(2)] : [word.slice(2, at), word.slice(at + 1)]
}

/** Puts a flag's value in its field: a list's grows, any other is given once. Why not, if not. */
const give = (fields: Fields, name: string, flag: Flag, value: string) => {
  const had = fields[flag.field]

  if (flag.form === 'many') {
    fields[flag.field] = [...(Array.isArray(had) ? had : []), value]

    return undefined
  }

  if (had !== undefined) {
    return `Give --${name} once.`
  }

  fields[flag.field] = value

  return undefined
}

/** Reads one flag into the fields, its value from its own word or the next. Why not, if not. */
const take = (grammar: Grammar, word: string, queue: string[], fields: Fields) => {
  const [name, inline] = split(word)
  const flag = Object.hasOwn(grammar.flags, name) ? grammar.flags[name] : undefined

  if (flag === undefined) {
    return `There is no --${name}.`
  }

  if (flag.form === 'switch') {
    fields[flag.field] = true

    return inline === undefined ? undefined : `--${name} takes no value.`
  }

  const value = inline ?? queue.shift()

  return value === undefined
    ? `--${name} needs a value: ${flag.value}.`
    : give(fields, name, flag, value)
}

/** Puts the words that are not flags in the arguments' fields, the last taking every word left. */
const placed = (grammar: Grammar, words: readonly string[], fields: Fields): Checked<Fields> => {
  const { args } = grammar

  if (args.length === 0 && words.length > 0) {
    const takes = Object.keys(grammar.flags).length === 0 ? 'nothing' : 'flags only'

    return { ok: false, error: `It takes ${takes}, not "${words.join(' ')}".` }
  }

  args.forEach((arg, i) => {
    const taken = i === args.length - 1 ? words.slice(i) : words.slice(i, i + 1)

    if (taken.length > 0) {
      fields[arg.field] = taken.join(' ')
    }
  })

  return { ok: true, value: fields }
}

/** A command's words as fields, by its grammar; a refusal says which word will not read. */
export const parseWords = (grammar: Grammar, words: readonly string[]): Checked<Fields> => {
  const queue = [...words]
  const loose: string[] = []
  const fields: Fields = {}

  for (let word = queue.shift(); word !== undefined; word = queue.shift()) {
    if (word === ENDS_FLAGS) {
      loose.push(...queue.splice(0))
    } else if (!isFlag(word)) {
      loose.push(word)
    } else {
      const error = take(grammar, word, queue, fields)

      if (error !== undefined) {
        return { ok: false, error }
      }
    }
  }

  return placed(grammar, loose, fields)
}
