/**
 * Resume commands made at random, seeded, so each run makes the same:
 * plain ones, built from the parts of the shell syntax the panel's reader
 * takes (cli/panel/command.ts), and ones holding a single part it refuses,
 * put in as a word of its own or inside double quotes. The suite holds the
 * reader to them, and a run outside it fills each one the reader takes
 * with hostile values and runs it in every shell.
 *
 * A plain command names `{claude}`, `{dir}` and `{tty}` only outside
 * quotes, so each is a placeholder wherever its text stands. Its words
 * are never a builtin that evaluates an argument, as `[ x -eq y ]` is: a
 * command passing a value to one is the user's own risk.
 */

/** A command made, and whether it holds plain syntax alone. */
export type Made = { command: string; isPlain: boolean }

/** A seeded generator of numbers in [0, 1) (mulberry32). */
export const randomOf = (seed: number) => {
  let state = seed | 0

  return () => {
    state = (state + 0x6d2b79f5) | 0

    let mixed = Math.imul(state ^ (state >>> 15), 1 | state)

    mixed = (mixed + Math.imul(mixed ^ (mixed >>> 7), 61 | mixed)) ^ mixed

    return ((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296
  }
}

const PLACEHOLDERS = ['{claude}', '{dir}', '{tty}']

const NAMES = ['echo', 'true', 'cd', 'cat', 'ls', ':']

const FLAGS = ['-n', '-z', '-d', '-f', '--', '--resume', '-p', '-s']

/** Plain characters to make a word of, never a `-` first, so never a flag but those above. */
const PLAIN = [...'abcex019_./:@%+,=']
const TRAILING = ['-', '=', ':', '/']

/** What single quotes hold here: anything but `'`, braces that name no placeholder among it. */
const SINGLE = [' ', 'x', '"', '\\', '`', '$', '$(', ')', '(', '}', '{', '{print $1}', '#', '!', '[', ';', '&', '|', '*', 'é', '\\t']

/** What double quotes hold here as text: what prints, but `"`, `\`, `$`, a backtick and `!`. */
const DOUBLE = [' ', 'x', "'", '(', ')', ';', '&', '|', '<', '>', '*', '?', '#', '~', '[', ']', '}', '{', '{x}', '%', '^', 'é', ',']

/** Parameters, one outside braces always ended by a character every shell ends it at. */
const PARAMETERS = ['$x/', '$s-', '${x}', '${x}:', '$HOME/', '$?=', '$$-', '$1,', '$_x9@', '$x$s+', '$1%']

/** What follows a `\` outside quotes: a blank never last, as the spaces around a command are trimmed. */
const ESCAPED = [' x', ...'\'"`$(){};&|<>*?#![]~\\^x']

const OPERATORS = [' | ', ' || ', ' && ', '; ', ';', '|', ' ; ']

const REDIRECTIONS = ['>', '>>', '<', '2>', '1>', '0<', '> ', '>> ', '< ', '2> ']

const DUPLICATIONS = ['2>&1', '>&2', '1>&2', '<&0', '3>&1']

/** Parts refused wherever they stand outside quotes, each a word of its own. */
const REFUSED = [
  '(',
  ')',
  'a(b',
  '`',
  '`x`',
  '{',
  '}',
  '{a,b}',
  '{ x; }',
  '!',
  '!x',
  '*',
  'x?',
  '#',
  '#x',
  '&',
  'x&',
  '<<x',
  '<<<x',
  '<(x)',
  '>(x)',
  '=(x)',
  '$((1))',
  '$(( {dir} ))',
  '$( (x) )',
  '${x:-y}',
  '${x:{dir}}',
  '${#x}',
  '${x[1]}',
  '${!x}',
  '${{dir}}',
  '${ x; }',
  '${| x; }',
  '$\'x\'',
  "$$'x'",
  '$${dir}',
  '$"x"',
  '$!',
  '$0',
  '$@',
  '$*',
  '$-',
  '$#',
  '$#$( [ {dir} ] )',
  '$x:h',
  '$x:F:{dir}:h',
  '$?:F:1:',
  '$1:t',
  '$10:F:{dir}:h',
  '$x.y',
  '$x{dir}',
  "$x'a'",
  '"$xé"',
  '$[1]',
  '$',
  'a[1]',
  'a[{dir}]=1',
  'x]',
  '[[',
  ']]',
  '>&x',
  '>&-',
  '>& 1',
  '>&{dir}',
  '2>&{dir}',
  '>&12',
  '>|x',
  '<>x',
  '&>x',
  '^x',
  'a~b',
  'é',
  '{session}',
  '{x}',
  '"{dir}"',
  "'{claude}'",
  '"a{tty}b"',
  'x=(a)',
  '$(echo "$(x)")',
  '$(case x in a) echo;; esac)',
]

/** Parts refused inside double quotes, put between two letters there. */
const REFUSED_DOUBLE = ['`', '!', '$x[1]', '$(x)', '$((1))', '\\\\', '\\n', '\\`', '${x:-y}', '${#x}', "$'", '$!', '$@', '$0', '$#', '$x:h', '$?:F:1:', '{dir}', '{claude}', '$']

/** A maker of commands, drawing on the numbers given. */
const makerOf = (random: () => number) => {
  const pick = <T>(things: readonly T[]): T => things[Math.floor(random() * things.length)] as T
  const chance = (odds: number) => random() < odds
  let depth = 0

  const plain = () => Array.from({ length: 1 + Math.floor(random() * 3) }, () => pick(PLAIN)).join('') + (chance(0.2) ? pick(TRAILING) : '')

  const single = () => `'${Array.from({ length: Math.floor(random() * 3) }, () => pick(SINGLE)).join('')}'`

  const double = () =>
    `"${Array.from({ length: Math.floor(random() * 3) }, () =>
      pick([() => pick(DOUBLE), () => pick(PARAMETERS), () => pick(['\\"', '\\$'])])(),
    ).join('')}"`

  const substitution = (): string => {
    if (depth > 2) {
      return '$(echo x)'
    }

    depth += 1

    const inside = chance(0.1) ? pick(['', ' ']) : ` ${list()} `.slice(chance(0.5) ? 1 : 0, chance(0.5) ? -1 : undefined)

    depth -= 1

    return `$(${inside})`
  }

  const part = (): string =>
    pick([
      plain,
      plain,
      () => pick(PLACEHOLDERS),
      () => pick(PLACEHOLDERS),
      single,
      double,
      () => pick(PARAMETERS),
      () => `\\${pick(ESCAPED)}`,
      substitution,
    ])()

  /** A word: parts joined, a `~` first or not where it may start one. */
  const word = (mayTilde = true) => (mayTilde && chance(0.1) ? '~' : '') + Array.from({ length: 1 + Math.floor(random() * 3) }, part).join('')

  const redirection = () => (chance(0.3) ? pick(DUPLICATIONS) : `${pick(REDIRECTIONS)}${word()}`)

  const argument = () => pick([() => word(), () => word(), () => word(), () => pick(FLAGS), redirection])()

  /** A simple command, the word given among its arguments, if any. */
  const command = (extra?: string): string => {
    const head = pick([() => pick(NAMES), () => `x=${word(false)}`, () => `s=${substitution()}`, () => pick(PLACEHOLDERS), () => '['])()
    const rest = Array.from({ length: Math.floor(random() * 4) }, argument)
    const at = Math.floor(random() * (rest.length + 1))
    const given = extra === undefined ? rest : [...rest.slice(0, at), extra, ...rest.slice(at)]

    return [head, ...given, ...(head === '[' ? [']'] : [])].join(' ')
  }

  /** Commands joined by operators, the word given among the arguments of one, if any. */
  const list = (extra?: string): string => {
    const count = 1 + Math.floor(random() * 3)
    const holding = Math.floor(random() * count)
    const commands = Array.from({ length: count }, (_, at) => command(at === holding ? extra : undefined))

    return commands.reduce((sofar, each) => `${sofar}${pick(OPERATORS)}${each}`)
  }

  /** A command with a refused part put in as a word, or inside double quotes, at the top level or in a `$(…)`. */
  const refused = () => {
    const part = chance(0.75) ? pick(REFUSED) : `"a${pick(REFUSED_DOUBLE)} b"`

    return list(chance(0.3) ? `$(echo ${part})` : part)
  }

  return { list, refused }
}

/** As many commands as asked, made from the seed: plain ones, and as often ones holding a part refused. */
export const commandsOf = (count: number, seed: number): Made[] => {
  const maker = makerOf(randomOf(seed))

  return Array.from({ length: count }, (_, at) => (at % 2 === 0 ? { command: maker.list(), isPlain: true } : { command: maker.refused(), isPlain: false }))
}
