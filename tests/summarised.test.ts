import type { On, ToolCallResult } from 'claude-code'
import { expect, test, tier, type Engine, type Plugin } from './kit'
import { blockKindOf, forgetUntold, heardRow, retold, summarisedLine } from '../hooks/summarised'
import { AGENT } from './support'
import { world } from './world'

tier('user')

/** A narration's signature as the API signs it, cut to its envelope's header: from a live transcript of 6 November 2026. */
const NARRATION = 'CAQS6QcKEQgTGAI4AUIJbmFycmF0aW9uEgwjUJy2LNEyXvAf'

/** Ordinary thinking's signature, cut likewise. */
const THINKING = 'CAQS0RIKEAgTGAI4AUIIdGhpbmtpbmcSDJj5yxu6XU6dRD/V'

/** A narration's signature on Fable 5, whose envelope's header ends some 175 bytes in, cut to the 256 characters read of it: from a live transcript. */
const FABLE_NARRATION =
  'CAISjwQKqAEIERgCKkDft0G0qDcL9bwdVJwZdLJ/Df6EkXNx2p1nyssp9cp/OSiNGd17qsvCYF1j4zGOM7y5g2WjDrpkGhUN76hQPVJmMg5jbGF1ZGUtZmFibGUtNTgBQgluYXJyYXRpb25aJDM3YWJjNzhjLTdiMjUtNDM4Yy05MGQ2LTY4OGFhMGE4Yjk1NnIQ4z/gznuGJGYNKWzGTl1aj4gBAagB5LXA1AawAQISDEt8ImpG5WfgvsZ0MhoM'

const varint = (value: number) => (value < 0x80 ? [value] : [(value & 0x7f) | 0x80, value >> 7])

/** A whole signature naming `kind`, its header widened by a field of `filler` bytes ahead of the kind. */
const signedWide = (kind: string, filler: number) => {
  const text = [...kind].map(char => char.charCodeAt(0))
  const header = [0x0a, ...varint(filler), ...Array(filler).fill(0x41), 0x42, text.length, ...text]
  const block = [0x0a, ...varint(header.length), ...header, 0x12, 12, ...Array(12).fill(0x42)]
  const tail = Array(600).fill(0x43)

  return btoa(
    String.fromCharCode(0x08, 0x02, 0x12, ...varint(block.length + tail.length), ...block, ...tail),
  )
}

/** The summary Lee saw in place of a live test's numbered steps. */
const SUMMARY =
  "SitRep is running with the new tty lookup, so I'm running the first live test now: switching to another Space and opening the row from SitRep's card."

/** What every form of the line asks of Claude. */
const SAY_AGAIN =
  'Say again, after your last tool call, whatever of them Lee still needs: a question, steps, a finding, a decision.'

const BUN_TEST = { command: 'bun test', description: 'Run the tests' }

/** Who raises a call the model made. */
const ENGINE = { plugin: 'engine', tier: 'core' } as const

const thinking = (text: string, signature: string) => ({
  type: 'thinking',
  thinking: text,
  signature,
})

type Block = ReturnType<typeof thinking> | { type: string; [field: string]: unknown }

/** A Read of a file whose path says how it ends beneath the mod: in an error, or answered with core's extras. */
const READ_FAILS = { tool: 'Read', file_path: '/missing' }
const READ = { tool: 'Read', file_path: '/notes.md' }

/** Core's answer to a Read, with the extras only core sets. */
const READ_ANSWER = { result: 'notes', ref: 7, text: 'notes', isReadOnly: true }

/** The model's rows, and core answering the Reads, beneath the mod; registered before the test first calls the engine. */
const model = (engine: Engine, on: On) => {
  on('tool.call', { tool: 'Read' }, ($, e) =>
    (e as { file_path?: string }).file_path === READ_FAILS.file_path
      ? ({ isError: true, result: 'File does not exist.', text: 'File does not exist.' } as never)
      : (READ_ANSWER as never),
  )

  let rows = 0

  return {
    /** A block of the response stored as its row, in the main conversation or a subagent's given its id. */
    streams: (block: Block, agentId?: string) =>
      engine.session.append({
        message: { type: 'assistant', role: 'assistant', content: [block] },
        door: 'response',
        origin: { kind: 'model', model: 'claude-opus-5-5' },
        uuid: `row-${rows++}`,
        ...(agentId === undefined ? {} : { agentId }),
      }),
    /** A call the engine runs from the main conversation, as the model made it. */
    reads: (read: typeof READ) => engine.tool.call(read as never),
  }
}

/** What Claude reads with a call's result, unseen by Lee. */
const contextOf = (answer: unknown) => (answer as { context?: readonly string[] }).context

test("blockKindOf reads the kind off a signature's envelope, and nothing off one that does not parse", () => {
  expect(blockKindOf(NARRATION)).toBe('narration')
  expect(blockKindOf(THINKING)).toBe('thinking')
  expect(blockKindOf(`${NARRATION}${'A'.repeat(2_000)}`), 'whole, read by its head').toBe(
    'narration',
  )
  expect(blockKindOf(FABLE_NARRATION), "Fable's wider header").toBe('narration')
  expect(blockKindOf(signedWide('narration', 150)), 'a header ending 172 bytes in').toBe(
    'narration',
  )
  expect(
    blockKindOf(signedWide('narration', 200)),
    "a header ending 222 bytes in, past the head's 192",
  ).toBeUndefined()
  expect(blockKindOf(''), 'empty').toBeUndefined()
  expect(blockKindOf('not base64!'), 'not base64').toBeUndefined()
  expect(blockKindOf('CAQSsgcKEAgTGAI4AUII'), 'its header cut short').toBeUndefined()
  expect(blockKindOf('CAQ='), 'no block').toBeUndefined()
  expect(blockKindOf('Bw=='), 'a wire type no envelope has').toBeUndefined()
})

test('the line quotes what Lee saw of the words, or says he saw none of them, and asks for what he still needs', () => {
  expect(summarisedLine([SUMMARY])).toBe(
    `Your words before this tool call reached Lee only as this summary: “${SUMMARY}”. He never saw the rest. ${SAY_AGAIN}`,
  )
  expect(summarisedLine(['', 'Merged it.', '', 'Testing it live.'])).toBe(
    `Your words before this tool call reached Lee only as this summary: “Merged it. Testing it live.”. He never saw the rest. ${SAY_AGAIN}`,
  )
  expect(summarisedLine(['', ''])).toBe(
    `Your words before this tool call never reached Lee: he saw none of them. ${SAY_AGAIN}`,
  )
})

test("a call after words Lee saw only as a summary tells Claude so with its result, in the summary's words", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.streams(thinking('', THINKING))
  await m.streams(thinking(`${SUMMARY}\n\n`, NARRATION))
  await m.streams({ type: 'tool_use', id: 'toolu_1', name: 'Bash', input: BUN_TEST })

  const bash = w.calls('Bash', BUN_TEST)

  bash.finish('2 pass')

  const answer = await bash.done

  expect(answer.result).toBe('2 pass')
  expect(contextOf(answer)).toEqual([summarisedLine([SUMMARY])])
})

test('a narration with no words tells Claude that Lee saw none of them', async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.streams(thinking('', THINKING))
  await m.streams(thinking('', NARRATION))

  const answer = await w.call('ask', { wants: 'yes', yes: 'Go', title: 'Give the go' })

  expect(contextOf(answer)).toEqual([summarisedLine([''])])
})

test("sitrep's own tools, whose calls end most turns, carry it", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.streams(thinking(SUMMARY, NARRATION))

  const answer = await w.call('ask', { wants: 'yes', yes: 'It works', title: 'Try the jump' })

  expect(contextOf(answer)).toEqual([summarisedLine([SUMMARY])])
})

test('two summarised messages in one turn are each told once, on the call after them', async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await w.turnStarts('Carry on.')
  await m.streams(thinking('Merged it.', NARRATION))

  const first = await w.call('status', { now: ['Testing the jump'] })
  const second = await w.call('note', { text: 'Started the live test' })

  await m.streams(thinking('Testing it live.', NARRATION))

  const third = await w.call('note', { text: 'Finished the live test' })
  const fourth = await w.call('note', { text: 'Wrote it up' })

  expect(contextOf(first)).toEqual([summarisedLine(['Merged it.'])])
  expect(contextOf(second), 'told already').toBeUndefined()
  expect(contextOf(third)).toEqual([summarisedLine(['Testing it live.'])])
  expect(contextOf(fourth), 'told already').toBeUndefined()
})

test('ordinary thinking, with words or without, a signature that does not parse, and text tell Claude nothing', async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.streams(thinking('Weighing the two edges.', THINKING))
  await m.streams(thinking('', THINKING))
  await m.streams(thinking(SUMMARY, 'not base64!'))
  await m.streams({ type: 'text', text: SUMMARY })

  expect(contextOf(await w.call('note', { text: 'Weighed the edges' }))).toBeUndefined()
})

test('a refused call carries nothing, and what it left untold rides the next call that settles', async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await w.turnStarts('Carry on.')
  await m.streams(thinking(SUMMARY, NARRATION))

  const refused = await w.call('ask', { wants: 'choice', title: 'Keep it?', options: ['Keep'] })
  const next = await w.call('ask', {
    wants: 'choice',
    title: 'Keep it?',
    options: ['Keep', 'Drop'],
  })

  expect(refused.deny).toBeDefined()
  expect(contextOf(refused)).toBeUndefined()
  expect(contextOf(next)).toEqual([summarisedLine([SUMMARY])])
})

test('an errored call carries it, as an answered one does', async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.streams(thinking(SUMMARY, NARRATION))

  const failed = await m.reads(READ_FAILS)
  const after = await m.reads(READ)

  expect(failed).toMatchObject({ isError: true, text: 'File does not exist.' })
  expect(contextOf(failed)).toEqual([summarisedLine([SUMMARY])])
  expect(contextOf(after), 'told already').toBeUndefined()
})

test("the line rides core's answer as it came: its ref, text and read-only mark untouched", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.streams(thinking(SUMMARY, NARRATION))

  expect(await m.reads(READ)).toEqual({ ...READ_ANSWER, context: [summarisedLine([SUMMARY])] })
})

test("a turn of the main conversation starting lets go of what is still untold; a subagent's run does not", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.streams(thinking(SUMMARY, NARRATION))
  await w.agentRunStarts(AGENT)

  expect(contextOf(await w.call('note', { text: 'Reviewed the diff' }))).toEqual([
    summarisedLine([SUMMARY]),
  ])

  await m.streams(thinking('Testing it live.', NARRATION))
  await w.turnStarts('Carry on.')

  expect(contextOf(await w.call('note', { text: 'Started over' }))).toBeUndefined()
})

test("a subagent's narrations and calls tell Claude nothing, and leave the main conversation's untold as it was", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.streams(thinking(SUMMARY, NARRATION))
  await m.streams(thinking('Reviewing the diff.', NARRATION), AGENT)

  const theirs = w.calls('Bash', BUN_TEST, { agentId: AGENT })

  theirs.finish()

  expect(contextOf(await theirs.done)).toBeUndefined()
  expect(contextOf(await w.call('note', { text: 'Reviewed the diff' }))).toEqual([
    summarisedLine([SUMMARY]),
  ])
})

/** Another plugin, whose `/probe` makes a call of its own: a Read, as the model's below. */
const PROBE: Plugin = {
  name: 'probe',
  register(on) {
    on('command.run', { command: 'probe' }, async $ => {
      await $.tool.call({ tool: 'Read', file_path: '/notes.md' })

      return {}
    })
  },
}

test(
  "another plugin's own call, raised through the hooks, leaves what is untold for the engine's next call",
  { plugins: [PROBE] },
  async ($, on) => {
    const w = world($, on)
    const m = model($, on)

    await w.begin()
    await m.streams(thinking(SUMMARY, NARRATION))
    await $.command.run({
      command: 'probe',
      args: '',
      origin: { kind: 'composer' },
      presentation: { isFullscreen: true, columns: 160 },
    })

    expect(contextOf(await m.reads(READ))).toEqual([summarisedLine([SUMMARY])])
  },
)

test("another plugin's own call gets nothing, the engine dropping what it adds, and leaves it for the engine's next call", () => {
  const answered: ToolCallResult = { result: 'done' }

  forgetUntold()
  heardRow({ message: { type: 'assistant', content: [thinking(SUMMARY, NARRATION)] } })

  expect(retold({ origin: { plugin: 'portal', tier: 'user' } }, answered)).toBe(answered)
  expect(retold({ origin: ENGINE }, answered)).toEqual({
    result: 'done',
    context: [summarisedLine([SUMMARY])],
  })
})
