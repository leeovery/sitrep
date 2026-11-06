/**
 * Words Lee saw only as a summary. Claude Code asks the API for its
 * thinking shown as "updates", and on Opus 5.5 a message whose prose comes
 * before a tool call can arrive with that prose inside its thinking and no
 * text block: the server sends a one-line summary in its place, a thinking
 * block whose signature marks it narration, and that summary is all Lee sees
 * (anthropics/claude-code#96288). A tool call of the main conversation made
 * by such a message tells Claude so with its result, once a message, for
 * Claude to write the words again after its last tool call.
 *
 * The model's requests mark where one message ends and the next begins; a
 * narration row of the main conversation, stored as it streams and so before
 * any tool call it makes, gives the message its summary. A subagent's
 * requests, rows and calls are left alone: Lee reads only the main chat.
 */
import type { AgentLoop, Args, ToolCallResult } from 'claude-code'

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
 * Undefined for anything that does not parse that far, the header whole, as
 * Claude Code itself reads it: an unreadable signature is no narration.
 */
export const blockKindOf = (signature: string) => {
  const bytes = bytesOf(signature)

  if (bytes === undefined) {
    return undefined
  }

  const block = bytesField(bytes, 0, bytes.length, 2)
  const header = block && bytesField(bytes, block.start, Math.min(block.end, bytes.length), 1)
  const kind =
    header && header.end <= bytes.length && bytesField(bytes, header.start, header.end, 8)

  return kind && kind.end <= header.end
    ? new TextDecoder().decode(bytes.subarray(kind.start, kind.end))
    : undefined
}

/** A block's text where it is a narration with some: the summary Lee saw in place of the words. */
const narrationOf = (block: Block) =>
  block.type === 'thinking' &&
  typeof block.thinking === 'string' &&
  typeof block.signature === 'string' &&
  block.thinking.trim() !== '' &&
  blockKindOf(block.signature) === NARRATION
    ? block.thinking.trim()
    : undefined

/** What Claude reads with a call's result when its message reached Lee only as `summary`. */
export const summarisedLine = (summary: string) =>
  `Your words before this tool call reached Lee only as this summary: “${summary}”. He never saw the rest. Write them again in full in your message after your last tool call.`

/** The main conversation's message now streaming: the summaries Lee saw in place of its words, and whether Claude was told. */
let streaming: { summaries: readonly string[]; isTold: boolean } = { summaries: [], isTold: false }

/** A model request of a loop: one of the main conversation's starts its message afresh. */
export const heardStep = ({ agentId }: AgentLoop) => {
  if (agentId === undefined) {
    streaming = { summaries: [], isTold: false }
  }
}

/** A response row stored: a narration of the main conversation's adds to its message's summaries. */
export const heardRow = ({
  agentId,
  message,
}: Pick<Args<'session.append'>, 'agentId' | 'message'>) => {
  if (agentId === undefined) {
    const summaries = message.content.flatMap(block => narrationOf(block) ?? [])

    streaming = { ...streaming, summaries: [...streaming.summaries, ...summaries] }
  }
}

/**
 * A call's result, telling Claude where the main conversation's message that
 * made it reached Lee only as a summary: the first result of that message's
 * calls that can carry it. A refusal carries nothing.
 */
export const retold = <R extends ToolCallResult>({ agentId }: AgentLoop, result: R): R => {
  const { summaries, isTold } = streaming

  if (agentId !== undefined || summaries.length === 0 || isTold || result.deny !== undefined) {
    return result
  }

  streaming = { ...streaming, isTold: true }

  return { ...result, context: [...(result.context ?? []), summarisedLine(summaries.join(' '))] }
}
