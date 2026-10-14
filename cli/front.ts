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

/** How often the watch looks: often enough to see the hand-back within a few tenths of its landing, as a look is two runs of lsappinfo at about 11ms each. */
export const LOOK_EVERY_MS = 50

/** How long the watch lasts: three times the half second after the jump at which the hand-back came. */
export const WATCH_MS = 1_500

/**
 * Brings Ghostty forward through LaunchServices, sending it no Apple Event,
 * so it needs no leave to control Ghostty: 68–98ms, where osascript's
 * `activate` took 202–354ms, long enough for the window to sit unfocused
 * for half a second after the hand-back (14 October 2026). Safe because it
 * runs only after a focus succeeded: Ghostty is running, so `open` never
 * launches it, and it has a visible window, so the reopen event `open`
 * sends never makes a new one.
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

/** The bundle id of the app in front; undefined when lsappinfo cannot tell. */
export const frontmost = async (io: Io) => {
  const asn = await printed(io, FRONT)

  return asn === undefined || asn === ''
    ? undefined
    : parseBundle((await printed(io, bundleWords(asn))) ?? '')
}

/**
 * Watches the front after a jump's focus: whether Ghostty needs bringing
 * forward again, another app having taken the front from it, or Ghostty
 * never having come forward. A look lsappinfo gives no answer to changes
 * nothing.
 */
const isFrontLost = async (io: Io) => {
  const until = io.now() + WATCH_MS
  let isForward = false

  while (io.now() < until) {
    await io.wait(LOOK_EVERY_MS)

    const front = await frontmost(io)

    if (isForward && front !== undefined && front !== GHOSTTY_BUNDLE) {
      return true
    }

    isForward = isForward || front === GHOSTTY_BUNDLE
  }

  return !isForward
}

/**
 * After a jump's focus, brings Ghostty forward once more should it lose the
 * front, when another app was in front as the jump began. Nothing when
 * Ghostty was, or lsappinfo could not tell; nothing that fails here fails
 * the jump.
 */
export const keepInFront = async (io: Io, before: string | undefined) => {
  if (before === undefined || before === GHOSTTY_BUNDLE || !(await isFrontLost(io))) {
    return
  }

  await look(io, BRING_FORWARD)
}
