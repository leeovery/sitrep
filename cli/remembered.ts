/**
 * Each device's Ghostty terminal, as the last knock on it found, so a later
 * jump focuses it by its id, with no listing and no knock. A terminal keeps
 * its device for its life, so an id that still names a terminal names the
 * one on that device.
 *
 * Kept in sitrep's folder beside `projects/`, which is all the mod and the
 * CLI list there, so nothing reading the board meets it. The CLI's file
 * system only appends, so each knock that answers adds a line, and the last
 * line for a device wins.
 */
import { isFilled, isObject, rootOf, tornLineEnd } from '../core'
import type { Io } from './io'

/** Each device's terminal id, by its device. */
export type Remembered = ReadonlyMap<string, string>

export const REMEMBERED_FILE = 'ghostty-terminals.jsonl'

/** Where they are kept: `<sitrep's folder>/ghostty-terminals.jsonl`. */
export const rememberedPath = (io: Io) => `${rootOf(io.env)}/${REMEMBERED_FILE}`

/** A device and its terminal's id, as a line. */
export const rememberedText = (device: string, terminal: string) =>
  `${JSON.stringify({ device, terminal })}\n`

/** A line as its device and terminal; undefined for a line torn, broken, or not a pair. */
const decode = (line: string): [device: string, terminal: string] | undefined => {
  let raw: unknown

  try {
    raw = JSON.parse(line)
  } catch {
    return undefined
  }

  return isObject(raw) && isFilled(raw.device) && isFilled(raw.terminal)
    ? [raw.device, raw.terminal]
    : undefined
}

/** The file's text as each device's terminal, the last line for a device winning. */
export const parseRemembered = (text: string): Remembered =>
  new Map(
    text.split('\n').flatMap(line => {
      const pair = decode(line)

      return pair === undefined ? [] : [pair]
    }),
  )

/** Each device's terminal as the file holds them; none while it is not there or cannot be read. */
export const readRemembered = async (io: Io): Promise<Remembered> =>
  parseRemembered(await io.fs.read(rememberedPath(io)).catch(() => ''))

/** Adds the terminal a knock found on the device, ending first a last line left torn, as core's append does. */
export const remember = async (io: Io, device: string, terminal: string) => {
  const path = rememberedPath(io)
  const text = await io.fs.read(path).catch(() => '')

  await io.fs.append(path, `${tornLineEnd(text)}${rememberedText(device, terminal)}`)
}
