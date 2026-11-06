/**
 * Words Lee saw only as a summary, or not at all. Claude Code asks the API
 * for its thinking shown as "updates", and on Opus 5.5 a message whose prose
 * comes before a tool call can arrive with that prose inside its thinking
 * and no text block: a thinking block whose signature marks it narration
 * comes in its place, holding a one-line summary, all Lee sees of it, or
 * nothing at all (anthropics/claude-code#96288). The next tool call of the
 * main conversation that the engine runs and answers tells Claude so with
 * its result, for Claude to say again what Lee still needs.
 *
 * Each narration row of the main conversation, stored as it streams, so
 * before any call after it, waits untold until a call carries it; a new turn
 * of the main conversation lets go of what is still untold. A subagent's
 * rows and calls, and another plugin's calls, are left alone: Lee reads only
 * the main chat, and the engine drops what a plugin's own call adds.
 */
import type { AgentLoop, Args, Origin, ToolCallResult } from 'claude-code'

type Block = Args<'session.append'>['message']['content'][number]

/** The block kind a narration's signature names. */
const NARRATION = 'narration'

/** Protobuf's wire types a field of the envelope may have. */
const WIRE = { varint: 0, fixed64: 1, bytes: 2, fixed32: 5 } as const

/** A field read: its number and wire type, and where its value starts and ends, the next field starting at its end. */
type Field = { number: number; wire: number; start: number; end: number }

/** A varint at `at`, and where the bytes after it start; undefined where it runs off the end or past ten bytes. */
const varintAt = (bytes: Uint8Array, at: number) => {
  let value = 0

  for (let index = at; index < bytes.length && index < at + 10; index += 1) {
    const byte = bytes[index] ?? 0

    value += (byte & 0x7f) * 2 ** (7 * (index - at))

    if (byte < 0x80) {
      return { value, next: index + 1 }
    }
  }

  return undefined
}

/** Where the value of a field of wire type `wire` starts at `at` and ends; undefined for a wire type no field of the envelope has. */
const extentOf = (bytes: Uint8Array, wire: number, at: number) => {
  switch (wire) {
    case WIRE.varint: {
      const read = varintAt(bytes, at)

      return read && { start: at, end: read.next }
    }
    case WIRE.fixed64:
      return { start: at, end: at + 8 }
    case WIRE.fixed32:
      return { start: at, end: at + 4 }
    case WIRE.bytes: {
      const read = varintAt(bytes, at)

      return read && { start: read.next, end: read.next + read.value }
    }
    default:
      return undefined
  }
}

/** The field whose tag is at `at`; undefined where it does not parse. */
const fieldAt = (bytes: Uint8Array, at: number): Field | undefined => {
  const tag = varintAt(bytes, at)
  const extent = tag && extentOf(bytes, tag.value % 8, tag.next)

  return tag && extent && { number: Math.floor(tag.value / 8), wire: tag.value % 8, ...extent }
}

/**
 * The first length-delimited field `number` among the fields from `from` up
 * to `to`, though its value may run past `to`, the caller deciding whether
 * it needs it whole. Undefined where it is not there, or a field before it
 * does not parse or runs past `to`.
 */
const bytesField = (bytes: Uint8Array, from: number, to: number, number: number) => {
  for (let at = from; at < to;) {
    const field = fieldAt(bytes, at)

    if (field === undefined) {
      return undefined
    }

    if (field.number === number && field.wire === WIRE.bytes) {
      return field
    }

    if (field.end > to) {
      return undefined
    }

    at = field.end
  }

  return undefined
}

/**
 * How much of a signature is decoded: its envelope's header lies near the
 * front, ending some twenty bytes in on Opus 5.5 (`CAQS…`) and some 175 on
 * Fable 5 (`CAIS…`), and every thinking block's signature is read, a few
 * thousand characters each. 256 characters are 192 bytes. A multiple of
 * four, so the head is base64 whole.
 */
const SIGNATURE_HEAD = 256

/** The bytes base64 gives, or undefined where it is not base64. */
const bytesOf = (base64: string) => {
  try {
    return Uint8Array.from(atob(base64), char => char.charCodeAt(0))
  } catch {
    return undefined
  }
}

/**
 * The block kind a thinking block's signature names: field 8 of the header,
 * field 1 of the block, field 2 of the envelope (`narration`, `thinking`).
 * Undefined for anything that does not parse that far, the header whole
 * within the signature's head, as Claude Code itself reads it: an unreadable
 * signature is no narration.
 */
export const blockKindOf = (signature: string) => {
  const bytes = bytesOf(signature.slice(0, SIGNATURE_HEAD))

  if (bytes === undefined) {
    return undefined
  }

  const block = bytesField(bytes, 0, bytes.length, 2)
  const within = block && Math.min(block.end, bytes.length)
  const header = within && bytesField(bytes, block.start, within, 1)
  const kind = header && header.end <= within && bytesField(bytes, header.start, header.end, 8)

  return kind && kind.end <= header.end
    ? new TextDecoder().decode(bytes.subarray(kind.start, kind.end))
    : undefined
}

/** A block's words where it is a narration: the summary Lee saw in their place, '' where he saw nothing. */
const narrationOf = (block: Block) =>
  block.type === 'thinking' &&
  typeof block.signature === 'string' &&
  blockKindOf(block.signature) === NARRATION
    ? (typeof block.thinking === 'string' ? block.thinking : '').trim()
    : undefined

/** What Claude is asked, whichever way its words were lost. */
const SAY_AGAIN =
  'Say again, after your last tool call, whatever of them Lee still needs: a question, steps, a finding, a decision.'

/** What Claude reads with a call's result when its words reached Lee only as `summaries`, or, with none that has words, not at all. */
export const summarisedLine = (summaries: readonly string[]) => {
  const summary = summaries.filter(text => text !== '').join(' ')

  return summary === ''
    ? `Your words before this tool call never reached Lee: he saw none of them. ${SAY_AGAIN}`
    : `Your words before this tool call reached Lee only as this summary: “${summary}”. He never saw the rest. ${SAY_AGAIN}`
}

/** The main conversation's narrations not yet told to Claude, in the order they came: each the summary Lee saw, '' for none. */
let untold: readonly string[] = []

/** The main conversation's turn starting: what is still untold belongs to a turn gone by. */
export const forgetUntold = () => {
  untold = []
}

/** A response row stored: a narration of the main conversation's waits to be told. */
export const heardRow = ({
  agentId,
  message,
}: Pick<Args<'session.append'>, 'agentId' | 'message'>) => {
  if (agentId === undefined) {
    untold = [...untold, ...message.content.flatMap(block => narrationOf(block) ?? [])]
  }
}

/** Who raises a call the model made: the engine, where a plugin's own `$.tool.call` names the plugin. */
const ENGINE = 'engine'

/** A tool call as the catch sees it: its loop, and who raised it (`next.origin`). */
export type Call = AgentLoop & { origin: Origin }

/**
 * A call's result, telling Claude of the main conversation's narrations
 * still untold: the first call the engine makes on the main loop that is
 * answered, an errored answer among them, carries them all. A refusal
 * carries nothing and leaves them for the next.
 */
export const retold = <R extends ToolCallResult>({ agentId, origin }: Call, result: R): R => {
  const isMain = origin.plugin === ENGINE && agentId === undefined

  if (!isMain || untold.length === 0 || result.deny !== undefined) {
    return result
  }

  const line = summarisedLine(untold)

  untold = []

  return { ...result, context: [...(result.context ?? []), line] }
}
