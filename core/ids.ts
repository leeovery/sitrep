/**
 * Ids, drawn from random bytes the front end supplies: a work's (greppable,
 * recorded in Claude's own docs) and an item's or reply's (short, unique
 * within its work).
 */

/** As many random bytes as asked: `crypto.getRandomValues` in a front end, a fixed sequence in a test. */
export type Random = (count: number) => Uint8Array

/** Crockford's base32, lowercase: no i, l, o or u to misread. 32 divides 256, so a byte maps without bias. */
const ALPHABET = '0123456789abcdefghjkmnpqrstvwxyz'

/** What marks a work id in Claude's docs, so a grep finds it. */
const WORK_PREFIX = 'sr-'

const WORK_ID_LENGTH = 6
const ITEM_ID_LENGTH = 4

/** Draws at one length before an id grows a character, so a crowded space never loops. */
const DRAWS_PER_LENGTH = 8

const WORK_ID = /^sr-[0-9a-hjkmnp-tv-z]{6,}$/

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

/** A new work id, unlike any in `taken`: `sr-` and six characters. */
export const newWorkId = (random: Random, taken: ReadonlySet<string>) =>
  fresh(random, taken, WORK_PREFIX, WORK_ID_LENGTH)

/** A new item or reply id, unlike any the work already uses. */
export const newItemId = (random: Random, taken: ReadonlySet<string>) =>
  fresh(random, taken, '', ITEM_ID_LENGTH)

/** Whether a string is a work id, as Claude passes one to join. */
export const isWorkId = (value: unknown): value is string =>
  typeof value === 'string' && WORK_ID.test(value)
