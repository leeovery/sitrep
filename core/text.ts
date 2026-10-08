/** Text helpers the other modules share. */

/** Runs of whitespace, newlines among them, as single spaces, trimmed. */
export const oneLine = (text: string) => text.replace(/\s+/g, ' ').trim()

/** Orders strings by code unit: the same in every front end, whatever its locale. */
export const compareText = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0)
