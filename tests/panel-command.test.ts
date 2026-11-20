import { expect, test } from './kit'
import { DEFAULT_COMMAND, lineOf, shellQuoted, typedOf, type ResumeFacts } from '../cli/panel/command'
import { commandsOf } from './commands'
import { HOME, W1 } from './data'
import { REFUSED_COMMANDS } from './refused-commands'

/**
 * The resume command, read, refused and filled as SitRep's TypedCommand
 * does it, held to the cases its Swift tests hold (TypedCommandTests,
 * ResumeCommandTests): plain shell syntax only, so a session's name or
 * folder never runs as code, and anything else refused in words pointing
 * to a script. What evaluates its arguments, as `eval`, passes as words:
 * a command passing a placeholder to one is the user's own risk.
 */
const NAME = 'Invoice ledger'

const FOLDER = `${HOME}/Code/litware`

const facts = (given: Partial<ResumeFacts> = {}): ResumeFacts => ({ claude: W1, dir: FOLDER, tty: '', isHeld: false, ...given })

/** The line for the command, its window's folder given, or why none runs. */
const line = (command: string, given: Partial<ResumeFacts> = {}) => lineOf(command, facts(given), NAME)

const filled = (value: string) => ({ ok: true, value })

const refused = (error: string) => ({ ok: false, error })

const QUOTED = refused('The resume command in Settings puts {dir} in quotes. Remove them: SitRep quotes each value itself.')

/** The refusal of a part sitrep can't check, as named. */
const unchecked = (part: string) =>
  refused(
    `The resume command in Settings uses ${part}, which sitrep can't check. Put that part in a script and pass it {claude}, {dir} or {tty}, as in ~/bin/resume {claude} {dir}.`,
  )

/** Hostile facts: a quote that would end its own, a backtick, and a subscript the shell would evaluate. */
const HOSTILE = { claude: "x'; touch PWNED; '", dir: 'a[$(touch PWNED)]', tty: '`touch PWNED`' }

/** The command with each placeholder replaced by its hostile fact, quoted. */
const filledHostile = (command: string) =>
  command.replaceAll('{claude}', shellQuoted(HOSTILE.claude)).replaceAll('{dir}', shellQuoted(HOSTILE.dir)).replaceAll('{tty}', shellQuoted(HOSTILE.tty))

test('the command is taken as given, less the spaces around it, line breaks among them', () => {
  expect(line(' claude --resume {claude} ')).toEqual(line('claude --resume {claude}'))
  expect(line('\n claude --resume {claude}\u0085\u3000')).toEqual(filled(`claude --resume '${W1}'`))
})

test('each value is always in single quotes, never bare, its own quotes closed, escaped and opened again', () => {
  const cases: [string, string][] = [
    ['%12', "'%12'"],
    ['/private/tmp/tmux-501/default', "'/private/tmp/tmux-501/default'"],
    ['litware-Qm4tZ8', "'litware-Qm4tZ8'"],
    ['litware · restore-card', "'litware · restore-card'"],
    ["team's work", "'team'\\''s work'"],
    ['$HOME;rm', "'$HOME;rm'"],
    ['=zmx', "'=zmx'"],
    ['~/tmux', "'~/tmux'"],
    ['', "''"],
    ["x'\u0301; touch pwned; '\u0301", "'x'\\''\u0301; touch pwned; '\\''\u0301'"],
  ]

  expect(cases.map(([value]) => shellQuoted(value))).toEqual(cases.map(([, quoted]) => quoted))
})

test('each placeholder is filled, quoted, every time it is named', () => {
  expect(line('cd {dir} && ls {dir}', { dir: 'litware · card' })).toEqual(filled("cd 'litware · card' && ls 'litware · card'"))
})

/** Lee's one-liner through his session tool, as DESIGN records it, the tool renamed `seat`; and tmux by `{tty}`. */
const SEAT =
  's=$(seat hook list | awk -F\'\\t\' -v id={claude} \'index($3, "--resume " id) {print $1; exit}\'); [ -n "$s" ] && seat open -s "$s" || seat open -p {dir} -- claude --resume {claude}'

const TMUX =
  't=$(tmux list-panes -a -F \'#{pane_tty} #{session_name}\' | awk -v d={tty} \'$1==d {print $2; exit}\'); [ -n "$t" ] && tmux attach -t "$t" || tmux new -c {dir} claude --resume {claude}'

test("the default, a script given the placeholders, and DESIGN's examples pass, filled exactly as written", () => {
  const dir = `${HOME}/Code/fabrikam`
  const tmuxed = (tty: string) =>
    `t=$(tmux list-panes -a -F '#{pane_tty} #{session_name}' | awk -v d='${tty}' '$1==d {print $2; exit}'); [ -n "$t" ] && tmux attach -t "$t" || tmux new -c '${dir}' claude --resume '${W1}'`

  expect(line(DEFAULT_COMMAND, { dir })).toEqual(filled(`cd '${dir}' && claude --resume '${W1}'`))
  expect(line('~/bin/resume {claude} {dir}', { dir })).toEqual(filled(`~/bin/resume '${W1}' '${dir}'`))
  expect(line(SEAT, { dir })).toEqual(
    filled(
      `s=$(seat hook list | awk -F'\\t' -v id='${W1}' 'index($3, "--resume " id) {print $1; exit}'); [ -n "$s" ] && seat open -s "$s" || seat open -p '${dir}' -- claude --resume '${W1}'`,
    ),
  )
  expect(line(TMUX, { dir, tty: '/dev/ttys041' })).toEqual(filled(tmuxed('/dev/ttys041')))
  expect(line(TMUX, { dir })).toEqual(filled(tmuxed('')))
})

test("the default resumes the conversation in its folder, a `'` in the folder's name closed and opened again", () => {
  expect(DEFAULT_COMMAND).toBe('cd {dir} && claude --resume {claude}')
  expect(line(DEFAULT_COMMAND, { dir: `${HOME}/Code/team's work` })).toEqual(filled(`cd '${HOME}/Code/team'\\''s work' && claude --resume '${W1}'`))
})

test('plain shell syntax passes, each placeholder filled wherever it stands outside quotes, however deep in `$(…)`', () => {
  const commands = [
    'a {dir} | b {claude} || c && d; e;f|g {tty}',
    'claude --resume {claude} 2>&1 >>~/log <&0 >{tty} < {dir} 1>&2',
    '[ -d {dir} ] && cd {dir}',
    'echo "$HOME" "${x}" "$?$$$1" "a\\"b\\$c" $x ${x}{dir} $_x9',
    'PATH=${PATH}:/opt/bin {dir} ${x}:{tty}',
    'echo \\( \\` \\$x \\  \\{ \\# {dir}',
    's=$(a $(b {claude}) {dir}); t=$( ); u=$()',
    '~/bin/x {dir} ~ ~/y >~/z',
    "echo 'a $(b) `c` {print} #!* \\' {dir}",
    'echo "it\'s (a) {x} ~ * ? # ; & | < > [ ] }" {dir}',
    'claude --resume={claude} -v id={claude} x{dir}y {dir}/sub "a"{claude} {dir}:{tty}',
  ]

  expect(commands.map(command => line(command, HOSTILE))).toEqual(commands.map(command => filled(filledHostile(command))))
})

test('`${dir}` and `$dir` are the shell\'s parameters, never placeholders', () => {
  expect(line('echo ${dir} "$dir" {dir}', { dir: 'a b' })).toEqual(filled(`echo \${dir} "$dir" 'a b'`))
})

test('a placeholder inside quotes is refused, naming each placeholder there once, in a `$(…)` too', () => {
  const commands = ['cd "{dir}"', "cd '{dir}'", 'cd "x{dir}y"', "cd $(echo '{dir}')", "cd '\u0301{dir}'"]

  expect(commands.map(command => line(command))).toEqual(Array(commands.length).fill(QUOTED))
  expect(line('cd "{dir}" "{claude}" "{dir}"')).toEqual(
    refused('The resume command in Settings puts {dir} and {claude} in quotes. Remove them: SitRep quotes each value itself.'),
  )
})

test("a name in braces inside quotes that is no placeholder's is text, as awk's `'{print}'` and tmux's `'#{pane}'`", () => {
  const commands = ["awk '{print $1}' {dir}", 'echo "{x}" {dir}', "tmux display -p '#{session_name}' {dir}"]

  expect(commands.map(command => line(command, HOSTILE))).toEqual(commands.map(command => filled(filledHostile(command))))
})

test("a placeholder SitRep doesn't know is refused, naming each, and the three it knows: `{session}`, `{socket}` and `{pane}` went with the open command", () => {
  expect(line('seat open -s {session}')).toEqual(
    refused("The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
  )
  expect(line('tmux -S {socket} attach -t {pane}')).toEqual(
    refused("The resume command in Settings has {socket} and {pane}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
  )
})

test('each part but plain shell syntax is refused, named as found, pointing to a script', () => {
  const cases: [string, string][] = [
    ['echo `pwd` {dir}', 'a backtick'],
    ['( cd {dir} )', '`(`'],
    ['cd {dir} )', '`)`'],
    ['{ cd {dir}; }', '`{`'],
    ['echo {a,b} {dir}', '`{`'],
    ['echo \\{dir} && cd {dir}', '`}`'],
    ['! cd {dir}', '`!`'],
    ['ls * {dir}', '`*`'],
    ['ls a? {dir}', '`?`'],
    ['ls a[1] {dir}', '`[`'],
    ['[[ -d {dir} ]]', '`[`'],
    ['echo x] {dir}', '`]`'],
    ['cd {dir} # note', '`#`'],
    ['claude & {dir}', '`&`'],
    ['cat <<x {dir}', '`<<`'],
    ['diff <(a) {dir}', '`<(`'],
    ['tee >(a) {dir}', '`>(`'],
    ['echo $((1)) {dir}', '`$((`'],
    ['echo $[1] {dir}', '`$[`'],
    ['echo ${x:-y} {dir}', '`${x:`'],
    ['echo ${ x; } {dir}', '`${ `'],
    ['echo ${{dir}}', '`${{`'],
    ['echo ${1} {dir}', '`${1}`'],
    ["echo $'x' {dir}", "`$'`"],
    ['echo $! {dir}', '`$!`'],
    ['echo $@ {dir}', '`$@`'],
    ['echo $0 {dir}', '`$0`'],
    ['echo $# {dir}', '`$#`'],
    ['echo $#$( [ {dir} ] )', '`$#`'],
    ['echo $x:F:{dir}:h', '`$x:`'],
    ['echo $?:h {dir}', '`$?:`'],
    ['echo $1:t {dir}', '`$1:`'],
    ['echo "$x:h" {dir}', '`$x:`'],
    ['echo $10:F:{dir}:h', '`$10`'],
    ['echo $x.log {dir}', '`$x.`'],
    ['echo $x{dir}', '`$x{`'],
    ["echo $x'a' {dir}", "`$x'`"],
    ['echo "$xé" {dir}', '`$xé`'],
    ['echo $ {dir}', '`$`'],
    ['echo $${dir}', '`$${`'],
    ["echo $$'\\'x' {dir}", "`$$'`"],
    ['echo "$(pwd)" {dir}', '`$(`'],
    ['echo "$((1))" {dir}', '`$((`'],
    ['echo "a\\\\b" {dir}', '`\\\\`'],
    ['echo "!" {dir}', '`!`'],
    ['echo "$x[1]" {dir}', '`$x[`'],
    ['echo "`pwd`" {dir}', 'a backtick'],
    ['echo x >&{dir}', '`>&{`'],
    ['echo x >&- {dir}', '`>&-`'],
    ['echo x >& 1 {dir}', '`>&`'],
    ['echo x 2>&12 {dir}', '`>&12`'],
    ['echo x 2>&1{dir}', '`>&1{`'],
    ['echo x >|{dir}', '`>|`'],
    ['echo x <>{dir}', '`<>`'],
    ['cd a~b {dir}', '`~`'],
    ['cd ~/café {dir}', '`é`'],
    ['cd {dir} >', '`>`'],
    ['cd {dir} \\', '`\\`'],
  ]

  expect(cases.map(([command]) => line(command))).toEqual(cases.map(([, part]) => unchecked(part)))
})

test('a quote or a `$(…)` left open is refused, naming the innermost', () => {
  const cases: [string, string][] = [
    ['cd {dir} "x', '`"`'],
    ["cd {dir} 'x", "`'`"],
    ['cd $(echo {dir}', '`$(`'],
    ['cd $(echo "x', '`"`'],
  ]

  expect(cases.map(([command]) => line(command))).toEqual(cases.map(([, part]) => refused(`The resume command in Settings opens ${part} but never closes it.`)))
})

test('a placeholder SitRep doesn\'t know is refused before one in quotes, and one in quotes before a part it can\'t check', () => {
  expect(line('echo {session} "{dir}" `x`')).toEqual(
    refused("The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
  )
  expect(line('echo "{dir}" `x`')).toEqual(QUOTED)
})

test('every hole the reviews of 19 November 2026 and the fuzz of the 20th found, and every case probed beside one, is refused', () => {
  expect(REFUSED_COMMANDS.filter(command => line(command, HOSTILE).ok)).toEqual([])
})

test('commands made at random from plain syntax pass, each placeholder filled quoted; one holding a part refused never does', () => {
  const made = commandsOf(4_000, 20_261_120)
  const plain = made.filter(({ isPlain }) => isPlain).map(({ command }) => command)
  const holding = made.filter(({ isPlain }) => !isPlain).map(({ command }) => command)

  expect(
    plain.filter(command => {
      const filledLine = line(command, HOSTILE)

      return !filledLine.ok || filledLine.value !== filledHostile(command)
    }),
  ).toEqual([])
  expect(holding.filter(command => line(command, HOSTILE).ok)).toEqual([])
})

test('what evaluates a name or number from its argument passes as words: a command passing a placeholder to one takes that risk', () => {
  const commands = ['eval {dir}', 'let {dir}', 'read {dir}', 'declare -i n={dir}', 'printf -v {dir} x', '[ {dir} -eq 1 ]', 'shift {dir}']

  expect(commands.map(command => line(command, HOSTILE))).toEqual(commands.map(command => filled(filledHostile(command))))
})

test("the default is told by its text, the spaces round it aside: any other is the user's own", () => {
  const isDefault = (command: string) => {
    const typed = typedOf(command, NAME)

    return typed.ok && typed.value.isDefault
  }

  expect([DEFAULT_COMMAND, ` ${DEFAULT_COMMAND}\n`].map(isDefault)).toEqual([true, true])
  expect(['cd {dir} &&  claude --resume {claude}', `${DEFAULT_COMMAND} --verbose`, ''].map(isDefault)).toEqual([false, false, false])
})

test("`{tty}` is the device its Claude still runs on where it is given; otherwise empty, run as ''", () => {
  expect(line('attach {tty}', { tty: '/dev/ttys041' })).toEqual(filled("attach '/dev/ttys041'"))
  expect(line('attach {tty}')).toEqual(filled("attach ''"))
})

test('an empty command says to set one or restore the default', () => {
  expect(['', '  '].map(command => line(command))).toEqual(
    Array(2).fill(refused(`The resume command in Settings is empty. To carry ${NAME} on, set one, or restore the default.`)),
  )
})

test('a command holding a control is refused before anything else, the common ones by name, the rest by their code point', () => {
  expect(line('claude\t--resume {claude}')).toEqual(refused("The resume command in Settings has a tab, which can't be typed."))
  expect(line('cd {dir}\u0015')).toEqual(refused("The resume command in Settings has a character that can't be typed (U+0015)."))
  expect(line('cd\u001bx {dir}')).toEqual(refused("The resume command in Settings has an escape, which can't be typed."))
  expect(line('cd\t"{session}" `x`')).toEqual(refused("The resume command in Settings has a tab, which can't be typed."))
})

test('a value holding a control, or another character that prints nothing, is refused, naming the fact and the character', () => {
  const cases: [string, string][] = [
    ['\u0015', "a character that can't be typed (U+0015)"],
    ['\u0003', "a character that can't be typed (U+0003)"],
    ['\u007f', "a character that can't be typed (U+007F)"],
    ['\u001b', "an escape, which can't be typed"],
    ['\n', "a line break, which can't be typed"],
    ['\r', "a line break, which can't be typed"],
    ['\u2028', "a line break, which can't be typed"],
    ['\t', "a tab, which can't be typed"],
    ['\u0085', "a line break, which can't be typed"],
    ['\u202e', "a character that can't be typed (U+202E)"],
    ['\ud800', "a character that can't be typed (U+D800)"],
  ]

  expect(cases.map(([character]) => line('cd {dir}', { dir: `x${character}touch pwned; echo '` }))).toEqual(
    cases.map(([, words]) => refused(`For ${NAME}, the folder its Claude ran in has ${words}.`)),
  )
  expect(line('claude --resume {claude}', { claude: 'x\u0015y' })).toEqual(
    refused(`For ${NAME}, the Claude Code session's id has a character that can't be typed (U+0015).`),
  )
  expect(line('attach {tty} {dir}', { tty: '\u0015', dir: '\u0003' })).toEqual(
    refused(`For ${NAME}, the folder its Claude ran in has a character that can't be typed (U+0003).`),
  )
})

test('a fact the command does not name is never looked at', () => {
  expect(line('claude --resume {claude}', { dir: 'x\u0015', tty: '\u001b' })).toEqual(filled(`claude --resume '${W1}'`))
})

test('a window that said no folder refuses a command naming `{dir}`, as its window or its last; one naming only `{claude}` and `{tty}` runs', () => {
  const said = 'did not say which folder it ran in, as a window on an older sitrep does not, so sitrep has nothing to put for {dir}.'

  expect(lineOf(DEFAULT_COMMAND, { claude: W1, tty: '', isHeld: false }, NAME)).toEqual(refused(`${NAME}'s last window ${said}`))
  expect(lineOf(DEFAULT_COMMAND, { claude: W1, tty: '', isHeld: true }, NAME)).toEqual(refused(`${NAME}'s window ${said}`))
  expect(lineOf('claude --resume {claude} {tty}', { claude: W1, tty: '', isHeld: false }, NAME)).toEqual(filled(`claude --resume '${W1}' ''`))
})

test('a quote with a combining mark after it still opens quotes, as the shell reads it: the placeholder inside is refused', () => {
  expect(line("cd '\u0301{dir}'", { dir: 'x; touch pwned' })).toEqual(QUOTED)
  expect(line('cd {dir}\u0301', { dir: 'litware' })).toEqual(unchecked('`\u0301`'))
  expect(line("cd {dir}'\u0301'", { dir: 'litware' })).toEqual(filled("cd 'litware''\u0301'"))
})
