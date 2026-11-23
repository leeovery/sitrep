/**
 * Ids, drawn from random bytes the front end supplies: a session's
 * (greppable, recorded in Claude's own docs) and an item's or reply's
 * (short, unique within its session).
 */

/** As many random bytes as asked: `crypto.getRandomValues` in a front end, a fixed sequence in a test. */
export type Random = (count: number) => Uint8Array

/** Crockford's base32, lowercase: no i, l, o or u to misread. 32 divides 256, so a byte maps without bias. */
const ALPHABET = '0123456789abcdefghjkmnpqrstvwxyz'

/** What marks a session id in Claude's docs, so a grep finds it. */
const SESSION_PREFIX = 'sr-'

const SESSION_ID_LENGTH = 6
const ITEM_ID_LENGTH = 4

/** Draws at one length before an id grows a character, so a crowded space never loops. */
const DRAWS_PER_LENGTH = 8

const SESSION_ID = /^sr-[0-9a-hjkmnp-tv-z]{6,}$/

const draw = (random: Random, length: number) =>
  Array.from(random(length), byte => ALPHABET[byte % ALPHABET.length]).join('')

/** A fresh id: `prefix` and `length` characters, longer only once draws keep landing on taken ones. */
const fresh = (random: Random, taken: ReadonlySet<string>, prefix: string, length: number) => {
  for (let size = length; ; size++) {
    for (let attempt = 0; attempt < DRAWS_PER_LENGTH; attempt++) {
      const id = `${prefix}${draw(random, size)}`

      if (!taken.has(id)) {
        return id
      }
    }
  }
}

/** A new session id, unlike any in `taken`: `sr-` and six characters. */
export const newSessionId = (random: Random, taken: ReadonlySet<string>) =>
  fresh(random, taken, SESSION_PREFIX, SESSION_ID_LENGTH)

/** A new item or reply id, unlike any the session already uses. */
export const newItemId = (random: Random, taken: ReadonlySet<string>) =>
  fresh(random, taken, '', ITEM_ID_LENGTH)

/** How long a saved attachment's name is: enough that two never meet, with no list of the taken to check. */
const MEDIA_NAME_LENGTH = 16

/** A new name for a saved attachment's file. */
export const newMediaName = (random: Random) => draw(random, MEDIA_NAME_LENGTH)

/** Whether a string is a session id, as Claude passes one to join. */
export const isSessionId = (value: unknown): value is string =>
  typeof value === 'string' && SESSION_ID.test(value)
