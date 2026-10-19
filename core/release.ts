/**
 * The sitrep release a window runs, against the CLI's own: each is its
 * plugin manifest's `version`, a window's said in its heartbeat, so the menu
 * can list the windows still to `/reload-plugins` (see "Versions side by
 * side" in DESIGN.md).
 */
import { isFilled, isObject } from './entries'
import { compareText } from './text'

const NUMBER = /^\d+$/

/** The version a plugin manifest's text gives; undefined where it is torn or gives none. */
export const manifestVersion = (text: string) => {
  try {
    const manifest: unknown = JSON.parse(text)

    return isObject(manifest) && isFilled(manifest.version) ? manifest.version : undefined
  } catch {
    return undefined
  }
}

/** Two versions' order, dotted part by part: numbers as numbers, anything else as text, a part missing as 0. */
const compareVersions = (a: string, b: string) => {
  const ours = a.split('.')
  const theirs = b.split('.')

  for (let i = 0; i < Math.max(ours.length, theirs.length); i += 1) {
    const x = ours[i] ?? '0'
    const y = theirs[i] ?? '0'
    const order = NUMBER.test(x) && NUMBER.test(y) ? Number(x) - Number(y) : compareText(x, y)

    if (order !== 0) {
      return order
    }
  }

  return 0
}

/**
 * Whether a window runs a sitrep behind `own`, the CLI's, and needs
 * `/reload-plugins`: one saying no version runs a release from before
 * heartbeats said it. With no version of its own to go by, only those.
 */
export const needsReload = (version: string | undefined, own: string | undefined) =>
  version === undefined || (own !== undefined && compareVersions(version, own) < 0)
