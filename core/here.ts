/**
 * Who views each held session, and each tty inside a multiplexer session,
 * as SitRep last read them, from its `here.json`. A viewer is `mac`, this
 * Mac's screen, or `ssh:<address>`, a device reached over SSH, so every
 * terminal one phone opens counts as that phone. SitRep writes the file at
 * once as what it says changes, and otherwise at most every 10 seconds
 * (`HereFile.refresh` in the app) while any held session is read; it
 * removes the file as none is, and as it quits. So no file says every held
 * session is filled, as one that does not read does; and a file older than
 * HERE_STALE_MS is a SitRep no longer reading, so it says nothing either.
 *
 * The panel dims a held session no device it is looked at from views
 * (`notHereOf`): over SSH, one open on the phone the panel is on draws
 * filled, and one open only in the Mac's Ghostty draws hollow there.
 */
import { isObject, isTime, parseVersioned } from './entries'
import type { Raw, Upgrade } from './versions'

/** Where a session or a tty is looked at from: `mac`, `ssh:<address>`, or what a later SitRep names. */
export type Viewers = ReadonlySet<string>

/** What `here.json` says: each held session's viewers, by its id; and each multiplexer tty's, by its device. */
export type Sightings = {
  sessions: ReadonlyMap<string, Viewers>
  ttys: ReadonlyMap<string, Viewers>
}

/** Where the panel is looked at from: its terminal's device, and its own `SSH_CONNECTION`, either unknown. */
export type Lookout = { tty?: string; sshConnection?: string }

const isIds = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every(each => typeof each === 'string')

/**
 * Version 1 named only the held sessions no terminal on this Mac showed,
 * as `notHere`: each is seen by nobody, so it stays dimmed wherever the
 * panel is, as version 1 dimmed it; a list that does not read leaves the
 * file unread.
 */
const fromNotHere: Upgrade = ({ notHere, ...rest }: Raw) => ({
  ...rest,
  sessions: isIds(notHere) ? Object.fromEntries(notHere.map(id => [id, []])) : undefined,
  ttys: {},
})

/** How the app's `here.json` of each past version is brought to the next. */
const UPGRADES: readonly Upgrade[] = [fromNotHere]

/**
 * How old a file may be and still say what SitRep reads. SitRep writes it
 * at least every 10 seconds while it reads, and removes it at quit and once
 * nothing is held, so this matters only for a SitRep that crashed, hung or
 * was napped. SitRep runs in the background, with no activity held against
 * App Nap, and macOS may stretch its 3 seconds' sleep well past 10 seconds:
 * so 30 seconds, lest every dimmed row in every panel blink filled while
 * SitRep is napped.
 */
export const HERE_STALE_MS = 30_000

const NONE: ReadonlySet<string> = new Set()

/** A JSON object whose every value is a list of text, as a map of viewers. */
const viewersOf = (value: unknown): ReadonlyMap<string, Viewers> | undefined =>
  isObject(value) && Object.values(value).every(isIds)
    ? new Map(Object.entries(value as Record<string, string[]>).map(([key, viewers]) => [key, new Set(viewers)]))
    : undefined

/**
 * What `here.json`'s text says at `now`: undefined where there is no file,
 * or it is not a JSON object of a version this reader knows, holding a
 * time and its maps of viewers, or its time is HERE_STALE_MS or more from
 * `now`, either side: a file from ahead of the clock, as a clock set back
 * leaves it, would stay fresh until then.
 */
export const sightingsOf = (text: string | undefined, now: number): Sightings | undefined => {
  const file = text === undefined ? undefined : parseVersioned(text, UPGRADES)

  if (file === undefined || !isTime(file.at) || Math.abs(now - file.at) >= HERE_STALE_MS) {
    return undefined
  }

  const sessions = viewersOf(file.sessions)
  const ttys = viewersOf(file.ttys)

  return sessions === undefined || ttys === undefined ? undefined : { sessions, ttys }
}

/**
 * Where the panel is looked at from: its own tty's viewers, where SitRep
 * lists any, as inside zmx or tmux, whose `SSH_CONNECTION` is the one the
 * session was made with; else the device its own `SSH_CONNECTION` names;
 * else this Mac's screen.
 */
export const lookingFrom = (sightings: Sightings | undefined, { tty, sshConnection }: Lookout): Viewers => {
  const listed = tty === undefined ? undefined : sightings?.ttys.get(tty)

  if (listed !== undefined && listed.size > 0) {
    return listed
  }

  const address = sshConnection?.trim().split(/\s+/)[0] ?? ''

  return new Set([address === '' ? 'mac' : `ssh:${address}`])
}

/**
 * The held sessions `here.json`'s text says no device the panel is looked
 * at from views, at `now`: those it names whose viewers share none with the
 * panel's. None for a file missing, unreadable or stale, so every held
 * session draws filled while SitRep isn't reading; a session it doesn't
 * name, never read, draws filled too.
 */
export const notHereOf = (text: string | undefined, now: number, lookout: Lookout): ReadonlySet<string> => {
  const sightings = sightingsOf(text, now)

  if (sightings === undefined) {
    return NONE
  }

  const own = lookingFrom(sightings, lookout)

  return new Set(
    [...sightings.sessions].filter(([, viewers]) => ![...viewers].some(each => own.has(each))).map(([id]) => id),
  )
}

/**
 * The tty a terminal's numbers name, as the app names a process's from the
 * kernel's table (`device(of:)`): `/dev/ttys032` for major 16, a pty, minor
 * 32, at least three digits; none for any other device, or for none. Bun's
 * `fstatSync(0).rdev` gives the panel's own.
 */
export const ttyOf = (rdev: number): string | undefined => {
  const numbers = rdev >>> 0
  const minor = numbers & 0xff_ffff

  return numbers >>> 24 === 16 ? `/dev/ttys${String(minor).padStart(3, '0')}` : undefined
}
