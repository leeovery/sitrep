/**
 * The option of a choice ask Claude recommends, as its `recommended` says,
 * or as Claude still types it into the option: "recommended" marking the
 * option, read as the field and stripped, so the option's own words never
 * carry it and every surface marks it once, beside the option.
 */
import { oneLine } from './text'

/** The word, any case, with an adverb Claude puts before it inside brackets. */
const WORD = String.raw`(?:(?:strongly|highly)\s+)?recommended`

/** What sets the word off from more words inside its brackets: a comma, semicolon or colon, an en or em dash, or a hyphen after a space. */
const SEPARATOR = String.raw`\s*(?:[,;:]|[–—]|\s-)\s*`

/**
 * Each way Claude types a marker, and what is left of the option without
 * it: "Recommended:" before the option; the word in parentheses or brackets
 * ending it, a full stop or a bang after; the word after a dash ending it,
 * a hyphen set off by a space, an en or em dash by none; the word in
 * brackets with more words after it; and brackets that start with the
 * word and go on after a separator, which keep what follows it.
 */
const MARKERS: readonly (readonly [marker: RegExp, left: string])[] = [
  [/^recommended\s*:\s*(?=\S)/i, ''],
  [new RegExp(String.raw`(\S)\s*(?:\(${WORD}\)|\[${WORD}\])[.!]?$`, 'i'), '$1'],
  [/(\S)(?:\s+-|\s*[–—])\s*recommended[.!]?$/i, '$1'],
  [new RegExp(String.raw`(\S)\s*(?:\(${WORD}\)|\[${WORD}\])(?=\s+\S)`, 'i'), '$1'],
  [new RegExp(String.raw`\(\s*${WORD}${SEPARATOR}([^()]*?\S)\s*\)`, 'i'), '($1)'],
  [new RegExp(String.raw`\[\s*${WORD}${SEPARATOR}([^[\]]*?\S)\s*\]`, 'i'), '[$1]'],
]

/** An option's words without the first marker found in them; undefined where none is. */
const stripOnce = (option: string) => {
  const found = MARKERS.find(([marker]) => marker.test(option))

  return found === undefined ? undefined : oneLine(option.replace(found[0], found[1]))
}

/** An option's words, every marker typed in them stripped, one after another until none is left, and whether they carried one. */
export const unmarked = (option: string): { text: string; isMarked: boolean } => {
  let text = option

  for (let next = stripOnce(text); next !== undefined; next = stripOnce(text)) {
    text = next
  }

  return { text, isMarked: text !== option }
}

/**
 * A choice's options, each one line already and none repeated, their
 * markers stripped and the repeats that leaves dropped; those that carried
 * a marker; and the options two given ones became, once stripped.
 */
export const readOptions = (given: readonly string[]) => {
  const read = given.map(unmarked)
  const texts = read.map(each => each.text)
  const distinct = (list: readonly string[]) => [...new Set(list)]

  return {
    options: distinct(texts),
    marked: distinct(read.filter(each => each.isMarked).map(each => each.text)),
    collapsed: distinct(texts.filter((text, i) => texts.indexOf(text) !== i)),
  }
}

/** The option offered in the words given: the same words, else the same once each is stripped of its markers, as an option posted before markers were read may carry one. */
export const offeredAs = (options: readonly string[], given: string) => {
  const bare = unmarked(given).text

  return (
    options.find(option => option === given) ??
    options.find(option => unmarked(option).text === bare)
  )
}
