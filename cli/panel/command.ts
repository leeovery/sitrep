/**
 * The resume command, read, refused and filled as SitRep's `TypedCommand`
 * does it (app/Sources/SitRepScreen/TypedCommand.swift), in its words: no
 * terminal, no shell.
 *
 * - It is held to plain shell syntax, which sh, bash, zsh, dash and ksh
 *   all read alike, and anything else is refused, in words pointing to a
 *   script (Lee, 20 November 2026): a reader refusing each place a shell
 *   reads a value again could never be finished, as three reviews each
 *   found more. Plain syntax is:
 *   - words of ASCII letters, digits and `_ . / : @ % + , = -`; a `~`
 *     starting one, or right after its first `=` or a `:` past that, as
 *     in `PATH=~/bin:~/go/bin`, though never right before a placeholder,
 *     as zsh and ksh read `~'…'` as a user's home; `\` and the character
 *     after it;
 *   - spaces between them; `|`, `||`, `&&` and `;`;
 *   - redirections, `<`, `>` and `>>`, each to a word, and `>&` or `<&` to
 *     a single digit, which nothing may join, as `2>&1`;
 *   - `[` and `]` as words of their own, as `[ -n "$s" ]`;
 *   - `'…'`, holding anything;
 *   - `"…"`, holding what prints but a backtick and `!`, and `\` only
 *     before `"` or `$`;
 *   - a parameter, in double quotes or out: `$name`, `${name}`, `$?`, `$$`,
 *     or `$1` to `$9`, one outside braces only where every shell ends it:
 *     at a blank, an operator, a redirection, a `)`, a double quote, one
 *     of `/ - = , + @ % \ $`, or the command's end, and in double quotes
 *     at a `'` too;
 *   - `$(…)`, outside quotes, holding plain syntax, however deep.
 *   `$!` is none: an interactive bash or zsh reads a `!` after it as
 *   history, and `&` alone, which gives `$!` its meaning, is refused. Nor
 *   is `$#`, always 0 here: zsh reads its `#` as asking the length of what
 *   follows, so in `$#$(…)` zsh reads the length of `$$` and a glob
 *   qualifier where the others read a `$(…)`.
 * - A placeholder, `{claude}`, `{dir}` or `{tty}`, is filled outside every
 *   quote, at the top level or in a `$(…)`, joined to a word or not:
 *   `id={claude}` is `id='…'`, one word. Inside quotes it is refused, as
 *   its quoted value would end them early. Another name in braces outside
 *   quotes is refused as one SitRep doesn't know; inside quotes it is
 *   text, as awk's `'{print}'`.
 * - What takes code, a name or a number from its argument passes as words,
 *   and a command passing a placeholder to one takes that risk itself: a
 *   builtin such as `eval`, `trap`, `let`, `read`, `declare`, `typeset`,
 *   `local`, `export`, `printf -v`, `test`'s numeric comparisons, `shift`,
 *   `exit`, `return` or `ulimit`; an assignment to a variable the shell
 *   evaluates, as `PS1`, `PS4`, `PROMPT_COMMAND`, `ENV` and `BASH_ENV`, or
 *   an integer one such as `RANDOM`, `SECONDS` or `OPTIND`; or a program
 *   running an argument as code, as `sh -c`.
 * - With zsh's GLOB_SUBST set, an unquoted parameter or `$(…)` holding a
 *   value can run code, as `x={dir}; echo $x` does: a command for such a
 *   shell puts them in double quotes. The panel's login shell, `-l -c`,
 *   reads no `.zshrc`, but the app's interactive one does.
 * - Each value goes in single quotes, never bare.
 * - Refused before anything runs: none given; a character that doesn't
 *   print, in the command or in a value; a placeholder SitRep doesn't know;
 *   one in quotes; any part but plain syntax, and a quote or `$(…)` left
 *   open; `{dir}`, where the window said no folder; a value starting with
 *   a dash, which a program would read as an option.
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

/** A command passing its placeholders to a script, as a refusal of a part SitRep can't check suggests. */
const SCRIPTED = '~/bin/resume {claude} {dir}'

/**
 * What fills the resume command: the window's writer, the Claude Code
 * session it ran; the folder that Claude ran in, none from a window on a
 * sitrep from before heartbeats said it; the device that Claude still runs
 * on, empty unless seen there; and whether a live window holds the session,
 * as a refusal names its window.
 */
export type ResumeFacts = { claude: string; dir?: string; tty: string; isHeld: boolean }

/** Where a placeholder stands: outside every quote, or inside quotes. */
type Standing = 'bare' | 'quoted'

/** The command's words as written, between its placeholders, and each placeholder and where it stands. */
type Piece = { words: string } | { name: string; standing: Standing }

/** Where a reading stopped: at a part SitRep can't check, or at the command's end, with a part left open. */
type Stop = { kind: 'unchecked' | 'unclosed'; part: string }

/** A command as read: its pieces, as far as the reading went, and where it stopped, if it did. */
type Reading = { pieces: Piece[]; stop: Stop | undefined }

/**
 * Where a reading stands outside quotes: at a word's start; inside a word;
 * after a redirection, its word to come; or after one to a descriptor,
 * `2>&1`, which nothing may join.
 */
type Spot = 'start' | 'word' | 'target' | 'apart'

/** The plain characters of a word. */
const WORD = /^[A-Za-z0-9_./:@%+,=-]$/

const NAME_START = /^[A-Za-z_]$/

const NAME_PART = /^[A-Za-z0-9_]$/

const PLACEHOLDER_PART = /^[A-Za-z_]$/

/** What `$` may name but a name: `$?`, `$$` and `$1` to `$9`. Never `$#`, as zsh reads `$#` as the length of what follows, `$#$` of `$$`. */
const SPECIAL = /^[?$1-9]$/

const DIGIT = /^[0-9]$/

const BLANKS: ReadonlySet<string> = new Set([' '])

/** What may follow a part nothing may join, `2>&1`, `[` or `]`: a blank, an operator, a redirection, a `$(…)`'s end, or the command's, read as ''. */
const BREAKS: ReadonlySet<string> = new Set(['', ' ', '|', '&', ';', '<', '>', ')'])

/**
 * What may follow a parameter outside braces, where every shell ends it: a
 * break, a double quote, or one of `/ - = , + @ % \ $`. Others read on:
 * zsh's `$x:F:…:` evaluates the `…` as arithmetic, `$x[…]` is zsh's
 * subscript, and zsh reads `$12` as `${12}` and `$$'…'` as `$$` and `$'…'`;
 * ksh reads `$x.y` as one name, and bash and ksh take a letter past ASCII
 * into one. All but `$'…'` hold in double quotes too.
 */
const PARAMETER_ENDS: ReadonlySet<string> = new Set([...BREAKS, '"', '/', '-', '=', ',', '+', '@', '%', '\\', '$'])

/** What may follow a parameter outside braces but inside double quotes: what may outside the quotes, and `'`, as in `"$USER's"`. */
const QUOTED_PARAMETER_ENDS: ReadonlySet<string> = new Set([...PARAMETER_ENDS, "'"])

/** What may start a word but its plain characters: a placeholder's brace, `~`, `\`, `$` and the quotes. */
const WORD_STARTS: ReadonlySet<string> = new Set(['{', '~', '\\', '$', "'", '"'])

/** What double quotes may not hold, though it prints: a backtick, and `!`, which an interactive bash or zsh reads as history. */
const UNQUOTABLE: ReadonlySet<string> = new Set(['`', '!'])

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

/** How many characters the parameter `$` starts at `at` takes, in double quotes or not, `$name`, `${name}`, `$?`, `$$` or `$1` to `$9`, one outside braces only where what follows ends it; none where it starts none. */
const parameterLength = (characters: readonly string[], at: number, isQuoted: boolean) => {
  const next = characters[at + 1] ?? ''
  const isBraced = next === '{'
  let end = at + (isBraced ? 2 : 1)

  if (SPECIAL.test(next)) {
    end += 1
  } else if (NAME_START.test(characters[end] ?? '')) {
    while (NAME_PART.test(characters[end] ?? '')) {
      end += 1
    }
  } else {
    return undefined
  }

  if (isBraced) {
    return characters[end] === '}' ? end + 1 - at : undefined
  }

  return (isQuoted ? QUOTED_PARAMETER_ENDS : PARAMETER_ENDS).has(characters[end] ?? '') ? end - at : undefined
}

/** A `$` at `at` that starts no parameter, as a refusal names it: what it starts, to the character that ends it, as `${x:`, `$x:`, `$$'` or `$'`; `$` alone before a blank or the command's end. */
const dollarPart = (characters: readonly string[], at: number) => {
  const next = characters[at + 1] ?? ''
  let end = at + (next === '{' ? 2 : 1)

  if (next === '' || BLANKS.has(next)) {
    return '$'
  }

  if (SPECIAL.test(next)) {
    end += 1
  } else if (next === '{' || NAME_START.test(next)) {
    while (NAME_PART.test(characters[end] ?? '')) {
      end += 1
    }
  }

  return characters.slice(at, end + 1).join('')
}

/**
 * The command read by plain shell syntax a character at a time, as far as
 * it holds to it: inside which quotes, if any; how many `$(…)` deep; where
 * outside quotes; where the word's first `=` stands, and each outer word's
 * while in a `$(…)`; and the redirection read last, as a refusal of what
 * follows it names it.
 */
const readingOf = (characters: readonly string[]): Reading => {
  const pieces: Piece[] = []
  let words = ''
  let at = 0
  let depth = 0
  let spot: Spot = 'start'
  let quote: "'" | '"' | undefined
  let equalsAt: number | undefined
  const outerEquals: (number | undefined)[] = []
  let redirection = ''
  let stop: Stop | undefined

  const ahead = (offset: number) => characters[at + offset] ?? ''

  const take = (count: number) => {
    words += characters.slice(at, at + count).join('')
    at += count
  }

  /** Into a word: a new one, its `=` yet to come, where the reading stood outside one. */
  const inWord = () => {
    if (spot !== 'word') {
      equalsAt = undefined
      spot = 'word'
    }
  }

  const word = (count: number) => {
    inWord()
    take(count)
  }

  /** A plain character, the word's first `=` kept, as a `~` may follow it. */
  const plain = (character: string) => {
    word(1)

    if (character === '=' && equalsAt === undefined) {
      equalsAt = at - 1
    }
  }

  const operator = (count: number) => {
    take(count)
    spot = 'start'
  }

  const refuse = (part: string) => {
    stop = { kind: 'unchecked', part }
  }

  const placeholder = (name: string, standing: Standing, end: number) => {
    pieces.push({ words }, { name, standing })
    words = ''
    at = end
  }

  /** A `{` outside quotes: a placeholder, known or not, joined to the word it is in; or a brace of the shell's, refused. */
  const brace = () => {
    const found = placeholderAt(characters, at)

    if (found === undefined) {
      return refuse('{')
    }

    inWord()
    placeholder(found.name, 'bare', found.end)
  }

  /** A `~` outside quotes: starting a word, or right after its first `=` or a `:` past that; never right before a placeholder, which zsh and ksh read through its quotes as a user's name. */
  const tilde = () => {
    const isAssigned = spot === 'word' && equalsAt !== undefined && (equalsAt === at - 1 || ahead(-1) === ':')
    const found = ahead(1) === '{' ? placeholderAt(characters, at + 1) : undefined

    if (spot !== 'start' && spot !== 'target' && !isAssigned) {
      return refuse('~')
    }

    return found === undefined ? word(1) : refuse(`~{${found.name}}`)
  }

  /** A `{` in quotes: a placeholder, refused as quoted; any other name, text. */
  const quotedBrace = () => {
    const found = placeholderAt(characters, at)

    return found !== undefined && isPlaceholder(found.name) ? placeholder(found.name, 'quoted', found.end) : take(1)
  }

  /** A `$`: a parameter; outside quotes, a `$(…)` opening; nothing else. */
  const dollar = () => {
    if (ahead(1) !== '(') {
      const length = parameterLength(characters, at, quote === '"')

      return length === undefined ? refuse(dollarPart(characters, at)) : word(length)
    }

    if (ahead(2) === '(' || quote === '"') {
      return refuse(ahead(2) === '(' ? '$((' : '$(')
    }

    inWord()
    outerEquals.push(equalsAt)
    take(2)
    depth += 1
    spot = 'start'
  }

  /** A `)` closing a `$(…)`, which leaves the word it is in open. */
  const close = () => {
    take(1)
    depth -= 1
    equalsAt = outerEquals.pop()
    spot = 'word'
  }

  /** `<`, `>` or `>>`, its word to come; or `>&` or `<&` and a digit; never `<<`, `<(` nor `>(`. */
  const redirect = (character: string) => {
    const next = ahead(1)

    if (next === '(' || (character === '<' && next === '<')) {
      return refuse(`${character}${next}`)
    }

    if (next === '&') {
      redirection = `${character}&${ahead(2)}`

      if (!DIGIT.test(ahead(2))) {
        return refuse(BLANKS.has(ahead(2)) ? `${character}&` : redirection)
      }

      take(3)
      spot = 'apart'

      return
    }

    redirection = character === '>' && next === '>' ? '>>' : character
    take(redirection.length)
    spot = 'target'
  }

  /** A character outside quotes, as plain syntax reads it where the reading stands. */
  const inCommand = (character: string) => {
    if (BLANKS.has(character)) {
      spot = spot === 'target' ? 'target' : 'start'

      return take(1)
    }

    if ((spot === 'target' && !WORD.test(character) && !WORD_STARTS.has(character)) || (spot === 'apart' && !BREAKS.has(character))) {
      return refuse(`${redirection}${character}`)
    }

    switch (character) {
      case '{':
        return brace()
      case '~':
        return tilde()
      case '\\':
        return ahead(1) === '' ? refuse('\\') : word(2)
      case '$':
        return dollar()
      case "'":
      case '"':
        quote = character

        return word(1)
      case ')':
        return depth > 0 ? close() : refuse(')')
      case '|':
      case ';':
        return operator(character === '|' && ahead(1) === '|' ? 2 : 1)
      case '&':
        return ahead(1) === '&' ? operator(2) : refuse('&')
      case '<':
      case '>':
        return redirect(character)
      case '[':
      case ']':
        return spot === 'start' && BREAKS.has(ahead(1)) ? word(1) : refuse(character)
      default:
        return WORD.test(character) ? plain(character) : refuse(character)
    }
  }

  /** A character in double quotes: their end, `\"` or `\$`, a parameter, or what prints but a backtick and `!`. */
  const inDouble = (character: string) => {
    switch (character) {
      case '"':
        quote = undefined

        return take(1)
      case '\\':
        return ahead(1) === '"' || ahead(1) === '$' ? take(2) : refuse(`\\${ahead(1)}`)
      case '$':
        return dollar()
      case '{':
        return quotedBrace()
      default:
        return UNQUOTABLE.has(character) ? refuse(character) : take(1)
    }
  }

  /** A character in single quotes: their end, or anything. */
  const inSingle = (character: string) => {
    if (character === "'") {
      quote = undefined

      return take(1)
    }

    return character === '{' ? quotedBrace() : take(1)
  }

  /** What is left open at the command's end: a quote, a `$(…)`, or a redirection's word. */
  const stopAtEnd = (): Stop | undefined => {
    if (quote !== undefined || depth > 0) {
      return { kind: 'unclosed', part: quote ?? '$(' }
    }

    return spot === 'target' ? { kind: 'unchecked', part: redirection } : undefined
  }

  while (at < characters.length && stop === undefined) {
    const character = characters[at] ?? ''

    if (quote === "'") {
      inSingle(character)
    } else if (quote === '"') {
      inDouble(character)
    } else {
      inCommand(character)
    }
  }

  return { pieces: [...pieces, { words }].filter(piece => !('words' in piece) || piece.words !== ''), stop: stop ?? stopAtEnd() }
}

const writtenOf = (piece: Piece) => ('words' in piece ? piece.words : `{${piece.name}}`)

/** The names of the placeholders standing as wanted, in order, once. */
const namesOf = (pieces: readonly Piece[], wanted: (standing: Standing) => boolean = () => true) => [
  ...new Set(pieces.flatMap(piece => ('name' in piece && wanted(piece.standing) ? [piece.name] : []))),
]

/** Placeholders by their names, as a refusal names them: `{claude} and {dir}`. */
const braced = (names: readonly string[], conjunction = 'and') => inWords(names.map(name => `{${name}}`), conjunction)

/** A part of the command as a refusal names it: one holding a backtick by its name, the rest as written, in backticks. */
const partWords = (part: string) => (part.includes('`') ? 'a backtick' : `\`${part}\``)

/** The first character in the text not fit to run, by its code point; none for text that only prints. */
const unprintableIn = (text: string) => UNPRINTABLE.exec(text)?.[0]?.codePointAt(0)

/** A character that can't be typed, as a refusal names it: the common ones by name, the rest by their code point. */
const untypable = (point: number) =>
  UNTYPABLE[point] ?? `a character that can't be typed (U+${point.toString(16).toUpperCase().padStart(4, '0')})`

/** Why the reading stopped, in SitRep's words: a part SitRep can't check, pointing to a script; or a part left open. */
const stopWords = ({ kind, part }: Stop) =>
  kind === 'unclosed'
    ? `${COMMAND} opens ${partWords(part)} but never closes it.`
    : `${COMMAND} uses ${partWords(part)}, which SitRep can't check. Put that part in a script and pass it ${braced(PLACEHOLDERS, 'or')}, as in ${SCRIPTED}.`

/** What is wrong with the command as written, less the spaces around it, whatever the session, in SitRep's words naming the session; none where nothing is. */
const problemOf = (text: string, { pieces, stop }: Reading, name: string): string | undefined => {
  const unprintable = unprintableIn(text)
  const unknown = namesOf(pieces).filter(each => !isPlaceholder(each))
  const quoted = namesOf(pieces, standing => standing === 'quoted')

  if (text === '') {
    return `${COMMAND} is empty. To carry ${name} on, set one, or restore the default.`
  }

  if (unprintable !== undefined) {
    return `${COMMAND} has ${untypable(unprintable)}.`
  }

  if (unknown.length > 0) {
    return `${COMMAND} has ${braced(unknown)}, which SitRep doesn't know. It knows ${braced(PLACEHOLDERS)}.`
  }

  if (quoted.length > 0) {
    return `${COMMAND} puts ${braced(quoted)} in quotes. Remove them: SitRep quotes each value itself.`
  }

  return stop === undefined ? undefined : stopWords(stop)
}

const valuesOf = ({ claude, dir, tty }: ResumeFacts): Record<Placeholder, string | undefined> => ({ claude, dir, tty })

/**
 * What is wrong with the facts the command names: `{dir}` with no folder; a
 * value that can't be typed; or one starting with a dash, which a program
 * would read as an option, as `claude --resume {claude}` would read an id
 * of `--settings=…`. Each the first by the placeholders' order.
 */
const factProblemOf = (wanted: readonly Placeholder[], facts: ResumeFacts, name: string): string | undefined => {
  const values = valuesOf(facts)
  const named = PLACEHOLDERS.filter(each => wanted.includes(each)).map(each => ({ each, value: values[each] ?? '' }))

  if (wanted.includes('dir') && facts.dir === undefined) {
    return `${name}'s ${facts.isHeld ? 'window' : 'last window'} did not say which folder it ran in, as a window on an older sitrep does not, so sitrep has nothing to put for {dir}.`
  }

  const untyped = named.map(({ each, value }) => ({ each, point: unprintableIn(value) })).find(({ point }) => point !== undefined)

  if (untyped?.point !== undefined) {
    return `For ${name}, ${FACT_WORDS[untyped.each]} has ${untypable(untyped.point)}.`
  }

  const dashed = named.find(({ value }) => value.startsWith('-'))

  return dashed === undefined ? undefined : `For ${name}, ${FACT_WORDS[dashed.each]} starts with a dash, which a program would read as an option.`
}

/** A value as a POSIX shell, or zsh, reads it back whole: in single quotes, each of its own closed, escaped and opened again; never bare, as a bare word can be a zsh global alias. */
export const shellQuoted = (value: string) => `'${value.replaceAll("'", "'\\''")}'`

/** A command read by plain shell syntax and found fit to fill, whatever the session: its pieces, the placeholders it names, and whether it is the default, told by its text. */
export type Typed = { pieces: readonly Piece[]; wanted: readonly Placeholder[]; isDefault: boolean }

/** The command, less the spaces around it, read by plain shell syntax, and found fit to fill; or why it is not, in SitRep's words naming the session. */
export const typedOf = (command: string, name: string): Checked<Typed> => {
  const text = command.replace(AROUND, '')
  const reading = readingOf([...text])
  const problem = problemOf(text, reading, name)

  if (problem !== undefined) {
    return { ok: false, error: problem }
  }

  return { ok: true, value: { pieces: reading.pieces, wanted: namesOf(reading.pieces).filter(isPlaceholder), isDefault: text === DEFAULT_COMMAND } }
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
