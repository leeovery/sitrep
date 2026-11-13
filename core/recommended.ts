/**
 * The option of a choice ask Claude recommends, as its `recommended` says,
 * or as Claude still types it into the option: "recommended" at the
 * option's end, read as the field and stripped, so the option's own words
 * never carry it and every surface marks it once, beside the option.
 */

/** "recommended" ending an option, any case, in parentheses or brackets, or after a dash a space sets off; something before it. */
const MARKER = /^(.*\S)(?:\s*\(recommended\)|\s*\[recommended\]|\s+[-–—]\s*recommended)$/i

/** An option's words, a marker typed at their end stripped, and whether they carried one. */
export const unmarked = (option: string): { text: string; isMarked: boolean } => {
  const before = MARKER.exec(option)?.[1]

  return before === undefined ? { text: option, isMarked: false } : { text: before, isMarked: true }
}

/** A choice's options, each one line already, their markers stripped and repeats then dropped; and those that carried a marker. */
export const readOptions = (given: readonly string[]) => {
  const read = given.map(unmarked)
  const distinct = (texts: readonly string[]) => [...new Set(texts)]

  return {
    options: distinct(read.map(each => each.text)),
    marked: distinct(read.filter(each => each.isMarked).map(each => each.text)),
  }
}
