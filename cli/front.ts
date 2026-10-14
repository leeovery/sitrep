/**
 * Which app is in front, as lsappinfo says, and Ghostty kept there after a
 * jump. With another app in front as a jump begins, and the Space the jump
 * goes to last showing that app in front, macOS hands the front back to it
 * once its slide to the Space ends: Ghostty in front about 0.2s after the
 * jump, the other app again at about 0.5s, Ghostty's focused terminal by
 * then the one the jump chose. Bringing Ghostty forward again then keeps it
 * there. With Ghostty in front as the jump began, it never happened (all
 * seen live, 14 October 2026).
 */
import type { Io } from './io'
import { look } from './look'

/** Ghostty's bundle id, by which lsappinfo names it and `open` finds it. */
export const GHOSTTY_BUNDLE = 'com.mitchellh.ghostty'

/** lsappinfo's words for the app in front, which it names by its ASN (`ASN:0x0-0x76076:`). */
export const FRONT = ['lsappinfo', 'front']

/** lsappinfo's words for the bundle id of the app an ASN names. */
export const bundleWords = (asn: string) => ['lsappinfo', 'info', '-only', 'bundleid', asn]

/** How often the watch looks: often enough to see the hand-back within a few tenths of its landing, as a look is a run or two of lsappinfo at about 11ms each. */
export const LOOK_EVERY_MS = 50

/**
 * How long the watch lasts: twice the half second after the jump's end at
 * which the hand-back came, in all three logged (14 October 2026). No
 * longer, since a jump that sees no hand-back keeps the app waiting this
 * long, and a switch Lee makes himself within it would be undone.
 */
export const WATCH_MS = 1_000

/**
 * Brings Ghostty forward through LaunchServices, sending it no Apple Event,
 * so it needs no leave to control Ghostty: 68–98ms, where osascript's
 * `activate` took 202–354ms, long enough for the window to sit unfocused
 * for half a second after the hand-back (14 October 2026). Safe because it
 * runs only on a hand-back, Ghostty seen in front after the focus and then
 * another app: Ghostty is running, so `open` never launches it, and its
 * window was just in front, so the reopen event `open` sends never makes a
 * new one.
 */
export const BRING_FORWARD = ['open', '-b', GHOSTTY_BUNDLE]

/** lsappinfo's line for a bundle id, `"CFBundleIdentifier"="com.mitchellh.ghostty"`; `[ NULL ]` in place of the id for an app gone. */
const BUNDLE_LINE = /"CFBundleIdentifier"="([^"]+)"/

/** The bundle id lsappinfo gives; undefined for none. */
export const parseBundle = (output: string) => BUNDLE_LINE.exec(output)?.[1]

/** What a program printed, trimmed, when it ran and ended well. */
const printed = async (io: Io, command: readonly string[]) => {
  const ran = await look(io, command)

  return ran?.exitCode === 0 ? ran.stdout.trim() : undefined
}

/** A look at the app in front: its bundle id, or undefined when lsappinfo cannot tell. */
export type Front = () => Promise<string | undefined>

/**
 * Looks at the app in front, one jump's worth: each look runs `lsappinfo
 * front`, and asks an app's bundle id only for an ASN not seen before, as
 * an ASN names one app for its whole life.
 */
export const frontmost = (io: Io): Front => {
  const bundles = new Map<string, string>()

  const bundleOf = async (asn: string) => {
    const bundle = bundles.get(asn) ?? parseBundle((await printed(io, bundleWords(asn))) ?? '')

    if (bundle !== undefined) {
      bundles.set(asn, bundle)
    }

    return bundle
  }

  return async () => {
    const asn = await printed(io, FRONT)

    return asn === undefined || asn === '' ? undefined : bundleOf(asn)
  }
}

/**
 * Watches the front after a jump's focus: whether another app took it back
 * from Ghostty, seen in front first. Ghostty never in front is no hand-back:
 * the focus may have shown nothing, Ghostty hidden or its window minimised,
 * and `open` could then make it a new window. A look lsappinfo gives no
 * answer to changes nothing.
 */
const isHandedBack = async (io: Io, look: Front) => {
  const until = io.now() + WATCH_MS
  let isForward = false

  while (io.now() < until) {
    await io.wait(LOOK_EVERY_MS)

    const front = await look()

    if (isForward && front !== undefined && front !== GHOSTTY_BUNDLE) {
      return true
    }

    isForward = isForward || front === GHOSTTY_BUNDLE
  }

  return false
}

/**
 * After a jump's focus, brings Ghostty forward once more should another app
 * take the front back from it, when another app, `before`, was in front as
 * the jump began. Nothing when Ghostty was, or lsappinfo could not tell;
 * nothing that fails here fails the jump.
 */
export const keepInFront = async (io: Io, front: Front, before: string | undefined) => {
  if (before === undefined || before === GHOSTTY_BUNDLE || !(await isHandedBack(io, front))) {
    return
  }

  await look(io, BRING_FORWARD)
}
