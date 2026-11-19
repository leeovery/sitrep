/**
 * What the panel asks the terminal of its colours, and what it reads from
 * the answer: its foreground (OSC 10) and background (OSC 11), then its
 * device attributes (DA1), which every terminal answers, so a terminal that
 * says nothing of its colours is known by its answering DA1 alone.
 *
 * - A colour comes as `rgb:` and 1 to 4 hex digits a channel, ended by
 *   `BEL` or `ST`, and is scaled to 8 bits a channel.
 * - A colour the answer doesn't give is left out of the paint: the dims are
 *   faint without it.
 */
import type { Level, Paint, Rgb } from './paint'

/** OSC 10 and OSC 11, asking for the foreground and the background, then DA1. */
export const COLOUR_QUERY = '\x1b]10;?\x07\x1b]11;?\x07\x1b[c'

/** A colour in an OSC 10 or OSC 11 answer: which, then its three channels. */
const ANSWER = /\x1b\]1([01]);rgb:([0-9a-f]{1,4})\/([0-9a-f]{1,4})\/([0-9a-f]{1,4})(?:\x07|\x1b\\)/gi

/** A channel of 1 to 4 hex digits, scaled to 0 to 255. */
const channel = (hex: string) => Math.round((Number.parseInt(hex, 16) / (16 ** hex.length - 1)) * 255)

/** The terminal's foreground and background, as its answer gives them, at the level the environment says. */
export const paintOf = (level: Level, answer: string): Paint => {
  const colours = new Map<string, Rgb>()

  for (const [, which = '', red = '', green = '', blue = ''] of answer.matchAll(ANSWER)) {
    colours.set(which, [channel(red), channel(green), channel(blue)])
  }

  const fg = colours.get('0')
  const bg = colours.get('1')

  return { level, ...(fg === undefined ? {} : { fg }), ...(bg === undefined ? {} : { bg }) }
}
