/** Text helpers the other modules share. */

/** Runs of whitespace, newlines among them, as single spaces, trimmed. */
export const oneLine = (text: string) => text.replace(/\s+/g, ' ').trim()

/** Orders strings by code unit: the same in every front end, whatever its locale. */
export const compareText = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0)

/** Things in plain words: `a`, `a and b`, `a, b and c`; or `a or b`, given `or`. */
export const inWords = (things: readonly string[], conjunction = 'and') =>
  things.length < 2
    ? things.join('')
    : `${things.slice(0, -1).join(', ')} ${conjunction} ${things.at(-1)}`
