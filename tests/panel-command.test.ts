import { expect, test } from './kit'
import { DEFAULT_COMMAND, isDefault, lineOf, shellQuoted, type ResumeFacts } from '../cli/panel/command'
import { HOME, W1 } from './data'

/**
 * The resume command, read, refused and filled as SitRep's TypedCommand
 * does it, held to the cases its Swift tests hold (TypedCommandTests,
 * ResumeCommandTests): a session's name or folder never runs as code.
 */
const NAME = 'Invoice ledger'

const FOLDER = `${HOME}/Code/litware`

const facts = (given: Partial<ResumeFacts> = {}): ResumeFacts => ({ claude: W1, dir: FOLDER, tty: '', isHeld: false, ...given })

/** The line for the command, its window's folder given, or why none runs. */
const line = (command: string, given: Partial<ResumeFacts> = {}) => lineOf(command, facts(given), NAME)

const filled = (value: string) => ({ ok: true, value })

const refused = (error: string) => ({ ok: false, error })

const QUOTED = refused('The resume command in Settings puts {dir} in quotes or backticks. Remove them: SitRep quotes each value itself.')

const EVALUATED = refused(
  'The resume command in Settings puts {dir} in arithmetic or a subscript, where the shell runs what is in a value even quoted. Move it out.',
)

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
  ]

  expect(cases.map(([value]) => shellQuoted(value))).toEqual(cases.map(([, quoted]) => quoted))
})

test('each placeholder is filled, quoted, every time it is named', () => {
  expect(line('cd {dir} # {dir}', { dir: 'litware · card' })).toEqual(filled("cd 'litware · card' # 'litware · card'"))
})

test("the shell's own braces, `{a,b}` and the group `{ x; }`, are no placeholders and stay as written", () => {
  expect(line('{ cd {dir}; } && echo {a,b}', { dir: 'litware' })).toEqual(filled("{ cd 'litware'; } && echo {a,b}"))
})

test("a brace after a `$`, a `#` or a backslash is no placeholder: the shell's `${…}`, tmux's `#{…}`, an escaped brace", () => {
  const commands = [
    'echo ${HOME} && cd {dir}',
    "tmux display -p '#{session_name}'; cd {dir}",
    'tmux display -p x#{pane}; cd {dir}',
    'echo \\{dir} && cd {dir}',
    'echo ${dir} && cd {dir}',
  ]

  expect(commands.map(command => line(command, { dir: 'a b' }))).toEqual(
    commands.map(command => filled(command.replace('cd {dir}', "cd 'a b'"))),
  )
})

test('a placeholder joined to unquoted text is filled, one shell word with it', () => {
  const cases: [string, string][] = [
    ['claude --resume={claude}', `claude --resume='${W1}'`],
    ['awk -v id={claude}', `awk -v id='${W1}'`],
    ['cd x{dir}y;', `cd x'${FOLDER}'y;`],
    ['cd {dir}/sub', `cd '${FOLDER}'/sub`],
    ['echo "a"{claude}', `echo "a"'${W1}'`],
  ]

  expect(cases.map(([command]) => line(command))).toEqual(cases.map(([, filledLine]) => filled(filledLine)))
})

test('a placeholder inside quotes is refused, naming each placeholder there once', () => {
  expect(['cd "{dir}"', "cd '{dir}'", "cd $'{dir}'", 'cd "x{dir}y"'].map(command => line(command))).toEqual(Array(4).fill(QUOTED))
  expect(line("awk -v id='{claude}'")).toEqual(
    refused('The resume command in Settings puts {claude} in quotes or backticks. Remove them: SitRep quotes each value itself.'),
  )
  expect(line('cd "{dir}" "{claude}" "{dir}"')).toEqual(
    refused('The resume command in Settings puts {dir} and {claude} in quotes or backticks. Remove them: SitRep quotes each value itself.'),
  )
})

test("an escaped `$`, or `$$`, opens no `$'…'`: the quote after it is a plain one, so a placeholder after it is in quotes, refused", () => {
  expect(["cd \\$'\\'X'{dir}'", "cd $$'\\'X'{dir}'"].map(command => line(command, { dir: 'a; touch pwned; ' }))).toEqual([QUOTED, QUOTED])
})

test('a placeholder in backticks is refused, as in quotes: bash scans for the closing backtick before any quoting inside', () => {
  const commands = ['cd `echo {dir} `', 'cd "`echo {dir} `"', 'x `a` `{dir}`']

  expect(commands.map(command => line(command, { dir: 'litware · card`;touch PWNED;' }))).toEqual(Array(3).fill(QUOTED))
})

test('a placeholder in arithmetic or a subscript is refused, saying why: the shell runs a `$(…)` there even in a quoted value', () => {
  const commands = [
    'echo $(( {dir} ))',
    '(( x = {dir} ))',
    'echo $(( 1 + ({dir}) ))',
    'echo $[ {dir} ]',
    'echo ${a[{dir}]}',
    'a[{dir}]=1',
    'echo $a[{dir}]',
    'echo "$(( {dir} ))"',
  ]

  expect(commands.map(command => line(command, { dir: '/x$(touch pwned)' }))).toEqual(Array(commands.length).fill(EVALUATED))
})

test("arithmetic and subscripts closed before a placeholder, a test's brackets, `$(…)` and `${…}` leave it filled; DESIGN's examples stand", () => {
  const commands = [
    'echo $(( 1 + (2) )) && cd {dir}',
    'echo ${a[1]} && cd {dir}',
    '[ -d {dir} ] && cd {dir}',
    '[[ -d {dir} ]] && cd {dir}',
    'cd $(echo x) {dir}',
    'cd ${x:-{dir}}',
    'cd `pwd` && cd {dir}',
    'echo "it\'s" && cd {dir}',
    'echo \'say "hi"\' && cd {dir}',
    'echo "a\\"b" && cd {dir}',
    "echo $'it\\'s' && cd {dir}",
  ]

  expect(commands.filter(command => !line(command).ok)).toEqual([])
})

/** Lee's Portal one-liner and tmux by `{tty}`, as DESIGN records them. */
const PORTAL =
  's=$(portal hook list | awk -F\'\\t\' -v id={claude} \'index($3, "--resume " id) {print $1; exit}\'); [ -n "$s" ] && portal open -s "$s" || portal open -p {dir} -- claude --resume {claude}'

const TMUX =
  't=$(tmux list-panes -a -F \'#{pane_tty} #{session_name}\' | awk -v d={tty} \'$1==d {print $2; exit}\'); [ -n "$t" ] && tmux attach -t "$t" || tmux new -c {dir} claude --resume {claude}'

test("DESIGN's examples fill exactly as written: the Portal one-liner, and tmux by `{tty}`, its device or ''", () => {
  const dir = `${HOME}/Code/fabrikam`
  const tmuxed = (tty: string) =>
    `t=$(tmux list-panes -a -F '#{pane_tty} #{session_name}' | awk -v d='${tty}' '$1==d {print $2; exit}'); [ -n "$t" ] && tmux attach -t "$t" || tmux new -c '${dir}' claude --resume '${W1}'`

  expect(line(PORTAL, { dir })).toEqual(
    filled(
      `s=$(portal hook list | awk -F'\\t' -v id='${W1}' 'index($3, "--resume " id) {print $1; exit}'); [ -n "$s" ] && portal open -s "$s" || portal open -p '${dir}' -- claude --resume '${W1}'`,
    ),
  )
  expect(line(TMUX, { dir, tty: '/dev/ttys041' })).toEqual(filled(tmuxed('/dev/ttys041')))
  expect(line(TMUX, { dir })).toEqual(filled(tmuxed('')))
})

test("the default resumes the conversation in its folder, a `'` in the folder's name closed and opened again", () => {
  expect(DEFAULT_COMMAND).toBe('cd {dir} && claude --resume {claude}')
  expect(line(DEFAULT_COMMAND, { dir: `${HOME}/Code/team's work` })).toEqual(filled(`cd '${HOME}/Code/team'\\''s work' && claude --resume '${W1}'`))
})

test('the default is told by its text, the spaces round it aside: any other is the user\'s own', () => {
  expect([DEFAULT_COMMAND, ` ${DEFAULT_COMMAND}\n`].map(isDefault)).toEqual([true, true])
  expect(['cd {dir} &&  claude --resume {claude}', `${DEFAULT_COMMAND} --verbose`, ''].map(isDefault)).toEqual([false, false, false])
})

test("`{tty}` is the device its Claude still runs on where it is given; otherwise empty, run as ''", () => {
  expect(line('attach {tty}', { tty: '/dev/ttys041' })).toEqual(filled("attach '/dev/ttys041'"))
  expect(line('attach {tty}')).toEqual(filled("attach ''"))
})

test("a placeholder SitRep doesn't know is refused, naming each, and the three it knows: `{session}`, `{socket}` and `{pane}` went with the open command", () => {
  expect(line('portal open -s {session}')).toEqual(
    refused("The resume command in Settings has {session}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
  )
  expect(line('tmux -S {socket} attach -t {pane}')).toEqual(
    refused("The resume command in Settings has {socket} and {pane}, which SitRep doesn't know. It knows {claude}, {dir} and {tty}."),
  )
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
  expect(line('cd\t"{session}"')).toEqual(refused("The resume command in Settings has a tab, which can't be typed."))
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
  expect(line('cd {dir}\u0301', { dir: 'litware' })).toEqual(filled("cd 'litware'\u0301"))
})
