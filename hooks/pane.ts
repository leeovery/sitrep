/**
 * The board's pane: opened on a place and an item, and closed again.
 *
 * Claude Code places a pane opened by Lee's press or command at any width
 * (docked from 110 columns in fullscreen, inline otherwise), and one opened
 * unasked only from 144. So the band's buttons open the board inside the
 * press itself, from the `ui.press` hook: an open made once the press has
 * settled counts as unasked.
 */
import type { SitrepPane, SitrepPlacement } from '../types'
import { endAnswering } from './answering'
import { lookAround } from './around'
import { fromTheTop } from './clip'
import type { Host } from './host'
import { EVERY_PROJECT } from './places'

/** The pane's id, as `$.ui.open` and its `ui.render` name it. */
export const PANE = 'sitrep'

const TITLE = 'sitrep'

/** The columns asked for, and the rows inline. */
const COLUMNS = 62
const ROWS = 24

/** The band's buttons: each a way into the board, or, while Lee answers in the prompt, the way out of that. */
export const BAND = {
  asks: 'band:asks',
  elsewhere: 'band:elsewhere',
  board: 'band:board',
  cancelAnswer: 'band:cancel-answer',
} as const

export const BAND_KEYS = Object.values(BAND)

/** How the board was last drawn on each surface, as its render's props said: what a press on it, answered by a hook, goes by. */
const drawnAs = new Map<string, SitrepPlacement>()

export const heardPaneDrawn = (surface: string, placement: SitrepPlacement) => {
  drawnAs.set(surface, placement)
}

/** Whether the board was drawn docked on a surface, as it is unless drawn inline there. */
export const isDrawnDocked = (surface: string) => drawnAs.get(surface) !== 'inline'

/** Where the board opens: where it looks, and the item opened under its line. */
export type Focus = Partial<Pick<SitrepPane, 'place' | 'selected'>>

/** Where each of the band's counts opens the board: this session, or every project. */
const COUNTED: Readonly<Record<string, Focus>> = {
  [BAND.asks]: { place: null },
  [BAND.elsewhere]: { place: EVERY_PROJECT },
}

/** Where the board opens once it has been closed: home, nothing opened, every RESOLVED showing its latest, and Ready to send's row for several held sends on the first. */
const HOME: Partial<SitrepPane> = {
  place: null,
  selected: null,
  resolvedInFull: null,
  heldShown: null,
}

const markOpen = (host: Host, isOpen: boolean) =>
  host.state.pane.update(pane => ({ ...pane, isOpen }))

/** The board closed: the band's button follows, and the board forgets where it had gone and how far down. */
const markClosed = async (host: Host) => {
  await host.state.pane.update(pane => ({ ...pane, ...HOME, isOpen: false }))
  await host.state.scroll.write(null)
}

const isUp = async (host: Host) => (await host.ui.panes()).some(pane => pane.id === PANE)

/**
 * Opens the board, and reads what it shows; one Claude Code would not draw
 * is closed again, and a toast says why.
 */
export const openBoard = async (host: Host, focus: Focus = {}) => {
  await host.state.pane.update(pane => ({ ...pane, ...focus }))

  const opened = await host.ui.open({ id: PANE, title: TITLE, columns: COLUMNS, rows: ROWS })

  if (!opened.isPlaced) {
    // Open but undrawn, the band would say "hide board" over nothing.
    await host.ui.close(PANE)
    await markClosed(host)
    host.ui.toast(`Claude Code didn't draw the board: ${opened.reason}`)

    return
  }

  await markOpen(host, true)
  await lookAround(host)
}

/** Closes the board: by the band's button, by an inline board's own close, or once an inline board's send is claimed. */
export const closeBoard = async (host: Host) => {
  await host.ui.close(PANE)
  // A plugin's own close never reaches its own ui.close hook, so the band hears of it here.
  await markClosed(host)
}

/** Shows the board, or hides it, as the engine has it rather than as the band's label says. */
const toggleBoard = async (host: Host) => ((await isUp(host)) ? closeBoard(host) : openBoard(host))

/** Brings the band's word on the board into line with the engine's record, after a reload. */
export const syncBoard = async (host: Host) => markOpen(host, await isUp(host))

/** The board closed by Lee's ✕. */
export const boardClosed = markClosed

/** Opens the board on what a count counts, at its top there, though the board was showing it already. */
const openOnCount = async (host: Host, focus: Focus) => {
  await openBoard(host, focus)
  await fromTheTop(host)
}

/** A press on one of the band's buttons: a count opens the board on what it counts. */
export const pressBand = async (host: Host, element: string) => {
  if (element === BAND.cancelAnswer) {
    return endAnswering(host)
  }

  const held = await host.state.attachment.read()
  const focus = Object.hasOwn(COUNTED, element) ? COUNTED[element] : undefined

  return held === null || focus === undefined ? toggleBoard(host) : openOnCount(host, focus)
}

/** Where the board was last seated on a surface, as the board drawn there said; unsaid there, or on a pane an older load saved, none. */
export const placementOn = (pane: SitrepPane, surface: string) => pane.placement?.[surface]

const isPlacement = (value: unknown): value is SitrepPlacement =>
  value === 'dock' || value === 'inline'

/** Keeps where the board's `Client` on a surface says it is seated, written only as it changes, so the band draws again then. */
export const heardPlacement = async (host: Host, surface: string, data: unknown) => {
  const { placement } = (data ?? {}) as { placement?: unknown }

  if (!isPlacement(placement) || placementOn(await host.state.pane.read(), surface) === placement) {
    return
  }

  await host.state.pane.update(pane => ({
    ...pane,
    placement: { ...pane.placement, [surface]: placement },
  }))
}
