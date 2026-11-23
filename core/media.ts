/**
 * Images and documents Lee attaches to a reply he writes in the prompt box,
 * as the reply's words: each saved as a file in sitrep's folder, and named
 * in the words where its placeholder sat, for Claude to open with its Read
 * tool (DESIGN.md, "An answer with an image"). A reply owns the files its
 * words name.
 */
import { mediaDir } from './paths'

/** A saved attachment: its kind, and the file it was saved as. */
export type SavedMedia = { kind: 'image' | 'document'; path: string }

/** The extension each common type is saved with; any other takes its subtype, or `bin`. */
const EXTENSIONS: Readonly<Record<string, string>> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/gif': 'gif',
  'image/webp': 'webp',
  'application/pdf': 'pdf',
}

const SUBTYPE = /^[a-z]+\/([a-z0-9]+)$/

/** What a saved file's name is: the name drawn for it, then its extension. */
const SAVED_NAME = /^[0-9a-z]+\.[0-9a-z]+$/

/** Where Claude Code's prompt leaves a pasted image: `[Image #1]`. */
const PLACEHOLDER = /\[Image #(\d+)\]/g

/** A saved attachment as a reply's words name it. */
const NAMED = /\[(?:image|document): ([^\]\n]+)\]/g

export const mediaExtension = (mediaType: string) =>
  EXTENSIONS[mediaType] ?? SUBTYPE.exec(mediaType)?.[1] ?? 'bin'

/** The file an attachment is saved as, under sitrep's folder `root`. */
export const mediaFile = (root: string, name: string, mediaType: string) =>
  `${mediaDir(root)}/${name}.${mediaExtension(mediaType)}`

/** A saved attachment in a reply's words: `[image: /…/media/k3x9.png]`. */
export const mediaWords = ({ kind, path }: SavedMedia) => `[${kind}: ${path}]`

/** What tells Claude, once in a message whose replies name a saved attachment, what to do with one. */
export const MEDIA_HINT =
  'Each [image: …] or [document: …] above is a file the user attached: open it with your Read tool.'

/** Whether a message's line names a saved attachment. */
export const namesMedia = (line: string) => new RegExp(NAMED.source).test(line)

/** The numbers of the image placeholders in `text`, each once, lowest first. */
const placeholdersIn = (text: string) =>
  [...new Set([...text.matchAll(PLACEHOLDER)].map(([, number]) => Number(number)))].sort(
    (a, b) => a - b,
  )

/**
 * Lee's words with each saved image in place of its placeholder: the
 * placeholders, lowest number first, take the images in the order attached.
 * What no placeholder places goes at the end, on a line of its own after
 * words of several lines.
 */
export const placeMedia = (text: string, saved: readonly SavedMedia[]) => {
  const numbers = placeholdersIn(text)
  const placed = new Map(
    saved
      .filter(each => each.kind === 'image')
      .flatMap((image, i) => (numbers[i] === undefined ? [] : [[numbers[i], image] as const])),
  )
  const words = text.replace(PLACEHOLDER, (whole, number: string) => {
    const image = placed.get(Number(number))

    return image === undefined ? whole : mediaWords(image)
  })
  const rest = saved.filter(each => ![...placed.values()].includes(each))

  if (rest.length === 0) {
    return words
  }

  return `${words}${words.includes('\n') ? '\n' : ' '}${rest.map(mediaWords).join(' ')}`
}

/**
 * The saved attachments words name, in sitrep's folder `root`: only a file
 * directly in its media folder, named as a save names one, so no words can
 * name anything else for removing.
 */
export const mediaNamed = (text: string | undefined, root: string) => {
  const dir = `${mediaDir(root)}/`

  return [...(text ?? '').matchAll(NAMED)].flatMap(([, path = '']) =>
    path.startsWith(dir) && SAVED_NAME.test(path.slice(dir.length)) ? [path] : [],
  )
}
