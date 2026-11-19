/**
 * The resume command, read, refused and filled as SitRep's `TypedCommand`
 * does it (app/Sources/SitRepScreen/TypedCommand.swift), in its words: no
 * terminal, no shell.
 *
 * - It is read as the shell reads it, far enough to find each placeholder
 *   and where it stands: each `{name}`, a name of ASCII letters and
 *   underscores, but none after an unescaped `$` or `#`, the shell's `${…}`
 *   and tmux's `#{…}`, nor one escaped, nor, inside quotes, one whose name
 *   is no placeholder's, as awk's `'{print}'`.
 * - A placeholder is filled only where no quote or backtick stands around
 *   it, however deep in `$(…)`, since its quoted value would end them
 *   early; and outside what the reader sees the shell evaluate as
 *   arithmetic, where a `$(…)` in a value runs even quoted: `$((…))`,
 *   `((…))`, `$[…]`, a subscript, and a `${…}`'s offset, `${x:…}`. Joined
 *   to unquoted text it is filled: `id={claude}` is `id='…'`, one word.
 * - What evaluates its arguments as code, `eval`, `let`, `[[ … -eq … ]]`,
 *   `declare -i`, zsh's `${(e)…}` or a glob qualifier `*(e:…:)`, the
 *   reader can't see: a command the user wrote that passes a placeholder
 *   to one takes that risk itself.
 * - Each value goes in single quotes, never bare.
 * - Refused before anything runs: none given; a character that doesn't
 *   print, in the command or in a value; a placeholder SitRep doesn't know;
 *   one evaluated; one in quotes or backticks; `{dir}`, where the window
 *   said no folder.
 * - It reads the command a code point at a time, as the Swift reads its
 *   scalars: a quote with a combining mark after it is still a quote, as
 *   the shell, reading bytes, takes it.
 */
import { inWords, type Checked } from '../../core'

/** The placeholders the resume command may name, in the order a refusal lists them. */
const PLACEHOLDERS = ['claude', 'dir', 'tty'] as const

type Placeholder = (typeof PLACEHOLDERS)[number]

/** The resume command where none is saved, as SitRep's `OpenSettings` holds it. */
export const DEFAULT_COMMAND = 'cd {dir} && claude --resume {claude}'

/**
 * What fills the resume command: the window's writer, the Claude Code
 * session it ran; the folder that Claude ran in, none from a window on a
 * sitrep from before heartbeats said it; the device that Claude still runs
 * on, empty unless seen there; and whether a live window holds the session,
 * as a refusal names its window.
 */
export type ResumeFacts = { claude: string; dir?: string; tty: string; isHeld: boolean }

/** Where a placeholder stands: bare; inside quotes or backticks; or where the shell evaluates it as arithmetic. */
type Standing = 'bare' | 'quoted' | 'evaluated'

/** The command's words as written, between its placeholders, and each placeholder and where it stands. */
type Piece = { words: string } | { name: string; standing: Standing }

type Quote = 'single' | 'ansi' | 'double' | 'backtick'

/**
 * How far a `${…}` is read: its parameter, as `x`, `@` or `x[1]`; a `:`
 * just after it; an offset or a length, `${x:1:2}`, which the shell
 * evaluates as arithmetic, as any `:` after the parameter opens but `:-`,
 * `:=`, `:?` and `:+`; or a word, past any other operator.
 */
type Phase = 'parameter' | 'colon' | 'offset' | 'word'

/**
 * Where the shell is: `'…'`; `$'…'`, where a backslash escapes; `"…"`;
 * `` `…` ``, which the shell scans for its closing backtick before any
 * quoting inside it; `$((…))` or `((…))`; `$[…]` or a subscript, which it
 * evaluates as arithmetic; `${…}`; or `$(…)`, read as a command of its own,
 * so quotes open afresh inside it, double quotes around it or not, and one
 * holding a `case` marked. Each that nests is open by as many as are
 * unclosed.
 */
type Context =
  | { kind: Quote }
  | { kind: 'arithmetic' | 'subscripted'; open: number }
  | { kind: 'expansion'; open: number; at: Phase }
  | { kind: 'substitution'; open: number; hasCase: boolean }

type Nested = Exclude<Context, { kind: Quote }>

/** The `(` read last: none, a plain one, or `$(`'s. */
type Paren = 'none' | 'plain' | 'dollar'

/** What the character before left the next to follow. */
type Before = { isAfterDollar: boolean; isAfterName: boolean; isAfterSpecial: boolean; paren: Paren }

const NESTING: Record<Nested['kind'], { opens: string; closes: string }> = {
  arithmetic: { opens: '(', closes: ')' },
  subscripted: { opens: '[', closes: ']' },
  expansion: { opens: '{', closes: '}' },
  substitution: { opens: '(', closes: ')' },
}

const QUOTES: ReadonlySet<Context['kind']> = new Set(['single', 'ansi', 'double', 'backtick'])

/** The shell's special parameters but the digits, which a name's characters take in: `$@`, `$*`, `$#`, `$?`, `$-`, `$$` and `$!`. */
const SPECIAL: ReadonlySet<string> = new Set(['@', '*', '#', '?', '-', '$', '!'])

/** What makes a word of what follows a `${…}`'s `:`, never an offset: `:-`, `:=`, `:?` and `:+`. */
const WORD_OPERATORS: ReadonlySet<string> = new Set(['-', '=', '?', '+'])

const NAME_PART = /^[A-Za-z0-9_]$/

const PLACEHOLDER_PART = /^[A-Za-z_]$/

/** What `TypedCommand` trims, Swift's whitespaces and newlines: every separator, the tab and the line breaks. */
const AROUND = /^[\p{Z}\t\n\v\f\r\u0085]+|[\p{Z}\t\n\v\f\r\u0085]+$/gu

/**
 * A character no line run by the shell may hold: a control (C0, DEL, C1),
 * which a terminal acts on before any quoting, or one that prints nothing,
 * a format character, a line or paragraph separator, one unassigned, or a
 * lone surrogate, which a JavaScript string can hold where a Swift one
 * can't.
 */
const UNPRINTABLE = /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}\p{Cn}\p{Cs}]/u

/** The command as SitRep's Settings name it, as each refusal opens. */
const COMMAND = 'The resume command in Settings'

/** What each fact is, as a refusal of a value that can't be typed names it. */
const FACT_WORDS: Record<Placeholder, string> = {
  claude: "the Claude Code session's id",
  dir: 'the folder its Claude ran in',
  tty: 'the terminal its Claude runs on',
}

/** The characters a refusal names in words. */
const UNTYPABLE: Readonly<Record<number, string>> = {
  0x09: "a tab, which can't be typed",
  0x0a: "a line break, which can't be typed",
  0x0d: "a line break, which can't be typed",
  0x85: "a line break, which can't be typed",
  0x1b: "an escape, which can't be typed",
  0x2028: "a line break, which can't be typed",
  0x2029: "a line break, which can't be typed",
}

const isPlaceholder = (name: string): name is Placeholder => (PLACEHOLDERS as readonly string[]).includes(name)

/** Whether the shell evaluates what stands in it as arithmetic, which runs a `$(…)` even in a quoted value. */
const isEvaluated = (context: Context) =>
  context.kind === 'arithmetic' ||
  context.kind === 'subscripted' ||
  (context.kind === 'expansion' && (context.at === 'colon' || context.at === 'offset'))

/** How far a `${…}` is read once a character is read directly in it, a placeholder's `{` among them. */
const phaseAfter = (at: Phase, character: string): Phase => {
  if (at === 'colon') {
    return WORD_OPERATORS.has(character) ? 'word' : 'offset'
  }

  if (at !== 'parameter') {
    return at
  }

  if (character === ':') {
    return 'colon'
  }

  return NAME_PART.test(character) || SPECIAL.has(character) || character === '[' ? 'parameter' : 'word'
}

/**
 * The shell reading a command a character at a time: inside which quotes,
 * backticks, arithmetic, subscripts, `${…}` or `$(…)`, as one may hold
 * another; whether the next character is escaped; whether the one before
 * is an unescaped `$` that opens an expansion, never the second of `$$`,
 * the shell's own process id, nor one escaped; whether it was a special
 * parameter after such a `$`, an unescaped `#` or `(`; whether it ended a
 * name, as a subscript's `[` follows one; and the name being read directly
 * in a `$(…)`, to tell its `case`.
 */
const shellReading = () => {
  const contexts: Context[] = []
  let isEscaped = false
  let isAfterDollar = false
  let isAfterHash = false
  let isAfterName = false
  let isAfterSpecial = false
  let paren: Paren = 'none'
  let word = ''

  const last = () => contexts.at(-1)

  const replaceLast = (context: Context) => {
    contexts.pop()
    contexts.push(context)
  }

  const forgetBefore = () => {
    isAfterDollar = false
    isAfterHash = false
    isAfterName = false
    isAfterSpecial = false
    paren = 'none'
  }

  /** What a character outside quotes, or in double quotes, leaves the next to follow. */
  const note = (character: string, before: Before) => {
    isAfterDollar = character === '$' && !before.isAfterDollar
    isAfterSpecial = before.isAfterDollar && SPECIAL.has(character)
    isAfterHash = character === '#'
    isAfterName = NAME_PART.test(character)
  }

  /** A `case` read directly in a `$(…)`, a word of its own or not, marks it. */
  const noteWord = (character: string) => {
    const context = last()

    if (context?.kind === 'substitution' && NAME_PART.test(character)) {
      word += character

      return
    }

    if (context?.kind === 'substitution' && word === 'case') {
      replaceLast({ ...context, hasCase: true })
    }

    word = ''
  }

  /**
   * A character that opens what nests, outside quotes or in double quotes:
   * `$(`; `$((`, the substitution `$(` opened taken for arithmetic; outside
   * double quotes, `((`, a command, its first `(` counted where it was read;
   * `${`; and `$[`, or a subscript after a name, a special parameter or a
   * `${…}`'s parameter. It is read before what it is in counts it, so a
   * `$(` or a `${` inside another is one of its own.
   */
  const opens = (character: string, before: Before, isInDouble: boolean) => {
    const context = last()

    if (character === '(' && before.paren === 'dollar') {
      replaceLast({ kind: 'arithmetic', open: 2 })
    } else if (character === '(' && before.isAfterDollar) {
      contexts.push({ kind: 'substitution', open: 1, hasCase: false })
      paren = 'dollar'
    } else if (character === '(' && before.paren === 'plain' && !isInDouble) {
      contexts.push({ kind: 'arithmetic', open: 1 })
    } else if (character === '{' && before.isAfterDollar) {
      contexts.push({ kind: 'expansion', open: 1, at: 'parameter' })
    } else if (
      character === '[' &&
      (before.isAfterDollar || before.isAfterName || before.isAfterSpecial || (context?.kind === 'expansion' && context.at === 'parameter'))
    ) {
      contexts.push({ kind: 'subscripted', open: 1 })
    } else {
      paren = character === '(' ? 'plain' : 'none'

      return false
    }

    return true
  }

  /**
   * Whether the character closes, or nests deeper in, what it is in: true
   * where it was only that. A `)` that would close a `$(…)` holding a `case`
   * may end one of its patterns: the substitution is kept open, so a quote
   * around it stays in force, reading on refusing more, never less.
   */
  const closes = (character: string) => {
    const context = last()

    if (context === undefined || !('open' in context)) {
      return false
    }

    const { opens: opening, closes: closing } = NESTING[context.kind]
    const open = character === opening ? context.open + 1 : character === closing ? context.open - 1 : undefined

    if (open === undefined) {
      return false
    }

    if (open === 0 && context.kind === 'substitution' && context.hasCase) {
      return true
    }

    contexts.pop()

    if (open > 0) {
      contexts.push({ ...context, open })
    }

    return true
  }

  const closeAt = (character: string, closing: string) => {
    if (character === closing) {
      contexts.pop()
    }
  }

  const inDouble = (character: string, before: Before) => {
    note(character, before)

    if (character === '"') {
      contexts.pop()
    } else if (character === '`') {
      contexts.push({ kind: 'backtick' })
    } else {
      opens(character, before, true)
    }
  }

  /** Outside quotes, or in what nests: how far a `${…}` it is read directly in is read, what it opens or closes, or the quotes it opens, `$'`, `'`, `"` or a backtick. */
  const outsideQuotes = (character: string, before: Before) => {
    const context = last()

    if (context?.kind === 'expansion') {
      replaceLast({ ...context, at: phaseAfter(context.at, character) })
    }

    note(character, before)

    if (opens(character, before, false) || closes(character)) {
      return
    }

    if (character === "'") {
      contexts.push({ kind: before.isAfterDollar ? 'ansi' : 'single' })
    } else if (character === '"' || character === '`') {
      contexts.push({ kind: character === '"' ? 'double' : 'backtick' })
    }
  }

  return {
    /** Whether a `{` here may open a placeholder: not escaped, and not after an unescaped `$` or `#`. */
    mayStartPlaceholder: () => !isEscaped && !isAfterDollar && !isAfterHash,
    /** Where a name opening here stands; none where it is no placeholder's and in quotes, being only words there. */
    standing: (isKnown: boolean): Standing | undefined => {
      if (contexts.some(isEvaluated)) {
        return 'evaluated'
      }

      if (!contexts.some(context => QUOTES.has(context.kind))) {
        return 'bare'
      }

      return isKnown ? 'quoted' : undefined
    },
    /** A placeholder read whole: what follows it follows no `$`, `#`, `(` or name, and a `${…}` it is directly in is read on, as by its `{`. */
    readPlaceholder: () => {
      const context = last()

      forgetBefore()
      word = ''

      if (context?.kind === 'expansion') {
        replaceLast({ ...context, at: phaseAfter(context.at, '{') })
      }
    },
    read: (character: string) => {
      const before: Before = { isAfterDollar, isAfterName, isAfterSpecial, paren }
      const isEscapedHere = isEscaped

      isEscaped = false
      forgetBefore()

      if (isEscapedHere) {
        word = ''

        return
      }

      noteWord(character)

      const kind = last()?.kind

      isEscaped = character === '\\' && kind !== 'single'

      switch (kind) {
        case 'single':
        case 'ansi':
          return closeAt(character, "'")
        case 'backtick':
          return closeAt(character, '`')
        case 'double':
          return inDouble(character, before)
        default:
          return outsideQuotes(character, before)
      }
    },
  }
}

/** `{name}` at `at` among the characters: its name and where what follows it starts; none where none is there. */
const placeholderAt = (characters: readonly string[], at: number) => {
  let end = at + 1

  while (PLACEHOLDER_PART.test(characters[end] ?? '')) {
    end += 1
  }

  return end > at + 1 && characters[end] === '}'
    ? { name: characters.slice(at + 1, end).join(''), end: end + 1 }
    : undefined
}

/** The command as given, less the spaces around it, as the shell reads it: its words, and each placeholder and where it stands. */
const piecesOf = (command: string): Piece[] => {
  const characters = [...command.replace(AROUND, '')]
  const reading = shellReading()
  const pieces: Piece[] = []
  let words = ''
  let at = 0

  while (at < characters.length) {
    const character = characters[at] ?? ''
    const found = character === '{' && reading.mayStartPlaceholder() ? placeholderAt(characters, at) : undefined
    const standing = found === undefined ? undefined : reading.standing(isPlaceholder(found.name))

    if (found !== undefined && standing !== undefined) {
      pieces.push({ words }, { name: found.name, standing })
      words = ''
      at = found.end
      reading.readPlaceholder()
    } else {
      reading.read(character)
      words += character
      at += 1
    }
  }

  return [...pieces, { words }].filter(piece => !('words' in piece) || piece.words !== '')
}

const writtenOf = (piece: Piece) => ('words' in piece ? piece.words : `{${piece.name}}`)

/** The names of the placeholders standing as wanted, in order, once. */
const namesOf = (pieces: readonly Piece[], wanted: (standing: Standing) => boolean = () => true) => [
  ...new Set(pieces.flatMap(piece => ('name' in piece && wanted(piece.standing) ? [piece.name] : []))),
]

/** Placeholders by their names, as a refusal names them: `{claude} and {dir}`. */
const braced = (names: readonly string[]) => inWords(names.map(name => `{${name}}`))

/** The first character in the text not fit to run, by its code point; none for text that only prints. */
const unprintableIn = (text: string) => UNPRINTABLE.exec(text)?.[0]?.codePointAt(0)

/** A character that can't be typed, as a refusal names it: the common ones by name, the rest by their code point. */
const untypable = (point: number) =>
  UNTYPABLE[point] ?? `a character that can't be typed (U+${point.toString(16).toUpperCase().padStart(4, '0')})`

/** What is wrong with the command as written, whatever the session, in SitRep's words naming the session; none where nothing is. */
const problemOf = (pieces: readonly Piece[], name: string): string | undefined => {
  const unprintable = unprintableIn(pieces.map(writtenOf).join(''))
  const unknown = namesOf(pieces).filter(each => !isPlaceholder(each))
  const evaluated = namesOf(pieces, standing => standing === 'evaluated')
  const quoted = namesOf(pieces, standing => standing === 'quoted')

  if (pieces.length === 0) {
    return `${COMMAND} is empty. To carry ${name} on, set one, or restore the default.`
  }

  if (unprintable !== undefined) {
    return `${COMMAND} has ${untypable(unprintable)}.`
  }

  if (unknown.length > 0) {
    return `${COMMAND} has ${braced(unknown)}, which SitRep doesn't know. It knows ${braced(PLACEHOLDERS)}.`
  }

  if (evaluated.length > 0) {
    return `${COMMAND} puts ${braced(evaluated)} in arithmetic or a subscript, where the shell runs what is in a value even quoted. Move it out.`
  }

  return quoted.length === 0 ? undefined : `${COMMAND} puts ${braced(quoted)} in quotes or backticks. Remove them: SitRep quotes each value itself.`
}

const valuesOf = ({ claude, dir, tty }: ResumeFacts): Record<Placeholder, string | undefined> => ({ claude, dir, tty })

/** What is wrong with the facts the command names: `{dir}` with no folder, or a value that can't be typed, the first by the placeholders' order. */
const factProblemOf = (wanted: readonly Placeholder[], facts: ResumeFacts, name: string): string | undefined => {
  const values = valuesOf(facts)

  if (wanted.includes('dir') && facts.dir === undefined) {
    return `${name}'s ${facts.isHeld ? 'window' : 'last window'} did not say which folder it ran in, as a window on an older sitrep does not, so sitrep has nothing to put for {dir}.`
  }

  const untyped = PLACEHOLDERS.filter(each => wanted.includes(each))
    .map(each => ({ each, point: unprintableIn(values[each] ?? '') }))
    .find(({ point }) => point !== undefined)

  return untyped?.point === undefined ? undefined : `For ${name}, ${FACT_WORDS[untyped.each]} has ${untypable(untyped.point)}.`
}

/** A value as a POSIX shell, or zsh, reads it back whole: in single quotes, each of its own closed, escaped and opened again; never bare, as a bare word can be a zsh global alias. */
export const shellQuoted = (value: string) => `'${value.replaceAll("'", "'\\''")}'`

/** Whether the command is the default, told by its text, the spaces around it aside: one saved the same as it is the default. */
const isDefault = (command: string) => command.replace(AROUND, '') === DEFAULT_COMMAND

/** A command read as the shell reads it and found fit to fill, whatever the session: its pieces, the placeholders it names, and whether it is the default. */
export type Typed = { pieces: readonly Piece[]; wanted: readonly Placeholder[]; isDefault: boolean }

/** The command read as the shell reads it, and found fit to fill; or why it is not, in SitRep's words naming the session. */
export const typedOf = (command: string, name: string): Checked<Typed> => {
  const pieces = piecesOf(command)
  const problem = problemOf(pieces, name)

  if (problem !== undefined) {
    return { ok: false, error: problem }
  }

  return { ok: true, value: { pieces, wanted: namesOf(pieces).filter(isPlaceholder), isDefault: isDefault(command) } }
}

/** The line to run for a session, named as the board names it: the typed command, each placeholder replaced by its fact, quoted; or why none runs, a fact missing or not fit to type. */
export const filledOf = ({ pieces, wanted }: Typed, facts: ResumeFacts, name: string): Checked<string> => {
  const problem = factProblemOf(wanted, facts, name)
  const values = valuesOf(facts)

  if (problem !== undefined) {
    return { ok: false, error: problem }
  }

  return {
    ok: true,
    value: pieces
      .map(piece => {
        const value = 'name' in piece && isPlaceholder(piece.name) ? values[piece.name] : undefined

        return value === undefined ? writtenOf(piece) : shellQuoted(value)
      })
      .join(''),
  }
}

/** The line to run for a session, named as the board names it, the command as given; or why none runs, in SitRep's words. */
export const lineOf = (command: string, facts: ResumeFacts, name: string): Checked<string> => {
  const typed = typedOf(command, name)

  return typed.ok ? filledOf(typed.value, facts, name) : typed
}
