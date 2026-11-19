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
 * - A placeholder is filled only outside quotes and backticks, where its
 *   quoted value would end them early, and outside arithmetic and
 *   subscripts, where the shell runs a `$(…)` even in a quoted value.
 *   Joined to unquoted text it is filled: `id={claude}` is `id='…'`, one
 *   shell word.
 * - Each value goes in single quotes, never bare.
 * - Refused before anything runs: none given; a character that doesn't
 *   print, in the command or in a value; a placeholder SitRep doesn't know;
 *   one in arithmetic or a subscript; one in quotes or backticks; `{dir}`,
 *   where the window said no folder.
 * - It reads the command a code point at a time, as the shell reads
 *   characters, where the Swift reads graphemes: a quote with a combining
 *   mark after it still opens quotes here.
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

/** Where a placeholder stands: bare; inside quotes or backticks; or where the shell evaluates it, in arithmetic or a subscript. */
type Standing = 'bare' | 'quoted' | 'evaluated'

/** The command's words as written, between its placeholders, and each placeholder and where it stands. */
type Piece = { words: string } | { name: string; standing: Standing }

type Quote = 'single' | 'ansi' | 'double' | 'backtick'

type Nest = 'arithmetic' | 'subscripted' | 'expansion'

/**
 * Where the shell is: `'…'`; `$'…'`, where a backslash escapes; `"…"`;
 * `` `…` ``, which the shell scans for its closing backtick before any
 * quoting inside it; `$((…))` or `((…))`; `$[…]` or a subscript, `a[…]` or
 * `${a[…]}`, which it evaluates as arithmetic; or `${…}`. Each that nests
 * is open by as many as are unclosed.
 */
type Context = { kind: Quote } | { kind: Nest; open: number }

/** The `(` read last: none, a plain one, or `$(`'s. */
type Paren = 'none' | 'plain' | 'dollar'

/** What the character before left the next to follow. */
type Before = { isAfterDollar: boolean; isAfterName: boolean; paren: Paren }

const NESTING: Record<Nest, { opens: string; closes: string }> = {
  arithmetic: { opens: '(', closes: ')' },
  subscripted: { opens: '[', closes: ']' },
  expansion: { opens: '{', closes: '}' },
}

const QUOTES: ReadonlySet<Context['kind']> = new Set(['single', 'ansi', 'double', 'backtick'])

const EVALUATED: ReadonlySet<Context['kind']> = new Set(['arithmetic', 'subscripted'])

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

/**
 * The shell reading a command a character at a time: inside which quotes,
 * backticks, arithmetic, subscripts or `${…}`, as one may hold another;
 * whether the next character is escaped; whether the one before is an
 * unescaped `$` that opens an expansion, never the second of `$$`, the
 * shell's own process id, nor one escaped; whether it was an unescaped `#`
 * or `(`; and whether it ended a name, as a subscript's `[` follows one.
 */
const shellReading = () => {
  const contexts: Context[] = []
  let isEscaped = false
  let isAfterDollar = false
  let isAfterHash = false
  let isAfterName = false
  let paren: Paren = 'none'

  const last = () => contexts.at(-1)

  const forgetBefore = () => {
    isAfterDollar = false
    isAfterHash = false
    isAfterName = false
    paren = 'none'
  }

  /** A character outside quotes, or in double quotes: the expansions and evaluations it opens, and what it leaves the next. `((` opens arithmetic only outside quotes, where it is a command. */
  const expand = (character: string, before: Before) => {
    isAfterDollar = character === '$' && !before.isAfterDollar
    isAfterHash = character === '#'
    isAfterName = NAME_PART.test(character)

    if (character === '(' && (before.paren === 'dollar' || (before.paren === 'plain' && last()?.kind !== 'double'))) {
      contexts.push({ kind: 'arithmetic', open: 2 })
    } else if (character === '(') {
      paren = before.isAfterDollar ? 'dollar' : 'plain'
    } else if (character === '[' && (before.isAfterDollar || before.isAfterName || last()?.kind === 'expansion')) {
      contexts.push({ kind: 'subscripted', open: 1 })
    } else if (character === '{' && before.isAfterDollar) {
      contexts.push({ kind: 'expansion', open: 1 })
    }
  }

  /** Whether the character closes, or nests deeper in, the arithmetic, subscript or `${…}` it is in: true where it was only that. */
  const closes = (character: string) => {
    const context = last()

    if (context === undefined || !('open' in context)) {
      return false
    }

    const { opens, closes: closing } = NESTING[context.kind]
    const open = character === opens ? context.open + 1 : character === closing ? context.open - 1 : undefined

    if (open === undefined) {
      return false
    }

    contexts.pop()

    if (open > 0) {
      contexts.push({ kind: context.kind, open })
    }

    return true
  }

  const closeAt = (character: string, closing: string) => {
    if (character === closing) {
      contexts.pop()
    }
  }

  const inDouble = (character: string, before: Before) => {
    if (character === '"') {
      contexts.pop()
    } else if (character === '`') {
      contexts.push({ kind: 'backtick' })
    } else {
      expand(character, before)
    }
  }

  /** Outside quotes, or in what nests: the quotes a character opens, `$'`, `'`, `"` or a backtick, or what it expands. */
  const outsideQuotes = (character: string, before: Before) => {
    if (closes(character)) {
      return
    }

    if (character === "'") {
      contexts.push({ kind: before.isAfterDollar ? 'ansi' : 'single' })
    } else if (character === '"' || character === '`') {
      contexts.push({ kind: character === '"' ? 'double' : 'backtick' })
    } else {
      expand(character, before)
    }
  }

  return {
    /** Whether a `{` here may open a placeholder: not escaped, and not after an unescaped `$` or `#`. */
    mayStartPlaceholder: () => !isEscaped && !isAfterDollar && !isAfterHash,
    /** Where a name opening here stands; none where it is no placeholder's and in quotes, being only words there. */
    standing: (isKnown: boolean): Standing | undefined => {
      if (contexts.some(context => EVALUATED.has(context.kind))) {
        return 'evaluated'
      }

      if (!contexts.some(context => QUOTES.has(context.kind))) {
        return 'bare'
      }

      return isKnown ? 'quoted' : undefined
    },
    /** A placeholder read whole: what follows it follows no `$`, `#`, `(` or name. */
    readPlaceholder: forgetBefore,
    read: (character: string) => {
      const before: Before = { isAfterDollar, isAfterName, paren }
      const isEscapedHere = isEscaped

      isEscaped = false
      forgetBefore()

      if (isEscapedHere) {
        return
      }

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
export const isDefault = (command: string) => command.replace(AROUND, '') === DEFAULT_COMMAND

/**
 * The line to run for a session, named as the board names it: the command
 * with each placeholder replaced by its fact, quoted; or why none runs, in
 * SitRep's words.
 */
export const lineOf = (command: string, facts: ResumeFacts, name: string): Checked<string> => {
  const pieces = piecesOf(command)
  const wanted = namesOf(pieces).filter(isPlaceholder)
  const problem = problemOf(pieces, name) ?? factProblemOf(wanted, facts, name)
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
