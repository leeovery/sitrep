import type { On } from 'claude-code'
import { expect, test, tier, type Engine } from 'claude-code/testing'
import { blockKindOf, summarisedLine } from '../hooks/summarised'
import { AGENT } from './support'
import { world } from './world'

tier('user')

/** A narration's signature as the API signs it, cut to its envelope's header: from a live transcript of 6 November 2026. */
const NARRATION = 'CAQS6QcKEQgTGAI4AUIJbmFycmF0aW9uEgwjUJy2LNEyXvAf'

/** Ordinary thinking's signature, cut likewise. */
const THINKING = 'CAQS0RIKEAgTGAI4AUIIdGhpbmtpbmcSDJj5yxu6XU6dRD/V'

/** The summary Lee saw in place of a live test's numbered steps. */
const SUMMARY =
  "SitRep is running with the new tty lookup, so I'm running the first live test now: switching to another Space and opening the row from SitRep's card."

const BUN_TEST = { command: 'bun test', description: 'Run the tests' }

const thinking = (text: string, signature: string) => ({
  type: 'thinking',
  thinking: text,
  signature,
})

type Block = ReturnType<typeof thinking> | { type: string; [field: string]: unknown }

/** The model, beneath the mod: each request answered with no tool asked for, the test standing in for its rows and calls. */
const model = (engine: Engine, on: On) => {
  on('turn.step', async function* ($, e) {
    return {
      turnId: e.turnId,
      index: e.index,
      answer: '',
      toolUses: [],
      stopReason: 'tool_use' as const,
      usage: null,
    }
  })

  let requests = 0
  let rows = 0

  return {
    /** A model request of the main conversation, or of a subagent given its id, read to its end. */
    steps: async (agentId?: string) => {
      const response = engine.turn.step({
        turnId: 'turn-1',
        index: requests++,
        model: 'claude-opus-5-5',
        messageCount: 1,
        ...(agentId === undefined ? {} : { agentId }),
      })

      for await (const _ of response) {
        // Read to its end, as the engine does.
      }
    },
    /** A block of the response stored as its row, in the main conversation or a subagent's given its id. */
    streams: (block: Block, agentId?: string) =>
      engine.session.append({
        message: { type: 'assistant', role: 'assistant', content: [block] },
        door: 'response',
        origin: { kind: 'model', model: 'claude-opus-5-5' },
        uuid: `row-${rows++}`,
        ...(agentId === undefined ? {} : { agentId }),
      }),
  }
}

/** What Claude reads with a call's result, unseen by Lee. */
const contextOf = (answer: unknown) => (answer as { context?: readonly string[] }).context

test("blockKindOf reads the kind off a signature's envelope, and nothing off one that does not parse", () => {
  expect(blockKindOf(NARRATION)).toBe('narration')
  expect(blockKindOf(THINKING)).toBe('thinking')
  expect(blockKindOf(''), 'empty').toBeUndefined()
  expect(blockKindOf('not base64!'), 'not base64').toBeUndefined()
  expect(blockKindOf('CAQSsgcKEAgTGAI4AUII'), 'its header cut short').toBeUndefined()
  expect(blockKindOf('CAQ='), 'no block').toBeUndefined()
  expect(blockKindOf('Bw=='), 'a wire type no envelope has').toBeUndefined()
})

test("a call made by a message Lee saw only as a summary tells Claude so with its result, in the summary's words, and Lee nothing", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.steps()
  await m.streams(thinking('', THINKING))
  await m.streams(thinking(`${SUMMARY}\n\n`, NARRATION))
  await m.streams({ type: 'tool_use', id: 'toolu_1', name: 'Bash', input: BUN_TEST })

  const bash = w.calls('Bash', BUN_TEST)

  bash.finish('2 pass')

  const answer = await bash.done

  expect(answer.result).toBe('2 pass')
  expect(contextOf(answer)).toEqual([summarisedLine(SUMMARY)])
  expect(summarisedLine(SUMMARY)).toBe(
    `Your words before this tool call reached Lee only as this summary: “${SUMMARY}”. He never saw the rest. Write them again in full in your message after your last tool call.`,
  )
})

test("sitrep's own tools, whose calls end most turns, carry it too", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.steps()
  await m.streams(thinking(SUMMARY, NARRATION))

  const answer = await w.call('ask', { wants: 'yes', yes: 'It works', title: 'Try the jump' })

  expect(contextOf(answer)).toEqual([summarisedLine(SUMMARY)])
})

test("a message's calls tell Claude once, and the next message starts afresh", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.steps()
  await m.streams(thinking(SUMMARY, NARRATION))

  const first = await w.call('status', { now: ['Testing the jump'] })
  const second = await w.call('note', { text: 'Started the live test' })

  await m.steps()

  const next = await w.call('note', { text: 'Finished the live test' })

  expect(contextOf(first)).toEqual([summarisedLine(SUMMARY)])
  expect(contextOf(second), 'the same message').toBeUndefined()
  expect(contextOf(next), 'a message with no summary').toBeUndefined()
})

test('a message with several summaries tells Claude them all, in the order they came', async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.steps()
  await m.streams(thinking('Merged it.', NARRATION))
  await m.streams(thinking('Testing it live.', NARRATION))

  expect(contextOf(await w.call('note', { text: 'Merged the jump' }))).toEqual([
    summarisedLine('Merged it. Testing it live.'),
  ])
})

test('ordinary thinking, a narration with no words, and a signature that does not parse tell Claude nothing', async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.steps()
  await m.streams(thinking('Weighing the two edges.', THINKING))
  await m.streams(thinking(' \n', NARRATION))
  await m.streams(thinking(SUMMARY, 'not base64!'))
  await m.streams({ type: 'text', text: SUMMARY })

  expect(contextOf(await w.call('note', { text: 'Weighed the edges' }))).toBeUndefined()
})

test('a refused call carries nothing, and the next call of its message tells Claude', async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.steps()
  await m.streams(thinking(SUMMARY, NARRATION))

  const refused = await w.call('resolve', { item: 'zzzz' })
  const bash = w.calls('Bash', BUN_TEST)

  bash.finish()

  expect(refused.deny).toBeDefined()
  expect(contextOf(refused)).toBeUndefined()
  expect(contextOf(await bash.done)).toEqual([summarisedLine(SUMMARY)])
})

test("a subagent's summaries and calls tell Claude nothing, and leave the main conversation's message as it was", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.steps()
  await m.streams(thinking(SUMMARY, NARRATION))
  await m.steps(AGENT)
  await m.streams(thinking('Reviewing the diff.', NARRATION), AGENT)

  const theirs = w.calls('Bash', BUN_TEST, { agentId: AGENT })

  theirs.finish()

  expect(contextOf(await theirs.done)).toBeUndefined()
  expect(contextOf(await w.call('note', { text: 'Reviewed the diff' }))).toEqual([
    summarisedLine(SUMMARY),
  ])
})

test("a subagent's summary alone tells the main conversation nothing", async ($, on) => {
  const w = world($, on)
  const m = model($, on)

  await w.begin()
  await m.steps()
  await m.streams(thinking('Reviewing the diff.', NARRATION), AGENT)

  expect(contextOf(await w.call('note', { text: 'Reviewed the diff' }))).toBeUndefined()
})
